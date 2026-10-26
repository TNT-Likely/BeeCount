const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..');
function assert(v,m){if(!v)throw Error(m)}
(async()=>{const b=await chromium.launch({channel:'chrome',headless:true});try{
const p=await b.newPage({viewport:{width:736,height:1800}}),errors=[],checks=[];p.on('pageerror',e=>errors.push(e.message));
const phone=p.locator('#bee-immersive-phone'),show=async(route,size='398x844')=>{await p.goto(pathToFileURL(path.join(root,'prototype/demo.html')).href+'?viewport='+size+'&page='+route);await p.waitForFunction(()=>window.beeImmersiveDemo);},click=a=>phone.locator('[data-action="'+a+'"]').first().click();
for(const size of ['398x844','320x568']){
 await show('flow-category-management',size);
 assert(await phone.locator('.d-manage-children :is(svg,img)').count()===5,'child icons missing');
 const fixed=await phone.locator('.bc-subhead').boundingBox();await phone.locator('.cm-manager-scroll').evaluate(e=>e.scrollTop=e.scrollHeight);assert(Math.abs((await phone.locator('.bc-subhead').boundingBox()).y-fixed.y)<1,'header scrolled');
 await click('f-go:category-tools');assert(await phone.locator('.bc-sheet').count()===1,'tools must be a dialog');
 for(const action of ['cm-share','cm-new-category','cm-import','cm-default','cm-clear'])assert(await phone.locator('.bc-sheet [data-action="'+action+'"]').count()===1,'missing original tool '+action);
 await click('cm-share');assert(await phone.locator('[data-action^="cm-share-choice:"]').count()===2,'share scopes lost');await click('r-close');
 await click('f-go:category-tools');await click('cm-default');assert(await phone.locator('[data-cm-mode]').count()===2,'default category modes lost');await phone.locator('[data-cm-mode="true"]').check();await click('r-close');
 await click('f-go:category-tools');await click('cm-clear');assert((await phone.locator('.bc-sheet').textContent()).includes('有账单的父子分类会保留'),'clear protection lost');await click('r-close');
 await phone.locator('[data-cm-import]').setInputFiles({name:'synthetic-category.zip',mimeType:'application/zip',buffer:Buffer.from('HTML selector draft; real ZIP parsing is in App')});
 assert(await phone.locator('[data-action^="cm-import-choice:"]').count()===2,'merge/overwrite missing');await click('r-close');
 await show('flow-category-children',size);assert(await phone.locator('.cm-child-grid img').count()===1,'custom child image lost');
 assert((await phone.locator('.cm-child-grid').textContent()).includes('奶茶'),'child title lost');
 await phone.screenshot({path:path.join(root,'qa/category-children-'+size+'.png')});
 await click('cm-new-child');assert(await phone.locator('.j-editor-shell').count()===1,'new child route missing');
 assert(await p.evaluate(()=>window.beeImmersiveDemo.state.fForm.categoryParent)==='饮品','new child parent missing');
 await show('flow-category-management',size);await click('d-manage-type:income');await click('cm-new-category');assert(await p.evaluate(()=>window.beeImmersiveDemo.state.dCategoryType)==='income','new income kind lost');
 await show('flow-category-empty',size);assert(await phone.getByText('暂无分类',{exact:true}).count()===1,'empty missing');assert(await phone.getByText('转账图标设置',{exact:true}).count()===1,'empty hides transfer');assert(await phone.getByText('分类工具',{exact:true}).count()===1,'empty hides tools');
 assert(!await phone.evaluate(e=>e.scrollWidth>e.clientWidth),'phone overflow');checks.push({size,tools:5,shareScopes:2,defaultModes:2,importModes:2,childCustomImage:true,incomeType:true,emptyRetainsTransfer:true,fixedHeader:true});
}
await p.goto(pathToFileURL(path.join(root,'components/ui-components.html')).href);await p.waitForFunction(()=>window.beeComponentCatalog);const guide=p.locator('#spec-50');assert(await guide.locator('.g-management-grid img').count()===1,'guide custom image missing');await guide.locator('[data-management-expand]').click();assert(await guide.locator('.g-management-children').isHidden(),'guide collapse failed');await guide.locator('[data-management-expand]').click();await guide.locator('[data-management-edit="奶茶"]').first().click();assert((await guide.locator('[data-management-result]').textContent()).includes('奶茶'),'guide event missing');
assert(!errors.length,errors.join('\n'));fs.writeFileSync(path.join(root,'qa/category-management-checks.json'),JSON.stringify({checks,guide:true,errors},null,2));console.log(JSON.stringify({checks,guide:true,errors}));
}finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
