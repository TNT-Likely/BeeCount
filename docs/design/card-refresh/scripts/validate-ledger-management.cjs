const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url'),{chromium}=require('playwright'),root=path.resolve(__dirname,'..');
const assert=(v,m)=>{if(!v)throw Error(m)};
(async()=>{const b=await chromium.launch({channel:'chrome',headless:true}),p=await b.newPage({viewport:{width:736,height:1600}}),errors=[],checks=[];p.on('pageerror',e=>errors.push(e.message));try{
for(const [size,scale,mode] of [['398x844',1,'light'],['320x568',1.4,'dark']]){
 await p.goto(pathToFileURL(path.join(root,'prototype/demo.html')).href+'?page=ledgers&viewport='+size+'&scale='+scale);await p.waitForFunction(()=>window.beeImmersiveDemo);await p.locator('#bee-skin-mode').selectOption(mode);
 p.setDefaultTimeout(7000);
 const phone=p.locator('#bee-immersive-phone'),click=a=>phone.locator(`[data-action="${a}"]`).first().click();
 assert(!await phone.getByText('加入共享账本',{exact:true}).count(),'local mode must hide shared join');
 assert(await phone.locator('[data-current="true"]').count()===1,'current state');
 await click('j-ledger-select:家庭账本');assert(await phone.locator('[data-j-ledger="家庭账本"][data-current=true]').count()===1,'switch');
 await click('j-ledger-menu:日常生活');assert((await phone.textContent()).includes('ID: 1'),'original identity missing');
 assert(!await phone.getByText('成员统计',{exact:true}).count(),'local cloud gate');await click('j-ledger-action:edit');
 await click('l-period');assert(await phone.locator('.l-day-grid button').count()===28,'day range');
 for(const box of await phone.locator('.l-day-grid button').evaluateAll(es=>es.map(e=>({w:e.getBoundingClientRect().width,h:e.getBoundingClientRect().height}))))assert(Math.min(box.w,box.h)>=43.99,'small day target');
 await click('l-day:28');await click('l-currency');assert(await phone.locator('[data-action^="l-currency-select:"]').count()===151,'all currencies');
 await phone.locator('[data-l-currency-query]').fill('USD');await click('l-currency-select:USD');await click('l-edit-save');
 assert((await phone.textContent()).includes('重算全部历史交易'),'currency reconversion confirmation');await click('r-close');await click('r-close');
 assert(await p.evaluate(()=>window.beeImmersiveDemo.state.lBooks[0].currency)==='CNY','cancel wrote book');
 await click('l-new');assert(await phone.locator('[data-action="l-edit-save"]').isDisabled(),'empty name guard');await phone.locator('[data-l-ledger-name]').fill('美元旅行');
 await click('l-currency');await phone.locator('[data-l-currency-query]').fill('USD');await click('l-currency-select:USD');
 await click('l-period');await click('l-day:28');await click('l-edit-save');
 assert(await p.evaluate(()=>window.beeImmersiveDemo.state.lBooks.some(b=>b.name==='美元旅行'&&b.currency==='USD'&&b.day===28)),'new draft save');
 for(const route of ['flow-ledgers-empty','flow-ledgers-loading','flow-ledgers-error','flow-ledgers-remote','flow-ledgers-editor','flow-ledger-conflict']){
  await p.locator('#bee-immersive-pages').selectOption(route);assert(!await phone.evaluate(el=>el.scrollWidth>el.clientWidth),'horizontal overflow '+route);
  if(route==='flow-ledgers-empty')assert(!await phone.locator('[data-j-ledger]').count(),'empty');
  if(route==='flow-ledgers-error')assert((await phone.textContent()).includes('本地数据仍保留'),'error and local');
  if(route==='flow-ledgers-remote'){await click('l-remote-menu');assert((await phone.textContent()).includes('删除云端账本'),'remote actions');await click('close');}
  if(route==='flow-ledgers-editor'){await click('j-ledger-menu:家庭账本');assert(!await phone.getByText('编辑账本',{exact:true}).count(),'editor must not edit');assert(await phone.getByText('仅删除本地账本',{exact:true}).count(),'editor local removal');await click('close');}
 }
 checks.push({size,scale,mode,originalMetadata:true,modalEditor:true,days:28,currencies:151,cancelNoWrites:true,newUSDDay28:true,editorPermissions:true,remoteStates:true,noOverflow:true});
}
assert(!errors.length,errors.join('\n'));fs.writeFileSync(path.join(root,'qa/ledger-management-checks.json'),JSON.stringify({checks,errors},null,2));console.log(JSON.stringify({checks,errors}));
}finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
