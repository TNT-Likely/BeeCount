"""Offline iOS release gates, synthetic profile/IPA identities and temp Xcode config.

No real secrets, signing, App Store/GitHub mutations, device operations or uploads.
Identity fixtures do not pretend to prove real codesign or TestFlight delivery.
"""
import base64
import contextlib
import copy
import datetime as dt
import hashlib
import io
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock

import ios_beta_release as ios
import beta_release as beta
import local_apk as gate

TEAM = 'ABCDEFGHIJ'
SHA = 'a' * 40
NOW = dt.datetime(2026, 11, 5, tzinfo=dt.timezone.utc)
KEY = b'-----BEGIN PRIVATE KEY-----\nYWJj\n-----END PRIVATE KEY-----'


def profile(bundle=ios.BUNDLE):
    return dict(UUID='12345678-1234-1234-1234-123456789abc',TeamIdentifier=[TEAM],
        ExpirationDate=NOW+dt.timedelta(days=60),DeveloperCertificates=[b'synthetic-certificate'],
        Entitlements={'application-identifier':TEAM+'.'+bundle,'get-task-allow':False,
            'beta-reports-active':True,'com.apple.security.application-groups':[ios.GROUP],
            'com.apple.developer.icloud-container-identifiers':['iCloud.'+ios.BUNDLE]})


def env():
    values={k:base64.b64encode(b'synthetic-not-a-real-secret').decode() for k in ios.SIGNING_KEYS}
    values.update(APPLE_TEAM_ID=TEAM,APPLE_CERTIFICATE_PASSWORD='synthetic-password',
                  APPLE_API_KEY_ID='123456789A',APPLE_API_ISSUER_ID='11111111-2222-3333-4444-555555555555',
                  APPLE_API_KEY_CONTENT=KEY.decode())
    return values


def android_record():
    return dict(schemaVersion=1,kind='beecount-beta-release',package=gate.PACKAGE,
        sourceSha=SHA,versionName='4.0.0-beta.5',versionCode=230,abi=gate.ABI,
        apkSha256='b'*64,certificateSha256=beta.PRODUCTION_CERTIFICATE)


class VersionAndInputTests(unittest.TestCase):
    def test_beta_name_is_mapped_to_numeric_apple_version_and_shared_code(self):
        self.assertEqual(ios.ios_version('4.0.0-beta.5',230),('4.0.0',230))
        self.assertEqual(ios.ios_version('4.0.0-beta.5',230,'231','229'),('4.0.0',231))
    def test_beta_rejects_stable_low_floor_reuse_and_crosses_stable_reserved_range(self):
        for version,code,explicit,floor in [('4.0.0',300,'','299'),('4.0.0-beta.5',230,'229','225'),
            ('4.0.0-beta.5',230,'230','230'),('4.0.0-beta.5',230,'300','229'),
            ('4.0.0-beta.5',230,'$(id)','225'),('4.0.0-beta.5',230,'','')]:
            with self.subTest(version=version,explicit=explicit,floor=floor), self.assertRaises((gate.GateError,ValueError)):
                ios.ios_version(version,code,explicit,floor)
    def test_ipa_mode_needs_both_distribution_profiles_but_no_api_key(self):
        values=env()
        for key in ios.API_KEYS:values.pop(key)
        with mock.patch.dict(os.environ,values,clear=True):
            self.assertNotIn('apiKey',ios.signing_inputs('ipa'))
            with self.assertRaises(gate.GateError):ios.signing_inputs('testflight')
        for key in ios.SIGNING_KEYS:
            missing=env();missing.pop(key)
            with self.subTest(key=key),mock.patch.dict(os.environ,missing,clear=True),self.assertRaises(gate.GateError):
                ios.signing_inputs('ipa')
    def test_bad_signing_base64_is_rejected_before_sdk(self):
        values=env();values['APPLE_PROVISIONING_PROFILE_WIDGET']='**not-base64**'
        with mock.patch.dict(os.environ,values,clear=True),self.assertRaises(gate.GateError):ios.signing_inputs('ipa')
    def test_api_key_accepts_pkcs8_pem_or_base64_without_printing(self):
        for value in [KEY.decode(),base64.b64encode(KEY).decode()]:
            values=env();values['APPLE_API_KEY_CONTENT']=value
            with mock.patch.dict(os.environ,values,clear=True):self.assertEqual(ios.api_key(),KEY)
        values=env();values['APPLE_API_KEY_CONTENT']='not a key'
        with mock.patch.dict(os.environ,values,clear=True),self.assertRaises(gate.GateError):ios.api_key()
    def test_api_key_normalizes_json_env_and_base64_escaped_newlines(self):
        import json
        escaped = KEY.decode().replace('\n', r'\n')
        for value in [escaped, json.dumps(KEY.decode()),
                      base64.b64encode(escaped.encode()).decode(),
                      '\ufeff' + KEY.decode(), KEY.decode().replace('\n', '\r\n')]:
            values = env(); values['APPLE_API_KEY_CONTENT'] = value
            with self.subTest(encoding=value[:8]), mock.patch.dict(os.environ,values,clear=True):
                self.assertEqual(ios.api_key(),KEY)
        for value in ['"not a key"', '{"key":"not a PEM"}', 'AuthKey_SYNTHETIC.p8']:
            values = env(); values['APPLE_API_KEY_CONTENT'] = value
            with mock.patch.dict(os.environ,values,clear=True), self.assertRaises(gate.GateError):
                ios.api_key()

    def test_build_subprocess_environment_excludes_all_credentials(self):
        values={**env(),'GH_TOKEN':'secret','GITHUB_TOKEN':'secret','TELEGRAM_BOT_TOKEN':'secret',
                'TELEGRAM_CHAT_ID':'private','PATH':'/bin','FLUTTER_ROOT':'/sdk'}
        with mock.patch.dict(os.environ,values,clear=True):clean=ios.build_environment()
        self.assertEqual(clean,dict(PATH='/bin',FLUTTER_ROOT='/sdk'))
    def test_public_names_cannot_mislabel_app_store_ipa_as_installable_ad_hoc(self):
        names=ios.public_names('4.0.0-beta.5',230)
        self.assertTrue(names[0].endswith('-ios-230-app-store.ipa'))
        self.assertEqual(names[2],'ios-release-230.json')


