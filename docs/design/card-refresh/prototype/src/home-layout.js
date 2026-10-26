  if(qParams.get('embed')==='1'){
    const style=document.createElement('style');style.textContent='body{margin:0!important;padding:0!important;max-width:none!important}#bee-immersive-suite{margin:0!important}#bee-immersive-suite .bc-preview-controls,.bc-preview-scene{display:none!important}#bee-immersive-suite .bc-stage{padding:0!important;border:0!important;background:none!important;display:block!important}';document.head.appendChild(style);
  }
  // Layout samples use synthetic records; repository and navigation remain App-owned.
  if(qParams.get('brand')==='hidden')settings.showBrand=false;
  if(qParams.get('records')==='empty'){state.year=2025;state.month=1;}
  const hPreviousHome=home;
  home=function(){
    const host=document.createElement('div');host.innerHTML=hPreviousHome();
    if(qParams.get('records')==='empty'){host.querySelector('.bc-budget')?.remove();const count=host.querySelector('.bc-stream-head small');if(count)count.textContent='0笔';}
    // A visual fixture for the original distinction between statistical expense
    // and budget expense; financial calculations are independently checked in App QA.
    if(qParams.get('budget')==='exceeded'){
      const hero=host.querySelector('.bc-hero-value');if(hero)hero.innerHTML='<span style="font-size:22px;font-weight:400">¥ </span>'+shown(3421.56);
      const metrics=host.querySelectorAll('.bc-dual strong');if(metrics[0])metrics[0].textContent=shown(264.27);if(metrics[1])metrics[1].textContent=shown(-3157.29);
      const budget=host.querySelector('.bc-budget');if(budget){budget.querySelector('.bc-between>span').textContent='月预算 ¥'+shown(2000);const remaining=budget.querySelector('.bc-between button');if(remaining){remaining.innerHTML='剩余 ¥'+shown(-1220.72)+icon('chevron-right');remaining.style.color='var(--bc-red)';}const track=budget.querySelector('.bc-budget-track>span');track.style.width='100%';track.style.background='var(--bc-red)';track.parentElement.setAttribute('aria-valuenow','100');}
    }
    const list=host.querySelector('.bc-stream>div:last-child');
    list.classList.add('h-journal-list');list.setAttribute('aria-label','账单列表，可滚动');
    if(!pRows().length&&!state.query)list.innerHTML=`<div class="h-empty">${icon('receipt-text')}<h3>还没有记账</h3><p>点击底部加号，马上记一笔</p></div>`;
    return host.innerHTML;
  };
  const hPreviousAfterRender=qAfterRender;
  qAfterRender=function(){hPreviousAfterRender();phone.dataset.homeCompact=String(state.page==='home'&&qPreview.height-76<620);};
  state.hLedgerQuery='';
  rSpecs['ledger-picker']={title:'选择账本',host:'home',kind:'dialog'};
  fDefs['ledger-picker'].body=()=>hLedgerBody();
  fDefs['ledger-picker'].source='widgets/biz/ledger_picker_sheet.dart';
  const hPreviousModalBody=rModalBody;
  function hLedgerBody(){const q=state.hLedgerQuery.toLowerCase(),books=state.lBooks.filter(b=>(b.name+' '+b.currency).toLowerCase().includes(q));return `<label class="bc-search">${icon('search')}<input data-h-ledger-query aria-label="搜索账本" placeholder="搜索" value="${esc(state.hLedgerQuery)}"></label><div class="h-ledger-options">${books.map(b=>btn('h-ledger-select:'+b.name,`<span class="bc-entry-icon">${icon('book-open')}</span><span><b>${esc(b.name)}</b><small>${b.currency} · ${b.count}笔${b.name===state.ledger?' · 当前账本':''}</small></span>${b.name===state.ledger?icon('check'):''}`,b.name+(b.name===state.ledger?'，当前账本':''),'h-ledger-option',`aria-pressed="${b.name===state.ledger}"`)).join('')||'<p class="bc-empty">没有可用账本</p>'}</div>${btn('h-ledger-manage',`${icon('settings-2')}账本管理`,'账本管理','bc-secondary')}`;}
  rModalBody=function(key){return key==='ledger-picker'?hLedgerBody():hPreviousModalBody(key);};
  root.addEventListener('input',e=>{if(!e.target.matches('[data-h-ledger-query]'))return;state.hLedgerQuery=e.target.value;const pos=e.target.selectionStart;rBuildModal();const field=phone.querySelector('[data-h-ledger-query]');field.focus({preventScroll:true});field.setSelectionRange(pos,pos);});
  root.addEventListener('click',e=>{const button=e.target.closest('[data-action]');if(!button)return;const action=button.dataset.action;if(action!=='ledger'&&!action.startsWith('h-ledger-'))return;e.preventDefault();e.stopImmediatePropagation();if(action==='ledger'){state.hLedgerQuery='';rSpecs['ledger-picker'].host=state.page;rOpenModal('ledger-picker');}else if(action==='h-ledger-manage'){rDismiss();navigate('ledgers');}else{state.ledger=action.slice('h-ledger-select:'.length);rDismiss();render();persist();}},true);
