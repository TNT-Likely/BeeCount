const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url'),{chromium}=require('playwright'),root=path.resolve(__dirname,'..');
const assert=(v,m)=>{if(!v)throw Error(m)};
(async()=>{const b=await chromium.launch({channel:'chrome',headless:true}),p=await b.newPage({viewport:{width:736,height:1800}}),checks=[],errors=[];p.on('pageerror',e=>errors.push(e.message));try{
for(const [size,scale,mode] of [['398x844',1,'light'],['320x568',1.4,'dark']]){
 await p.goto(pathToFileURL(path.join(root,'prototype/demo.html')).href+'?page=welcome&viewport='+size+'&scale='+scale);await p.waitForFunction(()=>window.beeImmersiveDemo);await p.locator('#bee-skin-mode').selectOption(mode);const phone=p.locator('#bee-immersive-phone'),pick=p.locator('#bee-immersive-pages');
 for(const route of ['welcome','welcomeCurrency','welcomeCategories','welcomeCloud','welcomePrivacy']){
  await pick.selectOption(route);const outer=await phone.boundingBox(),button=await phone.locator('.o-footer .bc-primary').boundingBox();assert(button&&button.y+button.height<=outer.y+outer.height,'main action below viewport '+route);assert(!await phone.evaluate(el=>el.scrollWidth>el.clientWidth),'horizontal overflow '+route);
  if(route==='welcome')assert(await phone.locator('[data-action^="w-language:"]').count()===5,'language choice missing');
  if(route==='welcomeCategories')assert(await phone.locator('.o-mode-features').count()===3,'original category explanations missing');
 }
 await pick.selectOption('welcomeCurrency');await phone.locator('[data-action="w-more-currencies"]').click();assert(await phone.locator('[data-action^="ow-currency:"]').count()===151,'full currency inventory');await phone.locator('[data-ow-currency-query]').fill('THB');assert(await phone.locator('[data-action="ow-currency:THB"]').count()===1,'Thai search');await phone.locator('[data-action="ow-currency:THB"]').click();assert(await p.evaluate(()=>window.beeImmersiveDemo.state.wCurrency)==='THB','selected currency not kept');
 await pick.selectOption('welcomeAttachments');assert((await phone.textContent()).includes('TAR.GZ'),'backup format must match production archive');assert(!await phone.evaluate(el=>el.scrollWidth>el.clientWidth),'restore overflow');
 checks.push({size,scale,mode,fiveSteps:true,languages:5,currencies:151,searchAndSelect:true,fixedMainAction:true,originalModeCopy:true,actualArchiveFormat:'TAR.GZ'});
}
assert(!errors.length,errors.join('\n'));fs.writeFileSync(path.join(root,'qa/onboarding-checks.json'),JSON.stringify({checks,errors},null,2));console.log(JSON.stringify({checks,errors}));
}finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
