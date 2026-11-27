import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from cloud_sync_baseline import run_file


class SyncEvidenceTests(unittest.TestCase):
    def check_suite(self, statuses):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            def completed(command, *, env, **kwargs):
                for case, status in statuses.items():
                    path = Path(env["CLOUD_SYNC_QA_OUTPUT"]) / (case + ".json")
                    path.write_text(json.dumps({"status": status}))
                return SimpleNamespace(returncode=0)
            cfg = SimpleNamespace(seed=1, transactions=1200, flutter="flutter", suite="core")
            with patch("cloud_sync_baseline.subprocess.run", side_effect=completed):
                return run_file(cfg, "upload", root, "http://127.0.0.1", root,
                                Path("python"), "abc", root)["status"]

    def test_complete_reports_are_required_even_with_successful_process(self):
        self.assertEqual(self.check_suite({"full-upload": "PASS"}), "FAIL")
        self.assertEqual(self.check_suite({"full-upload": "PASS", "incremental-upload": "FAIL"}), "FAIL")
        self.assertEqual(self.check_suite({"full-upload": "PASS", "incremental-upload": "PASS"}), "PASS")
