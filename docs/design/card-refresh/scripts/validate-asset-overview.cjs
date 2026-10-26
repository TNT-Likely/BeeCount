const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..');
function assert(v,m){if(!v)throw Error(m)}
(async()=>{const b=await chromium.launch({channel:'chrome',headless:true}),p=await b.newPage(),checks=[],errors=[];try{
p.on('pageerror',e=>errors.push(e.message));
for(const width of [1440,390,320]){
 await p.setViewportSize({width,height:900});await p.goto(pathToFileURL(path.join(root,'components/ui-components.html')).href);await p.waitForFunction(()=>window.beeComponentCatalog);const sample=p.locator('#spec-59');
 assert(await sample.count()===1,'asset component missing');
 await sample.locator('[data-asset-privacy]').click();assert(!(await sample.innerText()).includes('30,890'),'hidden amount leaked');assert(await sample.locator('[data-asset-privacy]').getAttribute('aria-label')==='显示资产金额','privacy label');
 await sample.locator('[data-asset-chart="composition"]').click();assert(await sample.locator('[data-asset-chart-panel="composition"]').isVisible(),'composition missing');assert(!(await sample.innerText()).includes('10,000'),'hidden composition amount leaked');
 await sample.locator('[data-asset-privacy]').click();assert((await sample.innerText()).includes('30,890.00'),'privacy did not restore');
 await sample.locator('[data-asset-enabled]').uncheck();assert(await sample.locator('[data-asset-defaults]').isHidden(),'disabled defaults still visible');assert((await sample.innerText()).includes('汇率管理'),'rate entry removed');
 await sample.locator('[data-asset-enabled]').check();await sample.locator('[data-asset-default="支出"]').click();assert((await sample.locator('[data-asset-result]').textContent()).includes('默认支出'),'default callback missing');
 await p.locator('#spec-mode').selectOption('dark');assert(!await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth),'horizontal overflow');await sample.screenshot({path:path.join(root,'qa/asset-overview-'+width+'.png')});checks.push({width,privacy:true,chartModes:2,featureGate:true,rateEntryRetained:true,defaultCallback:true,overflow:false});
}
assert(!errors.length,errors.join('\n'));fs.writeFileSync(path.join(root,'qa/asset-overview-checks.json'),JSON.stringify({checks,errors},null,2));console.log(JSON.stringify({checks,errors}));
}finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
