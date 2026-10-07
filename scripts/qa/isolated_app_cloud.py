#!/usr/bin/env python3
"""Isolated iOS + live Cloud acceptance. Only owned QA resources may be mutated."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import plistlib
import secrets
import shutil
import signal
import socket
import sqlite3
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request

APP_ID = 'com.tntlikely.beecount.qa'
GROUP_ID = 'group.com.tntlikely.beecount.qa'
PROJECT = Path(__file__).resolve().parents[2]


def command(args, **kwargs):
    return subprocess.check_output([str(a) for a in args], **kwargs).decode().strip()


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    path.chmod(0o600)


def inside(root, path):
    root, path = Path(root).resolve(), Path(path)
    if path.is_symlink() or root not in path.resolve().parents:
        raise ValueError('QA path is not owned by this run')
    for parent in path.parents:
        if parent.resolve() == root:
            break
        if parent.is_symlink():
            raise ValueError('QA path has a symlinked parent')
    return path.resolve()


def load_run(path):
    root = Path(path)
    if root.is_symlink():
        raise ValueError('QA root must not be a symlink')
    root = root.resolve()
    manifest = json.loads((root / 'manifest.json').read_text())
    if Path(manifest['root']).resolve() != root or (root / '.qa-owner').read_text() != manifest['run_id']:
        raise ValueError('QA ownership marker does not match manifest')
    for name in ('cloud-data', 'cloud-runtime', 'cloud-source', 'evidence', 'raw-logs'):
        inside(root, root / name)
    if manifest['app_id'] != APP_ID:
        raise ValueError('Expected independent QA app ID')
    return root, manifest


def device(manifest):
    udid = manifest['udid']
    if udid in manifest['protected_udids']:
        raise ValueError('Refusing to mutate an existing simulator')
    devices = json.loads(command(['xcrun', 'simctl', 'list', 'devices', '-j']))['devices']
    matches = [d for ds in devices.values() for d in ds if d['udid'] == udid]
    if len(matches) != 1 or matches[0]['name'] != manifest['device_name']:
        raise ValueError('QA simulator identity no longer matches')
    return matches[0]


def export_commit(repo, sha, target):
    target.mkdir()
    archive = subprocess.check_output(['git', '-C', str(repo), 'archive', sha])
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        for entry in tar.getmembers():
            inside(target, target / entry.name)
            if entry.issym() or entry.islnk():
                raise ValueError('Source archive contains a link; review before exporting')
        tar.extractall(target, filter='data')


def prepare(args):
    root = Path(tempfile.mkdtemp(prefix='beecount-qa-')).resolve()
    root.chmod(0o700)
    run_id = root.name
    (root / '.qa-owner').write_text(run_id)
    for name in ('cloud-data', 'cloud-runtime', 'evidence', 'raw-logs', 'private-backups'):
        (root / name).mkdir(mode=0o700)
    cloud = Path(args.cloud_repo).resolve()
    sha = command(['git', '-C', cloud, 'rev-parse', args.cloud_ref])
    export_commit(cloud, sha, root / 'cloud-source')
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    devices = json.loads(command(['xcrun', 'simctl', 'list', 'devices', '-j']))['devices']
    manifest = dict(root=str(root), run_id=run_id, app_id=APP_ID,
                    cloud_sha=sha, cloud_origin=f'http://127.0.0.1:{port}',
                    runtime=args.runtime, device_name=f'BeeCount-QA-{run_id}',
                    protected_udids=[d['udid'] for ds in devices.values() for d in ds],
                    app_sha=command(['git', '-C', PROJECT, 'rev-parse', 'HEAD']))
    manifest['tool_versions'] = dict(
        flutter=json.loads(command([args.flutter, '--version', '--machine']))['frameworkVersion'],
        xcode=command(['xcodebuild', '-version']),
        host_python=sys.version.split()[0],
        cloud_python=command([cloud / '.venv/bin/python', '-c', 'import sys; print(sys.version.split()[0])']))
    if args.skill_repo:
        manifest['skill_sha'] = command(['git', '-C', args.skill_repo, 'rev-parse', 'HEAD'])
    write_json(root / 'manifest.json', manifest)
    credentials = dict(email=f'{run_id}@qa.example.com', password=secrets.token_urlsafe(24),
                       jwt_secret=secrets.token_hex(32), admin_password=secrets.token_urlsafe(24))
    write_json(root / 'credentials.json', credentials)
    data = root / 'cloud-data'
    paths = dict(DATA_DIR=str(data), DATABASE_URL=f'sqlite:///{data}/beecount.db',
                 ATTACHMENT_STORAGE_DIR=str(data / 'attachments'),
                 BACKUP_STORAGE_DIR=str(data / 'backups'),
                 BACKUP_STAGING_DIR=str(data / 'backup-staging'),
                 RESTORE_DIR=str(data / 'restore'), RCLONE_CONFIG_PATH=str(data / 'rclone.conf'),
                 RAG_INDEX_CACHE_DIR=str(data / 'rag-index'), WEB_STATIC_DIR=str(data / 'static'))
    env = dict(PATH=os.environ['PATH'], PYTHONPATH=str(root / 'cloud-source'),
               PYTHONDONTWRITEBYTECODE='1', APP_ENV='test', TZ='Asia/Shanghai',
               JWT_SECRET=credentials['jwt_secret'], BOOTSTRAP_ADMIN_EMAIL=f'admin-{run_id}@qa.example.com',
               BOOTSTRAP_ADMIN_PASSWORD=credentials['admin_password'],
               REGISTRATION_ENABLED='true', ALLOW_APP_RW_SCOPES='true',
               BACKUP_SCHEDULER_ENABLED='false', RAG_INDEX_REFRESH_INTERVAL_SECONDS='0',
               EXCHANGE_RATE_PROXY_ENABLED='false', EMBEDDING_API_KEY='', **paths)
    write_json(root / 'cloud-env.json', env)
    python = cloud / '.venv/bin/python'
    migration = (
        'from alembic.config import Config; from alembic import command; '
        f'c=Config({str(root / "cloud-source/alembic.ini")!r}); '
        f'c.set_main_option("script_location", {str(root / "cloud-source/alembic")!r}); '
        'command.upgrade(c, "head")'
    )
    if (data / 'beecount.db').exists():
        raise ValueError('QA database must be new before migrations')
    with (root / 'raw-logs/migrations.log').open('w') as log:
        subprocess.run([str(python), '-c', migration], cwd=root / 'cloud-runtime',
                       env=env, stdout=log, stderr=log, check=True)
    # Generated wrapper only exists inside this run. Validate actual settings before app import.
    wrapper = f'''from pathlib import Path
from src.config import get_settings
s=get_settings()
root=Path({str(data)!r}).resolve()
assert s.database_url == {paths['DATABASE_URL']!r}
for key in ('attachment_storage_dir','backup_storage_dir','backup_staging_dir',
            'restore_dir','rclone_config_path','rag_index_cache_dir','web_static_dir'):
    p=Path(getattr(s,key))
    assert not p.is_symlink() and root in p.resolve().parents, key
assert not s.backup_scheduler_enabled and s.rag_index_refresh_interval_seconds == 0
from src.main import app
from fastapi import Request
from fastapi.responses import JSONResponse
fault = {{'offline': False}}
@app.middleware('http')
async def qa_fault(request: Request, call_next):
    if fault['offline'] and request.url.path.startswith('/api/'):
        return JSONResponse({{'detail': 'QA simulated Cloud outage'}}, status_code=503)
    return await call_next(request)
@app.post('/__qa__/fault')
async def qa_set_fault(request: Request):
    body=await request.json()
    assert body.get('run_id') == {run_id!r}
    fault['offline']=bool(body['offline'])
    return {{'offline': fault['offline']}}
@app.get('/__qa__/identity')
def qa_identity():
    return {{'run_id': {run_id!r}, 'cloud_sha': {sha!r}, 'database_is_isolated': True}}
'''
    (root / 'cloud-runtime/qa_server.py').write_text(wrapper)
    with (root / 'raw-logs/cloud.log').open('w') as log:
        proc = subprocess.Popen([str(python), '-m', 'uvicorn', 'qa_server:app', '--host',
                                 '127.0.0.1', '--port', str(port)], cwd=root / 'cloud-runtime',
                                env=env, stdout=log, stderr=log, start_new_session=True)
    manifest['cloud_pid'] = proc.pid
    manifest['cloud_process_start'] = command(['ps', '-p', str(proc.pid), '-o', 'lstart='])
    write_json(root / 'manifest.json', manifest)
    for _ in range(120):
        if proc.poll() is not None:
            raise RuntimeError(f'QA Cloud failed; inspect private log in {root}')
        try:
            with urllib.request.urlopen(manifest['cloud_origin'] + '/__qa__/identity', timeout=1) as r:
                identity = json.load(r)
            if identity['run_id'] != run_id or not identity['database_is_isolated']:
                raise ValueError('Cloud ownership probe failed')
            break
        except (OSError, ValueError):
            time.sleep(0.5)
    else:
        raise RuntimeError(f'QA Cloud startup timed out; resources preserved in {root}')
    manifest['udid'] = command(['xcrun', 'simctl', 'create', manifest['device_name'],
                                'com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro', args.runtime])
    write_json(root / 'manifest.json', manifest)
    device(manifest)
    defines = dict(QA_RUN_ID=run_id, QA_ORIGIN=manifest['cloud_origin'], QA_EMAIL=credentials['email'],
                   QA_PASSWORD=credentials['password'], QA_APP_ID=APP_ID)
    write_json(root / 'defines.json', defines)
    print(f'QA environment ready: {root}', flush=True)
    print(f'New simulator: {manifest["udid"]}; local Cloud: {manifest["cloud_origin"]}', flush=True)


def snapshot(root, manifest):
    target = inside(root, root / 'app-source')
    if target.exists():
        raise ValueError('App snapshot already exists; create a fresh run for new code')
    target.mkdir()
    files = command(['git', '-C', PROJECT, 'ls-files', '-z']).split('\0')
    files += [str(p.relative_to(PROJECT)) for directory in ('scripts/qa', 'integration_test', 'test_driver')
              for p in (PROJECT / directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    digest = hashlib.sha256()
    for name in sorted(set(files)):
        if not name or name == 'AGENTS.md':
            continue
        source = inside(PROJECT, PROJECT / name)
        if not source.is_file():
            continue
        dest = inside(target, target / name)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, dest)
        digest.update(name.encode() + b'\0' + source.read_bytes())
    manifest['source_hash'] = digest.hexdigest()
    manifest['app_sha'] = command(['git', '-C', PROJECT, 'rev-parse', 'HEAD'])
    # Overlay belongs to the disposable copy, never to the normal checkout.
    for name in ('ios/Flutter/Debug.xcconfig', 'ios/Flutter/Release.xcconfig', 'ios/Runner.xcodeproj/project.pbxproj'):
        p = target / name
        value = p.read_text().replace('com.tntlikely.beecount.dev', APP_ID)
        value = value.replace('com.tntlikely.beecount.BeeCountWidgetExtension', APP_ID + '.BeeCountWidgetExtension')
        value = value.replace('com.example.beecount.RunnerTests', APP_ID + '.RunnerTests')
        value = value.replace('PRODUCT_BUNDLE_IDENTIFIER=com.tntlikely.beecount\n', f'PRODUCT_BUNDLE_IDENTIFIER={APP_ID}\n')
        p.write_text(value)
    for name in ('ios/Runner/Runner.entitlements', 'ios/BeeCountWidgetExtension.entitlements'):
        p = target / name
        data = plistlib.loads(p.read_bytes())
        data = {k: v for k, v in data.items() if 'icloud' not in k.lower() and 'ubiquity' not in k.lower()}
        data['com.apple.security.application-groups'] = [GROUP_ID]
        p.write_bytes(plistlib.dumps(data))
    p = target / 'ios/Runner/Info.plist'
    data = plistlib.loads(p.read_bytes())
    data.pop('NSUbiquitousContainers', None)
    data['CFBundleDisplayName'] = 'BeeCount QA'
    data['CFBundleURLTypes'] = []
    p.write_bytes(plistlib.dumps(data))
    for p in list((target / 'ios/BeeCountWidget').glob('*.swift')) + [target / 'lib/main.dart']:
        p.write_text(p.read_text().replace('group.com.tntlikely.beecount', GROUP_ID))
    write_json(root / 'manifest.json', manifest)
    return target


def verify_artifact(root, manifest):
    app = inside(root, root / 'app-source/build/ios/iphonesimulator/Runner.app')
    bundles = [app] + list((app / 'PlugIns').glob('*.appex'))
    expected = [APP_ID, APP_ID + '.BeeCountWidgetExtension']
    found = []
    for bundle in bundles:
        info = plistlib.loads((bundle / 'Info.plist').read_bytes())
        found.append(info['CFBundleIdentifier'])
        if info['CFBundleIdentifier'] not in expected or 'NSUbiquitousContainers' in info:
            raise ValueError('Unsafe bundle identity or iCloud container in built artifact')
        ent = subprocess.run(['codesign', '-d', '--entitlements', '-', '--xml', str(bundle)],
                             capture_output=True, check=True).stdout
        entitlements = plistlib.loads(ent)
        if any('icloud' in k.lower() or 'ubiquity' in k.lower() for k in entitlements):
            raise ValueError('QA artifact retains iCloud entitlements')
        if entitlements.get('com.apple.security.application-groups') != [GROUP_ID]:
            raise ValueError('QA artifact must use its own App Group')
    if sorted(found) != sorted(expected):
        raise ValueError('Unexpected embedded extension set')
    manifest['verified_bundles'] = found
    manifest['artifact_hash'] = hashlib.sha256((app / 'Runner').read_bytes()).hexdigest()
    write_json(root / 'manifest.json', manifest)
    return app


def build(root, manifest, flutter):
    source = snapshot(root, manifest)
    commands = [[flutter, 'pub', 'get'], [flutter, 'build', 'ios', '--debug', '--simulator',
                '--target', 'integration_test/transaction_copy_live_test.dart',
                f'--dart-define-from-file={root / "defines.json"}']]
    for index, args in enumerate(commands):
        print(f'QA build stage {index + 1}; logs stay in private run directory', flush=True)
        with (root / f'raw-logs/build-{index}.log').open('w') as log:
            subprocess.run(args, cwd=source, stdout=log, stderr=log, check=True)
    app = source / 'build/ios/iphonesimulator/Runner.app'
    for bundle, entitlements in [(p, source / 'ios/BeeCountWidgetExtension.entitlements')
                                 for p in (app / 'PlugIns').glob('*.appex')] + [
                                     (app, source / 'ios/Runner/Runner.entitlements')]:
        subprocess.run(['codesign', '--force', '--sign', '-', '--entitlements', str(entitlements), str(bundle)],
                       capture_output=True, check=True)
    verify_artifact(root, manifest)
    print('QA artifact identities and signed entitlements verified', flush=True)


def backup_app(root, manifest):
    device(manifest)
    subprocess.run(['xcrun', 'simctl', 'terminate', manifest['udid'], APP_ID], capture_output=True)
    containers = [('data', 'data'), ('groups', GROUP_ID)]
    had_data = False
    for kind, container in containers:
        result = subprocess.run(['xcrun', 'simctl', 'get_app_container', manifest['udid'], APP_ID, container],
                                capture_output=True, text=True)
        if result.returncode:
            if kind == 'data':
                # Fresh device, no app data yet. Existing app query must also say it is absent.
                raw = subprocess.check_output(['xcrun', 'simctl', 'listapps', manifest['udid']])
                converted = subprocess.run(['plutil', '-convert', 'json', '-o', '-', '-'],
                                           input=raw, capture_output=True, check=True)
                apps = json.loads(converted.stdout)
                if APP_ID in apps:
                    raise ValueError('Cannot back up existing QA application')
            elif had_data:
                raise ValueError('Cannot back up the installed QA App Group')
            continue
        if kind == 'data':
            had_data = True
        source = Path(result.stdout.strip())
        dest = root / 'private-backups' / f'{kind}-{time.time_ns()}'
        shutil.copytree(source, dest)


def run(root, manifest, flutter):
    owned_device = device(manifest)
    app = verify_artifact(root, manifest)
    if owned_device['state'] != 'Booted':
        subprocess.run(['xcrun', 'simctl', 'boot', manifest['udid']], check=True)
    subprocess.run(['xcrun', 'simctl', 'bootstatus', manifest['udid'], '-b'], check=True)
    backup_app(root, manifest)
    env = dict(os.environ, QA_EVIDENCE_DIR=str(root / 'evidence'))
    args = [flutter, 'drive', '-d', manifest['udid'], '--use-application-binary', str(app),
            '--driver', 'test_driver/transaction_copy_live_test.dart',
            '--target', 'integration_test/transaction_copy_live_test.dart', '--keep-app-running']
    print('Running UI and live Cloud acceptance on the owned QA simulator', flush=True)
    with (root / 'raw-logs/drive.log').open('w') as log:
        result = subprocess.run(args, cwd=root / 'app-source', env=env, stdout=log, stderr=log)
    manifest['drive_exit_code'] = result.returncode
    write_json(root / 'manifest.json', manifest)
    backup_app(root, manifest)
    if result.returncode:
        raise RuntimeError(f'Acceptance failed; QA data and private logs preserved in {root}')
    db_path = inside(root, root / 'cloud-data/beecount.db')
    with sqlite3.connect(f'file:{db_path}?mode=ro', uri=True) as db:
        db.row_factory = sqlite3.Row
        rows = [dict(r) for r in db.execute('SELECT sync_id, tx_type, amount, note, category_sync_id, '
                                           'account_sync_id, from_account_sync_id, to_account_sync_id, '
                                           'exclude_from_stats, exclude_from_budget, currency_code, native_amount, '
                                           'created_by_user_id, tag_sync_ids_json, attachments_json '
                                           'FROM read_tx_projection ORDER BY sync_id')]
        migration = db.execute('SELECT version_num FROM alembic_version').fetchone()[0]
    write_json(root / 'evidence/cloud-projection.json', dict(migration=migration, transactions=rows))
    public = {k: manifest[k] for k in ('run_id', 'app_id', 'app_sha', 'cloud_sha', 'runtime', 'udid',
                                      'cloud_origin', 'source_hash', 'artifact_hash', 'verified_bundles', 'drive_exit_code')}
    public.update(tool_versions=manifest.get('tool_versions'), skill_sha=manifest.get('skill_sha'))
    write_json(root / 'evidence/environment.json', public)
    print(f'Acceptance passed; evidence: {root / "evidence"}', flush=True)


def stop(root, manifest):
    pid = manifest.get('cloud_pid')
    if pid:
        current = subprocess.run(['ps', '-p', str(pid), '-o', 'lstart='], capture_output=True, text=True)
        if current.returncode == 0:
            if current.stdout.strip() != manifest['cloud_process_start']:
                raise ValueError('Cloud PID has been reused; refusing to signal')
            args = command(['ps', '-p', str(pid), '-o', 'args='])
            if 'uvicorn qa_server:app' not in args:
                raise ValueError('Cloud process command no longer matches')
            os.kill(pid, signal.SIGTERM)
    if manifest.get('udid') and device(manifest)['state'] == 'Booted':
        subprocess.run(['xcrun', 'simctl', 'shutdown', manifest['udid']], check=True)
    manifest['stopped'] = True
    write_json(root / 'manifest.json', manifest)
    print('Owned QA Cloud and simulator stopped; data and evidence retained', flush=True)


def restart_check(root, manifest, flutter):
    """Launch a normal app entry after integration and check actual sandbox persistence."""
    device(manifest)
    source = inside(root, root / 'app-source')
    with (root / 'raw-logs/normal-build.log').open('w') as log:
        subprocess.run([flutter, 'build', 'ios', '--debug', '--simulator', '--target', 'lib/main.dart'],
                       cwd=source, stdout=log, stderr=log, check=True)
    app = source / 'build/ios/iphonesimulator/Runner.app'
    for bundle, entitlements in [(p, source / 'ios/BeeCountWidgetExtension.entitlements')
                                 for p in (app / 'PlugIns').glob('*.appex')] + [
                                     (app, source / 'ios/Runner/Runner.entitlements')]:
        subprocess.run(['codesign', '--force', '--sign', '-', '--entitlements', str(entitlements), str(bundle)],
                       capture_output=True, check=True)
    verify_artifact(root, manifest)
    manifest['normal_artifact_hash'] = manifest['artifact_hash']
    backup_app(root, manifest)
    subprocess.run(['xcrun', 'simctl', 'install', manifest['udid'], str(app)], check=True)
    launched = command(['xcrun', 'simctl', 'launch', manifest['udid'], APP_ID])
    if not launched.startswith(APP_ID + ': '):
        raise ValueError('Unexpected QA App launch identity')
    pid = int(launched.rsplit(': ', 1)[1])
    time.sleep(15)
    process = command(['ps', '-p', str(pid), '-o', 'comm='])
    if 'Runner.app/Runner' not in process:
        raise ValueError('Normal QA application is no longer running')
    manifest['normal_launch_pid'] = pid
    write_json(root / 'manifest.json', manifest)
    subprocess.run(['xcrun', 'simctl', 'io', manifest['udid'], 'screenshot',
                    str(root / 'evidence/06-normal-app-restart.png')], check=True)
    container = Path(command(['xcrun', 'simctl', 'get_app_container', manifest['udid'], APP_ID, 'data']))
    app_db = container / 'Documents/beecount.sqlite'
    with sqlite3.connect(f'file:{app_db}?mode=ro', uri=True) as db:
        rows = [dict(sync_id=r[0], note=r[1], amount=r[2]) for r in db.execute(
            'SELECT sync_id, note, amount FROM transactions ORDER BY sync_id')]
    report = json.loads((root / 'evidence/acceptance.json').read_text())
    copy = next(r for r in rows if r['sync_id'] == report['copy_sync_id'])
    if copy['note'] != 'QA Cloud 修改后' or copy['amount'] != 55.5:
        raise ValueError('Normal App restart did not retain the synchronized copy')
    report['cases'].append(dict(id='T10-restart', status='PASS', detail='Normal lib/main.dart entry retains QA transactions after reinstall/launch'))
    write_json(root / 'evidence/acceptance.json', report)
    write_json(root / 'evidence/restart-persistence.json', rows)
    environment = json.loads((root / 'evidence/environment.json').read_text())
    environment.update(normal_artifact_hash=manifest['normal_artifact_hash'], normal_launch_alive=True)
    write_json(root / 'evidence/environment.json', environment)
    backup_app(root, manifest)
    print('Normal QA App launch and persistent sandbox data verified', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'build', 'preflight', 'run', 'restart-check', 'stop'))
    parser.add_argument('--run')
    parser.add_argument('--cloud-repo')
    parser.add_argument('--cloud-ref', default='origin/main')
    parser.add_argument('--skill-repo', help='Record the skill repository HEAD used for this run')
    parser.add_argument('--runtime', default='com.apple.CoreSimulator.SimRuntime.iOS-26-5')
    parser.add_argument('--flutter', default=shutil.which('flutter'))
    args = parser.parse_args()
    if args.action == 'prepare':
        if not args.cloud_repo:
            parser.error('prepare requires --cloud-repo')
        prepare(args)
    else:
        if not args.run:
            parser.error('action requires --run')
        root, manifest = load_run(args.run)
        if args.action == 'build':
            build(root, manifest, args.flutter)
        elif args.action == 'preflight':
            device(manifest)
            verify_artifact(root, manifest)
            print('QA preflight passed')
        elif args.action == 'run':
            run(root, manifest, args.flutter)
        elif args.action == 'restart-check':
            restart_check(root, manifest, args.flutter)
        else:
            stop(root, manifest)


if __name__ == '__main__':
    main()
