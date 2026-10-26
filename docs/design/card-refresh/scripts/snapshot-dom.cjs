// Snapshot browser DOM for editable Figma import. Only painter canvases become
// discrete bitmap illustrations; text, controls, cards and SVG icons stay DOM.
module.exports=function(element){
  const copy=element.cloneNode(true);
  const originals=[...element.querySelectorAll('*')],clones=[...copy.querySelectorAll('*')];
  originals.forEach((e,i)=>{
    const c=clones[i];
    if(e instanceof HTMLCanvasElement){const img=document.createElement('img'),r=e.getBoundingClientRect();img.src=e.toDataURL();img.className=e.className;img.style.cssText=e.style.cssText;img.style.width=r.width+'px';img.style.height=r.height+'px';img.alt='动态皮肤画面';c.replaceWith(img);}
    if(e instanceof HTMLInputElement){c.setAttribute('value',e.value);if(e.checked)c.setAttribute('checked','');else c.removeAttribute('checked');}
    if(e instanceof HTMLTextAreaElement)c.textContent=e.value;
    if(e instanceof HTMLSelectElement)for(let j=0;j<c.options.length;j++)if(e.options[j].selected)c.options[j].setAttribute('selected','');else c.options[j].removeAttribute('selected');
    if(e.scrollTop)c.setAttribute('data-snapshot-scroll',String(e.scrollTop));
  });
  copy.removeAttribute('id');
  return copy.outerHTML;
};