class PodDeploymentTests(unittest.TestCase):
    def test_implicit_flutter_pod_install_is_forced_into_deployment_mode(self):
        with tempfile.TemporaryDirectory()as tmp:
            root=Path(tmp);original=root/'original pod'
            capture=root/'arguments.json'
            original.write_text('#!/usr/bin/env python3\nimport json,sys\nopen('+repr(str(capture))+',"w").write(json.dumps(sys.argv[1:]))\n')
            original.chmod(0o700)
            with mock.patch.dict(os.environ,dict(PATH=os.environ.get('PATH',''))),mock.patch.object(ios.shutil,'which',return_value=str(original)),mock.patch.object(ios,'command',return_value=b'1.16.2\n'):
                ios.enforce_locked_pods(root)
                subprocess.run([str(root/'tools/pod'),'install','--verbose'],check=True)
                self.assertEqual(json.loads(capture.read_text()),['install','--verbose','--deployment'])
                subprocess.run([str(root/'tools/pod'),'_1.16.2_','install','--deployment'],check=True)
                self.assertEqual(json.loads(capture.read_text()),['_1.16.2_','install','--deployment'])
    def test_wrong_pod_version_is_rejected(self):
        with tempfile.TemporaryDirectory()as tmp,mock.patch.object(ios.shutil,'which',return_value='/fake/pod'),mock.patch.object(ios,'command',return_value=b'1.17.0\n'),self.assertRaises(gate.GateError):
            ios.enforce_locked_pods(Path(tmp))


