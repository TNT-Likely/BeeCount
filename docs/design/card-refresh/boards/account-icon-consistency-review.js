(() => {
  'use strict';
  const {esc,icon,status,toast,bindControls,phone}=SelectionReview;
  const typeLabels={cash:'现金',bank_card:'银行卡',credit_card:'信用卡',alipay:'支付宝',wechat:'微信',other:'其他账户',real_estate:'房产',vehicle:'车辆',investment:'投资',insurance:'保险',social_fund:'公积金',loan:'贷款',receivable:'应收款'};
  const daily=['cash','bank_card','credit_card','alipay','wechat','other'];
  const valuation=['real_estate','vehicle','investment','insurance','social_fund','loan'];
  const accounts=[
    {id:'wechat',name:'微信零钱',type:'wechat',currency:'CNY',balance:8760.50},
    {id:'bank',name:'招商银行日常储蓄与家庭备用金',type:'bank_card',currency:'CNY',balance:28640.50,detail:'尾号 8862'},
    {id:'alipay',name:'支付宝余额',type:'alipay',currency:'CNY',balance:2108.32},
    {id:'cash',name:'随身现金',type:'cash',currency:'CNY',balance:360},
    {id:'credit',name:'日常信用卡',type:'credit_card',currency:'CNY',balance:-3200,detail:'尾号 5580'},
    {id:'unknown',name:'自定义钱包',type:'custom_unmapped',currency:'CNY',balance:1500,detail:'未知类型 · 钱包兜底'},
    {id:'usd',name:'旅行美元现金',type:'cash',currency:'USD',balance:1240.75},
    {id:'hidden',name:'旧微信账户',type:'wechat',currency:'CNY',balance:29.20,hidden:true},
  ];
  const initialAccounts=accounts.map(a=>({...a}));
  const state={scene:'assets',style:'original',case:'normal',account:'wechat',query:'',overlay:null,typeGroup:'daily',typeDraft:'wechat',tab:'all'};
  const account=()=>accounts.find(a=>a.id===state.account);
  const knownType=type=>ACCOUNT_REVIEW_SVGS[type]?type:'other';
  function accountIcon(type,extra=''){
    const resolved=knownType(type),source=ACCOUNT_REVIEW_SVGS[resolved];
    return `<span class="account-icon ${extra}" data-account-type="${esc(type)}" data-resolved-type="${resolved}" style="--account-image:url('${source}')"><img src="${source}" alt="" draggable="false"><i class="mono-fill" aria-hidden="true"></i></span>`;
  }
  const label=a=>typeLabels[a.type]||'其他账户';
  const money=a=>`${a.currency==='USD'?'$':'¥'}${a.balance.toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2})}`;
  const meta=a=>`${a.currency} · ${a.hidden?'已隐藏':a.detail||label(a)}`;
  function row(a,select=false,amount=true){return `<button class="account-row" data-account="${a.id}" ${select?`aria-pressed="${state.account===a.id}"`:''} aria-label="${esc(a.name)}，${esc(label(a))}，${money(a)}${a.hidden?'，已隐藏':''}">${accountIcon(a.type)}<span class="account-copy"><span class="account-name">${esc(a.name)}${a.hidden?'<i class="hidden-badge">已隐藏</i>':''}</span><span class="account-meta">${esc(meta(a))}</span></span>${amount?`<span class="account-amount">${money(a)}</span>`:''}${select?`<span class="check-ring">${state.account===a.id?icon('check'):''}</span>`:icon('right')}</button>`;}
  function header(title,back='assets',action='more'){return `${status()}<header class="app-header"><button class="icon-button" data-scene-to="${back}" aria-label="返回">${icon('back')}</button><h2>${title}</h2><button class="icon-button" data-action="${action}" aria-label="更多操作">${icon('more')}</button></header>`;}
  function nav(){return `<nav class="bottom-nav" aria-label="底部导航"><button data-action="nav" aria-label="明细">${icon('home')}明细</button><button data-action="nav" aria-label="统计">${icon('chart')}统计</button><button class="nav-plus" data-scene-to="picker" aria-label="记一笔">${icon('plus')}</button><button aria-current="page" data-scene-to="assets">${icon('wallet')}资产</button><button data-action="nav" aria-label="我的">${icon('user')}我的</button></nav>`;}
  function renderAssets(){
    const visible=accounts.filter(a=>!a.hidden);
    phone.innerHTML=`${status()}<div class="screen-content"><header class="asset-title"><h2>资产</h2><div class="asset-actions"><button class="icon-button" data-scene-to="picker" aria-label="选择账户">${icon('search')}</button><button class="icon-button" data-scene-to="types" aria-label="添加账户">${icon('plus')}</button></div></header><section class="card asset-summary"><div class="balance-caption">净资产 · CNY ${icon('eye')}</div><div class="net-amount number"><small>¥</small>38,169.32</div><div class="asset-metrics"><div><span>总资产</span><strong class="number">¥41,369.32</strong></div><div><span>总负债</span><strong class="number">¥3,200.00</strong></div></div></section><h3 class="asset-subtitle">日常账户 <span>${visible.length} 个</span></h3><section class="card account-list">${visible.map(a=>row(a)).join('')}</section><p class="detail-note">外币账户按原币展示，净资产示例不包含未折算美元。</p></div>${nav()}<div class="home-indicator"></div>`;
  }
  function renderEntry(){
    const a=account();
    phone.innerHTML=`${header('编辑账单')}<div class="screen-content edit-shell"><div class="type-tabs"><button aria-pressed="true">支出</button><button data-action="income">收入</button><button data-action="transfer">转账</button></div><div class="edit-amount"><small>${state.case==='foreign'?'USD':'CNY'}</small>38.00</div><section class="card"><div class="info-row"><span>分类</span><strong>${icon('coffee')}餐饮</strong></div><div class="info-row"><span>日期</span><strong>2026.10.26</strong></div></section><span class="field-title">账户</span><button class="entry-preview" data-action="open-picker">${a?accountIcon(a.type):`<span class="no-account-icon">${icon('wallet')}</span>`}<span class="account-copy"><span class="account-name">${a?esc(a.name):'无账户'}</span><span class="account-meta">${a?esc(meta(a)):'这笔账单不关联账户'}</span></span>${icon('right')}</button><p class="detail-note">选择账户后，即可在这个摘要与资产列表中核对同一图标。</p></div><footer class="phone-footer"><button class="primary" data-action="save-entry">保存账单</button></footer><div class="home-indicator"></div>`;
  }
  function renderDetail(){
    const a=account();if(!a){state.account='wechat';return renderDetail();}
    phone.innerHTML=`${header('账户详情')}<div class="screen-content"><section class="card detail-account-hero"><div class="detail-identity">${accountIcon(a.type,'large')}<span class="account-copy"><span class="account-name">${esc(a.name)}</span><span class="account-meta">${esc(meta(a))}</span></span><button class="icon-button" data-scene-to="picker" aria-label="切换账户">${icon('right')}</button></div><span class="balance-caption">当前余额</span><div class="net-amount number">${money(a)}</div><div class="detail-properties"><div><small>账户类型</small><strong>${esc(label(a))}</strong></div><div><small>币种</small><strong>${a.currency}</strong></div><div><small>计入净资产</small><strong>${a.hidden?'未计入':'已计入'}</strong></div></div></section><div class="detail-actions"><button class="secondary" data-scene-to="types">编辑类型</button><button class="primary" data-scene-to="picker">切换账户</button></div>${a.hidden?'<p class="detail-note">这是历史账单关联的隐藏账户，仍保留原图标便于辨认。</p>':''}<div class="detail-tab"><button data-tab="all" aria-pressed="${state.tab==='all'}">全部</button><button data-tab="expense" aria-pressed="${state.tab==='expense'}">支出</button><button data-tab="income" aria-pressed="${state.tab==='income'}">收入</button></div><section class="card">${state.tab!=='income'?`<div class="detail-transaction"><span>餐饮 · 咖啡<small>10.26 14:32 · 日常生活</small></span><strong>−38.00</strong></div><div class="detail-transaction"><span>生活用品<small>10.24 11:20 · 家庭账本</small></span><strong>−126.00</strong></div>`:''}${state.tab!=='expense'?'<div class="detail-transaction"><span>退款<small>10.23 09:48 · 日常生活</small></span><strong>+68.00</strong></div>':''}</section></div><div class="home-indicator"></div>`;
  }
  function typeButton(type){return `<button class="type-option" data-type="${type}" aria-pressed="${state.typeDraft===type}">${accountIcon(type)}<span>${typeLabels[type]}</span>${state.typeDraft===type?`<i class="type-check">${icon('check')}</i>`:''}</button>`;}
  function renderTypes(){
    const a=account()||accounts[0];
    phone.innerHTML=`${header('账户类型')}<div class="screen-content"><p class="field-title" style="margin-top:9px">当前选择</p><div class="selected-type">${accountIcon(state.typeDraft,'large')}<span class="account-copy"><span class="account-name">${typeLabels[state.typeDraft]||'其他账户'}</span><span class="account-meta">${esc(a.name)}</span></span></div><div class="type-tabs"><button data-group="daily" aria-pressed="${state.typeGroup==='daily'}">日常账户</button><button data-group="valuation" aria-pressed="${state.typeGroup==='valuation'}">估值账户</button></div><div class="type-caption"><span>${state.typeGroup==='daily'?'用于日常收支与转账':'手动更新价值，不参与日常记账'}</span></div><div class="type-grid">${(state.typeGroup==='daily'?daily:valuation).map(typeButton).join('')}</div><p class="detail-note">切换分组保留当前选择。原色 / 单色切换同步作用于所有类型。</p><p class="detail-note">未知类型的展示兜底：${esc(typeLabels[knownType('custom_unmapped')])}</p></div><footer class="phone-footer"><button class="secondary" data-scene-to="detail">取消</button><button class="primary" data-action="save-type">保存类型</button></footer><div class="home-indicator"></div>`;
  }
  function render(){
    closeOverlay();
    phone.classList.toggle('icon-style-mono',state.style==='mono');phone.classList.toggle('icon-style-original',state.style==='original');
    ({assets:renderAssets,picker:renderEntry,detail:renderDetail,types:renderTypes})[state.scene]();bindPhone();updateCaption();
    if(state.scene==='picker')openPicker();
  }
  function go(scene){
    state.scene=scene;if(scene==='types'){state.typeDraft=account()?.type||'other';state.typeGroup=valuation.includes(state.typeDraft)?'valuation':'daily';}
    document.querySelectorAll('[data-scene]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.scene===scene)));render();
  }
  function updateCaption(){document.querySelector('#scene-caption').textContent=`${{assets:'资产列表',picker:'账户选择',detail:'详情摘要',types:'编辑类型'}[state.scene]} / ${state.style==='original'?'原 SVG 配色':'中性单色'}`;}
  function bindPhone(){
    phone.querySelectorAll('[data-account]').forEach(b=>b.addEventListener('click',()=>{state.account=b.dataset.account;go('detail');}));
    phone.querySelectorAll('[data-scene-to]').forEach(b=>b.addEventListener('click',()=>go(b.dataset.sceneTo)));
    phone.querySelectorAll('[data-group]').forEach(b=>b.addEventListener('click',()=>{state.typeGroup=b.dataset.group;render();}));
    phone.querySelectorAll('[data-type]').forEach(b=>b.addEventListener('click',()=>{state.typeDraft=b.dataset.type;render();}));
    phone.querySelectorAll('[data-tab]').forEach(b=>b.addEventListener('click',()=>{state.tab=b.dataset.tab;render();}));
    phone.querySelector('[data-action=save-type]')?.addEventListener('click',()=>{
      const a=account()||accounts[0];a.type=state.typeDraft;state.account=a.id;go('detail');toast('已保存示例类型，其他入口同步更新');renderComparison();
    });
    phone.querySelector('[data-action=open-picker]')?.addEventListener('click',openPicker);
    for(const [action,message]of [['nav','本轮只预览账户相关入口'],['more','本轮只确认图标一致性'],['save-entry','已保存示例账单'],['income','本轮保留支出示例'],['transfer','本轮保留支出示例']]) phone.querySelectorAll(`[data-action=${action}]`).forEach(b=>b.addEventListener('click',()=>toast(message)));
  }
  function closeOverlay(){phone.querySelector('.overlay')?.remove();state.overlay=null;}
  function openPicker(){
    closeOverlay();state.query='';const overlay=document.createElement('div');overlay.className='overlay';overlay.innerHTML=`<section class="sheet account-picker" role="dialog" aria-modal="true" aria-labelledby="account-picker-title"><div class="grabber"></div><div class="sheet-head"><h3 id="account-picker-title">选择账户</h3><button class="icon-button" data-close aria-label="关闭账户选择器">${icon('close')}</button></div><label class="search">${icon('search')}<input type="search" id="account-search" placeholder="搜索账户名称或类型" aria-label="搜索账户名称或类型"><button data-clear-query aria-label="清空搜索" hidden>${icon('close')}</button></label><div class="sheet-summary"><span>${state.case==='foreign'?'USD':'CNY'} · 日常可交易账户</span><span id="account-count"></span></div><div class="sheet-scroll" id="account-options"></div><p class="sheet-note">${state.case==='hidden'?'仅当前历史账单的隐藏账户被保留，可原样保存。':'原色与单色均使用相同 SVG；主题色只标记当前选择。'}</p></section>`;phone.append(overlay);state.overlay='picker';
    overlay.querySelector('[data-close]').addEventListener('click',closeOverlay);
    overlay.addEventListener('click',e=>{if(e.target===overlay)closeOverlay();});
    overlay.querySelector('input').addEventListener('input',e=>{state.query=e.target.value;renderOptions();});
    overlay.querySelector('[data-clear-query]').addEventListener('click',()=>{state.query='';overlay.querySelector('input').value='';renderOptions();overlay.querySelector('input').focus();});
    renderOptions();overlay.querySelector('[data-close]').focus({preventScroll:true});
  }
  function renderOptions(){
    const q=state.query.trim().toLocaleLowerCase(),currency=state.case==='foreign'?'USD':'CNY';
    const filtered=accounts.filter(a=>a.currency===currency&&(!a.hidden||(state.case==='hidden'&&a.id==='hidden'))&&daily.includes(knownType(a.type))).filter(a=>`${a.name} ${label(a)} ${a.currency}`.toLocaleLowerCase().includes(q));
    const options=phone.querySelector('#account-options');if(!options)return;
    options.innerHTML=`${!q?`<button class="account-row" data-unset aria-pressed="${state.account===null}"><span class="no-account-icon">${icon('wallet')}</span><span class="account-copy"><span class="account-name">无账户</span><span class="account-meta">不关联账户</span></span><span class="check-ring">${state.account===null?icon('check'):''}</span></button>`:''}${filtered.length?filtered.map(a=>row(a,true)).join(''):`<div class="empty">${icon('search')}<strong>没有找到匹配账户</strong>试试名称、类型或清除搜索</div>`}`;
    phone.querySelector('#account-count').textContent=`${filtered.length} 个`;phone.querySelector('[data-clear-query]').hidden=!q;
    options.querySelectorAll('[data-account]').forEach(b=>b.addEventListener('click',()=>{state.account=b.dataset.account;closeOverlay();renderEntry();bindPhone();toast(`已选择${account().name}`);}));
    options.querySelector('[data-unset]')?.addEventListener('click',()=>{state.account=null;closeOverlay();renderEntry();bindPhone();toast('已设为无账户');});
  }
  function renderComparison(){
    const sample=accounts.filter(a=>['wechat','bank','alipay'].includes(a.id));const a=accounts[0];
    document.querySelector('#comparison-grid').innerHTML=['original','mono'].map(style=>`<article class="compare-panel icon-style-${style}" data-appearance="${phone.dataset.appearance}" data-accent="${phone.dataset.accent}"><h3>${style==='original'?'A · 原 SVG 配色':'B · 中性单色'}</h3><p>${style==='original'?'保留品牌识别与图形内部层次。建议采用。':'形状与颜色更统一；当前实心底板会合并内部细节。'}</p><h4 class="mini-heading">01 资产列表</h4><div class="card">${sample.map(a=>row(a)).join('')}</div><h4 class="mini-heading">02 账户选择弹窗</h4><div class="account-picker"><div class="card">${row(a,true)}</div></div><h4 class="mini-heading">03 详情摘要</h4><div class="card mini-summary">${accountIcon(a.type,'large')}<span><small>${esc(a.name)} · 当前余额</small><strong>${money(a)}</strong></span></div><h4 class="mini-heading">04 编辑类型选择</h4><div class="type-grid">${daily.map(typeButton).join('')}</div></article>`).join('');
    document.querySelectorAll('#comparison-grid [data-account]').forEach(b=>b.addEventListener('click',()=>{state.account=b.dataset.account;go('detail');phone.scrollIntoView({behavior:'smooth',block:'center'});}));
    document.querySelectorAll('#comparison-grid [data-type]').forEach(b=>b.addEventListener('click',()=>{go('types');state.typeDraft=b.dataset.type;render();phone.scrollIntoView({behavior:'smooth',block:'center'});}));
  }
  function toggleComparison(show){document.querySelector('#comparison').hidden=!show;document.querySelector('#compare-toggle').setAttribute('aria-pressed',String(show));if(show){renderComparison();document.querySelector('#comparison').scrollIntoView({behavior:'smooth',block:'start'});}}
  function applyCase(value){state.case=value;document.querySelector('#account-case').value=value;state.account=({normal:'wechat',hidden:'hidden',unknown:'unknown',foreign:'usd'})[value];render();renderComparison();}
  document.querySelectorAll('[data-scene]').forEach(b=>b.addEventListener('click',()=>go(b.dataset.scene)));
  document.querySelector('#icon-style').addEventListener('change',e=>{state.style=e.target.value;phone.classList.toggle('icon-style-mono',state.style==='mono');phone.classList.toggle('icon-style-original',state.style==='original');updateCaption();});
  document.querySelector('#account-case').addEventListener('change',e=>applyCase(e.target.value));
  document.querySelector('#compare-toggle').addEventListener('click',()=>toggleComparison(document.querySelector('#comparison').hidden));document.querySelector('#compare-close').addEventListener('click',()=>toggleComparison(false));
  document.querySelector('#reset').addEventListener('click',()=>{accounts.splice(0,accounts.length,...initialAccounts.map(a=>({...a})));state.account='wechat';state.style='original';document.querySelector('#icon-style').value='original';state.scene='assets';applyCase('normal');go('assets');});
  document.querySelectorAll('[data-test]').forEach(b=>b.addEventListener('click',()=>{if(b.dataset.test==='compare')toggleComparison(true);else go(b.dataset.test);}));
  document.addEventListener('keydown',e=>{if(!state.overlay)return;if(e.key==='Escape'){e.preventDefault();closeOverlay();phone.querySelector('[data-action=open-picker]')?.focus();}if(e.key==='Tab'){const f=[...phone.querySelectorAll('.overlay button:not(:disabled),.overlay input')].filter(x=>!x.hidden&&x.getClientRects().length);if(e.shiftKey&&document.activeElement===f[0]){e.preventDefault();f.at(-1)?.focus();}else if(!e.shiftKey&&document.activeElement===f.at(-1)){e.preventDefault();f[0]?.focus();}}});
  bindControls(()=>{if(!document.querySelector('#comparison').hidden)renderComparison();});render();
  const params=new URLSearchParams(location.search);if(params.get('style')==='mono'){state.style='mono';document.querySelector('#icon-style').value='mono';}if(['normal','hidden','unknown','foreign'].includes(params.get('case')))applyCase(params.get('case'));if(['assets','picker','detail','types'].includes(params.get('scene')))go(params.get('scene'));else render();if(params.get('compare')==='true')toggleComparison(true);
})();
