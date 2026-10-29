#!/usr/bin/env python3
"""Refresh the small App component contracts from BeeCount-Design/card-refresh.

Run after rebuilding the design component guide, then review both repository
diffs and update design.lock.json to the published design revision. This script
never fetches sources or mutates the design repository.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--design-root', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
design = args.design_root.resolve()
target = root / 'tool/design/contracts/card-refresh'
(target / 'components').mkdir(parents=True, exist_ok=True)
sources = ['scripts/build-guide.cjs',
           'prototype/src/refresh-component-catalog.cjs',
           'prototype/src/resource-detail-samples.cjs',
           'prototype/src/extracted-component-samples.cjs']
guide = (design / sources[0]).read_text()
value = {
    'schema': 1,
    'scope': 'Rendering declarations at the locked design revision; source files live in BeeCount-Design/card-refresh.',
    'guide_ids': ['spec-' + str(int(x)) for x in re.findall(r"card\('(\d+) · ", guide)],
    'enhanced': {},
    'sourceFiles': {name: hashlib.sha256((design / name).read_bytes()).hexdigest()
                    for name in sources},
}
for source in sources[1:3]:
    for ident, page, case in re.findall(r"\{id:(\d+),group:'(foundation|business)',case:(\d+),",
                                       (design / source).read_text()):
        key = 'spec-' + ident
        assert key not in value['enhanced'], ('Duplicate enhanced source', key)
        value['enhanced'][key] = {'page': page, 'case': int(case), 'source': source}
for name in ('samples.json', 'catalog.json'):
    shutil.copy2(design / 'components' / name, target / 'components' / name)
(target / 'rendering-sources.json').write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
print(f'Updated 3 component contracts from {design}')