class ProfileTests(unittest.TestCase):
    def test_main_and_widget_distribution_profiles_pass_with_the_same_leaf_certificate(self):
        for bundle in (ios.BUNDLE,ios.WIDGET):
            ios.profile_gate(profile(bundle),bundle,TEAM,b'synthetic-certificate',NOW)
    def test_expired_wrong_team_bundle_debug_ad_hoc_enterprise_cert_or_groups_are_rejected(self):
        changes=[lambda x:x.update(ExpirationDate=NOW-dt.timedelta(seconds=1)),
            lambda x:x.update(TeamIdentifier=['OTHERTEAM0']),
            lambda x:x['Entitlements'].update({'application-identifier':TEAM+'.com.other.app'}),
            lambda x:x['Entitlements'].update({'get-task-allow':True}),
            lambda x:x['Entitlements'].update({'beta-reports-active':False}),
            lambda x:x.update(ProvisionedDevices=['fake-device']),lambda x:x.update(ProvisionsAllDevices=True),
            lambda x:x.update(DeveloperCertificates=[b'other']),
            lambda x:x['Entitlements'].update({'com.apple.security.application-groups':[]}),
            lambda x:x['Entitlements'].update({'com.apple.developer.icloud-container-identifiers':[]})]
        for index,change in enumerate(changes):
            value=profile();change(value)
            with self.subTest(case=index),self.assertRaises(gate.GateError):
                ios.profile_gate(value,ios.BUNDLE,TEAM,b'synthetic-certificate',NOW)
    def test_profile_uuid_must_be_safe_for_cleanup_filename(self):
        value=profile();value['UUID']='../../elsewhere'
        with self.assertRaises(gate.GateError):ios.profile_gate(value,ios.BUNDLE,TEAM,now=NOW)


class SyntheticIpaIdentityTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.app=Path(self.tmp.name)/'Runner.app';self.widget=self.app/'PlugIns/BeeCount.appex'
        self.context=dict(appVersion='4.0.0',buildNumber=230)
        for path,bundle in [(self.app,ios.BUNDLE),(self.widget,ios.WIDGET)]:
            path.mkdir(parents=True,exist_ok=True)
            value=dict(CFBundleIdentifier=bundle,CFBundleShortVersionString='4.0.0',CFBundleVersion='230',
                       CFBundleExecutable='Runner',DTPlatformName='iphoneos',DTSDKName='iphoneos26.2')
            (path/'Info.plist').write_bytes(plistlib.dumps(value));(path/'Runner').write_bytes(b'synthetic-non-executable')
    def test_synthetic_identity_only_accepts_main_and_widget_matching_versions(self):
        self.assertEqual(len(ios.validate_ipa_tree(self.app,self.context,TEAM)),2)
    def test_synthetic_identity_rejects_qa_buildnumber_mismatch_simulator_and_old_sdk(self):
        for key,value in [('CFBundleIdentifier',ios.BUNDLE+'.qa'),('CFBundleVersion','229'),
                          ('CFBundleShortVersionString','4.0.0-beta.5'),('DTPlatformName','iphonesimulator'),
                          ('DTSDKName','iphoneos18.5'),('CFBundleExecutable','../../outside')]:
            original=(self.widget/'Info.plist').read_bytes();record=plistlib.loads(original);record[key]=value
            (self.widget/'Info.plist').write_bytes(plistlib.dumps(record))
            with self.subTest(key=key),self.assertRaises(gate.GateError):ios.validate_ipa_tree(self.app,self.context,TEAM)
            (self.widget/'Info.plist').write_bytes(original)
    def test_missing_widget_and_multiple_extensions_are_rejected(self):
        shutil.rmtree(self.widget)
        with self.assertRaises(gate.GateError):ios.validate_ipa_tree(self.app,self.context,TEAM)


class AppStoreApiTests(unittest.TestCase):
    def test_real_openssl_synthetic_p256_signature_has_jose_size(self):
        with tempfile.TemporaryDirectory()as tmp:
            key=Path(tmp)/'fake.p8'
            subprocess.run(['openssl','genpkey','-algorithm','EC','-pkeyopt','ec_paramgen_curve:P-256','-out',str(key)],check=True,capture_output=True)
            signed=subprocess.run(['openssl','dgst','-sha256','-sign',str(key)],input=b'synthetic JWT signing input',check=True,capture_output=True).stdout
            converted=ios.jwt_signature(signed)
            self.assertEqual(len(converted),64);self.assertNotEqual(converted,b'\0'*64)
    def test_invalid_der_signatures_are_rejected(self):
        for value in [b'',b'\x30',b'\x30\x02\x02\x00',b'\x30\x06\x02\x01\x80\x02\x01\x01',b'\x30\x06\x02\x01\x00\x02\x01\x01']:
            with self.subTest(value=value),self.assertRaises(gate.GateError):ios.jwt_signature(value)
    def test_preflight_requires_exact_app_and_candidate_above_all_uploaded_builds(self):
        client=mock.Mock();client.all.side_effect=[[dict(id='1',attributes=dict(bundleId=ios.BUNDLE))],
                                                [dict(attributes=dict(version='225')),dict(attributes=dict(version='229'))]]
        ios.app_store_preflight(client,dict(buildNumber=230))
        client.all.side_effect=[[dict(id='1',attributes=dict(bundleId=ios.BUNDLE))],[dict(attributes=dict(version='230'))]]
        with self.assertRaises(gate.GateError):ios.app_store_preflight(client,dict(buildNumber=230))
    def test_preflight_refuses_ambiguous_app_and_non_integer_existing_builds(self):
        client=mock.Mock();client.all.return_value=[]
        with self.assertRaises(gate.GateError):ios.app_store_preflight(client,dict(buildNumber=230))
        client.all.side_effect=[[dict(id='1',attributes=dict(bundleId=ios.BUNDLE))],[dict(attributes=dict(version='1.2'))]]
        with self.assertRaises(gate.GateError):ios.app_store_preflight(client,dict(buildNumber=230))
    def test_api_pagination_refuses_foreign_origin(self):
        client=ios.AppStore(Path('/does/not/exist'),Path('/not-used'))
        with mock.patch.object(client,'request',return_value=dict(data=[],links=dict(next='https://evil.invalid/v1/builds'))),self.assertRaises(gate.GateError):
            client.all('/v1/builds')


