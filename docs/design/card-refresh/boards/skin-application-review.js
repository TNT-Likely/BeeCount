(() => {
'use strict';
const $=s=>document.querySelector(s),$$=s=>[...document.querySelectorAll(s)];
const runtime=new URL('../renderers/build/original-skins-390/index.html',location.href);
const state={skin:'anniversary',page:'home',viewport:'398x844',application:'auto',placement:'adapt',appearance:'both',theme:'original',motion:'play',plain:false,linked:true,referencePlay:false};
const params=new URLSearchParams(location.search),single=['light','dark'].includes(params.get('single'))?params.get('single'):null;
const accent={yellow:'#facb16',green:'#28a399',blue:'#2395e7',violet:'#8060bf'};
for(const key of ['skin','page','viewport','application','placement','appearance','theme','motion']){
 const input=$('#'+key),value=params.get(key);
 if(value&&[...input.options].some(o=>o.value===value))state[key]=value;
}
if(single){state.appearance=single;document.body.dataset.single='true';}
state.plain=params.get('plain')==='1';
const entries=new Map(),renderers=new Map(),media=matchMedia('(prefers-reduced-motion: reduce)');
function effectiveScheme(appearance){return state.application==='auto'?(appearance==='dark'?'canopy':'folio'):state.application;}
function boundColor(){return state.skin==='anniv_cake'?'#ff7a45':'#f8c91c';}
function rendererUrl(id,kind,dark){const url=new URL(runtime);url.search=new URLSearchParams({instance:id,kind,skin:state.skin,dark:dark?'1':'0',motion:kind==='header'?'off':state.motion});return url.href;}
function recordRenderer(frame,id,kind,dark){const record={frame,id,kind,dark,ready:false,lastConfig:'',status:null};renderers.set(id,record);frame.src=rendererUrl(id,kind,dark);return record;}
function sizeFrames(){
 const[w,h]=state.viewport.split('x').map(Number);
 document.documentElement.style.setProperty('--device-width',w+'px');document.documentElement.style.setProperty('--device-height',h+'px');
 for(const frame of $$('[data-frame]')){const holder=frame.parentElement;if(!holder.clientWidth)continue;const scale=Math.min(1,holder.clientWidth/w);Object.assign(frame.style,{width:w+'px',height:h+'px',transform:'scale('+scale+')'});holder.style.height=h*scale+'px';}
 for(const frame of $$('[data-reference]')){const holder=frame.parentElement;if(!holder.clientWidth)continue;const scale=Math.min(1,holder.clientWidth/398);Object.assign(frame.style,{width:'398px',height:'208px',transform:'scale('+scale+')'});holder.style.height=208*scale+'px';}
}
function send(record,config,force=false){if(!record?.ready)return;const text=JSON.stringify({type:'beecount-original-skin',command:'configure',skin:state.skin,kind:record.kind,dark:record.dark,motion:state.motion,systemReduced:media.matches,...config});if(force||record.lastConfig!==text){record.lastConfig=text;record.frame.contentWindow.postMessage(text,location.origin);}}
function colorInt(text){const parts=text.match(/[\d.]+/g)?.map(Number)||[25,26,27];return (0xff000000+parts[0]*65536+parts[1]*256+parts[2])>>>0;}
function paperColor(entry,element){const probe=entry.colorProbe;probe.style.color=entry.win.getComputedStyle(element).getPropertyValue('--bc-paper');probe.style.colorScheme=entry.appearance;return colorInt(entry.win.getComputedStyle(probe).color);}
function relativeRect(el,phone){const b=el.getBoundingClientRect(),p=phone.getBoundingClientRect();return [b.left-p.left,b.top-p.top,b.width,b.height];}
function mainScroll(entry){const main=entry.phone.querySelector('.bc-main');return main&&main.scrollHeight>main.clientHeight+2&&['auto','scroll'].includes(entry.win.getComputedStyle(main).overflowY)?main:entry.phone.querySelector('.h-journal-list')||main;}
function setScroll(value){syncing=true;for(const entry of entries.values()){const target=mainScroll(entry);if(target)target.scrollTop=value;decorate(entry);}$$('[data-scroll]').forEach(b=>b.setAttribute('aria-pressed',String(Number(b.dataset.scroll)===value)));requestAnimationFrame(()=>syncing=false);}
let syncing=false;
function scrolled(entry){decorate(entry);if(!state.linked||syncing)return;const target=mainScroll(entry);if(!target)return;const ratio=target.scrollTop/Math.max(1,target.scrollHeight-target.clientHeight);syncing=true;for(const other of entries.values())if(other!==entry){const t=mainScroll(other);if(t)t.scrollTop=ratio*Math.max(0,t.scrollHeight-t.clientHeight);decorate(other);}requestAnimationFrame(()=>syncing=false);}
function decorate(entry){
 const{phone,win}=entry,scheme=effectiveScheme(entry.appearance),main=phone.querySelector('.bc-main');if(!main)return;
 const active=['home','mine'].includes(entry.demo.state.page),modal=Boolean(entry.demo.state.rModal)||phone.dataset.modal==='true';
 phone.dataset.nativeApplication=scheme;phone.dataset.nativeActive=String(active);phone.dataset.nativePlain=String(state.plain);
 phone.style.setProperty('--original-page',win.BeeOriginalSkinLayout.pageBackground(state.skin,entry.appearance==='dark'));
 const[w,h]=state.viewport.split('x').map(Number),host=phone.parentElement;
 host.style.position='relative';Object.assign(entry.native.frame.style,{width:w+'px',height:h+'px',left:phone.offsetLeft+'px',top:phone.offsetTop+'px',display:active&&!state.plain?'block':'none'});
 const topbar=phone.querySelector('.bc-topbar'),summary=phone.querySelector('.bc-summary,.u-ledger-summary')||main.querySelector('.bc-surface');
 const geometry=win.BeeOriginalSkinLayout.layout({width:w,height:h,page:entry.demo.state.page,scheme,placement:state.placement,summaryRect:summary?relativeRect(summary,phone):[18,113,w-36,284],headerTop:topbar?relativeRect(topbar,phone)[1]:43,navRect:phone.querySelector('.bc-nav')?relativeRect(phone.querySelector('.bc-nav'),phone):null});
 const {headerSlot,headerArtRect,headerRadius}=geometry;
 const nav=phone.querySelector('.bc-nav'),tabSlot=nav?relativeRect(nav,phone):[17,h-89,w-34,57];
 const hidden=entry.frame.closest('[data-appearance-card]').hidden||document.hidden;
 const headerVisible=active&&!state.plain&&!hidden&&geometry.headerOnScreen;
 entry.headerSlot=headerSlot;entry.headerArtRect=headerArtRect;
 send(entry.native,{headerSlot,headerArtRect,headerRadius,tabSlot,tabRadius:29,tabBackground:paperColor(entry,nav||phone),headerVisible,tabVisible:active&&!state.plain&&!hidden,motion:modal?'paused':state.motion});
 const target=mainScroll(entry);
 if(entry.scrollMain!==main){entry.scrollMain=main;main.addEventListener('scroll',()=>scrolled(entry),{passive:true});phone.querySelector('.h-journal-list')?.addEventListener('scroll',()=>scrolled(entry),{passive:true});}
 const status=$('[data-status="'+entry.appearance+'"]');
 status.textContent=!entry.native.ready?'正在加载线上原实现…':!active?'已进入交互页面 · 场景收起':state.plain?'无皮肤 · 原页面布局':modal?'弹窗打开 · 原动画暂停':!headerVisible?'场景离场 · 原动画暂停':state.motion==='off'||media.matches?'原代码静态帧 · 完整构图':state.motion==='paused'?'原动画已暂停':target?.scrollTop>0?'滚动预览 · 原动画播放':'原画与原动画 · 正在播放';
 $('[data-mode-label="'+entry.appearance+'"]').textContent=scheme==='folio'?'02 · 首卡共景':'01 · 顶部柔幕';
}
function refresh(entry,resetPage=false){
 const d=entry.demo,w=Number(state.viewport.split('x')[0]),h=Number(state.viewport.split('x')[1]);
 Object.assign(d.settings,{skin:'none',immersive:false,appearance:entry.appearance,accent:state.theme==='original'?boundColor():accent[state.theme],userAccent:state.theme==='original'?boundColor():accent[state.theme],animation:false});
 if(resetPage){d.state.page=state.page;d.state.rModal=null;}
 if(entry.viewport!==state.viewport){const select=entry.doc.querySelector('#bee-preview-size');if(select){if(![...select.options].some(o=>o.value===state.viewport))select.add(new entry.win.Option(state.viewport,state.viewport));select.value=state.viewport;select.dispatchEvent(new entry.win.Event('change',{bubbles:true}));}entry.viewport=state.viewport;}
 d.render();d.freeze?.();Object.assign(entry.phone.style,{width:w+'px',height:h+'px',maxHeight:h+'px'});decorate(entry);
}
function updateLinks(){$('[data-demo-link]').href='../prototype/demo.html?'+new URLSearchParams({originalSkin:state.skin,page:state.page,viewport:state.viewport,appearance:state.appearance==='dark'?'dark':'light'});for(const a of $$('[data-single]'))a.href='skin-application-review.html?'+new URLSearchParams({...state,single:a.dataset.single,plain:state.plain?'1':'0'});}
function update(resetPage=false){
 for(const key of ['skin','page','viewport','application','placement','appearance','theme','motion'])$('#'+key).value=state[key];
 document.body.dataset.appearance=state.appearance==='dark'?'dark':'light';$('#plain').setAttribute('aria-pressed',String(state.plain));$('#plain').textContent=state.plain?'返回原版皮肤':'无皮肤对照';
 $$('[data-appearance-card]').forEach(card=>card.hidden=state.appearance!=='both'&&state.appearance!==card.dataset.appearanceCard);
 for(const entry of entries.values())refresh(entry,resetPage);
 for(const record of renderers.values())if(record.kind==='header')send(record,{motion:state.referencePlay?state.motion:'off'});
 updateLinks();sizeFrames();
}
async function initialize(frame,appearance){
 const win=frame.contentWindow,doc=win.document;if(!win.beeImmersiveDemo){setTimeout(()=>initialize(frame,appearance),60);return;}
 await new Promise(resolve=>{const link=doc.createElement('link');link.rel='stylesheet';link.href=new URL('skin-application-review.css',location.href).href;link.onload=resolve;link.onerror=resolve;doc.head.appendChild(link);});
 const entry={frame,appearance,win,doc,demo:win.beeImmersiveDemo,phone:doc.querySelector('#bee-immersive-phone'),viewport:null};
 const probe=doc.createElement('span');probe.style.cssText='position:fixed;width:0;height:0;visibility:hidden;pointer-events:none';probe.setAttribute('aria-hidden','true');doc.body.appendChild(probe);entry.colorProbe=probe;
 const native=doc.createElement('iframe');native.className='sa-original-stage';native.title='3.9.0原生动态皮肤画布';native.setAttribute('aria-hidden','true');native.tabIndex=-1;
 entry.phone.parentElement.appendChild(native);entry.native=recordRenderer(native,'application-'+appearance,'application',appearance==='dark');entries.set(appearance,entry);
 doc.documentElement.style.background='transparent';doc.body.style.background='transparent';
 entry.observer=new win.MutationObserver(()=>decorate(entry));entry.observer.observe(entry.phone,{childList:true});
 refresh(entry,true);sizeFrames();
}
window.addEventListener('message',event=>{
 if(event.origin!==location.origin||typeof event.data!=='string')return;let data;try{data=JSON.parse(event.data);}catch{return;}
 if(data.type!=='beecount-original-skin-status')return;const record=renderers.get(data.instance);
 if(!record||event.source!==record.frame.contentWindow)return;
 record.status=data;record.ready=true;
 if(record.kind==='application'){const entry=entries.get(record.dark?'dark':'light');if(entry)decorate(entry);}else send(record,{motion:state.referencePlay?state.motion:'off'});
 window.skinApplicationReady=entries.size===2&&[...entries.values()].every(e=>e.native.ready&&Array.isArray(e.native.status?.headerSlot));
});
for(const frame of $$('[data-frame]')){frame.addEventListener('load',()=>initialize(frame,frame.dataset.frame));frame.src='../prototype/demo.html?embed=1&page='+state.page+'&viewport='+state.viewport+'&brand=shown';}
for(const frame of $$('[data-reference]'))recordRenderer(frame,'reference-'+frame.dataset.reference,'header',frame.dataset.reference==='dark');
for(const key of ['skin','page','viewport','application','placement','appearance','theme'])$('#'+key).addEventListener('change',event=>{state[key]=event.target.value;update(key==='page');});
$('#motion').addEventListener('change',event=>{state.motion=event.target.value;for(const entry of entries.values())decorate(entry);for(const record of renderers.values())if(record.kind==='header')send(record,{motion:state.referencePlay?state.motion:'off'});updateLinks();});
$('#plain').addEventListener('click',()=>{state.plain=!state.plain;update();});$('#linked').addEventListener('change',e=>state.linked=e.target.checked);
$('#reference-play').addEventListener('change',e=>{state.referencePlay=e.target.checked;for(const record of renderers.values())if(record.kind==='header')send(record,{motion:state.referencePlay?state.motion:'off'});});
$('#same-frame').addEventListener('click',()=>{state.motion='off';state.referencePlay=false;$('#reference-play').checked=false;update();});
$$('[data-scroll]').forEach(b=>b.addEventListener('click',()=>setScroll(Number(b.dataset.scroll))));
window.addEventListener('resize',()=>{sizeFrames();for(const e of entries.values())decorate(e);});document.addEventListener('visibilitychange',()=>{for(const e of entries.values())decorate(e);});media.addEventListener('change',()=>{for(const e of entries.values())decorate(e);for(const r of renderers.values())if(r.kind==='header')send(r,{motion:state.referencePlay?state.motion:'off'});});
window.skinApplicationReview={state,entries,renderers,update,decorate,setScroll,mainScroll,effectiveScheme};update();
})();
