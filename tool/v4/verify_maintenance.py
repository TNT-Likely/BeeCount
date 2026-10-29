#!/usr/bin/env python3
"""Read-only r103 UI, original contract and approved service-change audit."""
import hashlib
import json
import re
from pathlib import Path
from migration_contracts import AUDIT, REVIEWED_SOURCE, audit_dependency, audit_block, page_bindings, reviewed_source
ROOT=Path(__file__).resolve().parents[2]
BACKUP=ROOT/'.docs/v4-ui-migration/backup/parallel-maintenance-r103'
manifest=json.loads((BACKUP/'manifest.json').read_text())
pages=['lib/pages/settings/log_center_page.dart','lib/pages/settings/storage_management_page.dart','lib/pages/settings/widget_management_page.dart','lib/pages/maintenance/orphan_cleanup_page.dart']
logger='lib/services/system/logger_service.dart'
cleaner='lib/services/maintenance/orphan_cleaner.dart'
unchanged={}
for name,expected in manifest['files'].items():
    old=BACKUP/name
    assert hashlib.sha256(old.read_bytes()).hexdigest()==expected
    assert old.stat().st_mode&0o222==0
    if name not in pages+[logger,cleaner]:
        current=audit_dependency(name, old.read_text())
        unchanged[name]=current
for file in ['maintenance-r103-logger-handoff.json','maintenance-r103-orphan-handoff.json']:
    for row in json.loads((ROOT/'.docs/v4-ui-migration'/file).read_text())['files']:
        assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest()==row['sha256'],row['path']
old=(BACKUP/logger).read_text();new=(ROOT/logger).read_text()
regions=[(None,'class LoggerService {'),('  /// 获取所有日志','  /// 加载持久化的日志'),('  /// 保存日志到持久化存储','  Future<void> _doSaveLogs()'),('  /// Debug 日志','  /// 清空日志'),('  /// 导出所有日志为文本',None)]
for start,end in regions:
    def block(source):return source[source.index(start) if start else 0:source.index(end) if end else len(source)]
    assert block(old)==block(new),(start,end)
old=(BACKUP/cleaner).read_text();new=(ROOT/cleaner).read_text();a=old.index('          for (final r in dbRecords)');b=new.index('          for (var index')
assert old[:a]==new[:b]
assert old[old.index('\n        });',a):]==new[new.index('\n        });',b):]
original='\n'.join((BACKUP/p).read_text() for p in pages)
current='\n'.join(p.read_text() for p in (ROOT/'lib/pages').rglob('maintenance_*.dart'))
keys=set(re.findall(r'(?:l10n|AppLocalizations\.of\(context\))\.([A-Za-z]\w*)',original))
missing=[key for key in keys if not re.search(r'\b'+key+r'\b',current)]
assert not missing,missing
for p in pages:
    assert 'maintenance_' in (ROOT/p).read_text()
for literal in ["endsWith('.tflite')","contains('BeeCount_')","endsWith('.apk')",'getApplicationDocumentsDirectory','getExternalStorageDirectory','_logger.exportAsText()','log.toFormattedString()','_logger.clear()','orphanScanReportProvider','cleaner.clean(records)','OrphanSeeder(db: db)']:
    assert literal in current,literal
old_sample=(BACKUP/'lib/pages/settings/widget_management_page.dart').read_text().split('Account _sampleAccount(',1)[1]
new_sample=(ROOT/'lib/pages/settings/widgets/bindings/maintenance_widgets.dart').read_text().split('Account _sampleAccount(',1)[1]
assert re.sub(r'\s+','',old_sample)==re.sub(r'\s+','',new_sample),'Widget synthetic data changed'
for view in ['GlanceView.medium','GlanceView.small','NetWorthView(','QuickAddView(','BudgetView(','RecentView(','DashboardView(','ConsumptionRhythmView(','BeeTrailView(']:
    assert view in current,view
pure=(ROOT/'packages/beecount_business_ui/lib/src/cloud_data/maintenance.dart').read_text()
for prohibited in ['flutter_riverpod','dart:io','path_provider','providers.dart','LoggerService','OrphanScanner','OrphanCleaner','http.']:
    assert prohibited not in pure,prohibited
print(json.dumps({'reviewed_pre_move_source':REVIEWED_SOURCE,'reported_source_deltas':AUDIT,'status':'PASS','source_commit':manifest['source_commit'],'pages':4,'old_l10n_fields':len(keys),'widget_previews':9,'widget_sample_data_unchanged':True,'approved_service_regions_unchanged':True,'verified_dependency_sha256':unchanged,'network_and_device_calls':0},ensure_ascii=False,indent=2))
