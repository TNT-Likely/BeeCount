#!/usr/bin/env python3
"""iOS stage of the unified Beta delivery; never enters the stable release flow.

Only an already published, receipted Android Beta may supply source/version/notes.
Private source/signing copies live under RUNNER_TEMP. No debug/unsigned fallback.
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import secrets
import shlex
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
import zipfile

import beta_release as beta
import local_apk as gate
from android_version_code import parse_version

BUNDLE = 'com.tntlikely.beecount'
WIDGET = BUNDLE + '.BeeCountWidgetExtension'
GROUP = 'group.com.tntlikely.beecount'
MODES = ('ipa', 'testflight')
SIGNING_KEYS = ('APPLE_CERTIFICATE_P12', 'APPLE_CERTIFICATE_PASSWORD',
                'APPLE_PROVISIONING_PROFILE', 'APPLE_PROVISIONING_PROFILE_WIDGET', 'APPLE_TEAM_ID')
API_KEYS = ('APPLE_API_KEY_CONTENT', 'APPLE_API_KEY_ID', 'APPLE_API_ISSUER_ID')
MAX_ASSET = 1_500_000_000


def signing_inputs(mode):
    gate.require(mode in MODES, 'iOS Beta 模式只能是 ipa 或 testflight')
    gate.require(all(os.environ.get(k) for k in SIGNING_KEYS), 'iOS主App/Widget签名secrets必须齐全，拒绝未签名回退')
    gate.require(re.fullmatch(r'[A-Z0-9]{10}', os.environ['APPLE_TEAM_ID']), 'Apple Team ID 格式错误')
    values = {}
    for key in ('APPLE_CERTIFICATE_P12', 'APPLE_PROVISIONING_PROFILE', 'APPLE_PROVISIONING_PROFILE_WIDGET'):
        try:
            decoded = base64.b64decode(''.join(os.environ[key].split()), validate=True)
        except ValueError:
            raise gate.GateError('iOS签名材料不是有效Base64') from None
        gate.require(0 < len(decoded) <= 10 * 1024 * 1024, 'iOS签名材料大小无效')
        values[key] = decoded
    if mode == 'testflight':
        values['apiKey'] = api_key()
    return values


def api_key():
    gate.require(all(os.environ.get(k) for k in API_KEYS), 'TestFlight需要现有APPLE_API_KEY_CONTENT/ID/ISSUER_ID')
    gate.require(re.fullmatch(r'[A-Z0-9]{10}', os.environ['APPLE_API_KEY_ID']), 'App Store Connect Key ID 格式错误')
    gate.require(re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}', os.environ['APPLE_API_ISSUER_ID']), 'App Store Connect Issuer ID 格式错误')
    raw = os.environ['APPLE_API_KEY_CONTENT'].strip().lstrip('\ufeff')
    # GitHub secrets created from JSON/env files can retain escaped newlines or
    # the quotes of a JSON string. Normalize transport encoding only; the PEM
    # identity check below remains mandatory and never logs private material.
    if raw.startswith('"'):
        try:
            raw = json.loads(raw)
        except (ValueError, TypeError):
            raise gate.GateError('App Store Connect私钥JSON字符串格式无效') from None
        gate.require(isinstance(raw, str), 'App Store Connect私钥必须是字符串')
    value = raw.encode()
    for _ in range(2):
        if value.startswith(b'-----BEGIN ') or value.startswith(b'\x30'):
            break
        try:
            value = base64.b64decode(b''.join(value.split()), validate=True)
        except ValueError:
            raise gate.GateError('App Store Connect私钥须为PKCS8 PEM/DER或其Base64') from None
    gate.require(0 < len(value) <= 16384, 'App Store Connect私钥大小无效')
    # Apple .p8 content is sometimes stored as its bare base64 DER body.
    # OpenSSL must parse it as a real key before canonical PEM is accepted.
    if value.startswith(b'\x30'):
        converted = subprocess.run(['openssl', 'pkey', '-inform', 'DER', '-outform', 'PEM'],
            input=value, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)
        gate.require(converted.returncode == 0, 'App Store Connect DER私钥无法解析')
        value = converted.stdout.strip()
    value = value.replace(b'\\r\\n', b'\n').replace(b'\\n', b'\n').replace(b'\r\n', b'\n').strip()
    match = re.fullmatch(rb'-----BEGIN PRIVATE KEY-----\s*([A-Za-z0-9+/=\s]+)-----END PRIVATE KEY-----\s*', value)
    gate.require(match is not None and len(value) <= 16384,
        'App Store Connect私钥格式无效（PEM边界=' + str(value.startswith(b'-----BEGIN ')) +
        '）；需要完整PKCS8 .p8内容，不能填文件名或其他凭据')
    # Canonical line breaks also support a single-line copied PEM.
    body = b''.join(match[1].split())
    value = b'-----BEGIN PRIVATE KEY-----\n' + b'\n'.join(body[i:i+64] for i in range(0,len(body),64)) + b'\n-----END PRIVATE KEY-----'

    return value


def profile_gate(value, bundle, team, certificate=None, now=None):
    now = now or dt.datetime.now(dt.timezone.utc)
    expiry = value.get('ExpirationDate')
    if isinstance(expiry, dt.datetime) and expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=dt.timezone.utc)
    ent = value.get('Entitlements', {})
    gate.require(isinstance(expiry, dt.datetime) and expiry > now, 'iOS分发描述文件已过期或日期缺失')
    gate.require(value.get('TeamIdentifier') == [team] and ent.get('application-identifier') == team + '.' + bundle,
                 'iOS描述文件不属于目标Team/生产Bundle ID')
    gate.require(ent.get('get-task-allow') is False and ent.get('beta-reports-active') is True
                 and not value.get('ProvisionedDevices') and not value.get('ProvisionsAllDevices'),
                 '只接受App Store分发profile，拒绝开发/Ad Hoc/企业配置')
    gate.require(GROUP in ent.get('com.apple.security.application-groups', []), '描述文件缺少生产App Group权限')
    if bundle == BUNDLE:
        gate.require('iCloud.' + BUNDLE in ent.get('com.apple.developer.icloud-container-identifiers', []),
                     '主App描述文件缺少生产iCloud容器')
    gate.require(re.fullmatch(r'[A-Fa-f0-9-]{36}', value.get('UUID', '')) is not None, '描述文件UUID无效')
    if certificate is not None:
        gate.require(certificate in value.get('DeveloperCertificates', []), 'P12分发证书不在主App/Widget描述文件中')
    return value['UUID']


def ios_version(version, android_code, explicit='', floor='225'):
    parsed = parse_version(version)
    gate.require(parsed.beta is not None, 'iOS Beta流程拒绝正式版')
    gate.require(re.fullmatch(r'[1-9][0-9]*', str(floor)), 'iOS最高已交付build水位缺失或无效')
    text = explicit or str(android_code)
    gate.require(re.fullmatch(r'[1-9][0-9]*', text), 'iOS build必须为正整数')
    number = int(text)
    gate.require(number >= android_code and number > int(floor), 'iOS build须不低于该Beta的Android码且高于iOS已交付水位')
    if parsed.initial_beta:
        gate.require(225 < number < 300, '4.0.0 iOS Beta只使用226..299，正式版保留从300开始')
    else:
        gate.require(number >= 300, '后续iOS版本build至少300')
    return f'{parsed.major}.{parsed.minor}.{parsed.patch}', number


def public_names(version, number):
    stem = f'beecount-{version}-ios-{number}-app-store.ipa'
    return stem, stem + '.sha256', f'ios-release-{number}.json'


def validate_ipa_tree(app, context, team):
    """Identity assertions only; real codesign verification is separate and mandatory."""
    bundles = [app, *sorted((app / 'PlugIns').glob('*.appex'))]
    gate.require(len(bundles) == 2, 'IPA必须包含唯一主App及唯一Widget扩展')
    identities = []
    for target, expected in zip(bundles, (BUNDLE, WIDGET)):
        value = plistlib.loads((target / 'Info.plist').read_bytes())
        gate.require(value.get('CFBundleIdentifier') == expected, 'IPA混入开发/QA身份或Widget ID不符')
        gate.require(value.get('CFBundleShortVersionString') == context['appVersion']
                     and value.get('CFBundleVersion') == str(context['buildNumber']), '主App/Widget实际版本不一致')
        gate.require(value.get('DTPlatformName') == 'iphoneos' and re.fullmatch(r'iphoneos(?:2[6-9]|[3-9][0-9])(?:\.[0-9]+)*', value.get('DTSDKName', '')),
                     'IPA不是iOS真机产物或低于Apple当前iOS26 SDK要求')
        gate.require(re.fullmatch(r'[A-Za-z0-9_.-]+', value.get('CFBundleExecutable', '')) is not None, 'IPA可执行文件名异常')
        gate.require((target / value['CFBundleExecutable']).is_file(), 'IPA缺少可执行文件')
        gate.require(not (target / 'flutter_assets/kernel_blob.bin').exists(), 'IPA包含Flutter debug内核')
        identities.append((target, expected, value))
    return identities


def context_path():
    path = Path(os.environ['IOS_BETA_CONTEXT']).resolve()
    root = Path(os.environ['RUNNER_TEMP']).resolve()
    gate.require(path.parent == root and path.name.startswith('beecount-ios-beta-'), 'iOS发布上下文必须位于本轮RUNNER_TEMP')
    return path


def context_read():
    path = context_path()
    gate.private_file(path)
    return json.loads(path.read_text())


def context_write(value):
    gate.write_json(context_path(), value)


def build_diagnostic(output, label):
    """Only source-build tools may emit bounded, redacted failure diagnostics."""
    if label not in {'flutter-config', 'pod-install', 'archive', 'export', 'pub-get'}:
        return ''
    text = output.decode('utf-8', errors='replace')
    for key in (*SIGNING_KEYS, *API_KEYS, 'GH_TOKEN', 'GITHUB_TOKEN', 'TELEGRAM_BOT_TOKEN', 'TELEGRAM_CHAT_ID'):
        value = os.environ.get(key, '')
        if value:
            text = text.replace(value, '[REDACTED]')
    text = re.sub(r'-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----',
                  '[REDACTED PRIVATE KEY]', text, flags=re.S)
    text = re.sub(r'https?://[^\s/@]+:[^\s/@]+@', 'https://[REDACTED]@', text)
    text = text.replace(str(Path.home()), '$HOME').replace(os.environ.get('RUNNER_TEMP', '\x00'), '$RUNNER_TEMP')
    return '\n'.join(text.splitlines()[-70:])[-10000:]


def command(args, *, cwd=None, env=None, label='command', run=None):
    """Capture commands privately. Never print raw signer/API errors or secrets."""
    result = subprocess.run([str(x) for x in args], cwd=cwd, env=env or build_environment(), capture_output=True)
    if run is not None:
        logs = run / 'logs'
        logs.mkdir(exist_ok=True, mode=0o700)
        path = logs / (label + '.log')
        path.write_bytes(result.stdout + result.stderr)
        path.chmod(0o600)
    if result.returncode != 0:
        diagnostic = build_diagnostic(result.stdout + result.stderr, label)
        if diagnostic:
            print('已脱敏构建诊断：\n' + diagnostic)
    gate.require(result.returncode == 0, label + '失败；私有日志保留，未输出签名或账号材料')
    return result.stdout


def build_environment():
    # Flutter/Pods/Xcode source scripts never inherit signing/API/GitHub/TG secrets.
    private = set(SIGNING_KEYS) | set(API_KEYS) | {'GH_TOKEN','GITHUB_TOKEN','TELEGRAM_BOT_TOKEN','TELEGRAM_CHAT_ID'}
    return {k:v for k,v in os.environ.items() if k not in private}


def get_release(client, version):
    release = client.request('GET', f'/repos/{beta.REPOSITORY}/releases/tags/{version}')
    gate.require(release.get('draft') is False and release.get('prerelease') is True
                 and release.get('tag_name') == version, 'iOS只补充已公开且版本一致的Beta prerelease')
    receipts = [a for a in release.get('assets', []) if a.get('name') == beta.RECEIPT]
    gate.require(len(receipts) == 1, '目标Beta缺少唯一Android发布回执，先完成Android Beta')
    record = client.receipt(receipts[0])
    parsed = beta.validate_receipt(release, record)
    gate.require(parsed.beta is not None, '目标回执不是Beta')
    return release, record


def published_ios_floor(client, floor):
    gate.require(re.fullmatch(r'[1-9][0-9]*',floor), 'iOS已交付水位无效')
    highest = int(floor)
    for release in client.releases():
        for asset in release.get('assets',[]):
            if not re.fullmatch(r'ios-release-[1-9][0-9]*\.json',asset.get('name','')):
                continue
            record = client.receipt(asset)
            gate.require(record.get('schemaVersion') == 1 and record.get('kind') == 'beecount-ios-beta-release'
                         and record.get('bundleId') == BUNDLE and record.get('widgetBundleId') == WIDGET
                         and record.get('versionName') == release.get('tag_name')
                         and type(record.get('buildNumber')) is int
                         and type(record.get('androidVersionCode')) is int
                         and re.fullmatch(r'[0-9a-f]{40}',record.get('sourceSha',''))
                         and re.fullmatch(r'[0-9a-f]{64}',record.get('ipaSha256','')),
                         '历史iOS Beta回执身份无效，拒绝忽略已交付水位')
            app_version, number = ios_version(record['versionName'],record['androidVersionCode'],str(record['buildNumber']),'225')
            gate.require(record.get('appVersion') == app_version and asset['name'] == f'ios-release-{number}.json', '历史iOS版本/回执名称不一致')
            highest = max(highest,number)
    return str(highest)


def require_tag(client, version, source):
    obj = client.request('GET', f'/repos/{beta.REPOSITORY}/git/ref/tags/{version}')['object']
    for _ in range(4):
        if obj.get('type') == 'commit':
            break
        gate.require(obj.get('type') == 'tag', '无法解析目标Beta tag')
        obj = client.request('GET', f'/repos/{beta.REPOSITORY}/git/tags/{obj["sha"]}')['object']
    gate.require(obj.get('type') == 'commit' and obj.get('sha') == source, 'Beta tag不再指向原冻结源码')


def plan():
    gate.require(os.environ.get('GITHUB_REPOSITORY') == beta.REPOSITORY
                 and os.environ.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
                 and os.environ.get('GITHUB_REF_NAME') == 'v4', '统一iOS Beta阶段只接受目标仓库v4的手动运行')
    mode = os.environ.get('IOS_BETA_MODE', 'ipa')
    signing_inputs(mode)
    version = parse_version(os.environ.get('BETA_VERSION', '')).name
    client = beta.GitHub()
    atomic = os.environ.get('BETA_ATOMIC') == '1'
    if atomic:
        android = beta.read_context()
        gate.require(android.get('status') == 'verified' and android.get('versionName') == version
                     and android.get('certificateSha256') == beta.PRODUCTION_CERTIFICATE,
                     'iOS必须引用同一轮已经验包的Android私有候选')
        gate.require(str(android.get('workflowRun', os.environ.get('GITHUB_RUN_ID'))) == os.environ.get('GITHUB_RUN_ID'),
                     '双端候选不属于同一次发布作业')
        sha = beta.source_sha(android['sourceSha'], Path.cwd())
        record = dict(sourceSha=sha, versionCode=android['versionCode'])
        release = dict(id=None, html_url=None, body=android['notes'], assets=[])
    else:
        release, record = get_release(client, version)
        sha = beta.source_sha(record['sourceSha'], Path.cwd())
        require_tag(client, version, sha)
    floor = published_ios_floor(client,os.environ.get('IOS_BUILD_NUMBER_FLOOR','225'))
    app_version, number = ios_version(version, record['versionCode'],
        os.environ.get('IOS_BUILD_NUMBER', ''), floor)
    names = public_names(version, number)
    gate.require(not any(a.get('name') in names or a.get('name') == f'ios-testflight-{number}.json'
                         for a in release.get('assets', [])), '同一iOS build已有资产，禁止替换；核对后使用新的显式build号')
    summary = beta.extract_update_summary(release.get('body'))
    if os.environ.get('TESTFLIGHT_PUBLIC_URL'):
        gate.require(re.fullmatch(r'https://testflight\.apple\.com/join/[A-Za-z0-9]+',os.environ['TESTFLIGHT_PUBLIC_URL']) is not None, 'TestFlight公开链接格式无效')
    gate.require(not context_path().exists(), 'iOS发布上下文已存在，拒绝覆盖')
    run = Path(tempfile.mkdtemp(prefix='beecount-ios-beta-run-', dir=os.environ['RUNNER_TEMP']))
    run.chmod(0o700)
    state = dict(status='planned', atomic=atomic, run=str(run), mode=mode, sourceSha=sha,
                 versionName=version, appVersion=app_version, buildNumber=number,
                 androidVersionCode=record['versionCode'], releaseId=release['id'],
                 releaseUrl=release['html_url'], notificationSummary=summary,
                 workflowRun=os.environ['GITHUB_RUN_ID'], profiles=[], keychain=None)
    gate.write_private(context_path(), b'{}')
    context_write(state)
    if mode == 'testflight':
        key_dir = run/'api'
        key_dir.mkdir(mode=0o700)
        key_path = key_dir/('AuthKey_'+os.environ['APPLE_API_KEY_ID']+'.p8')
        gate.write_private(key_path,api_key())
        app_store_preflight(AppStore(key_path,run),state)
    output = os.environ.get('GITHUB_OUTPUT')
    if output:
        with open(output, 'a') as f:
            f.write(f'artifact_dir={run / "dist"}\nversion={version}\nbuild_number={number}\n')
    print(f'iOS候选已冻结：{version} / {app_version}+{number}，尚未构建、上传或通知')


def configure_signing(context, source, run):
    values = signing_inputs('ipa')
    team = os.environ['APPLE_TEAM_ID']
    signing = run / 'signing'
    signing.mkdir(mode=0o700)
    p12 = signing / 'distribution.p12'
    gate.write_private(p12, values['APPLE_CERTIFICATE_P12'])
    env = dict(build_environment(), IOS_P12_PASSWORD=os.environ['APPLE_CERTIFICATE_PASSWORD'])
    pem = command(['openssl', 'pkcs12', '-in', p12, '-clcerts', '-nokeys', '-passin', 'env:IOS_P12_PASSWORD'], env=env, label='p12-certificate', run=run)
    certs = re.findall(rb'-----BEGIN CERTIFICATE-----\s+([A-Za-z0-9+/=\s]+)-----END CERTIFICATE-----', pem)
    gate.require(len(certs) == 1, 'P12必须包含唯一分发叶证书')
    certificate = base64.b64decode(re.sub(rb'\s', b'', certs[0]), validate=True)
    der = signing / 'distribution.cer'
    gate.write_private(der, certificate)
    subject = command(['openssl', 'x509', '-inform', 'DER', '-in', der, '-noout', '-subject'], label='certificate-subject', run=run)
    gate.require(b'Apple Distribution' in subject, 'P12不是Apple Distribution分发证书')
    profiles = {}
    for key, bundle in [('APPLE_PROVISIONING_PROFILE', BUNDLE), ('APPLE_PROVISIONING_PROFILE_WIDGET', WIDGET)]:
        path = signing / (bundle + '.mobileprovision')
        gate.write_private(path, values[key])
        decoded = plistlib.loads(command(['security', 'cms', '-D', '-i', path], label='decode-' + bundle, run=run))
        uuid = profile_gate(decoded, bundle, team, certificate)
        destination = Path.home() / 'Library/MobileDevice/Provisioning Profiles' / (uuid + '.mobileprovision')
        gate.require(not destination.exists(), '临时Runner已存在同UUID profile，拒绝覆盖')
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
        destination.chmod(0o600)
        context['profiles'].append(str(destination))
        context_write(context)
        profiles[bundle] = uuid
    old_keychains = shlex.split(command(['security', 'list-keychains', '-d', 'user'], label='existing-keychains', run=run).decode())
    keychain = signing / 'beta.keychain-db'
    context.update(keychain=str(keychain), oldKeychains=old_keychains)
    context_write(context)
    password = secrets.token_urlsafe(36)
    command(['security', 'create-keychain', '-p', password, keychain], label='keychain-create', run=run)
    command(['security', 'set-keychain-settings', '-lut', '21600', keychain], label='keychain-settings', run=run)
    command(['security', 'unlock-keychain', '-p', password, keychain], label='keychain-unlock', run=run)
    command(['security', 'import', p12, '-P', os.environ['APPLE_CERTIFICATE_PASSWORD'], '-A', '-t', 'cert', '-f', 'pkcs12', '-k', keychain], label='keychain-import', run=run)
    command(['security', 'list-keychains', '-d', 'user', '-s', keychain, *old_keychains], label='keychain-search', run=run)
    command(['security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:', '-s', '-k', password, keychain], label='keychain-partition', run=run)
    cert_id = hashlib.sha1(certificate).hexdigest().upper()  # Xcode selects the exact imported identity.
    config = dict(team=team, mainProfile=profiles[BUNDLE], widgetProfile=profiles[WIDGET],
                  certificate=cert_id, appVersion=context['appVersion'], buildNumber=str(context['buildNumber']))
    config_path = signing / 'xcode-signing.json'
    gate.write_private(config_path, json.dumps(config).encode())
    helper = Path(__file__).with_name('configure_ios_beta_signing.rb').resolve()
    command(['ruby', helper, source / 'ios/Runner.xcodeproj', config_path], label='configure-project', run=run)
    options = dict(method='app-store-connect', teamID=team, signingStyle='manual',
                   signingCertificate=cert_id, provisioningProfiles=profiles,
                   uploadSymbols=True, manageAppVersionAndBuildNumber=False, destination='export')
    options_path = signing / 'ExportOptions.plist'
    gate.write_private(options_path, plistlib.dumps(options))
    return options_path, hashlib.sha256(certificate).hexdigest()


def verify_ipa(path, context, certificate, run):
    extracted = run / ('verify-' + secrets.token_hex(4))
    extracted.mkdir(mode=0o700)
    gate.require(0 < path.stat().st_size <= MAX_ASSET, 'IPA大小无效')
    with zipfile.ZipFile(path) as z:
        gate.require(len(z.namelist()) == len(set(z.namelist())), 'IPA包含重复路径')
        gate.require(sum(x.file_size for x in z.infolist()) <= 3_000_000_000, 'IPA解压体积异常')
        gate.require(z.testzip() is None, 'IPA ZIP CRC错误')
        for item in z.infolist():
            relative = PurePosixPath(item.filename)
            gate.require(not relative.is_absolute() and '..' not in relative.parts
                         and not stat.S_ISLNK(item.external_attr >> 16), 'IPA含越界路径或符号链接')
            gate.require(relative.suffix.lower() not in {'.p8','.p12','.keystore','.sqlite','.db'}, 'IPA包含私钥或数据库')
            gate.require(relative.name not in {'kernel_blob.bin','app.dill'}, 'IPA包含debug/JIT内核')
        z.extractall(extracted)
    apps = list((extracted / 'Payload').glob('*.app'))
    gate.require(len(apps) == 1, 'IPA缺少唯一主App')
    identities = validate_ipa_tree(apps[0], context, os.environ['APPLE_TEAM_ID'])
    for index, (app, bundle, info) in enumerate(identities):
        command(['codesign', '--verify', '--strict', '--deep', app], label=f'verify-signature-{index}', run=run)
        arch = command(['lipo', '-archs', app / info['CFBundleExecutable']], label=f'verify-architecture-{index}', run=run).decode().split()
        gate.require(arch == ['arm64'], 'IPA主App/Widget不是单一arm64真机架构')
        ent_bytes = command(['codesign', '-d', '--entitlements', ':-', app], label=f'verify-entitlements-{index}', run=run)
        ent = plistlib.loads(ent_bytes)
        gate.require(ent.get('application-identifier') == os.environ['APPLE_TEAM_ID'] + '.' + bundle
                     and ent.get('get-task-allow') is not True and GROUP in ent.get('com.apple.security.application-groups', []),
                     '实签名权限不属于生产App/Widget或含调试权限')
        if bundle == BUNDLE:
            gate.require('iCloud.' + BUNDLE in ent.get('com.apple.developer.icloud-container-identifiers',[]), '实签主App缺少原生产iCloud容器')
        profile = plistlib.loads(command(['security', 'cms', '-D', '-i', app / 'embedded.mobileprovision'], label=f'verify-profile-{index}', run=run))
        profile_gate(profile, bundle, os.environ['APPLE_TEAM_ID'])
        prefix = extracted / f'certificate-{index}-'
        command(['codesign', '-d', '--extract-certificates=' + str(prefix), app], label=f'extract-certificate-{index}', run=run)
        gate.require(gate.sha256(Path(str(prefix) + '0')) == certificate, 'IPA实际签名证书与已验证P12不一致')
    return dict(ipaSha256=gate.sha256(path), bytes=path.stat().st_size,
                bundleId=BUNDLE, widgetBundleId=WIDGET, appVersion=context['appVersion'],
                buildNumber=context['buildNumber'], certificateSha256=certificate,
                architecture='arm64', sdk=identities[0][2]['DTSDKName'])


def enforce_locked_pods(run):
    pod = shutil.which('pod')
    gate.require(pod is not None, '缺少本轮固定CocoaPods')
    version = command([pod,'_1.16.2_','--version'],label='cocoapods-version',run=run).decode().strip()
    gate.require(version == '1.16.2', '必须使用固定CocoaPods 1.16.2')
    tools = run/'tools'
    tools.mkdir(mode=0o700)
    # JSON >=2.8 changed empty-array pretty printing, which changes Podspec
    # checksums despite identical dependency versions. Match the committed lock
    # with a private serializer instead of rewriting its SPEC CHECKSUMS.
    json_gems = run/'json-gems'
    command(['gem', 'install', 'json', '-v', '2.7.2', '--no-document',
             '--install-dir', json_gems], label='json-serializer-install', run=run)
    bootstrap = tools/'json-compat.rb'
    gate.write_private(bootstrap,b"gem 'json', '= 2.7.2'\nrequire 'json'\n")
    os.environ['GEM_PATH'] = str(json_gems) + os.pathsep + os.environ.get('GEM_PATH', os.environ.get('GEM_HOME', ''))
    os.environ['RUBYOPT'] = '-r' + shlex.quote(str(bootstrap)) + (' ' + os.environ['RUBYOPT'] if os.environ.get('RUBYOPT') else '')
    version = command(['ruby', '-e', 'require "json"; puts JSON::VERSION'],
                      label='json-serializer-version',run=run).decode().strip()
    gate.require(version == '2.7.2', 'Podspec序列化必须固定JSON 2.7.2，不能修改依赖锁绕过')
    # Flutter 3.27 config-only also invokes pod install. Enforce deployment
    # on that implicit invocation, before an unlocked resolver could run.
    wrapper = tools/'pod'
    script = ('#!/bin/sh\nif [ "$1" = install ]; then\n  exec '+shlex.quote(pod)+
              ' "$@" --deployment\nfi\nexec '+shlex.quote(pod)+' "$@"\n')
    gate.write_private(wrapper,script.encode())
    wrapper.chmod(0o700)
    os.environ['PATH'] = str(tools)+os.pathsep+os.environ.get('PATH','')


def build():
    context = context_read()
    gate.require(context['status'] == 'planned' and os.environ.get('RUNNER_OS') == 'macOS', 'iOS构建只允许macOS的planned上下文')
    run = Path(context['run'])
    runner = gate.Runner(run, build_environment())
    sdk = command(['xcrun', '--sdk', 'iphoneos', '--show-sdk-version'], label='sdk-version', run=run).decode().strip()
    gate.require(re.fullmatch(r'[0-9]+(?:\.[0-9]+)*', sdk) and int(sdk.split('.')[0]) >= 26, 'Apple上传要求iOS26或更高SDK')
    source, archive_hash = gate.freeze_source(Path.cwd(), context['sourceSha'], run, runner)
    overlay = gate.release_overlay(source)
    context.update(source=str(source), sourceArchiveSha256=archive_hash, releaseOverlaySha256=overlay['overlaySha256'])
    context_write(context)
    lock_paths = ['pubspec.lock', 'ios/Podfile.lock']
    locks = {name: gate.sha256(source / name) for name in lock_paths}
    enforce_locked_pods(run)
    production_before = gate.production_source_hashes(source)
    command(['flutter','pub','get','--enforce-lockfile'], cwd=source, label='pub-get', run=run)
    generated = gate.generated_source_overlay(production_before,gate.production_source_hashes(source))
    expected_production = gate.production_source_hashes(source)
    options, certificate = configure_signing(context, source, run)
    command(['flutter','build','ios','--config-only','--release','--no-pub',
             '--build-name=' + context['appVersion'], '--build-number=' + str(context['buildNumber']),
             '--dart-define=CI_VERSION=' + context['versionName'], '--dart-define=GIT_COMMIT=' + context['sourceSha'],
             '--dart-define=BUILD_TIME=' + os.environ['GITHUB_RUN_ID']], cwd=source, label='flutter-config', run=run)
    command(['pod','_1.16.2_','install','--deployment'], cwd=source / 'ios', label='pod-install', run=run)
    gate.require(all(gate.sha256(source / name) == value for name,value in locks.items()), 'iOS构建依赖锁发生漂移，拒绝继续')
    archive = run / 'BeeCount.xcarchive'
    command(['xcodebuild','archive','-workspace','ios/Runner.xcworkspace','-scheme','Runner',
             '-configuration','Release','-destination','generic/platform=iOS','-archivePath',archive,'-quiet'],
            cwd=source, label='archive', run=run)
    export = run / 'export'
    command(['xcodebuild','-exportArchive','-archivePath',archive,'-exportOptionsPlist',options,
             '-exportPath',export,'-quiet'], cwd=source, label='export', run=run)
    gate.require(gate.production_source_hashes(source) == expected_production, 'iOS构建修改了冻结的业务源码/依赖，拒绝发布')
    gate.require(all(gate.sha256(source / name) == value for name,value in locks.items()), 'iOS归档后依赖锁漂移')
    ipas = list(export.glob('*.ipa'))
    gate.require(len(ipas) == 1, '没有唯一已签名IPA，拒绝unsigned/debug回退')
    artifact = verify_ipa(ipas[0], context, certificate, run)
    dist = run / 'dist'
    dist.mkdir(mode=0o700)
    name, checksum, receipt_name = public_names(context['versionName'], context['buildNumber'])
    shutil.copy2(ipas[0], dist / name)
    (dist / checksum).write_text(artifact['ipaSha256'] + '  ' + name + '\n')
    receipt = dict(schemaVersion=1,kind='beecount-ios-beta-release',versionName=context['versionName'],
                   sourceSha=context['sourceSha'],androidVersionCode=context['androidVersionCode'],
                   **artifact, sourceArchiveSha256=archive_hash, releaseOverlaySha256=overlay['overlaySha256'],
                   dependencyLockUnchanged=True,generatedSourceOverlay=generated,workflowRun=os.environ['GITHUB_RUN_ID'],
                   distribution='app-store',testflightStatus='not-uploaded',
                   functionalAcceptance='已验证签名、版本、真机架构及权限；不等同于真机功能验收。')
    (dist / receipt_name).write_text(json.dumps(receipt,ensure_ascii=False,indent=2))
    context.update(status='verified',artifact=artifact,dist=str(dist),receipt=receipt)
    context_write(context)
    print('IPA静态门禁通过；尚未上传App Store Connect或发布到GitHub')


def publish():
    context = context_read()
    gate.require(not context.get('atomic'), '私有双端候选只能通过统一原子发布入口公开')
    gate.require(context['status'] == 'verified', '仅允许已验包IPA进入GitHub prerelease')
    client = beta.GitHub()
    release, record = get_release(client, context['versionName'])
    gate.require(release['id'] == context['releaseId'] and record['sourceSha'] == context['sourceSha'], 'Android Beta身份在构建期间改变')
    require_tag(client, context['versionName'], context['sourceSha'])
    names = public_names(context['versionName'], context['buildNumber'])
    gate.require(not any(a.get('name') in names for a in release.get('assets', [])), '同名IPA/回执已存在，拒绝覆盖')
    dist = Path(context['dist'])
    gate.require(gate.sha256(dist / names[0]) == context['artifact']['ipaSha256'], '发布前IPA字节已变化')
    gate.require((dist / names[1]).read_text() == context['artifact']['ipaSha256']+'  '+names[0]+'\n'
                 and json.loads((dist / names[2]).read_text()) == context['receipt'], '发布前校验文件或机器回执改变')
    for name in names:
        kind = 'application/octet-stream' if name.endswith('.ipa') else 'text/plain' if name.endswith('.sha256') else 'application/json'
        client.upload(release['id'], name, (dist / name).read_bytes(), kind)
    context['status'] = 'published'
    context_write(context)
    print('同一Beta prerelease已补充已签名App Store IPA及校验回执；该IPA不能直接侧载安装')


def jwt_signature(der):
    """Convert an OpenSSL P-256 ECDSA DER signature into JOSE R||S."""
    def length(at):
        gate.require(at < len(der), 'API签名DER长度无效')
        size = der[at]
        if size < 128:
            return size, at + 1
        count = size & 127
        gate.require(count in (1,2) and at + 1 + count <= len(der), 'API签名DER长度异常')
        return int.from_bytes(der[at+1:at+1+count], 'big'), at + 1 + count
    gate.require(der[:1] == b'\x30', 'API签名不是DER序列')
    size, pos = length(1)
    gate.require(pos + size == len(der), 'API签名DER尾部无效')
    values = []
    for _ in range(2):
        gate.require(der[pos:pos+1] == b'\x02', 'API签名不是ECDSA整数')
        size, start = length(pos+1)
        raw = der[start:start+size]
        gate.require(len(raw) == size and 0 < size <= 33 and not (raw[0] & 128), 'API签名整数无效')
        value = int.from_bytes(raw, 'big')
        gate.require(0 < value < 2**256, 'API签名整数超界')
        values.append(value.to_bytes(32,'big'))
        pos = start + size
    gate.require(pos == len(der), 'API签名含多余值')
    return b''.join(values)


class AppStore:
    def __init__(self, key_path, run):
        self.key_path, self.run = key_path, run

    def request(self, method, path, data=None):
        gate.require(path.startswith('/v1/') and not path.startswith('//'), 'App Store Connect路径异常')
        encode = lambda b: base64.urlsafe_b64encode(b).rstrip(b'=')
        now = int(time.time())
        header = encode(json.dumps(dict(alg='ES256',kid=os.environ['APPLE_API_KEY_ID'],typ='JWT'),separators=(',',':')).encode())
        claims = encode(json.dumps(dict(iss=os.environ['APPLE_API_ISSUER_ID'],iat=now,exp=now+600,aud='appstoreconnect-v1'),separators=(',',':')).encode())
        signing_input = header + b'.' + claims
        result = subprocess.run(['openssl','dgst','-sha256','-sign',str(self.key_path)],input=signing_input,capture_output=True)
        gate.require(result.returncode == 0, '无法生成App Store Connect API签名')
        token = signing_input + b'.' + encode(jwt_signature(result.stdout))
        req = urllib.request.Request('https://api.appstoreconnect.apple.com'+path,
            data=None if data is None else json.dumps(data).encode(),method=method,
            headers={'Authorization':'Bearer '+token.decode(),'Content-Type':'application/json'})
        try:
            with beta.open_url(req,timeout=60) as response:
                content = response.read(2 * 1024 * 1024 + 1)
            gate.require(len(content) <= 2 * 1024 * 1024, 'App Store Connect响应过大')
            return json.loads(content) if content else {}
        except gate.GateError:
            raise
        except Exception:
            raise gate.GateError('App Store Connect请求失败；账号/私钥与原始响应未输出') from None

    def all(self, path):
        result = []
        for _ in range(100):
            value = self.request('GET',path)
            gate.require(isinstance(value.get('data'),list), 'App Store Connect列表无效')
            result.extend(value['data'])
            url = value.get('links',{}).get('next')
            if not url:
                return result
            parsed = urllib.parse.urlsplit(url)
            gate.require(parsed.scheme == 'https' and parsed.netloc == 'api.appstoreconnect.apple.com', '拒绝API跨域分页')
            path = parsed.path + ('?' + parsed.query if parsed.query else '')
        raise gate.GateError('App Store Connect分页超过限制，拒绝忽略旧build水位')


def app_store_preflight(client, context):
    apps = client.all('/v1/apps?' + urllib.parse.urlencode({'filter[bundleId]':BUNDLE,'limit':2}))
    gate.require(len(apps) == 1 and apps[0].get('attributes',{}).get('bundleId') == BUNDLE, 'API Key无法唯一访问生产App')
    app = apps[0]
    builds = client.all('/v1/builds?' + urllib.parse.urlencode({'filter[app]':app['id'],'limit':200}))
    numbers = [x.get('attributes',{}).get('version','') for x in builds]
    gate.require(all(re.fullmatch(r'[1-9][0-9]*', x) for x in numbers), '已有iOS build不是单整数，须人工核对水位')
    gate.require(context['buildNumber'] > max([225,*map(int,numbers)]), 'iOS候选build不高于App Store Connect已上传最大build，禁止重复上传或倒退')
    return app


def upload():
    context = context_read()
    expected = 'verified' if context.get('atomic') else 'published'
    gate.require(context['status'] == expected and context['mode'] == 'testflight',
                 'TestFlight需已签名验包；私有原子候选不得提前发布')
    run = Path(context['run'])
    key_dir = run / 'api'
    key_dir.mkdir(mode=0o700,exist_ok=True)
    key_path = key_dir / ('AuthKey_' + os.environ['APPLE_API_KEY_ID'] + '.p8')
    gate.require(key_path.is_file() and key_path.read_bytes() == api_key(), 'API私钥在构建期间变化')
    client = AppStore(key_path,run)
    app = app_store_preflight(client,context)  # Real ASC high-water read, not a guess from GitHub run_number.
    name = public_names(context['versionName'],context['buildNumber'])[0]
    ipa = Path(context['dist']) / name
    gate.require(gate.sha256(ipa) == context['artifact']['ipaSha256'], 'TestFlight上传前IPA字节改变')
    env = dict(build_environment(),API_PRIVATE_KEYS_DIR=str(key_dir))
    auth = ['--api-key',os.environ['APPLE_API_KEY_ID'],'--api-issuer',os.environ['APPLE_API_ISSUER_ID']]
    command(['xcrun','altool','--validate-app',ipa,'--type','ios',*auth], env=env,label='app-store-validate',run=run)
    command(['xcrun','altool','--upload-app','-f',ipa,'--type','ios',*auth],env=env,label='testflight-upload',run=run)
    context['status'] = 'uploaded-awaiting-processing'
    context_write(context)
    build_record = None
    for _ in range(60):
        values = client.all('/v1/builds?'+urllib.parse.urlencode({'filter[app]':app['id'],'filter[version]':str(context['buildNumber']),'limit':2}))
        gate.require(len(values) <= 1, 'App Store Connect返回重复build身份')
        if values:
            state = values[0].get('attributes',{}).get('processingState')
            gate.require(state not in ('FAILED','INVALID'), 'Apple处理失败；IPA已保留，不能以上传接受冒充TestFlight可测')
            if state == 'VALID':
                build_record = values[0]
                break
        time.sleep(20)
    gate.require(build_record is not None, 'Apple处理等待超时；IPA保留，需到App Store Connect检查，不自动重复上传')
    locale = app.get('attributes',{}).get('primaryLocale')
    gate.require(isinstance(locale,str) and re.fullmatch(r'[A-Za-z0-9-]{2,20}',locale), 'App主语言缺失，无法写入本次内测说明')
    notes = '\n'.join('• '+x for x in context['notificationSummary']) + '\n\n反馈：' + beta.FEEDBACK
    existing = client.all(f'/v1/builds/{build_record["id"]}/betaBuildLocalizations?limit=200')
    matches = [x for x in existing if x.get('attributes',{}).get('locale') == locale]
    gate.require(len(matches) <= 1, 'TestFlight测试说明语言存在歧义')
    data = dict(type='betaBuildLocalizations',attributes=dict(whatsNew=notes))
    if matches:
        data['id'] = matches[0]['id']
        client.request('PATCH',f'/v1/betaBuildLocalizations/{matches[0]["id"]}',dict(data=data))
    else:
        data['attributes']['locale'] = locale
        data['relationships'] = dict(build=dict(data=dict(type='builds',id=build_record['id'])))
        client.request('POST','/v1/betaBuildLocalizations',dict(data=data))
    record = dict(schemaVersion=1,kind='beecount-ios-testflight-upload',sourceSha=context['sourceSha'],
                  versionName=context['versionName'],appVersion=context['appVersion'],buildNumber=context['buildNumber'],
                  ipaSha256=context['artifact']['ipaSha256'],processingState='VALID',uploadAccepted=True,
                  testNotesUpdated=True,usesNonExemptEncryption=build_record.get('attributes',{}).get('usesNonExemptEncryption'),
                  testerAvailability='待维护者在App Store Connect分配测试组；外部测试可能需Beta审核，不自动提审正式版。',
                  workflowRun=os.environ['GITHUB_RUN_ID'])
    receipt_name = f'ios-testflight-{context["buildNumber"]}.json'
    payload = json.dumps(record,ensure_ascii=False,indent=2).encode()
    if not context.get('atomic'):
        beta.GitHub().upload(context['releaseId'],receipt_name,payload)
    (Path(context['dist'])/receipt_name).write_bytes(payload)
    context.update(status='testflight-processed',testflight=record)
    context_write(context)
    print('Apple已处理TestFlight build，简短内测说明已更新；测试组/合规/外部Beta审核状态须另核验')


def telegram_text(context, public_url=''):
    summary = [beta.short_summary_item(x) for x in context['notificationSummary']]
    gate.require(1 <= len(summary) <= 5, 'iOS公告须有1至5条审核后的短摘要')
    lines = ['🐝 蜜蜂记账 · iOS Beta',f'版本：{context["versionName"]}（iOS {context["appVersion"]} / build {context["buildNumber"]}）','']
    lines.extend('• '+x for x in summary)
    lines += ['', 'IPA归档/校验：'+context['releaseUrl'], 'App Store签名IPA不能直接侧载；请通过TestFlight安装。']
    if context['status'] == 'testflight-processed':
        lines += ['TestFlight：Apple已处理，测试组/外部审核以App Store Connect为准。']
        if public_url:
            gate.require(re.fullmatch(r'https://testflight\.apple\.com/join/[A-Za-z0-9]+',public_url) is not None, 'TestFlight公开邀请链接格式无效')
            lines += ['邀请：'+public_url]
    else:
        lines += ['本次仅生成IPA，未上传TestFlight。']
    lines += ['反馈：'+beta.FEEDBACK]
    text = '\n'.join(lines)
    gate.require(len(text) <= 1200, 'iOS Beta公告超长')
    return text


def notify():
    context = context_read()
    gate.require(context['status'] == ('testflight-processed' if context['mode'] == 'testflight' else 'published'), 'iOS交付尚未完整成功，拒绝成功公告')
    token, chat = os.environ.get('TELEGRAM_BOT_TOKEN',''),os.environ.get('TELEGRAM_CHAT_ID','')
    gate.require(bool(token and chat), 'iOS资产已发布，但TG凭据缺失')
    gate.require(re.fullmatch(r'[0-9]+:[A-Za-z0-9_-]+',token), 'TG token格式无效')
    text = telegram_text(context,os.environ.get('TESTFLIGHT_PUBLIC_URL',''))
    payload = urllib.parse.urlencode(dict(chat_id=chat,text=text,disable_web_page_preview='true')).encode()
    try:
        request = urllib.request.Request('https://api.telegram.org/bot'+token+'/sendMessage',data=payload,method='POST')
        with beta.open_url(request,timeout=30) as response:
            value = json.loads(response.read(128*1024))
        gate.require(value.get('ok') is True, 'iOS已交付，但TG未确认送达')
    except gate.GateError:
        raise
    except Exception:
        raise gate.GateError('iOS已交付，但TG通知失败；未输出凭据') from None
    print('iOS Beta Telegram已确认送达')


def notification_plan():
    """Read-only retry, without signing keys, builds, version allocation or uploads."""
    gate.require(os.environ.get('GITHUB_REPOSITORY') == beta.REPOSITORY
                 and os.environ.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
                 and os.environ.get('GITHUB_REF_NAME') == 'v4', '只允许目标仓库v4手动重发通知')
    version = parse_version(os.environ.get('BETA_VERSION','')).name
    client = beta.GitHub()
    release, android = get_release(client,version)
    require_tag(client,version,android['sourceSha'])
    app_version, number = ios_version(version,android['versionCode'],os.environ.get('IOS_BUILD_NUMBER',''),'225')
    names = public_names(version,number)
    by_name = {a['name']:a for a in release.get('assets',[])}
    gate.require(all(n in by_name for n in names), '缺少完整已发布iOS IPA/校验/回执，不能重发成功公告')
    record = client.receipt(by_name[names[2]])
    gate.require(record.get('kind') == 'beecount-ios-beta-release'
                 and record.get('sourceSha') == android['sourceSha']
                 and record.get('versionName') == version
                 and record.get('appVersion') == app_version and record.get('buildNumber') == number
                 and record.get('bundleId') == BUNDLE and record.get('widgetBundleId') == WIDGET
                 and record.get('architecture') == 'arm64'
                 and re.fullmatch(r'[0-9a-f]{64}',record.get('ipaSha256',''))
                 and re.fullmatch(r'[0-9a-f]{64}',record.get('certificateSha256','')),
                 '已发布iOS机器回执身份无效')
    asset = by_name[names[0]]
    gate.require(asset.get('size') == record.get('bytes') and asset['size'] > 0
                 and (asset.get('digest') is None or asset['digest'] == 'sha256:'+record['ipaSha256']),
                 'IPA资产大小/摘要与iOS回执不符')
    tf_name = f'ios-testflight-{number}.json'
    processed = False
    if tf_name in by_name:
        tf = client.receipt(by_name[tf_name])
        gate.require(tf.get('kind') == 'beecount-ios-testflight-upload'
                     and tf.get('sourceSha') == record['sourceSha'] and tf.get('ipaSha256') == record['ipaSha256']
                     and tf.get('appVersion') == app_version and tf.get('buildNumber') == number
                     and tf.get('uploadAccepted') is True and tf.get('processingState') == 'VALID',
                     'TestFlight回执身份无效')
        processed = True
    gate.require(not context_path().exists(), '通知上下文已存在，拒绝覆盖')
    gate.write_private(context_path(),b'{}')
    context_write(dict(status='testflight-processed' if processed else 'published',
        mode='testflight' if processed else 'ipa', versionName=version,appVersion=app_version,
        buildNumber=number,releaseUrl=release['html_url'],notificationSummary=beta.extract_update_summary(release.get('body'))))
    print('已只读核对公开IPA/可选TestFlight回执；没有构建、分配版本或上传')


def cleanup():
    if not context_path().exists():
        return
    context = context_read()
    run = Path(context['run']).resolve()
    gate.require(run.parent == Path(os.environ['RUNNER_TEMP']).resolve() and run.name.startswith('beecount-ios-beta-run-'), '拒绝清理非本轮临时目录')
    errors = []
    try:
        if context.get('keychain'):
            keychain = Path(context['keychain']).resolve()
            gate.require(keychain.parent == run/'signing', 'Keychain清理范围越界')
            if context.get('oldKeychains'):
                result = subprocess.run(['security','list-keychains','-d','user','-s',*context['oldKeychains']],capture_output=True)
                if result.returncode != 0:
                    errors.append('恢复keychain搜索列表失败')
            result = subprocess.run(['security','delete-keychain',str(keychain)],capture_output=True)
            if result.returncode != 0 and keychain.exists():
                errors.append('删除临时keychain失败')
        for name in context.get('profiles',[]):
            path = Path(name)
            gate.require(path.parent == Path.home()/'Library/MobileDevice/Provisioning Profiles'
                         and re.fullmatch(r'[A-Fa-f0-9-]{36}\.mobileprovision',path.name), 'Profile清理路径越界')
            path.unlink(missing_ok=True)
    finally:
        for name in ('signing','api'):
            shutil.rmtree(run/name,ignore_errors=True)
    gate.require(not errors, '临时密钥文件已删除；'+'、'.join(errors))
    print('本轮临时签名材料已清理；未修改任何本机checkout或用户App数据')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['plan','build','publish','upload','notify','notification_plan','cleanup'])
    args = parser.parse_args(argv)
    try:
        globals()[args.action]()
        return 0
    except (gate.GateError,ValueError) as error:
        print('iOS Beta门禁拒绝：'+str(error),file=sys.stderr)
    except Exception:
        print('iOS Beta操作失败；未输出可能含凭据的原始异常。',file=sys.stderr)
    return 2


if __name__ == '__main__':
    raise SystemExit(main())
