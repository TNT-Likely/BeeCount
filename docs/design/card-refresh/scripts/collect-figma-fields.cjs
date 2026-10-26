const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..'),scenes=JSON.parse(fs.readFileSync(path.join(root,'qa/figma-source.json'),'utf8')).screens;
(async()=>{const b=await chromium.launch({channel:'chrome',headless:true}),p=await b.newPage({viewport:{width:1440,height:1800}}),out=[];
for(const s of [...scenes,{slug:'components-light'},{slug:'components-dark'}]){await p.goto(pathToFileURL(path.join(root,'figma/html',s.slug+'.html')).href);await p.evaluate(()=>document.fonts.ready);const fields=await p.evaluate(()=>{
 const root=document.querySelector('.spec')||document.querySelector('.bc-phone'),base=root.getBoundingClientRect(),fields=[];
 for(const e of root.querySelectorAll('input,textarea,select')){
  if(e.closest('[inert]')||['checkbox','radio','range','color','hidden'].includes(e.type))continue;
  const r=e.getBoundingClientRect(),c=getComputedStyle(e);if(!r.width||!r.height||r.bottom<base.top||r.top>base.bottom||c.display==='none'||c.visibility==='hidden')continue;
  let clipped=false;for(let a=e.parentElement;a&&a!==root;a=a.parentElement){const ac=getComputedStyle(a),ar=a.getBoundingClientRect();if(['hidden','auto','scroll'].includes(ac.overflowY)&&(r.top>=ar.bottom||r.bottom<=ar.top))clipped=true;}if(clipped)continue;
  const content=e.tagName==='SELECT'?e.selectedOptions[0]?.textContent:e.type==='password'&&e.value?'••••••':e.type==='file'?'选择文件':e.value||e.getAttribute('placeholder');if(!content)continue;
  const color=!e.value&&e.hasAttribute('placeholder')?getComputedStyle(e,'::placeholder').color:c.color;const m=color.match(/[\d.]+/g);const hex='#'+m.slice(0,3).map(n=>Math.round(+n).toString(16).padStart(2,'0')).join('');
  const size=parseFloat(c.fontSize),line=parseFloat(c.lineHeight)||size*1.5,left=parseFloat(c.paddingLeft)||0,right=parseFloat(c.paddingRight)||0;
  fields.push({type:'text',name:'字段 · '+(e.getAttribute('aria-label')||content).slice(0,30),content,fontFamily:'Noto Sans SC',fontSize:size,weight:+c.fontWeight>=550?'Bold':'Regular',lineHeight:line,color:hex,width:Math.max(1,r.width-left-right+2),height:Math.max(line,r.height),position:{type:'absolute',x:r.left-base.left+left,y:r.top-base.top+(e.tagName==='TEXTAREA'?(parseFloat(c.paddingTop)||0):Math.max(0,(r.height-line)/2))}});
 }
 return fields;
});if(fields.length)out.push({slug:s.slug,group:s.group,title:s.title,fields});}
fs.writeFileSync(path.join(root,'qa/figma-fields.json'),JSON.stringify(out,null,2));await b.close();console.log(JSON.stringify({scenes:out.length,fields:out.reduce((n,s)=>n+s.fields.length,0)}));})().catch(e=>{console.error(e);process.exit(1)});
