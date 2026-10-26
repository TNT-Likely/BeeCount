// Normalize only Figma import copies; leave the canonical demo unchanged.
module.exports=el=>{
  const elements=[el,...el.querySelectorAll('*')];
  for(const e of elements){
   const c=getComputedStyle(e),sides=['Top','Right','Bottom','Left'];
   if(e.scrollTop)e.setAttribute('data-snapshot-scroll',String(e.scrollTop));
   const side=sides.find(s=>parseFloat(c['border'+s+'Width'])>0&&c['border'+s+'Style']!=='none');
   if(side)e.style.borderColor=c['border'+side+'Color'];
   if(['auto','scroll'].includes(c.overflowY)||['auto','scroll'].includes(c.overflowX))e.style.overflow='hidden';
   // The desktop bridge exposes Regular/Bold consistently for this family.
   // Keep the original weight in the canonical demo; normalize only the import.
   if(e.tagName.toLowerCase()!=='svg'&&!e.closest('svg'))e.style.fontWeight=Number(c.fontWeight)>=550?'700':'400';
  }
  for(const e of elements){
   if(e.closest('svg'))continue;
   for(const side of ['before','after']){
    const c=getComputedStyle(e,'::'+side);
    if(c.content==='none'||c.content==='normal'||c.display==='none')continue;
    const part=document.createElement('span');part.dataset.name='Decorative '+side;
    for(const prop of c)if(!prop.startsWith('--'))part.style.setProperty(prop,c.getPropertyValue(prop));
    part.style.content='normal';part.style.pointerEvents='none';part.setAttribute('aria-hidden','true');
    part.textContent=c.content.startsWith('"')?c.content.slice(1,-1):c.content.startsWith('counter(')?String([...e.parentElement.children].indexOf(e)+1):'';
    e.setAttribute('data-figma-'+side,'');if(side==='before')e.prepend(part);else e.append(part);
   }
  }
  for(const e of [...el.querySelectorAll('input,textarea,select')]){
   if(['checkbox','radio','range','color','hidden'].includes(e.type))continue;
   const c=getComputedStyle(e),r=e.getBoundingClientRect(),part=document.createElement('div');
   for(const prop of c)if(!prop.startsWith('--'))part.style.setProperty(prop,c.getPropertyValue(prop));
   part.className=e.className;part.dataset.name=e.getAttribute('aria-label')||'表单字段';
   part.style.width=r.width+'px';part.style.height=r.height+'px';
   part.style.whiteSpace=e.tagName==='TEXTAREA'?'pre-wrap':'nowrap';
   part.textContent=e.tagName==='SELECT'?e.selectedOptions[0]?.textContent:e.type==='password'&&e.value?'••••••':e.type==='file'?'选择文件':e.value||e.getAttribute('placeholder')||'';
   if(!e.value&&e.hasAttribute('placeholder'))part.style.color=getComputedStyle(e,'::placeholder').color;
   e.replaceWith(part);
  }
  return el.outerHTML;
 };
