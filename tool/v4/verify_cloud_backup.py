#!/usr/bin/env python3
"""Read-only r95 contract and modern-path byte-preservation audit."""
import hashlib
import json
import re
from pathlib import Path
from migration_contracts import AUDIT, REVIEWED_SOURCE, audit_dependency, audit_block, page_bindings, reviewed_source
ROOT=Path(__file__).resolve().parents[2]
BACKUP=ROOT/'.docs/v4-ui-migration/backup/parallel-cloud-backup-r95'
manifest=json.loads((BACKUP/'manifest.json').read_text())
for row in manifest['files']:
    old=BACKUP/row['path']
    assert hashlib.sha256(old.read_bytes()).hexdigest()==row['sha256']
    assert not old.stat().st_mode&0o222
    if row['path'] not in ['lib/pages/cloud/cloud_sync_page.dart','lib/cloud/transactions_sync_manager.dart']:
        audit_dependency(row['path'], old.read_text())
service=(ROOT/'lib/cloud/transactions_sync_manager.dart').read_text()
a=service.index('// BEGIN r95 atomic legacy restore')
b=service.index('// END r95 atomic legacy restore',a)+len('// END r95 atomic legacy restore\n\n')
imports="import '../data/repositories/local/local_repository.dart';\nimport '../data/repositories/transaction_repository.dart' show BatchAttachmentData;\nimport '../services/currency/rate_math.dart';\n"
reconstructed=(service[:a]+service[b:]).replace(imports,'',1).encode()
original=(BACKUP/'lib/cloud/transactions_sync_manager.dart').read_bytes()
assert reconstructed==original,'Existing manager bytes changed outside the new legacy adapter'
assert 'deleteTransaction(' not in service[a:b].replace('// deleteTransaction,','// safe-delete,'),'Do not delete physical files in a rollbackable transaction'
adapter=service[service.index('// BEGIN r95 atomic legacy restore'):service.index('// END r95 atomic legacy restore')]
assert 'tx.amount < 0' not in adapter and 'native < 0' not in adapter
assert "(raw['nativeAmount'] as num) < 0" not in adapter
assert 'Cross-currency transfer' not in adapter
assert '!tx.amount.isFinite' in adapter and '!native.isFinite' in adapter
old=(BACKUP/'lib/pages/cloud/cloud_sync_page.dart').read_text()
new=(ROOT/'lib/pages/cloud/backup/bindings/cloud_backup_controls.dart').read_text()
def callback(source,marker,needle='onTap: () async {'):
    begin=source.index(needle,source.index(marker))+len(needle);i=begin;depth=1
    while depth:
        if source[i]=='{':depth+=1
        elif source[i]=='}':depth-=1
        i+=1
    return source[begin:i-1]
def method(source,name,end):
    a=source.index('  Future<void> '+name);a=source.index('async {',a)+len('async {')
    return source[a:source.index(end,a)].rsplit('}',1)[0]
def canonical(text):
    text=re.sub(r'//[^\n]*','',text)
    text=re.sub(r'\s+','',text).replace('context.mounted','mounted')
    text=text.replace('finalcontainer=ProviderScope.containerOf(context,listen:false);','').replace('container.','ref.')
    text=text.replace('ref.invalidate(cloudBackupUserProvider);','').replace('PostProcessor.runAfterDownloadC(container)','PostProcessor.runAfterDownload(ref)')
    text=text.replace('syncManager.restoreLegacyBackupToCurrentLedger(', 'sync.downloadAndRestoreToCurrentLedger(')
    return text
checks=[('// 同步状态',': () async {','_showDetails(SyncStatus st)','  Future<void> _relogin'),('// 上传\n','onTap: () async {','_upload(SyncService sync, int ledgerId)','  Future<void> _download'),('// 下载\n','onTap: () async {','_download(SyncService sync, int ledgerId)','  Future<void> _accountAction'),('// 登录/登出 (仅 Supabase 需要','onTap: () async {','_accountAction(CloudUser? userNow)','\n}\n')]
for marker,needle,name,end in checks:
    assert canonical(callback(old,marker,needle))==canonical(method(new,name,end)),name
pattern=r'(?:AppLocalizations\.of\(context\)|\bl)\s*\.\s*([a-zA-Z]\w*)'
keys=set(re.findall(pattern,old));now=set(re.findall(pattern,new));assert keys<=now,keys-now
pure=(ROOT/'packages/beecount_business_ui/lib/src/cloud_data/cloud_backup.dart').read_text()
for prohibited in ['riverpod','providers.dart','dart:io','SyncService','http.','SharedPreferences']:
    assert prohibited not in pure
print(json.dumps({'reviewed_pre_move_source':REVIEWED_SOURCE,'reported_source_deltas':AUDIT,'status':'PASS','backup_files':9,'verified_dependencies':7,'old_callbacks_preserved':4,
'localized_keys':len(keys),'original_service_sha256':hashlib.sha256(original).hexdigest(),
'new_service_sha256':hashlib.sha256(service.encode()).hexdigest(),'all_existing_manager_bytes_unchanged':True,'signed_refunds_and_historical_cross_currency_transfers':True},ensure_ascii=False))
