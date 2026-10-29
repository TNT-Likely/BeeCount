"""Rejection tests for the local snapshot-audit normalization boundary."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from tool.v4 import migration_contracts as contracts


class MigrationContractTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.addCleanup(self.temp.cleanup)
        self.original = "import '../widgets/ui/ui.dart';\nint count() => 20;"
        contracts.AUDIT.clear()

    def check_source(self, current, reviewed):
        (self.root / 'source.dart').write_text(current)
        with patch.object(contracts, 'ROOT', self.root), patch.object(
                contracts, 'reviewed_source', return_value=reviewed):
            return contracts.audit_dependency('source.dart', self.original)

    def test_moved_or_removed_import_does_not_change_body(self):
        self.check_source("import 'package:beecount_ui/beecount_ui.dart';\nint count()=>20;",
                          self.original)
        self.assertEqual(contracts.AUDIT[-1]['relation'], 'original-semantics')

    def test_preexisting_fix_is_explicitly_reported(self):
        reviewed = 'int count() => 24;'
        self.check_source(reviewed, reviewed)
        self.assertEqual(contracts.AUDIT[-1]['relation'], 'preexisting-v4-change')

    def test_new_behavior_change_cannot_be_blessed_by_old_delta(self):
        with self.assertRaisesRegex(AssertionError, 'Dependency changed after'):
            self.check_source('int count() => 25;', 'int count() => 24;')

    def test_string_content_is_not_discarded_as_comments_or_whitespace(self):
        first = "String source() => 'https://example.invalid/a b';"
        second = "String source() => 'https://example.invalid/ab';"
        self.assertNotEqual(contracts.source_tokens(first), contracts.source_tokens(second))


if __name__ == '__main__':
    unittest.main()
