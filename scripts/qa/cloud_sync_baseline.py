#!/usr/bin/env python3
"""Exercise BeeCount's actual sync engine against temporary SQLite and PostgreSQL Clouds."""
import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import tarfile
import urllib.request

from isolated_app_cloud import export_commit
from cloud_sync_report import render

APP = Path(__file__).resolve().parents[2]
SERVER = Path(__file__).with_name("cloud_sync_server.py")
CASES = {"upload": ("full-upload", "incremental-upload"),
         "pull": ("full-pull", "delta-pull", "same-device-restore"), "relations": ("relations",),
         "full_upload_retry": ("upload-resume-dictionary", "upload-resume-uncommitted", "upload-resume-lost-receipt"),
         "contracts": ("shared-ledger", "recovery"), "mode": ("mode-switch",),
         "compatibility": ("compatibility",)}
CORE = ("upload", "full_upload_retry", "pull", "relations", "contracts", "mode")
CLOUD_PATHS = {
    "ATTACHMENT_STORAGE_DIR": "attachments", "BACKUP_STORAGE_DIR": "backups",
    "BACKUP_STAGING_DIR": "staging", "RESTORE_DIR": "restore", "RCLONE_CONFIG_PATH": "rclone.conf",
    "RAG_INDEX_CACHE_DIR": "rag", "WEB_STATIC_DIR": "static",
}


def git(repo, *args):
    return subprocess.check_output(["git", "-C", repo, *args], text=True).strip()


