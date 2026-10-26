"""Run from any directory; checks design inventory and presentation boundaries."""
from pathlib import Path
import json
import re
import argparse

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--root', type=Path,
                    default=Path(__file__).resolve().parents[2],
                    help='Repository root; an isolated metadata fixture may be used for rejection tests.')
root = parser.parse_args().root.resolve()
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

# A declared group must actually reach the widget in its gallery source. This is
# a static construction/callback check, not proof that a native frame was seen.
def mask_dart(text):
    pattern = r'''("""[\s\S]*?"""|\x27\x27\x27[\s\S]*?\x27\x27\x27|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27|//[^\n]*|/\*[\s\S]*?\*/)'''
    return re.sub(pattern, lambda m: re.sub(r'[^\n]', ' ', m[0]), text)


def close_delimiter(text, start, opening='{', closing='}'):
    depth = 0
    for index in range(start, len(text)):
        if text[index] == opening:
            depth += 1
        elif text[index] == closing:
            depth -= 1
            if depth == 0:
                return index
    raise AssertionError(('Unclosed source delimiter', start))


nodes = {}
helper_names = {'showBeeDialog', 'showBeeSheet', 'showBeeContextMenu'}
gallery = root / 'lib/presentation/v4/gallery'
for path in list((root / 'packages/beecount_ui/lib').rglob('*.dart')) + list(gallery.glob('*.dart')):
    code = mask_dart(path.read_text())
    for match in re.finditer(r'\bclass\s+(\w+)', code):
        start = code.find('{', match.end())
        if start >= 0:
            end = close_delimiter(code, start)
            nodes.setdefault(match[1], []).append(code[start:end + 1])
    for name in helper_names:
        for match in re.finditer(r'\b' + name + r'(?:<[^>]+>)?\s*\(', code):
            start = code.find('(', match.start())
            end = close_delimiter(code, start, '(', ')') + 1
            tail = re.match(r'\s*(?:async\s*)?(\{|=>)', code[end:])
            if not tail:
                continue  # This occurrence is a call, not a declaration.
            body = end + tail.end() - len(tail[1])
            if tail[1] == '{':
                finish = close_delimiter(code, body) + 1
            else:
                cursor, depth = body + 2, 0
                while cursor < len(code):
                    char = code[cursor]
                    if char in '([{':
                        depth += 1
                    elif char in ')]}':
                        depth -= 1
                    elif char == ';' and depth == 0:
                        break
                    cursor += 1
                finish = cursor + 1
            nodes.setdefault(name, []).append(code[body:finish])

foundation_code = mask_dart((gallery / 'foundation_page.dart').read_text())
start = foundation_code.index('{', foundation_code.index('=> switch (index)'))
end = close_delimiter(foundation_code, start)
switch = foundation_code[start:end]
branches = list(re.finditer(r'^        (\d+|_)\s*=>', switch, re.M))
case_sources = {match[1]: switch[match.end():branches[i + 1].start() if i + 1 < len(branches) else len(switch)]
                for i, match in enumerate(branches)}


def reachable(source_code):
    pending = set(re.findall(r'\b\w+\b', source_code)) & nodes.keys()
    visited = set()
    while pending:
        name = pending.pop()
        if name in visited:
            continue
        visited.add(name)
        for body in nodes[name]:
            pending.update((set(re.findall(r'\b\w+\b', body)) & nodes.keys()) - visited)
    return visited


case_reachable = {case: reachable(case_sources.get(str(case), case_sources['_']))
                  for case in range(case_counts['foundation'])}
unreachable = [{'component': row['component'], 'case': case}
               for row in inventory for case in row['cases']
               if row['component'] not in case_reachable[case]]
assert not unreachable, ('Foundational inventory has no source construction/callback witness', unreachable)
print(f'PASS: all {len(base_widgets)} foundational widgets are source-reachable from their declared groups.')

catalog = json.loads((root / 'docs/design/card-refresh/components/catalog.json').read_text())
actual_cards = {card['id']: (group['id'], card) for group in catalog for card in group['cards']}
assert len(actual_cards) == sum(len(group['cards']) for group in catalog), 'Duplicate catalog ID'
mapping = json.loads((root / 'tool/v4/component_catalog_coverage.json').read_text())['cards']
assert len({card['id'] for card in mapping}) == len(mapping), 'Duplicate mapped catalog ID'
assert {card['id'] for card in mapping} == actual_cards.keys(), 'Unmapped or stale HTML catalog cards'
guide_source = (root / 'docs/design/card-refresh/scripts/build-guide.cjs').read_text()
guide_ids = {'spec-' + str(int(value)) for value in re.findall(r"card\('(\d+) · ", guide_source)}
enhanced = {}
enhanced_paths = {}
for source in ('refresh-component-catalog.cjs', 'resource-detail-samples.cjs'):
    source_path = 'docs/design/card-refresh/prototype/src/' + source
    enhanced_source = (root / source_path).read_text()
    for ident, page, case in re.findall(r"\{id:(\d+),group:'(foundation|business)',case:(\d+),", enhanced_source):
        key = 'spec-' + ident
        assert key not in enhanced, ('Duplicate enhanced source', key)
        enhanced[key] = (page, int(case))
        enhanced_paths[key] = source_path
assert guide_ids | enhanced.keys() == actual_cards.keys(), 'Catalog diverges from its rendering sources'
assert not guide_ids & enhanced.keys(), 'Enhanced cards overwrite existing anchors'
contracts = {row['design_key']: row for row in coverage}
used_keys = set()
for card in mapping:
    page, actual = actual_cards[card['id']]
    assert (card['page'], card['case'], card['nativeLabel']) == (page, actual['nativeCase'], actual['nativeLabel']), card
    dart = (gallery / f'{page}_page.dart').read_text()
    labels = re.findall(r"'([^']*)'", re.search(r'const ' + page + r'Cases = \[(.*?)\];', dart, re.S)[1])
    assert labels[card['case']] == card['nativeLabel'], ('Stale Flutter label/index', card['id'])
    assert card['components'] and set(card['components']) <= classes, card
    assert card['supportedStates'] and all(isinstance(s, str) and s.strip() for s in card['supportedStates']), card
    assert (root / card['source']).is_file(), card
    assert set(card['design_keys']) <= contracts.keys(), card
    used_keys.update(card['design_keys'])
    if card['id'] in enhanced:
        assert card['kind'] == 'enhanced' and (page, card['case']) == enhanced[card['id']], card
        assert card['source'] == enhanced_paths[card['id']], card
    else:
        assert card['kind'] == 'catalog' and card['source'].endswith('/build-guide.cjs'), card
assert used_keys == contracts.keys(), ('Contracts missing from the current HTML catalog', contracts.keys() - used_keys)
for row in coverage:
    assert row['supportedStates'] and row['catalog_ids'], row
    actual_ids = {card['id'] for card in mapping if row['design_key'] in card['design_keys']}
    assert set(row['catalog_ids']) == actual_ids, ('Stale contract to catalog mapping', row['design_key'])
print(f'PASS: {len(actual_cards)} HTML cards, including {len(enhanced)} enhancements, map to current Flutter groups and all {len(coverage)} design contracts.')
print('Scope: source declarations and presentation boundaries only; native visual/data acceptance is reported separately.')
