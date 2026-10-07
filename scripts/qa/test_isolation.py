"""Host guard tests; never access a simulator or a Cloud database."""
import json
import plistlib
import subprocess
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import isolated_app_cloud as qa


class IsolationTests(unittest.TestCase):
    def test_path_escape_and_symlink_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertEqual(qa.inside(root, root / 'new.db'), (root / 'new.db').resolve())
            with self.assertRaises(ValueError):
                qa.inside(root, root / '../live.db')
            (root / 'link').symlink_to('/tmp')
            with self.assertRaises(ValueError):
                qa.inside(root, root / 'link')

    def test_protected_device_is_rejected_before_any_command(self):
        with patch.object(qa, 'command') as command:
            with self.assertRaises(ValueError):
                qa.device(dict(udid='existing', protected_udids=['existing']))
            command.assert_not_called()

    def test_linked_parent_is_rejected_even_inside_run(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            (root / 'owned').mkdir()
            (root / 'alias').symlink_to(root / 'owned', target_is_directory=True)
            with self.assertRaises(ValueError):
                qa.inside(root, root / 'alias/new.db')

    def test_renamed_or_missing_device_is_rejected(self):
        manifest = dict(udid='qa-only', protected_udids=['existing'], device_name='BeeCount-QA-run')
        with patch.object(qa, 'command', return_value=json.dumps({'devices': {'ios': [
            {'udid': 'qa-only', 'name': 'someone-elses-device'}
        ]}})):
            with self.assertRaises(ValueError):
                qa.device(manifest)

    def test_run_ownership_and_production_bundle_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / '.qa-owner').write_text('other-run')
            qa.write_json(root / 'manifest.json', dict(root=str(root), run_id='my-run', app_id=qa.APP_ID))
            with self.assertRaises(ValueError):
                qa.load_run(root)
            (root / '.qa-owner').write_text('my-run')
            qa.write_json(root / 'manifest.json', dict(root=str(root), run_id='my-run',
                                                     app_id='com.tntlikely.beecount'))
            with self.assertRaises(ValueError):
                qa.load_run(root)

    def test_production_artifact_is_rejected_before_codesign(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = root / 'app-source/build/ios/iphonesimulator/Runner.app'
            app.mkdir(parents=True)
            (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'com.tntlikely.beecount'}))
            with patch.object(qa.subprocess, 'run') as run:
                with self.assertRaises(ValueError):
                    qa.verify_artifact(root, {})
                run.assert_not_called()

    def test_production_container_entitlements_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = root / 'app-source/build/ios/iphonesimulator/Runner.app'
            app.mkdir(parents=True)
            (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': qa.APP_ID}))
            for entitlements in [
                {'com.apple.security.application-groups': ['group.com.tntlikely.beecount']},
                {'com.apple.security.application-groups': [qa.GROUP_ID],
                 'com.apple.developer.icloud-container-identifiers': ['iCloud.com.tntlikely.beecount']},
            ]:
                signed = subprocess.CompletedProcess([], 0, stdout=plistlib.dumps(entitlements))
                with patch.object(qa.subprocess, 'run', return_value=signed):
                    with self.assertRaises(ValueError):
                        qa.verify_artifact(root, {})


if __name__ == '__main__':
    unittest.main()
