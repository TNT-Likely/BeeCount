  Object.assign(state,{wWelcomeCurrencyQuery:''});
  function wWelcomeCurrencies(){const q=state.wWelcomeCurrencyQuery.trim().toLowerCase();return `<label class="p-search-box v-currency-search">${icon('search')}<input data-ow-currency-query placeholder="搜索币种名称、代码或符号" aria-label="搜索初始化币种" value="${esc(state.wWelcomeCurrencyQuery)}"></label><div class="v-currency-list">${wCurrencies.filter(c=>!q||[c.code,wCurrencyName(c),c.symbol].join(' ').toLowerCase().includes(q)).map(c=>btn('ow-currency:'+c.code,`<span class="v-currency-symbol">${esc(c.symbol)}</span><span class="v-currency-copy"><b>${c.code}<span>${esc(wCurrencyName(c))}</span></b></span><span class="v-currency-check">${state.wCurrency===c.code?icon('check'):''}</span>`,'选择'+c.code,'v-currency-row',`aria-pressed="${state.wCurrency===c.code}"`)).join('')||'<p class="p-empty">没有找到此币种</p>'}</div>`;}
  rSpecs['welcome-currency-picker']={title:'全部币种',host:'welcome',kind:'sheet'};
  const wPreviousCurrencyModal=rModalBody;
  rModalBody=function(key){return key==='welcome-currency-picker'?wWelcomeCurrencies():wPreviousCurrencyModal(key);};
  wCurrencySheet=function(){state.wStep=wStep();state.page='welcome';state.wWelcomeCurrencyQuery='';rOpenModal('welcome-currency-picker');};
  root.addEventListener('input',event=>{if(!event.target.matches('[data-ow-currency-query]'))return;state.wWelcomeCurrencyQuery=event.target.value;const pos=event.target.selectionStart;rBuildModal();const input=phone.querySelector('[data-ow-currency-query]');input.focus({preventScroll:true});input.setSelectionRange(pos,pos);});
  root.addEventListener('click',event=>{const el=event.target.closest('[data-action^="ow-currency:"]');if(!el)return;event.preventDefault();event.stopImmediatePropagation();state.wCurrency=el.dataset.action.split(':')[1];rClose();render();persist();},true);
  fDefine('welcome-currency-picker','欢迎 · 全部币种与搜索','启动与分享','auth/welcome_page.dart',wWelcomeCurrencies);
  const wWelcomePreview=root.querySelector('#bee-immersive-pages');
  (wWelcomePreview.querySelector('optgroup[label="启动与分享"]')||wWelcomePreview).appendChild(new Option('欢迎 · 全部币种与搜索','flow-welcome-currency-picker'));
  const wPreviousPrepare=rPrepareRoute;
  rPrepareRoute=function(){if(state.page==='flow-welcome-currency-picker')state.wStep=1;wPreviousPrepare();};
