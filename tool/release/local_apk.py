#!/usr/bin/env python3
"""BeeCount 本地 APK 门禁；默认只准备，--execute 才调用 Flutter。"""

from __future__ import annotations

import argparse
import datetime as dt
import difflib
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import zipfile

from android_version_code import MAX_VERSION_CODE, parse_version, validate_candidate, validate_recorded_version

PACKAGE = "com.tntlikely.beecount"
ABI = "arm64-v8a"
REGISTRY_HEADER = {"kind": "beecount-delivered-apk-registry", "schemaVersion": 1}
GALLERY = "lib/presentation/v4/gallery"
GALLERY_ENTRY = GALLERY + "/component_gallery_page.dart"
GENERATED_REGISTRANT = "android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java"
GALLERY_IMPORTERS = {
    "lib/pages/main/home_page.dart",
    "lib/presentation/v4/bindings/support_about_controls.dart",
}
CREDENTIAL_ENV = {
    "storeFile": "BEECOUNT_APK_STORE_FILE",
    "storePassword": "BEECOUNT_APK_STORE_PASSWORD",
    "keyAlias": "BEECOUNT_APK_KEY_ALIAS",
    "keyPassword": "BEECOUNT_APK_KEY_PASSWORD",
}
FALLBACK_MARKERS = (
    "[signing] generating ci debug", "[signing] failed to generate",
    "[signing] no keystore", "release apk will be unsigned",
)


class GateError(Exception):
    """Only non-sensitive, deliberately written messages cross this boundary."""


def require(condition, message):
    if not condition:
        raise GateError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical(value) -> bytes:
    return json.dumps(value, sort_keys=True, ensure_ascii=True, separators=(",", ":")).encode()


def write_private(path: Path, value: bytes):
    with path.open("xb") as file:
        os.fchmod(file.fileno(), 0o600)
        file.write(value)


def write_json(path: Path, value):
    # The caller constructs a public-only manifest, never vars(args) or credentials.
    path.write_bytes(json.dumps(value, ensure_ascii=False, indent=2).encode())
    path.chmod(0o600)


def private_file(path: Path):
    require(not path.is_symlink(), "私有材料不能是符号链接")
    try:
        info = path.stat()
    except OSError:
        raise GateError("所需私有材料缺失或不可读") from None
    require(stat.S_ISREG(info.st_mode), "私有材料必须为普通文件")
    require(info.st_uid == os.getuid() and info.st_mode & 0o077 == 0,
            "私有材料必须属于当前用户，且禁止组/其他用户访问")


def certificate_digest(value: str) -> str:
    digest = value.lower().replace(":", "").strip()
    require(re.fullmatch(r"[0-9a-f]{64}", digest), "必须显式提供可信线上证书 SHA256")
    return digest


def java_property(value: str) -> str:
    """Escape ISO-8859-1 Properties using UTF-16 code units for Unicode."""
    escaped = []
    utf16 = value.encode("utf-16-be")
    for byte_pair in [utf16[i:i + 2] for i in range(0, len(utf16), 2)]:
        code = int.from_bytes(byte_pair, "big")
        char = chr(code)
        if char in "\\ =:#!":
            escaped.append("\\" + char)
        elif char in "\n\r\t\f":
            escaped.append({"\n": r"\n", "\r": r"\r", "\t": r"\t", "\f": r"\f"}[char])
        elif 0x20 <= code <= 0x7e:
            escaped.append(char)
        else:
            escaped.append("\\u%04x" % code)
    return "".join(escaped)


def properties_bytes(credentials: dict[str, str]) -> bytes:
    require(set(credentials) == set(CREDENTIAL_ENV), "签名配置四字段必须完整且没有额外字段")
    return ("\n".join(key + "=" + java_property(credentials[key]) for key in CREDENTIAL_ENV) + "\n").encode("ascii")


def load_credentials(path: Path | None, environment: dict[str, str]) -> dict[str, str]:
    if path is not None:
        private_file(path)
        try:
            value = json.loads(path.read_text())
        except (ValueError, UnicodeError):
            raise GateError("签名私有 JSON 无效") from None
    else:
        value = {key: environment.get(env) for key, env in CREDENTIAL_ENV.items()}
    require(isinstance(value, dict) and set(value) == set(CREDENTIAL_ENV), "必须提供全部签名字段")
    require(all(isinstance(item, str) and item and "\0" not in item for item in value.values()),
            "签名字段缺失或无效；拒绝调用 Flutter")
    require(value["keyAlias"].lower() != "androiddebugkey", "拒绝 debug alias")
    store = Path(value["storeFile"]).expanduser()
    private_file(store)
    require(store.name.lower() not in {"debug.keystore", "ci-debug.keystore"}, "拒绝 debug keystore")
    value["storeFile"] = str(store.resolve())
    return value


