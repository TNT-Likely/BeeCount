"""Negative fixtures for the read-only coverage verifier; no App/QA data access."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
VERIFIER = ROOT / 'tool/v4/verify_component_coverage.py'


class CoverageRejectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='beecount-coverage-metadata-')
        self.root = Path(self.temp.name)
        for relative in ('packages/beecount_ui/lib',
                         'packages/beecount_business_ui/lib',
                         'lib/presentation/v4/gallery'):
            shutil.copytree(ROOT / relative, self.root / relative)
        for relative in ('tool/v4/component_coverage.json',
                         'tool/v4/component_catalog_coverage.json',
                         'tool/v4/foundation_inventory.json',
                         'docs/design/card-refresh/components/samples.json',
                         'docs/design/card-refresh/components/catalog.json',
                         'docs/design/card-refresh/scripts/build-guide.cjs',
                         'docs/design/card-refresh/prototype/src/refresh-component-catalog.cjs'):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        self.addCleanup(self.temp.cleanup)

    def change(self, relative, mutate):
        path = self.root / relative
        value = json.loads(path.read_text())
        mutate(value)
        path.write_text(json.dumps(value, ensure_ascii=False))

    def check(self, expected, reason=''):
        result = subprocess.run([sys.executable, str(VERIFIER), '--root', str(self.root)],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        if reason:
            self.assertIn(reason, result.stdout + result.stderr)

    def test_current_declarations_pass(self):
        self.check(0, '105 HTML cards')

    def test_unmapped_sample_rejected(self):
        self.change('tool/v4/component_coverage.json', lambda value: value.pop())
        self.check(1, 'AssertionError')

    def test_unknown_sample_rejected(self):
        self.change('docs/design/card-refresh/components/samples.json',
                    lambda value: value.update({'new-unmapped-sample': '<div></div>'}))
        self.check(1, 'AssertionError')

    def test_unknown_component_rejected(self):
        self.change('tool/v4/component_coverage.json',
                    lambda value: value[0].update(components=['BeeDoesNotExist']))
        self.check(1, 'BeeDoesNotExist')

    def test_out_of_bounds_group_rejected(self):
        self.change('tool/v4/component_coverage.json',
                    lambda value: value[0].update(case=999))
        self.check(1, 'AssertionError')

    def test_missing_foundational_widget_rejected(self):
        self.change('tool/v4/foundation_inventory.json',
                    lambda value: value['components'].pop())
        self.check(1, 'AssertionError')

    def test_paper_only_foundation_mapping_rejected(self):
        self.change('tool/v4/foundation_inventory.json', lambda value:
                    next(row for row in value['components']
                         if row['component'] == 'BeeInlineLabel').update(cases=[8]))
        self.check(1, 'no source construction/callback witness')

    def test_removed_inline_example_rejected(self):
        path = self.root / 'lib/presentation/v4/gallery/foundation_page.dart'
        path.write_text(path.read_text().replace('BeeInlineLabel(', 'UnmappedLabel('))
        self.check(1, 'no source construction/callback witness')

    def test_removed_multi_select_example_rejected(self):
        path = self.root / 'lib/presentation/v4/gallery/foundation_page.dart'
        path.write_text(path.read_text().replace('BeeMultiSelect<String>(', 'UnmappedSelect<String>('))
        self.check(1, 'no source construction/callback witness')

    def test_missing_enhanced_card_rejected(self):
        self.change('tool/v4/component_catalog_coverage.json',
                    lambda value: value['cards'].pop())
        self.check(1, 'Unmapped or stale HTML catalog cards')

    def test_new_unmapped_card_rejected(self):
        self.change('docs/design/card-refresh/components/catalog.json', lambda value:
                    value[0]['cards'].append(dict(value[0]['cards'][0], id='spec-2999')))
        self.check(1, 'Unmapped or stale HTML catalog cards')

    def test_changed_native_group_rejected(self):
        self.change('tool/v4/component_catalog_coverage.json',
                    lambda value: value['cards'][-1].update(case=0))
        self.check(1, 'AssertionError')

    def test_unknown_contract_relation_rejected(self):
        self.change('tool/v4/component_catalog_coverage.json', lambda value:
                    value['cards'][-1].update(design_keys=['missing-key']))
        self.check(1, 'AssertionError')

    def test_empty_states_rejected(self):
        self.change('tool/v4/component_catalog_coverage.json', lambda value:
                    value['cards'][-1].update(supportedStates=[]))
        self.check(1, 'AssertionError')

    def test_stale_reverse_relation_rejected(self):
        self.change('tool/v4/component_coverage.json', lambda value:
                    value[0].update(catalog_ids=['spec-2999']))
        self.check(1, 'Stale contract to catalog mapping')

    def test_presentation_package_import_boundary_preserved(self):
        path = self.root / 'packages/beecount_ui/lib/forbidden_fixture.dart'
        path.write_text("import 'package:http/http.dart';\n")
        self.check(1, 'http/http.dart')


if __name__ == '__main__':
    unittest.main(verbosity=2)
