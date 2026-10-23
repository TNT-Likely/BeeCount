"""Run from any directory; checks design inventory and presentation boundaries."""
from pathlib import Path
import json
import re

root = Path(__file__).resolve().parents[2]
coverage = json.loads((root / 'tool/v4/component_coverage.json').read_text())
assert len({c['design_key'] for c in coverage}) == len(coverage)
source = '\n'.join(p.read_text() for name in ('beecount_ui', 'beecount_business_ui')
                   for p in (root / 'packages' / name / 'lib').rglob('*.dart'))
classes = set(re.findall(r'(?:class|enum)\s+(\w+)', source))
case_counts = {}
for page in ('foundation','business'):
    dart = (root / f'lib/presentation/v4/gallery/{page}_page.dart').read_text()
    catalog = re.search(r'const '+page+r'Cases = \[(.*?)\];',dart,re.S).group(1)
    case_counts[page] = len(re.findall(r"'[^']*'",catalog))
for row in coverage:
    assert set(row['components']) <= classes, row
    assert row['page'] in ('foundation', 'business')
    assert 0 <= row['case'] < case_counts[row['page']]
design = root / 'docs/design/card-refresh/components/samples.json'
if design.exists():
    assert set(json.loads(design.read_text())) == {c['design_key'] for c in coverage}
for name in ('beecount_ui', 'beecount_business_ui'):
    allowed = ('package:flutter/', 'package:beecount_ui/', 'dart:')
    if name == 'beecount_ui':
        allowed += ('package:flutter_svg/',)
    for path in (root / 'packages' / name / 'lib').rglob('*.dart'):
        for imp in re.findall(r"import\s+'([^']+)'", path.read_text()):
            assert not imp.startswith('package:') or imp.startswith(allowed), (path.name, imp)
print(f'PASS: {len(coverage)} design groups mapped; both presentation package boundaries checked.')

# Every public foundational widget needs a declared gallery/state inventory.
base_source = '\n'.join(p.read_text() for p in (root / 'packages/beecount_ui/lib').rglob('*.dart'))
base_widgets = set(re.findall(r'class\s+(\w+)(?:<[^>]*>)?\s+extends\s+(?:Stateless|Stateful)Widget', base_source))
inventory = json.loads((root / 'tool/v4/foundation_inventory.json').read_text())['components']
assert {r['component'] for r in inventory} == base_widgets
for row in inventory:
    assert row['supportedStates'] and row['cases']
    assert all(0 <= c < case_counts['foundation'] for c in row['cases'])
print(f"PASS: {len(base_widgets)} foundational widgets have explicit sample/state inventories.")
