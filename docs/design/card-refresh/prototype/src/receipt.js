  // A receipt remains modal over its source transaction; no extra receipt page.
  Object.assign(state,{ar89ReceiptFields:['note','tags'],ar89ReceiptOpen:true});
  const ar89ReceiptRoutes=new Set(['receipt-preview','receipt-long','receipt-busy','receipt-unavailable']);
  function ar89ReceiptBody(mode='data'){
    if(mode==='unavailable')return `<div class="ar89-state" role="alert">${icon('circle-alert')}<p>${esc(ar89Text.transactionReceiptUnavailable)}</p>${btn('ar89-receipt-retry',esc(ar89Text.helpCenterRetry),ar89Text.helpCenterRetry,'bc-primary')}</div>`;
    if(state.ar89ReceiptOpen)requestAnimationFrame(()=>ar89OpenReceipt(mode));
    return `<div class="ar89-stack ar89-receipt-source"><article class="ar89-card"><div class="ar89-between"><b>QA 午餐</b><strong>USD −1,234.56</strong></div><p>2026.10.20 · QA 日常账本</p><p>QA 一顿简单的午餐 · #朋友</p></article>${btn('ar89-receipt-open',`${icon('receipt-text')}${esc(ar89Text.transactionReceiptTitle)}`,ar89Text.transactionReceiptTitle,'bc-primary')}<p class="bc-small">预览只改变小票字段；源账单保持原样。原生相册和系统分享在 App 验收。</p></div>`;
  }
  function ar89ReceiptPaper(mode='data'){
    const fields=new Set(state.ar89ReceiptFields),long=mode==='long',t=ar89Text;
    const row=(label,value)=>`<div class="ar89-ticket-row"><span>${esc(label)}</span><span>${esc(value)}</span></div>`;
    return `<article class="ar89-ticket"><header><img src="${brandImages.bee}" alt=""><strong>${esc(t.sharePosterAppName)}</strong><small>BEECOUNT</small></header><div class="ar89-ticket-rule"></div><p class="ar89-ticket-kind">${esc(t.homeExpense)}</p><strong class="ar89-ticket-amount">−${long?'1,234,567,890.12':'1,234.56'}</strong><p class="ar89-ticket-code">USD</p><div class="ar89-ticket-rule"></div>${row(t.importFieldCategory,'QA 餐饮')}${row(t.importFieldDate,'2026.10.20 12:30')}${fields.has('account')?row(t.importFieldAccount,'QA 私人账户'):''}${fields.has('ledger')?row(t.transactionReceiptLedger,'QA 私人账本'):''}${fields.has('tags')?row(t.transactionReceiptTags,'#朋友'):''}${fields.has('note')?`<div class="ar89-ticket-note"><small>${esc(t.importFieldNote)}</small><p>${esc(long?'QA 长备注与 Unicode ☕ 家庭旅行\n'.repeat(32):'QA 一顿简单的午餐')}</p></div>`:''}<div class="ar89-ticket-rule"></div><footer>${esc(t.transactionReceiptFooter)}<small>${esc(t.transactionReceiptTitle)}</small></footer></article>`;
  }
  function ar89OpenReceipt(mode='data'){
    if(document.querySelector('dialog.ar89-receipt-modal'))return;
    const t=ar89Text,dialog=document.createElement('dialog');
    let busy=mode==='busy';
    dialog.className='ar89-receipt-modal';dialog.setAttribute('aria-label',t.transactionReceiptTitle);
    dialog.innerHTML=`<div class="ar89-receipt-heading"><b>${esc(t.transactionReceiptTitle)}</b><button data-ar89-receipt-close aria-label="${esc(t.commonClose)}" ${busy?'disabled':''}>${icon('x')}</button></div><div class="ar89-receipt-canvas">${ar89ReceiptPaper(mode)}</div><div class="ar89-receipt-controls"><p>${esc(t.transactionReceiptFields)}</p><div class="ar89-receipt-fields">${[['note','importFieldNote'],['tags','transactionReceiptTags'],['account','importFieldAccount'],['ledger','transactionReceiptLedger']].map(([value,key])=>`<button data-ar89-receipt-field="${value}" aria-pressed="${state.ar89ReceiptFields.includes(value)}" ${busy?'disabled':''}>${esc(t[key])}</button>`).join('')}</div><div class="ar89-receipt-actions"><button data-ar89-receipt-export="save" ${busy?'disabled':''}>${icon('download')}${esc(t.sharePosterSave)}</button><button class="ar89-receipt-primary" data-ar89-receipt-export="share" ${busy?'disabled':''}>${icon('share')}${esc(t.sharePosterShare)}</button></div><p class="ar89-receipt-event" role="status">${busy?esc(t.annualReportGenerating):''}</p></div>`;
    phone.appendChild(dialog);dialog.showModal();
    if(busy)setTimeout(()=>{if(!dialog.isConnected)return;busy=false;dialog.querySelectorAll('button:disabled').forEach(button=>button.disabled=false);dialog.querySelector('.ar89-receipt-event').textContent='仅演示忙碌状态；未执行原生导出';},1200);
    if(window.lucide)window.lucide.createIcons();
    const close=()=>{state.ar89ReceiptOpen=false;dialog.close();dialog.remove();};
    dialog.addEventListener('cancel',event=>{if(busy)event.preventDefault();else close();});
    dialog.addEventListener('click',event=>{
      if(event.target.closest('[data-ar89-receipt-close]')&&!busy){close();return;}
      const field=event.target.closest('[data-ar89-receipt-field]');
      if(field&&!busy){const value=field.dataset.ar89ReceiptField,set=new Set(state.ar89ReceiptFields);set.has(value)?set.delete(value):set.add(value);state.ar89ReceiptFields=[...set];field.setAttribute('aria-pressed',set.has(value));dialog.querySelector('.ar89-receipt-canvas').innerHTML=ar89ReceiptPaper(mode);return;}
      const action=event.target.closest('[data-ar89-receipt-export]');
      if(action&&!busy)dialog.querySelector('.ar89-receipt-event').textContent=action.dataset.ar89ReceiptExport==='save'?'已调用示例保存回调；原生相册由 App 验收':'已调用示例分享回调；系统分享面板由 App 验收';
    });
  }
  for(const [key,title,mode]of [['receipt-preview','账单小票弹窗','data'],['receipt-long','账单小票 · 长备注与大金额','long'],['receipt-busy','账单小票 · 导出中','busy'],['receipt-unavailable','账单小票 · 无法加载','unavailable']])fDefine(key,title,'年度账单与小票','widgets/biz/transaction_receipt_dialog.dart',()=>ar89ReceiptBody(mode));
  const ar89ReceiptPreviousRender=fRender;
  fRender=function(key){if(ar89ReceiptRoutes.has(key))return subhead(ar89Text.transactionReceiptTitle)+ar89ReceiptBody(key==='receipt-preview'?'data':key.slice('receipt-'.length));return ar89ReceiptPreviousRender(key);};
  document.addEventListener('click',event=>{
    const action=event.target.closest('[data-action]')?.dataset.action;
    if(action==='ar89-receipt-open'||action==='ar89-receipt-retry'){event.preventDefault();event.stopImmediatePropagation();state.ar89ReceiptOpen=true;ar89OpenReceipt(state.page==='flow-receipt-long'?'long':'data');}
  },true);
