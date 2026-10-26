const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..');
const assert=(v,m)=>{if(!v)throw Error(m)};
(async()=>{const b=await chromium.launch({channel:'chrome',headless:true});try{
 const p=await b.newPage({viewport:{width:1000,height:1100}}),errors=[],geometry=[];p.on('pageerror',e=>errors.push(e.message));
 const base=pathToFileURL(path.join(root,'prototype/demo.html')).href;
 const catalog=JSON.parse(fs.readFileSync(path.join(root,'tokens/category-icon-catalog.json')));
 const frozen=JSON.parse(fs.readFileSync(path.resolve(root,'../../../test/fixtures/v4-category-icon-catalog.json')));
 const keys=new Set();for(const kind of ['expense','income']){assert(JSON.stringify(catalog[kind].map(g=>({label:g.label,keys:g.items.map(i=>i[0])})))===JSON.stringify(frozen[kind]),'original icon groups differ');catalog[kind].forEach(g=>g.items.forEach(([k])=>keys.add(k)))}assert(keys.size===237,'legacy keys');
 for(const viewport of ['398x844','320x568']){
  await p.goto(base+'?page=flow-category-edit&viewport='+viewport);await p.waitForFunction(()=>window.beeImmersiveDemo);
  assert(await p.locator('.j-editor-shell').count()===1,'editor missing');
  assert(await p.locator('[data-j-editor-level]').isDisabled(),'editing level changed');
  assert(await p.locator('[data-f-field="categoryName"]').getAttribute('maxlength')==='10','name limit');
  const box=await p.locator('.j-editor-grid').evaluate(el=>{const cell=el.querySelector('button'),r=cell.getBoundingClientRect(),style=getComputedStyle(el);return {width:el.getBoundingClientRect().width,cellWidth:r.width,cellHeight:r.height,columns:style.gridTemplateColumns.split(' ').length,gap:parseFloat(style.gap),radius:parseFloat(getComputedStyle(cell).borderRadius)}});
  geometry.push({viewport,...box});assert(box.cellWidth>=44&&box.cellHeight>=44,'touch target');
  assert(await p.locator('.j-editor-footer button').isVisible(),'save absent');
  const phone=await p.locator('#bee-immersive-phone').boundingBox(),save=await p.locator('.j-editor-footer button').boundingBox();assert(save.y+save.height<=phone.y+phone.height,'save outside phone');
  await p.locator('[data-action="j-editor-group:1"]').click();assert(await p.locator('.j-editor-grid button').count()===18,'full food icon group '+await p.locator('.j-editor-grid button').count()+' '+JSON.stringify(await p.evaluate(()=>({group:window.beeImmersiveDemo.state.jEditorGroup,type:window.beeImmersiveDemo.state.dCategoryType,page:window.beeImmersiveDemo.state.page}))));
  await p.locator('[data-action="j-editor-icon:ramen_dining"]').click();assert(await p.locator('[data-action="j-editor-icon:ramen_dining"]').getAttribute('aria-pressed')==='true','controlled choice');
  await p.locator('[data-action="j-icon-mode:custom"]').click();const preview=await p.locator('.j-editor-image .j-icon-preview').boundingBox();assert(preview.width===72&&preview.height===72,'custom preview');
  await p.screenshot({path:path.join(root,'qa/category-editor-'+viewport+'.png')});
 }
 await p.goto(base+'?page=flow-category-new');await p.waitForFunction(()=>window.beeImmersiveDemo);assert(!await p.locator('[data-j-editor-level]').isDisabled(),'new level locked');await p.locator('[data-j-editor-level]').check();assert(await p.locator('[data-action="j-editor-parent-open"]').count()===1,'parent picker missing');await p.locator('[data-action="j-editor-parent-open"]').click();assert(await p.locator('[data-action="j-editor-parent-select:购物"]').isDisabled(),'parent with direct records must be disabled');await p.locator('[data-j-parent-query]').fill('饮品');assert(await p.locator('[data-j-parent-name]:visible').count()===1,'parent search');await p.locator('[data-action="j-editor-parent-select:饮品"]').click();assert(await p.locator('.bc-sheet-layer').count()===0,'immediate parent choice must close');
 await p.goto(base+'?page=flow-transfer-icon');await p.waitForFunction(()=>window.beeImmersiveDemo);assert((await p.locator('.j-editor-type').textContent()).trim()==='转账','transfer type wrong');
 assert(!errors.length,errors.join('\n'));const result={status:'PASS',geometry,legacyIcons:keys.size,errors};fs.writeFileSync(path.join(root,'qa/category-editor-validation.json'),JSON.stringify(result,null,2));if(process.argv.includes('--freeze'))fs.writeFileSync(path.resolve(root,'../../../test/fixtures/v4-category-editor-geometry.json'),JSON.stringify({source:'Actual HTML category editor at 100% font, no skin',geometry},null,2)+'\n');console.log(JSON.stringify(result));
 }finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
