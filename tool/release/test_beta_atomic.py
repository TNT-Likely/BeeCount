"""Synthetic staging/notification gates; does not claim real Apple or signer QA."""
import copy
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import beta_atomic as atomic
import beta_release as android
import beta_metadata as metadata
import ios_beta_release as ios
import local_apk as gate

SHA='a'*40
VERSION='4.0.0-beta.6'

class StageTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.env=mock.patch.dict(os.environ,dict(RUNNER_TEMP=self.temp.name,BETA_ATOMIC='1'));self.env.start();self.addCleanup(self.env.stop)
        self.run=Path(self.temp.name)/'beecount-ios-beta-run-synthetic';self.dist=self.run/'dist';self.dist.mkdir(parents=True)
        self.a=dict(status='verified',sourceSha=SHA,versionName=VERSION,versionCode=231)
        names=ios.public_names(VERSION,231);self.ipa=self.dist/names[0];self.ipa.write_bytes(b'synthetic IPA bytes, not a signed app')
        digest=gate.sha256(self.ipa)
        receipt=dict(schemaVersion=1,kind='beecount-ios-beta-release',sourceSha=SHA,versionName=VERSION,
            androidVersionCode=231,appVersion='4.0.0',buildNumber=231,bundleId=ios.BUNDLE,
            widgetBundleId=ios.WIDGET,architecture='arm64',distribution='app-store',
            dependencyLockUnchanged=True,certificateSha256='b'*64,ipaSha256=digest,bytes=self.ipa.stat().st_size)
        tf=dict(kind='beecount-ios-testflight-upload',sourceSha=SHA,versionName=VERSION,ipaSha256=digest,
            appVersion='4.0.0',buildNumber=231,uploadAccepted=True,processingState='VALID',testNotesUpdated=True)
        (self.dist/names[1]).write_text(digest+'  '+names[0]+'\n');(self.dist/names[2]).write_text(json.dumps(receipt))
        (self.dist/'ios-testflight-231.json').write_text(json.dumps(tf))
        self.i=dict(atomic=True,status='testflight-processed',mode='testflight',sourceSha=SHA,versionName=VERSION,
            androidVersionCode=231,appVersion='4.0.0',buildNumber=231,run=str(self.run),dist=str(self.dist),
            artifact=dict(ipaSha256=digest,bytes=self.ipa.stat().st_size),receipt=receipt,testflight=tf)

    def test_complete_staging_returns_all_four_hash_bound_assets(self):
        assets=atomic.ios_assets(self.a,self.i)
        self.assertEqual(len(assets),4)
        self.assertTrue(all(gate.sha256(Path(x['path']))==x['sha256'] for x in assets))

    def test_incomplete_or_other_source_never_calls_release_creation(self):
        for key,value in [('status','verified'),('atomic',False),('sourceSha','c'*40),('versionName','4.0.0-beta.7'),('androidVersionCode',232)]:
            bad={**self.i,key:value}
            with self.subTest(key=key),mock.patch.object(android,'read_context',return_value=self.a),mock.patch.object(ios,'context_read',return_value=bad),mock.patch.object(android,'publish')as publish:
                with self.assertRaises(gate.GateError):atomic.publish()
                publish.assert_not_called()

    def test_changed_ipa_checksum_receipt_or_missing_processed_result_is_rejected(self):
        self.ipa.write_bytes(b'changed')
        with self.assertRaises(gate.GateError):atomic.ios_assets(self.a,self.i)
        self.ipa.write_bytes(b'synthetic IPA bytes, not a signed app')
        for key,value in [('processingState','PROCESSING'),('testNotesUpdated',False),('uploadAccepted',False)]:
            bad=copy.deepcopy(self.i);bad['testflight'][key]=value
            with self.subTest(key=key),self.assertRaises(gate.GateError):atomic.ios_assets(self.a,bad)
        (self.dist/'ios-testflight-231.json').unlink()
        with self.assertRaises(gate.GateError):atomic.ios_assets(self.a,self.i)

    def test_symlink_ipa_cannot_escape_private_staging(self):
        self.ipa.unlink();self.ipa.symlink_to(Path(self.temp.name)/'outside.ipa')
        with self.assertRaises(gate.GateError):atomic.ios_assets(self.a,self.i)

    def test_ipa_only_mode_requires_verified_signed_stage_and_no_testflight_claim(self):
        candidate={**self.i, 'mode':'ipa','status':'verified'}
        assets=atomic.ios_assets(self.a,candidate)
        self.assertEqual(len(assets),3)


