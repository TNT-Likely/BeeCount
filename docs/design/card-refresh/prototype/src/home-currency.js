  // Quotes are fixed design fixtures; historical nativeAmount is never recomputed.
  const vQuotes={CNY:1,USD:7.10,EUR:7.72,HKD:.91,JPY:.048,GBP:9.23,AUD:4.73,CAD:5.19,SGD:5.38,CHF:8.12,KRW:.0052,THB:.213};
  const vQuote=code=>code===state.fBaseCurrency?1:vQuotes[code]&&vQuotes[state.fBaseCurrency]?vQuotes[code]/vQuotes[state.fBaseCurrency]:null;
  const vCommon=['CNY','USD','EUR','HKD','JPY','GBP','AUD','CAD','SGD','KRW'];
  const vSymbols={CNY:'¥',USD:'US$',EUR:'€',HKD:'HK$',JPY:'JP¥',GBP:'£',AUD:'A$',CAD:'CA$',SGD:'S$',KRW:'₩',AED:'AED',SAR:'SAR'};
  Object.assign(state,{vCurrencyQuery:'',vRateDraft:'',vRateError:'',vEditId:null,vQuoteStatus:'ready'});
  dContextKeys.push('vEditId','vQuoteStatus');
  const vRound=n=>Math.round((n+Number.EPSILON)*100)/100;
  const vCode=r=>r.currency||state.fBaseCurrency||'CNY';
  const vSymbol=code=>{const symbol=vSymbols[code]||wCurrencies.find(c=>c.code===code)?.symbol||code;return /[\u0590-\u08ff]/.test(symbol)?code:symbol;};
  const vForeign=r=>vCode(r)!==state.fBaseCurrency;
  const vNative=r=>Number.isFinite(r.nativeAmount)?r.nativeAmount:vForeign(r)?vRound(r.amount*Number(r.rate||vQuote(vCode(r))||1)):r.amount;
  const vRateText=n=>Number(n).toLocaleString('en-US',{maximumFractionDigits:6});
  const vOriginal=r=>(r.type==='transfer'?'':r.type==='income'?'+':'−')+(vForeign(r)?vSymbol(vCode(r)):'')+shown(r.amount);
  const vConversion=r=>vForeign(r)?`<span class="v-converted bc-num">≈ ${vSymbol(state.fBaseCurrency)}${shown(vNative(r))}</span>`:'';
  function vRowAmount(r){return `<span class="bc-entry-money bc-num ${r.type==='income'?'income':''}"><span class="v-original">${vOriginal(r)}</span><span class="v-entry-secondary">${vConversion(r)}${r.tag?tag(r.tag):''}</span></span>`;}
  // Foreign examples are immediately visible in home/search/batch.
  Object.assign(items.find(r=>r.id===2),{currency:'USD',amount:12,rate:7.1,nativeAmount:85.2,account:'美元账户',tag:'旅行'});
  Object.assign(items.find(r=>r.id===3),{currency:'JPY',amount:125,rate:.048,nativeAmount:6,account:'日元现金'});
  accounts.forEach(a=>a.currency='CNY');
  accounts.push({id:'usd',name:'美元账户',currency:'USD',note:'美元 · USD',icon:'wallet',amount:320.5},{id:'jpy',name:'日元现金',currency:'JPY',note:'现金 · JPY',icon:'banknote',amount:18000});
  rSpecs['currency-picker']={title:'选择币种',host:'editor',kind:'sheet'};
  rSpecs['exchange-rate']={title:'补充汇率',host:'editor',kind:'dialog'};
  fDefine('currency-picker','账单币种选择','交互补充','../widgets/currency/currency_picker_sheet.dart',()=>vCurrencyBody());
  fDefine('foreign-editor','记账 · 外币折算预览','交互补充','../widgets/biz/amount_editor_sheet.dart',()=>{vPrepareForeign();return pEditor();});
  fDefine('rate-unavailable','记账 · 汇率获取失败','交互补充','../widgets/biz/amount_editor_sheet.dart',()=>{vPrepareForeign('AED');return pEditor();});
  fDefine('exchange-rate','记账 · 手动补充汇率','交互补充','../widgets/biz/amount_editor_sheet.dart',()=>vRateBody());
  fDefine('foreign-detail','账单详情 · 外币与记录时汇率','交互补充','../widgets/biz/transaction_list_item.dart',()=>dBillDetail());
  function vPrepareForeign(code='USD'){state.fRecordCurrency=code;state.fRecordRate=String(vQuote(code)||'');state.vQuoteStatus=vQuote(code)?'ready':'error';state.vEditId=null;state.recordAccount=code==='USD'?'美元账户':'';state.amount='12.00';state.expression='12.00';state.category='饮品';state.subcategory='咖啡';state.expandedCategory='';state.note='一杯拿铁';}
  function vCurrencyBody(){const query=state.vCurrencyQuery.trim().toLowerCase(),match=c=>!query||[c.code,wCurrencyName(c),c.symbol].join(' ').toLowerCase().includes(query),common=vCommon.map(code=>wCurrencies.find(c=>c.code===code)).filter(Boolean),other=wCurrencies.filter(c=>!vCommon.includes(c.code));
    const rows=list=>list.filter(match).map(c=>{const rate=vQuote(c.code);return btn('v-use-currency:'+c.code,`<span class="v-currency-symbol">${esc(vSymbol(c.code))}</span><span class="v-currency-copy"><b>${c.code}<span>${esc(wCurrencyName(c))}</span></b><small>${c.code===state.fBaseCurrency?'账本本位币':rate?'1 '+c.code+' ≈ '+vRateText(rate)+' '+state.fBaseCurrency:'暂无汇率 · 选择后可手动补充'}</small></span><span class="v-currency-check">${state.fRecordCurrency===c.code?icon('check'):''}</span>`,'选择'+c.code+' '+wCurrencyName(c),'v-currency-row',`aria-pressed="${state.fRecordCurrency===c.code}"`);}).join('');
    const first=rows(common),rest=rows(other);return `<label class="p-search-box v-currency-search">${icon('search')}<input data-v-currency-query aria-label="搜索币种" placeholder="搜索币种名称、代码或符号" value="${esc(state.vCurrencyQuery)}"></label><div class="v-currency-list">${first?'<h4>常用币种</h4>'+first:''}${rest?'<h4>全部币种</h4>'+rest:''}${!first&&!rest?'<div class="p-empty">没有找到此币种</div>':''}</div><p class="v-currency-foot">汇率为示例；统计合计按 ${esc(state.fBaseCurrency)} 折算</p>`;
  }
  function vEditorPreview(){if(state.fRecordCurrency===state.fBaseCurrency||state.recordType==='transfer')return '';const calc=pCalcState();if(!calc.valid)return '<span class="bc-small">完成算式后预览折算金额</span>';if(state.vQuoteStatus==='loading')return `${icon('loader-circle')}正在获取汇率…`;if(!(Number(state.fRecordRate)>0))return btn('v-rate',`${icon('circle-alert')}汇率获取失败 · 手动补充${icon('chevron-right')}`,'汇率获取失败，手动补充汇率','v-rate-error');return `<span class="bc-num">≈ ${vSymbol(state.fBaseCurrency)}${money(vRound(calc.value*Number(state.fRecordRate)))}</span><small>1 ${esc(state.fRecordCurrency)} ≈ ${vRateText(state.fRecordRate)} ${esc(state.fBaseCurrency)}</small>`;}
  function vOpenCurrency(){state.vCurrencyQuery='';rOpenModal('currency-picker');}
  function vUseCurrency(code){if(code!==state.fRecordCurrency){state.fRecordCurrency=code;state.recordAccount='';state.fRecordRate=String(vQuote(code)||'');state.vQuoteStatus=Number(state.fRecordRate)>0?'ready':'error';}rDismiss();render();persist();}
  function vOpenRate(){state.vRateDraft=Number(state.fRecordRate)>0?String(state.fRecordRate):'';state.vRateError='';rOpenModal('exchange-rate');}
  function vRateBody(){return `<p class="v-rate-caption">暂时无法获取 ${esc(state.fRecordCurrency)} 汇率，补充后可继续保存。</p><div class="v-rate-equation"><span>1 ${esc(state.fRecordCurrency)}</span><span>=</span><label><input data-v-rate inputmode="decimal" type="text" aria-label="折算汇率" placeholder="输入汇率" value="${esc(state.vRateDraft)}"><span>${esc(state.fBaseCurrency)}</span></label></div><p class="v-rate-hint">仅用于本笔账单的折算。</p><p class="p-inline-error" data-v-rate-error role="alert">${esc(state.vRateError)}</p><div class="bc-inline-actions">${btn('r-close','取消','取消补充汇率','bc-secondary')}${btn('v-rate-confirm','确认汇率','确认汇率','bc-primary')}</div>`;}
  // Account currencies are visible and incompatible accounts are omitted.
  fDefs['account-picker'].body=()=>{const code=state.fRecordCurrency||state.fBaseCurrency,rows=accounts.filter(a=>state.recordType==='transfer'||a.currency===code);return `<p class="v-account-filter">${state.recordType==='transfer'?'全部账户':'仅显示 '+code+' 账户'}</p>${rows.length?surface(rows.map(a=>menuRow('g-use-account:'+a.name,a.icon,a.name,a.note,vSymbol(a.currency)+money(a.amount))).join('')):surface('<div class="p-empty">此币种暂无账户<br>可暂不设置，或新建账户</div>')}${btn('g-use-account:','不设置账户','不设置账户','bc-secondary')}${fLink('account-edit','plus','新增账户')}`;};
  root.addEventListener('input',e=>{if(e.target.matches('[data-v-currency-query]')){state.vCurrencyQuery=e.target.value;const pos=e.target.selectionStart;rBuildModal();const input=phone.querySelector('[data-v-currency-query]');input.focus({preventScroll:true});input.setSelectionRange(pos,pos);}if(e.target.matches('[data-v-rate]'))state.vRateDraft=e.target.value;if(e.target.dataset.pField==='expression'){const preview=phone.querySelector('[data-v-preview]');if(preview){preview.innerHTML=vEditorPreview();globalThis.lucide?.createIcons({attrs:{width:16,height:16}});}}});
  root.addEventListener('click',e=>{const el=e.target.closest('[data-action]');if(!el)return;const [action,...parts]=el.dataset.action.split(':'),arg=parts.join(':');if(el.closest('.x-swipe')&&performance.now()<xGestureBlock){e.preventDefault();e.stopImmediatePropagation();return;}if(action==='page'&&arg==='editor'&&state.page!=='editor')state.vEditId=null;if(!action.startsWith('v-'))return;e.preventDefault();e.stopImmediatePropagation();
    if(action==='v-currency')vOpenCurrency();
    else if(action==='v-use-currency')vUseCurrency(arg);
    else if(action==='v-rate')vOpenRate();
    else if(action==='v-rate-confirm'){const value=Number(state.vRateDraft);if(!state.vRateDraft.trim()||!Number.isFinite(value)||value<=0||value>1e9){state.vRateError='请输入大于 0 的有效汇率';phone.querySelector('[data-v-rate-error]').textContent=state.vRateError;return;}state.fRecordRate=String(value);state.vQuoteStatus='ready';rDismiss();render();}
    else if(action==='v-row-category'){const row=pRows().find(r=>r.id===Number(arg));if(row){if(row.type==='transfer'){state.detailId=row.id;navigate('detail');}else{const child=dSubOf(row);dOpenCategory(dParentOf(row),child==='未细分'?'':child,row.type==='income'?'income':'expense');}}}
    persist();
  },true);
