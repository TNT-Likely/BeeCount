const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {pathToFileURL}=require('node:url'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..'),repo=path.resolve(root,'../../..');
const evidence=process.env.BEE_CATEGORY_ROW_EVIDENCE||path.join(repo,'.docs/v4-ui-migration/category-picker-row-html');
fs.mkdirSync(evidence,{recursive:true});
const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'beecount-category-row-')),harness=path.join(temporary,'demo.html');
const current=fs.readFileSync(path.join(root,'prototype/src/selectors.js'),'utf8');
let html=fs.readFileSync(path.join(root,'prototype/demo.html'),'utf8');
function section(code){const start=code.indexOf('  function sCategoryBody(){'),end=code.indexOf("  root.addEventListener('input',e=>{if(!e.target.matches('[data-s-category-query]')",start);assert(start>=0&&end>start);return {start,end,body:code.slice(start,end)};}
const old=section(html),fixed=section(current).body;
const testApi=`
  window.__categoryPickerRowQa={
    original(value){state.__categoryRowOriginal=value;rBuildModal();},
    append(){for(let i=0;i<32;i++)sCategoryGroups.push({id:'qa'+i,name:'QA父类'+i,icon:'shapes',enabled:false,count:i,children:[{id:'qc'+i,name:'QA子类'+i,icon:'shapes',enabled:true,count:i+1}]});state.sCategoryParent='traffic';state.sCategoryQuery='';rBuildModal();},
    open(){state.sCategoryQuery='';rOpenModal('category-select');}
  };
`;
const replacement=old.body.replace('function sCategoryBody(){','function sCategoryBodyOriginal(){')+
  fixed.replace('function sCategoryBody(){','function sCategoryBodyFixed(){')+
  '  function sCategoryBody(){return state.__categoryRowOriginal?sCategoryBodyOriginal():sCategoryBodyFixed();}\n'+testApi;
html=html.slice(0,old.start)+replacement+html.slice(old.end);
html=html.replace('src="vendor/lucide.min.js"','src="'+pathToFileURL(path.join(root,'prototype/vendor/lucide.min.js')).href+'"')
 .replace('src="scene-presets.js"','src="'+pathToFileURL(path.join(root,'prototype/scene-presets.js')).href+'"');
