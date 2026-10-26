  // Review-only layout. Production Flutter stays unchanged until approved.
  const zReview=new URLSearchParams(location.search).get('editorLayout')==='pinned';
  function zPinned(){return zReview&&state.page==='editor'&&state.recordType!=='transfer';}
  Object.assign(state,{zNoteExpanded:false});
  let zCategoryMemory=null;
  function zRememberCategoryScroll(){
    const scroll=phone.querySelector('.z-category-scroll');
    if(scroll)zCategoryMemory={top:scroll.scrollTop,expanded:scroll.dataset.expanded,type:scroll.dataset.type};
    else if(state.page!=='editor')zCategoryMemory=null;
  }
  function zConversion(){
    if(state.fRecordCurrency===state.fBaseCurrency)return '<span class="z-formula">支持 + − × ÷ 四则运算</span>';
    if(state.vQuoteStatus==='loading')return '<span class="z-formula">正在获取折算金额…</span>';
    const calc=pCalcState(),rate=Number(state.fRecordRate);
    if(!calc.valid)return `<span class="z-formula">${esc(calc.message)}</span>`;
    if(!(rate>0))return btn('v-rate',`${icon('circle-alert')}汇率暂不可用 · 手动填写${icon('chevron-right')}`,'手动填写本笔汇率','z-rate-error');
    return btn('v-rate',`<span>折合 ${esc(state.fBaseCurrency)}</span><b>≈ ${vSymbol(state.fBaseCurrency)}${money(vRound(calc.value*rate))}</b>${icon('chevron-right')}`,'查看或编辑本笔汇率','z-conversion');
  }
  function zEditorLayout(){
    phone.dataset.zEditor=String(zPinned());if(!zPinned())return;
    const main=phone.querySelector('.bc-main'),head=main.querySelector('.p-editor-head'),amount=main.querySelector('.p-amount-card'),category=main.querySelector('.p-category-card'),keypad=main.querySelector('.p-keypad'),footer=main.querySelector('.p-calc-footer'),error=main.querySelector('[data-error]');
    if(!head||!amount||!category||!keypad||!footer)return;
    if(state.fSeedMode!=='none')category.innerHTML=gOriginalCategoryGrid(pAllCategories.length);
    const chip=amount.querySelector('.v-currency-chip');if(chip)chip.innerHTML=`<b>${esc(state.fRecordCurrency)}</b>${icon('chevron-down')}`;
    amount.querySelector('.p-expression')?.remove();amount.querySelector('.v-editor-conversion')?.remove();
    const summary=document.createElement('div');summary.className='z-summary';summary.setAttribute('data-z-summary','');summary.innerHTML=zConversion();amount.appendChild(summary);
    const scroll=document.createElement('div');scroll.className='q-category-scroll z-category-scroll';scroll.setAttribute('aria-label','分类列表，可滚动');scroll.appendChild(category);scroll.dataset.expanded=state.expandedCategory||'';scroll.dataset.type=state.recordType;
    const meta=document.createElement('section');meta.className='z-meta';meta.setAttribute('aria-label','固定记账信息');
    const tags=state.recordTags.length?state.recordTags:state.tag?[state.tag]:[];
    const compact=qPreview.height<720,expanded=!compact||state.zNoteExpanded;
    const date=btn('record-date',`${icon('calendar-days')}<span>${qPreview.width<=340?`${state.month}.${String(state.day).padStart(2,'0')}`:`${state.month}月${state.day}日`}</span>`,'选择日期与时间','z-date z-date-reference');
    const attachment=btn('record-attachment',icon('image-plus'),'添加附件','z-attachment-reference');
    const tagChoice=btn('record-tag',`${tags.length?tag(tags[0]):icon('tag')+'<span>标签</span>'}${tags.length>1?`<small>+${tags.length-1}</small>`:''}`,'选择标签','z-tag-reference');
    const account=btn('record-account',`${icon('wallet')}<span>${esc(state.recordAccount||'选择账户')}</span>`,'选择账户','z-account');
    const noteToggle=compact?btn('z-note-toggle',`${icon(state.zNoteExpanded?'chevron-up':'pencil-line')}${state.note?'<i class="z-note-dot" aria-hidden="true"></i>':''}`,state.zNoteExpanded?'收起备注':'展开备注，直接编辑','z-note-toggle'):'';
    meta.dataset.noteExpanded=String(expanded);
    meta.innerHTML=expanded?`<div class="z-note-top"><label class="z-note-field">${icon('pencil-line')}<input data-z-note value="${esc(state.note)}" placeholder="添加备注" aria-label="直接编辑账单备注" maxlength="120" autocomplete="off"></label>${noteToggle}${attachment}</div><div class="z-reference-row">${account}${date}${tagChoice}</div>`:`<div class="z-reference-row z-reference-folded">${noteToggle}${account}${date}${tagChoice}${attachment}</div>`;
    if(qPreview.height<720){
      amount.classList.add('z-amount-compact');
      const header=amount.querySelector('.bc-between'),line=amount.querySelector('.p-amount-line'),ledger=header.querySelector('.bc-mini-ledger'),row=document.createElement('div');row.className='z-compact-amount-row';
      line.querySelector('span')?.remove();ledger.setAttribute('aria-label','切换账本：'+state.ledger);ledger.innerHTML=qPreview.width<=340?icon('book-open'):esc(state.ledger)+icon('chevron-down');row.append(chip,line,ledger);header.remove();amount.prepend(row);if(state.fRecordCurrency===state.fBaseCurrency)summary.hidden=true;
    }
    main.replaceChildren(head,amount,scroll,meta,keypad,...(error?[error]:[]),footer);
    globalThis.lucide?.createIcons({attrs:{width:20,height:20}});
    scroll.scrollTop=zCategoryMemory?.type===state.recordType?zCategoryMemory.top:0;
    if(state.expandedCategory&&zCategoryMemory?.expanded!==state.expandedCategory){
      requestAnimationFrame(()=>{if(!scroll.isConnected)return;const child=scroll.querySelector('.p-subcategories');if(!child)return;const visible=scroll.getBoundingClientRect(),box=child.getBoundingClientRect();if(box.bottom>visible.bottom)scroll.scrollTop+=Math.min(box.bottom-visible.bottom,box.top-visible.top);});
    }
  }
  root.addEventListener('input',e=>{if(e.target.matches('[data-z-note]'))state.note=e.target.value;if(zPinned()&&e.target.dataset.pField==='expression'){const s=phone.querySelector('[data-z-summary]');if(s){s.innerHTML=zConversion();globalThis.lucide?.createIcons({attrs:{width:16,height:16}});}}});

  root.addEventListener('click',e=>{if(e.target.closest('[data-action="z-note-toggle"]')){e.preventDefault();e.stopImmediatePropagation();state.zNoteExpanded=!state.zNoteExpanded;render();if(state.zNoteExpanded)phone.querySelector('[data-z-note]')?.focus({preventScroll:true});}},true);
