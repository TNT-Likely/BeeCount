"""Checks shared with the existing Apple signing tools for an official iOS release."""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
from urllib.parse import urlencode
from zipfile import ZipFile

import ios_beta_release as apple
import local_apk as gate


def apple_build_number(client, floor):
    gate.require(re.fullmatch(r'[1-9][0-9]*', floor), 'iOS 构建号水位必须是正整数')
    apps = client.all('/v1/apps?' + urlencode({'filter[bundleId]': apple.BUNDLE, 'limit': 2}))
    gate.require(len(apps) == 1 and apps[0]['attributes']['bundleId'] == apple.BUNDLE,
                 'App Store Connect 无法唯一确认生产 App')
    builds = client.all('/v1/builds?' + urlencode({'filter[app]': apps[0]['id'], 'limit': 200}))
    numbers = [build['attributes']['version'] for build in builds]
    gate.require(all(re.fullmatch(r'[1-9][0-9]*', number) for number in numbers),
                 'Apple 已上传构建存在非整数版本号，请核对水位')
    return max([299, int(floor), *map(int, numbers)]) + 1


def live_build_number():
    with tempfile.TemporaryDirectory(prefix='asc-preflight-', dir=os.environ['RUNNER_TEMP']) as temp:
        directory = Path(temp)
        key = directory / 'auth.p8'
        gate.write_private(key, apple.api_key())
        client = apple.AppStore(key, directory)
        print(apple_build_number(client, os.environ['IOS_BUILD_NUMBER_FLOOR']))


def locked_pods():
    directory = Path(tempfile.mkdtemp(prefix='pod-config-', dir=os.environ['RUNNER_TEMP']))
    apple.enforce_locked_pods(directory)
    with open(os.environ['GITHUB_ENV'], 'a') as stream:
        for key in ('GEM_PATH', 'RUBYOPT'):
            stream.write(f'{key}={os.environ[key]}\n')
    with open(os.environ['GITHUB_PATH'], 'a') as stream:
        stream.write(str(directory / 'tools') + '\n')


def verify_configuration(config, version, build, metrics_url):
    settings = dict(line.split('=', 1) for line in config.splitlines()
                    if '=' in line and not line.startswith('//'))
    encoded = settings.get('DART_DEFINES', '').split(',')
    defines = dict(base64.b64decode(item, validate=True).decode().split('=', 1)
                   for item in encoded if item)
    expected = {
        'BEECOUNT_SKINS_ENABLED': 'true',
        'BEECOUNT_PAID_SKINS_ENABLED': 'true',
        'BEECOUNT_SKIN_SALES': 'true',
        'BEECOUNT_SKIN_PRODUCTION_SALES': 'true',
        'BEECOUNT_SKIN_METRICS_URL': metrics_url,
    }
    gate.require(all(defines.get(key) == value for key, value in expected.items()) and
                 not any(key.startswith('BEECOUNT_OFFICIAL_QA') for key in defines) and
                 'BEECOUNT_SKIN_PRODUCT_ID' not in defines,
                 '正式构建开关与发布配置不一致')
    gate.require(settings.get('FLUTTER_BUILD_NAME') == version
                 and settings.get('FLUTTER_BUILD_NUMBER') == str(build),
                 'Flutter 归档配置中的版本或构建号不一致')


