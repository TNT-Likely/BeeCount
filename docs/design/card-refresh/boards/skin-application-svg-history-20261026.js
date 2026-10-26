(() => {
'use strict';
const $=s=>document.querySelector(s), $$=s=>[...document.querySelectorAll(s)];
const schemes=['canopy','folio','paper'], skins=['constellation','cake'];
const state={skin:'constellation',page:'home',viewport:'398x844',appearance:'light',theme:'yellow',motion:'play',plain:false,linked:true};
const accents={yellow:'#facb16',green:'#28a399',blue:'#2395e7',violet:'#8060bf'};
const colors={
 constellation:{light:{top:'#f8dda0',middle:'#fff1cd',bottom:'#faf7ee',line:'#a37826',gold:'#edbd40'},dark:{top:'#3d3020',middle:'#2a261f',bottom:'#20221f',line:'#e3bd71',gold:'#e9bd52'}},
 cake:{light:{top:'#f6cdb0',middle:'#fcebdd',bottom:'#faf4ed',line:'#b68156',gold:'#edbb65',cake:'#e6b17b',cream:'#fff4df',candle:'#d98461'},dark:{top:'#403029',middle:'#2d2621',bottom:'#22211f',line:'#e4b67e',gold:'#edbd60',cake:'#c18d58',cream:'#ebca98',candle:'#e3a66a'}}
};
const stars=[[267,44],[283,36],[283,52],[283,68],[283,84],[283,101],[265,101],[302,101],[253,74],[318,66]];
const art={
 constellation:`<svg viewBox="0 0 390 280" preserveAspectRatio="xMidYMin slice" aria-hidden="true"><path class="sr-guide-arc" d="M196 161C225 143 332 151 350 83C362 43 329 22 283 20"/><path class="sr-guide-arc" d="M204 174C265 156 349 163 364 103"/><polyline class="sr-constellation" points="267,44 283,36 283,52 283,68 283,84 283,101 265,101 302,101"/>${stars.map(([x,y],i)=>`<circle class="sr-twinkle" cx="${x}" cy="${y}" r="${i===2||i===5?1.9:1.25}" style="animation-delay:-${i*.61}s"/>`).join('')}<path class="sr-twinkle" d="M316 89l1.1 4.2 4.2 1.1-4.2 1.1-1.1 4.2-1.1-4.2-4.2-1.1 4.2-1.1z"/><path class="sr-twinkle" d="M243 52l.8 3.1 3.1.8-3.1.8-.8 3.1-.8-3.1-3.1-.8 3.1-.8z"/><g class="sr-bee-motion"><ellipse class="sr-wing" cx="313" cy="116" rx="4" ry="2.5" transform="rotate(-24 313 116)"/><ellipse class="sr-wing" cx="320" cy="115" rx="4" ry="2.5" transform="rotate(24 320 115)"/><ellipse class="sr-bee-body" cx="316.5" cy="120" rx="5" ry="3.7"/><circle class="sr-bee-head" cx="316" cy="113" r="2.7"/><path class="sr-bee-stripe" d="M312 119h9m-8 3h7"/></g><circle class="sr-constellation-base" cx="228" cy="113" r=".8"/><circle class="sr-constellation-base" cx="341" cy="142" r=".7"/></svg>`,
 cake:`<svg viewBox="0 0 390 280" preserveAspectRatio="xMidYMin slice" aria-hidden="true"><defs><radialGradient id="sr-warm"><stop stop-color="#efbd70" stop-opacity=".5"/><stop offset="1" stop-color="#efbd70" stop-opacity="0"/></radialGradient></defs><ellipse class="sr-glow" cx="290" cy="73" rx="90" ry="78"/><path class="sr-ribbon" d="M223 23C246 17 253 50 274 36S309 22 336 37"/><path class="sr-ribbon" style="animation-delay:-5s;opacity:.23" d="M276 14C292 26 320 4 348 18S370 43 388 35"/><g><ellipse class="sr-cake-body" cx="288" cy="115" rx="32" ry="6"/><rect class="sr-cake-body" x="260" y="81" width="56" height="33" rx="7"/><path class="sr-cake-cream" d="M260 83Q260 75 269 75H307Q316 75 316 83V87Q312 95 308 87V84Q304 91 301 85V83Q296 92 292 86V83Q288 91 284 85V83Q278 91 274 85V83Q267 94 263 87Z"/><path class="sr-candle" d="M283 56l5-3v20m-5 0h11"/><path class="sr-flame" d="M289 48C280 43 288 35 289 31C292 38 297 44 289 48Z"/><path d="M261 102H315" stroke="var(--sr-cream)" stroke-width="1.6" opacity=".65"/></g><circle class="sr-twinkle" cx="245" cy="63" r="1.2"/><path class="sr-twinkle" style="animation-delay:-2s" d="M325 76l.8 3 3 .8-3 .8-.8 3-.8-3-3-.8 3-.8z"/><circle class="sr-twinkle" cx="334" cy="115" r="1"/></svg>`
};

const frames=new Map(), params=new URLSearchParams(location.search);
const single=schemes.includes(params.get('single'))?params.get('single'):null;
for(const key of ['skin','page','viewport','appearance','theme','motion']){
 const input=$('#'+key), value=params.get(key);
 if(value&&[...input.options].some(o=>o.value===value)){state[key]=value;input.value=value;}
}
state.plain=params.get('plain')==='1';
if(single){document.body.dataset.single='true';$$('[data-scheme]').forEach(el=>el.hidden=el.dataset.scheme!==single);}
const media=matchMedia('(prefers-reduced-motion: reduce)');
function sizeFrames(){
 const [w,h]=state.viewport.split('x').map(Number);
 document.documentElement.style.setProperty('--device-width',w+'px');
 document.documentElement.style.setProperty('--device-height',h+'px');
 for(const frame of $$('[data-frame]')){
  const holder=frame.parentElement;if(!holder.clientWidth)continue;
  const zoom=Math.min(1,holder.clientWidth/w);
  Object.assign(frame.style,{width:w+'px',height:h+'px',transform:'scale('+zoom+')'});
  holder.style.height=h*zoom+'px';
 }
}
function makeArt(entry,inset){
 const layer=entry.doc.createElement('div');
 layer.className='sa-art'+(inset?' sa-card-art':'');layer.setAttribute('aria-hidden','true');
 layer.innerHTML=art[state.skin];
 if(inset)layer.querySelector('svg').setAttribute('viewBox','221 22 133 115');
 return layer;
}
function scrollTarget(entry){
 const main=entry.phone.querySelector('.bc-main');
 const mainCanScroll=main&&main.scrollHeight>main.clientHeight+2&&['auto','scroll'].includes(entry.win.getComputedStyle(main).overflowY);
 return mainCanScroll?main:(entry.phone.querySelector('.h-journal-list')||main);
}
function updateLinks(){
 for(const link of $$('[data-single]')){
  const q=new URLSearchParams({...state,single:link.dataset.single,plain:state.plain?'1':'0'});
  link.href='skin-application-svg-history-20261026.html?'+q;
 }
}
function applyScroll(entry){
 const {phone}=entry,main=phone.querySelector('.bc-main');if(!main)return;
 const y=main.scrollTop, layer=phone.querySelector('.sa-art'), rect=phone.getBoundingClientRect();
 const modalOpen=Boolean(entry.demo.state.rModal)||phone.dataset.modal==='true';
 let progress=Math.min(1,y/190), asleep=false;
 if(entry.scheme==='folio'&&entry.demo.state.page==='mine'){
  const fade=Math.max(0,1-y/150);
  if(layer){layer.style.opacity=String(fade);layer.style.transform='translateY('+(-y*.38)+'px)';}
  asleep=fade<=.015;
 }else if(entry.scheme==='folio'){
  const scene=layer?.getBoundingClientRect();
  asleep=!scene||scene.bottom<=rect.top+36||scene.top>=rect.bottom;
 }else{
  const fade=entry.scheme==='paper'?Math.max(0,1-y/290):Math.max(0,1-y/190);
  if(layer){layer.style.opacity=String(fade);layer.style.transform='translateY('+(-y*(entry.scheme==='paper'?.12:.38))+'px)';}
  asleep=fade<=.015;
 }
 if(entry.bed)entry.bed.style.top=Math.max(25,entry.bedTop-y)+'px';
 phone.style.setProperty('--sa-cap-opacity',String(progress));
 const frameRect=entry.frame.getBoundingClientRect();
 phone.dataset.saSleep=String(asleep||modalOpen||state.plain||document.hidden||frameRect.bottom<0||frameRect.top>innerHeight||phone.dataset.saActive!=='true');
 phone.dataset.saMotion=media.matches?'off':state.motion;
 const status=$('[data-status="'+entry.scheme+'"]');
 if(!status)return;
 const local=phone.querySelector('.h-journal-list')?.scrollTop||0;
 const motion=state.plain?'无皮肤':media.matches?'系统减弱动效 · 静态':state.motion==='off'?'静态构图':state.motion==='paused'?'已暂停':state.motion==='reduced'?'仅微光':'正在播放';
 status.textContent=phone.dataset.saActive!=='true'?'已进入交互页面 · 返回继续看皮肤':modalOpen?'弹窗打开 · 背景动效暂停':asleep?'场景已离场 · 动效暂停':local>0&&y===0?'列表局部滚动 · 顶部'+motion:y>0?'整页过渡 · '+motion:'顶部场景 · '+motion;
}
function decorate(entry){
 const {phone,doc}=entry;
 if(entry.decorating)return;entry.decorating=true;
 try{
  phone.dataset.saScheme=entry.scheme;
  phone.dataset.saActive=String(['home','mine'].includes(entry.demo.state.page));
  phone.dataset.saPlain=String(state.plain);
  const p=colors[state.skin][state.appearance];
  for(const [name,value]of Object.entries(p)){phone.style.setProperty('--sr-'+name,value);phone.style.setProperty('--sa-'+name,value);}
  phone.style.setProperty('--sa-line-ink',p.line);
  const main=phone.querySelector('.bc-main');
  const anchor=phone.querySelector('.bc-summary,.u-ledger-summary')||main?.querySelector('.bc-surface');
  if(anchor)anchor.classList.add('sa-anchor');
  let layer=phone.querySelector('.sa-art');
  const profile=entry.scheme==='folio'&&entry.demo.state.page==='mine';
  const inset=entry.scheme==='folio'&&anchor&&!profile;
  if(layer&&(layer.dataset.skin!==state.skin||layer.classList.contains('sa-card-art')!==Boolean(inset)||layer.classList.contains('sa-profile-art')!==profile)){layer.remove();layer=null;}
  if(!layer){layer=makeArt(entry,Boolean(inset)||profile);if(profile){layer.classList.remove('sa-card-art');layer.classList.add('sa-profile-art');}layer.dataset.skin=state.skin;(inset?anchor:phone).prepend(layer);}
  if(entry.scheme==='paper'){
   let bed=phone.querySelector(':scope>.sa-paper-bed');
   if(!bed){bed=doc.createElement('div');bed.className='sa-paper-bed';bed.setAttribute('aria-hidden','true');phone.prepend(bed);}
   const next=phone.querySelector('.bc-stream')||[...(main?.querySelectorAll('.bc-surface')||[])].find(el=>el!==anchor);
   entry.bed=bed;entry.bedTop=next?next.getBoundingClientRect().top-phone.getBoundingClientRect().top+(main?.scrollTop||0):300;
  }
  if(!phone.querySelector(':scope>.sa-scroll-cap')){const cap=doc.createElement('div');cap.className='sa-scroll-cap';cap.setAttribute('aria-hidden','true');phone.prepend(cap);}
  if(entry.scrollMain!==main){
   entry.scrollMain=main;
   main?.addEventListener('scroll',()=>onScroll(entry),{passive:true});
   phone.querySelector('.h-journal-list')?.addEventListener('scroll',()=>onScroll(entry),{passive:true});
  }
  applyScroll(entry);
 }finally{entry.decorating=false;}
}
let syncing=false;
function onScroll(entry){
 applyScroll(entry);
 if(!state.linked||syncing)return;
 const target=scrollTarget(entry);if(!target)return;
 const fraction=target.scrollTop/Math.max(1,target.scrollHeight-target.clientHeight);
 syncing=true;
 for(const other of frames.values())if(other!==entry){const t=scrollTarget(other);if(t)t.scrollTop=fraction*Math.max(0,t.scrollHeight-t.clientHeight);applyScroll(other);}
 requestAnimationFrame(()=>{syncing=false;});
}
function setScroll(value){
 syncing=true;
 for(const entry of frames.values()){const target=scrollTarget(entry);if(target)target.scrollTop=value;applyScroll(entry);}
 $$('[data-scroll]').forEach(button=>button.setAttribute('aria-pressed',String(Number(button.dataset.scroll)===value)));
 requestAnimationFrame(()=>{syncing=false;});
}
function refresh(entry,resetPage=false){
 const d=entry.demo;
 Object.assign(d.settings,{skin:'none',immersive:false,appearance:state.appearance,accent:accents[state.theme],userAccent:accents[state.theme],animation:false});
 if(resetPage){d.state.page=state.page;d.state.rModal=null;}
 const [w,h]=state.viewport.split('x').map(Number);
 if(entry.viewport!==state.viewport){
  const select=entry.doc.querySelector('#bee-preview-size');
  if(select){if(![...select.options].some(o=>o.value===state.viewport))select.add(new entry.win.Option(state.viewport,state.viewport));select.value=state.viewport;select.dispatchEvent(new entry.win.Event('change',{bubbles:true}));}
  entry.viewport=state.viewport;
 }
 d.render();d.freeze?.();
 Object.assign(entry.phone.style,{width:w+'px',height:h+'px',maxHeight:h+'px'});
 decorate(entry);
}
function update(resetPage=false){
 for(const key of ['skin','page','viewport','appearance','theme','motion'])$('#'+key).value=state[key];
 $('#linked').checked=state.linked;
 document.body.dataset.appearance=state.appearance;
 $('#plain').setAttribute('aria-pressed',String(state.plain));
 $('#plain').textContent=state.plain?'返回皮肤效果':'无皮肤对照';
 for(const entry of frames.values())refresh(entry,resetPage);
 updateLinks();sizeFrames();
}
async function initialize(frame,scheme){
 const win=frame.contentWindow,doc=win.document;
 if(!win.beeImmersiveDemo){setTimeout(()=>initialize(frame,scheme),60);return;}
 const links=['skins-refresh-review-art.css','skin-application-svg-history-20261026.css'].map(name=>new Promise(resolve=>{const link=doc.createElement('link');link.rel='stylesheet';link.href=new URL(name,location.href).href;link.onload=resolve;link.onerror=resolve;doc.head.appendChild(link);}));
 await Promise.all(links);
 const entry={frame,scheme,win,doc,demo:win.beeImmersiveDemo,phone:doc.querySelector('#bee-immersive-phone'),viewport:null,decorating:false};
 frames.set(scheme,entry);doc.documentElement.style.background='transparent';doc.body.style.background='transparent';
 entry.observer=new win.MutationObserver(()=>{if(!entry.phone.querySelector('.sa-art'))decorate(entry);else applyScroll(entry);});
 entry.observer.observe(entry.phone,{childList:true});
 refresh(entry,true);sizeFrames();
 window.skinApplicationReady=frames.size===(single?1:3);
}
for(const frame of $$('[data-frame]')){
 const scheme=frame.dataset.frame;if(single&&scheme!==single)continue;
 frame.addEventListener('load',()=>initialize(frame,scheme));
 frame.src='../prototype/demo.html?embed=1&page='+state.page+'&viewport='+state.viewport+'&brand=shown';
}
for(const key of ['skin','page','viewport','appearance','theme'])$('#'+key).addEventListener('change',event=>{state[key]=event.target.value;update(key==='page');});
$('#motion').addEventListener('change',event=>{state.motion=event.target.value;for(const entry of frames.values())applyScroll(entry);updateLinks();});
$('#plain').addEventListener('click',()=>{state.plain=!state.plain;update();});
$('#linked').addEventListener('change',event=>{state.linked=event.target.checked;});
$$('[data-scroll]').forEach(button=>button.addEventListener('click',()=>setScroll(Number(button.dataset.scroll))));
window.addEventListener('resize',()=>{sizeFrames();for(const entry of frames.values())applyScroll(entry);});
window.addEventListener('scroll',()=>{for(const entry of frames.values())applyScroll(entry);},{passive:true});
document.addEventListener('visibilitychange',()=>{for(const entry of frames.values())applyScroll(entry);});
media.addEventListener('change',()=>{for(const entry of frames.values())applyScroll(entry);});
window.skinApplicationReview={state,frames,schemes,colors,decorate,update,setScroll,scrollTarget};
update();
})();
