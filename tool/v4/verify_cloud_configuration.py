#!/usr/bin/env python3
"""Read-only r91 backup, request/storage and localization contract audit."""
import hashlib
import json
import re
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
BACKUP = ROOT / '.docs/v4-ui-migration/backup/parallel-cloud-config-r91'
manifest = json.loads((BACKUP / 'manifest.json').read_text())
for row in manifest['files']:
    old = BACKUP / row['path']
    assert hashlib.sha256(old.read_bytes()).hexdigest() == row['sha256'], row['path']
    assert not old.stat().st_mode & 0o222
    if '/pages/' not in row['path']:
        assert hashlib.sha256((ROOT / row['path']).read_bytes()).hexdigest() == row['sha256'], 'Service source changed: ' + row['path']

def strip_comments(text):
    result=[];i=0;quote=None
    while i<len(text):
        c=text[i]
        if quote:
            result.append(c)
            if c=='\\' and i+1<len(text): i+=1;result.append(text[i])
            elif c==quote: quote=None
        elif c in "'\"": quote=c;result.append(c)
        elif text[i:i+2]=='//':
            while i<len(text) and text[i]!='\n':i+=1
            continue
        else:result.append(c)
        i+=1
    return ''.join(result)

def canonical(text):
    text = re.sub(r'\s+', '', strip_comments(text)).replace('CloudConfigurationControls','CloudServicePage')
    text = text.replace('if(!mounted)return;', '').replace('if(!context.mounted)return;', '')
    text = re.sub(r'if\(mounted\)\{(showToast\([^;]+;)\}', r'if(mounted)\1', text)
    return text

def section(text,start,end):return text[text.index(start):text.index(end,text.index(start))]
old=(BACKUP/'lib/pages/cloud/cloud_service_page.dart').read_text()
new=(ROOT/'lib/presentation/v4/bindings/cloud_configuration_controls.dart').read_text()
methods=[('_autoTestActiveConnection','  @override\n  Widget build'),('_switchService','  Future<void> _configureService'),('_configureService','  Future<void> _showBeeCountCloudConfigDialog'),('_showBeeCountCloudConfigDialog','  Future<void> _showSupabaseConfigDialog'),('_showSupabaseConfigDialog','  Future<void> _showWebdavConfigDialog'),('_showWebdavConfigDialog','  Future<void> _showS3ConfigDialog'),('_showS3ConfigDialog','  String _getTypeName')]
for name,end in methods:
    start='  Future<void> '+name+'('
    assert canonical(section(old,start,end))==canonical(section(new,start,end)), 'Service contract changed: '+name
before=old[old.index('  Future<void> _testConnection('):old.index('// Supabase配置对话框')]
after=new[new.index('  Future<void> _testConnection('):new.index('// Supabase配置对话框')]
def connection(text):
    value=canonical(text).replace('finall10n=AppLocalizations.of(context);','').replace('l10n.','AppLocalizations.of(context).')
    return value
assert connection(before)==connection(after),'Connection request contract changed'
login_old=(BACKUP/'lib/pages/auth/login_page.dart').read_text()
login_new=(ROOT/'lib/presentation/v4/bindings/cloud_login_controls.dart').read_text()
for start,end in [('  Future<void> _loadSavedCredentials()', '  Future<void> _saveCredentials('),('  Future<void> _saveCredentials(', '  @override\n  void dispose()')]:
    assert canonical(section(login_old,start,end))==canonical(section(login_new,start,end)),start
body_old=section(login_old,'                                          final email = emailCtrl.text.trim();','                                        },\n                                  child: busy')
body_new=section(login_new,'    final email = emailCtrl.text.trim();','\n  @override\n  Widget build')
assert canonical(body_old)+'}'==canonical(body_new),'Login request/post-auth contract changed'
pattern=r'(?:AppLocalizations\.of\(context\)|\bl10n|\bl)\s*\.\s*([a-zA-Z]\w*)'
old_keys=set(re.findall(pattern,old+login_old));new_keys=set(re.findall(pattern,new+login_new))
assert old_keys<=new_keys, 'Original localized content missing: '+repr(old_keys-new_keys)
assert '!kIsWeb && Platform.isIOS' in new
pure=(ROOT/'packages/beecount_business_ui/lib/src/cloud_configuration.dart').read_text()
for forbidden in ['riverpod','providers.dart','dart:io','http.','CloudAuthService','SharedPreferences']:
    assert forbidden not in pure
print(json.dumps({'status':'PASS','source_commit':manifest['source_commit'],'backup_files':9,'unchanged_service_files':7,'request_storage_contracts':11,'localized_keys_preserved':len(old_keys),'platform':'!kIsWeb && Platform.isIOS'},ensure_ascii=False))
