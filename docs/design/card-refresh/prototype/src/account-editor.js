  const aEditorIcons=__ACCOUNT_EDITOR_ICONS__;
  const aEditorTypes=[['cash','现金','daily'],['bank_card','银行卡','daily'],['credit_card','信用卡','daily'],['alipay','支付宝','daily'],['wechat','微信','daily'],['other','其他','daily'],['real_estate','房产','valuation'],['vehicle','车辆','valuation'],['investment','投资','valuation'],['insurance','保险','valuation'],['social_fund','社保公积金','valuation'],['loan','贷款','valuation']];
  let aEditorDraft=null,aEditorRoute='',aEditorMode=false,aEditorDay='';
  function aEditorInit(){
    const route=state.page.replace(/^flow-/,'');
    if(aEditorRoute===route&&aEditorDraft)return aEditorDraft;
    aEditorRoute=route;
    const fresh=route==='account-new',credit=route==='account-credit',valuation=route==='account-valuation';
    return aEditorDraft={fresh,hasTransactions:!fresh&&!credit&&!valuation,group:valuation?'valuation':'daily',lockedGroup:valuation?'valuation':'daily',type:valuation?'investment':credit?'credit_card':fresh?'cash':'bank_card',name:fresh?'':valuation?'长期投资':credit?'日常信用卡':'招商银行',currency:'CNY',balance:fresh?'':valuation?'50000.00':credit?'3200.00':'28640.50',original:credit?-3200:28640.5,overpayment:false,creditLimit:credit?'20000':'',billingDay:credit?12:null,paymentDueDay:credit?28:null,bankName:fresh?'':'招商银行',lastFour:fresh?'':'8862',note:fresh?'':'日常使用',reminder:false,lead:3,hidden:false};
  }
  function aEditorField(key,label,{number=false,required=false,maxlength='',multiline=false,prefix=''}={}){
    const d=aEditorInit(),attrs=`data-ae-field="${key}" aria-label="${label}" ${required?'required':''} ${maxlength?`maxlength="${maxlength}"`:''}`;
    return `<label class="f-field ae-field"><span>${label}</span><div class="ae-input-wrap">${prefix?`<span>${esc(prefix)}</span>`:''}${multiline?`<textarea ${attrs} rows="3">${esc(d[key])}</textarea>`:`<input ${attrs} type="${number?'number':'text'}" ${number?'step="any"':''} ${number&&key==='balance'&&d.type==='credit_card'?'min="0"':''} ${key==='creditLimit'?'min="0.0000001"':''} value="${esc(d[key])}">`}</div>${key==='lastFour'?`<small class="ae-counter">${d[key].length}/4</small>`:''}</label>`;
  }
  function aEditorDayField(key,label){const d=aEditorInit();return `<div class="ae-day-row">${btn('ae-day:'+key,`<span>${label}<small>${d[key]===null?'请选择日期':`每月 ${d[key]} 日`}</small></span>${icon('chevron-down')}`,'选择'+label)}${d[key]===null?'':btn('ae-clear-day:'+key,icon('x'),'清除'+label)}</div>`;}
  function aEditorBody(){
    const d=aEditorInit(),credit=d.type==='credit_card',bank=d.type==='bank_card',valuation=d.lockedGroup==='valuation';
    const typeGrid=aEditorTypes.filter(t=>t[2]===d.group).map(([type,label,group])=>btn('ae-type:'+type,`${bcAccountVisual(type)}<span>${label}</span>`,'选择'+label,'',`aria-pressed="${d.type===type}" ${!d.fresh&&group!==d.lockedGroup?'disabled':''}`)).join('');
    const bankFields=`<div class="ae-bank-fields">${aEditorField('bankName','银行名称')}${aEditorField('lastFour','卡号后四位',{maxlength:4})}</div>`;
    return `<div class="ae-shell"><div class="ae-scroll">${surface(`<div class="bc-segment ae-groups">${[['daily','日常账户'],['valuation','估值账户']].map(([g,n])=>btn('ae-group:'+g,n,n,'',`aria-pressed="${d.group===g}"`)).join('')}</div><div class="ae-type-grid">${typeGrid}</div>`)}${surface(aEditorField('name','账户名称',{required:true})+btn('ae-currency',`${icon('globe')}<span>币种<small>${d.currency} · ${d.currency==='CNY'?'人民币':d.currency==='USD'?'美元':d.currency}</small></span>${icon('chevron-right')}`,'选择账户币种','ae-menu')+(!d.fresh&&valuation?'':aEditorField('balance',d.fresh?credit?'初始欠款':d.type==='loan'?'初始欠款':'初始余额':credit?'当前欠款':'当前余额',{number:true,prefix:d.currency==='USD'?'US$':'¥'}))+(credit?`<div class="bc-segment">${[[false,'欠款'],[true,'溢缴款']].map(([v,n])=>btn('ae-overpayment:'+v,n,n,'',`aria-pressed="${d.overpayment===v}"`)).join('')}</div>`:''))}${credit?surface(`<h3>信用卡设置</h3>${aEditorField('creditLimit','信用额度',{number:true})}<div class="ae-days">${aEditorDayField('billingDay','账单日')}${aEditorDayField('paymentDueDay','还款日')}</div><hr>${bankFields}<label class="ae-toggle"><span>还款提醒<small>在还款日前提醒</small></span><input type="checkbox" class="v4-switch" role="switch" data-ae-reminder aria-label="还款提醒" ${d.reminder?'checked':''}></label>${d.reminder?`<div class="bc-segment ae-lead">${[1,3,5,7].map(v=>btn('ae-lead:'+v,`提前${v}天`,`提前${v}天`,'',`aria-pressed="${v===d.lead}"`)).join('')}</div>`:''}`):bank?surface(`<h3>账户信息</h3>${bankFields}`):''}${surface(aEditorField('note','备注',{multiline:true}))}${d.fresh?'':menuCard([['ae-hide','eye-off',d.hidden?'恢复账户':'隐藏账户','保留历史流水'],['ae-delete','trash-2','删除账户','删除前核对关联账单']])}</div><div class="ae-footer">${btn('ae-save','保存','保存账户','bc-primary')}</div></div>`;
  }
  fDefs['account-edit'].body=aEditorBody;
  let aEditorPreviewGroup=[...picker.querySelectorAll('optgroup')].find(g=>g.label==='补齐 · 账户与资产');
  if(!aEditorPreviewGroup){aEditorPreviewGroup=document.createElement('optgroup');aEditorPreviewGroup.label='补齐 · 账户与资产';picker.appendChild(aEditorPreviewGroup);}
  for(const [key,title] of [['account-new','新建账户'],['account-credit','编辑信用卡'],['account-valuation','编辑估值账户']]){fDefine(key,title,'账户与资产','account/account_edit_page.dart',aEditorBody);aEditorPreviewGroup.appendChild(new Option(title+' · 完整表单','flow-'+key));}
  const aEditorPreviousRender=fRender;
  fRender=function(key){if(!['account-edit','account-new','account-credit','account-valuation'].includes(key))return aEditorPreviousRender(key);return subhead(fDefs[key].title)+aEditorBody();};
  const aEditorAfterRender=qAfterRender;
  qAfterRender=function(){aEditorAfterRender();phone.dataset.aeScale=String(qPreview.scale);};
  const aEditorPreviousModal=rModalBody;
  rModalBody=function(key){
    if(!key.startsWith('ae-'))return aEditorPreviousModal(key);
    const d=aEditorInit();
    if(key==='ae-day')return `<div class="ae-day-grid">${Array.from({length:28},(_,i)=>btn('ae-pick-day:'+(i+1),i+1,`${i+1}日`,'',`aria-pressed="${d[aEditorDay]===i+1}"`)).join('')}</div>`;
    if(key==='ae-currency')return `<label class="ae-search">${icon('search')}<input aria-label="搜索账户币种" placeholder="搜索币种" data-ae-query></label><div class="ae-currencies">${wCurrencies.map(c=>btn('ae-pick-currency:'+c.code,`${esc(wCurrencyName(c))} (${c.code})${c.code===d.currency?icon('check'):''}`,c.code,'',`data-ae-code="${c.code} ${esc(wCurrencyName(c))}"`)).join('')}</div>`;
    if(key==='ae-locked')return '<p>该账户已有交易，无法修改币种。</p>'+rModalActions('r-close','取消','r-close','确定');
    if(key==='ae-adjust'){
      const target=Number(d.balance)*(d.type==='credit_card'&&!d.overpayment?-1:1),difference=target-d.original,symbol=d.currency==='USD'?'US$':'¥',money=n=>(n<0?'−':'')+symbol+Math.abs(n).toFixed(2);
      return `<p class="ae-adjust-caption">请选择这次余额变更的保存方式</p><div class="ae-balance-summary"><div class="ae-balance-pair"><div><small>当前余额</small><strong>${money(d.original)}</strong></div>${icon('arrow-right')}<div><small>调整后余额</small><strong>${money(target)}</strong></div></div><hr><div class="ae-difference"><span>本次差额</span><strong style="color:${difference>0?'#22c55e':difference<0?'#ef4444':'var(--bc-muted)'}">${difference>0?'+':''}${money(difference)}</strong></div></div><div class="bc-segment ae-adjust-modes">${[[false,'仅修改余额'],[true,'生成平账交易']].map(([mode,title])=>btn('ae-adjust-mode:'+mode,title,'选择'+title,'',`aria-pressed="${aEditorMode===mode}"`)).join('')}</div><p class="ae-adjust-caption">${aEditorMode?'同时新增一笔普通收入或支出，归入“平账”分类，并计入收支和预算统计。':'不创建交易；历史余额趋势会按新的余额基线重新计算。'}</p>${btn('ae-confirm-save',`${icon('check')}${aEditorMode?'确认并生成平账交易':'确认仅修改余额'}`,'确认保存账户','bc-primary ae-wide')}`;
    }
    if(key==='ae-hide'||key==='ae-delete')return `<p>${key==='ae-delete'?(d.hasTransactions?'该账户有 8 笔关联交易，删除后交易记录中的账户信息将被清空。确认删除吗？':'确认删除该账户吗？'):'隐藏后无法再记账到它，新增记账时也不再显示；历史交易与余额保留，可随时恢复。'}</p>`+rModalActions('r-close','取消',key==='ae-hide'?'ae-confirm-hide':'ae-confirm-delete','确认');
    return '';
  };
  for(const [key,title,kind] of [['ae-day','选择日期','sheet'],['ae-currency','选择币种','sheet'],['ae-locked','提示','dialog'],['ae-adjust','确认余额变更','sheet'],['ae-hide','隐藏账户','dialog'],['ae-delete','删除账户','dialog']])rSpecs[key]={title,host:'flow-account-edit',kind};
  function aEditorRedraw(){const scroll=phone.querySelector('.ae-scroll')?.scrollTop||0;render();phone.querySelector('.ae-scroll')?.scrollTo(0,scroll);}
  root.addEventListener('input',e=>{if(e.target.matches('[data-ae-field]')){aEditorInit()[e.target.dataset.aeField]=e.target.value;e.target.setCustomValidity('');const counter=e.target.closest('label')?.querySelector('.ae-counter');if(counter)counter.textContent=e.target.value.length+'/4';}if(e.target.matches('[data-ae-query]'))for(const b of phone.querySelectorAll('[data-ae-code]'))b.hidden=!b.dataset.aeCode.toLowerCase().includes(e.target.value.toLowerCase());});
  root.addEventListener('change',e=>{if(e.target.matches('[data-ae-reminder]')){aEditorInit().reminder=e.target.checked;aEditorRedraw();}});
  root.addEventListener('click',e=>{
    const el=e.target.closest('[data-action^="ae-"]');if(!el)return;e.preventDefault();e.stopImmediatePropagation();
    const [action,arg]=el.dataset.action.split(':'),d=aEditorInit();
    if(action==='ae-group'){d.group=arg;aEditorRedraw();}
    else if(action==='ae-type'){const previous=d.type;if(previous!==arg&&(previous==='credit_card'||arg==='credit_card')){const signed=Number(d.balance)*(previous==='credit_card'&&!d.overpayment?-1:1);d.overpayment=signed>0;d.balance=String(arg==='credit_card'?Math.abs(signed):signed);}d.type=arg;if(previous==='credit_card'&&arg!=='credit_card'){d.creditLimit='';d.billingDay=null;d.paymentDueDay=null;d.reminder=false;}if(!['bank_card','credit_card'].includes(arg)){d.bankName='';d.lastFour='';}aEditorRedraw();}
    else if(action==='ae-overpayment'){d.overpayment=arg==='true';aEditorRedraw();}
    else if(action==='ae-lead'){d.lead=Number(arg);aEditorRedraw();}
    else if(action==='ae-day'){aEditorDay=arg;rSpecs['ae-day'].title=arg==='billingDay'?'账单日':'还款日';rOpenModal('ae-day');}
    else if(action==='ae-clear-day'){d[arg]=null;aEditorRedraw();}
    else if(action==='ae-pick-day'){d[aEditorDay]=Number(arg);rDismiss();aEditorRedraw();}
    else if(action==='ae-currency')rOpenModal(d.hasTransactions?'ae-locked':'ae-currency');
    else if(action==='ae-pick-currency'){d.currency=arg;rDismiss();aEditorRedraw();}
    else if(action==='ae-hide'||action==='ae-delete'){rSpecs[action].title=action==='ae-hide'?'隐藏此账户？':d.hasTransactions?'确认删除':'确定';rOpenModal(action);}
    else if(action==='ae-confirm-hide'){d.hidden=true;rDismiss();aEditorRedraw();notice('账户已隐藏（演示草稿）');}
    else if(action==='ae-confirm-delete'){rDismiss();notice('账户已删除（演示草稿）');navigate('accounts');}
    else if(action==='ae-adjust-mode'){aEditorMode=arg==='true';rBuildModal();}
    else if(action==='ae-confirm-save'){rDismiss();notice(aEditorMode?'账户与平账记录已保存（演示）':'账户余额已保存（演示）');}
    else if(action==='ae-save'){
      for(const input of phone.querySelectorAll('[data-ae-field]'))if(!input.reportValidity())return;
      if(!d.name.trim()){const input=phone.querySelector('[data-ae-field="name"]');input.setCustomValidity('请输入账户名称');input.reportValidity();return;}
      if(d.type==='credit_card'&&d.reminder&&d.paymentDueDay===null){notice('请先选择还款日','error');return;}
      const target=Number(d.balance)*(d.type==='credit_card'&&!d.overpayment?-1:1);
      if(!d.fresh&&d.lockedGroup==='daily'&&target!==d.original){aEditorMode=false;rOpenModal('ae-adjust');}else notice('账户已保存（演示草稿）');
    }
  },true);