fs.writeFileSync(harness,html);
(async()=>{const browser=await chromium.launch({channel:'chrome',headless:true});let page;const errors=[],checks=[];
try{
 page=await browser.newPage({viewport:{width:900,height:1200}});
 page.on('pageerror',e=>errors.push(e.message));
 await page.route(/^https?:/,route=>route.abort());
 for(const profile of [{width:398,height:844,scale:1,appearance:'light'},{width:320,height:568,scale:1.4,appearance:'dark'}]){
  await page.goto(pathToFileURL(harness).href+'?page=flow-category-select&viewport='+profile.width+'x'+profile.height);
  await page.waitForFunction(()=>window.beeResponsivePreview&&window.__categoryPickerRowQa);
  await page.evaluate(profile=>{Object.assign(window.beeImmersiveDemo.settings,{appearance:profile.appearance,skin:'none'});window.beeResponsivePreview.set(profile)},profile);
  const phone=page.locator('#bee-immersive-phone');
  const geometry=()=>phone.locator('[data-action^="s-category-parent"],[data-action^="s-category-child"]').evaluateAll(nodes=>nodes.map(n=>{const r=n.getBoundingClientRect();return [n.dataset.action,...['x','y','width','height'].map(k=>Math.round(r[k]*100)/100)];}));
  const fixedFour=await geometry();
  await page.evaluate(()=>window.__categoryPickerRowQa.original(true));
  assert.deepEqual(await geometry(),fixedFour,'original four sample geometry must stay identical');
  await page.evaluate(()=>window.__categoryPickerRowQa.original(false));
  assert.equal(await phone.locator('[data-action^="s-category-parent"]').count(),4);
  assert(await phone.locator('[data-action="s-category-parent:blocked"]').isDisabled());
  assert(await phone.locator('[data-action="s-category-child:tea"]').isDisabled());
  await page.evaluate(()=>window.__categoryPickerRowQa.append());
  assert.equal(await phone.locator('[data-action^="s-category-parent"]').count(),36);
  const legacyReference=old.body.includes('const roots=groups.map(');
  if(legacyReference){
   await page.evaluate(()=>window.__categoryPickerRowQa.original(true));
   await phone.locator('[data-action="s-category-parent:food"]').click();
   const hiddenChild=await phone.locator('[data-action="s-category-child:lunch"]').evaluate(n=>{
    const viewport=n.closest('.s-category-frame').children[1];return n.getBoundingClientRect().top>viewport.getBoundingClientRect().bottom;
   });
   assert(hiddenChild,'legacy long-list reference must reproduce the offscreen-child bug');
   await phone.locator('.bc-sheet').screenshot({path:path.join(evidence,'legacy-long-child-offscreen-'+profile.width+'.png')});
   await page.evaluate(()=>window.__categoryPickerRowQa.original(false));
  }
  await phone.locator('[data-action="s-category-parent:food"]').click();
  const position=await phone.locator('[data-action="s-category-child:lunch"]').evaluate(n=>{
   const group=n.closest('[data-s-category-children]'),row=group.previousElementSibling,next=group.nextElementSibling;
   const viewport=n.closest('.s-category-frame').children[1],r=n.getBoundingClientRect(),v=viewport.getBoundingClientRect();
   return {row:row.dataset.sCategoryRow,nextRow:next.dataset.sCategoryRow,top:r.top,bottom:r.bottom,viewportTop:v.top,viewportBottom:v.bottom,scrollTop:viewport.scrollTop,childBlockBeforeNextRow:group.getBoundingClientRect().bottom<=next.getBoundingClientRect().top};
  });
  assert.equal(position.row,'0');assert.equal(position.nextRow,'1');assert.equal(position.scrollTop,0);
  assert(position.top>=position.viewportTop&&position.bottom<=position.viewportBottom,'first-row child must be fully visible without tail scroll');
  assert(position.childBlockBeforeNextRow);
  assert(await phone.locator('[data-action="s-category-child:food"]').isDisabled());
  await phone.locator('.bc-sheet').screenshot({path:path.join(evidence,'long-first-row-'+profile.width+'.png')});
  await phone.locator('[data-action="s-category-child:lunch"]').click();
  assert.equal(await phone.locator('.bc-sheet').count(),0);assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.subcategory),'午餐');
  await page.evaluate(()=>window.__categoryPickerRowQa.open());
  await phone.locator('[data-s-category-query]').fill('咖啡');
  assert.equal(await phone.locator('[data-action^="s-category-parent"]').count(),1);
  assert.equal(await phone.locator('[data-action="s-category-child:tea"]').count(),0);
  assert.equal(await phone.locator('[data-action="s-category-child:coffee"]').count(),1);
  await phone.locator('[data-action="s-category-child:coffee"]').click();
  assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.subcategory),'咖啡');
  await page.evaluate(()=>window.__categoryPickerRowQa.open());
  await phone.locator('[data-action="s-category-parent:traffic"]').click();
  assert.equal(await phone.locator('.bc-sheet').count(),0);
  assert.equal(await page.evaluate(()=>window.beeImmersiveDemo.state.category),'交通');
  checks.push({profile,parents:36,firstRowNoScroll:position,legacyOffscreenBugReproduced:legacyReference?true:null,fourSampleGeometryUnchanged:true,disabledParentChildEligibility:true,search:true,immediate:true});
 }
 assert.deepEqual(errors,[]);
 fs.writeFileSync(path.join(evidence,'checks.json'),JSON.stringify({checks,errors},null,2));
 console.log(JSON.stringify({profiles:checks.length,longListParents:36,fourSampleGeometryUnchanged:true,errors}));
}catch(error){if(page)await page.screenshot({path:path.join(evidence,'failure.png')});throw error;}
finally{await browser.close();fs.rmSync(temporary,{recursive:true,force:true});}
})().catch(error=>{console.error(error);process.exit(1)});
