const fs=require('fs'),path=require('path'),os=require('os'),assert=require('assert'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..'),spec=require('../prototype/src/p2-support-module.cjs'),temporary=fs.mkdtempSync(path.join(os.tmpdir(),'beecount-p2-support-')),harness=path.join(temporary,'demo.html');
let html=fs.readFileSync(path.join(root,'prototype/demo.html'),'utf8');
html=html.includes('// PS102 SUPPORT START')?html.replace(/  \/\/ PS102 SUPPORT START[\s\S]*?  \/\/ PS102 SUPPORT END/,()=>spec.javascript):html.replace('  const views={categoryPicker:',()=>spec.javascript+'\n  const views={categoryPicker:');
html=html.replace('</head>','<style>'+spec.css+'</style></head>').replace('src="vendor/lucide.min.js"','src="'+pathToFileURL(path.join(root,'prototype/vendor/lucide.min.js')).href+'"').replace('src="scene-presets.js"','src="'+pathToFileURL(path.join(root,'prototype/scene-presets.js')).href+'"');fs.writeFileSync(harness,html);
(async()=>{const browser=await chromium.launch({channel:'chrome'}),errors=[];try{
 const page=await browser.newPage({viewport:{width:900,height:1500}});page.on('pageerror',e=>errors.push(e.message));
 await page.route('https://count.beejz.com/**',route=>route.fulfill({status:200,contentType:'text/html',body:'<!doctype html><html lang="zh"><meta charset="utf-8"><body><p>QA isolated document response</p></body></html>'}));
 const go=async(scene,q='')=>{await page.goto(pathToFileURL(harness).href+'?page='+scene+q);await page.waitForFunction(()=>window.beeImmersiveDemo);};let profiles=0;
 for(const [viewport,scale,appearance]of[['398x844','1','light'],['320x568','1.4','dark']])for(const scene of spec.scenes){
  await go(scene,'&viewport='+viewport+'&scale='+scale);await page.evaluate(a=>{window.beeImmersiveDemo.settings.appearance=a;window.beeImmersiveDemo.render()},appearance);
  for(const element of await page.locator('.ps102-stack,.ps102-card,.ps102-shortcut,.ps102-document').all())assert(!(await element.evaluate(n=>n.scrollWidth>n.clientWidth+1)),scene+' overflow');
  if(scene==='flow-support-about')assert.equal(await page.locator('[data-action="ps102-link:telegram"]').count(),0);
  if(scene.endsWith('-ios')&&scene.includes('about'))assert.equal(await page.locator('[data-action="ps102-update"]').count(),0);
  if(scene.includes('shortcuts'))assert.equal(await page.locator('.ps102-shortcut').count(),6);
  if(scene==='flow-support-privacy')assert((await page.locator('iframe').getAttribute('src')).startsWith('https://count.beejz.com/privacy?embed=1'));
  if(scene==='flow-support-donation-products')assert.equal(await page.locator('.ps102-product-option').count(),6);
  if(process.env.BEE_SUPPORT_EVIDENCE&&viewport==='320x568'&&['flow-support-about','flow-support-help-error','flow-support-donation-products','flow-support-shortcuts-ios'].includes(scene))await page.locator('.bc-phone').screenshot({path:path.join(process.env.BEE_SUPPORT_EVIDENCE,scene+'.png')});
  profiles++;
 }
 await go('flow-support-help-error');await page.locator('[data-action="ps102-doc-retry"]').click();assert.equal(await page.locator('iframe').count(),1);
 await go('about');await page.locator('[data-action="ps102-update"]').click();assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.page),'about');assert(await page.locator('[role="dialog"],.r-modal-layer').count());
 await page.locator('[data-action="ps102-mirrors"]').click();assert.equal(await page.locator('.ps102-modal [data-action^="ps102-mirror:"]').count(),6);await page.locator('[data-action="ps102-mirror:2"]').click();assert((await page.locator('.ps102-modal').innerText()).includes('mirror.ghproxy.com'));
 await page.locator('[data-action="ps102-download"]').click();assert(await page.locator('.ps102-modal').innerText().then(t=>t.includes('42%')));await page.locator('[data-action="ps102-update-cancel"]').click();assert.equal(await page.locator('.ps102-modal').count(),0);
 await go('flow-support-shortcuts-ios');await page.locator('[data-action="ps102-copy:5"]').click();
 await go('flow-support-donation-products');await page.locator('[data-action="ps102-donation:small"]').click();assert(await page.locator('.ps102-modal').innerText().then(t=>t.includes('QA')));
 await go('about');await page.locator('[data-action="ps102-product:assets"]').click();assert.equal(await page.locator('.ps102-product-shots img').count(),2);assert((await page.locator('.ps102-product-links a').last().getAttribute('href')).includes('com.tntlikely.beeassets'));
 await page.locator('[data-action="ps102-shot:1"]').click();assert.equal(await page.locator('.ps102-full-shot').count(),1);await page.locator('[data-action="ps102-back-product"]').click();assert.equal(await page.locator('.ps102-product-shots img').count(),2);
 await go('about');await page.locator('[data-action="ps102-doc:changelog"]').click();assert((await page.locator('iframe').getAttribute('src')).includes('/docs/changelog?embed=1'));
 assert.deepEqual(errors,[]);console.log(JSON.stringify({profiles,sourcePrivacyUrl:true,sixCopyLinks:true,storeProductsAreQA:true,updateStaysDialog:true,downloadCancelUI:true,errors}));
}finally{await browser.close();fs.rmSync(temporary,{recursive:true,force:true});}})().catch(error=>{console.error(error);fs.rmSync(temporary,{recursive:true,force:true});process.exit(1)});
