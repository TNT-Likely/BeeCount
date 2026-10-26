const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../../../../..'),texts=JSON.parse(fs.readFileSync(path.join(root,'lib/l10n/app_zh.arb'),'utf8'));
const source=fs.readFileSync(path.join(__dirname,'cloud-backup.js'),'utf8').replace('__CLOUD_BACKUP_TEXTS__',JSON.stringify(texts));
const handlers={},timers=[];const ctx={state:{},fDefs:{},esc:String,icon:name=>`<i>${name}</i>`,subhead:title=>`<header>${title}</header>`,render(){},setTimeout(fn){timers.push(fn);},fRender:key=>'existing:'+key,
 btn:(action,label,aria,kind,attrs='')=>`<button data-action="${action}" ${attrs}>${label}</button>`,document:{addEventListener(type,handler){handlers[type]=handler;}}};
ctx.fDefine=(key,title,group,source,body)=>{ctx.fDefs[key]={title,group,source,body};};vm.createContext(ctx);vm.runInContext(source,ctx);
const render=key=>vm.runInContext(`fRender(${JSON.stringify(key)})`,ctx),click=command=>handlers.click({target:{closest(){return {dataset:{action:'cb95-'+command}};}},preventDefault(){},stopImmediatePropagation(){}});
let html=render('backup');assert(html.includes(texts.cloudSyncHint));assert(html.includes(texts.mineUploadTitle));assert(html.includes(texts.mineDownloadTitle));assert(!/\{(?:count|time|fingerprint)\}/.test(html));
click('detail');html=render('backup');assert(html.includes('local-qa'));assert(html.includes('remote-qa'));click('close');
for(const diff of ['notConfigured','notLoggedIn','noRemote','inSync','localNewer','cloudNewer','different','error']){ctx.state.cb95Diff=diff;html=render('backup');assert(html.includes('cb95-upload'));if(['notLoggedIn','inSync'].includes(diff))assert(html.includes('data-action="cb95-upload" disabled'));}
html=render('backup-signed-out');assert(html.includes('data-action="cb95-login"'));assert(html.includes('data-cb95-auto  disabled'));
html=render('backup-beecount');assert(html.includes('qa@example.invalid'));assert(!html.includes('data-action="cb95-upload"'));assert(!html.includes('data-cb95-auto'));
html=render('backup-relogin');assert(html.includes(texts.cloudReloginTitle));click('relogin');assert.equal(ctx.state.cb95User,true);
html=render('backup-preview');assert(html.includes(texts.syncPreviewTitle));assert.equal((html.match(/data-cb95-change=/g)||[]).length,3);click('select-all');assert(ctx.state.cb95Selected.every(x=>!x));assert(render('backup-preview').includes('data-action="cb95-apply" disabled'));click('close');assert.equal(ctx.state.cb95Modal,'');
html=render('backup-old-format');assert(html.includes(texts.syncPreviewOldFormatMessage));click('close');assert.equal(ctx.state.cb95Modal,'');
html=render('backup-error');assert(html.includes('QA status failed'));click('retry');assert.equal(ctx.state.cb95Error,'');
render('backup');ctx.state.cb95Diff='different';click('upload');assert.equal(ctx.state.cb95Busy,'upload');timers.shift()();assert.equal(ctx.state.cb95Diff,'inSync');assert(render('backup').includes(texts.mineUploadSuccess));
assert.equal(render('cloud-sync'),'existing:cloud-sync');assert(!source.includes('fetch('));
console.log(JSON.stringify({status:'PASS',routes:Object.keys(ctx.fDefs).length,statuses:8,originalPreviewSelection:true,legacyConfirmation:true,network:'not called'}));
