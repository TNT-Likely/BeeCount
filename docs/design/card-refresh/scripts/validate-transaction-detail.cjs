const assert=require('assert'),fs=require('fs'),os=require('os'),path=require('path'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..'),spec=require('../prototype/src/transaction-detail-module.cjs'),temporary=fs.mkdtempSync(path.join(os.tmpdir(),'beecount-transaction-detail-ui-')),harness=path.join(temporary,'demo.html');
let html=fs.readFileSync(path.join(root,'prototype/demo.html'),'utf8');
if(html.includes('// TD94 TRANSACTION DETAIL START'))html=html.replace(/  \/\/ TD94 TRANSACTION DETAIL START[\s\S]*?  \/\/ TD94 TRANSACTION DETAIL END/,()=>spec.javascript);
else html=html.replace('  const views={categoryPicker:',()=>spec.javascript+'\n  const views={categoryPicker:');
html=html.replace('</head>','<style>'+spec.css+'</style></head>').replace('src="vendor/lucide.min.js"','src="'+pathToFileURL(path.join(root,'prototype/vendor/lucide.min.js')).href+'"').replace('src="scene-presets.js"','src="'+pathToFileURL(path.join(root,'prototype/scene-presets.js')).href+'"');fs.writeFileSync(harness,html);
(async()=>{
 const browser=await chromium.launch({channel:'chrome'}),errors=[];
 try{
  const page=await browser.newPage({viewport:{width:900,height:1500}});page.on('pageerror',error=>errors.push(error.message));
  let profiles=0;
  const go=async(scene,query='')=>{await page.goto(pathToFileURL(harness).href+'?page='+scene+query);await page.waitForFunction(()=>window.beeImmersiveDemo);};
  for(const [viewport,scale,appearance] of [['398x844','1','light'],['320x568','1.4','dark']])for(const scene of spec.scenes){
   await go(scene,'&viewport='+viewport+'&scale='+scale);
   await page.evaluate(appearance=>{window.beeImmersiveDemo.settings.appearance=appearance;window.beeImmersiveDemo.render()},appearance);
   for(const node of await page.locator('.td94-stack,.td94-card,.td94-line,.td94-actions').all())assert(!(await node.evaluate(element=>element.scrollWidth>element.clientWidth+1)),scene+' overflow');
   if(scene.endsWith('-transfer'))assert(!(await page.locator('[data-td94-amount]').innerText()).startsWith('−'));
   if(scene.endsWith('-private')){assert.equal(await page.locator('[data-td94-amount]').innerText(),'••••');assert.equal(await page.locator('[data-td94-snapshot]').innerText(),'••••');assert(!(await page.locator('[data-td94-rate]').innerText()).includes('7.15000'));}
   if(scene.endsWith('-unconverted')){assert.equal(await page.locator('[data-td94-snapshot]').innerText(),'未折算');assert.equal(await page.locator('[data-td94-rate]').count(),0);}
   if(scene.endsWith('-attachments')||scene.endsWith('-missing-image'))assert.equal(await page.locator('.td94-image').count(),3);
   if(scene.endsWith('-readonly'))assert.equal(await page.locator('.td94-actions button:disabled').count(),2);
   assert.equal(await page.locator('.td94-stack input').count(),0,'Detail does not introduce financial edit controls');
   profiles++;
  }
  await go('detail');await page.evaluate(()=>{const demo=window.beeImmersiveDemo;demo.state.additions.push({id:901,ledger:demo.state.ledger,year:demo.state.year,month:demo.state.month,day:25,time:'12:30:00',type:'expense',amount:-12,nativeAmount:-85.8,currency:'USD',category:'咖啡',title:'QA refund',account:'美元账户'});demo.state.detailId=901;demo.render()});assert.equal(await page.locator('[data-td94-amount]').innerText(),'+12.00');
  await go('flow-transaction-detail-foreign');const snapshot=await page.locator('.td94-snapshot').innerText();
  await page.evaluate(()=>{window.beeImmersiveDemo.state.fRecordRate='99';window.beeImmersiveDemo.state.xrmAuto={'CNY:USD':'99'};window.beeImmersiveDemo.render()});
  assert.equal(await page.locator('.td94-snapshot').innerText(),snapshot,'Historical snapshot must not follow current quotes');
  await go('flow-transaction-detail-private');await page.locator('[data-action="td94-privacy"]').click();assert.equal(await page.locator('[data-td94-amount]').innerText(),'−12.00');
  await go('flow-transaction-detail-error');await page.locator('[data-action="td94-retry"]').click();assert.equal(await page.locator('.td94-stack').count(),1);
  await go('flow-transaction-detail-missing-image');await page.waitForSelector('.td94-image-error:not([hidden])');
  await go('flow-transaction-detail-attachments');await page.locator('[data-action="td94-attachment:2"]').click();
  assert((await page.locator('.u-viewer-title').innerText()).includes('3 / 3'),'Existing full viewer preserves the index');
  await page.locator('.u-viewer-toolbar [data-action="close"]').click();
  await go('home');await page.locator('.tx-row .primary').first().click();assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.page),'editor','Q01=B ordinary list click edits');
  await go('home');await page.locator('.tx-row .category-target').first().click();assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.page),'categoryDetail');
  await go('home');await page.locator('.tx-row .primary').first().click({button:'right'});
  for(const action of ['edit-record','copy-record','x-select:','x-receipt:','x-delete:'])assert(await page.locator('.r-modal-layer [data-action^="'+action+'"]').count()||await page.locator('[role="dialog"] [data-action^="'+action+'"]').count()||await page.locator('[role="menu"] [data-action^="'+action+'"]').count(),'Original context action missing: '+action);
  await page.locator('[data-action^="td94-open:"]').click();assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.page),'detail');assert.equal(await page.locator('.td94-stack').count(),1);
  assert.equal(await page.locator('.v-entry [data-action^="td94-open:"]').count(),0,'No new right-side detail dot');
  await page.locator('[data-action="td94-edit"]').click();assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.page),'editor');assert(await page.evaluate(()=>window.beeImmersiveDemo.state.vEditId!==null));
  await go('detail');await page.locator('[data-action="td94-copy"]').click();assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.page),'editor');assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.vEditId),null);
  await go('detail');await page.locator('[data-action="td94-receipt"]').click();assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.page),'receipt');
  await go('detail');await page.locator('.td94-stack').evaluate((node,sample)=>node.innerHTML=sample,spec.sample);await page.locator('[data-td94-demo]').first().click();assert((await page.locator('[data-td94-demo-result]').innerText()).includes('不编辑真实账单'));
  assert.deepEqual(errors,[]);console.log(JSON.stringify({profiles,historicalSnapshot:true,privacy:true,missingImage:true,existingViewerIndex:true,ordinaryTapEdits:true,categoryIconNavigates:true,contextActionsRetained:true,detailCopyEditReceipt:true,guideCallback:true,errors}));
 }finally{await browser.close();fs.rmSync(temporary,{recursive:true,force:true});}
})().catch(error=>{console.error(error);fs.rmSync(temporary,{recursive:true,force:true});process.exit(1)});
