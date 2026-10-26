// Local contract checks only. Browser rendering and native files are separate QA.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../../../../..');
const texts = JSON.parse(fs.readFileSync(path.join(root, 'lib/l10n/app_zh.arb'), 'utf8'));
const source = fs.readFileSync(path.join(__dirname, 'transaction-import.js'), 'utf8')
  .replace('__TRANSACTION_IMPORT_TEXTS__', JSON.stringify(texts));
const handlers = {};
let renders = 0;
const ctx = {state: {}, fDefs: {}, esc: s => String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;'),
  icon: name => `<i data-icon="${name}"></i>`,
  btn: (action, label, aria, kind, attrs='') => `<button data-action="${action}" class="${kind}" aria-label="${aria}" ${attrs}>${label}</button>`,
  subhead: title => `<header>${title}</header>`, fRender: key => 'existing:' + key,
  fDefine(key,title,group,source,body){this.fDefs[key]={title,group,source,body};},
  render(){renders++;}, document: {addEventListener(type,handler){handlers[type]=handler;}}};
// fDefine is called as a plain function by the module.
ctx.fDefine=(key,title,group,source,body)=>{ctx.fDefs[key]={title,group,source,body};};
vm.createContext(ctx);vm.runInContext(source,ctx);
const render = key => vm.runInContext(`fRender(${JSON.stringify(key)})`,ctx);
assert.equal(ctx.state.im87Source,'generic');
const file=render('import');
assert.match(file,/accept=".csv,.tsv,.txt,.xlsx"/);
assert.match(file,/未选择文件/);
assert.doesNotMatch(file,/粘贴|首行为表头|重复数据/);
const mapping=render('mapping');
assert.equal((mapping.match(/data-im87-map=/g)||[]).length,12);
assert.equal((mapping.match(/<tr>/g)||[]).length,10);
assert.match(mapping,/仅预览前 10 行，共 26 行/);
for(const key of ['currency','sub_category','from_account','to_account','tags','attachments'])assert.match(mapping,new RegExp('data-im87-map="'+key+'"'));
assert.match(render('category-map'),/保持原名（自动创建\/合并）/);
assert.match(render('import-preview'),/确认账户币种/);
assert.doesNotMatch(render('import-preview'),/修正为 CNY|跳过异常记录/);
assert.match(render('import-progress'),/后台导入/);
assert.match(render('import-progress'),/取消导入/);
assert.match(render('import-partial'),/跳过 1 条非收支记录/);
assert.match(render('import-cancelled'),/（已取消）/);
assert.match(render('import-invalid-currency'),/币种无效/);
assert.match(render('import-open-error'),/无法打开文件选择器/);
assert.equal(render('other-page'),'existing:other-page');
function click(action){handlers.click({target:{closest(){return {dataset:{action}};}},preventDefault(){},stopImmediatePropagation(){}});}
click('im87-source:wechat');assert.equal(ctx.state.im87Source,'wechat');
click('im87-next');assert.equal(ctx.state.page,'flow-category-map');
click('im87-review');assert.equal(ctx.state.im87Overlay,'review');
click('im87-dismiss');assert.equal(ctx.state.im87Overlay,'');
click('im87-confirm');assert.equal(ctx.state.page,'flow-import-progress');
click('im87-cancel');assert.equal(ctx.state.page,'flow-category-map');assert.match(ctx.state.im87Event,/导入中/);
assert.equal(renders,6);
console.log(JSON.stringify({status:'PASS',routes:Object.keys(ctx.fDefs).length,fields:12,previewRows:10,interactions:6,nativeFilePicker:'not executed'}));