def verify(version, build, ipa):
    folder = Path(os.environ['RUNNER_TEMP'])
    workspace = Path(os.environ['GITHUB_WORKSPACE'])
    checkouts = workspace / 'release-sources'
    with tempfile.TemporaryDirectory(prefix='store-verification-', dir=folder) as temp:
        directory = Path(temp)
        certificate = apple.command(
            ['openssl', 'pkcs12', '-in', folder / 'build_certificate.p12',
             '-clcerts', '-nokeys', '-passin', 'env:IOS_P12_PASSWORD'],
            label='distribution-certificate', run=directory,
            env={'PATH': os.environ['PATH'], 'IOS_P12_PASSWORD': os.environ['IOS_P12_PASSWORD']},
        )
        pem = re.findall(rb'-----BEGIN CERTIFICATE-----\s+([A-Za-z0-9+/=\s]+)-----END CERTIFICATE-----', certificate)
        gate.require(len(pem) == 1, '分发材料须有唯一叶证书')
        digest = hashlib.sha256(base64.b64decode(pem[0])).hexdigest()
        static = apple.verify_ipa(ipa, {'appVersion': version, 'buildNumber': build},
                                  digest, directory)
    with ZipFile(ipa) as archive:
        app_info, = [name for name in archive.namelist()
                     if re.fullmatch(r'Payload/[^/]+\.app/Info\.plist', name)]
        metadata = plistlib.loads(archive.read(app_info))
        gate.require(metadata.get('ITSAppUsesNonExemptEncryption') is False,
                     '归档缺少已核对的加密合规声明')
        privacy = plistlib.loads(archive.read(app_info.replace('Info.plist', 'PrivacyInfo.xcprivacy')))
        collected = {item['NSPrivacyCollectedDataType']: item
                     for item in privacy['NSPrivacyCollectedDataTypes']}
        expected_privacy_types = {'NSPrivacyCollectedDataType' + data
                                  for data in ('DeviceID', 'ProductInteraction', 'PurchaseHistory')}
        gate.require(expected_privacy_types <= collected.keys()
                     and privacy.get('NSPrivacyTracking') is False
                     and all(collected[data].get('NSPrivacyCollectedDataTypeLinked') is True
                             and collected[data].get('NSPrivacyCollectedDataTypeTracking') is False
                             and collected[data].get('NSPrivacyCollectedDataTypePurposes') ==
                             ['NSPrivacyCollectedDataTypePurposeAnalytics']
                             for data in expected_privacy_types),
                     '归档内的 App 隐私清单和正式申报不一致')
    verify_configuration(Path('ios/Flutter/Generated.xcconfig').read_text(), version,
                         build, os.environ['IOS_SKIN_METRICS_URL'])
    pods = subprocess.check_output(['git', '-C', workspace, 'show', 'HEAD:ios/Podfile.lock'])
    gate.require(Path('ios/Podfile.lock').read_bytes() == pods, '归档的 CocoaPods 依赖锁发生变化')
    with open('ios/ExportOptions.plist', 'rb') as stream:
        options = plistlib.load(stream)
    gate.require(options.get('method') == 'app-store-connect' and
                 options.get('testFlightInternalTestingOnly') is not True,
                 '正式构建必须使用可提审的 App Store 导出')
    sources = {key: subprocess.check_output(['git', '-C', checkout, 'rev-parse', 'HEAD'],
                                           text=True).strip()
               for key, checkout in (('app', workspace), ('skins', checkouts / 'BeeCount-Skins'),
                                     ('commercial', checkouts / 'BeeCount-Commercial'))}
    gate.require(sources['app'] == os.environ['GITHUB_SHA'], '工作流提交与打包源码不一致')
    receipt = {
        'version': version, 'build': build, 'workflowRun': os.environ['GITHUB_RUN_ID'],
        'sources': sources, 'ipaSha256': static['ipaSha256'], 'sdk': static['sdk'],
        'bundleId': static['bundleId'], 'widgetBundleId': static['widgetBundleId'],
    }
    (folder / 'ios-app-store-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print('正式 App / Widget 签名、身份、版本、依赖锁和发布配置核验通过')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_subparsers(dest='action', required=True)
    actions.add_parser('build-number')
    actions.add_parser('locked-pods')
    verify_parser = actions.add_parser('verify')
    verify_parser.add_argument('version')
    verify_parser.add_argument('build', type=int)
    verify_parser.add_argument('ipa', type=Path)
    args = parser.parse_args()
    try:
        if args.action == 'build-number':
            live_build_number()
        elif args.action == 'locked-pods':
            locked_pods()
        else:
            verify(args.version, args.build, args.ipa)
    except (gate.GateError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        parser.exit(1, f'iOS App Store 检查失败：{error}\n')


if __name__ == '__main__':
    main()
