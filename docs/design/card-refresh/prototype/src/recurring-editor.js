  // RE90 RECURRING EDITOR START
  const re90Text=__RECURRING_EDITOR_TEXTS__,re90Currencies=__RECURRING_EDITOR_CURRENCIES__;
  const re90Scenes=['recurring-edit','recurring-edit-new','recurring-edit-transfer','recurring-edit-daily','recurring-edit-weekly','recurring-edit-yearly','recurring-edit-saving','recurring-edit-error','recurring-edit-loading','recurring-edit-load-error','recurring-edit-long','recurring-edit-empty-accounts'];
  const re90Accounts=[{id:'1',name:'QA 人民币现金',currency:'CNY'},{id:'2',name:'QA USD 现金',currency:'USD'},{id:'3',name:'QA USD 银行',currency:'USD'},{id:'4',name:'QA 隐藏USD',currency:'USD',hidden:true}];
  const re90Today=()=>{const d=new Date();return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
  Object.assign(state,{re90Scene:'',re90Draft:null,re90Error:'',re90Busy:false,re90Saved:false,re90AccountSide:'from',re90AccountCommitted:false,re90Loaded:false});
  function re90Init(key){
    if(state.re90Scene===key)return;
    state.re90Scene=key;state.re90Error=key==='recurring-edit-error'?'QA 合成保存错误，草稿已保留':'';state.re90Busy=key==='recurring-edit-saving';state.re90Saved=false;state.re90Loaded=false;
    state.re90Draft={editing:key!=='recurring-edit-new',type:key==='recurring-edit-transfer'?'transfer':'expense',ledger:'0',currency:key==='recurring-edit-empty-accounts'?'JPY':'USD',amount:key==='recurring-edit-new'?'':'18.00',category:key==='recurring-edit-new'?'':'QA 咖啡',from:key==='recurring-edit-transfer'?'2':'',to:key==='recurring-edit-transfer'?'3':'',frequency:key==='recurring-edit-daily'?'daily':key==='recurring-edit-weekly'?'weekly':key==='recurring-edit-yearly'?'yearly':'monthly',interval:1,day:31,start:re90Today(),end:'',note:'QA 合成周期备注'};
  }
  const re90Base=()=>state.re90Draft.ledger==='1'?'USD':'CNY',re90Currency=()=>state.re90Draft.currency||re90Base();
  function re90Valid(){const d=state.re90Draft,raw=d.amount.trim(),number=raw!==''&&(!Number.isNaN(Number(raw))||/^nan$/i.test(raw));return number&&(d.type==='transfer'?d.from&&d.to&&d.from!==d.to:d.category);}
  function re90Label(key,value,glyph){return `<span class="re90-label">${icon(glyph)}${esc(re90Text[key]||key)}</span>${value}`;}
  function re90Select(name,label,values,current,glyph){return `<label class="re90-field">${re90Label(label,`<select data-re90-field="${name}" ${state.re90Busy?'disabled':''}>${values.map(([v,n])=>`<option value="${esc(v)}" ${String(v)===String(current)?'selected':''}>${esc(n)}</option>`).join('')}</select>`,glyph)}</label>`;}
  function re90AccountName(side){return re90Accounts.find(a=>a.id===state.re90Draft[side])?.name||re90Text.accountNone;}
  function re90FrequencyLabel(value){return re90Text['recurringTransaction'+({daily:'Daily',weekly:'Weekly',monthly:'Monthly',yearly:'Yearly'}[value])];}
  function re90IntervalLabel(value){return re90Text['recurringTransactionEveryN'+({daily:'Days',weekly:'Weeks',monthly:'Months',yearly:'Years'}[state.re90Draft.frequency])].replace('{n}',value);}
  function re90Body(key){
    re90Init(key);const d=state.re90Draft,t=re90Text;
    if(key==='recurring-edit-loading')return `<div class="re90-state" role="status">${icon('loader-circle')}${esc(t.mineCloudServiceLoading)}</div>`;
    if(key==='recurring-edit-load-error'&&!state.re90Loaded)return `<div class="re90-state">${icon('circle-alert')}<p>${esc(t.commonError)}</p>${btn('re90-retry',esc(t.v4RecordingRetry),t.v4RecordingRetry,'bc-primary')}</div>`;
    const ledgerOptions=[['0',key==='recurring-edit-long'?'QA 一个完整保留名称的家庭共享账本 · CNY':state.ledger+' · CNY'],['1','QA 美元账本 · USD']];
    const currencyOptions=re90Currencies.map(c=>[c.code,c.code+' · '+c.name]);
    const categories=d.type==='income'?['QA 工资','QA 奖金']:['QA 咖啡','QA 午餐'];
    return `<div class="re90-form"><div class="re90-types" role="group" aria-label="账单类型">${[['expense',t.categoryExpense],['income',t.categoryIncome],['transfer',t.transferTitle]].map(([v,n])=>btn('re90-type:'+v,esc(n),n,'',`aria-pressed="${d.type===v}" ${state.re90Busy?'disabled':''}`)).join('')}</div><section class="re90-card">${re90Select('ledger','ledgerSelectTitle',ledgerOptions,d.ledger,'book-open')}${re90Select('currency','txCurrencyLabel',currencyOptions,re90Currency(),'coins')}</section><section class="re90-card"><label class="re90-field">${re90Label('importFieldAmount',`<input data-re90-field="amount" inputmode="decimal" value="${esc(d.amount)}" ${state.re90Busy?'disabled':''}>`,'banknote')}</label></section><section class="re90-card">${d.type!=='transfer'?re90Select('category','categoryTitle',[['',t.commonSearch],...categories.map(x=>[x,x])],d.category,'shapes'):''}<button class="re90-field re90-choice" data-action="re90-account:from" ${state.re90Busy?'disabled':''}>${re90Label(d.type==='transfer'?'transferFromAccount':'accountSelectTitle',`<b>${esc(re90AccountName('from'))}</b>`,'wallet')}${icon('chevron-right')}</button>${d.type==='transfer'?`<button class="re90-field re90-choice" data-action="re90-account:to" ${state.re90Busy?'disabled':''}>${re90Label('transferToAccount',`<b>${esc(re90AccountName('to'))}</b>`,'arrow-right-left')}${icon('chevron-right')}</button>`:''}</section><section class="re90-card">${re90Select('frequency','recurringTransactionFrequency',['daily','weekly','monthly','yearly'].map(f=>[f,re90FrequencyLabel(f)]),d.frequency,'repeat-2')}${d.frequency!=='daily'?re90Select('interval','recurringTransactionInterval',Array.from({length:12},(_,i)=>[i+1,re90IntervalLabel(i+1)]),d.interval,'clock'):''}${d.frequency==='monthly'?re90Select('day','recurringTransactionDayOfMonth',Array.from({length:31},(_,i)=>[i+1,String(i+1)]),d.day,'calendar-days'):''}<label class="re90-field">${re90Label('recurringTransactionStartDate',`<input type="date" data-re90-field="start" value="${d.start}" min="${re90Today()}" max="2100-01-01" ${state.re90Busy?'disabled':''}>`,'calendar')}</label><div class="re90-date-row"><label class="re90-field">${re90Label('recurringTransactionEndDate',`<input type="date" data-re90-field="end" value="${d.end}" min="${d.start}" max="2100-01-01" aria-label="${esc(t.recurringTransactionEndDate)}" ${state.re90Busy?'disabled':''}>`,'calendar-check')}<small>${d.end?'':esc(t.recurringTransactionNoEndDate)}</small></label>${d.end?btn('re90-clear-end',icon('x'),t.commonRemove,'re90-clear',state.re90Busy?'disabled':''):''}</div></section><section class="re90-card"><label class="re90-field">${re90Label('commonNoteHint',`<textarea data-re90-field="note" rows="3" ${state.re90Busy?'disabled':''}>${esc(d.note)}</textarea>`,'notebook-pen')}</label></section>${state.re90Error?`<p class="re90-error" role="alert">${esc(state.re90Error)}</p>`:''}${state.re90Saved?'<p class="re90-saved" role="status">QA 局部示例已保存，不生成交易或写入真实周期配置</p>':''}<button class="bc-primary re90-save" data-action="re90-save" ${state.re90Busy||!re90Valid()?'disabled':''} aria-busy="${state.re90Busy}">${icon(state.re90Busy?'loader-circle':'check')}${esc(t.commonSave)}</button></div>`;
  }
  for(const key of re90Scenes)fDefine(key,re90Text.recurringTransactionEdit+' · '+key.replace('recurring-edit','原编辑流程'),'自动化与识别','transaction/recurring_transaction_edit_page.dart',()=>re90Body(key));
  const re90RenderBefore=fRender;fRender=function(key){if(re90Scenes.includes(key)){re90Init(key);const d=state.re90Draft;return `<div class="re90-shell">${subhead(d.editing?re90Text.recurringTransactionEdit:re90Text.recurringTransactionAdd,d.editing?'re90-delete-open':'','trash-2')}${re90Body(key)}</div>`;}return re90RenderBefore(key);};
  rSpecs['re90-account']={title:re90Text.accountSelectTitle,host:'flow-recurring-edit',kind:'dialog'};
  rSpecs['re90-delete']={title:re90Text.commonDelete,host:'flow-recurring-edit',kind:'dialog'};
  const re90ModalBefore=rModalBody;rModalBody=function(key){
    if(key==='re90-account'){
      const side=state.re90AccountSide,d=state.re90Draft,rows=re90Accounts.filter(a=>a.currency===re90Currency()&&!a.hidden&&(side!=='to'||a.id!==d.from));
      return `<div class="re90-account-list">${side==='from'?btn('re90-account-set:',esc(re90Text.accountNone),re90Text.accountNone,'re90-account-option'):''}${rows.map(a=>btn('re90-account-set:'+a.id,esc(a.name),a.name,'re90-account-option')).join('')}${!rows.length&&side==='to'?`<p>${esc(re90Text.commonEmpty)}</p>`:''}</div>${rModalActions('re90-account-cancel',re90Text.commonCancel,'re90-account-cancel',re90Text.commonClose)}`;
    }
    if(key==='re90-delete')return `<p>${esc(re90Text.recurringTransactionDeleteConfirm)}</p>${rModalActions('r-close',re90Text.commonCancel,'re90-delete',re90Text.commonDelete)}`;
    return re90ModalBefore(key);
  };
  const re90DismissBefore=rDismiss;rDismiss=function(){if(state.rModal==='re90-account'&&!state.re90AccountCommitted&&state.re90Draft)state.re90Draft[state.re90AccountSide]='';return re90DismissBefore();};
  document.addEventListener('input',event=>{
    const input=event.target.closest('[data-re90-field]');if(!input||!['amount','note'].includes(input.dataset.re90Field))return;
    state.re90Draft[input.dataset.re90Field]=input.value;
    const save=phone.querySelector('.re90-save');if(save)save.disabled=state.re90Busy||!re90Valid();
  });
  document.addEventListener('change',event=>{
    const input=event.target.closest('[data-re90-field]');if(!input||['amount','note'].includes(input.dataset.re90Field))return;
    const field=input.dataset.re90Field,d=state.re90Draft;
    d[field]=['interval','day'].includes(field)?Number(input.value):input.value;
    if(field==='currency'){d.currency=input.value===re90Base()?null:input.value;d.from='';d.to='';}
    if(field==='ledger'&&d.currency===re90Base())d.currency=null;
    if(field==='frequency'&&d.frequency==='daily')d.interval=1;
    render();
  });
  document.addEventListener('click',event=>{
    const demo=event.target.closest('[data-re90-demo]');if(demo){const out=demo.closest('.re90-guide')?.querySelector('[data-re90-demo-result]');if(out)out.textContent='QA 局部草稿已更新，不写入真实周期配置';return;}
    const el=event.target.closest('[data-action]');if(!el||!el.dataset.action.startsWith('re90-')||el.disabled)return;
    event.preventDefault();event.stopImmediatePropagation();const [action,value]=el.dataset.action.split(':'),d=state.re90Draft;
    if(action==='re90-type'){d.type=value;d.category='';if(value!=='transfer')d.to='';render();}
    else if(action==='re90-account'){state.re90AccountSide=value;state.re90AccountCommitted=false;rSpecs['re90-account'].title=value==='to'?re90Text.transferToAccount:d.type==='transfer'?re90Text.transferFromAccount:re90Text.accountSelectTitle;rOpenModal('re90-account');}
    else if(action==='re90-account-set'){d[state.re90AccountSide]=value;if(state.re90AccountSide==='from'&&value===d.to)d.to='';state.re90AccountCommitted=true;rDismiss();render();}
    else if(action==='re90-account-cancel'){rDismiss();render();}
    else if(action==='re90-clear-end'){d.end='';render();}
    else if(action==='re90-retry'){state.re90Loaded=true;render();}
    else if(action==='re90-delete-open')rOpenModal('re90-delete');
    else if(action==='re90-delete'){rDismiss();state.re90Saved=false;state.re90Error='';render();notice('QA 局部删除示例，不修改真实周期配置');}
    else if(action==='re90-save'&&re90Valid()){state.re90Busy=true;state.re90Error='';render();setTimeout(()=>{state.re90Busy=false;state.re90Saved=true;render();},250);}
  },true);
  // RE90 RECURRING EDITOR END
