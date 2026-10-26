  // TD94 TRANSACTION DETAIL START
  const td94Text=__TRANSACTION_DETAIL_TEXTS__,td94Assets=__TRANSACTION_DETAIL_ASSETS__;
  const td94Scenes=['transaction-detail','transaction-detail-income','transaction-detail-transfer','transaction-detail-foreign','transaction-detail-unconverted','transaction-detail-private','transaction-detail-attachments','transaction-detail-missing-image','transaction-detail-long','transaction-detail-loading','transaction-detail-error','transaction-detail-missing','transaction-detail-readonly'];
  Object.assign(state,{td94Key:'',td94Retry:false,td94Reveal:false,td94ViewerActive:false,td94ViewerItems:[],td94ViewerBill:0});
  function td94Mode(key){return key==='detail'||key==='transaction-detail'?'normal':key.replace('transaction-detail-','');}
  function td94Row(mode){
    const base=xRow(state.detailId),row={...base};
    if(mode==='income')return {...(pRows().find(r=>r.type==='income')||row),type:'income'};
    if(mode==='transfer')return {...row,type:'transfer',category:'',title:'QA 同币种账户转账',account:'QA USD现金',toAccount:'QA USD银行',currency:'USD',amount:120,nativeAmount:858};
    if(['foreign','private','unconverted'].includes(mode))return {...(pRows().find(r=>r.type==='expense')||row),type:'expense',currency:'USD',amount:12,nativeAmount:mode==='unconverted'?null:85.8};
    if(mode==='long')return {...row,title:'QA 需要完整展示的分类及备注信息与长名称账本',note:'QA 长备注：保留每一笔生活记录与账户来源。\n'.repeat(12),account:'QA 一个需要换行但不能丢失的账户完整名称',ledger:'QA 一个完整保留名称的家庭共享账本',tags:['QA 非常长的中文标签名称','QA original English tag name'],currency:'USD',amount:123456789.12,nativeAmount:882667042.208};
    return row;
  }
  function td94Images(row,mode){
    if(mode==='attachments'||mode==='missing-image')return td94Assets.attachments.map((a,i)=>({...a,src:mode==='missing-image'&&i===1?'data:image/png;base64,AA==':a.src}));
    return uAttachments(row);
  }
  function td94Hidden(mode){return state.hide||(mode==='private'&&!state.td94Reveal);}
  function td94Line(label,value,action=''){
    const body=`<span>${esc(label)}</span><b>${value}${action?icon('chevron-right'):''}</b>`;
    return action?btn(action,body,label,'td94-line td94-link'):`<div class="td94-line">${body}</div>`;
  }
  function td94Body(key){
    if(state.td94Key!==key){state.td94Key=key;state.td94Retry=false;state.td94Reveal=false;}
    const mode=td94Mode(key),t=td94Text;
    if(mode==='loading')return `<div class="td94-state" role="status">${icon('loader-circle')}${esc(t.mineCloudServiceLoading)}</div>`;
    if(mode==='missing')return `<div class="td94-state">${icon('file-question')}${esc(t.aiChatTransactionNotFound)}</div>`;
    if(mode==='error'&&!state.td94Retry)return `<div class="td94-state">${icon('circle-alert')}<p>${esc(t.commonError)}</p>${btn('td94-retry',esc(t.v4RecordingRetry),t.v4RecordingRetry,'bc-primary')}</div>`;
    const row=td94Row(mode),hidden=td94Hidden(mode),code=row.currency||state.fBaseCurrency||'CNY',base=state.fBaseCurrency||'CNY',foreign=code!==base;
    const kind=row.type==='income'?t.exportTypeIncome:row.type==='transfer'?t.exportTypeTransfer:t.exportTypeExpense;
    const signed=row.type==='expense'?-row.amount:row.amount;
    const amount=hidden?'••••':(row.type==='transfer'||signed===0?'':signed<0?'−':'+')+money(Math.abs(signed));
    const native=Number.isFinite(row.nativeAmount)?row.nativeAmount:null,rate=native!==null&&row.amount!==0?Math.abs(native/row.amount):null;
    const parent=row.type==='transfer'?'':dParentOf(row),sub=row.type==='transfer'?'':dSubOf(row),category=parent+(sub&&sub!=='未细分'?' / '+sub:'');
    const catAction=row.type==='transfer'?'':`d-bill-category:${parent}:${sub==='未细分'?'':sub}`;
    const account=accounts.find(a=>a.name===row.account),toAccount=accounts.find(a=>a.name===row.toAccount),tags=row.tags?.length?row.tags:row.tag?[row.tag]:[],images=td94Images(row,mode);
    const iconHtml=row.type==='transfer'?icon('arrow-left-right'):jCategoryVisual(sub==='未细分'?parent:sub,row.icon);
    return `<div class="td94-stack"><section class="td94-card td94-hero">${catAction?btn(catAction,iconHtml,t.categoryDetailTooltip,'td94-icon'):`<span class="td94-icon">${iconHtml}</span>`}<h3>${esc(row.title||category||kind)}</h3><div class="td94-amount ${row.type}" data-td94-amount>${esc(amount)}</div><small>${esc(kind+' · '+code)}</small></section>${foreign?`<section class="td94-card td94-snapshot"><small>${esc(t.v4TransactionDetailSnapshot)}</small><b data-td94-snapshot>${hidden?'••••':native===null?esc(t.unconvertedBadge):'≈ '+esc(base)+' '+money(native)}</b>${rate!==null?`<p data-td94-rate>${esc(t.v4TransactionDetailSnapshotRate)} · ${hidden?'••••':'1 '+esc(code)+' ≈ '+rate.toPrecision(6)+' '+esc(base)}</p>`:''}</section>`:''}<section class="td94-card td94-fields">${row.type!=='transfer'?td94Line(t.importFieldCategory,esc(category||t.v4DetailMissingCategory),catAction):''}${td94Line(row.type==='transfer'?t.transferFromAccount:t.importFieldAccount,(account?bcAccountVisual(account,20):'')+esc(row.account||t.accountNone),account?'account:'+account.id:'')}${row.type==='transfer'?td94Line(t.transferToAccount,(toAccount?bcAccountVisual(toAccount,20):'')+esc(row.toAccount||t.accountNone),toAccount?'account:'+toAccount.id:''):''}${td94Line(t.transactionReceiptLedger,esc(row.ledger||state.ledger))}${td94Line(t.importFieldDate,esc(`${state.year||2026}.${String(state.month).padStart(2,'0')}.${String(row.day||25).padStart(2,'0')} ${row.time||'12:30:00'}`))}</section>${row.note||row.title?`<section class="td94-card td94-note"><small>${esc(t.exportCsvHeaderNote)}</small><p>${esc(row.note||row.title)}</p></section>`:''}${tags.length?`<section class="td94-card td94-tags"><small>${esc(t.transactionReceiptTags)}</small><div>${tags.map(name=>btn('d-tag:'+name,bcTagPill(name),name,'td94-tag bc-tag-hit',`title="${esc(name)}"`)).join('')}</div></section>`:''}${images.length?`<section class="td94-card td94-attachments"><div class="td94-attachment-heading"><b>${esc(t.exportCsvHeaderAttachments)}</b><small>${esc(t.attachmentCount.replace('{count}',images.length))}</small></div><div class="td94-grid" data-count="${images.length}">${images.map((a,i)=>btn('td94-attachment:'+i,`<img src="${a.src}" alt="${esc(a.title)}" data-td94-image><span class="td94-image-error" hidden>${icon('image-off')}</span><span class="td94-expand">${icon('expand')}</span>`,a.title+' · '+(i+1)+' / '+images.length,'td94-image')).join('')}</div></section>`:''}${row.excludeFromStats||row.excludeFromBudget?`<section class="td94-card td94-flags">${row.excludeFromStats?`<span>${icon('info')}${esc(t.txFlagExcludeFromStats)}</span>`:''}${row.excludeFromBudget?`<span>${icon('info')}${esc(t.txFlagExcludeFromBudget)}</span>`:''}</section>`:''}<div class="td94-actions">${btn('td94-copy',icon('copy')+esc(t.transactionCopyAction),t.transactionCopyAction,'bc-secondary',mode==='readonly'?'disabled':'')}${btn('td94-edit',icon('pencil-line')+esc(t.commonEdit),t.commonEdit,'bc-primary',mode==='readonly'?'disabled':'')}</div>${btn('td94-receipt',icon('share-2')+esc(t.transactionReceiptAction),t.transactionReceiptAction,'td94-share')}</div>`;
  }
  function td94Page(key='detail'){
    const content=td94Body(key),mode=td94Mode(key),hidden=td94Hidden(mode);
    return subhead(td94Text.v4TransactionDetailTitle,'td94-privacy',hidden?'eye-off':'eye').replace('更多操作',hidden?td94Text.v4AmountsShow:td94Text.v4AmountsHide)+content;
  }
  dBillDetail=function(){return td94Page('detail');};
  for(const key of td94Scenes)fDefine(key,td94Text.v4TransactionDetailTitle+' · '+(key==='transaction-detail'?'原交易':key.replace('transaction-detail-','')),'账单与详情','transaction/transaction_detail_page.dart',()=>td94Body(key));
  const td94RenderBefore=fRender;fRender=function(key){return td94Scenes.includes(key)?td94Page(key):td94RenderBefore(key);};
  const td94ContextBefore=xContext;xContext=function(id){td94ContextBefore(id);const summary=phone.querySelector('.x-context-summary');if(summary&&!phone.querySelector('[data-action^="td94-open:"]'))summary.insertAdjacentHTML('afterend',menuRow('td94-open:'+id,'file-text',td94Text.v4TransactionDetailTitle));globalThis.lucide?.createIcons({attrs:{width:18,height:18}});};
  const td94AttachmentsBefore=uAttachments;uAttachments=function(row){return state.td94ViewerActive&&row?.id===state.td94ViewerBill?state.td94ViewerItems:td94AttachmentsBefore(row);};
  const td94DismissBefore=rDismiss;rDismiss=function(){if(state.rModal==='attachment-viewer')state.td94ViewerActive=false;return td94DismissBefore();};
  function td94Legacy(action){const button=document.createElement('button');button.dataset.action=action;button.hidden=true;root.appendChild(button);button.click();button.remove();}
  document.addEventListener('error',event=>{const img=event.target;if(img instanceof HTMLImageElement&&img.matches('[data-td94-image]')){img.hidden=true;img.nextElementSibling.hidden=false;}},true);
  document.addEventListener('click',event=>{
    const guide=event.target.closest('[data-td94-demo]');if(guide){const out=guide.closest('.td94-guide')?.querySelector('[data-td94-demo-result]');if(out)out.textContent='QA 局部详情回调，不编辑真实账单或分享文件';return;}
    const el=event.target.closest('[data-action]');if(!el||el.disabled)return;
    const [action,...parts]=el.dataset.action.split(':'),arg=parts.join(':');
    // Q01=B: ordinary list taps still invoke the existing edit entry.
    if(action==='detail'&&el.closest('.bc-entry')&&state.page!=='batch'){
      event.preventDefault();event.stopImmediatePropagation();
      if(performance.now()<xGestureBlock)return;
      state.detailId=Number(arg);td94Legacy('edit-record');return;
    }
    if(!action.startsWith('td94-'))return;
    event.preventDefault();event.stopImmediatePropagation();
    const key=state.page==='detail'?'detail':state.page.replace('flow-',''),mode=td94Mode(key),row=td94Row(mode);
    if(action==='td94-open'){state.detailId=Number(arg);rDismiss();navigate('detail');}
    else if(action==='td94-privacy'){if(mode==='private'&&!state.td94Reveal){state.td94Reveal=true;state.hide=false;}else state.hide=!state.hide;render();}
    else if(action==='td94-retry'){state.td94Retry=true;render();}
    else if(action==='td94-edit'||action==='td94-copy'){state.detailId=row.id;td94Legacy(action==='td94-edit'?'edit-record':'copy-record');}
    else if(action==='td94-receipt'){state.receiptId=row.id;state.detailId=row.id;td94Legacy('x-receipt:'+row.id);}
    else if(action==='td94-attachment'){state.td94ViewerItems=td94Images(row,mode);state.td94ViewerBill=row.id;state.td94ViewerActive=true;state.uAttachmentBill=row.id;state.uAttachmentIndex=Number(arg);rOpenModal('attachment-viewer');}
  },true);
  // TD94 TRANSACTION DETAIL END