def clean_environment(java_home: Path, sdk: Path) -> dict[str, str]:
    # Do not pass host tokens, passwords, QA flags, JAVA_TOOL_OPTIONS or DART_DEFINES.
    keep = {"PATH", "HOME", "TMPDIR", "LANG", "LC_ALL", "LC_CTYPE", "PUB_CACHE", "GRADLE_USER_HOME"}
    result = {key: value for key, value in os.environ.items() if key in keep}
    result.update(JAVA_HOME=str(java_home), ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk))
    result.update(CI="true", FLUTTER_SUPPRESS_ANALYTICS="true", DART_SUPPRESS_ANALYTICS="true")
    result["PATH"] = str(java_home / "bin") + os.pathsep + result.get("PATH", "")
    return result


class Runner:
    def __init__(self, root: Path, environment: dict[str, str]):
        self.logs = root / "logs"
        self.logs.mkdir(mode=0o700)
        self.environment = environment
        self.commands = []

    def run(self, arguments, *, label, cwd=None) -> str:
        # Never shell=True. Arguments contain only public options/paths, never passwords.
        completed = subprocess.run([str(item) for item in arguments], cwd=cwd,
                                   env=self.environment, capture_output=True)
        log = self.logs / (label + ".log")
        write_private(log, completed.stdout + b"\n" + completed.stderr)
        self.commands.append({"label": label, "exitCode": completed.returncode})
        require(completed.returncode == 0, "本地命令失败：" + label + "（详见私有日志）")
        return completed.stdout.decode("utf-8", errors="replace")


def _registry_lines(content: bytes):
    require(content.endswith(b"\n"), "交付 registry 截断或未正确结束")
    try:
        lines = [json.loads(line) for line in content.splitlines()]
    except (ValueError, UnicodeError):
        raise GateError("交付 registry 无效") from None
    require(lines and lines[0] == REGISTRY_HEADER, "交付 registry 缺少正确头部")
    previous = hashlib.sha256(canonical(lines[0])).hexdigest()
    highest = 0
    previous_version = None
    fields = {"sequence", "deliveredAtUtc", "versionName", "versionCode", "sourceSha", "apkSha256",
              "certificateSha256", "abi", "package", "acceptanceReportSha256", "previousEntrySha256", "entrySha256"}
    for sequence, entry in enumerate(lines[1:], 1):
        require(isinstance(entry, dict) and set(entry) == fields, "交付 registry 字段无效")
        require(type(entry["sequence"]) is int and entry["sequence"] == sequence and entry["previousEntrySha256"] == previous,
                "交付 registry 链被改写")
        body = {key: value for key, value in entry.items() if key != "entrySha256"}
        require(hashlib.sha256(canonical(body)).hexdigest() == entry["entrySha256"], "交付 registry 校验失败")
        try:
            version = validate_recorded_version(entry["versionName"], entry["versionCode"])
        except ValueError:
            raise GateError("交付 registry 版本名或码号无效") from None
        require(version.code > highest, "交付 registry 存在复用或回退码号")
        require(previous_version is None or version.order >= previous_version.order,
                "交付 registry 版本名回退")
        previous_version = version
        require(entry["package"] == PACKAGE and entry["abi"] == ABI, "交付 registry 身份无效")
        require(re.fullmatch(r"[0-9a-f]{40}", entry["sourceSha"]), "交付 registry 源码身份无效")
        for key in ("apkSha256", "certificateSha256", "acceptanceReportSha256"):
            require(re.fullmatch(r"[0-9a-f]{64}", entry[key]), "交付 registry 摘要无效")
        require(re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?\+00:00", entry["deliveredAtUtc"]),
                "交付 registry 时间无效")
        highest = entry["versionCode"]
        previous = entry["entrySha256"]
    return lines, highest, previous


def init_registry(path: Path):
    require(path.parent.is_dir(), "registry 父目录必须先创建")
    require(not registry_head(path).exists(), "registry 水位凭据已存在，禁止重置历史")
    content = canonical(REGISTRY_HEADER) + b"\n"
    write_private(path, content)
    update_registry_head(path, content)


def registry_head(path):
    return path.with_name(path.name + ".head.json")


def registry_state(content):
    lines, maximum, previous = _registry_lines(content)
    return {"maximumCode": maximum, "entryCount": len(lines) - 1,
            "contentSha256": hashlib.sha256(content).hexdigest(), "lastEntrySha256": previous}


