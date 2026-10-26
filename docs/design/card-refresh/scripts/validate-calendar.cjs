const fs=require('fs'),path=require('path'),assert=require('assert'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..'),base=pathToFileURL(root+'/').href;
(async()=>{const browser=await chromium.launch({channel:'chrome'});try{const page=await browser.newPage({viewport:{width:900,height:1500}}),errors=[],profiles=[];page.on('pageerror',e=>errors.push(e.message));const phone=page.locator('#bee-immersive-phone');
for(const[size,scale,mode]of [['398x844','1','light'],['320x568','1.4','dark']]){
 for(const scene of ['calendar','flow-calendar-unselected','flow-calendar-empty','flow-calendar-loading','flow-calendar-error','flow-calendar-earliest','flow-calendar-latest']){
  await page.goto(base+'prototype/demo.html?page='+scene+'&viewport='+size);await page.waitForFunction(()=>window.beeImmersiveDemo);await page.evaluate(mode=>{window.beeImmersiveDemo.settings.appearance=mode;window.beeImmersiveDemo.render()},mode);await page.locator('#bee-preview-scale').selectOption(scale);
  const shell=phone.locator('.cl-shell');assert.equal(await shell.count(),1,scene);
  if(scene.endsWith('loading'))assert.equal(await shell.locator('[role=status]').count(),1);
  else if(scene.endsWith('error')){await shell.locator('[data-action=cl-retry]').click();assert.equal(await shell.locator('.cl-grid').count(),1);}
  else{
   assert.equal(await shell.locator('.cl-weekday').count(),7);
   assert.equal(await shell.locator('.cl-day').count()%7,0);
   if(scene.endsWith('unselected')||scene.endsWith('earliest')||scene.endsWith('latest'))assert.equal(await shell.locator('.cl-day-heading').count(),0);
   if(scene.endsWith('earliest'))assert.equal(await shell.locator('[data-action=cl-prev]').isDisabled(),true);
   if(scene.endsWith('latest'))assert.equal(await shell.locator('[data-action=cl-next]').isDisabled(),true);
   if(scene.endsWith('empty'))assert((await shell.innerText()).includes('当天无交易'));
   if(scene==='calendar'){
    const selected=shell.locator('.cl-day[aria-pressed=true]');assert.equal(await selected.locator('small').count(),2);assert.equal(await selected.locator('.cl-expense').innerText(),'-208');assert.equal(await selected.locator('.cl-income').innerText(),'+1.2w');
    assert((await selected.getAttribute('aria-label')).includes('支出208.40'),'transfer and excluded30 do not affect daily totals');
    assert.equal(await shell.locator('.cl-transaction').count(),4);assert((await shell.innerText()).includes('不计收支仍然显示'));assert((await shell.innerText()).includes('≈ ¥85.20'));
    if(size==='398x844'){
     const style=await page.addStyleTag({content:'#bee-immersive-phone{border:0!important}'}),f=JSON.parse(fs.readFileSync(path.resolve(root,'../../../test/fixtures/v4-calendar-geometry.json'),'utf8')),card=await shell.locator('.cl-month-card').boundingBox(),heading=await shell.locator('.cl-month-heading').boundingBox(),day=await selected.boundingBox();
     assert.equal(card.width,f.monthCardWidth);assert.equal(heading.height,f.monthHeadingHeight);assert.equal(day.height,f.dayVisualHeight);assert(Math.abs(day.width-(f.dayColumnWidth-2*f.dayHorizontalMargin))<.05);await style.evaluate(e=>e.remove());
    }
   }
  }
  assert.equal(await shell.evaluate(e=>e.scrollWidth>e.clientWidth),false,'horizontal overflow '+scene);
  profiles.push({size,scale,mode,scene});
 }
 await page.goto(base+'prototype/demo.html?page=calendar&viewport='+size);await page.waitForFunction(()=>window.beeImmersiveDemo);
 await phone.locator('[data-action=cl-next]').click();assert.equal(await phone.locator('.cl-day-heading').count(),0);assert((await phone.innerText()).includes('2026年11月'));
 await phone.locator('[data-action=cl-today]').click();assert.equal(await phone.locator('.cl-day[aria-pressed=true] span').innerText(),'20');
 await phone.locator('[data-action="cl-day:15"]').click();await phone.locator('[data-action=cl-add]').click();assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.fForm.recordDate),'2026-10-15');assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.fForm.recordTime),'12:00');
 await page.goto(base+'prototype/demo.html?page=calendar&viewport='+size);await page.waitForFunction(()=>window.beeImmersiveDemo);await phone.locator('[data-action=cl-month]').click();assert.equal(await phone.locator('[data-j-wheel]').count(),2);
 await phone.locator('[data-action="j-wheel:year:2000"]').click({force:true});await phone.locator('[data-action="j-wheel:month:1"]').click({force:true});await phone.locator('[data-action=cl-confirm-month]').click();assert((await phone.innerText()).includes('2000年1月'));assert.equal(await phone.locator('.cl-day-heading').count(),0);
}
assert.equal(errors.length,0);const result={status:'PASS',profiles,originalMonthWheelAndBounds:true,dualTotalsOriginalExclusionsAndNativeSnapshots:true,selectedDateNoonEditor:true,monthClearAndToday:true,frozenGeometry:true,errors};fs.writeFileSync(root+'/qa/calendar-checks.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));}finally{await browser.close()}})().catch(e=>{console.error(e);process.exit(1)});
