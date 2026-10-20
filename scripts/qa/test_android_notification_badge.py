"""Android host guards: never contact a real device or emulator."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import android_notification_badge as badge


class AndroidBadgeGuards(unittest.TestCase):
    def test_absent_app_is_confirmed_without_attempting_a_backup(self):
        manifest = dict(serial='emulator-5554')
        with patch.object(badge, 'device'), patch.object(badge.qa, 'command', return_value=''), \
                patch.object(badge.qa, 'write_json'), patch.object(badge, 'adb') as adb:
            badge.backup(Path('/unused-owned-run'), manifest)
            adb.assert_not_called()
            self.assertTrue(manifest['first_install_absence_confirmed'])

    def test_existing_and_physical_devices_rejected_before_any_command(self):
        for serial, protected in [('emulator-5554', ['emulator-5554']), ('phone-serial', [])]:
            with self.subTest(serial=serial), patch.object(badge.qa, 'command') as command:
                with self.assertRaises(ValueError):
                    badge.device(dict(serial=serial, protected_serials=protected))
                command.assert_not_called()

    def test_reused_emulator_port_with_different_avd_is_rejected(self):
        with patch.object(badge.qa, 'command', return_value='Someone-elses-AVD\nOK'):
            with self.assertRaises(ValueError):
                badge.device(dict(serial='emulator-5554', protected_serials=[], avd_name='Owned-QA'))

    def test_production_apk_is_rejected_before_installation(self):
        with patch.object(badge.qa, 'command', return_value="package: name='com.tntlikely.beecount'"):
            with self.assertRaises(ValueError):
                badge.verify(Path('/unused-owned-run'), {})

    def test_wrong_owner_or_linked_source_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            manifest = dict(root=str(root), run_id='owned', android_app_id=badge.APP_ID)
            (root / 'manifest.json').write_text(json.dumps(manifest))
            (root / '.qa-owner').write_text('other')
            with self.assertRaises(ValueError):
                badge.load(root)
            (root / '.qa-owner').write_text('owned')
            (root / 'app-source').symlink_to('/tmp')
            with self.assertRaises(ValueError):
                badge.load(root)


if __name__ == '__main__':
    unittest.main()
