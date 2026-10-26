"""Global delivery-floor ordering; version names never encode Android codes."""
import json
from pathlib import Path
import subprocess
import sys
import unittest

from android_version_code import MAX_VERSION_CODE, parse_version, validate_candidate, validate_recorded_version


class AndroidVersionCodeTests(unittest.TestCase):
    def test_this_beta_starts_immediately_after_production_225(self):
        self.assertEqual(validate_candidate("4.0.0-beta.1", minimum_code=225).code, 226)
        self.assertEqual(validate_candidate("4.0.0-beta.2", minimum_code=226).code, 227)

    def test_all_beta_codes_fit_below_first_stable_300(self):
        for floor in range(225, 299):
            self.assertEqual(validate_candidate("4.0.0-beta.1", minimum_code=floor).code, floor + 1)
        for floor in (299, 300, 301, MAX_VERSION_CODE):
            with self.subTest(floor=floor), self.assertRaises(ValueError):
                validate_candidate("4.0.0-beta.2", minimum_code=floor)

    def test_stable_and_later_codes_increment_globally(self):
        for floor, expected in [(225, 300), (298, 300), (299, 300), (300, 301), (301, 302)]:
            self.assertEqual(validate_candidate("4.0.0", minimum_code=floor).code, expected)
        self.assertEqual(validate_candidate("4.0.1", minimum_code=300).code, 301)
        self.assertEqual(validate_candidate("4.1.0-beta.1", minimum_code=301).code, 302)

    def test_version_name_does_not_imply_a_code(self):
        self.assertIsNone(parse_version("4.0.0-beta.1").code)
        self.assertEqual(validate_candidate("4.0.0-beta.74", minimum_code=225).code, 226)
        self.assertEqual(validate_candidate("4.0.0-beta.1", minimum_code=226).code, 227)
        self.assertEqual(validate_recorded_version("4.0.0-beta.74", 227).code, 227)

    def test_android_ceiling_refuses_overflow(self):
        self.assertEqual(validate_candidate("4.1.0", minimum_code=MAX_VERSION_CODE - 1).code, MAX_VERSION_CODE)
        with self.assertRaises(ValueError):
            validate_candidate("4.1.0", minimum_code=MAX_VERSION_CODE)

    def test_unsupported_and_injected_names_are_rejected(self):
        for value in ("4.0", "4.0.0-beta.0", "4.0.0-beta.-1", "4.0.0-beta.01", "4.0.0-rc.1", "04.0.0", "4.00.0", "4.0.0+123", "manual-sha", " 4.0.0", "4.0.0\n", "4.0.0;echo BAD", "v4.0.0'", None):
            with self.subTest(value=value), self.assertRaises(ValueError):
                parse_version(value)

    def test_v_prefix_normalizes_name_and_old_product_versions_fail(self):
        candidate = validate_candidate("v4.0.0-beta.1", minimum_code=225)
        self.assertEqual((candidate.name, candidate.code), ("4.0.0-beta.1", 226))
        for version in ("3.8.99", "3.9.0-beta.98", "3.9.0", "3.9.1", "3.99.0"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                validate_candidate(version, minimum_code=225)
        with self.assertRaises(ValueError):
            validate_candidate("4.0.0-beta.1", minimum_code=227, minimum_version="4.0.0-beta.2")
        with self.assertRaises(ValueError):
            validate_candidate("4.0.0", minimum_code=301, minimum_version="4.0.1")

    def test_floor_is_explicit_and_must_cover_verified_online(self):
        for floor in (0, 224, -1, True, 225.0, MAX_VERSION_CODE + 1):
            with self.subTest(floor=floor), self.assertRaises(ValueError):
                validate_candidate("4.0.0-beta.1", minimum_code=floor)

    def test_stored_pairs_have_channel_boundaries_without_name_formula(self):
        for name, code in [("4.0.0-beta.1", 225), ("4.0.0-beta.1", 300), ("4.0.0", 299), ("4.0.1", True), ("4.0.1", 0), ("4.0.1", MAX_VERSION_CODE + 1)]:
            with self.subTest(name=name, code=code), self.assertRaises(ValueError):
                validate_recorded_version(name, code)
        self.assertGreater(parse_version("4.0.0").order, parse_version("4.0.0-beta.999").order)

    def test_cli_requires_floor_and_keeps_failure_stdout_empty(self):
        script = Path(__file__).with_name("android_version_code.py")
        for args in (("4.0.0",), ("4.0.0-beta.1", "--minimum-code", "299")):
            result = subprocess.run([sys.executable, str(script), *args], text=True, capture_output=True)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(result.stdout, "")
        result = subprocess.run([sys.executable, str(script), "4.0.0-beta.1", "--minimum-code", "225", "--json"], text=True, capture_output=True, check=True)
        self.assertEqual(json.loads(result.stdout)["versionCode"], 226)


if __name__ == "__main__":
    unittest.main()
