const vm=require('vm'),assert=require('assert/strict'),m=require('./auto-billing-module.cjs'),fixtures=require('./auto-billing-samples.cjs');
const c=vm.createContext({esc:String,icon:String});vm.runInContext(m.javascript,c);
for(const scene of fixtures.scenes){c.scene=scene;const html=vm.runInContext('ab92Use(scene.key)',c);assert.ok(html.includes('ab92-page'));if(scene.data.platform==='ios')assert.ok(!html.includes('ab92-switch'));else assert.ok(!html.includes('ab92-manual'));}
function change(key,expr){c.key=key;vm.runInContext('ab92Use(key)',c);return vm.runInContext(expr,c);}
assert.equal(change('auto-billing-permission-denied','ab92Toggle()'),false);assert.equal(vm.runInContext('ab92Data.enabled',c),false);
assert.equal(change('auto-billing-enable-error','ab92Toggle()'),false);assert.equal(change('auto-billing-disable-error','ab92Toggle()'),false);
assert.equal(change('auto-billing-android','ab92Toggle()'),true);assert.equal(vm.runInContext('ab92Data.enabled',c),true);
assert.equal(change('auto-billing-busy','ab92Toggle()'),false);
change('auto-billing-ios','ab92Open("shortcut")');assert.equal(vm.runInContext('ab92Requests[0].url',c),fixtures.shortcutUrl);
change('auto-billing-ios-opening','ab92Open("shortcut")');assert.equal(vm.runInContext('ab92Requests.length',c),0);
assert.ok(!m.javascript.includes('launchUrl('));assert.ok(!m.javascript.includes('window.open('));assert.ok(!m.javascript.includes('fetch('));assert.equal(m.scenes.length,16);
console.log('PASS 15 platform states, denied/error/busy guards, original URL callback identity, 0 external/native actions; controlled sample exported.');
