  const r86Text = __RECURRING_BILL_TEXTS__;
  const r86Seed = [
    {id:'coffee',title:'咖啡',glyph:'coffee',ledger:'日常生活 · CNY',code:'USD',amount:'−12.00',frequency:r86Text.recurringTransactionMonthly,note:'每个月的一杯咖啡，QA 合成备注',last:'10/20',enabled:true,type:'expense'},
    {id:'salary',title:'工资',glyph:'briefcase-business',ledger:'家庭账本 · CNY',amount:'+12,000.00',frequency:r86Text.recurringTransactionEveryNMonths.replace('{n}','2'),note:'每两个月结算',last:'10/1',enabled:false,type:'income'},
    {id:'transfer',title:r86Text.transferTitle,glyph:'arrow-left-right',ledger:'旅行账本 · JPY',amount:'5,000.00',frequency:r86Text.recurringTransactionEveryNYears.replace('{n}','2'),note:'同币种账户定期转入',last:'',enabled:true,type:'transfer'},
  ];
  Object.assign(state,{r86Rows:r86Seed.map(x=>({...x})),r86Preset:''});
  const r86Keys = new Set(['recurring','recurring-empty','recurring-loading','recurring-error','recurring-saving','recurring-long','recurring-save-error']);
  function r86Card(row,{busy=false,long=false,guide=false}={}) {
    const t=r86Text;
    const title=long?'为长期旅行准备的自定义分类及周期记账计划':row.title;
    const ledger=long?'一个需要完整保留名称的家庭共享账本 · '+row.ledger.split(' · ').at(-1):row.ledger;
    const open=guide?'data-r86-demo-open':`data-action="f-go:recurring-edit"`;
    const switchAttr=guide?'data-r86-demo-toggle':`data-r86-toggle="${esc(row.id)}"`;
    return `<article class="r86-rule" ${busy?'':open}>
      <div class="r86-rule-head"><span class="r86-icon">${jCategoryVisual(row.title,row.glyph)}</span>
        <div class="r86-rule-name"><button class="r86-open" ${busy?'disabled':open}><span class="r86-title">${esc(title)}</span></button><span class="r86-ledger">${esc(ledger)}</span></div>
        ${busy?icon('loader-circle'):''}<button class="r86-switch" ${switchAttr} role="switch" aria-checked="${row.enabled}" aria-label="${esc(t.recurringTransactionTitle+' · '+title)}" ${busy?'disabled':''}><span class="r86-switch-track"></span></button>
      </div>
      <div class="r86-amount ${row.type}" title="${esc((row.code||'')+' '+row.amount)}">${row.code?`<small>${esc(row.code)}</small>`:''}${esc(row.amount)}</div>
      <div class="r86-details"><span>${icon('repeat-2')}${esc(row.frequency)}</span>${row.last?`<span>${icon('clock')}${esc(t.v4RecurringLastGeneratedLabel+' '+row.last)}</span>`:''}</div>
      ${row.note?`<p class="r86-note">${esc(long?row.note.repeat(5):row.note)}</p>`:''}
    </article>`;
  }
  function r86Body(mode) {
    const t=r86Text;
    if(mode==='empty') return `<div class="r86-state">${icon('repeat-2')}<b>${esc(t.recurringTransactionEmpty)}</b><p>${esc(t.recurringTransactionEmptyHint)}</p>${btn('f-go:recurring-edit',esc(t.recurringTransactionAdd),t.recurringTransactionAdd,'bc-primary')}</div>`;
    if(mode==='loading') return `<div class="r86-state" role="status">${icon('loader-circle')}<p>正在加载</p></div>`;
    if(mode==='error') return `<div class="r86-state">${icon('circle-alert')}<b>${esc(t.commonError)}</b>${btn('r86-retry',esc(t.v4RecordingRetry),t.v4RecordingRetry,'bc-primary')}</div>`;
    return `<div class="r86-list"><section class="r86-rule r86-usage">${icon('info')}<div><b>${esc(t.recurringTransactionUsageTitle)}</b><p>${esc(t.recurringTransactionUsageContent)}</p></div></section>${mode==='save-error'?'<p class="r86-error" role="status">保存失败，已保留原开关状态，请重试。</p>':''}${state.r86Rows.map(row=>r86Card(row,{busy:mode==='saving',long:mode==='long'})).join('')}</div>`;
  }
  fDefine('recurring',r86Text.recurringTransactionTitle,'自动化与识别','transaction/recurring_transaction_page.dart',()=>r86Body('data'));
  for(const [suffix,title] of [['empty','空列表'],['loading','加载中'],['error','加载失败与重试'],['saving','启停保存中'],['long','长分类与账本名称'],['save-error','保存失败保持原状态']]) {
    fDefine('recurring-'+suffix,r86Text.recurringTransactionTitle+' · '+title,'自动化与识别','transaction/recurring_transaction_page.dart',()=>r86Body(suffix));
  }
  const r86RenderBefore=fRender;
  fRender=function(key) {
    if(r86Keys.has(key))return subhead(r86Text.recurringTransactionTitle,'f-go:recurring-edit','plus')+r86Body(key==='recurring'?'data':key.slice(10));
    return r86RenderBefore(key);
  };
  document.addEventListener('click',event=>{
    const toggle=event.target.closest('[data-r86-toggle]');
    if(toggle&&!toggle.disabled){
      event.preventDefault();event.stopImmediatePropagation();
      const row=state.r86Rows.find(x=>x.id===toggle.dataset.r86Toggle);
      if(row&&state.page!=='flow-recurring-save-error')row.enabled=!row.enabled;
      render();return;
    }
    if(event.target.closest('[data-action="r86-retry"]')) {
      event.preventDefault();event.stopImmediatePropagation();state.page='flow-recurring';render();
    }
  },true);
