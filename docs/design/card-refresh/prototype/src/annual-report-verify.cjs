const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert/strict');
const root=path.resolve(__dirname,'../../../../..');
const arb=JSON.parse(fs.readFileSync(path.join(root,'lib/l10n/app_zh.arb'),'utf8'));
const handlers={},definitions={};
const state={};
const context={state,console,Set,requestAnimationFrame:()=>{},brandImages:{bee:'data:image/png;base64,QA'},document:{addEventListener:(name,callback)=>(handlers[name]??=[]).push(callback),querySelector:()=>null},fDefine:(key,title,group,source,body)=>definitions[key]={title,group,source,body},fRender:()=>'',subhead:title=>`<header>${title}</header>`,esc:value=>String(value).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;'),icon:()=>'<svg></svg>',btn:(action,text,label,kind)=>`<button data-action="${action}" aria-label="${label}" class="${kind}">${text}</button>`,render:()=>{},notice:()=>{}};
vm.createContext(context);
for(const file of ['annual-report.js','receipt.js']){
  const source=fs.readFileSync(path.join(__dirname,file),'utf8').replace('__ANNUAL_REPORT_TEXTS__',()=>JSON.stringify(arb));
  new vm.Script(source,{filename:file}).runInContext(context);
}
assert.equal(Object.keys(definitions).length,9);
for(let chapter=0;chapter<7;chapter++){
  state.ar89Chapter=chapter;
  const html=context.fRender('annual-report');
  assert.match(html,/ar89-report/);
  assert.doesNotMatch(html,/undefined|NaN|\{count/);
}
state.ar89Chapter=0;state.ar89Year=2026;const current=context.fRender('annual-report');state.ar89Year=2025;const previous=context.fRender('annual-report');assert.notEqual(current,previous);assert.match(previous,/2025/);
for(const mode of ['loading','empty','error','long'])assert.doesNotMatch(context.fRender('annual-report-'+mode),/undefined|NaN/);
const defaults=context.ar89ReceiptPaper();assert.match(defaults,/QA 一顿简单的午餐/);assert.match(defaults,/#朋友/);assert.doesNotMatch(defaults,/QA 私人账户|QA 私人账本/);
state.ar89ReceiptFields=['account','ledger'];const privateFields=context.ar89ReceiptPaper();assert.match(privateFields,/QA 私人账户/);assert.match(privateFields,/QA 私人账本/);assert.doesNotMatch(privateFields,/QA 一顿简单的午餐|#朋友/);
assert.match(context.fRender('receipt-preview'),/ar89-receipt-open/);assert.match(context.fRender('receipt-unavailable'),/无法|加载|小票/);
assert.ok(handlers.click.length>=2);assert.ok(handlers.change.length>=1);
for(const file of ['annual-report.css','receipt.css'])assert.doesNotMatch(fs.readFileSync(path.join(__dirname,file),'utf8'),/var\(--(surface|muted|ink|soft|accent),/);
console.log('PASS annual 7 chapters + 4 states; year changes; receipt private defaults and explicit fields; 9 independent routes; CSS uses shared tokens. Native UI/browser rendering not exercised.');
