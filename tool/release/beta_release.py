#!/usr/bin/env python3
"""Manually dispatched Beta CI. Secrets stay in env/private files, never argv.

Only plan reads GitHub. Build uses the existing audited APK wrapper. Publish
creates a draft after all artifact checks and never replaces an existing tag.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request

import local_apk as gate
from android_version_code import parse_version, validate_candidate, validate_recorded_version

REPOSITORY = "TNT-Likely/BeeCount"
FEEDBACK = "https://github.com/TNT-Likely/BeeCount/issues/580"
LOCAL_DELIVERED_FLOOR = 226  # 已实际交付 4.0.0-beta.1；不是由 Beta 序号推算。
PRODUCTION_CERTIFICATE = "0db081285aca34ec4a93137999524c2a3d05f58c5d9ed9899952c6669dab1e9f"
RECEIPT = "android-release.json"
RESERVATION = "android-version-reservation.json"


class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        gate.require(urllib.parse.urlsplit(newurl).scheme == "https", "拒绝降级到非 HTTPS 下载")
        redirected = super().redirect_request(req, fp, code, msg, headers, newurl)
        if redirected and urllib.parse.urlsplit(req.full_url).netloc != urllib.parse.urlsplit(newurl).netloc:
            redirected.remove_header("Authorization")
        return redirected


def open_url(request, timeout):
    return urllib.request.build_opener(SafeRedirect()).open(request, timeout=timeout)


class GitHub:
    def __init__(self):
        self.token = os.environ.get("GH_TOKEN", "")
        gate.require(bool(self.token), "缺少 GitHub 发布凭据")

    def request(self, method, path, data=None, *, raw=False, content_type="application/json"):
        # URLs never come from release bodies, workflow inputs or credential data.
        gate.require(path.startswith("/repos/" + REPOSITORY + "/"), "GitHub 路径不属于目标仓库")
        host = "https://uploads.github.com" if "/assets?" in path else "https://api.github.com"
        payload = data if raw else (None if data is None else json.dumps(data).encode())
        request = urllib.request.Request(host + path, data=payload, method=method, headers={
            "Authorization": "Bearer " + self.token, "Accept": "application/vnd.github+json",
            "Content-Type": content_type, "X-GitHub-Api-Version": "2022-11-28"})
        try:
            with open_url(request, timeout=120) as response:
                content = response.read(256 * 1024 * 1024)
        except urllib.error.HTTPError as error:
            raise gate.GateError(f"GitHub 请求失败（HTTP {error.code}），未输出响应或凭据") from None
        except (OSError, urllib.error.URLError):
            raise gate.GateError("GitHub 请求失败，未输出请求或凭据") from None
        return content if raw else (json.loads(content) if content else None)

    def releases(self):
        result = []
        for page in range(1, 101):
            items = self.request("GET", f"/repos/{REPOSITORY}/releases?per_page=100&page={page}")
            gate.require(isinstance(items, list), "Release 列表无效")
            result.extend(items)
            if len(items) < 100:
                return result
        raise gate.GateError("Release 列表超过安全分页上限")

    def receipt(self, asset):
        # GitHub asset API requires octet-stream to return the uploaded bytes.
        path = f"/repos/{REPOSITORY}/releases/assets/{int(asset['id'])}"
        request = urllib.request.Request("https://api.github.com" + path, headers={
            "Authorization": "Bearer " + self.token, "Accept": "application/octet-stream",
            "X-GitHub-Api-Version": "2022-11-28"})
        try:
            with open_url(request, timeout=30) as response:
                content = response.read(128 * 1024 + 1)
            gate.require(len(content) <= 128 * 1024, "版本回执超过安全上限")
            return json.loads(content)
        except gate.GateError:
            raise
        except Exception:
            raise gate.GateError("无法读取版本回执；拒绝忽略水位") from None

    def upload(self, release_id, name, content, content_type="application/json"):
        path = f"/repos/{REPOSITORY}/releases/{int(release_id)}/assets?name=" + urllib.parse.quote(name, safe="")
        return self.request("POST", path, content, raw=True, content_type=content_type)


def source_sha(value: str, repo: Path) -> str:
    gate.require(value == "v4" or re.fullmatch(r"[0-9a-f]{40}", value), "源码只接受 v4 或完整提交 SHA")
    def git(*args):
        result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)
        gate.require(result.returncode == 0, "无法核对 v4 源码身份")
        return result.stdout.strip()
    remote = git("remote", "get-url", "origin")
    gate.require(re.fullmatch(r"(?:git@github.com:|https://github.com/)TNT-Likely/BeeCount(?:\.git)?", remote, re.I),
                 "源码仓库身份错误")
    sha = git("rev-parse", "--verify", ("refs/remotes/origin/v4" if value == "v4" else value) + "^{commit}")
    gate.require(re.fullmatch(r"[0-9a-f]{40}", sha), "无法冻结完整源码 SHA")
    git("merge-base", "--is-ancestor", sha, "refs/remotes/origin/v4")
    return sha


def release_floor(client, releases, explicit_floor, version):
    gate.require(re.fullmatch(r"[0-9]+", explicit_floor or ""), "必须提供全渠道最高已交付 code")
    floor = max(int(explicit_floor), LOCAL_DELIVERED_FLOOR)
    minimum_version = parse_version("4.0.0-beta.1")
    for release in releases:
        # Even a legacy Release without a machine receipt must prevent a
        # version-name downgrade. Its code still belongs in the required,
        # externally verified all-channel floor supplied by the operator.
        try:
            tagged = parse_version(release.get("tag_name", ""))
            if not release.get("draft") and tagged.order > minimum_version.order:
                minimum_version = tagged
        except ValueError:
            pass
        for asset in release.get("assets", []):
            if asset.get("name") not in {RECEIPT, RESERVATION}:
                continue
            record = client.receipt(asset)
            gate.require(record.get("package") == gate.PACKAGE and record.get("schemaVersion") == 1,
                         "版本回执身份无效")
            recorded = validate_recorded_version(record["versionName"], record["versionCode"])
            gate.require(release["tag_name"].removeprefix("v") == recorded.name, "Release 与版本回执不一致")
            floor = max(floor, recorded.code)
            if recorded.order > minimum_version.order:
                minimum_version = recorded
    candidate = validate_candidate(version, minimum_code=floor, minimum_version=minimum_version.name)
    gate.require(candidate.beta is not None, "Beta workflow 拒绝正式版")
    return candidate, floor


def context_path():
    return Path(os.environ["BETA_CONTEXT"])


def read_context():
    path = context_path()
    gate.private_file(path)
    return json.loads(path.read_text())


def save_context(value):
    gate.write_json(context_path(), value)


def signing_inputs():
    secrets = {name: os.environ.get(name, "") for name in (
        "ANDROID_KEYSTORE_BASE64", "ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD")}
    gate.require(all(secrets.values()), "正式签名四项 secrets 必须齐全，拒绝 debug fallback")
    gate.require(secrets["ANDROID_KEY_ALIAS"].lower() != "androiddebugkey", "拒绝 debug 签名 alias")
    try:
        decoded = base64.b64decode("".join(secrets["ANDROID_KEYSTORE_BASE64"].split()), validate=True)
    except ValueError:
        raise gate.GateError("keystore base64 无效") from None
    gate.require(0 < len(decoded) <= 10 * 1024 * 1024, "keystore 大小无效")
    return secrets, decoded


def credentials():
    signing_inputs()
    print("签名输入齐全；实际私钥与生产证书仍须在构建前核验")


def plan():
    gate.require(os.environ.get("GITHUB_REPOSITORY") == REPOSITORY and
                 os.environ.get("GITHUB_EVENT_NAME") == "workflow_dispatch", "仅允许目标仓库手动运行")
    repo = Path.cwd()
    sha = source_sha(os.environ.get("BETA_SOURCE_REF", ""), repo)
    certificate = gate.certificate_digest(os.environ.get("BETA_EXPECTED_CERTIFICATE", ""))
    gate.require(certificate == PRODUCTION_CERTIFICATE, "预期指纹不是已核生产签名；须先审核证书轮换")
    client = GitHub()
    releases = client.releases()
    version, floor = release_floor(client, releases, os.environ.get("BETA_CHANNEL_FLOOR", ""),
                                   os.environ.get("BETA_VERSION", ""))
    tag = version.name
    gate.require(not any(r.get("tag_name", "").removeprefix("v") == tag for r in releases),
                 "同版本 Release 已存在（包括失败草稿），禁止覆盖")
    for tag_name in [tag, "v" + tag]:
        tags = subprocess.run(["git", "show-ref", "--verify", "--quiet", "refs/tags/" + tag_name])
        gate.require(tags.returncode == 1, "同名 tag 已存在或无法检查，禁止覆盖")
    notes = subprocess.run(["git", "show", sha + ":docs/releases/" + tag + ".md"], capture_output=True, text=True)
    gate.require(notes.returncode == 0 and len(notes.stdout.strip()) >= 80,
                 "冻结源码缺少完整 Beta 发布说明")
    gate.require(FEEDBACK in notes.stdout, "发布说明缺少固定反馈 issue")
    gate.require(not context_path().exists(), "本轮发布上下文已存在，禁止覆盖")
    gate.write_private(context_path(), b"{}")
    save_context({"sourceSha": sha, "versionName": tag, "versionCode": version.code, "floor": floor,
                  "certificateSha256": certificate, "notes": notes.stdout,
                  "repository": REPOSITORY, "status": "planned"})
    print(f"已冻结 {tag}+{version.code} / {sha}，尚未构建或发布")


def build():
    context = read_context()
    gate.require(context["status"] == "planned", "发布状态不是 planned")
    secrets, decoded = signing_inputs()
    run_parent = Path(tempfile.mkdtemp(prefix="beecount-beta-build-", dir=os.environ["RUNNER_TEMP"]))
    run_parent.chmod(0o700)
    signing = run_parent / "signing-inputs"
    signing.mkdir(mode=0o700)
    context["runParent"] = str(run_parent)
    save_context(context)
    try:
        store = signing / "production.keystore"
        gate.write_private(store, decoded)
        credentials = signing / "credentials.json"
        gate.write_private(credentials, json.dumps({"storeFile": str(store),
            "storePassword": secrets["ANDROID_KEYSTORE_PASSWORD"], "keyAlias": secrets["ANDROID_KEY_ALIAS"],
            "keyPassword": secrets["ANDROID_KEY_PASSWORD"]}).encode())
        registry = run_parent / "ci-local-delivery.jsonl"
        gate.init_registry(registry)  # Runner has no local deliveries; external floor remains mandatory.
        flutter = shutil.which("flutter")
        gate.require(flutter is not None, "Flutter 缺失")
        result = gate.prepare_or_build(argparse.Namespace(
            repo=Path.cwd(), source_sha=context["sourceSha"], version=context["versionName"],
            minimum_code=context["floor"], expected_certificate=context["certificateSha256"],
            registry=registry, credentials_file=credentials, flutter=Path(flutter),
            java_home=Path(os.environ["JAVA_HOME"]),
            sdk_root=Path(os.environ.get("ANDROID_SDK_ROOT") or os.environ["ANDROID_HOME"]),
            build_tools="36.0.0", run_parent=run_parent, execute=True,
            arm64_only=True, allow_pub_network=True))
        manifest = json.loads((result / "manifest.json").read_text())
        gate.require(manifest["status"] == "artifact-verified-awaiting-functional-qa" and
                     manifest["versionCode"] == context["versionCode"], "构建未通过既有 APK 门禁")
        context.update(status="verified", manifest=str(result / "manifest.json"))
        save_context(context)
    finally:
        shutil.rmtree(signing)


def publish():
    context = read_context()
    gate.require(context["status"] == "verified", "未经签名与产物验证，拒绝发布")
    client = GitHub()
    releases = client.releases()
    gate.require(not any(r.get("tag_name", "").removeprefix("v") == context["versionName"] for r in releases),
                 "同版本 Release 已存在，禁止覆盖")
    candidate, _ = release_floor(client, releases, str(context["floor"]), context["versionName"])
    gate.require(candidate.code == context["versionCode"], "构建期间水位提高，须重新构建新 code")
    manifest_path = Path(context["manifest"])
    manifest = json.loads(manifest_path.read_text())
    apk = manifest_path.parent / manifest["artifactRelativePath"]
    verification_dir = Path(tempfile.mkdtemp(prefix="publish-verify-", dir=context["runParent"]))
    runner = gate.Runner(verification_dir, gate.clean_environment(Path(manifest["javaHome"]), Path(manifest["toolsPath"]).parents[1]))
    verified = gate.verify_apk(apk, expected_version=context["versionName"], expected_code=context["versionCode"],
        expected_certificate=context["certificateSha256"], tools=Path(manifest["toolsPath"]), runner=runner)
    gate.require(verified == manifest["artifact"], "发布前产物身份改变")
    receipt = {"schemaVersion": 1, "kind": "beecount-beta-release", "package": gate.PACKAGE,
        "sourceSha": context["sourceSha"], "versionName": context["versionName"],
        "versionCode": context["versionCode"], "apkSha256": verified["apkSha256"],
        "certificateSha256": context["certificateSha256"], "abi": gate.ABI,
        "functionalAcceptance": "静态构建门禁通过；Beta 用户继续验证实际功能",
        "workflowRun": os.environ["GITHUB_RUN_ID"]}
    body = (context["notes"].rstrip() + "\n\n## 构建身份\n\n"
        + f"- 源码：`{context['sourceSha']}`\n- Android：`{context['versionName']}+{context['versionCode']}`\n"
        + f"- ARM64 APK SHA-256：`{verified['apkSha256']}`\n"
        + f"- [本次构建](https://github.com/{REPOSITORY}/actions/runs/{os.environ['GITHUB_RUN_ID']})\n")
    # Atomic create refuses an existing remote tag, including one created
    # after plan. Never retarget a tag through Release's target_commitish.
    client.request("POST", f"/repos/{REPOSITORY}/git/refs", {
        "ref": "refs/tags/" + context["versionName"], "sha": context["sourceSha"]})
    release = client.request("POST", f"/repos/{REPOSITORY}/releases", {
        "tag_name": context["versionName"], "target_commitish": context["sourceSha"],
        "name": "蜜蜂记账 " + context["versionName"], "body": body,
        "draft": True, "prerelease": True, "make_latest": "false"})
    context.update(status="draft-created", releaseId=release["id"], releaseUrl=release["html_url"])
    save_context(context)
    # Store the floor BEFORE exposing an APK. An interrupted draft keeps this
    # reservation, so future runs cannot reuse the code or overwrite this tag.
    payload = json.dumps(receipt, ensure_ascii=False, indent=2).encode()
    client.upload(release["id"], RESERVATION, payload)
    client.upload(release["id"], apk.name, apk.read_bytes(), "application/vnd.android.package-archive")
    client.upload(release["id"], apk.name + ".sha256", (verified["apkSha256"] + "  " + apk.name + "\n").encode(), "text/plain")
    client.upload(release["id"], RECEIPT, payload)
    remote_tag = client.request("GET", f"/repos/{REPOSITORY}/git/ref/tags/{context['versionName']}")
    gate.require(remote_tag.get("object", {}).get("sha") == context["sourceSha"], "发布前 tag 源码已改变")
    published = client.request("PATCH", f"/repos/{REPOSITORY}/releases/{release['id']}",
                               {"draft": False, "prerelease": True, "make_latest": "false"})
    context.update(status="published", releaseUrl=published["html_url"])
    save_context(context)
    print("已发布 Beta：" + context["releaseUrl"])
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as out:
            out.write(f"### Beta 已发布\n\n[{context['versionName']}+{context['versionCode']}]({context['releaseUrl']})\n\n[反馈]({FEEDBACK})\n")


def notify():
    context = read_context()
    gate.require(context["status"] == "published", "仅成功发布后通知 Telegram")
    token, chat = os.environ.get("TELEGRAM_BOT_TOKEN", ""), os.environ.get("TELEGRAM_CHAT_ID", "")
    gate.require(bool(token and chat), "Beta 已发布，但 Telegram secrets 缺失，尚未通知")
    gate.require(re.fullmatch(r"[0-9]+:[A-Za-z0-9_-]+", token), "Telegram token 格式无效")
    text = (f"蜜蜂记账 {context['versionName']}（Android {context['versionCode']}）已发布\n"
            f"正式签名 ARM64 APK：{context['releaseUrl']}\n反馈：{FEEDBACK}")
    payload = urllib.parse.urlencode({"chat_id": chat, "text": text, "disable_web_page_preview": "true"}).encode()
    try:
        request = urllib.request.Request("https://api.telegram.org/bot" + token + "/sendMessage", data=payload, method="POST")
        with open_url(request, timeout=30) as response:
            result = json.loads(response.read(128 * 1024))
        gate.require(result.get("ok") is True, "Beta 已发布，但 Telegram 未确认送达")
    except gate.GateError:
        raise
    except Exception:
        raise gate.GateError("Beta 已发布，但 Telegram 通知失败；凭据未输出") from None
    print("Telegram 已确认送达")


def cleanup():
    if not context_path().exists():
        return
    context = read_context()
    if context.get("runParent"):
        parent = Path(context["runParent"])
        gate.require(parent.parent == Path(os.environ["RUNNER_TEMP"]) and parent.name.startswith("beecount-beta-build-"),
                     "清理目录不属于本轮 Beta")
        for path in parent.rglob("*"):
            if path.name in {"credentials.json", "production.keystore", "signing.keystore", "signing.properties", "key.properties"}:
                gate.require(not path.is_symlink(), "拒绝清理符号链接")
                path.unlink(missing_ok=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["credentials", "plan", "build", "publish", "notify", "cleanup"])
    args = parser.parse_args(argv)
    try:
        globals()[args.action]()
        return 0
    except (gate.GateError, ValueError) as error:
        print("Beta 门禁拒绝：" + str(error), file=sys.stderr)
    except Exception:
        print("Beta 操作失败，未输出可能含私有材料的异常；请检查执行阶段。", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
