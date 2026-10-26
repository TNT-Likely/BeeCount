  // EX88 TRANSACTION EXPORT START
  // Fixed CSV/current-ledger contract from the production ExportPage.
  const ex88Text = __TRANSACTION_EXPORT_TEXTS__;
  const ex88Fields = ['Type','Category','SubCategory','Amount','Currency','Account','FromAccount','ToAccount','Note','Time','Tags','Attachments'].map(key=>ex88Text['exportCsvHeader'+key]);
  const ex88Keys = new Set(['export','export-running','export-success','export-error','export-ios','export-share-error','export-long']);
  Object.assign(state,{ex88Mode:'ready',ex88GeneratedFor:'',ex88SavedIos:false});
  function ex88Mode(key) {
    const preset=key==='export'?'ready':key.slice(7);
    return state.ex88GeneratedFor===state.page&&state.ex88Mode==='success'?'success':preset;
  }
  function ex88Body(key='export') {
    const t=ex88Text,mode=ex88Mode(key),ios=mode==='ios'||mode==='share-error'||(mode==='success'&&state.ex88SavedIos),busy=mode==='running';
    const path=(ios?'/QA/Documents/':'/QA/Download/BeeCount/')+'beecount_20261025_080910.csv';
    const action=ios?t.exportButtonIOS:t.exportButtonAndroid;
    const ledger=mode==='long'?'QA 一个用于验证窄屏和大字号的长名称家庭共享账本 · USD':state.ledger;
    return `<div class="ex88-stack"><section class="ex88-card"><div class="ex88-identity">${icon('file-spreadsheet')}<b>CSV</b><span>${icon('file-down')}</span></div><p class="ex88-description">${esc(t.exportDescription)}</p><div class="ex88-ledger">${icon('book-open')}<div><b>${esc(t.configIncludeLedgers)}</b><small>${esc(ledger)}</small></div></div></section><section class="ex88-card"><div class="ex88-fields">${ex88Fields.map(label=>`<span>${icon('check')}${esc(label)}</span>`).join('')}</div></section><button class="bc-primary ex88-export" data-action="ex88-export" ${busy?'disabled aria-busy="true"':''}>${icon(busy?'loader-circle':'file-down')}${esc(action)}</button>${busy?`<section class="ex88-card" role="status"><div class="ex88-progress-label"><span>${esc(action)}</span><span>60%</span></div><progress max="100" value="60" aria-label="${esc(action)}">60%</progress></section>`:''}${['success','share-error'].includes(mode)?`<section class="ex88-card ex88-result" role="status">${icon('circle-check')}<p>${esc(t.exportSavedTo.replace('{path}',path))}</p></section>`:''}${['error','share-error'].includes(mode)?`<section class="ex88-card ex88-result ex88-error" role="alert">${icon('circle-alert')}<div><b>${esc(t.exportFailedTitle)}</b><p>${esc(mode==='error'?'QA 合成文件写入错误':'QA 合成系统分享错误')}</p></div></section>`:''}</div>`;
  }
  for(const [key,label] of [['export',''],['export-running','导出中'],['export-success','已保存'],['export-error','失败后重试'],['export-ios','iOS 分享入口'],['export-share-error','已保存但分享失败'],['export-long','长账本名称']]) {
    fDefine(key,ex88Text.exportTitle+(label?' · '+label:''),'导入导出与维护','data/export_page.dart',()=>ex88Body(key));
  }
  const ex88RenderBefore=fRender;
  fRender=function(key) {
    if(ex88Keys.has(key))return subhead(ex88Text.exportTitle)+ex88Body(key);
    return ex88RenderBefore(key);
  };
  function ex88CsvCell(value) {const text=String(value);return /[",\n\r]/.test(text)?'"'+text.replaceAll('"','""')+'"':text;}
  document.addEventListener('click',event=>{
    const demo=event.target.closest('[data-ex88-demo]');
    if(demo){event.preventDefault();const root=demo.closest('.ex88-guide');const output=root?.querySelector('[data-ex88-demo-result]');if(output)output.textContent='QA 局部导出完成示例，不访问真实数据或系统目录';return;}
    const action=event.target.closest('[data-action="ex88-export"]');
    if(!action||action.disabled)return;
    event.preventDefault();event.stopImmediatePropagation();
    const rows=[ex88Fields,[ex88Text.exportTypeExpense,'QA 餐饮','QA 午餐','32.00','USD','QA 现金','','','QA 合成账单','  2026-10-25 08:09:10  ','QA 标签','qa-receipt.png'],[ex88Text.exportTypeTransfer,'','','10.00','USD','','QA 现金','QA 银行','','  2026-10-25 08:09:10  ','','']];
    const csv='\uFEFF'+rows.map(row=>row.map(ex88CsvCell).join(',')).join('\n');
    const url=URL.createObjectURL(new Blob([csv],{type:'text/csv;charset=utf-8'})),link=document.createElement('a');
    link.href=url;link.download='beecount_20261025_080910.csv';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
    state.ex88SavedIos=['flow-export-ios','flow-export-share-error'].includes(state.page);state.ex88GeneratedFor=state.page;state.ex88Mode='success';render();
    notice('QA 合成 CSV 已生成；原生保存与分享由 App 提供');
  },true);

  // EX88 TRANSACTION EXPORT END
