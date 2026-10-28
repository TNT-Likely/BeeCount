// Same four-column / two-cell overflow rule as RecordingSubcategoryGrid.
(()=>{const observer=new ResizeObserver(entries=>entries.forEach(e=>fit(e.target)));
function fit(grid){if(!grid.isConnected||!grid.clientWidth)return;const style=getComputedStyle(grid),cell=(grid.clientWidth-parseFloat(style.paddingLeft)-parseFloat(style.paddingRight)-15)/4,ctx=document.createElement('canvas').getContext('2d');for(const button of grid.children){const label=button.querySelector('span')||button,cs=getComputedStyle(label);ctx.font='600 '+cs.fontSize+' '+cs.fontFamily;const width=ctx.measureText(label.textContent).width+33;button.style.gridColumn='span '+(width>cell?2:1);}}
globalThis.beeFitSubcategories=()=>{observer.disconnect();document.querySelectorAll('.p-subcategories,[data-adaptive-subcategories]').forEach(grid=>{grid.setAttribute('data-adaptive-subcategories','');fit(grid);observer.observe(grid);});};
requestAnimationFrame(globalThis.beeFitSubcategories);
document.addEventListener('click',e=>{const b=e.target.closest('[data-adaptive-example]');if(!b)return;b.parentElement.querySelectorAll('button').forEach(x=>x.setAttribute('aria-pressed',String(x===b)));});
})();