def save(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def traffic(origin):
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(origin + "/__qa__/traffic", timeout=5) as response:
        return json.load(response)


def postgres_bins(explicit):
    if explicit:
        directory = explicit.resolve()
    elif shutil.which("initdb"):
        directory = Path(shutil.which("initdb")).parent
    elif shutil.which("pg_config"):
        directory = Path(subprocess.check_output(["pg_config", "--bindir"], text=True).strip())
    else:
        raise ValueError("Install PostgreSQL server tools or pass --postgres-bin DIR")
    if not all((directory / name).is_file() for name in ("initdb", "pg_ctl")):
        raise ValueError(f"PostgreSQL server binaries missing in {directory}")
    return directory


@contextmanager
def database(root, name, pg_bin, python, log):
    if name == "sqlite":
        yield "sqlite:///" + str(root / "qa.db")
        return
    data, sock = root / "pgdata", root / "socket"
    sock.mkdir(mode=0o700)
    # No inherited PG settings, TCP listener, system cluster or existing databases.
    env = {"PATH": os.environ["PATH"], "LC_ALL": "C", "PGHOST": str(sock),
           "PGPORT": "5432", "PGUSER": "qa"}
    def run(*args):
        subprocess.run(args, check=True, env=env, stdout=log, stderr=log)
    run(pg_bin / "initdb", "-D", data, "-U", "qa", "-A", "trust", "--no-locale",
        "--encoding=UTF8", "--no-sync")
    run(pg_bin / "pg_ctl", "-D", data, "-l", root / "postgres.log", "-w", "-o",
        f"-h '' -k '{sock}' -p 5432 -c timezone=Asia/Shanghai", "start")
    try:
        run(python, "-c", "import psycopg\nwith psycopg.connect(dbname='postgres', autocommit=True) as db:\n"
            "    db.execute('CREATE DATABASE qa_sync')")
        yield f"postgresql+psycopg://qa@/qa_sync?host={sock}"
    finally:
        run(pg_bin / "pg_ctl", "-D", data, "-m", "fast", "-w", "stop")


@contextmanager
def cloud(root, source, python, sha, name, pg_bin, log, provisioning_source=None):
    root = root.resolve()
    with database(root, name, pg_bin, python, log) as url:
        env = {"PATH": os.environ["PATH"], "PYTHONPATH": str(source),
               "PYTHONDONTWRITEBYTECODE": "1", "APP_ENV": "test", "TZ": "Asia/Shanghai",
               "DATABASE_URL": url, "DATA_DIR": str(root), "QA_RUN_ID": root.name,
               "QA_CLOUD_SHA": sha, "JWT_SECRET": secrets.token_hex(32),
               "BOOTSTRAP_ADMIN_EMAIL": "admin@qa.example.com",
               "BOOTSTRAP_ADMIN_PASSWORD": secrets.token_urlsafe(32),
               "REGISTRATION_ENABLED": "true", "ALLOW_APP_RW_SCOPES": "true",
               "BACKUP_SCHEDULER_ENABLED": "false", "MCP_RECURRING_ENABLED": "false",
               "RAG_INDEX_REFRESH_INTERVAL_SECONDS": "0", "EXCHANGE_RATE_PROXY_ENABLED": "false",
               **{key: str(root / rel) for key, rel in CLOUD_PATHS.items()}}
        migration = [python, SERVER, "migrate"]
        migration_env = env
        if provisioning_source:
            migration.extend(["--target-schema-from", str(source)])
            migration_env = {**env, "PYTHONPATH": str(provisioning_source)}
        subprocess.run(migration, cwd=root, env=migration_env,
                       stdout=log, stderr=log, check=True)
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            listener.listen(128)
            origin = f"http://127.0.0.1:{listener.getsockname()[1]}"
            worker = subprocess.Popen([python, SERVER, "serve", "--fd", str(listener.fileno())],
                                      cwd=root, env=env, stdout=log, stderr=log,
                                      pass_fds=(listener.fileno(),))
        try:
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            deadline = time.monotonic() + 45
            while time.monotonic() < deadline:
                if worker.poll() is not None:
                    raise RuntimeError("Isolated Cloud exited before startup")
                try:
                    with opener.open(origin + "/__qa__/identity", timeout=1) as response:
                        identity = json.load(response)
                except OSError:
                    time.sleep(0.2)
                    continue
                if (identity.get("run_id") != root.name or identity.get("cloud_sha") != sha
                        or identity.get("database") != name or not identity.get("database_is_isolated")):
                    raise ValueError("The running Cloud does not match the requested source and database")
                break
            else:
                raise RuntimeError("Isolated Cloud did not start within 45 seconds")
            yield origin, identity
        finally:
            if worker.poll() is None:
                worker.terminate()
                try:
                    worker.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    worker.kill()
                    worker.wait()


def run_file(cfg, suite, dest, origin, log_dir, python, app_sha, app_repo):
    """Only evidence produced by this invocation can satisfy a case."""
    directory = dest / suite
    directory.mkdir(mode=0o700)
    settings = {"CLOUD_SYNC_QA_URL": origin, "CLOUD_SYNC_QA_OUTPUT": str(directory), "CLOUD_SYNC_QA_SUITE": cfg.suite,
                "CLOUD_SYNC_QA_APP_SHA": app_sha,
                "CLOUD_SYNC_QA_SEED": str(cfg.seed), "CLOUD_SYNC_QA_TRANSACTIONS": str(cfg.transactions)}
    if suite == "contracts":
        command = [python, "qa/cloud_sync/cloud_contracts.py"]
    else:
        command = [cfg.flutter, "test", "--no-pub", "--reporter", "expanded", "--timeout", "30m",
                   "qa/cloud_sync/" + suite + "_test.dart"]
    cases = CASES[suite]
    if cfg.suite == "capacity":
        command.extend(["--plain-name", "full-upload"])
        cases = ("full-upload",)
    started = time.monotonic()
    with (log_dir / (suite + ".log")).open("w") as log:
        completed = subprocess.run(command, cwd=app_repo, env={**os.environ, **settings},
                                   stdout=log, stderr=log)
    files = []
    for case in cases:
        path = directory / (case + ".json")
        if path.exists():
            # Malformed output is a test failure, even when Flutter reports a zero exit code.
            report = json.loads(path.read_text())
            if not isinstance(report, dict):
                raise ValueError(f"{case} did not produce a result object")
            if report.get("status") == "PASS":
                files.append(case)
    passed = completed.returncode == 0 and len(files) == len(cases)
    return {"suite": suite, "status": "PASS" if passed else "FAIL", "exit": completed.returncode,
            "case_files": files, "expected": list(cases), "seconds": round(time.monotonic() - started, 2)}


def run(cfg):
    repo = cfg.cloud_repo.resolve()
    sha = git(repo, "rev-parse", "--verify", cfg.cloud_ref + "^{commit}")
    common = Path(git(repo, "rev-parse", "--path-format=absolute", "--git-common-dir"))
    python = cfg.cloud_python or repo / ".venv/bin/python"
    if not cfg.cloud_python and not python.exists():
        python = common.parent / ".venv/bin/python"
    # Do not resolve a venv's symlink to the underlying system interpreter.
    python = python.absolute()
    if not python.is_file():
        raise ValueError("Install BeeCount-Cloud requirements in .venv or pass --cloud-python")
    dialects = ["sqlite", "postgresql"] if cfg.database == "both" else [cfg.database]
    pg_bin = postgres_bins(cfg.postgres_bin) if "postgresql" in dialects else None
    if cfg.output:
        output = cfg.output.resolve()
        output.mkdir(mode=0o700, parents=True, exist_ok=False)
    else:
        output = Path(tempfile.mkdtemp(prefix="beecount-results-"))
    result = {"app_sha": git(APP, "rev-parse", "--verify", (cfg.app_ref or "HEAD") + "^{commit}"),
              "cloud_sha": sha, "suite": cfg.suite,
              "app_dirty": not cfg.app_ref and bool(git(APP, "status", "--porcelain")),
              "seed": cfg.seed, "transactions": 2 if cfg.suite == "compatibility" else cfg.transactions,
              "selected": list(cfg.case or CORE), "databases": {}}
    print(f"Results: {output}", flush=True)
    with tempfile.TemporaryDirectory(prefix="bc-sync-source-") as tmp:
        src = Path(tmp) / "source"
        export_commit(repo, sha, src)
        provisioning_source = None
        if cfg.provisioning_ref:
            result["provisioning_sha"] = git(repo, "rev-parse", "--verify", cfg.provisioning_ref + "^{commit}")
            provisioning_source = Path(tmp) / "provisioning"
            export_commit(repo, result["provisioning_sha"], provisioning_source)
        app_repo = APP
        if cfg.app_ref:
            app_repo = Path(tmp) / "app"
            app_repo.mkdir()
            archive = Path(tmp) / "app.tar"
            subprocess.run(["git", "-C", APP, "archive", "-o", archive, result["app_sha"],
                            "lib", "packages", "assets", "pubspec.yaml", "pubspec.lock", "l10n.yaml"], check=True)
            with tarfile.open(archive) as bundle:
                bundle.extractall(app_repo, filter="data")
            probe = app_repo / "qa/cloud_sync"
            probe.mkdir(parents=True)
            for filename in ("compatibility_test.dart", "fixture_client.dart"):
                shutil.copyfile(APP / "qa/cloud_sync" / filename, probe / filename)
            subprocess.run([cfg.flutter, "pub", "get"], cwd=app_repo, check=True)
        for name in dialects:
            # Unix-domain socket paths must be short on macOS.
            root = Path(tempfile.mkdtemp(prefix="beecount-qa-sync-", dir="/tmp"))
            dest = output / name
            dest.mkdir()
            record = {"suites": []}
            result["databases"][name] = record
            try:
                with (root / "cloud.log").open("w") as log, cloud(
                    root, src, python, sha, name, pg_bin, log, provisioning_source
                ) as (origin, identity):
                    record["identity"] = identity
                    for suite in cfg.case or CORE:
                        print(f"{name}: {suite} running", flush=True)
                        before = traffic(origin)
                        item = run_file(cfg, suite, dest, origin, root, python, result["app_sha"], app_repo)
                        after = traffic(origin)
                        item["http"] = {key: after[key] - before[key] for key in
                                        ("requests", "request_body_bytes", "response_body_bytes")}
                        item["cloud_peak_rss_bytes"] = after["cloud_peak_rss_bytes"]
                        record["suites"].append(item)
                        print(f"{name}: {suite} {item['status']} ({item['seconds']}s)", flush=True)
                        save(output / "summary.json", result)
            except Exception as exc:
                # Exception text may include private installation paths or connection details.
                record["error"] = type(exc).__name__
                if isinstance(exc, subprocess.CalledProcessError):
                    record["exit"] = exc.returncode
                with (root / "cloud.log").open("a") as log:
                    print(f"{type(exc).__name__}: {exc}", file=log)
                print(f"{name}: {record['error']} (see private diagnostics)", file=sys.stderr, flush=True)
            completed = (not record.get("error") and len(record["suites"]) == len(result["selected"])
                         and all(x["status"] == "PASS" for x in record["suites"]))
            record["status"] = "PASS" if completed else "FAIL"
            save(output / "summary.json", result)
            if completed:
                shutil.rmtree(root)
            else:
                print(f"Private diagnostics: {root}", flush=True)
    render(output, result)
    return 0 if all(item["status"] == "PASS" for item in result["databases"].values()) else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("run",))
    parser.add_argument("--suite", choices=("core", "capacity", "compatibility"), default="core")
    parser.add_argument("--app-ref", help="compile the portable compatibility probe against this App revision")
    parser.add_argument("--cloud-repo", type=Path, required=True)
    parser.add_argument("--cloud-ref", default="HEAD", help="committed Cloud ref to export")
    parser.add_argument("--provisioning-ref", help="prepare an existing-install compatibility database "
                        "with this Cloud ref's migrations up to the running Cloud's schema revision")
    parser.add_argument("--cloud-python", type=Path)
    parser.add_argument("--postgres-bin", type=Path)
    parser.add_argument("--flutter", default="flutter")
    parser.add_argument("--database", choices=("sqlite", "postgresql", "both"), default="both")
    parser.add_argument("--case", choices=CASES, action="append", help="only run this test file (repeatable)")
    parser.add_argument("--transactions", type=int, default=1200)
    parser.add_argument("--seed", type=int, default=20261126)
    parser.add_argument("--output", type=Path, help="new results directory (system temp by default)")
    cfg = parser.parse_args()
    if cfg.transactions < 48:
        parser.error("The 48 representative transactions require --transactions >= 48")
    if cfg.suite == "capacity":
        if cfg.case:
            parser.error("The capacity suite selects its own full-upload test")
        cfg.case = ["upload"]
    if cfg.suite == "compatibility":
        if cfg.case:
            parser.error("The compatibility suite selects its own cross-version probe")
        cfg.case = ["compatibility"]
    elif cfg.app_ref or cfg.provisioning_ref:
        parser.error("--app-ref and --provisioning-ref are used with --suite compatibility")
    if cfg.case and len(cfg.case) != len(set(cfg.case)):
        parser.error("Use each --case once")
    if not (APP / ".dart_tool/package_config.json").is_file():
        subprocess.run([cfg.flutter, "pub", "get"], cwd=APP, check=True)
    return run(cfg)


if __name__ == "__main__":
    sys.exit(main())
