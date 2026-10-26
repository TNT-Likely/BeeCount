  const qPreview={width:398,height:844,scale:1};
  const qParams=new URLSearchParams(location.search),qSize=qParams.get('viewport');
  if(['398x844','398x900','375x667','320x568'].includes(qSize)){[qPreview.width,qPreview.height]=qSize.split('x').map(Number);if(qParams.get('page')==='editor')state.page='editor';}

  const qControls=document.createElement('div');qControls.style.display='contents';
  qControls.innerHTML='<label class="form-label">预览尺寸<select class="form-select" id="bee-preview-size"><option value="398x844">标准 · 398 × 844</option><option value="398x900">长屏 · 398 × 900</option><option value="375x667">短屏 · 375 × 667</option><option value="320x568">小屏 · 320 × 568</option></select></label><label class="form-label">文字大小<select class="form-select" id="bee-preview-scale"><option value="1">100%</option><option value="1.4">140%</option></select></label>';
  root.querySelector('.bc-preview-controls').appendChild(qControls);
  document.getElementById('bee-preview-size').addEventListener('change',e=>{const [w,h]=e.target.value.split('x').map(Number);qPreview.width=w;qPreview.height=h;render();});
  document.getElementById('bee-preview-scale').addEventListener('change',e=>{qPreview.scale=Number(e.target.value);render();});
  function qAfterRender(){
    const compact=state.page==='editor'&&qPreview.height<720;
    phone.dataset.qSize=qPreview.width+'x'+qPreview.height;phone.dataset.qCompact=String(compact);phone.dataset.qNarrow=String(qPreview.width<=340);
    phone.style.setProperty('--q-width',qPreview.width+'px');phone.style.setProperty('--q-height',qPreview.height+'px');phone.style.setProperty('--q-scale',qPreview.scale);
    if(qPreview.width===398&&qPreview.height===844){for(const prop of ['width','height','min-height','max-height'])phone.style.removeProperty(prop);}else{phone.style.setProperty('width',qPreview.width+'px','important');phone.style.setProperty('height',qPreview.height+'px','important');phone.style.setProperty('min-height',qPreview.height+'px','important');phone.style.setProperty('max-height',qPreview.height+'px','important');}
    document.getElementById('bee-preview-size').value=qPreview.width+'x'+qPreview.height;document.getElementById('bee-preview-scale').value=String(qPreview.scale);
    phone.dataset.zEditor=String(zPinned());
    if(zPinned()){zEditorLayout();return;}
    if(!compact)return;
    const main=phone.querySelector('.bc-main'),head=main.querySelector('.p-editor-head'),amount=main.querySelector('.p-amount-card'),category=main.querySelector('.p-category-card'),keypad=main.querySelector('.p-keypad'),footer=main.querySelector('.p-calc-footer'),error=main.querySelector('[data-error]');
    if(!head||!amount||!category||!keypad||!footer)return;
    const scroll=document.createElement('div');scroll.className='q-category-scroll';scroll.setAttribute('aria-label','分类列表，可滚动');scroll.appendChild(category);
    const bar=document.createElement('div');bar.className='q-quickbar';bar.setAttribute('aria-label','记账快捷操作');
    bar.innerHTML=[['q-note','pencil-line','备注','编辑备注'],['record-account','wallet','账户','选择账户'],['record-date','calendar-days',String(state.month).padStart(2,'0')+'.'+String(state.day).padStart(2,'0'),'选择日期'],['record-tag','tag','标签','选择标签'],['record-attachment','image-plus','附件','添加附件'],['p-key:clear','delete','清空','清空金额']].map(([a,i,n,l])=>btn(a,icon(i)+'<span>'+esc(n)+'</span>',l,'')).join('');
    main.replaceChildren(head,amount,scroll,bar,keypad,...(error?[error]:[]),footer);
    if(globalThis.lucide)globalThis.lucide.createIcons({attrs:{width:20,height:20}});
  }
  window.beeResponsivePreview={set(options={}){Object.assign(qPreview,options);render();},get value(){return {...qPreview};}};

  rSpecs['compact-note']={title:'账单备注',host:'editor',kind:'dialog'};
  function qNoteBody(){return `<label class="bc-form-label">备注<textarea class="p-note-area" data-q-note aria-label="编辑账单备注" rows="4" maxlength="120">${esc(state.note)}</textarea></label><div class="bc-inline-actions" style="margin-top:14px">${btn('r-close','取消','取消修改备注','bc-secondary')}${btn('q-note-save','确定','确认备注','bc-primary')}</div>`;}
  root.addEventListener('click',e=>{const el=e.target.closest('[data-action]');if(!el||!el.dataset.action.startsWith('q-'))return;e.preventDefault();e.stopImmediatePropagation();if(el.dataset.action==='q-note')rOpenModal('compact-note');else if(el.dataset.action==='q-note-save'){state.note=phone.querySelector('[data-q-note]').value;rDismiss();render();}},true);
