"""Ordering, collision boundaries and fail-closed local/CI command contracts."""

import json
from pathlib import Path
import subprocess
import sys
import unittest

from android_version_code import MAX_VERSION_CODE, parse_version, validate_candidate


class AndroidVersionCodeTests(unittest.TestCase):
    def test_beta_sequence_and_stable_have_reserved_increasing_slots(self):
        codes = [parse_version(f"4.0.0-beta.{n}").code for n in range(1, 99)]
        codes.append(parse_version("4.0.0").code)
        self.assertEqual(codes, list(range(4_000_001, 4_000_100)))
        self.assertGreater(parse_version("4.0.1-beta.1").code, codes[-1])

    def test_patch_minor_and_major_carry_without_collisions(self):
        for major in (0, 3, 4, 2098):
            for minor in (0, 1, 98):
                for patch in (0, 1, 98):
                    self.assertLess(
                        parse_version(f"{major}.{minor}.{patch}").code,
                        parse_version(f"{major}.{minor}.{patch + 1}-beta.1").code,
                    )
                self.assertLess(
                    parse_version(f"{major}.{minor}.99").code,
                    parse_version(f"{major}.{minor + 1}.0-beta.1").code,
                )
            self.assertLess(
                parse_version(f"{major}.99.99").code,
                parse_version(f"{major + 1}.0.0-beta.1").code,
            )

    def test_android_upper_bound_is_not_silently_wrapped(self):
        self.assertEqual(parse_version("2099.99.99").code, 2_099_999_999)
        self.assertLessEqual(parse_version("2099.99.99").code, MAX_VERSION_CODE)
        with self.assertRaises(ValueError):
            parse_version("2100.0.0-beta.1")

    def test_unsupported_names_and_slot_overflow_are_rejected(self):
        for value in (
            "4.0", "4.0.0-beta.0", "4.0.0-beta.99", "4.0.0-beta.100",
            "4.0.0-beta.-1", "4.0.0-beta.01", "4.0.0-rc.1", "4.100.0",
            "4.0.100", "04.0.0", "4.00.0", "4.0.0+123", "manual-sha",
            " 4.0.0", "4.0.0\n", "4.0.0;echo BAD", "v4.0.0'",
        ):
            with self.subTest(value=value), self.assertRaises(ValueError):
                parse_version(value)

    def test_v_prefix_only_normalizes_the_version_name(self):
        result = validate_candidate("v4.0.0-beta.1", minimum_code=225)
        self.assertEqual(result.name, "4.0.0-beta.1")
        self.assertEqual(result.code, 4_000_001)

    def test_observed_legacy_production_is_strictly_lower(self):
        self.assertGreater(
            validate_candidate("4.0.0-beta.1", minimum_code=225).code, 225
        )
        for version in ("3.8.99", "3.9.0-beta.98", "3.9.0"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                validate_candidate(version, minimum_code=225)

    def test_current_floor_cannot_be_guessed_below_known_online(self):
        for floor in (0, 224, -1, True, 225.0, MAX_VERSION_CODE + 1):
            with self.subTest(floor=floor), self.assertRaises(ValueError):
                validate_candidate("4.0.0-beta.1", minimum_code=floor)

    def test_equal_lower_and_outdated_stable_codes_are_rejected(self):
        for name, floor in (
            ("4.0.0-beta.1", 4_000_001),
            ("4.0.0-beta.1", 4_000_002),
            ("4.0.0", 4_000_099),
            ("4.0.0", 4_000_101),
        ):
            with self.subTest(name=name, floor=floor), self.assertRaises(ValueError):
                validate_candidate(name, minimum_code=floor)
        self.assertEqual(
            validate_candidate("4.0.0", minimum_code=4_000_098).code, 4_000_099
        )
        self.assertEqual(
            validate_candidate("4.0.1", minimum_code=4_000_101).code, 4_000_199
        )

    def test_cli_requires_the_floor_and_keeps_failure_stdout_empty(self):
        script = Path(__file__).with_name("android_version_code.py")
        for args in (("4.0.0",), ("4.0.0-beta.1", "--minimum-code", "4000001")):
            result = subprocess.run(
                [sys.executable, str(script), *args], text=True, capture_output=True
            )
            self.assertEqual(result.returncode, 2)
            self.assertEqual(result.stdout, "")
        result = subprocess.run(
            [sys.executable, str(script), "4.0.0-beta.1", "--minimum-code", "225", "--json"],
            text=True, capture_output=True, check=True,
        )
        self.assertEqual(json.loads(result.stdout)["versionCode"], 4_000_001)


if __name__ == "__main__":
    unittest.main()
