  // im87: original two-page import contract; the browser uses display fixtures.
  const im87Text = __TRANSACTION_IMPORT_TEXTS__;
  const im87Fields = [
    ['date','importFieldDate'],['type','importFieldType'],['amount','importFieldAmount'],
    ['currency','importFieldCurrency'],['category','importFieldCategory'],['sub_category','exportCsvHeaderSubCategory'],
    ['account','importFieldAccount'],['from_account','exportCsvHeaderFromAccount'],['to_account','exportCsvHeaderToAccount'],
    ['note','importFieldNote'],['tags','exportCsvHeaderTags'],['attachments','exportCsvHeaderAttachments'],
  ];
  const im87Sources = [['generic','importBillTypeGeneric'],['alipay','importBillTypeAlipay'],['wechat','importBillTypeWechat']];
  const im87Fixture = [
    ['日期','类型','金额','币种','分类','二级分类','账户','转出账户','转入账户','备注','标签','附件'],
    ['2026-10-20','支出','32.50','CNY','餐饮','午餐','现金','','','工作日午餐','日常','receipt.jpg'],
    ['2026-10-20','收入','12000.00','CNY','工资','','银行卡','','','月度工资','',''],
    ['2026-10-19','转账','200.00','CNY','','','','银行卡','现金','取现','',''],
    ['2026-10-19','支出','22.00','CNY','餐饮','饮品','现金','','','咖啡','',''],
    ['2026-10-18','支出','86.50','CNY','购物','','银行卡','','','日用品','',''],
    ['2026-10-18','支出','39.00','CNY','餐饮','','现金','','','晚餐','',''],
    ['2026-10-17','支出','68.00','CNY','文教','','银行卡','','','书籍','',''],
    ['2026-10-17','支出','41.00','CNY','餐饮','','现金','','','早餐','',''],
    ['2026-10-16','收入','100.00','CNY','其他','','银行卡','','','退款','',''],
  ];
  Object.assign(state,{im87Source:'generic',im87File:'',im87Map:Object.fromEntries(im87Fields.map(([key],i)=>[key,i])),im87Categories:{'餐饮':'9','工资':'10'},im87Overlay:'',im87Event:''});
  const im87Keys = new Set(['import','mapping','category-map','import-preview','import-progress','import-result','import-partial','import-cancelled','import-reading','import-empty','import-open-error','import-invalid-currency','import-background']);
  function im87T(key, values={}) { let value=im87Text[key]||key;for(const [k,v]of Object.entries(values))value=value.replaceAll('{'+k+'}',String(v));return value; }
  function im87Button(action,label,kind='bc-primary'){return btn('im87-'+action,esc(label),label,kind);}
  function im87Steps(step){return `<div class="im87-steps" aria-label="${esc(im87T('importTitle'))}">${['importChooseFile','importConfirmMapping','importCategoryMapping'].map((k,i)=>`<span ${i===step?'aria-current="step"':''}>${i+1} ${esc(im87T(k))}</span>`).join('')}</div>`;}
  function im87Card(title,body,description=''){return `<section class="im87-card">${title?`<h3>${esc(title)}</h3>`:''}${description?`<p class="im87-muted">${esc(description)}</p>`:''}${body}</section>`;}
  function im87Table(){return `<div class="im87-scroll" tabindex="0" aria-label="${esc(im87T('importPreview'))}"><table><thead><tr>${im87Fixture[0].map(s=>`<th>${esc(s)}</th>`).join('')}</tr></thead><tbody>${im87Fixture.slice(1).map(row=>`<tr>${row.map(s=>`<td>${esc(s)}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`;}
  function im87Preview(){return im87Card(im87T('importPreview'),im87Table()+`<p class="im87-muted">${esc(im87T('importPreviewLimit',{shown:10,total:26}))}</p>`);}
  function im87FileBody(){return im87Steps(0)+im87Card('',`<p class="im87-muted">${esc(im87T('importSelectCsvFile'))}</p><h3>${esc(im87T('importBillType'))}</h3><div class="im87-sources">${im87Sources.map(([value,key])=>btn('im87-source:'+value,esc(im87T(key)),im87T(key),'',`aria-pressed="${state.im87Source===value}"`)).join('')}</div>`)+im87Card('',`<div class="im87-file">${icon('file-spreadsheet')}<div><b>${esc(state.im87File||im87T('importNoFileSelected'))}</b><small>CSV · TSV · TXT · XLSX</small></div></div><label class="im87-file-button">${icon('folder-open')}${esc(im87T('importChooseFile'))}<input type="file" accept=".csv,.tsv,.txt,.xlsx" data-im87-file aria-label="${esc(im87T('importChooseFile'))}"></label>`)+`<p class="im87-hint">${esc(im87T('importHint'))}</p>`;}
  function im87MappingBody(empty=false){return im87Steps(1)+(empty?im87Card('',`<p>${esc(im87T('importNoDataParsed'))}</p>`):'')+im87Card(im87T('importConfirmMapping'),`<div class="im87-fields">${im87Fields.map(([key,label])=>`<label class="im87-field"><span>${esc(im87T(label))}</span><select data-im87-map="${key}" aria-label="${esc(im87T(label))}">${empty?`<option>${esc(im87T('importAutoDetect'))}</option>`:im87Fixture[0].map((column,i)=>`<option value="${i}" ${state.im87Map[key]===i?'selected':''}>${esc(column)}</option>`).join('')}</select></label>`).join('')}</div>`)+(empty?'':im87Preview())+`<div class="im87-actions">${im87Button('next',im87T('importNextStep'))}</div>`;}
  function im87CategoryBody(){return im87Steps(2)+im87Card(im87T('importCategoryMapping'),`<div class="im87-fields">${['餐饮','工资'].map(name=>`<label class="im87-field"><span>${esc(name)}</span><select data-im87-category="${esc(name)}" aria-label="${esc(name)}">${[['',im87T('importKeepOriginalName')],['9','餐饮 ('+im87T('categoryExpense')+')'],['10','工资 ('+im87T('categoryIncome')+')']].map(([value,label])=>`<option value="${value}" ${state.im87Categories[name]===value?'selected':''}>${esc(label)}</option>`).join('')}</select></label>`).join('')}</div>`,im87T('importCategoryMappingDescription'))+`<div class="im87-actions">${im87Button('previous',im87T('importPreviousStep'),'bc-secondary')}${im87Button('review',im87T('importStartImport'))}</div>`;}
  function im87Dialog(kind){
    let title='',body='',actions='';
    if(kind==='review') {title=im87T('importAccountCurrencyPreview');body=`<p class="im87-muted">${esc(im87T('importAccountCurrencyPreviewHint'))}</p><div class="im87-account">现金 <b>CNY</b></div><div class="im87-account">银行卡 <b>CNY</b></div>`;actions=im87Button('dismiss',im87T('commonCancel'),'bc-secondary')+im87Button('confirm',im87T('importStartImport'));}
    if(kind==='reading'){title=im87T('importReading');body=`<p>42%</p><progress value="42" max="100"></progress>`;actions=im87Button('read-cancel',im87T('commonCancel'),'bc-secondary');}
    if(kind==='progress'){title=im87T('importInProgress');body=`<p class="im87-muted">${esc(im87T('importProgressDetail',{done:18,ok:17,fail:1,total:26}))}</p><progress value="18" max="26"></progress>`;actions=im87Button('background',im87T('importBackgroundImport'),'bc-secondary')+im87Button('cancel',im87T('importCancelImport'),'bc-secondary');}
    if(kind==='partial'||kind==='cancelled'){title=im87T('importCompleteTitle');body=`<p>${esc(im87T('importCompleted',{cancelled:kind==='cancelled'?im87T('importCancelled'):'',ok:24,fail:1}))}</p><p class="im87-muted">${esc(im87T('importSkippedNonTransactionTypes',{count:1}))}<br>不计收支(1)</p>`;actions=im87Button('result',im87T('commonConfirm'));}
    if(kind==='invalid'){title=im87T('commonError');body=`<p>${esc(im87T('importCurrencyInvalid'))} 2: ?bad</p>`;actions=im87Button('dismiss',im87T('commonConfirm'));}
    return `<div class="im87-overlay"><div class="im87-dialog" role="dialog" aria-modal="true" aria-label="${esc(title)}"><h3>${esc(title)}</h3>${body}<div class="im87-actions">${actions}</div></div></div>`;
  }
  function im87Body(key){
    let body=key==='import'||key==='import-reading'||key==='import-open-error'?im87FileBody():key==='mapping'||key==='import-empty'?im87MappingBody(key==='import-empty'):im87CategoryBody();
    const fixed={ 'import-preview':'review','import-reading':'reading','import-progress':'progress','import-partial':'partial','import-cancelled':'cancelled','import-invalid-currency':'invalid' }[key];
    if(key==='import-result')body=im87Card(im87T('importCompleteTitle'),`<p>${esc(im87T('importCompleted',{cancelled:'',ok:26,fail:0}))}</p>`);
    if(key==='import-background')body=im87Card(im87T('importBackgroundImport'),`<p>${esc(im87T('importProgress',{ok:18,fail:0}))}</p><progress value="18" max="26"></progress>`);
    if(key==='import-open-error')body+=`<p class="im87-error" role="status">${esc(im87T('importFileOpenError',{error:'无法读取所选文件'}))}</p>`;
    if(state.im87Event)body+=`<p class="im87-muted" role="status">${esc(state.im87Event)}</p>`;
    return `<div class="im87-shell">${body}${fixed||state.im87Overlay?im87Dialog(state.im87Overlay||fixed):''}</div>`;
  }
  for(const key of im87Keys){const title=im87T(key==='import'||key==='import-open-error'?'importTitle':key==='mapping'||key==='import-empty'?'importConfirmMapping':key==='import-preview'?'importAccountCurrencyPreview':key==='import-reading'?'importReading':key==='import-progress'||key==='import-background'?'importInProgress':['import-result','import-partial','import-cancelled'].includes(key)?'importCompleteTitle':'importCategoryMapping');fDefine(key,title,'导入导出与维护',key==='import'?'data/import_page.dart':'data/import_confirm_page.dart',()=>im87Body(key));}
  const im87RenderBefore=fRender;
  fRender=function(key){if(!im87Keys.has(key))return im87RenderBefore(key);const heading=key==='import'||key==='import-reading'||key==='import-open-error'?'importTitle':key==='mapping'||key==='import-empty'?'importConfirmMapping':'importCategoryMapping';return subhead(im87T(heading))+im87Body(key);};
  function im87Go(key){state.im87Overlay='';state.im87Event='';state.page='flow-'+key;render();}
  document.addEventListener('click',event=>{
    const element=event.target.closest('[data-action]');const action=element?.dataset.action;
    if(!action?.startsWith('im87-'))return;
    event.preventDefault();event.stopImmediatePropagation();
    const [command,value]=action.slice(5).split(':');
    if(command==='source'){state.im87Source=value;render();}
    else if(command==='next'){if(state.page==='flow-import-empty'){state.im87Event=im87T('importSelectCategoryFirst');render();}else im87Go('category-map');}
    else if(command==='previous')im87Go('mapping');
    else if(command==='review'){state.im87Overlay='review';render();}
    else if(command==='dismiss'){state.im87Overlay='';if(['flow-import-preview','flow-import-invalid-currency'].includes(state.page))state.page='flow-category-map';render();}
    else if(command==='confirm')im87Go('import-progress');
    else if(command==='background')im87Go('import-background');
    else if(command==='cancel'){state.im87Overlay='';state.page='flow-category-map';state.im87Event=im87T('importProgress',{ok:17,fail:1});render();}
    else if(command==='read-cancel'){state.im87Overlay='';im87Go('mapping');}
    else if(command==='result'){state.im87Overlay='';state.page='data';render();}
  },true);
  document.addEventListener('change',event=>{
    const el=event.target;
    if(el.matches('[data-im87-file]')){const file=el.files?.[0];if(file){state.im87File=file.name;im87Go('mapping');}}
    else if(el.matches('[data-im87-map]')){state.im87Map[el.dataset.im87Map]=Number(el.value);}
    else if(el.matches('[data-im87-category]')){state.im87Categories[el.dataset.im87Category]=el.value;}
  });
