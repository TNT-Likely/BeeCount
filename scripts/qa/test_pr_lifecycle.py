"""Regression checks for handoff, retries and ownership-sensitive cleanup."""
import json
import plistlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from zipfile import ZipFile

import pr_lifecycle as lifecycle
import qa_cleanup

APP_PR = 'https://github.com/TNT-Likely/BeeCount/pull/100'
CLOUD_PR = 'https://github.com/TNT-Likely/BeeCount-Cloud/pull/200'


class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.registry = self.base / 'registry'
        self.root = self.base / 'beecount-qa-example'
        self.root.mkdir(mode=0o700)
        (self.root / '.qa-owner').write_text(self.root.name)
        lifecycle.write_json(self.root / 'manifest.json', {
            'root': str(self.root), 'run_id': self.root.name,
            'app_id': 'com.tntlikely.beecount.qa',
        })
        lifecycle.register_run(self.registry, 'example', self.root)

    def read(self):
        return lifecycle.read_record(self.registry / 'example.json')[0]

    def test_registration_and_binding_are_idempotent(self):
        lifecycle.register_run(self.registry, 'example', self.root)
        with lifecycle.edit_round(self.registry, 'example') as record:
            record['pending_pr_repos'] = ['tnt-likely/beecount', 'tnt-likely/beecount-cloud']
            lifecycle.bind(record, APP_PR)
            lifecycle.bind(record, APP_PR)
        record = self.read()
        self.assertEqual(record['pr_urls'], [APP_PR])
        self.assertEqual(record['pending_pr_repos'], ['tnt-likely/beecount-cloud'])
        self.assertEqual(len(record['runs']), 1)
        self.assertEqual(len(lifecycle.find(self.registry, APP_PR.lower())), 1)

    def test_run_cannot_be_registered_to_two_rounds(self):
        with self.assertRaisesRegex(ValueError, 'another round'):
            lifecycle.register_run(self.registry, 'different', self.root)

    def test_cleanup_preview_preserves_registry(self):
        record = self.registry / 'example.json'
        original = record.read_bytes()
        self.assertEqual(qa_cleanup.cleanup_round(self.registry, 'example', False, True)['state'],
                         'ready')
        self.assertEqual(record.read_bytes(), original)
        self.assertTrue(self.root.is_dir())

    def test_cleanup_refuses_simulator_with_production_app(self):
        device_root = self.base / 'simulated-device'
        bundle = device_root / 'data/Containers/Bundle/Application/id/Runner.app'
        bundle.mkdir(parents=True)
        (bundle / 'Info.plist').write_bytes(plistlib.dumps({
            'CFBundleIdentifier': 'com.tntlikely.beecount',
        }))
        runtime = 'fixture-runtime'
        identity = {'udid': 'fixture-udid', 'protected_udids': [],
                    'runtime': runtime, 'device_name': 'fixture-device'}
        data = {'udid': identity['udid'], 'name': identity['device_name'],
                'dataPath': str(device_root / 'data'), 'state': 'Shutdown'}
        with patch.object(qa_cleanup, 'ios_devices', return_value=[(runtime, data)]):
            with self.assertRaisesRegex(ValueError, 'outside'):
                qa_cleanup.cleanup_ios(identity, False)

    def test_cleanup_waits_for_each_associated_pr(self):
        with lifecycle.edit_round(self.registry, 'example') as record:
            lifecycle.bind(record, APP_PR)
            lifecycle.bind(record, CLOUD_PR)
        merged = json.dumps({'state': 'MERGED', 'mergeCommit': {'oid': 'a' * 40}})
        with patch.object(qa_cleanup, 'command', side_effect=[merged, '{"state":"OPEN"}']):
            result = qa_cleanup.cleanup(self.registry, APP_PR, apply=True)
        self.assertFalse(result)
        self.assertTrue(self.root.exists())

    def test_prepare_failure_can_be_reclaimed_and_retried(self):
        report = qa_cleanup.cleanup_round(self.registry, 'example', True, True)
        self.assertEqual(report['state'], 'removed')
        self.assertFalse(self.root.exists())
        self.assertEqual(qa_cleanup.cleanup_round(self.registry, 'example', True, True)['state'],
                         'already cleaned')

    def test_interrupted_removal_resumes_from_intent(self):
        with lifecycle.edit_round(self.registry, 'example') as record:
            record['cleanup_intent'] = {str(self.root): {'run_id': self.root.name, 'root': str(self.root)}}
        (self.root / '.qa-owner').unlink()
        (self.root / 'manifest.json').unlink()
        self.root.rmdir()
        self.assertEqual(qa_cleanup.cleanup_round(self.registry, 'example', True, True)['state'],
                         'removed')

    def test_live_runner_lock_and_changed_marker_protect_data(self):
        with lifecycle.run_lock(self.root):
            self.assertEqual(qa_cleanup.cleanup_round(self.registry, 'example', True, True)['state'],
                             'pending')
        (self.root / '.qa-owner').write_text('wrong-run')
        self.assertEqual(qa_cleanup.cleanup_round(self.registry, 'example', True, True)['state'],
                         'pending')
        self.assertTrue(self.root.exists())

    def test_report_and_reference_survive_cleanup(self):
        html = self.base / 'index.html'
        html.write_text('<title>QA</title>')
        archive = self.base / 'report.zip'
        with ZipFile(archive, 'w') as zip_file:
            zip_file.write(html, html.name)
        with lifecycle.edit_round(self.registry, 'example') as record:
            lifecycle.bind(record, APP_PR)
            lifecycle.bind(record, CLOUD_PR)
            lifecycle.record_report(record, html, archive, ['TNT-Likely/BeeCount=' + 'a' * 40])
            lifecycle.record_delivery(record, APP_PR, 'upload', archive.name,
                                      'https://github.com/user-attachments/files/1/report.zip')
        with lifecycle.edit_round(self.registry, 'example') as resumed:
            lifecycle.record_delivery(resumed, APP_PR, 'published', None, None)
            with self.assertRaisesRegex(ValueError, 'verified copy'):
                lifecycle.record_delivery(resumed, CLOUD_PR, 'reference', None, APP_PR)
            lifecycle.record_delivery(resumed, APP_PR, 'verified', None, archive)
            lifecycle.record_delivery(resumed, CLOUD_PR, 'reference', None, APP_PR)
            lifecycle.record_delivery(resumed, CLOUD_PR, 'reference', None, APP_PR)
            with self.assertRaisesRegex(ValueError, 'verified copy'):
                lifecycle.record_delivery(resumed, APP_PR, 'reference', None, CLOUD_PR)
        self.assertEqual(qa_cleanup.cleanup_round(self.registry, 'example', True, True)['state'],
                         'removed')
        result = self.read()
        digest = lifecycle.digest(archive)
        self.assertTrue(result['delivery'][APP_PR.lower()][digest]['verified'])
        self.assertEqual(result['delivery'][CLOUD_PR.lower()][digest], {'reference_pr': APP_PR})
        self.assertTrue(html.is_file())
