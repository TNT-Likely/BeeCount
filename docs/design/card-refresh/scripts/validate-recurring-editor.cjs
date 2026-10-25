const assert=require('assert'),fs=require('fs'),os=require('os'),path=require('path'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..'),spec=require('../prototype/src/recurring-editor-module.cjs'),temporary=fs.mkdtempSync(path.join(os.tmpdir(),'beecount-recurring-editor-ui-')),harness=path.join(temporary,'demo.html');
let html=fs.readFileSync(path.join(root,'prototype/demo.html'),'utf8');
if(html.includes('// RE90 RECURRING EDITOR START'))html=html.replace(/  \/\/ RE90 RECURRING EDITOR START[\s\S]*?  \/\/ RE90 RECURRING EDITOR END/,()=>spec.javascript);
else html=html.replace('  const views={categoryPicker:',()=>spec.javascript+'\n  const views={categoryPicker:');
html=html.replace('</head>','<style>'+spec.css+'</style></head>').replace('src="vendor/lucide.min.js"','src="'+pathToFileURL(path.join(root,'prototype/vendor/lucide.min.js')).href+'"').replace('src="scene-presets.js"','src="'+pathToFileURL(path.join(root,'prototype/scene-presets.js')).href+'"');
fs.writeFileSync(harness,html);
(async()=>{
 const browser=await chromium.launch({channel:'chrome'}),errors=[];
 try{
  const page=await browser.newPage({viewport:{width:900,height:1500}});page.on('pageerror',error=>errors.push(error.message));
  let profiles=0;
  for(const [viewport,scale,appearance] of [['398x844','1','light'],['320x568','1.4','dark']])for(const scene of spec.scenes){
   await page.goto(pathToFileURL(harness).href+'?page='+scene+'&viewport='+viewport+'&scale='+scale);await page.waitForFunction(()=>window.beeImmersiveDemo);
   await page.evaluate(appearance=>{window.beeImmersiveDemo.settings.appearance=appearance;window.beeImmersiveDemo.render()},appearance);
   for(const node of await page.locator('.re90-form,.re90-card,.re90-types,.re90-date-row').all())assert(!(await node.evaluate(element=>element.scrollWidth>element.clientWidth+1)),scene+' overflow');
   if(!scene.endsWith('loading')&&!scene.endsWith('load-error')){
    assert.equal(await page.locator('[data-re90-field="currency"] option').count(),spec.currencies.length);
    assert.equal(await page.locator('.re90-form input[type="checkbox"]').count(),0,'Original editor has no enabled switch');
    if(scene.endsWith('daily'))assert.equal(await page.locator('[data-re90-field="interval"]').count(),0);
    if(!['flow-recurring-edit-daily','flow-recurring-edit-weekly','flow-recurring-edit-yearly'].includes(scene))assert.equal(await page.locator('[data-re90-field="day"] option').count(),31);
    if(scene.endsWith('transfer')){assert.equal(await page.locator('[data-re90-field="category"]').count(),0);assert.equal(await page.locator('[data-action="re90-account:to"]').count(),1);}
    if(scene.endsWith('saving'))assert(await page.locator('.re90-save').isDisabled());
    if(scene.endsWith('-new'))assert(await page.locator('.re90-save').isDisabled());
   }
   profiles++;
  }
  const go=async scene=>{await page.goto(pathToFileURL(harness).href+'?page='+scene);await page.waitForSelector('.re90-form');};
  await go('flow-recurring-edit-transfer');
  await page.locator('[data-action="re90-account:to"]').click();
  assert.equal(await page.locator('[data-action="re90-account-set:2"]').count(),0,'To account excludes selected source');
  assert.equal(await page.locator('[data-action="re90-account-set:4"]').count(),0,'Hidden account is excluded');
  assert.equal(await page.locator('[data-action="re90-account-set:"]').count(),0,'To account has no optional null row');
  await page.locator('[data-action="re90-account-cancel"]').first().click();
  assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.re90Draft.to),'','Account cancel preserves original clearing behavior');
  await page.locator('[data-re90-field="currency"]').selectOption('CNY');
  assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.re90Draft.currency),null);assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.re90Draft.from),'');
  await page.locator('[data-action="re90-type:income"]').click();
  await page.locator('[data-re90-field="category"]').selectOption('QA 工资');
  await page.locator('[data-re90-field="frequency"]').selectOption('monthly');
  await page.locator('[data-re90-field="interval"]').selectOption('12');
  await page.locator('[data-re90-field="day"]').selectOption('31');
  await page.locator('[data-re90-field="frequency"]').selectOption('daily');
  assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.re90Draft.interval),1);
  assert.equal(await page.locator('[data-re90-field="interval"]').count(),0);
  await page.locator('[data-re90-field="end"]').fill('2050-01-01');await page.locator('[data-re90-field="end"]').dispatchEvent('change');
  await page.locator('[data-action="re90-clear-end"]').click();assert.equal(await page.locator('[data-re90-field="end"]').inputValue(),'');
  await page.locator('.re90-save').click();await page.waitForSelector('.re90-saved');
  assert((await page.locator('.re90-saved').innerText()).includes('不生成交易'));
  await go('flow-recurring-edit-error');await page.locator('.re90-save').click();await page.waitForSelector('.re90-saved');assert.equal(await page.locator('.re90-error').count(),0);
  await go('flow-recurring-edit');await page.locator('[data-action="re90-delete-open"]').click();assert.equal(await page.locator('[data-action="re90-delete"]').count(),1);
  await page.locator('[data-action="r-close"]').last().click();assert.equal(await page.locator('.re90-form').count(),1);
  await page.goto(pathToFileURL(harness).href+'?page=flow-recurring-edit-load-error');await page.locator('[data-action="re90-retry"]').click();assert.equal(await page.locator('.re90-form').count(),1);
  await page.locator('.re90-form').evaluate((node,sample)=>node.innerHTML=sample,spec.sample);await page.locator('[data-re90-demo]').click();assert((await page.locator('[data-re90-demo-result]').innerText()).includes('不写入真实周期配置'));
  assert.deepEqual(errors,[]);console.log(JSON.stringify({profiles,currencies:spec.currencies.length,frequencyBounds:true,currencyAccountLink:true,accountCancelClears:true,saveAndRetry:true,deleteCancel:true,guideCallback:true,errors}));
 }finally{await browser.close();fs.rmSync(temporary,{recursive:true,force:true});}
})().catch(error=>{console.error(error);fs.rmSync(temporary,{recursive:true,force:true});process.exit(1)});
