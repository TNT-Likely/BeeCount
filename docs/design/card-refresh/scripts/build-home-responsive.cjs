const fs=require('fs'),path=require('path'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..');
const cases=[['标准屏 · 固定汇总','398x844',1,''],['短屏 · 顶部可上滑','375x667',1,''],['小屏 · 140% 字体 · 上滑后','320x568',1.4,''],['空账本 · 小屏 · 上滑后','320x568',1.4,'&records=empty'],['标准屏 · 预算超支','398x844',1,'&budget=exceeded']];
const cards=cases.map(([name,size,scale,extra])=>{const [w,h]=size.split('x');return `<article><h2>${name}</h2><p>${size} · ${scale*100}% 字体</p><a href="../prototype/demo.html?page=home&viewport=${size}&scale=${scale}&brand=hidden${extra}">打开交互原型 ↗</a><iframe ${size==='320x568'?'data-preview-scroll="300" onload="this.contentDocument.querySelector(\'.bc-main\').scrollTop=300"':''} title="${name}" width="${Number(w)+2}" height="${Number(h)+2}" src="../prototype/demo.html?page=home&viewport=${size}&scale=${scale}&brand=hidden${extra}&embed=1"></iframe></article>`}).join('');
const html=`<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>首页 · 长短屏布局</title><style>*{box-sizing:border-box}body{margin:0;padding:28px;background:#eef1f4;color:#25282c;font:14px -apple-system,BlinkMacSystemFont,'PingFang SC',sans-serif}h1{font-size:26px}header{max-width:1100px;margin-bottom:24px;line-height:1.7}main{display:flex;align-items:flex-start;gap:22px;flex-wrap:wrap}article{background:#fff;padding:16px;border-radius:22px}h2{font-size:16px;margin:0 0 5px}p{color:#777c82;margin:0 0 8px}a{display:block;color:#887019;margin-bottom:12px}iframe{display:block;border:0;border-radius:30px}</style><header><h1>首页 · 长短屏与空态</h1><p>标准屏固定顶部汇总，账单在卡片内滚动；短屏可先上滑顶部卡片，账单列表保留独立滚动区域。底部操作栏保持可用；双击明细标签回到顶部。原型使用合成数据。</p></header><main>${cards}</main></html>`;
fs.writeFileSync(path.join(root,'boards/home-responsive.html'),html);
(async()=>{const b=await chromium.launch({channel:'chrome',headless:true}),p=await b.newPage({viewport:{width:2300,height:1200}});try{
 await p.goto('file://'+path.join(root,'boards/home-responsive.html'));await Promise.all(p.frames().slice(1).map(f=>f.waitForFunction(()=>window.beeImmersiveDemo)));await p.waitForTimeout(300);await p.screenshot({path:path.join(root,'boards/home-responsive.png'),fullPage:true});
 const checks=[],errors=[];p.on('pageerror',e=>errors.push(e.message));
 for(const [name,size,scale,extra] of cases){
  await p.goto('file://'+path.join(root,'prototype/demo.html')+`?page=home&viewport=${size}&scale=${scale}&brand=hidden${extra}`);await p.waitForFunction(()=>window.beeImmersiveDemo);
  const phone=p.locator('#bee-immersive-phone');
  const geometry=await phone.evaluate(e=>{const m=e.querySelector('.bc-main'),l=e.querySelector('.h-journal-list'),n=e.querySelector('.bc-nav'),r=e.getBoundingClientRect();return {phoneWidth:r.width,phoneHeight:r.height,overflow:e.scrollWidth>e.clientWidth,mainBottom:m.getBoundingClientRect().bottom-r.top,navTop:n.getBoundingClientRect().top-r.top,listHeight:l.clientHeight,compact:e.dataset.homeCompact};});
  if(geometry.overflow||geometry.mainBottom>geometry.navTop||geometry.listHeight<100)throw Error(JSON.stringify({name,geometry}));
  if(extra.includes('records=empty')&&!await phone.getByText('还没有记账',{exact:true}).count())throw Error('empty state missing');
  if(geometry.compact==='true'){const moved=await phone.locator('.bc-main').evaluate(e=>{e.scrollTop=300;return e.scrollTop;});if(moved<50)throw Error('compact header cannot scroll');}
  if(extra.includes('budget=exceeded')&&!await phone.getByText('剩余 ¥-1,220.72',{exact:true}).count())throw Error('original budget exclusion state missing');
  checks.push({name,size,scale,...geometry});
 }
 if(errors.length)throw Error(errors.join('\n'));
 fs.writeFileSync(path.join(root,'qa/home-layout-checks.json'),JSON.stringify({checks,errors},null,2));
 const samples=JSON.parse(fs.readFileSync(path.join(root,'components/samples.json')));
 // Re-capture the actual current home markup, including its row renderer and metrics.
 // Otherwise the brand card can retain an obsolete embedded transaction list.
 await p.goto('file://'+path.join(root,'prototype/demo.html')+'?page=home&viewport=398x844&brand=shown');await p.waitForFunction(()=>window.beeImmersiveDemo);
 samples.brand=await p.locator('#bee-immersive-phone .bc-topbar').evaluate(e=>e.outerHTML);
 samples.summary=await p.locator('#bee-immersive-phone .bc-summary').evaluate(e=>e.outerHTML);
 await p.goto('file://'+path.join(root,'prototype/demo.html')+'?page=home&viewport=320x568&brand=hidden');await p.waitForFunction(()=>window.beeImmersiveDemo);
 samples.brandOff=await p.locator('#bee-immersive-phone .bc-topbar').evaluate(e=>e.outerHTML);
 const stream=await p.locator('#bee-immersive-phone .bc-stream').evaluate(e=>e.outerHTML);
 await p.locator('#bee-immersive-phone [data-action=ledger]').first().click();
 samples.ledgerPicker=await p.locator('.r-modal-layer .bc-sheet').evaluate(e=>e.innerHTML);
 samples.brandOff+='<div class="h-gallery-compact"><p>¥3,286.50</p>'+stream+'</div>';
 fs.writeFileSync(path.join(root,'components/samples.json'),JSON.stringify(samples,null,2));
 console.log(JSON.stringify({checks,errors}));
}finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
