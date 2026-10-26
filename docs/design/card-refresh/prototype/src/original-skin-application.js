// Layout adapter only. All moving artwork comes from the pinned 3.9 Flutter renderer.
// Shared by the main demo and the isolated application review.
(function(global){
'use strict';
const originals=new Set(['anniversary','anniv_cake']);
function layout({width:w,height:h,page,scheme,placement='adapt',summaryRect,headerTop=43,navRect}){
 const scrollOffset=headerTop-43;
 let headerSlot,headerArtRect=null,headerRadius=0;
 if(scheme==='folio'&&page==='home'){headerSlot=summaryRect;headerRadius=22;}
 else if(scheme==='folio'&&page==='mine'){
  headerSlot=[18,headerTop,w-36,Math.max(90,summaryRect[1]-headerTop)];headerRadius=22;
 }else{
  const available=Math.max(70,summaryRect[1]-scrollOffset),height=Math.min(208,available),width=height*398/208;
  const left=page==='home'?Math.max(0,(w-320)*.43):Math.max(0,(w-width)/2);
  headerSlot=[left,scrollOffset,Math.min(width,w-left),height];
 }
 if(scheme==='folio'&&placement==='adapt'){
  const artWidth=Math.min(240,headerSlot[2]-96),artHeight=artWidth*208/398;
  headerArtRect=[headerSlot[2]-artWidth-12,page==='home'?48:Math.max(0,(headerSlot[3]-artHeight)/2),artWidth,artHeight];
 }
 const draw=headerArtRect||[0,0,headerSlot[2],headerSlot[3]],drawHeight=Math.min(draw[2]/398,draw[3]/208)*208,drawTop=headerSlot[1]+draw[1];
 return{headerSlot,headerArtRect,headerRadius,tabSlot:navRect||[17,h-89,w-34,57],tabRadius:29,headerOnScreen:drawTop+drawHeight>36&&drawTop<h-70};
}
function pageBackground(skin,dark){return dark?'linear-gradient(#000 0px,#000 180px,#201b13 390px,var(--bc-bg) 100%)':skin==='anniv_cake'?'linear-gradient(#fff8ee,var(--bc-bg) 540px)':'linear-gradient(#fff9df,var(--bc-bg) 540px)';}
function rect(node,phone){const b=node.getBoundingClientRect(),p=phone.getBoundingClientRect();return[b.left-p.left,b.top-p.top,b.width,b.height];}
function colorNumber(text){const c=text.match(/[\d.]+/g)?.map(Number)||[0,0,0];return(0xff000000+c[0]*65536+c[1]*256+c[2])>>>0;}
function install(demo){
 const phone=demo.phone,doc=phone.ownerDocument,win=doc.defaultView,media=win.matchMedia('(prefers-reduced-motion: reduce)');
 phone.parentElement.style.position='relative';
 let frame=null,ready=false,lastConfig='',status=null,ownsLayer=false,visible=true,scrollNode=null;
 const probe=doc.createElement('span');probe.style.cssText='position:fixed;width:0;height:0;visibility:hidden;pointer-events:none';probe.setAttribute('aria-hidden','true');doc.body.appendChild(probe);
 function send(config){if(!frame||!ready)return;const text=JSON.stringify({type:'beecount-original-skin',command:'configure',...config});if(text===lastConfig)return;lastConfig=text;frame.contentWindow.postMessage(text,win.location.origin);}
 function update(){
  const skin=demo.settings.skin,dark=demo.settings.appearance==='dark'||(demo.settings.appearance==='auto'&&win.matchMedia('(prefers-color-scheme: dark)').matches),page=demo.state.page;
  const active=originals.has(skin)&&!['editor','welcome','welcomeCurrency','welcomeCategories','welcomeCloud','welcomePrivacy','welcomeImport','welcomeAttachments','welcomeDone'].includes(page);
  if(!active){if(!ownsLayer)return;ownsLayer=false;delete phone.dataset.nativeOriginal;delete phone.dataset.nativeApplication;delete phone.dataset.nativeActive;delete phone.dataset.nativePlain;phone.style.removeProperty('--original-page');if(frame){frame.style.display='none';send({...status,skin:originals.has(skin)?skin:'anniversary',kind:'application',headerVisible:false,tabVisible:false,motion:'paused'});}return;}
  ownsLayer=true;phone.dataset.nativeOriginal='true';phone.dataset.nativeActive='true';phone.dataset.nativePlain='false';
  // Old world/hero canvases are hidden; keep the existing thumbnail animation loop.
  if(!frame){frame=doc.createElement('iframe');frame.className='sa-original-stage';frame.title='线上原版动态皮肤';frame.setAttribute('aria-hidden','true');frame.tabIndex=-1;
   const url=new URL('../renderers/build/original-skins-390/index.html',win.location.href);url.search=new URLSearchParams({instance:'prototype-original',kind:'application',skin,dark:dark?'1':'0'});frame.src=url.href;phone.parentElement.appendChild(frame);}
  const w=phone.offsetWidth,h=phone.offsetHeight,main=phone.querySelector('.bc-main'),topbar=phone.querySelector('.bc-topbar,.bc-subhead'),summary=phone.querySelector('.bc-summary,.u-ledger-summary')||main?.querySelector('.bc-surface'),nav=phone.querySelector('.bc-nav');
  const scheme=dark||!['home','mine'].includes(page)?'canopy':'folio';
  phone.dataset.nativeApplication=scheme;phone.style.setProperty('--original-page',pageBackground(skin,dark));
  Object.assign(frame.style,{display:'block',width:w+'px',height:h+'px',left:phone.offsetLeft+'px',top:phone.offsetTop+'px'});
  const geometry=layout({width:w,height:h,page,scheme,summaryRect:summary?rect(summary,phone):[18,150,w-36,140],headerTop:topbar?rect(topbar,phone)[1]:43,navRect:nav?rect(nav,phone):[0,0,0,0]});
  probe.style.color=win.getComputedStyle(nav||phone).getPropertyValue('--bc-paper');probe.style.colorScheme=dark?'dark':'light';
  const modal=Boolean(demo.state.rModal)||phone.dataset.modal==='true'||Boolean(phone.querySelector('.c3-context-layer'));
  send({...geometry,skin,kind:'application',dark,headerVisible:visible&&!doc.hidden&&geometry.headerOnScreen,tabVisible:visible&&!doc.hidden&&Boolean(nav),tabBackground:colorNumber(win.getComputedStyle(probe).color),motion:modal?'paused':demo.settings.animation?'play':'off',systemReduced:media.matches});
  if(main&&scrollNode!==main){scrollNode=main;main.addEventListener('scroll',update,{passive:true});phone.querySelector('.h-journal-list')?.addEventListener('scroll',update,{passive:true});}
 }
 win.addEventListener('message',event=>{if(!frame||event.source!==frame.contentWindow||event.origin!==win.location.origin||typeof event.data!=='string')return;let data;try{data=JSON.parse(event.data);}catch{return;}if(data.type!=='beecount-original-skin-status'||data.instance!=='prototype-original')return;status=data;ready=true;update();});
 const observer=new win.MutationObserver(update);observer.observe(phone,{childList:true});
 new win.ResizeObserver(update).observe(phone);
 new win.IntersectionObserver(entries=>{visible=entries[0].isIntersecting;update();},{rootMargin:'100px'}).observe(phone);
 doc.addEventListener('visibilitychange',update);doc.addEventListener('change',()=>queueMicrotask(update));media.addEventListener('change',update);
 update();return{update,get status(){return status},get frame(){return frame}};
}
global.BeeOriginalSkinLayout={layout,pageBackground,install};
})(window);
