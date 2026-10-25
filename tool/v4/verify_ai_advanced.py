#!/usr/bin/env python3
"""Read-only r101 contract and source-hash verification; no App/Cloud requests."""
import hashlib
import json
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BACKUP=ROOT/'.docs/v4-ui-migration/backup/parallel-ai-advanced-r101'
manifest=json.loads((BACKUP/'manifest.json').read_text())
page_files={'lib/pages/ai/agent_'+name+'_page.dart' for name in ['memory','permissions','activity']}
services={}
for name,expected in manifest['files'].items():
    source=BACKUP/name
    assert hashlib.sha256(source.read_bytes()).hexdigest()==expected
    assert source.stat().st_mode&0o222==0
    if name not in page_files:
        actual=hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
        assert actual==expected, 'Original dependency changed: '+name
        services[name]=actual
original='\n'.join((BACKUP/name).read_text() for name in page_files)
new='\n'.join(p.read_text() for p in (ROOT/'lib/presentation/v4/bindings').glob('ai_advanced_*.dart'))
keys=set(re.findall(r'(?:l10n|AppLocalizations\.of\(context\))\.([a-zA-Z]\w*)',original))
assert all(re.search(r'\b'+key+r'\b',new) for key in keys)
for call in ['listActive(ledgerId:', 'forget(memory.id, ledgerId:', 'clearForLedger(ledger)', 'listRecentRuns(ledgerId:', 'listToolCalls(run.runId)', '.readAll()', '.setPermission(name, permission)', '.restoreDefaults()']:
    assert call in new, 'Original operation lost: '+call
assert 'clearAll(' not in new and 'saveExplicit(' not in new
for prohibited in ['agentAppFacadeProvider','localAgentToolGatewayProvider','aiChatServiceProvider','agentModelCapabilityServiceProvider']:
    assert prohibited not in new
pure=(ROOT/'packages/beecount_business_ui/lib/src/ai_advanced.dart').read_text()
for prohibited in ['flutter_riverpod','agentcore','dart:io','SharedPreferences','providers.dart','http.']:
    assert prohibited not in pure
# Original business assertions remain unchanged; only lifecycle/scroll driving changes.
def expects(source):
    output=[]
    for match in re.finditer(r'\bexpect\(',source):
        start=match.start();i=match.end();depth=1;quote=None
        while depth:
            c=source[i]
            if quote:
                if c==quote and source[i-1]!='\\':quote=None
            elif c in "'\"":quote=c
            elif c=='(':depth+=1
            elif c==')':depth-=1
            i+=1
        output.append(re.sub(r'\s+','',source[start:i]))
    return output
original_tests=ROOT/'.docs/v4-ui-migration/backup/parallel-ai-advanced-r101-original-tests'
tests=json.loads((original_tests/'manifest.json').read_text())
assertions=0
for name in tests['files']:
    old=expects((original_tests/name).read_text());now=expects((ROOT/name).read_text())
    assert old==now, 'Original test assertion changed: '+name
    assertions+=len(old)
print(json.dumps({'status':'PASS','source_commit':manifest['source_commit'],'pages':3,'old_l10n_fields':len(keys),'original_assertions_preserved':assertions,'unchanged_dependency_sha256':services,'model_and_tool_requests':0},ensure_ascii=False,indent=2))
