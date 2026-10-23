const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const toSvg=require('./dom-to-svg.cjs'),snapshotDom=require('./snapshot-dom.cjs'),root=path.resolve(__dirname,'..');
const write=(name,data)=>fs.writeFileSync(path.join(root,name),data),esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const cases=[
 {slug:'compact-667',title:'紧凑记账 · 375×667',width:375,height:667},
 {slug:'compact-667-subcategories',title:'短屏二级分类展开',width:375,height:667,expanded:true},
 {slug:'compact-568',title:'紧凑记账 · 320×568',width:320,height:568},
 {slug:'compact-568-subcategories',title:'小屏二级分类 · 两列图标',width:320,height:568,expanded:true},
 {slug:'compact-note',title:'小屏备注直接编辑',width:320,height:568,noteExpanded:true},
 {slug:'compact-currency',title:'小屏币种选择弹层',width:320,height:568,modal:'v-currency'},
 {slug:'compact-large-text',title:'小屏 · 140% 字体',width:320,height:568,scale:1.4,expanded:true},
];
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true}),page=await browser.newPage({viewport:{width:900,height:1100},deviceScaleFactor:2});const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(pathToFileURL(path.join(root,'prototype/demo.html')).href);await page.waitForFunction(()=>window.beeResponsivePreview&&window.beeImmersiveDemo);
 const presets=await require('./scene-presets.cjs')(page,root);
 const base=await page.evaluate(()=>JSON.parse(JSON.stringify(window.beeImmersiveDemo.state)));const css=[...fs.readFileSync(path.join(root,'prototype/source.fragment.html'),'utf8').matchAll(/<style>([\s\S]*?)<\/style>/g)].map(m=>m[1]).join('\n');
 const manifest=[],checks=[];fs.mkdirSync(path.join(root,'figma/html'),{recursive:true});
 for(const c of cases){
  await page.evaluate(({base,c})=>{const api=window.beeImmersiveDemo;Object.assign(api.state,JSON.parse(JSON.stringify(base)),{page:'editor',zNoteExpanded:c.noteExpanded===true,expression:'32.00',amount:'32.00',recordType:'expense',category:'餐饮',expandedCategory:c.expanded?'餐饮':'',subcategory:c.expanded?'午餐':'',note:'午间食堂',rModal:null,history:[]});Object.assign(api.settings,{skin:'none',appearance:'light',immersive:false});window.beeResponsivePreview.set({width:c.width,height:c.height,scale:c.scale||1});}, {base,c});
  if(c.expanded) await page.locator('.q-category-scroll').evaluate(sc=>{const child=sc.querySelector('.p-subcategories');if(child)sc.scrollTop+=child.getBoundingClientRect().top-sc.getBoundingClientRect().top;});
  if(c.modal) await page.locator(`[data-action="${c.modal}"]`).click();
  await page.evaluate(async()=>{await document.fonts.ready;await Promise.all([...document.images].map(img=>img.decode().catch(()=>{})));await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));});
  const phone=page.locator('#bee-immersive-phone');const geometry=await phone.evaluate(el=>{const r=el.getBoundingClientRect(),rect=q=>{const a=el.querySelector(q).getBoundingClientRect();return {x:a.x-r.x,y:a.y-r.y,width:a.width,height:a.height};};return {phone:{width:r.width,height:r.height},amount:rect('.p-amount-card'),category:rect('.q-category-scroll'),toolbar:rect('.z-meta'),keypad:rect('.p-keypad'),save:rect('.p-calc-footer'),keyHeights:[...el.querySelectorAll('.p-keypad button')].map(b=>b.getBoundingClientRect().height),modal:!!el.querySelector('[role="dialog"]')};});
  if(geometry.keyHeights.some(h=>h<43.9)||geometry.category.height<40||geometry.save.y+geometry.save.height>c.height+1)throw Error(c.slug+' layout overflow '+JSON.stringify(geometry));
  await presets.capture(page,c.slug);
  await phone.screenshot({path:path.join(root,'screens/viewport',c.slug+'.png')});fs.copyFileSync(path.join(root,'screens/viewport',c.slug+'.png'),path.join(root,'screens/full',c.slug+'.png'));
  const svg=await phone.evaluate(toSvg);write('figma/'+c.slug+'.svg',svg.svg);const dom=await phone.evaluate(snapshotDom);write('figma/html/'+c.slug+'.html',`<!doctype html><html lang="zh-CN"><meta charset="utf-8"><style>${css}*{box-sizing:border-box}body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}#bee-immersive-suite{width:${c.width}px}</style><div id="bee-immersive-suite">${dom}</div><script>for(const e of document.querySelectorAll('[data-snapshot-scroll]'))e.scrollTop=Number(e.dataset.snapshotScroll);</script></html>`);
  manifest.push({route:'editor',slug:c.slug,title:c.title,group:'短屏适配',width:c.width,height:c.height,fullHeight:c.height,viewport:'screens/viewport/'+c.slug+'.png',full:'screens/full/'+c.slug+'.png',svg:'figma/'+c.slug+'.svg'});checks.push({slug:c.slug,pass:true,geometry});
  if(c.modal&&!geometry.modal)throw Error(c.slug+' modal missing');
  if(c.modal==='q-note'){
    await page.locator('[data-q-note]').fill('合成备注取消');await page.getByRole('button',{name:'取消修改备注',exact:true}).click();
    if(await page.evaluate(()=>window.beeImmersiveDemo.state.note)!=='午间食堂')throw Error('note cancel wrote draft');
    await page.locator('[data-action="q-note"]').click();await page.locator('[data-q-note]').fill('合成备注确认');await page.locator('[data-action="q-note-save"]').click();
    if(await page.evaluate(()=>window.beeImmersiveDemo.state.note)!=='合成备注确认')throw Error('note confirm did not apply');
  }
  if(c.modal==='v-currency'){
    await page.locator('[role="dialog"] [data-action="close"]').first().click();
    if(await page.evaluate(()=>window.beeImmersiveDemo.state.fRecordCurrency)!=='CNY')throw Error('currency cancel changed selection');
  }

 }
 presets.save();
 const old=JSON.parse(fs.readFileSync(path.join(root,'screens/manifest.json'),'utf8')).filter(s=>s.group!=='短屏适配');write('screens/manifest.json',JSON.stringify([...old,...manifest],null,2));
 const figures=items=>items.map(m=>`<figure class="screen" data-compact="true"><h2><span>${esc(m.title)}<small>短屏适配 · ${m.width}×${m.height}</small></span></h2><a href="../prototype/demo.html?page=${encodeURIComponent(m.route)}&scene=${encodeURIComponent(m.slug)}" style="display:flex;justify-content:center;align-items:flex-start;height:844px"><img src="../${m.viewport}" alt="${esc(m.title)}" style="width:${m.width}px;height:${m.height}px;max-width:100%;object-fit:contain"></a></figure>`).join('');
 write('boards/compact-pages.html',`<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>BeeCount · 紧凑记账设计</title><style>*{box-sizing:border-box}body{margin:0;padding:40px;background:#f1f3f5;color:#262829;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;width:1400px}h1{font-size:30px;margin:0 0 10px}p{font-size:14px;color:#697078;margin:0 0 30px}.grid{display:grid;grid-template-columns:repeat(3,398px);gap:24px 42px}.screen{margin:0}.screen h2{height:50px;font-size:15px;margin:0}.screen small{display:block;font-size:11px;color:#777;font-weight:400;margin-top:5px}.screen img{border-radius:26px}a{color:inherit}</style><h1>紧凑记账 · 短屏与交互补充稿</h1><p>金额常驻 · 分类占剩余高度滚动 · 快捷栏与键盘固定 · 44 点击高度 · 默认无皮肤 · 2026-10-23 · <a href="../prototype/demo.html?viewport=320x568&amp;page=editor">打开交互原型</a></p><main class="grid">${figures(manifest)}</main></html>`);
 const boardPage=await browser.newPage({deviceScaleFactor:1});
 for(const name of ['all-pages','main-pages','interactions','compact-pages']){
  if(name!=='compact-pages'){
   const file=path.join(root,'boards/'+name+'.html');let text=fs.readFileSync(file,'utf8').replace(/<figure class="screen" data-compact="true">[\s\S]*?<\/figure>/g,'');const selected=name==='all-pages'?manifest:name==='main-pages'?manifest.filter(s=>['compact-667','compact-568','compact-large-text'].includes(s.slug)):manifest.filter(s=>s.slug.includes('subcategories')||s.slug==='compact-note'||s.slug==='compact-currency');text=text.replace('</main>',figures(selected)+'</main>');const count=(text.match(/<figure class="screen"/g)||[]).length;text=text.replace(/· \d+ 个场景 ·/,'· '+count+' 个场景 ·');write('boards/'+name+'.html',text);
  }
  await boardPage.goto(pathToFileURL(path.join(root,'boards/'+name+'.html')).href);await boardPage.evaluate(()=>Promise.all([...document.images].map(i=>i.decode())));await boardPage.screenshot({path:path.join(root,'boards/'+name+'.png'),fullPage:true});
 }
 const tokens=JSON.parse(fs.readFileSync(path.join(root,'tokens/design-tokens.json'),'utf8'));tokens.responsive={compactSafeHeight:720,referenceViewports:[[375,667],[320,568]],textScales:[1,1.4],minKeyTouch:44,childRows:2,childViewport:92,narrowChildColumns:2,amount:'short-screen pinned compact card',category:'remaining-height scroll',metadata:'fixed quick action bar',nativeFigma:'compact supplement not synced yet'};write('tokens/design-tokens.json',JSON.stringify(tokens,null,2));write('components/product.css',css);write('qa/responsive-checks.json',JSON.stringify({scenes:cases.length,errors,checks},null,2));
 if(errors.length)throw Error(errors.join('\n'));console.log(JSON.stringify({scenes:cases.length,board:'boards/compact-pages.png',editable:'figma/compact-*.svg and figma/html/compact-*.html',errors}));await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