class AtomicPlanTests(unittest.TestCase):
    def test_private_android_candidate_does_not_require_public_release_or_tag(self):
        with tempfile.TemporaryDirectory() as root:
            values=dict(RUNNER_TEMP=root, IOS_BETA_CONTEXT=str(Path(root)/'beecount-ios-beta-context.json'),
                BETA_ATOMIC='1', BETA_VERSION=VERSION, IOS_BETA_MODE='ipa',
                GITHUB_REPOSITORY=android.REPOSITORY, GITHUB_EVENT_NAME='workflow_dispatch',
                GITHUB_REF_NAME='v4', GITHUB_RUN_ID='123')
            a=dict(status='verified',versionName=VERSION,sourceSha=SHA,versionCode=231,
                certificateSha256=android.PRODUCTION_CERTIFICATE,workflowRun='123',notes='## 更新摘要\n- 测试改进。')
            with mock.patch.dict(os.environ,values,clear=True),mock.patch.object(ios,'signing_inputs'),mock.patch.object(android,'GitHub'),mock.patch.object(android,'read_context',return_value=a),mock.patch.object(android,'source_sha',return_value=SHA),mock.patch.object(ios,'published_ios_floor',return_value=230),mock.patch.object(ios,'get_release')as public,mock.patch.object(ios,'require_tag')as tag:
                ios.plan();state=ios.context_read()
                self.assertTrue(state['atomic']);self.assertEqual(state['buildNumber'],231)
                self.assertIsNone(state['releaseId']);public.assert_not_called();tag.assert_not_called()
                state['status']='verified';ios.context_write(state)
                with self.assertRaises(gate.GateError):ios.publish()
                public.assert_not_called()


class AnnouncementTests(unittest.TestCase):
    def setUp(self):
        self.context=dict(status='published',versionName=VERSION,sourceSha=SHA,versionCode=231)
        self.i=dict(status='testflight-processed',buildNumber=231)
        self.identity=atomic.notification_identity(self.context,self.i)
        self.client=mock.Mock();self.release=dict(id=7,assets=[])
        self.patches=[mock.patch.object(atomic.delivery,'notification_plan'),mock.patch.object(android,'read_context',return_value=self.context),mock.patch.object(ios,'context_read',return_value=self.i),mock.patch.object(android,'GitHub',return_value=self.client),mock.patch.object(ios,'get_release',return_value=(self.release,{})),mock.patch.object(android,'notify',return_value=123),mock.patch.dict(os.environ,dict(BETA_EXPECT_TESTFLIGHT='1'),clear=False)]
        self.handles=[p.start()for p in self.patches]
        for p in self.patches:self.addCleanup(p.stop)
        self.notify=self.handles[5]
        os.environ.pop('BETA_NOTIFICATION_MANUAL_RETRY',None)

    def record(self,kind):return dict(schemaVersion=1,kind=kind,**self.identity)

    def test_first_success_sends_once_between_persisted_intent_and_ack(self):
        events=[]
        def request(method,path,data=None):
            if method=='PATCH':
                self.release.update(data)
                records=metadata.records(self.release)
                events.append(atomic.ACK if atomic.ACK in records else atomic.INTENT)
            return self.release.copy()
        self.client.request.side_effect=request
        self.notify.side_effect=lambda:events.append('TG')or 123
        atomic.announce()
        self.assertEqual(events,[atomic.INTENT,'TG',atomic.ACK])
        self.notify.assert_called_once()
        self.client.upload.assert_not_called()
        self.assertEqual(metadata.records(self.release)[atomic.ACK]['messageId'],123)

    def test_already_acknowledged_release_never_sends_or_uploads_again(self):
        self.release['assets']=[dict(name=atomic.ACK)]
        self.client.receipt.return_value=self.record('beecount-beta-notification-ack')
        atomic.announce();self.notify.assert_not_called();self.client.upload.assert_not_called()

    def test_unknown_send_state_does_not_automatically_retry(self):
        self.release['assets']=[dict(name=atomic.INTENT)]
        self.client.receipt.return_value=self.record('beecount-beta-notification-intent')
        with self.assertRaises(gate.GateError):atomic.announce()
        self.notify.assert_not_called()

    def test_only_explicit_manual_retry_can_continue_unacknowledged_intent(self):
        self.release['assets']=[dict(name=atomic.INTENT)];self.client.receipt.return_value=self.record('beecount-beta-notification-intent')
        def request(method,path,data=None):
            if method=='PATCH':self.release.update(data)
            return self.release.copy()
        self.client.request.side_effect=request
        with mock.patch.dict(os.environ,dict(BETA_NOTIFICATION_MANUAL_RETRY='1')):atomic.announce()
        self.notify.assert_called_once();self.client.upload.assert_not_called()
        self.assertIn(atomic.ACK,metadata.records(self.release))

    def test_intent_upload_failure_never_sends(self):
        self.client.request.side_effect=gate.GateError('synthetic metadata failure')
        with self.assertRaises(gate.GateError):atomic.announce()
        self.notify.assert_not_called()

    def test_mismatched_ack_and_incomplete_testflight_are_refused(self):
        self.release['assets']=[dict(name=atomic.ACK)]
        self.client.receipt.return_value={**self.record('beecount-beta-notification-ack'),'sourceSha':'f'*40}
        with self.assertRaises(gate.GateError):atomic.announce()
        self.notify.assert_not_called()
        self.i['status']='published';self.release['assets']=[]
        with self.assertRaises(gate.GateError):atomic.announce()
        self.notify.assert_not_called()


if __name__=='__main__':unittest.main()
