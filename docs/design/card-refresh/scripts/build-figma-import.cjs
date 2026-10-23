const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const normalize=require('./normalize-figma-dom.cjs');
const root=path.resolve(__dirname,'..'),snapshots=JSON.parse(fs.readFileSync(path.join(root,'figma/dom-snapshots.json'),'utf8'));
const css=fs.readFileSync(path.join(root,'components/product.css'),'utf8');
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const font='@font-face{font-family:"Noto Sans SC";src:url("../fonts/NotoSansSC-Variable.ttf") format("truetype");font-weight:100 900;font-display:block}';
const fixed='*{box-sizing:border-box}body{margin:0;background:#eceeef}#bee-immersive-suite .bc-phone{width:398px!important;min-width:398px!important;height:844px!important;min-height:844px!important;max-height:844px!important;box-shadow:none!important;border:0!important;font-family:"Noto Sans SC",sans-serif!important}#bee-immersive-suite .bc-num,#bee-immersive-suite .sk-inscription,#bee-immersive-suite .x-year-title strong{font-family:"Noto Sans SC",sans-serif!important}[data-figma-before]::before,[data-figma-after]::after{content:none!important;display:none!important}.sc-host{width:398px;overflow:hidden}.review-grid{display:grid;grid-template-columns:repeat(3,398px);gap:60px;padding:40px}';
const restore='<script>for(const e of document.querySelectorAll("[data-snapshot-scroll]"))e.scrollTop=Number(e.dataset.snapshotScroll);</script>';
function html(content){return '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><style>'+font+css+fixed+'</style><div id="bee-immersive-suite">'+content+'</div>'+restore+'</html>';}
(async()=>{const b=await chromium.launch({channel:'chrome',headless:true}),p=await b.newPage({viewport:{width:1440,height:1000}});const normalized=[];
for(const [i,s] of snapshots.entries()){
 const target=path.join(root,'figma/html',s.slug+'.html');fs.writeFileSync(target,html(s.dom));await p.goto(pathToFileURL(target).href);await p.evaluate(()=>document.fonts.ready);
 const dom=await p.locator('.bc-phone').evaluate(normalize);
 fs.writeFileSync(target,html(dom));normalized.push({...s,dom});if(i%30===0)console.log('Prepared '+(i+1)+' / '+snapshots.length);
}
const groups=[normalized.filter(s=>s.group!=='动态皮肤'),normalized.filter(s=>s.group==='动态皮肤')];
for(const [i,list] of groups.entries())fs.writeFileSync(path.join(root,'figma/html',i?'skins.html':'pages.html'),html('<div class="review-grid">'+list.map(s=>'<div class="sc-host" data-label="'+esc(s.title)+'" data-name="'+esc(s.title)+'" id="screen-'+s.slug+'">'+s.dom+'</div>').join('')+'</div>'));
fs.writeFileSync(path.join(root,'qa/figma-source.json'),JSON.stringify({count:normalized.length,fonts:'Noto Sans SC (OFL)',fontScope:'Figma import only; canonical prototype keeps system fonts',screens:normalized.map(({slug,title,group})=>({slug,title,group}))},null,2));
await b.close();console.log('Figma import sources ready');})().catch(e=>{console.error(e);process.exit(1)});
