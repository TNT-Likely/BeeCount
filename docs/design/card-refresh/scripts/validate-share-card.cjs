const assert=require('assert'),fs=require('fs'),os=require('os'),path=require('path'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..'),spec=require('../prototype/src/share-card-module.cjs'),temporary=fs.mkdtempSync(path.join(os.tmpdir(),'beecount-share-card-ui-')),harness=path.join(temporary,'demo.html');
let html=fs.readFileSync(path.join(root,'prototype/demo.html'),'utf8');
if(html.includes('// SC100 SHARE CARD START'))html=html.replace(/  \/\/ SC100 SHARE CARD START[\s\S]*?  \/\/ SC100 SHARE CARD END/,()=>spec.javascript);
else html=html.replace('  const views={categoryPicker:',()=>spec.javascript+'\n  const views={categoryPicker:');
html=html.replace('</head>','<style>'+spec.css+'</style></head>').replace('src="vendor/lucide.min.js"','src="'+pathToFileURL(path.join(root,'prototype/vendor/lucide.min.js')).href+'"').replace('src="scene-presets.js"','src="'+pathToFileURL(path.join(root,'prototype/scene-presets.js')).href+'"');fs.writeFileSync(harness,html);
(async()=>{
 const browser=await chromium.launch({channel:'chrome'}),errors=[];
 try{
  const page=await browser.newPage({viewport:{width:900,height:1500},acceptDownloads:true});page.on('pageerror',e=>errors.push(e.message));
  const go=async(scene,query='')=>{await page.goto(pathToFileURL(harness).href+'?page='+scene+query);await page.waitForFunction(()=>window.beeImmersiveDemo);};let profiles=0;
  for(const [viewport,scale,appearance] of [['398x844','1','light'],['320x568','1.4','dark']])for(const scene of spec.scenes){
   await go(scene,'&viewport='+viewport+'&scale='+scale);await page.evaluate(appearance=>{window.beeImmersiveDemo.settings.appearance=appearance;window.beeImmersiveDemo.render()},appearance);
   for(const node of await page.locator('.sc100-body,.d104-root .poster,.sc100-templates,.sc100-actions').all())assert(!(await node.evaluate(el=>el.scrollWidth>el.clientWidth+1)),scene+' overflow');
   if(scene==='flow-share-card')assert.equal(await page.locator('.sc100-templates button').count(),2);
   if(scene.endsWith('-private')){assert.equal(await page.locator('.d104-root .paired b').nth(0).innerText(),'**');assert.equal(await page.locator('.d104-root .paired b').nth(1).innerText(),'**');}
   if(scene.endsWith('-loading'))assert.equal(await page.locator('.sc100-actions button:disabled').count(),2);
   assert.equal(await page.locator('.x-poster-styles').count(),0);
   if(process.env.BEE_SHARE_CARD_HTML_EVIDENCE&&['flow-share-card','flow-share-card-private'].includes(scene))await page.locator('.sc100-body').screenshot({path:path.join(process.env.BEE_SHARE_CARD_HTML_EVIDENCE,scene+'-'+appearance+'.png')});
   profiles++;
  }
  await go('flow-share-card');
  assert.deepEqual(await page.evaluate(()=>window.sc100PeriodDivisors(2026,10,10,new Date(2026,10,5))),{days:27,months:10});
  assert.deepEqual(await page.evaluate(()=>window.sc100PeriodDivisors(2025,2,1,new Date(2026,9,25))),{days:28,months:12});
  assert.deepEqual(await page.evaluate(()=>window.sc100PeriodDivisors(2027,2,1,new Date(2026,9,25))),{days:0,months:0});
  await go('flow-share-card');await page.locator('[data-action="sc100-kind:app"]').click();assert.equal(await page.locator('[data-sc100-kind]').getAttribute('data-sc100-kind'),'app');
  await go('flow-share-card-error');await page.locator('[data-action="sc100-retry"]').click();assert.equal(await page.locator('[data-sc100-kind]').count(),1);
  await go('flow-share-card-private');await page.locator('[data-action="sc100-privacy"]').click();assert.notEqual(await page.locator('.d104-root .paired b').nth(0).innerText(),'**');
  const download=page.waitForEvent('download');await page.locator('[data-action="sc100-save"]').click();const file=await download;const bytes=fs.readFileSync(await file.path());assert.equal(bytes.readUInt32BE(0),0x89504e47);assert.equal(bytes.readUInt32BE(16),750);assert.equal(bytes.readUInt32BE(20),1334);
  await go('mine');await page.evaluate(()=>{const el=document.createElement('button');el.dataset.action='leaf:分享海报';el.id='qa-open-share';document.querySelector('#bee-immersive-suite').appendChild(el)});await page.locator('#qa-open-share').click();assert.equal(await page.locator('.sc100-body').count(),1);assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.page),'mine');
  assert.deepEqual(errors,[]);console.log(JSON.stringify({profiles,defaultProfileAppOnly:true,privacy:true,retry:true,png:[750,1334],productionPopup:true,errors}));
 }finally{await browser.close();fs.rmSync(temporary,{recursive:true,force:true});}
})().catch(error=>{console.error(error);fs.rmSync(temporary,{recursive:true,force:true});process.exit(1)});
