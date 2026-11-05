"""Unified delivery gates: real platform success requires its public receipt."""
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import beta_delivery as delivery
import beta_release as android
import local_apk as gate


class DeliveryTests(unittest.TestCase):
    def test_missing_ios_is_an_explicit_partial_delivery(self):
        for status in ('failure', 'cancelled', 'skipped', ''):
            lines = delivery.platform_lines(None, status)
            self.assertIn('尚未完成', lines[1])
            self.assertNotIn('已处理', '\n'.join(lines))
        with self.assertRaises(gate.GateError):
            delivery.platform_lines(None, 'success')

    def test_ipa_cannot_be_announced_as_installable_or_testflight_ready(self):
        lines = delivery.platform_lines(dict(status='published', buildNumber=230), 'success')
        self.assertIn('不能直接侧载', lines[1])
        self.assertNotIn('Apple已处理', '\n'.join(lines))

    def test_processed_build_preserves_apple_group_review_limitation(self):
        context = dict(status='testflight-processed', buildNumber=230)
        lines = delivery.platform_lines(context, 'success', 'https://testflight.apple.com/join/Abcd1234')
        self.assertIn('外部审核', lines[1])
        self.assertEqual(len(lines), 3)
        with self.assertRaises(gate.GateError):
            delivery.platform_lines(context, 'success', 'https://evil.example/join/1234')

    def test_unknown_ci_result_is_rejected(self):
        with self.assertRaises(gate.GateError):
            delivery.platform_lines(None, 'ok')

    def test_curated_summary_stays_bounded_with_both_platforms(self):
        context = dict(versionName='4.0.0-beta.5', versionCode=230,
            releaseUrl='https://github.com/TNT-Likely/BeeCount/releases/tag/4.0.0-beta.5',
            notificationSummary=['修复界面问题']*5,
            platformLines=delivery.platform_lines(dict(status='testflight-processed',buildNumber=230),'success'))
        text = android.telegram_text(context)
        self.assertLessEqual(len(text.splitlines()), 15)
        self.assertEqual(text.count('•'), 5)
        with self.assertRaises(gate.GateError):
            android.telegram_text({**context,'platformLines':['arbitrary\nmultiline']})

    def test_workflow_has_one_entry_one_notification_and_ios_after_frozen_android(self):
        root = Path(__file__).resolve().parents[2]
        workflow = (root/'.github/workflows/beta-release.yml').read_text()
        self.assertFalse((root/'.github/workflows/beta-ios-release.yml').exists())
        self.assertIn('name: Beta Release',workflow)
        self.assertIn('needs: beta',workflow)
        self.assertIn('needs: [beta, ios-beta]',workflow)
        self.assertEqual(workflow.count('beta_release.py notify'),1)
        self.assertNotIn('ios_beta_release.py notify',workflow)
        self.assertIn('default: testflight',workflow)
        self.assertIn('if: always() && (inputs.mode',workflow)
        self.assertNotIn('continue-on-error: true',workflow)
        self.assertNotIn('google-play',workflow)

    def test_notification_plan_checks_ios_identity_before_merging(self):
        with tempfile.TemporaryDirectory() as temp:
            paths=dict(BETA_CONTEXT=temp+'/android.json',IOS_BETA_CONTEXT=temp+'/ios.json',
                       IOS_DELIVERY_RESULT='success')
            record=dict(sourceSha='a'*40,versionCode=230)
            names=delivery.ios.public_names('4.0.0-beta.5',230)
            context=dict(versionName='4.0.0-beta.5',versionCode=230)
            with mock.patch.dict(os.environ,paths), mock.patch.object(android,'notification_plan'), \
                 mock.patch.object(android,'read_context',return_value=context), \
                 mock.patch.object(android,'GitHub'), mock.patch.object(delivery.ios,'get_release',
                   return_value=(dict(assets=[dict(name=n) for n in names]),record)), \
                 mock.patch.object(delivery.ios,'notification_plan',side_effect=gate.GateError('identity mismatch')), \
                 mock.patch.object(android,'save_context') as save:
                with self.assertRaises(gate.GateError):delivery.notification_plan()
                save.assert_not_called()


if __name__=='__main__':unittest.main()
