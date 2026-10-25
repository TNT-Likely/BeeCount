#!/usr/bin/env python3
"""Read-only r99 migration contract checks; never contact a device or Cloud."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BACKUP = ROOT / '.docs/v4-ui-migration/backup/parallel-cloud-shared-r99'
manifest = json.loads((BACKUP / 'manifest.json').read_text())
bindings = ROOT / 'lib/presentation/v4/bindings'
current = '\n'.join(p.read_text() for p in bindings.glob('cloud_shared_*.dart'))
original = '\n'.join((BACKUP / p).read_text() for p in manifest['files'] if '/pages/' in p)
keys = set(re.findall(r'l10n\.([A-Za-z][A-Za-z0-9_]*)', original))
missing = sorted(k for k in keys if not re.search(r'\b' + k + r'\b', current))
assert not missing, f'Original localization/field lost: {missing}'
service_hashes = {}
for file, expected in manifest['files'].items():
    if '/pages/' in file:
        continue
    actual = hashlib.sha256((ROOT / file).read_bytes()).hexdigest()
    assert actual == expected, f'Shared service changed: {file}'
    service_hashes[file] = actual
# The original SyncEngine part methods also remain byte-identical to source SHA.
for source in sorted((ROOT / 'lib/cloud/sync').glob('sync_engine_*.dart')):
    relative = source.relative_to(ROOT).as_posix()
    baseline = subprocess.check_output(['git', 'show', manifest['source_commit'] + ':' + relative], cwd=ROOT)
    expected = hashlib.sha256(baseline).hexdigest()
    actual = hashlib.sha256(source.read_bytes()).hexdigest()
    assert actual == expected, f'SyncEngine part changed: {relative}'
    service_hashes[relative] = actual
for call in ['cloud.createInvite(', 'previewInvite(ref,', 'acceptInvite(ref,',
             'cloud.removeMember(', 'engine.onInviteAccepted(',
             'engine.checkSyncHealth(', 'engine.backfillUntrackedEntities(',
             'engine.syncMyProfile(', 'engine.sync(', 'reconcileProfileToServer(',
             'provider.getTwoFactorStatus(', 'Share.share(', 'Clipboard.setData(']:
    assert call in current, f'Original operation lost: {call}'
for page in ['beecount_cloud_sync_page', 'invite_page', 'join_shared_ledger_page', 'member_list_page', 'member_stats_page']:
    text = (ROOT / 'lib/pages/cloud' / (page + '.dart')).read_text()
    assert 'cloud_shared_' in text
pure = (ROOT / 'packages/beecount_business_ui/lib/src/cloud_shared.dart').read_text()
assert not re.search(r'flutter_riverpod|flutter_cloud_sync|NetworkImage|Image\.network|dart:io|providers\.dart', pure)
assert 'final result = await engine.sync(' in current and 'if (result.hasError)' in current
assert 'Transfer ownership: Phase 3 only' in current
assert "'all'" in current and "'year'" in current and "'month'" in current
assert set(re.findall(r'(?m)^\s*import ([^;]+);', pure)) == {"'package:beecount_ui/beecount_ui.dart'", "'package:flutter/material.dart'"}
print(json.dumps({'status':'PASS','source_commit':manifest['source_commit'],'original_l10n_fields':len(keys),'pages':5,'unchanged_service_sha256':service_hashes,'network':'not called'},ensure_ascii=False,indent=2))
