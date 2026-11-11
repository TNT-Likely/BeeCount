"""Release-body storage and legacy compatibility, without network or binaries."""
import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import beta_metadata as meta
import beta_release as beta
import ios_beta_release as ios
import local_apk as gate


def android_record(version='4.0.0-beta.6', code=231):
    return dict(schemaVersion=1, kind='beecount-beta-release', package=gate.PACKAGE,
                versionName=version, versionCode=code, sourceSha='a'*40,
                certificateSha256=beta.PRODUCTION_CERTIFICATE, apkSha256='b'*64, abi=gate.ABI)


class BodyStorageTests(unittest.TestCase):
    def test_round_trip_preserves_curated_notes_and_uses_no_extra_asset(self):
        notes = '# 内测\n\n## 更新摘要\n- 首页更清晰。\n\n## 安装\n请保留原数据。\n'
        record = android_record()
        body = meta.with_records(notes, {beta.RECEIPT: record})
        self.assertTrue(body.startswith(notes.rstrip()))
        self.assertEqual(body.count(meta.PREFIX), 1)
        self.assertEqual(meta.records({'body':body}), {beta.RECEIPT:record})
        client = mock.Mock()
        self.assertEqual(meta.read(client, dict(body=body, assets=[]), beta.RECEIPT), record)
        client.receipt.assert_not_called()
        self.assertEqual(beta.extract_update_summary(body), ['首页更清晰。'])

    def test_immutable_append_and_identical_retry(self):
        body = meta.with_records('notes', {'android-release.json': {'value': 1}})
        self.assertEqual(meta.with_records(body, {'android-release.json': {'value': 1}}), body)
        with self.assertRaises(gate.GateError):
            meta.with_records(body, {'android-release.json': {'value': 2}})
        updated = meta.with_records(body, {'ios-release-231.json': {'value': 3}})
        self.assertEqual(len(meta.records({'body':updated})), 2)

    def test_legacy_beta_assets_are_read_without_migration(self):
        release = dict(body='old notes',assets=[dict(name=beta.RECEIPT,id=1)])
        client = mock.Mock();client.receipt.return_value = android_record()
        self.assertEqual(meta.read(client,release,beta.RECEIPT), android_record())
        client.request.assert_not_called();client.upload.assert_not_called()

    def test_duplicate_records_and_corrupted_markers_refuse(self):
        body = meta.with_records('notes', {beta.RECEIPT: android_record()})
        for release in [dict(body=body+body),dict(body=body.replace(':v1:',':v8:')),
                        dict(body=body.replace(' -->',' invalid -->')),
                        dict(body=body,assets=[dict(name=beta.RECEIPT,id=1)]),
                        dict(assets=[dict(name=beta.RECEIPT,id=1),dict(name=beta.RECEIPT,id=2)])]:
            with self.subTest(release=release),self.assertRaises(gate.GateError):
                meta.names(release)
        for name,record in [('../bad.json',{}),('token.json',[]),('x.sha256',{})]:
            with self.assertRaises(gate.GateError):meta.with_records('',{name:record})
        with self.assertRaises(gate.GateError):meta.with_records('',{'x.json':dict(value='x'*meta.MAX_BYTES)})

    def test_fresh_notes_are_preserved_and_ack_does_not_remove_intent(self):
        old = dict(id=7,body=meta.with_records('original notes',{'beta-notification-intent.json':{'id':1}}),assets=[])
        remote = copy.deepcopy(old);remote['body']=remote['body'].replace('original notes','edited notes')
        client = mock.Mock()
        def request(method,path,data=None):
            if method=='PATCH':remote.update(data)
            return copy.deepcopy(remote)
        client.request.side_effect=request
        meta.save(client,old,'beta-notification.json',{'id':2})
        self.assertIn('edited notes',remote['body'])
        self.assertEqual(len(meta.records(remote)),2)
        client.upload.assert_not_called()

    def test_removed_intent_or_unconfirmed_patch_refuses(self):
        old = dict(id=7,body=meta.with_records('notes',{'beta-notification-intent.json':{'id':1}}),assets=[])
        client=mock.Mock();client.request.return_value=dict(id=7,body='notes',assets=[])
        with self.assertRaises(gate.GateError):meta.save(client,old,'beta-notification.json',{'id':2})
        self.assertTrue(all(c.args[0]=='GET'for c in client.request.call_args_list))

    def test_embedded_android_floor_prevents_reusing_or_downgrading_code(self):
        release=dict(tag_name='4.0.0-beta.6',draft=False,body=meta.with_records('notes',
            {beta.RECEIPT:android_record()}),assets=[dict(name='candidate.apk')])
        client=mock.Mock()
        candidate,floor=beta.release_floor(client,[release],'225','4.0.0-beta.7')
        self.assertEqual((candidate.code,floor),(232,231))
        client.receipt.assert_not_called()
        with self.assertRaises((ValueError,gate.GateError)):
            beta.release_floor(client,[release],'225','4.0.0-beta.5')

    def test_embedded_ios_floor_and_wrong_identity(self):
        record=dict(schemaVersion=1,kind='beecount-ios-beta-release',bundleId=ios.BUNDLE,
            widgetBundleId=ios.WIDGET,versionName='4.0.0-beta.6',buildNumber=240,
            androidVersionCode=231,sourceSha='a'*40,ipaSha256='b'*64,appVersion='4.0.0')
        release=dict(tag_name='4.0.0-beta.6',body=meta.with_records('',{'ios-release-240.json':record}))
        client=mock.Mock();client.releases.return_value=[release]
        self.assertEqual(ios.published_ios_floor(client,'230'),'240')
        record['bundleId']+='.qa';release['body']=meta.with_records('',{'ios-release-240.json':record})
        with self.assertRaises(gate.GateError):ios.published_ios_floor(client,'230')

    def test_two_binary_release_retries_ios_notification_from_embedded_receipts(self):
        """No JSON/checksum assets or Apple credentials are needed for retries."""
        version = '4.0.0-beta.6'
        name = ios.public_names(version, 231)[0]
        receipt = dict(kind='beecount-ios-beta-release', sourceSha='a'*40,
            versionName=version, appVersion='4.0.0', buildNumber=231,
            bundleId=ios.BUNDLE, widgetBundleId=ios.WIDGET, architecture='arm64',
            ipaSha256='c'*64, certificateSha256='d'*64, bytes=123)
        tf = dict(kind='beecount-ios-testflight-upload', sourceSha='a'*40,
            ipaSha256='c'*64, appVersion='4.0.0', buildNumber=231,
            uploadAccepted=True, processingState='VALID')
        body = meta.with_records('## 更新摘要\n- 首页新增紧凑汇总\n', {
            beta.RECEIPT: android_record(), 'ios-release-231.json': receipt,
            'ios-testflight-231.json': tf})
        release = dict(id=7, tag_name=version, draft=False, prerelease=True,
            body=body, html_url='https://github.com/TNT-Likely/BeeCount/releases/tag/'+version,
            assets=[dict(name='candidate.apk'), dict(name=name,size=123,digest='sha256:'+'c'*64)])
        client = mock.Mock()
        client.request.side_effect = [release, dict(object=dict(type='commit',sha='a'*40))]
        with tempfile.TemporaryDirectory() as tmp:
            values = dict(GITHUB_REPOSITORY=beta.REPOSITORY,GITHUB_EVENT_NAME='workflow_dispatch',
                GITHUB_REF_NAME='v4',BETA_VERSION=version,RUNNER_TEMP=tmp,
                IOS_BETA_CONTEXT=str(Path(tmp)/'beecount-ios-beta-notify.json'))
            with mock.patch.dict(os.environ,values,clear=True),mock.patch.object(beta,'GitHub',return_value=client):
                ios.notification_plan()
                self.assertEqual(ios.context_read()['status'],'testflight-processed')
        client.receipt.assert_not_called()
        client.upload.assert_not_called()
        self.assertTrue(all(c.args[0]=='GET' for c in client.request.call_args_list))


if __name__=='__main__':unittest.main()
