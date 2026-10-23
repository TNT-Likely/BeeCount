const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..');
function assert(ok,message){if(!ok)throw Error(message);}
(async()=>{const browser=await chromium.launch({channel:'chrome',headless:true});try{
 const page=await browser.newPage({viewport:{width:1000,height:1100}}),errors=[],geometry=[];
 page.on('pageerror',e=>errors.push(e.message));
 const url=pathToFileURL(path.join(root,'prototype/demo.html')).href;
 const key=v=>page.locator(`[data-action="s-pin:${v}"]`);
 async function digits(value){for(const v of value)await key(v).click();}
 for(const size of ['398x844','320x568']){
  await page.goto(url+'?page=flow-pin&viewport='+size);await page.waitForFunction(()=>window.beeImmersiveDemo);
  assert(await page.locator('.f-pin-dots span').count()===4,'four-digit PIN');
  assert(await page.locator('[data-action="s-pin:bio"]').count()===0,'setup must not show biometric shortcut');
  geometry.push(await key('1').evaluate((el,size)=>({viewport:size,width:el.getBoundingClientRect().width,height:el.getBoundingClientRect().height,radius:parseFloat(getComputedStyle(el).borderRadius),font:parseFloat(getComputedStyle(el).fontSize),gridGap:parseFloat(getComputedStyle(el.parentElement).gap)}),size));
  await digits('1234');assert((await page.locator('.s-security h2').textContent())==='请再次输入密码','new PIN confirmation');
  await digits('9999');assert(await page.locator('.s-security').getAttribute('data-invalid')==='true','mismatch state');
  await page.waitForFunction(()=>window.beeImmersiveDemo.state.sPinError===false);
  assert((await page.locator('.s-security h2').textContent())==='请设置新密码','mismatch resets to new entry');
  await page.evaluate(()=>window.beeResponsivePreview.set({scale:1.4}));
  await digits('1234');await digits('1234');assert((await page.locator('#bee-immersive-phone').textContent()).includes('密码设置成功'),'saved result');
 }
 await page.goto(url+'?page=flow-pin-change');await page.waitForFunction(()=>window.beeImmersiveDemo);
 assert((await page.locator('.s-security h2').textContent())==='请输入当前密码','change first verifies original');
 await digits('9999');await page.waitForFunction(()=>window.beeImmersiveDemo.state.sPinError===false);assert((await page.locator('.s-security h2').textContent())==='请输入当前密码','wrong original stays in verification');
 await digits('1234');assert((await page.locator('.s-security h2').textContent())==='请设置新密码','correct original advances');
 for(const route of ['flow-lock','flow-lock-bio']){await page.goto(url+'?page='+route);await page.waitForFunction(()=>window.beeImmersiveDemo);assert(await page.locator('.bc-subhead [data-action="back"]').count()===0,'locked screen has no back action');assert(await key('bio').count()===(route.endsWith('bio')?1:0),'biometric availability');}
 assert(!errors.length,errors.join('\n'));
 fs.writeFileSync(path.join(root,'qa/security-checks.json'),JSON.stringify({status:'PASS',geometry,errors},null,2));
 if(process.argv.includes('--freeze'))fs.writeFileSync(path.resolve(root,'../../../test/fixtures/v4-security-geometry.json'),JSON.stringify({source:'docs/design/card-refresh/prototype/demo.html?page=flow-pin',measuredWith:'Chromium computed styles, default skin, 2026-10-24',geometry},null,2)+'\n');
 console.log(JSON.stringify({status:'PASS',geometry,errors}));
 }finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1});