class PublishedBetaAndNotificationTests(unittest.TestCase):
    def test_only_existing_public_prerelease_and_trusted_android_receipt_are_accepted(self):
        client=mock.Mock();client.request.return_value=dict(id=1,tag_name='4.0.0-beta.5',draft=False,prerelease=True,assets=[dict(name=beta.RECEIPT)])
        client.receipt.return_value=android_record()
        ios.get_release(client,'4.0.0-beta.5')
        client.request.return_value['draft']=True
        with self.assertRaises(gate.GateError):ios.get_release(client,'4.0.0-beta.5')
    def test_published_ios_receipts_raise_floor_and_bad_receipt_is_not_ignored(self):
        client=mock.Mock();client.releases.return_value=[dict(tag_name='4.0.0-beta.4',assets=[dict(name='ios-release-240.json')])]
        record=dict(schemaVersion=1,kind='beecount-ios-beta-release',bundleId=ios.BUNDLE,widgetBundleId=ios.WIDGET,versionName='4.0.0-beta.4',buildNumber=240,androidVersionCode=229,sourceSha=SHA,ipaSha256='b'*64,appVersion='4.0.0')
        client.receipt.return_value=record
        self.assertEqual(ios.published_ios_floor(client,'225'),'240')
        record['bundleId']=ios.BUNDLE+'.qa'
        with self.assertRaises(gate.GateError):ios.published_ios_floor(client,'225')
    def test_tag_identity_must_match_existing_android_source(self):
        client=mock.Mock();client.request.return_value=dict(object=dict(type='commit',sha='b'*40))
        with self.assertRaises(gate.GateError):ios.require_tag(client,'4.0.0-beta.5',SHA)
    def test_notify_labels_ipa_non_installable_and_distinguishes_testflight_processing(self):
        context=dict(versionName='4.0.0-beta.5',appVersion='4.0.0',buildNumber=230,
                     notificationSummary=['短更新']*5,releaseUrl='https://github.com/TNT-Likely/BeeCount/releases/tag/4.0.0-beta.5',status='published')
        text=ios.telegram_text(context)
        self.assertIn('不能直接侧载',text);self.assertIn('未上传TestFlight',text);self.assertIn(beta.FEEDBACK,text)
        context['status']='testflight-processed';text=ios.telegram_text(context,'https://testflight.apple.com/join/AbCd1234')
        self.assertIn('外部审核',text);self.assertIn('AbCd1234',text);self.assertNotIn(SHA,text);self.assertLessEqual(len(text),1200)
        with self.assertRaises(gate.GateError):ios.telegram_text(context,'https://evil.invalid')
    def test_notification_only_is_read_only_and_needs_no_apple_secrets(self):
        with tempfile.TemporaryDirectory()as tmp:
            values=dict(GITHUB_REPOSITORY=beta.REPOSITORY,GITHUB_EVENT_NAME='workflow_dispatch',GITHUB_REF_NAME='v4',
                        BETA_VERSION='4.0.0-beta.5',RUNNER_TEMP=tmp,IOS_BETA_CONTEXT=tmp+'/beecount-ios-beta-notify.json')
            names=ios.public_names('4.0.0-beta.5',230)
            receipt=dict(kind='beecount-ios-beta-release',sourceSha=SHA,versionName='4.0.0-beta.5',appVersion='4.0.0',buildNumber=230,
                         bundleId=ios.BUNDLE,widgetBundleId=ios.WIDGET,architecture='arm64',ipaSha256='c'*64,certificateSha256='d'*64,bytes=123)
            release=dict(id=1,tag_name='4.0.0-beta.5',draft=False,prerelease=True,body='## 更新摘要\n- 有效短更新\n\n## 安装\n仅测试',
                         html_url='https://github.com/TNT-Likely/BeeCount/releases/tag/4.0.0-beta.5',
                         assets=[dict(name=beta.RECEIPT),*[dict(name=n,size=123,digest='sha256:'+'c'*64) for n in names]])
            client=mock.Mock();client.request.side_effect=[release,dict(object=dict(type='commit',sha=SHA))]
            client.receipt.side_effect=[android_record(),receipt]
            with mock.patch.dict(os.environ,values,clear=True),mock.patch.object(beta,'GitHub',return_value=client):
                ios.notification_plan();actual=ios.context_read()
            self.assertEqual(actual['status'],'published')
            self.assertTrue(all(c.args[0]=='GET' for c in client.request.call_args_list));client.upload.assert_not_called()
    def test_wrong_branch_or_invalid_context_cannot_run_plan(self):
        with mock.patch.dict(os.environ,dict(GITHUB_REPOSITORY=beta.REPOSITORY,GITHUB_EVENT_NAME='workflow_dispatch',GITHUB_REF_NAME='main'),clear=True),self.assertRaises(gate.GateError):ios.plan()
        with mock.patch.dict(os.environ,dict(RUNNER_TEMP='/tmp',IOS_BETA_CONTEXT='/outside/context.json'),clear=True),self.assertRaises(gate.GateError):ios.context_path()


class TemporaryXcodeConfigTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('ruby'),'Ruby not available')
    def test_only_release_profile_app_and_widget_are_changed_in_temp_project(self):
        probe=subprocess.run(['ruby','-e','require "xcodeproj"'],capture_output=True)
        if probe.returncode:self.skipTest('xcodeproj gem not installed')
        root=Path(__file__).resolve().parents[2]
        original=root/'ios/Runner.xcodeproj/project.pbxproj';before=hashlib.sha256(original.read_bytes()).hexdigest()
        with tempfile.TemporaryDirectory()as tmp:
            project=Path(tmp)/'Runner.xcodeproj';project.mkdir();shutil.copy2(original,project/'project.pbxproj')
            inspect='require "xcodeproj";require "json";p=Xcodeproj::Project.open(ARGV[0]);puts JSON.generate(p.targets.to_h{|t|[t.name,t.build_configurations.to_h{|c|[c.name,c.build_settings]}]})'
            read=lambda:json.loads(subprocess.check_output(['ruby','-e',inspect,str(project)]))
            prior=read();config=Path(tmp)/'config.json';config.write_text(json.dumps(dict(team=TEAM,certificate='A'*40,mainProfile='1'*36,widgetProfile='2'*36,appVersion='4.0.0',buildNumber='230')))
            subprocess.run(['ruby',str(root/'tool/release/configure_ios_beta_signing.rb'),str(project),str(config)],check=True,capture_output=True)
            after=read()
            self.assertEqual(prior['RunnerTests'],after['RunnerTests'])
            for target,bundle in [('Runner',ios.BUNDLE),('BeeCountWidgetExtension',ios.WIDGET)]:
                self.assertEqual(prior[target]['Debug'],after[target]['Debug'])
                for mode in ['Release','Profile']:
                    settings=after[target][mode]
                    self.assertEqual(settings['PRODUCT_BUNDLE_IDENTIFIER'],bundle)
                    self.assertEqual(settings['CURRENT_PROJECT_VERSION'],'230')
                    self.assertEqual(settings['MARKETING_VERSION'],'4.0.0')
                    self.assertEqual(settings['CODE_SIGN_STYLE'],'Manual')
                    self.assertEqual(settings['DEVELOPMENT_TEAM'],TEAM)
                    self.assertTrue(all(settings[k]=='A'*40 for k in settings if k.startswith('CODE_SIGN_IDENTITY')))
        self.assertEqual(hashlib.sha256(original.read_bytes()).hexdigest(),before)


if __name__=='__main__':unittest.main()