def update_registry_head(path, content):
    # Separate high-water receipt detects loss of an otherwise valid complete tail.
    descriptor, temporary = tempfile.mkstemp(prefix=".apk-registry-head-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as file:
            os.fchmod(file.fileno(), 0o600)
            file.write(canonical(registry_state(content)))
            file.flush()
            os.fsync(file.fileno())
        os.replace(temporary, registry_head(path))
    finally:
        Path(temporary).unlink(missing_ok=True)


def verify_registry_head(path, content):
    head = registry_head(path)
    private_file(head)
    require(json.loads(head.read_text()) == registry_state(content), "registry 与历史水位凭据不同；拒绝截断或重置")


def registry_snapshot(path: Path):
    private_file(path)
    with path.open("rb") as file:
        fcntl.flock(file, fcntl.LOCK_SH)
        content = file.read()
        verify_registry_head(path, content)
    state = registry_state(content)
    lines, _, _ = _registry_lines(content)
    state["latestVersionName"] = lines[-1]["versionName"] if len(lines) > 1 else None
    return state


def append_delivery(path: Path, fields: dict):
    private_file(path)
    # O_APPEND + advisory lock: concurrent cooperating writers cannot replace old entries.
    descriptor = os.open(path, os.O_RDWR | os.O_APPEND | os.O_NOFOLLOW)
    with os.fdopen(descriptor, "r+b") as file:
        fcntl.flock(file, fcntl.LOCK_EX)
        original = file.read()
        verify_registry_head(path, original)
        lines, maximum, previous = _registry_lines(original)
        require(fields["versionCode"] > maximum, "交付码号已存在或被后来的交付超越")
        entry = dict(fields, sequence=len(lines), previousEntrySha256=previous)
        entry["entrySha256"] = hashlib.sha256(canonical(entry)).hexdigest()
        # Validate the complete prospective chain before a single append.
        _registry_lines(b"\n".join(canonical(line) for line in [*lines, entry]) + b"\n")
        appended = canonical(entry) + b"\n"
        file.write(appended)
        file.flush()
        os.fsync(file.fileno())
        update_registry_head(path, original + appended)
        return entry


def verify_signing(credentials, expected, java_home, runner, run):
    private = dict(credentials)
    key_copy = run / "signing.keystore"
    properties = run / "signing.properties"
    shutil.copyfile(credentials["storeFile"], key_copy)
    key_copy.chmod(0o600)
    private["storeFile"] = str(key_copy)
    write_private(properties, properties_bytes(private))
    classes = run / "signing-probe"
    classes.mkdir(mode=0o700)
    runner.run([java_home / "bin/javac", "-d", classes, Path(__file__).with_name("KeyStoreProbe.java")], label="compile-signing-probe")
    result = runner.run([java_home / "bin/java", "-cp", classes, "KeyStoreProbe", properties], label="unlock-private-key")
    try:
        result = json.loads(result)
    except ValueError:
        raise GateError("签名预检响应无效") from None
    require(result.get("privateKeyUnlocked") is True and result.get("debugCertificate") is False,
            "签名私钥未成功解锁或属于 debug")
    require(result.get("certificateSha256") == expected, "签名证书与可信线上证书不同；拒绝调用 Flutter")
    return properties


def extract_archive(archive: Path, destination: Path):
    destination.mkdir(mode=0o700)
    links = []
    with tarfile.open(archive, "r:") as tar:
        total = 0
        for member in tar:
            relative = PurePosixPath(member.name)
            require(not relative.is_absolute() and ".." not in relative.parts and ".git" not in relative.parts,
                    "Git archive 含越界路径")
            require(relative.name not in {".env", ".env.local", "key.properties", "ci-debug.keystore", "debug.keystore"},
                    "冻结提交包含不应继承的本地配置/签名材料")
            target = destination.joinpath(*relative.parts)
            require(target.resolve().is_relative_to(destination.resolve()), "Git archive 路径越界")
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
            elif member.isfile():
                total += member.size
                require(total <= 3_000_000_000, "Git archive 超出本地安全上限")
                target.parent.mkdir(parents=True, exist_ok=True)
                with tar.extractfile(member) as source, target.open("xb") as output:
                    shutil.copyfileobj(source, output)
                target.chmod(0o755 if member.mode & 0o111 else 0o644)
            elif member.issym():
                links.append((target, member.linkname))
            else:
                raise GateError("Git archive 含不支持的链接或特殊文件")
    for target, value in links:
        require(not Path(value).is_absolute() and (target.parent / value).resolve().is_relative_to(destination.resolve()),
                "Git archive 符号链接越界")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.symlink_to(value)


def freeze_source(repo, source_sha, run, runner):
    require(re.fullmatch(r"[0-9a-f]{40}", source_sha), "必须提供冻结的完整40位 Git commit SHA")
    remote = runner.run(["git", "-C", repo, "remote", "get-url", "origin"], label="source-origin").strip()
    require(re.fullmatch(r"(?:git@github.com:|https://github.com/)TNT-Likely/BeeCount(?:\.git)?", remote, re.I),
            "源码仓库 origin 不是预期 BeeCount")
    actual = runner.run(["git", "-C", repo, "rev-parse", "--verify", source_sha + "^{commit}"], label="source-commit").strip()
    require(actual == source_sha, "冻结源码 SHA 不匹配")
    archive = run / "source.tar"
    with archive.open("xb") as file:
        os.fchmod(file.fileno(), 0o600)
        result = subprocess.run(["git", "-C", str(repo), "archive", "--format=tar", source_sha],
                                stdout=file, stderr=subprocess.PIPE, env=runner.environment)
    write_private(runner.logs / "source-archive.log", result.stderr)
    require(result.returncode == 0, "冻结源码归档失败")
    source = run / "source"
    extract_archive(archive, source)
    require((source / "lib/main.dart").is_file() and (source / "pubspec.lock").is_file(), "冻结源码缺少正常入口/锁文件")
    return source, sha256(archive)


def release_overlay(source: Path):
    pubspec = source / "pubspec.yaml"
    original = pubspec.read_text()
    pattern = r"(?m)^\s*-\s*assets/v4_gallery/\s*(?:#[^\n]*)?\n"
    updated, count = re.subn(pattern, "\n", original)
    require(count == 1 and (source / GALLERY_ENTRY).is_file() and (source / "assets/v4_gallery").is_dir(),
            "开发 gallery 布局已变化，须审查发布 overlay")
    for dart in (source / "lib").rglob("*.dart"):
        relative = dart.relative_to(source).as_posix()
        if relative.startswith(GALLERY + "/"):
            continue
        content = dart.read_text()
        require("assets/v4_gallery/" not in content, "生产代码开始使用 gallery 素材，不能自动剔除")
        if re.search(r"(?:import|export)\s+['\"][^'\"]*gallery/", content):
            require(relative in GALLERY_IMPORTERS and "kDebugMode" in content and
                    all(value == "component_gallery_page.dart" for value in re.findall(r"gallery/([^'\"]+)", content)),
                    "发现未审核的 gallery 入口，拒绝自动发布 overlay")
            guards = {
                "lib/pages/main/home_page.dart": r"case\s+'components':\s*if\s*\(kDebugMode\)\s*\{[^}]{0,500}\bComponentGalleryPage\s*\(",
                "lib/presentation/v4/bindings/support_about_controls.dart": r"if\s*\(kDebugMode\)\s*BeeSupportActions\([\s\S]{0,1000}\bComponentGalleryPage\s*\(",
            }
            require(len(re.findall(r"\bComponentGalleryPage\s*\(", content)) == 1 and re.search(guards[relative], content),
                    "gallery 入口不再由已审查的 kDebugMode 分支保护")
    affected = [pubspec, *[p for root in [source / GALLERY, source / "assets/v4_gallery"] for p in root.rglob("*") if p.is_file()]]
    before = {p.relative_to(source).as_posix(): sha256(p) for p in affected}
    shutil.rmtree(source / GALLERY)
    shutil.rmtree(source / "assets/v4_gallery")
    (source / GALLERY).mkdir(parents=True)
    # Both production call sites are kDebugMode-only; remove the sample import graph as well.
    stub = (
        "import 'package:flutter/widgets.dart';\n"
        "class ComponentGalleryPage extends StatelessWidget {\n"
        "  const ComponentGalleryPage({super.key, this.enableLiveData = true});\n"
        "  final bool enableLiveData;\n"
        "  @override Widget build(BuildContext context) =>\n"
        "      throw UnsupportedError('Development gallery omitted from release');\n}\n")
    (source / GALLERY_ENTRY).write_text(stub)
    pubspec.write_text(updated)
    after = {relative: sha256(source / relative) if (source / relative).is_file() else None for relative in before}
    require(GALLERY_ENTRY in after, "gallery overlay 未记录入口")
    return {"reason": "开发验收素材及样例导入图从发布专用副本剔除，生产正常入口不变",
            "changes": [{"path": p, "beforeSha256": before[p], "afterSha256": after[p]} for p in sorted(before)],
            "pubspecDiff": "".join(difflib.unified_diff(original.splitlines(keepends=True), updated.splitlines(keepends=True),
                                                       fromfile="pubspec.yaml", tofile="pubspec.yaml")),
            "galleryEntryReplacement": stub,
            "overlaySha256": hashlib.sha256(canonical(after)).hexdigest()}


def production_source_hashes(source):
    paths = {source / "pubspec.yaml", source / "pubspec.lock"}
    for root in [source / "lib", source / "packages", source / "android"]:
        for path in root.rglob("*"):
            if path.is_file() and path.suffix in {".dart", ".arb", ".yaml", ".gradle", ".xml", ".kt", ".java"} and not any(
                    part in {"build", ".dart_tool", ".gradle"} for part in path.relative_to(root).parts):
                paths.add(path)
    return {path.relative_to(source).as_posix(): sha256(path) for path in sorted(paths)}


def generated_source_overlay(before, after):
    require(all(after.get(path) == value for path, value in before.items()),
            "pub get 改写已冻结生产文件；须审查并冻结新提交")
    added = after.keys() - before.keys()
    require(added.issubset({GENERATED_REGISTRANT}), "pub get 新增未审核的生产源码")
    return [{"path": path, "sha256": after[path], "reason": "Flutter根据锁定插件依赖正常生成；构建后要求原字节不变"}
            for path in sorted(added)]


def parse_badging(text: str):
    def one(pattern):
        values = re.findall(pattern, text, re.M)
        require(len(values) == 1, "APK badging 身份字段缺失或歧义")
        return values[0]
    package, code, version = one(r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'")
    return {"package": package, "versionCode": int(code), "versionName": version,
            "minSdk": int(one(r"^sdkVersion:'(\d+)'$")),
            "targetSdk": int(one(r"^targetSdkVersion:'(\d+)'$")),
            "launcher": one(r"^launchable-activity: name='([^']+)'")}


def manifest_gate(text: str):
    require(not re.search(r"E: instrumentation(?:\s|$)", text), "APK 含 instrumentation")
    for flag in ("debuggable", "testOnly"):
        matches = re.findall(r"A: android:" + flag + r"\([^)]*\)=([^\n]+)", text)
        require(len(matches) <= 1, "APK Manifest 标志有歧义")
        if matches:
            require(re.fullmatch(r"\(type 0x12\)0x0(?:\s*)", matches[0]), "APK 含开发/测试标志或无法解析")
    require(not re.search(r"com\.tntlikely\.beecount\.(?:qa|dev|debug)(?:[.\"/]|$)", text),
            "APK Manifest 混入 QA/开发身份")


def audit_zip(path: Path):
    try:
        with zipfile.ZipFile(path) as archive:
            names = archive.namelist()
            require(len(names) == len(set(names)) and "AndroidManifest.xml" in names, "APK ZIP 无效或含重复项")
            require(sum(item.file_size for item in archive.infolist()) <= 1_000_000_000, "APK 解压体积异常")
            require(archive.testzip() is None, "APK ZIP CRC 检查失败")
            abis = set()
            markers = (b"assets/v4_gallery/", b"qa-owner@example.invalid", b"qa-editor@example.invalid", b"BEECOUNT_QA_FIXTURE")
            for name in names:
                relative = PurePosixPath(name)
                require(not relative.is_absolute() and ".." not in relative.parts, "APK ZIP 路径越界")
                lower = name.lower()
                require(relative.name not in {"kernel_blob.bin", "app.dill"} and relative.suffix != ".dill",
                        "APK 含 Dart debug/JIT payload，拒绝作为 release")
                if lower.startswith("assets/"):
                    require(not any(part in lower for part in ("v4_gallery", "/integration_test/", "/fixtures/", "/qa/", "private-upgrade", "key.properties", "/.env")),
                            "APK 含验收素材/测试配置/私有材料")
                require(relative.suffix.lower() not in {".db", ".sqlite", ".sqlite3", ".keystore", ".jks", ".jceks", ".p12", ".pfx", ".key", ".pem", ".p8"},
                        "APK 含数据库/备份/签名材料")
                match = re.fullmatch(r"lib/([^/]+)/[^/]+\.so", name)
                if match:
                    abis.add(match[1])
                if not name.endswith("/"):
                    with archive.open(name) as file:
                        prefix = file.read(24)
                        require(not prefix.startswith(b"SQLite format 3\0"), "APK 含 SQLite 数据")
                        if name in {f"lib/{ABI}/libapp.so", f"lib/{ABI}/libflutter.so"}:
                            require(prefix[:6] == b"\x7fELF\x02\x01" and prefix[18:20] == b"\xb7\x00",
                                    "APK 主库实际不是 arm64 ELF/AOT")
                        require(not any(marker in prefix for marker in markers), "APK 含验收内容标记")
                        tail = prefix
                        for chunk in iter(lambda: file.read(1024 * 1024), b""):
                            joined = tail + chunk
                            require(not any(marker in joined for marker in markers), "APK 含验收内容标记")
                            tail = joined[-128:]
            require(abis == {ABI} and {f"lib/{ABI}/libapp.so", f"lib/{ABI}/libflutter.so"}.issubset(names),
                    "APK 实际 native ABI 不是单独 arm64 或缺少正常 Flutter 主库")
            return {"abis": sorted(abis), "zipEntries": len(names), "assetAudit": "PASS"}
    except (zipfile.BadZipFile, RuntimeError):
        raise GateError("APK ZIP 读取失败") from None


def verify_apk(path, *, expected_version, expected_code, expected_certificate, tools, runner, label="artifact"):
    require(path.is_file() and not path.is_symlink(), "待检 APK 缺失或不是普通文件")
    zipped = audit_zip(path)
    identity = parse_badging(runner.run([tools / "aapt", "dump", "badging", path], label=label + "-badging"))
    require(identity == {"package": PACKAGE, "versionCode": expected_code, "versionName": expected_version,
                         "minSdk": 23, "targetSdk": 36, "launcher": PACKAGE + ".MainActivity"},
            "APK 实际包名/版本/SDK/正常入口与预期不一致")
    manifest_gate(runner.run([tools / "aapt", "dump", "xmltree", path, "AndroidManifest.xml"], label=label + "-manifest"))
    signer = runner.run([tools / "apksigner", "verify", "--verbose", "--print-certs", path], label=label + "-certificate")
    certificates = re.findall(r"^Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]{64})$", signer, re.M)
    require(len(certificates) == 1 and certificates[0].lower() == expected_certificate,
            "APK 实际签名证书不匹配或存在多 signer")
    runner.run([tools / "zipalign", "-c", "-P", "16", "-v", "4", path], label=label + "-alignment")
    return dict(identity, **zipped, certificateSha256=expected_certificate, apkSha256=sha256(path), bytes=path.stat().st_size)


def select_arm64(source: Path, version, code, *, arm64_only=False):
    directory = source / "build/app/outputs/apk/prod/release"
    metadata = directory / "output-metadata.json"
    require(metadata.is_file(), "缺少正式 prod release 的 output-metadata.json")
    data = json.loads(metadata.read_text())
    require(data.get("applicationId") == PACKAGE and data.get("variantName") == "prodRelease", "Gradle 产物不是正式 prodRelease")
    selected = []
    for entry in data.get("elements", []):
        filters = entry.get("filters", [])
        if len(filters) == 1 and filters[0].get("filterType") == "ABI" and (filters[0].get("value") or filters[0].get("identifier")) == ABI:
            require(entry.get("versionCode") == code and entry.get("versionName") == version, "ABI metadata 版本不匹配")
            relative = PurePosixPath(entry["outputFile"])
            require(not relative.is_absolute() and ".." not in relative.parts, "ABI metadata 文件路径越界")
            selected.append(directory.joinpath(*relative.parts))
    require(len(selected) == 1, "ABI metadata 缺少或重复 arm64 产物")
    if arm64_only:
        require(len(data.get("elements", [])) == 1 and
                set(directory.glob("*.apk")) == {selected[0]},
                "ARM64-only 构建仍产出额外 ABI/universal APK")
    return selected[0]


def build_command(flutter, source_sha, version, code, build_time, *, arm64_only=False):
    return [str(flutter), "--suppress-analytics", "build", "apk", "--release", "--flavor", "prod", "--no-pub", "--target=lib/main.dart",
            "--build-name=" + version, "--build-number=" + str(code),
            "--target-platform=" + ("android-arm64" if arm64_only else "android-arm,android-arm64,android-x64"),
            "--dart-define=CI_VERSION=" + version, "--dart-define=GIT_COMMIT=" + source_sha,
            "--dart-define=BUILD_TIME=" + build_time, "--dart-define=GOOGLE_PLAY=false",
            "--dart-define=BEECOUNT_V4_RECORDING=false", "--dart-define=BEECOUNT_V4_GALLERY=false",
            "--dart-define=BEECOUNT_QA=false"]


def prepare_or_build(args):
    expected = certificate_digest(args.expected_certificate)
    snapshot = registry_snapshot(args.registry)
    floor = max(args.minimum_code, snapshot["maximumCode"])
    require(225 <= args.minimum_code <= MAX_VERSION_CODE, "必须提供可信渠道最高码号，至少为已核225")
    version = validate_candidate(args.version, minimum_code=floor, minimum_version=snapshot["latestVersionName"])
    credentials = load_credentials(args.credentials_file, os.environ)
    java_home, sdk, flutter = args.java_home.resolve(), args.sdk_root.resolve(), args.flutter.resolve()
    tools = sdk / "build-tools" / args.build_tools
    for executable in [java_home / "bin/java", java_home / "bin/javac", flutter,
                       *[tools / name for name in ("aapt", "apksigner", "zipalign")]]:
        require(executable.is_file() and os.access(executable, os.X_OK), "缺少本地必需工具")
    run = Path(tempfile.mkdtemp(prefix="beecount-local-apk-", dir=args.run_parent)).resolve()
    run.chmod(0o700)
    write_private(run / ".apk-build-owner", run.name.encode())
    runner = Runner(run, clean_environment(java_home, sdk))
    manifest = {"schemaVersion": 1, "runId": run.name, "status": "preflight",
                "sourceSha": args.source_sha, "versionName": version.name, "versionCode": version.code,
                "explicitChannelFloor": args.minimum_code, "effectiveFloor": floor,
                "registryPath": str(args.registry.resolve()), "registryBefore": snapshot,
                "expectedCertificateSha256": expected, "abi": ABI, "package": PACKAGE,
                "builderSha256": sha256(Path(__file__)), "functionalAcceptance": "未执行",
                "createdAtUtc": dt.datetime.now(dt.timezone.utc).isoformat()}
    try:
        runner.run([java_home / "bin/java", "-version"], label="java-version")
        # java -version writes stderr; retain the exact local tool evidence privately.
        java_log = (runner.logs / "java-version.log").read_text()
        require(re.search(r'version "17(?:\.|\")', java_log), "本地构建要求 Java17")
        signing = verify_signing(credentials, expected, java_home, runner, run)
        source, archive_hash = freeze_source(args.repo.resolve(), args.source_sha, run, runner)
        arm64_only = getattr(args, "arm64_only", False)
        if arm64_only:
            require("BEECOUNT_APK_ABI" in (source / "android/app/build.gradle").read_text(),
                    "冻结源码不支持 ARM64-only Gradle 开关")
            runner.environment["BEECOUNT_APK_ABI"] = ABI
        runner.environment["BEECOUNT_REQUIRE_PRODUCTION_SIGNING"] = "true"
        lock_hash = sha256(source / "pubspec.lock")
        overlay = release_overlay(source)
        write_json(run / "release-overlay.json", overlay)
        source_hashes = production_source_hashes(source)
        write_json(run / "production-source-after-overlay.json", source_hashes)
        manifest.update(sourceArchiveSha256=archive_hash, pubspecLockSha256=lock_hash,
                        overlaySha256=overlay["overlaySha256"], signingPrivateKeyPreflight="PASS",
                        productionSourceSha256=hashlib.sha256(canonical(source_hashes)).hexdigest())
        command = build_command(flutter, args.source_sha, version.name, version.code,
                                manifest["createdAtUtc"], arm64_only=arm64_only)
        manifest["arm64OnlyBuild"] = arm64_only
        manifest["flutterBuildArguments"] = command[1:]
        manifest["status"] = "prepared-no-flutter-executed"
        if args.execute:
            key_properties = source / "android/key.properties"
            write_private(key_properties, signing.read_bytes())
            require(sha256(key_properties) == sha256(signing), "发布副本签名四字段与预检不一致")
            pub_mode = [] if getattr(args, "allow_pub_network", False) else ["--offline"]
            runner.run([flutter, "--suppress-analytics", "pub", "get", *pub_mode, "--enforce-lockfile"], label="flutter-pub-get", cwd=source)
            require(sha256(source / "pubspec.lock") == lock_hash, "pub get 改写锁文件，拒绝构建")
            compile_sources = production_source_hashes(source)
            generated = generated_source_overlay(source_hashes, compile_sources)
            write_json(run / "generated-source-overlay.json", generated)
            manifest.update(generatedSourceOverlay=generated,
                            compiledProductionSourceSha256=hashlib.sha256(canonical(compile_sources)).hexdigest())
            runner.run(command, label="flutter-build-apk", cwd=source)
            build_log = (runner.logs / "flutter-build-apk.log").read_text().lower()
            require(not any(marker in build_log for marker in FALLBACK_MARKERS), "构建触发签名 fallback，拒绝交付")
            require(sha256(source / "pubspec.lock") == lock_hash, "构建期间锁文件发生漂移")
            require(production_source_hashes(source) == compile_sources, "构建期间生产源码或生成插件注册文件发生漂移")
            selected = select_arm64(source, version.name, version.code, arm64_only=arm64_only)
            result = verify_apk(selected, expected_version=version.name, expected_code=version.code,
                                expected_certificate=expected, tools=tools, runner=runner)
            latest = registry_snapshot(args.registry)
            require(version.code > max(args.minimum_code, latest["maximumCode"]), "构建期间已有更高或相同码号交付")
            delivery = run / "delivery"
            delivery.mkdir(mode=0o700)
            copied = delivery / ("beecount-" + version.name + "-arm64-v8a.apk")
            shutil.copyfile(selected, copied)
            copied.chmod(0o600)
            require(sha256(copied) == result["apkSha256"] and len(list(delivery.iterdir())) == 1,
                    "交付目录/hash不符合仅一份 APK 的要求")
            manifest.update(status="artifact-verified-awaiting-functional-qa", artifact=result,
                            artifactRelativePath=str(copied.relative_to(run)), registryAfter=latest,
                            toolsPath=str(tools), javaHome=str(java_home))
    except Exception:
        manifest["status"] = "failed"
        raise
    finally:
        for sensitive in [run / "signing.properties", run / "signing.keystore", run / "source/android/key.properties"]:
            sensitive.unlink(missing_ok=True)
        manifest["commands"] = runner.commands
        manifest["temporarySigningMaterialRemoved"] = True
        write_json(run / "manifest.json", manifest)
        print(json.dumps({"run": str(run), "status": manifest["status"], "versionName": version.name,
                          "versionCode": version.code, "functionalAcceptance": "未执行"}, ensure_ascii=False))
    return run


def record_delivery(args):
    require(args.confirm_delivered, "仅在真正交付后显式确认记录，构建通过不等于已交付")
    private_file(args.manifest)
    run = args.manifest.resolve().parent
    require((run / ".apk-build-owner").read_text() == run.name, "构建 run 所有权标记无效")
    data = json.loads(args.manifest.read_text())
    require(data["status"] == "artifact-verified-awaiting-functional-qa", "候选未通过实际 APK 门禁")
    latest = registry_snapshot(Path(data["registryPath"]))
    candidate = validate_candidate(data["versionName"], minimum_code=max(args.minimum_code, latest["maximumCode"]),
                                   minimum_version=latest["latestVersionName"])
    require(candidate.code == data["versionCode"], "已发最高码号已变化；候选必须按新 floor 重新分配并构建")
    require(225 <= args.minimum_code <= MAX_VERSION_CODE, "交付前必须再次核对全部渠道最高码号")
    require(args.acceptance_report.is_file() and args.acceptance_report.stat().st_size > 0,
            "必须提供真实功能/升级验收报告；工具不替代该验收")
    artifact = run / data["artifactRelativePath"]
    require(artifact.resolve().is_relative_to(run) and sha256(artifact) == data["artifact"]["apkSha256"], "已验 APK 被替换")
    runner = Runner(Path(tempfile.mkdtemp(prefix="delivery-recheck-", dir=run)),
                    clean_environment(Path(data["javaHome"]), Path(data["toolsPath"]).parents[1]))
    verify_apk(artifact, expected_version=data["versionName"], expected_code=data["versionCode"],
               expected_certificate=data["expectedCertificateSha256"], tools=Path(data["toolsPath"]), runner=runner)
    entry = append_delivery(Path(data["registryPath"]), {"deliveredAtUtc": dt.datetime.now(dt.timezone.utc).isoformat(),
                    "versionName": data["versionName"], "versionCode": data["versionCode"],
                    "sourceSha": data["sourceSha"], "apkSha256": data["artifact"]["apkSha256"],
                    "certificateSha256": data["expectedCertificateSha256"], "abi": ABI, "package": PACKAGE,
                    "acceptanceReportSha256": sha256(args.acceptance_report)})
    write_json(run / "delivery-receipt.json", {"registryEntry": entry, "confirmation": "操作者确认已验收并真正交付；工具仅核产物与报告hash"})
    print(json.dumps({"registryRecorded": True, "versionName": data["versionName"],
                      "versionCode": data["versionCode"], "entrySha256": entry["entrySha256"]}, ensure_ascii=False))


class SafeArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        # argparse normally echoes unrecognised arguments, including accidentally pasted passwords.
        self.print_usage(sys.stderr)
        self.exit(2, "参数无效；签名只接受私有文件或环境，未回显输入值。\n")


def parser():
    result = SafeArgumentParser(description=__doc__)
    sub = result.add_subparsers(dest="action", required=True)
    init = sub.add_parser("init-registry", help="明确确认没有历史本地交付记录后初始化空 registry")
    init.add_argument("--registry", type=Path, required=True)
    build = sub.add_parser("prepare", help="默认仅预检/准备；--execute 才真正构建")
    for name in ["repo", "registry", "flutter", "java-home", "sdk-root"]:
        build.add_argument("--" + name, type=Path, required=True)
    build.add_argument("--source-sha", required=True)
    build.add_argument("--version", required=True)
    build.add_argument("--minimum-code", type=int, required=True)
    build.add_argument("--expected-certificate", required=True)
    build.add_argument("--credentials-file", type=Path)
    build.add_argument("--build-tools", default="36.0.0")
    build.add_argument("--run-parent", type=Path)
    build.add_argument("--execute", action="store_true")
    build.add_argument("--arm64-only", action="store_true", help="Flutter和Gradle均只构建ARM64，拒绝额外APK")
    build.add_argument("--allow-pub-network", action="store_true", help="CI显式允许下载锁定依赖，仍强制lockfile与源码不变")
    record = sub.add_parser("record-delivery", help="人工验收且确实交付后追加记录，不签名、不安装")
    record.add_argument("--manifest", type=Path, required=True)
    record.add_argument("--acceptance-report", type=Path, required=True)
    record.add_argument("--minimum-code", type=int, required=True, help="真正交付前再次核查全部渠道最高实际码号")
    record.add_argument("--confirm-delivered", action="store_true")
    return result


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        if args.action == "init-registry":
            init_registry(args.registry)
        elif args.action == "prepare":
            prepare_or_build(args)
        else:
            record_delivery(args)
    except (GateError, ValueError) as error:
        # ValueError from the version calculator is deliberately public; do not print JSON/parser errors.
        text = str(error) if isinstance(error, GateError) else "版本或输入格式无效"
        print("本地 APK 门禁失败：" + text, file=sys.stderr)
        return 2
    except Exception as error:
        print("本地 APK 门禁异常：" + type(error).__name__ + "（详情仅保留在私有 run）", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
