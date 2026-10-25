const assert=require('assert'),path=require('path'),fs=require('fs'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..'),base=pathToFileURL(root+'/prototype/demo.html').href,t=JSON.parse(fs.readFileSync(path.resolve(root,'../../../lib/l10n/app_zh.arb')));
(async()=>{const b=await chromium.launch({channel:'chrome'});try{const p=await b.newPage({viewport:{width:900,height:1500}}),errors=[],profiles=[];p.on('pageerror',e=>errors.push(e.message));
for(const[size,scale,mode]of [['398x844','1','light'],['320x568','1.4','dark']]){
 for(const scene of ['smart','flow-smart-direct','flow-smart-gp','flow-smart-ios','flow-feature-guide','flow-voice-trigger','flow-smart-guide-image','flow-smart-guide-camera','flow-smart-guide-voice','flow-smart-guide-share']){
  await p.goto(base+'?page='+scene+'&viewport='+size);await p.waitForFunction(()=>window.beeImmersiveDemo);await p.evaluate(mode=>{window.beeImmersiveDemo.settings.appearance=mode;window.beeImmersiveDemo.render()},mode);await p.locator('#bee-preview-scale').selectOption(scale);
  const phone=p.locator('#bee-immersive-phone'),shell=phone.locator('.s80-shell');assert.equal(await shell.count(),1,scene);assert.equal(await phone.locator('[data-f-field=nPlatform]').count(),0,'platform selector must not be production UI');
  if(scene.includes('guide')||scene==='flow-voice-trigger'){
   assert.equal(await phone.locator('[role=dialog]').count(),1,scene+' keeps dialog path');
   if(scene.includes('guide'))assert.equal(await phone.locator('.s80-guide').count(),1);
  }else{
   const share=shell.locator('[data-action^="n-guide:"]').filter({hasText:t.shareBilling});assert.equal(await share.count(),scene.endsWith('ios')?0:1,scene+' share policy');
   assert.equal(await shell.locator('[data-action="f-go:auto-billing"]').count(),scene.endsWith('gp')?0:1,scene+' screenshot policy');
   const range=shell.locator('[data-n-silence]');assert.equal(await range.getAttribute('min'),'500');assert.equal(await range.getAttribute('max'),'4000');assert.equal(await range.getAttribute('step'),'100');
  }
  const overflow=await shell.evaluate(e=>e.scrollWidth>e.clientWidth+1);assert(!overflow,scene+' horizontal overflow');profiles.push({scene,size,scale,mode});
 }
}
await p.goto(base+'?page=smart&viewport=398x844');const shell=p.locator('.s80-shell');await shell.locator('[data-action^="n-guide:"]').first().click();assert.equal(await p.locator('.s80-copy').innerText(),t.smartBillingImageBillingGuide);await p.getByRole('button',{name:t.commonKnow,exact:true}).click();
await shell.locator('[data-action="r-open:voice-trigger"]').click();await p.locator('[data-action="n-voice:hold"]').click();assert.equal(await shell.locator('[data-n-silence]').count(),0);await shell.locator('[data-action="r-open:voice-trigger"]').click();await p.locator('[data-action="n-voice:auto"]').click();
await shell.locator('[data-n-silence]').focus();await shell.locator('[data-n-silence]').press('End');assert.equal(await shell.locator('[data-n-silence]').inputValue(),'4000');await shell.locator('[data-action="r-open:voice-trigger"]').click();await p.getByRole('button',{name:t.commonCancel,exact:true}).click();assert.equal(await shell.locator('[data-n-silence]').inputValue(),'4000');
assert.deepEqual(errors,[]);await p.locator('#bee-immersive-phone').screenshot({path:'/tmp/beecount-v4-smart-r80-final-html.png'});console.log(JSON.stringify({profiles:profiles.length,originalGuide:true,voiceChoiceAndCancel:true,rangeEndPersisted:true,errors}));
}finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
