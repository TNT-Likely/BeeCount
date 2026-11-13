"""Execute the actual stable iOS version step before the platform-specific sed."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[2]


class StableIosBuildNumberTests(unittest.TestCase):
    def run_step(self, version, android, ios):
        text = (ROOT / '.github/workflows/release.yml').read_text()
        step = text.split('      - name: Update pubspec.yaml version (iOS)\n', 1)[1]
        step = step.split('      - name: Setup iOS signing', 1)[0]
        script = textwrap.dedent(step.split('        run: |\n', 1)[1])
        script = script.split('sed -i', 1)[0] + 'printf "RESULT=%s\\n" "$BUILD_NUMBER"\n'
        with tempfile.TemporaryDirectory(prefix='beecount-stable-version-') as folder:
            root = Path(folder)
            (root / 'tool/release').mkdir(parents=True)
            shutil.copy2(ROOT / 'tool/release/android_version_code.py', root / 'tool/release')
            (root / 'pubspec.yaml').write_text('name: fixture\nversion: 3.9.0+225\n')
            return subprocess.run(['bash', '-c', script], cwd=root, text=True,
                capture_output=True, env={**os.environ, 'RELEASE_VERSION_NAME': version,
                    'ANDROID_VERSION_CODE_FLOOR': android, 'IOS_BUILD_NUMBER_FLOOR': ios})

    def test_first_stable_exceeds_all_4_0_betas(self):
        result = self.run_step('4.0.0', '231', '232')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('RESULT=300', result.stdout)

    def test_larger_ios_retry_build_is_respected(self):
        result = self.run_step('v4.0.1', '300', '305')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('RESULT=306', result.stdout)

    def test_missing_or_injected_floor_is_rejected(self):
        for android, ios in [('', '232'), ('231', '232;echo INJECTED'), ('231', '-1')]:
            with self.subTest(android=android, ios=ios):
                result = self.run_step('4.0.0', android, ios)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('RESULT=', result.stdout)


if __name__ == '__main__':
    unittest.main()
