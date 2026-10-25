const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../../../../..'),texts=JSON.parse(fs.readFileSync(path.join(root,'lib/l10n/app_zh.arb'),'utf8'));
const source=fs.readFileSync(path.join(__dirname,'cloud-configuration.js'),'utf8').replace('__CLOUD_CONFIGURATION_TEXTS__',JSON.stringify(texts));
const handlers={},ctx={state:{},fDefs:{},rSpecs:{'cloud-config':{kind:'dialog'}},URL,
  esc:String,icon:name=>`<i>${name}</i>`,subhead:title=>`<header>${title}</header>`,
  btn:(action,label,aria,kind,attrs='')=>`<button data-action="${action}" ${attrs}>${label}</button>`,
  fRender:key=>'existing:'+key,cloud:()=>'<old-cloud>',render(){},document:{addEventListener(type,handler){handlers[type]=handler;}}};
ctx.fDefine=(key,title,group,source,body)=>{ctx.fDefs[key]={title,group,source,body};};vm.createContext(ctx);vm.runInContext(source,ctx);
const render=key=>vm.runInContext(`fRender(${JSON.stringify(key)})`,ctx);
const click=action=>handlers.click({target:{closest(selector){return selector==='[data-action]'?{dataset:{action}}:null;}},preventDefault(){},stopImmediatePropagation(){}});
assert.equal(ctx.state.cc91Tab,'offline');assert.equal(ctx.state.cc91Active,'local');assert.equal(ctx.rSpecs['cloud-config'],undefined);
assert.match(render('cloud-config'),/本地存储/);click('cc91-tab:backup');let backup=render('cloud-config');
for(const text of [texts.cloudCustomWebdavTitle,texts.cloudCustomS3Title,texts.cloudCustomSupabaseTitle])assert(backup.includes(text));assert(!backup.includes('data-action="cc91-select:icloud"'));
render('cloud-config-ios');assert(render('cloud-config-ios').includes('data-action="cc91-select:icloud"'));
for(const [type,count]of Object.entries({beecount:3,supabase:3,webdav:4,s3:7})){
  click('cc91-configure:'+type);const html=render('cloud-config');assert.equal((html.match(/data-cc91-field=/g)||[]).length,count);assert.match(html,/role="dialog"/);assert(!html.includes('data-cc91-field="apiPrefix"'));click('cc91-close');
}
click('cc91-configure:beecount');ctx.state.cc91Draft={url:' https://qa.example.invalid/path '};click('cc91-save');assert.equal(ctx.state.cc91Active,'local');assert.equal(ctx.state.cc91Configured.beecount.apiPrefix,'/api/v1');
click('cc91-select:beecount');assert.equal(ctx.state.cc91Overlay,'switch');click('cc91-close');assert.equal(ctx.state.cc91Active,'local');
click('cc91-select:beecount');click('cc91-activate');assert.equal(ctx.state.cc91Active,'beecount');assert(!ctx.state.cc91Event.includes('{type}'));assert(render('cloud-config').includes('qa.example.invalid'));assert(!render('cloud-config').includes('https://qa.example.invalid/path'));
click('cc91-configure:s3');ctx.state.cc91Draft={endpoint:'https://s3.example.invalid',region:'',accessKey:'qa',secretKey:'qa',bucket:'qa',useSSL:false,port:'9000'};click('cc91-save');assert.equal(ctx.state.cc91Configured.s3.endpoint,'s3.example.invalid');assert.equal(ctx.state.cc91Configured.s3.region,'us-east-1');assert.equal(ctx.state.cc91Configured.s3.useSSL,false);assert.equal(ctx.state.cc91Configured.s3.port,9000);
for(const [type,lastKey]of Object.entries({beecount:'cloudTutorialFeature4',webdav:'cloudWebdavHelpStep5',supabase:'cloudSupabaseHelpFaq3',s3:'cloudS3HelpProvider7',icloud:'cloudIcloudHelpFaq4',multi:'cloudSyncGuideLimitItem4'})){click('cc91-help:'+type);assert(render('cloud-config').includes(texts[lastKey]));click('cc91-close');}
assert.match(render('login'),/data-cc91-remember/);assert(!render('login').includes('修改服务器配置'));assert(render('login-webdav').includes(texts.webdavConfiguredMessage));assert(!render('login-webdav').includes('data-cc91-login'));
ctx.state.cc91Email='invalid';click('cc91-login');assert.equal(ctx.state.cc91Error,texts.authInvalidEmail);
ctx.state.cc91Email='qa@example.invalid';click('cc91-login');assert.equal(ctx.state.cc91Error,texts.authErrorInvalidCredentials);
assert.equal(render('cloud-sync'),'existing:cloud-sync');assert(render('cloud-config-normal').includes(texts.cloudStatusNormal));assert(render('cloud-config-failed').includes(texts.cloudStatusFailed));assert(!/fetch\(|XMLHttpRequest|https?:\/\/localhost/.test(source));
console.log(JSON.stringify({status:'PASS',routes:Object.keys(ctx.fDefs).length,services:6,dialogs:{beecount:3,supabase:3,webdav:4,s3:7},completeHelp:6,network:'not called'}));
