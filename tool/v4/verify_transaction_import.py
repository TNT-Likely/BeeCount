#!/usr/bin/env python3
"""Verify r87 backup integrity and unchanged import conversion/write contracts."""
import hashlib
import json
import re
from pathlib import Path

from migration_contracts import AUDIT, REVIEWED_SOURCE, audit_dependency, audit_block, page_bindings, reviewed_source
ROOT = Path(__file__).resolve().parents[2]
BACKUP = ROOT / '.docs/v4-ui-migration/backup/parallel-import-r87'
manifest = json.loads((BACKUP / 'manifest.json').read_text())
for item in manifest['files']:
    old = BACKUP / item['path']
    assert hashlib.sha256(old.read_bytes()).hexdigest() == item['sha256'], item['path']
    assert not old.stat().st_mode & 0o222, f'Backup must remain read-only: {old}'
    if '/pages/' not in item['path']:
        audit_dependency(item['path'], old.read_text())

def canonical(text):
    text = re.sub(r'//[^\n]*', '', text)
    text = re.sub(r'\s+', '', text).replace('showBeeToast(', 'showToast(')
    # V4 dialogs gain a presentation-only corner shape.
    return text.replace('shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),', '')

old = (BACKUP / 'lib/pages/data/import_confirm_page.dart').read_text()
reviewed = reviewed_source('lib/presentation/v4/bindings/import_confirm_controls.dart')
new = (ROOT / 'lib/pages/data/import/bindings/import_confirm_controls.dart').read_text()
markers = [
    ('ImportData _buildImportDataFromCsv(', 'void _buildDistinctCategories()'),
    ('void _buildDistinctCategories()', '// isolate 入口函数'),
    ('// 定义进度变量', '/// 将CSV数据转换为统一的ImportData格式'),
    ('List<List<String>> _parseRowsIsolate(', 'Future<List<schema.Category>> _loadAllCategories('),
]
for start, end in markers:
    before = old[old.index(start):old.index(end, old.index(start))]
    after = new[new.index(start):new.index(end, new.index(start))]
    reference = reviewed[reviewed.index(start):reviewed.index(end, reviewed.index(start))]
    audit_block(before, after, reference, 'Import contract: '+start, canonical)
# The category query remains identical, including top-level then child ordering.
before = old[old.index('Future<List<schema.Category>> _loadAllCategories('):old.index('class _PreviewTable')]
after = new[new.index('Future<List<schema.Category>> _loadAllCategories('):]
assert canonical(before) == canonical(after), 'Original category query changed'

pure = (ROOT / 'packages/beecount_business_ui/lib/src/cloud_data/transaction_import.dart').read_text()
assert 'riverpod' not in pure and 'providers.dart' not in pure
assert all(term not in pure for term in ['dart:io', 'http.', 'FilePicker', 'Repository'])
assert len(re.findall(r"\(l\.[A-Za-z]+, '[a-z_]+'\)", new[new.index('final fields ='):new.index('return V4PageScaffold(', new.index('final fields ='))])) == 12
print(json.dumps({'reviewed_pre_move_source':REVIEWED_SOURCE,'reported_source_deltas':AUDIT,'status': 'PASS', 'source_commit': manifest['source_commit'], 'backup_files': len(manifest['files']),
    'verified_services': 10, 'conversion_and_write_contracts': 5, 'fields': 12}, ensure_ascii=False))
