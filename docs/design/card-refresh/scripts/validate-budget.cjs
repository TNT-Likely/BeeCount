const fs=require('fs'),path=require('path'),assert=require('assert'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..'),base=pathToFileURL(root+'/').href;
(async()=>{const browser=await chromium.launch({channel:'chrome'});try{const page=await browser.newPage({viewport:{width:900,height:1500}}),errors=[],profiles=[];page.on('pageerror',e=>errors.push(e.message));const phone=page.locator('#bee-immersive-phone');
for(const[size,scale,mode]of [['398x844','1','light'],['320x568','1.4','dark']]){
 for(const scene of ['budget','budget-warning','budget-danger','budget-exceeded','budget-empty','budget-readonly','budget-empty-readonly','budget-loading','budget-error','budget-usd']){
  await page.goto(base+'prototype/demo.html?page=flow-'+scene+'&viewport='+size);await page.waitForFunction(()=>window.beeImmersiveDemo);await page.evaluate(mode=>{window.beeImmersiveDemo.settings.appearance=mode;window.beeImmersiveDemo.render()},mode);await page.locator('#bee-preview-scale').selectOption(scale);
  const shell=phone.locator('.bgt-shell');assert.equal(await shell.count(),1,scene);assert.equal(await phone.locator('.bc-month').count(),0,'budget follows ledger period; no fake month selection');
  if(scene==='budget-empty'||scene==='budget-empty-readonly'){assert.equal(await shell.locator('.bgt-total-card').count(),0);assert.equal(await shell.locator('[data-action=bgt-add]').count(),scene.endsWith('readonly')?0:2);}
  else if(scene==='budget-loading'){assert.equal(await shell.locator('[role=status]').count(),1);assert.equal(await shell.locator('.bgt-ring').count(),0);}
  else if(scene==='budget-error'){await shell.locator('[data-action=bgt-retry]').click();assert.equal(await shell.locator('.bgt-ring').count(),1);}
  else {
   assert.equal(await shell.locator('.bgt-ring').count(),1);assert.equal(await shell.locator('.bgt-category').count(),3);assert.equal(await shell.locator('.bgt-category-icon img').count(),1);
   if(scene==='budget-readonly'){assert.equal(await shell.locator('.bgt-edit').count(),0);assert.equal(await shell.locator('.bgt-category:disabled').count(),3);assert.equal(await shell.locator('[data-action=bgt-add]').count(),0);}
   if(scene==='budget-exceeded'){assert((await shell.locator('.bgt-remaining strong').innerText()).includes('-1250.00'));assert.equal(await shell.locator('.bgt-ring b').innerText(),'125%');assert.equal(await shell.locator('.bgt-remaining strong').evaluate(e=>getComputedStyle(e).color),mode==='dark'?'rgb(242, 184, 181)':'rgb(179, 38, 30)');}
   if(scene==='budget-usd'){assert.equal(await shell.locator('.bgt-remaining strong').innerText(),'$-15.20');assert.equal(await shell.locator('.bgt-bottom>div:first-child strong').innerText(),'$215.20');}
   const toggle=shell.locator('[data-action=bgt-home]');const initial=await toggle.getAttribute('aria-checked');await toggle.click();assert.notEqual(await toggle.getAttribute('aria-checked'),initial);await toggle.click();assert.equal(await toggle.getAttribute('aria-checked'),initial);
   if(size==='398x844'&&scene==='budget'){
    const style=await page.addStyleTag({content:'#bee-immersive-phone{border:0!important}'}),f=JSON.parse(fs.readFileSync(path.resolve(root,'../../../test/fixtures/v4-budget-geometry.json'),'utf8')),ring=await shell.locator('.bgt-ring').boundingBox(),surface=await shell.locator('.bgt-total-card').boundingBox(),row=await shell.locator('.bgt-category').first().boundingBox(),icon=await shell.locator('.bgt-category-icon').first().boundingBox();
    assert.equal(surface.width,f.overviewWidth);assert.equal(ring.width,f.ringSize);assert.equal(ring.height,f.ringSize);assert.equal(ring.y-surface.y,f.ringTopInset);assert.equal(row.height,f.categoryRowHeight);assert.equal(icon.width,f.categoryIconSize);await style.evaluate(e=>e.remove());
   }
  }
  assert.equal(await shell.evaluate(e=>e.scrollWidth>e.clientWidth),false,scene+' horizontal overflow');
  if(['budget','budget-exceeded','budget-readonly','budget-usd'].includes(scene))await phone.screenshot({path:root+'/qa/'+scene+'-'+size+'.png'});
  profiles.push({size,scale,mode,scene});
 }
 await page.goto(base+'prototype/demo.html?page=flow-budget&viewport='+size);await page.waitForFunction(()=>window.beeImmersiveDemo);await phone.locator('[data-action=bgt-total]').click();assert((await phone.innerText()).includes('预算金额'),'original edit entry');
}
assert.equal(errors.length,0);const result={status:'PASS',profiles,originalPeriodNoFakeSelector:true,ledgerCurrencyAndNegativeRemaining:true,customIconAndReadonlyRole:true,homeToggleControlled:true,geometryFrozen128Ring80Row:true,errors};fs.writeFileSync(root+'/qa/budget-checks.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));}finally{await browser.close()}})().catch(e=>{console.error(e);process.exit(1)});
