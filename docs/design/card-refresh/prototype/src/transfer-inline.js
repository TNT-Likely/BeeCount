  const ti93Text=__TRANSFER_INLINE_TEXTS__;
  const ti93Fixtures=__TRANSFER_INLINE_FIXTURES__;
  const ti93Keys=new Set(ti93Fixtures.scenes.map(scene=>scene.key));
  Object.assign(state,{ti93Scene:'',ti93Draft:null,ti93Rows:[],ti93NextId:1,ti93Event:''});
  function ti93Copy(value){return JSON.parse(JSON.stringify(value));}
  function ti93Start(key){
    const scene=ti93Fixtures.scenes.find(scene=>scene.key===key)||ti93Fixtures.scenes[0];
    state.ti93Scene=scene.key;state.ti93Draft=ti93Copy(scene.draft);state.ti93Rows=[];state.ti93Event='';state.ti93NextId=1;
    if(['edit','copy'].includes(state.ti93Draft.mode))state.ti93Rows.push({id:'qa-source',from:state.ti93Draft.from,to:state.ti93Draft.to,currencyCode:state.ti93Draft.originalCurrency,amount:Number(state.ti93Draft.expression),nativeAmount:Number(state.ti93Draft.expression)*state.ti93Draft.rateOverride,note:state.ti93Draft.note,date:state.ti93Draft.date,tags:[...state.ti93Draft.tags]});
  }
  function ti93Account(id){return (state.ti93Draft?.externalAccounts||ti93Fixtures.accounts).find(account=>account.id===id)||null;}
  function ti93OriginalPair(){const d=state.ti93Draft;return d.mode==='edit'&&d.from===d.originalFrom&&d.to===d.originalTo;}
  function ti93Currency(){const d=state.ti93Draft;return ti93OriginalPair()?(d.originalCurrency||ti93Account(d.from)?.currency||'CNY'):(ti93Account(d.from)?.currency||'CNY');}
  function ti93Candidates(from){
    const d=state.ti93Draft;if(d.emptyAccounts)return [];
    const all=d.externalAccounts||ti93Fixtures.accounts;
    const eligible=all.filter(account=>(!account.hidden||d.pins.includes(account.id))&&(account.tradable||(d.mode==='edit'&&d.pins.includes(account.id))));
    if(from)return eligible;
    const source=ti93Account(d.from);
    return eligible.filter(account=>account.id!==d.from&&(!source||account.currency===source.currency||(ti93OriginalPair()&&account.id===d.originalTo)));
  }
  function ti93SetAccount(from,id){
    const d=state.ti93Draft,oldCurrency=ti93Currency();
    if(!ti93Candidates(from).some(account=>account.id===id))return false;
    if(from){d.from=id;const source=ti93Account(id),target=ti93Account(d.to);if(d.to===id||(!ti93OriginalPair()&&target&&source.currency!==target.currency))d.to=null;}
    else d.to=id;
    if(oldCurrency!==ti93Currency())d.rateOverride=null;
    d.error='';return true;
  }
  function ti93Amount(){try{const value=typeof pCalculate==='function'?pCalculate(state.ti93Draft.expression):Number(state.ti93Draft.expression);return Number.isFinite(value)&&Math.abs(value)>0?Math.abs(value):null;}catch(_){return null;}}
  function ti93Rate(){const d=state.ti93Draft,currency=ti93Currency();if(currency==='CNY')return 1;const raw=d.rateOverride!==null?d.rateOverride:(d.missingQuotes||[]).includes(currency)?null:ti93Fixtures.rates[currency];const value=Number(raw);return raw!==null&&Number.isFinite(value)&&Math.abs(value)>0?Math.abs(value):null;}
  function ti93PairValid(){const d=state.ti93Draft,from=ti93Account(d.from),to=ti93Account(d.to);return !!from&&!!to&&from.id!==to.id&&(from.currency===to.currency||ti93OriginalPair());}
  function ti93CanSubmit(){return !state.ti93Draft.busy&&!state.ti93Draft.saved&&ti93PairValid()&&ti93Amount()!==null;}
  function ti93Save(){
    const d=state.ti93Draft;if(!ti93CanSubmit())return false;
    const amount=ti93Amount(),rate=ti93Rate(),nativeAmount=rate===null?null:amount*rate;
    if(nativeAmount===null||!Number.isFinite(nativeAmount)||nativeAmount<=0){d.error=ti93Text.txRateMissingHint;return false;}
    const id=d.retryId||d.editId||'qa-created-'+state.ti93NextId++,row={id,from:d.from,to:d.to,type:'transfer',currencyCode:ti93Currency(),amount,nativeAmount,note:d.note,date:d.date,tags:[...d.tags],attachments:ti93Copy(d.attachments),excludeFromStats:!!d.excludeFromStats,excludeFromBudget:!!d.excludeFromBudget};
    const at=state.ti93Rows.findIndex(item=>item.id===id);if(at<0)state.ti93Rows.push(row);else state.ti93Rows[at]=row;
    if(d.failNextMetadata){d.failNextMetadata=false;d.retryId=id;d.error=ti93Text.v4RecordingSaveFailed;return false;}
    d.error='';d.saved=true;state.ti93Event='已保存局部合成转账：'+row.currencyCode+' '+amount.toFixed(2)+' · 折合 CNY '+nativeAmount.toFixed(2);return true;
  }
  function ti93Money(value){return Number(value).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});}
  function ti93Button(action,body,label,classes='',disabled=false){return `<button class="${classes}" data-ti93-action="${action}" aria-label="${esc(label)}" ${disabled?'disabled':''}>${body}</button>`;}
  function ti93Render(){
    const d=state.ti93Draft,t=ti93Text,from=ti93Account(d.from),to=ti93Account(d.to),currency=ti93Currency(),amount=ti93Amount(),rate=ti93Rate(),compact=qPreview.height<720,expanded=!compact||d.noteExpanded;
    const accountRow=(isFrom,account)=>ti93Button('account:'+(isFrom?'from':'to'),`<span class="ti93-account-icon">${account?bcAccountVisual(account,24):icon('wallet')}</span><span class="ti93-account-copy"><b>${esc(account?.name||t.transferSelectAccount)}</b><small>${esc((isFrom?t.transferFromAccount:t.transferToAccount)+(account?' · '+(account.hidden?t.accountHiddenTag:account.currency):''))}</small></span>${icon('chevron-right')}`,isFrom?t.transferFromAccount:t.transferToAccount,'ti93-account-row',d.busy);
    const conversion=currency==='CNY'?`<span class="ti93-formula">${esc(t.v4RecordingCalculationHint)}</span>`:ti93Button('rate',`<span>${esc(t.v4RecordingConvertedLabel.replace('{currency}','CNY'))}</span><b>${amount!==null&&rate!==null?'≈ ¥'+ti93Money(amount*rate):esc(t.txRateMissingHint)}</b>${icon('chevron-right')}`,t.txRateLabel,'ti93-conversion '+(rate===null?'ti93-error':''),d.busy);
    const description=d.mode==='edit'&&ti93OriginalPair()&&from?.currency!==to?.currency?'历史跨币种原账户对可继续编辑；修改账户后仅允许同币种':d.mode==='copy'&&from?.currency!==to?.currency?'复制会创建新记录，请把转入账户改为同币种后保存':!ti93PairValid()&&from&&to?t.transferDifferentCurrencyError:'';
    const eligible=ti93Candidates(true),noAccounts=eligible.length===0,needsPair=!ti93PairValid()&&new Set(eligible.map(account=>account.currency)).size===eligible.length;
    return `<section class="ti93-shell ${compact?'ti93-compact':''}" data-ti93-note-expanded="${expanded}" aria-label="${esc(t.transferTitle)}同屏编辑"><header class="ti93-header">${ti93Button('back',icon('chevron-left'),t.commonBack)}<div class="ti93-type-tabs">${[['expense',t.categoryExpense],['income',t.categoryIncome],['transfer',t.transferTitle]].map(([type,label])=>ti93Button('type:'+type,esc(label),label,type==='transfer'?'selected':'',d.busy)).join('')}</div><span class="ti93-header-spacer"></span></header>
      <article class="ti93-amount-card"><div class="ti93-currency-row"><b>${currency}</b><span>QA ${esc(state.ledger||'日常生活')} · CNY</span></div><label class="ti93-amount-line"><span>${currency==='USD'?'US$':currency==='EUR'?'€':'¥'}</span><input data-ti93-expression value="${esc(d.expression)}" inputmode="decimal" aria-label="${esc(t.transferTitle)}金额" ${d.busy?'disabled':''}></label><div class="ti93-summary">${conversion}</div></article>
      <div class="ti93-account-region" role="region" aria-label="${esc(t.transferSelectAccount)}">${noAccounts?`<article class="ti93-account-empty">${icon('wallet')}<b>${esc(t.widgetNoAccounts)}</b>${ti93Button('add-account',esc(t.accountAddButton),t.accountAddButton,'ti93-add-account',d.busy)}</article>`:`<article class="ti93-pair">${accountRow(true,from)}<div class="ti93-pair-divider">${icon('arrow-down')}<span></span></div>${accountRow(false,to)}${needsPair?ti93Button('add-account',esc(t.accountAddButton),t.accountAddButton,'ti93-add-account ti93-pair-add',d.busy):''}</article>`}${description?`<p class="ti93-description">${esc(description)}</p>`:''}${d.attachments.length?`<div class="ti93-attachment-strip">${d.attachments.map((file,i)=>ti93Button('attachment:'+i,`${icon('image')}<span>${esc(file.name)}</span>`,file.name,'ti93-attachment-tile',d.busy)).join('')}</div>`:''}${d.error?`<p class="ti93-error ti93-description" role="alert">${esc(d.error)}</p>`:''}${state.ti93Event?`<p class="ti93-description" role="status">${esc(state.ti93Event)}</p>`:''}</div>
      <article class="ti93-metadata">${expanded?`<div class="ti93-note-line">${ti93Button('note-history',icon('pencil-line'),t.appearanceNoteHistory)}<input data-ti93-note value="${esc(d.note)}" placeholder="${esc(t.commonNoteHint)}" aria-label="${esc(t.importFieldNote)}" ${d.busy?'disabled':''}>${compact?ti93Button('note-toggle',icon('chevron-up'),t.commonNoteHint,'',d.busy):''}${ti93Button('attachments',`${icon('image-plus')}${d.attachments.length?'<sup>'+d.attachments.length+'</sup>':''}`,t.attachmentAdd,'',d.busy)}</div>`:''}<div class="ti93-reference-row">${!expanded?ti93Button('note-toggle',icon('pencil-line'),t.commonNoteHint,'',d.busy):''}${ti93Button('date',`${icon('calendar-days')}<span>${esc(d.date.slice(5,10).replace('-','.'))}</span>`,t.importFieldDate,'ti93-date',d.busy)}${ti93Button('tags',d.tags.length?`<span class="ti93-tag">${esc(d.tags[0])}</span>${d.tags.length>1?'<small>+'+(d.tags.length-1)+'</small>':''}`:icon('tag'),t.tagSelectTitle,'ti93-tags',d.busy)}${!expanded?ti93Button('attachments',`${icon('image-plus')}${d.attachments.length?'<sup>'+d.attachments.length+'</sup>':''}`,t.attachmentAdd,'',d.busy):''}</div></article>
      <footer class="ti93-dock"><div class="ti93-keypad" aria-label="计算器键盘">${['7','8','9','÷','4','5','6','×','1','2','3','−','.','0','backspace','+'].map(key=>ti93Button('key:'+key,key==='backspace'?icon('delete'):key,key==='backspace'?t.commonDelete:key,/[+−×÷]/.test(key)?'ti93-op':'',d.busy)).join('')}</div><div class="ti93-footer-actions">${ti93Button('clear',esc(t.commonClear||'清空'),'清空金额','',d.busy)}${ti93Button('equals','=','计算结果','ti93-equals',d.busy)}${ti93Button('save',`${d.busy?icon('loader-circle'):icon('check')}<span>${esc(ti93PairValid()?t.commonSave:t.transferSelectAccount)}</span>`,t.commonSave,'ti93-save',!ti93CanSubmit())}</div></footer></section>`;
  }
  function ti93Dialog(title,body,onConfirm,{confirmLabel=ti93Text.commonConfirm,confirm=true}={}){
    const dialog=document.createElement('dialog');dialog.className='ti93-dialog';dialog.setAttribute('aria-label',title);dialog.innerHTML=`<header><b>${esc(title)}</b><button data-ti93-close aria-label="${esc(ti93Text.commonClose)}">${icon('x')}</button></header><div class="ti93-dialog-body">${body}</div><footer><button data-ti93-close>${esc(ti93Text.commonCancel)}</button>${confirm?`<button class="ti93-primary" data-ti93-confirm>${esc(confirmLabel)}</button>`:''}</footer>`;
    phone.appendChild(dialog);dialog.showModal();globalThis.lucide?.createIcons();
    const close=()=>{dialog.close();dialog.remove();};dialog.addEventListener('click',event=>{if(event.target.closest('[data-ti93-close]'))close();if(event.target.closest('[data-ti93-confirm]')&&onConfirm?.(dialog)!==false)close();});dialog.addEventListener('cancel',close);return dialog;
  }
  function ti93OpenAccounts(from){
    const choices=ti93Candidates(from),selected=from?state.ti93Draft.from:state.ti93Draft.to;
    const dialog=ti93Dialog(from?ti93Text.transferFromAccount:ti93Text.transferToAccount,`<input data-ti93-search placeholder="${esc(ti93Text.transferSelectAccount)}" aria-label="${esc(ti93Text.transferSelectAccount)}"><div class="ti93-account-choices">${choices.map(account=>`<button data-ti93-choice="${account.id}" aria-pressed="${account.id===selected}">${bcAccountVisual(account,24)}<b>${esc(account.name)}</b><small>${esc(account.currency+(account.hidden?' · '+ti93Text.accountHiddenTag:''))}</small></button>`).join('')||`<p>${esc(ti93Text.accountsEmptyMessage)}</p>`}</div>`,null,{confirm:false});
    dialog.addEventListener('input',event=>{if(event.target.matches('[data-ti93-search]'))for(const choice of dialog.querySelectorAll('[data-ti93-choice]'))choice.hidden=!choice.textContent.toLowerCase().includes(event.target.value.toLowerCase());});
    dialog.addEventListener('click',event=>{const choice=event.target.closest('[data-ti93-choice]');if(choice&&ti93SetAccount(from,choice.dataset.ti93Choice)){dialog.close();dialog.remove();render();}});
  }
  function ti93OpenRate(){
    const t=ti93Text,dialog=ti93Dialog(t.txRateLabel,`<label>1 ${ti93Currency()} = <input data-ti93-rate inputmode="decimal" aria-label="${esc(t.txRateLabel)}" value="${ti93Rate()??''}"> CNY</label><p data-ti93-rate-error class="ti93-error" role="alert"></p>`,node=>{const rate=Number(node.querySelector('[data-ti93-rate]').value);if(!Number.isFinite(rate)||rate<=0)return false;state.ti93Draft.rateOverride=rate;state.ti93Draft.error='';render();});
    const input=dialog.querySelector('[data-ti93-rate]'),validate=()=>{const rate=Number(input.value),valid=Number.isFinite(rate)&&rate>0;dialog.querySelector('[data-ti93-confirm]').disabled=!valid;dialog.querySelector('[data-ti93-rate-error]').textContent=valid?'':t.v4RateInvalid;};input.addEventListener('input',validate);validate();
  }
  function ti93Key(key){
    const d=state.ti93Draft;if(d.busy)return;
    let raw=String(d.expression||'0');if(key==='backspace')raw=raw.slice(0,-1)||'0';else if(/[+−×÷]/.test(key))raw=raw.replace(/[+−×÷]$/,'')+key;else if(key==='.'){if(!raw.split(/[+−×÷]/).at(-1).includes('.'))raw+='.';}else raw=raw==='0'?key:raw+key;d.expression=raw;d.error='';
  }
  function ti93Back(){const previous=state.history?.pop();state.page=previous?.page||'home';state.leaf=previous?.leaf;if(previous?.details)Object.assign(state,previous.details);state.ti93Scene='';render();}
  function ti93OpenTags(){
    const selected=new Set(state.ti93Draft.tags),options=[...new Set([...selected,'QA 旅行','QA 家庭','QA 外币'])];
    const dialog=ti93Dialog(ti93Text.tagSelectTitle,`<div class="ti93-tag-options">${options.map(tag=>`<button data-ti93-tag="${esc(tag)}" aria-pressed="${selected.has(tag)}">${esc(tag)}</button>`).join('')}</div>`,()=>{state.ti93Draft.tags=[...selected];render();});
    dialog.addEventListener('click',event=>{const button=event.target.closest('[data-ti93-tag]');if(button){const value=button.dataset.ti93Tag;selected.has(value)?selected.delete(value):selected.add(value);button.setAttribute('aria-pressed',selected.has(value));}});
  }
  function ti93OpenAttachments(){
    const draft=state.ti93Draft,working=ti93Copy(draft.attachments),dialog=ti93Dialog(ti93Text.attachmentAdd,`<div data-ti93-attachment-list></div><button data-ti93-synthetic-file>添加合成图片</button><label class="ti93-file-source">${esc(ti93Text.attachmentChooseFromGallery)}<input data-ti93-files type="file" accept="image/*" multiple aria-label="${esc(ti93Text.attachmentChooseFromGallery)}"></label><p>文件只保留在此局部预览，不上传。</p>`,()=>{draft.attachments=working.slice(0,9);render();});
    const paint=()=>dialog.querySelector('[data-ti93-attachment-list]').innerHTML=working.map((file,i)=>`<div class="ti93-pending-file">${icon('image')}<span>${esc(file.name)}</span><button data-ti93-remove-file="${i}" aria-label="${esc(ti93Text.commonDelete)}">×</button></div>`).join('');paint();
    dialog.addEventListener('click',event=>{if(event.target.closest('[data-ti93-synthetic-file]')&&working.length<9){working.push({name:'QA-receipt-'+(working.length+1)+'.png',synthetic:true});paint();}const remove=event.target.closest('[data-ti93-remove-file]');if(remove){working.splice(Number(remove.dataset.ti93RemoveFile),1);paint();}});
    dialog.addEventListener('change',event=>{if(event.target.matches('[data-ti93-files]')){for(const file of Array.from(event.target.files||[]).slice(0,9-working.length))working.push({name:file.name,synthetic:false});paint();}});
  }
  for(const scene of ti93Fixtures.scenes)fDefine(scene.key,scene.title,'主记账转账','widgets/transaction/transfer_form.dart',()=>{if(state.ti93Scene!==scene.key)ti93Start(scene.key);return ti93Render();});
  const ti93PreviousRender=fRender;
  fRender=function(key){if(ti93Keys.has(key)){if(state.ti93Scene!==key)ti93Start(key);return ti93Render();}if(key==='transfer'){if(state.ti93Scene!=='transfer-inline')ti93Start('transfer-inline');return ti93Render();}return ti93PreviousRender(key);};
  const ti93PreviousAfter=rAfterRender;
  rAfterRender=function(){ti93PreviousAfter();const active=!!phone.querySelector('.ti93-shell');phone.dataset.ti93Editor=String(active);if(active){phone.dataset.ti93Compact=String(qPreview.height<720);phone.dataset.ti93Narrow=String(qPreview.width<=340);}};
  document.addEventListener('input',event=>{if(event.target.matches('[data-ti93-note]'))state.ti93Draft.note=event.target.value;if(event.target.matches('[data-ti93-expression]')){state.ti93Draft.expression=event.target.value;const active=document.activeElement;const cursor=event.target.selectionStart;render();const field=phone.querySelector('[data-ti93-expression]');if(active?.matches('[data-ti93-expression]')){field?.focus({preventScroll:true});field?.setSelectionRange(cursor,cursor);}}},true);
  document.addEventListener('click',event=>{
    const action=event.target.closest('[data-ti93-action]')?.dataset.ti93Action;if(!action)return;event.preventDefault();event.stopImmediatePropagation();
    const d=state.ti93Draft;if(d.busy)return;
    if(action==='add-account'){navigate('flow-account-new');return;}
    if(action.startsWith('account:')){ti93OpenAccounts(action.endsWith('from'));return;}
    if(action==='rate'){ti93OpenRate();return;}
    if(action==='tags'){ti93OpenTags();return;}
    if(action==='attachments'||action.startsWith('attachment:')){ti93OpenAttachments();return;}
    if(action==='date'){ti93Dialog(ti93Text.importFieldDate,`<input data-ti93-date type="datetime-local" value="${esc(d.date)}" aria-label="${esc(ti93Text.importFieldDate)}">`,dialog=>{const value=dialog.querySelector('[data-ti93-date]').value;if(!value)return false;d.date=value;render();});return;}
    if(action==='note-history'){ti93Dialog(ti93Text.appearanceNoteHistory,`<button data-ti93-history>QA 一笔家庭转账</button>`,null,{confirm:false}).addEventListener('click',event=>{if(event.target.closest('[data-ti93-history]')){d.note='QA 一笔家庭转账';event.currentTarget.close();event.currentTarget.remove();render();}});return;}
    if(action==='back'||action.startsWith('type:')){if(action==='type:transfer')return;ti93Dialog(ti93Text.v4RecordingDiscardTitle,`<p>${esc(ti93Text.v4RecordingDiscardMessage)}</p>`,()=>{if(action==='back')ti93Back();else{state.recordType=action.slice(5);state.category=state.recordType==='income'?'工资':'餐饮';state.ti93Scene='';state.page='editor';render();}});return;}
    if(action==='note-toggle')d.noteExpanded=!d.noteExpanded;
    if(action.startsWith('key:'))ti93Key(action.slice(4));
    if(action==='clear')d.expression='0';
    if(action==='equals'){const amount=ti93Amount();if(amount!==null)d.expression=String(amount);}
    if(action==='save')ti93Save();
    render();
  },true);
  window.beeTransferInlinePreview={scenes:[...ti93Keys],start(key){ti93Start(key);state.page='flow-'+key;render();},get draft(){return ti93Copy(state.ti93Draft);},get rows(){return ti93Copy(state.ti93Rows);},render:ti93Render};
  // Installed before the views map: income/expense keep the existing renderer.
  const ti93PreviousEditor=pEditor;
  pEditor=function(){
    if(state.recordType!=='transfer')return ti93PreviousEditor();
    if(state.ti93Scene!=='main-transfer'){
      ti93Start('transfer-inline');state.ti93Scene='main-transfer';
      const d=state.ti93Draft,mainAccounts=typeof accounts!=='undefined'?accounts:[];
      d.externalAccounts=[...mainAccounts.map((account,i)=>({id:'main-'+(account.id||i),name:account.name,currency:account.currency||'CNY',type:account.type||'cash',tradable:!['real_estate','vehicle','investment','insurance','social_fund','loan'].includes(account.type),hidden:!!account.hidden,balance:account.amount||0})),...ti93Fixtures.accounts.filter(account=>account.currency!=='CNY')];
      const byName=name=>d.externalAccounts.find(account=>account.name===name)?.id||null;
      d.from=byName(state.recordAccount);d.to=byName(state.toAccount);d.expression=String(state.expression||'0');d.note=state.note||'';d.tags=[...(state.recordTags||[])];d.date=`${state.year||2026}-${String(state.month||10).padStart(2,'0')}-${String(state.day||25).padStart(2,'0')}T12:30`;
      if(state.vEditId){d.mode='edit';d.editId=String(state.vEditId);d.originalFrom=d.from;d.originalTo=d.to;d.originalCurrency=state.fRecordCurrency||ti93Account(d.from)?.currency;const rate=Number(state.fRecordRate);d.rateOverride=Number.isFinite(rate)&&rate>0?rate:null;d.pins=[d.from,d.to].filter(Boolean);}
    }
    return ti93Render();
  };
