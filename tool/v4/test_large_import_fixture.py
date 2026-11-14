"""Safety and input-domain checks for generated synthetic files only."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("fixture", Path(__file__).with_name("generate_large_import_fixture.py"))
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)


class FixturePolicyTests(unittest.TestCase):
    def test_category_count_matches_dart_utf16_and_not_python_scalar_count(self):
        self.assertEqual(fixture.utf16_units("Q15" + "🧋" * 4), 11)
        row, item = next(fixture.records(1))
        item["category"] = "Q15" + "🧋" * 4
        self.assertIn("category:over-10-utf16", fixture.manual_input_boundaries(item))

    def test_routine_boundary_is_positive_two_decimals_and_complete_category(self):
        for _, item in fixture.records(15000):
            self.assertEqual(fixture.manual_input_boundaries(item), [])
        names = [fixture.category_names(i, "expense") for i in range(24)]
        self.assertTrue(any(fixture.utf16_units(p) == 10 for p, _ in names))
        self.assertTrue(any(c and fixture.utf16_units(c) == 10 for _, c in names))
        self.assertTrue(any(fixture.utf16_units(n) == 20 for n in fixture.TAG_NAMES))

    def test_robustness_profile_does_not_hide_manual_boundaries(self):
        reasons = {reason for _, r in fixture.records(1000, profile="import-robustness")
                   for reason in r["manualInputBoundaryReasons"]}
        self.assertTrue({"category:over-10-utf16", "tagName:over-20-safe-units",
                         "amount:not-positive", "amount:over-two-decimals",
                         "category:missing-for-new-entry"}.issubset(reasons))

    def test_resource_suggestions_preserve_kind_parent_and_never_claim_application(self):
        data = fixture.resource_plan(15000)
        categories = {(c["kind"], c["name"]): c for c in data["categories"]}
        for cat in categories.values():
            self.assertLessEqual(fixture.utf16_units(cat["name"]), 10)
            if cat["level"] == 2:
                self.assertIn((cat["kind"], cat["parentName"]), categories)
        self.assertTrue(data["notAnImportableBackup"])
        self.assertEqual(len({a["type"] for a in data["accounts"]}), 12)
        self.assertTrue(all(len(a["cardLastFour"]) == 4 for a in data["accounts"] if "cardLastFour" in a))
        renames = fixture.legacy_rename_plan(15000)
        self.assertTrue(renames["neverApplyByNameAlone"])
        self.assertEqual(len(renames["tags"]), 3)
        self.assertEqual(len({(r["kind"], r["newName"]) for r in renames["categories"]}), len(renames["categories"]))

    def test_bad_profile_and_existing_outputs_are_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                fixture.make_fixture(directory, count=5, profile="unmarked")
            first = fixture.make_fixture(directory, count=5)
            path = Path(directory) / first["csv"]["file"]
            original = path.read_bytes()
            with self.assertRaises(FileExistsError):
                fixture.make_fixture(directory, count=5)
            self.assertEqual(path.read_bytes(), original)
        with self.assertRaises(ValueError):
            fixture.make_fixture(fixture.ROOT / "test/fixtures/not-a-generated-directory", count=5)


if __name__ == "__main__":
    unittest.main()
