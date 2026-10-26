const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert/strict'),fixtures=require('./detail-currency-samples.cjs');
const texts=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../../../../../lib/l10n/app_zh.arb'),'utf8'));
const source=fs.readFileSync(path.join(__dirname,'detail-currency.js'),'utf8').replace('__DETAIL_CURRENCY_TEXTS__',()=>JSON.stringify(texts)).replace('__DETAIL_CURRENCY_FIXTURES__',()=>JSON.stringify(fixtures));
const context=vm.createContext({state:{},settings:{},esc:String,icon:name=>name});vm.runInContext(source,context);
function summary(s,kind='category'){context.value=s;return JSON.parse(vm.runInContext(`JSON.stringify(dc97Summary(value,'${kind}'))`,context));}
const base=structuredClone(fixtures.defaults),before=JSON.stringify(base.rows);
const all=summary(base);assert.ok(Math.abs(all.expense-272.6)<1e-8);assert.equal(all.projection.target,'CNY');assert.equal(all.count,5);
const changed=summary({...base,rates:{CNY:{USD:{rate:'7.2',manual:true}}}});assert.equal(changed.expense,275);assert.equal(JSON.stringify(base.rows),before);
const usd=summary({...base,target:2});assert.ok(Math.abs(usd.expense-(24+102.2/7.1))<1e-8);
for(const [scene]of fixtures.scenes.map(s=>[s])){const s=summary(scene.scenario,scene.kind);assert.ok(s.rows.every(row=>typeof row.id==='number'));context.scene=scene;const html=vm.runInContext(`dc97Active=dc97Copy(scene.scenario);dc97Render(scene.kind)`,context);assert.ok(html.includes('dc97-detail'));if(scene.scenario.privacy){assert.ok(!html.includes('85.20'));assert.ok(!html.includes('272.60'));}}
for(const key of ['missing','native-missing','unknown','invalid']){const scene=fixtures.scenes.find(s=>s.key==='detail-currency-category-'+key),s=summary(scene.scenario);assert.equal(s.projection.complete,false);assert.ok(s.projection.missing.length>0);}
const legacy=summary(fixtures.scenes.find(s=>s.key.endsWith('category-legacy')).scenario);assert.equal(legacy.expense,10);assert.equal(legacy.projection.complete,true);
const shared=summary(fixtures.scenes.find(s=>s.key.endsWith('tag-shared')).scenario,'tag');assert.equal(shared.rows[0].categoryId,-9701);assert.ok(Math.abs(shared.expense-142)<1e-8);assert.equal(shared.rows[0].native,20);
assert.equal(summary({...base,scope:'current'}).count,3);assert.equal(summary({...base,period:'month'}).count,3);assert.equal(summary({...base,period:'year'}).count,4);
const custom=summary(fixtures.scenes.find(s=>s.key.endsWith('tag-custom-month')).scenario,'tag');assert.equal(custom.count,1);assert.equal(custom.expense,7);
console.log('PASS 31 routes: two source ledger bases, target/inverse/quote changes, no source writes, missing/native/invalid/unknown, legacy, shared IDs, privacy, month/year/all/current. Pure prototype only.');
