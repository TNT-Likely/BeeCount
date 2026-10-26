(() => {
  'use strict';
  const $ = selector => document.querySelector(selector);
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const paths = {
    left:'m14 6-6 6 6 6',right:'m10 6 6 6-6 6',down:'m7 10 5 5 5-5',more:'M5 12h.01M12 12h.01M19 12h.01',close:'m6 6 12 12M6 18 18 6',
    calendar:'M5 4h14a2 2 0 0 1 2 2v14H3V6a2 2 0 0 1 2-2ZM7 2v4m10-4v4M3 10h18M7 14h2m4 0h2',up:'M7 17V7h13M7 7l5 5M7 7l5-5',
    coffee:'M5 8h12v8a4 4 0 0 1-4 4H9a4 4 0 0 1-4-4V8Zm12 1h1a3 3 0 0 1 0 6h-1M8 3v2m4-2v2m4-2v2',
    cup:'M7 3h10l-1 18H8L7 3Zm-1 5h12M12 3V1',glass:'M7 3h10v4a5 5 0 0 1-10 0V3Zm5 9v9m-4 0h8',
    wallet:'M4 5h14a2 2 0 0 1 2 2v13H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h12M16 10h6v5h-6z',
    income:'M3 7h18v14H3zM8 7V3h8v4M3 12l9 3 9-3m-9 0v3',pet:'M4 9a2 2 0 1 0 0-4 2 2 0 0 0 0 4m5-3a2 2 0 1 0 0-4 2 2 0 0 0 0 4m6 0a2 2 0 1 0 0-4 2 2 0 0 0 0 4m5 3a2 2 0 1 0 0-4 2 2 0 0 0 0 4M8 12c-1 1-5 5-3 7s5-1 7-1 5 3 7 1-2-6-3-7-6-1-8 0',
    shapes:'M3 16h6v5H3zM17 14a4 4 0 1 0 0 8 4 4 0 0 0 0-8M8 2l5 8H3L8 2Z',search:'m21 21-5-5M10 18a8 8 0 1 0 0-16 8 8 0 0 0 0 16',
    edit:'m16 3 5 5-12 12-6 1 1-6L16 3Zm-10 10 5 5',transfer:'M4 7h15m-4-4 4 4-4 4M20 17H5m4-4-4 4 4 4',
    empty:'M4 6h16l2 14H2L4 6Zm-1 8h5l1 3h6l1-3h5M8 2h8',plus:'M12 5v14M5 12h14',check:'m5 12 4 4L19 6',
    info:'M12 11v6m0-10h.01M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20',sort:'M5 4v16m-3-3 3 3 3-3M12 5h10m-10 5h7m-7 5h4',
    image:'M3 3h18v18H3zM3 17l5-5 5 5 3-3 5 5M8 7h.01',book:'M3 3h8v18H3V3Zm8 0h10v18H11M6 7h2m6 0h4',
    signal:'M4 18v3m5-7v7m5-12v12m5-17v17',wifi:'M2 8a15 15 0 0 1 20 0M5 12a10 10 0 0 1 14 0m-11 4a5 5 0 0 1 8 0m-4 4h.01',battery:'M2 6h18v12H2zM22 10v4M5 9h11v6H5z'
  };
  const icon = name => `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="${paths[name] || paths.shapes}"></path></svg>`;
  const categories = {
    drinks:{name:'饮品',icon:'coffee',kind:'expense'},coffee:{name:'咖啡',icon:'coffee',kind:'expense',parent:'drinks'},tea:{name:'奶茶',icon:'cup',kind:'expense',parent:'drinks',image:'../prototype/assets/category-milk-tea.png'},wine:{name:'酒水',icon:'glass',kind:'expense',parent:'drinks'},
    longParent:{name:'工作出差与城市旅行中的日常餐饮消费',icon:'coffee',kind:'expense'},longChild:{name:'和同事一起喝的精品手冲咖啡与下午茶',icon:'coffee',kind:'expense',parent:'longParent'},
    pet:{name:'宠物医疗',icon:'pet',kind:'expense'},income:{name:'工作收入',icon:'income',kind:'income'},salary:{name:'工资',icon:'income',kind:'income',parent:'income'}
  };
  const initialCategories = JSON.parse(JSON.stringify(categories));
  const cases = [
    {id:'child',label:'二级分类',category:'coffee'},
    {id:'parent',label:'一级分类',category:'drinks'},
    {id:'long',label:'长名称 · 二级',category:'longChild'},
    {id:'long-parent',label:'长名称 · 一级',category:'longParent'},
    {id:'empty',label:'暂无记录',category:'pet'},
    {id:'income',label:'收入分类',category:'salary'},
    {id:'foreign',label:'跨账本 · 外币',category:'coffee',allBooks:true}
  ];
  const rows = [];
  const notes = ['工作前的一杯拿铁','街角咖啡店','和朋友喝咖啡','下午的奖励','手冲咖啡'];
  for(let i=0;i<26;i++) {
    const category=['coffee','coffee','tea','coffee','wine'][i%5];
    const foreign=i%7===0;
    rows.push({id:'drink-'+i,category,date:`2026-10-${String(25-i%23).padStart(2,'0')}`,time:`${String(9+i%11).padStart(2,'0')}:${i%2?'20':'35'}`,amount:foreign?12:[32,25,18,38,68][i%5],native:foreign?85.2:[32,25,18,38,68][i%5],currency:foreign?'USD':'CNY',note:category==='coffee'?notes[i%notes.length]:category==='tea'?'一杯少糖奶茶':'周末聚餐',account:foreign?'美元现金':'微信',book:foreign?'旅行账本':'日常生活',tag:i%3===0?'工作日':'',attachments:i%5===0?1:0});
  }
  rows.push({id:'past-1',category:'coffee',date:'2026-09-16',time:'08:30',amount:28,native:28,currency:'CNY',note:'早餐咖啡',account:'微信',book:'日常生活',tag:''});
  rows.push({id:'past-2',category:'coffee',date:'2025-11-12',time:'14:20',amount:36,native:36,currency:'CNY',note:'周末的咖啡',account:'微信',book:'日常生活',tag:''});
  for(let i=0;i<7;i++)rows.push({id:'long-'+i,category:'longChild',date:`2026-10-${String(20-i).padStart(2,'0')}`,time:'14:30',amount:48+i*3,native:48+i*3,currency:'CNY',note:['出差途中和项目伙伴喝咖啡','下午茶'][i%2],account:'招商银行',book:'日常生活',tag:'待报销'});
  for(let i=0;i<3;i++)rows.push({id:'salary-'+i,category:'salary',date:`2026-${String(10-i).padStart(2,'0')}-10`,time:'09:00',amount:12000,native:12000,currency:'CNY',note:'每月工资',account:'工资卡',book:'日常生活',tag:''});
  const state = {case:'child',category:'coffee',history:[],period:'all',year:2026,month:10,sort:'timeDesc',showAll:false,width:398,height:844,scale:1,mode:'light',selectedTrend:null};
  let modal=null,returnFocus=null,toastTimer=null;
  const money = amount => amount.toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});
  const currentCase = () => cases.find(c=>c.id===state.case);
  const categoryIcon = category => category.image?`<img src="${esc(category.image)}" alt="自定义分类图片">`:icon(category.icon);
  const kindLabel = () => categories[state.category].kind==='income'?'收入':'支出';
  function inPeriod(row) {
    return state.period==='all'||(state.period==='year'?row.date.startsWith(String(state.year)):row.date.startsWith(`${state.year}-${String(state.month).padStart(2,'0')}`));
  }
  function scopedRows() { return rows.filter(row=>inPeriod(row)&&(currentCase().allBooks||row.book==='日常生活')); }
  function family(id) { return [id,...Object.keys(categories).filter(k=>categories[k].parent===id)]; }
  function data() {
    const ids=family(state.category),scoped=scopedRows();
    const selected=scoped.filter(row=>ids.includes(row.category)).sort((a,b)=>state.sort==='amountDesc'?b.amount-a.amount:state.sort==='amountAsc'?a.amount-b.amount:state.sort==='timeAsc'?(a.date+a.time).localeCompare(b.date+b.time):(b.date+b.time).localeCompare(a.date+a.time));
    const amount=selected.reduce((total,row)=>total+row.native,0),parent=categories[state.category].parent;
    const denominator=scoped.filter(row=>parent?family(parent).includes(row.category):categories[row.category]?.kind===categories[state.category].kind).reduce((total,row)=>total+row.native,0);
    return {rows:selected,count:selected.length,amount,average:selected.length?amount/selected.length:0,share:denominator?amount/denominator:0,children:Object.keys(categories).filter(k=>categories[k].parent===state.category)};
  }
  const rangeText=()=>state.period==='all'?'全部时间':state.period==='year'?`${state.year} 年`:`${state.year} 年 ${state.month} 月`;
  const periodText=()=>state.period==='all'?'累计':state.period==='year'?'本年':'本月';
  function renderPeriods() {
    $('#period-controls').innerHTML=`<div class="period-tab-zone"><div class="period-track"></div><nav class="period-tabs" aria-label="统计周期" role="tablist">${[['month','月'],['year','年'],['all','全部']].map(([id,label])=>`<button role="tab" data-action="period:${id}" aria-selected="${state.period===id}">${label}</button>`).join('')}</nav></div><div class="range-strip ${state.period==='all'?'all-range':''}">${state.period==='all'?'':`<button class="range-step" data-action="previous" aria-label="上一${state.period==='year'?'年':'月'}" ${state.year===2000&&(state.period==='year'||state.month===1)?'disabled':''}>${icon('left')}</button>`}<button class="range-label" data-action="date" aria-label="选择统计时间：${esc(rangeText())}">${icon('calendar')}<span>${rangeText()}</span>${icon('down')}</button>${state.period==='all'?'<span class="range-hint">所有记录</span>':`<button class="range-step" data-action="next" aria-label="下一${state.period==='year'?'年':'月'}" ${state.year===2100&&(state.period==='year'||state.month===12)?'disabled':''}>${icon('right')}</button>`}</div>`;
  }
  function hero(d) {
    const category=categories[state.category],parent=category.parent&&categories[category.parent];
    return `<section class="card hero" aria-label="分类汇总">${parent?`<button class="ancestry" data-action="parent" aria-label="查看上级分类：${esc(parent.name)}" title="${esc(parent.name)}">${icon('up')}<span class="ancestry-label">上级</span><span class="parent-name">${esc(parent.name)}</span><span class="parent-arrow">${icon('right')}</span></button>`:''}<div class="identity"><span class="category-icon">${categoryIcon(category)}</span><div class="identity-copy"><h3 title="${esc(category.name)}">${esc(category.name)}</h3><p>${parent?'二级分类':`一级分类 · ${d.children.length} 个二级分类`} · ${currentCase().allBooks?'全部账本':'日常生活'}</p></div></div><div class="amount-label"><span>${periodText()}${kindLabel()}</span><span class="currency-label">CNY</span></div><div class="hero-amount num"><span class="symbol">¥</span><span>${money(d.amount)}</span></div><div class="metrics"><div><span class="metric-label">记录笔数</span><strong class="metric-value num">${d.count} 笔</strong></div><div><span class="metric-label">单笔均额</span><strong class="metric-value small-amount num">¥${money(d.average)}</strong></div><div><span class="metric-label">占总${kindLabel()}</span><strong class="metric-value num">${(d.share*100).toFixed(1)}%</strong></div></div></section>`;
  }
  function breakdown(d) {
    if(!d.children.length)return '';
    return `<section class="card"><div class="card-heading"><h3>二级分类</h3><small>${d.children.length} 个</small></div>${d.children.map(id=>{const cat=categories[id],items=d.rows.filter(row=>row.category===id),sum=items.reduce((n,r)=>n+r.native,0);return `<button class="breakdown-row" data-action="category:${id}" aria-label="查看${esc(cat.name)}分类详情"><span class="breakdown-icon">${categoryIcon(cat)}</span><span class="breakdown-copy"><span class="breakdown-name">${esc(cat.name)}</span><small>${items.length} 笔 · ${d.amount?(sum/d.amount*100).toFixed(1):'0.0'}%</small><span class="breakdown-track"><i style="width:${d.amount?sum/d.amount*100:0}%"></i></span></span><strong class="breakdown-amount num">¥${money(sum)}</strong><span class="chevron">${icon('right')}</span></button>`}).join('')}</section>`;
  }
  function trend(d) {
    const buckets=new Map();
    [...d.rows].sort((a,b)=>a.date.localeCompare(b.date)).forEach(row=>{const key=row.date.slice(0,state.period==='month'?10:7);buckets.set(key,(buckets.get(key)||0)+row.native)});
    let running=0;const points=[...buckets].map(([date,value])=>({date,value:running+=value})),max=points.at(-1)?.value||1;
    const active=points.find(p=>p.date===state.selectedTrend);
    return `<section class="card"><div class="card-heading"><h3>累计${kindLabel()}趋势</h3><small>CNY</small></div><div class="trend-wrap"><div class="trend-chart" aria-label="累计${kindLabel()}趋势">${points.length?points.map(p=>`<button class="trend-bar" style="--bar-height:${Math.max(3,p.value/max*100)}%" data-action="trend:${p.date}" aria-pressed="${p.date===state.selectedTrend}" aria-label="${p.date} 累计${money(p.value)}元"></button>`).join(''):'<span class="sheet-description">暂无趋势数据</span>'}</div><div class="trend-axis"><span>${points[0]?.date.replace(/-/g,'.')||'—'}</span><span>${points.length>1?points.at(-1).date.replace(/-/g,'.'):''}</span></div><p class="trend-caption">${active?`${active.date.replace(/-/g,'.')} · 累计${kindLabel()} ¥${money(active.value)}`:'点击柱形，查看累计金额'}</p></div></section>`;
  }
  function transaction(row) {
    const cat=categories[row.category],foreign=row.currency!=='CNY',allBooks=currentCase().allBooks;
    return `<button class="transaction" data-action="transaction:${row.id}" data-kind="${cat.kind}" aria-label="查看账单：${esc(row.note)}，${row.currency} ${row.amount}"><span class="transaction-icon">${categoryIcon(cat)}</span><span class="transaction-copy"><span class="tx-top"><span class="tx-name">${esc(row.note)}</span><span class="tx-amount num">${cat.kind==='income'?'+':'−'}${foreign?'US$':''}${money(row.amount)}</span></span><span class="tx-bottom"><span class="tx-account">${icon('wallet')}${esc(row.account)}</span>${row.attachments?`<span class="tx-account">${icon('image')}${row.attachments}</span>`:''}${!foreign&&!allBooks&&row.tag?`<span class="tx-tag">${esc(row.tag)}</span>`:''}${foreign?`<span class="tx-converted num">≈ ¥${money(row.native)}</span>`:`<span class="tx-time">${row.time}</span>`}</span>${foreign||allBooks?`<span class="tx-third">${allBooks?`<span class="tx-ledger">${esc(row.book)}</span>`:''}${row.tag?`<span class="tx-tag">${esc(row.tag)}</span>`:''}<span class="tx-time">${row.time}</span></span>`:''}</span></button>`;
  }
  function transactions(d) {
    const sortLabels={timeDesc:'时间降序',timeAsc:'时间升序',amountDesc:'金额降序',amountAsc:'金额升序'};
    let lastDay=null;const shown=state.showAll?d.rows:d.rows.slice(0,4);
    return `<div class="list-title"><h3>关联交易 <span style="font-size:10px;color:var(--muted);font-weight:400">${d.count} 笔</span></h3><button class="sort-button" data-action="sort">${icon('sort')}${sortLabels[state.sort]}</button></div><section class="card transactions">${shown.length?shown.map(row=>{const first=lastDay!==row.date;lastDay=row.date;const sum=d.rows.filter(r=>r.date===row.date).reduce((total,r)=>total+r.native,0);return `${first?`<div class="day-heading"><strong>${row.date.replace(/-/g,'.')}</strong><span>${kindLabel()} ¥${money(sum)}</span></div>`:''}${transaction(row)}`}).join(''):`<div class="empty-state">${icon('empty')}<strong>暂无关联记录</strong><p>符合当前筛选的账单<br>将在这里显示</p></div>`}</section>${d.count>4?`<button class="all-records" data-action="all-records">${state.showAll?'收起记录':`查看全部 ${d.count} 笔交易`}${icon(state.showAll?'up':'down')}</button>`:''}<button class="primary-button" data-action="record">${icon('plus')}使用此分类记一笔</button>`;
  }
  function render({resetScroll=false}={}) {
    const scroll=$('#screen-scroll').scrollTop,d=data();
    renderPeriods();
    $('#screen-scroll').innerHTML=hero(d)+(currentCase().allBooks?`<aside class="currency-note">${icon('info')}<div><p>汇总金额统一折算为 CNY</p><button data-action="currency">保留原账本历史金额 · 查询时汇率</button></div></aside>`:'')+breakdown(d)+trend(d)+transactions(d);
    $('#screen-scroll').scrollTop=resetScroll?0:scroll;
    $('#case-caption').textContent=currentCase().label+(state.history.length?' · 已进入分类':'');
    $('#case-list').innerHTML=cases.map((c,i)=>`<button class="case-button" data-case="${c.id}" aria-pressed="${state.case===c.id}"><span class="case-dot"></span><span class="case-name">${c.label}</span><span class="case-index">${String(i+1).padStart(2,'0')}</span></button>`).join('');
    $('#back-button').setAttribute('aria-label',state.history.length?'返回上个分类':'返回分类列表');
    document.body.dataset.mode=state.mode;document.body.dataset.small=String(state.width===320);document.body.dataset.largeFont=String(state.scale>1);
    document.documentElement.style.setProperty('--phone-width',state.width+'px');document.documentElement.style.setProperty('--phone-height',state.height+'px');document.documentElement.style.setProperty('--text-scale',state.scale);
    document.querySelectorAll('[data-mode]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.mode===state.mode)));
    if(modal)renderModal();
  }
  function selectCase(id) { closeModal();state.case=id;state.category=cases.find(c=>c.id===id).category;state.history=[];state.period='all';state.showAll=false;state.selectedTrend=null;render({resetScroll:true}); }
  function navigate(id) { state.history.push(state.category);state.category=id;state.showAll=false;state.selectedTrend=null;closeModal();render({resetScroll:true}); }
  function notify(message) { clearTimeout(toastTimer);$('#toast').textContent=message;$('#toast').hidden=false;toastTimer=setTimeout(()=>$('#toast').hidden=true,2500); }
  function openModal(kind,extra={}) {
    if(!modal)returnFocus=document.activeElement;
    modal={kind,...extra};
    $('#screen-scroll').inert=true;$('#period-controls').inert=true;$('.app-header').inert=true;
    renderModal();requestAnimationFrame(()=>$('#overlay-host [data-close]')?.focus({preventScroll:true}));
  }
  function closeModal() {
    modal=null;$('#overlay-host').replaceChildren();$('#screen-scroll').inert=false;$('#period-controls').inert=false;$('.app-header').inert=false;
    if(returnFocus?.isConnected)returnFocus.focus({preventScroll:true});returnFocus=null;
  }
  const menuRow=(action,name,ico,extra='')=>`<button class="menu-row" data-action="${action}">${icon(ico)}<span class="label">${esc(name)}</span>${extra}${icon('right')}</button>`;
  const infoRow=(label,value)=>`<div class="info-row"><span>${esc(label)}</span><strong>${esc(value)}</strong></div>`;
  function modalContent() {
    const cat=categories[state.category],d=data();
    if(modal.kind==='date') {
      const draft=modal.draft;
      return {title:'选择统计时间',body:`<nav class="sheet-tabs" role="tablist" aria-label="选择时间类型">${[['month','月'],['year','年'],['all','全部']].map(([id,label])=>`<button data-action="draft-period:${id}" role="tab" aria-selected="${draft.period===id}">${label}</button>`).join('')}</nav>${draft.period==='all'?`<div class="all-period-note">${icon('calendar')}<strong>查看全部时间</strong><span>汇总此分类的全部历史记录</span></div>`:`<div class="wheels"><div class="wheel-highlight"></div>${wheel('year',Array.from({length:101},(_,i)=>i+2000),draft.year,'年')}${draft.period==='month'?wheel('month',Array.from({length:12},(_,i)=>i+1),draft.month,'月'):''}</div><p class="sheet-status" id="wheel-status">${draft.year} 年${draft.period==='month'?' '+draft.month+' 月':''}</p>`}<button class="primary-button" data-action="apply-date">${icon('check')}确认</button>`};
    }
    if(modal.kind==='menu')return {title:'分类操作',body:menuRow('search','搜索此分类账单','search')+menuRow('edit','编辑分类','edit')+menuRow('migrate','分类迁移','transfer')+menuRow('manage','分类管理','shapes')};
    if(modal.kind==='sort')return {title:'交易排序',body:[['timeDesc','时间降序'],['timeAsc','时间升序'],['amountDesc','金额降序'],['amountAsc','金额升序']].map(([id,label])=>menuRow('sort-value:'+id,label,'sort',state.sort===id?icon('check'):'')).join('')};
    if(modal.kind==='manage')return {title:'分类管理',body:`<p class="sheet-description">点击分类查看详情；长名称在这里完整展示。</p>${Object.keys(categories).filter(id=>!categories[id].parent).map(id=>`<button class="menu-row" data-action="category:${id}">${icon(categories[id].icon)}<span class="label" style="white-space:normal">${esc(categories[id].name)}</span>${icon('right')}</button>`).join('')}`};
    if(modal.kind==='edit')return {title:'编辑分类',body:`<p class="sheet-description">仅修改当前交互稿中的示例名称。</p><label class="sheet-field">分类名称<input id="name-field" value="${esc(cat.name)}" maxlength="40"><small>最多 40 个字</small></label><p class="field-error" id="name-error"></p><button class="primary-button" data-action="save-name">保存</button>`};
    if(modal.kind==='search')return {title:'搜索分类账单',body:`<p class="sheet-description">${esc(cat.name)} · ${esc(rangeText())}</p><label class="sheet-field">搜索备注<input id="search-field" type="search" placeholder="输入备注关键词" autocomplete="off"></label><div id="search-results">${searchResults('')}</div>`};
    if(modal.kind==='migrate')return {title:'分类迁移',body:`<p class="sheet-description">保留原有迁移入口。迁移属于另一条完整流程，本稿仅预览来源与目标选择，不改写示例账单。</p>${infoRow('来源分类',cat.name)}${infoRow('当前范围记录',d.count+' 笔')}<button class="menu-row" data-action="migration-target">${icon('shapes')}<span class="label">${esc(modal.target||'选择目标分类')}</span>${icon('right')}</button><button class="primary-button" data-action="migration-next" ${modal.target?'':'disabled'}>预览迁移</button>`};
    if(modal.kind==='migration-target')return {title:'选择目标分类',body:Object.keys(categories).filter(id=>id!==state.category&&categories[id].kind===cat.kind).map(id=>menuRow('migration-choose:'+id,categories[id].name,categories[id].icon)).join('')};
    if(modal.kind==='migration-preview')return {title:'迁移预览',body:`<p class="sheet-description">当前仅确认分类详情的视觉方案，迁移确认与实际写入继续沿用原流程。</p>${infoRow('来源',cat.name)}${infoRow('目标',modal.target)}${infoRow('当前范围',d.count+' 笔')}<button class="primary-button" data-action="close">返回查看设计</button>`};
    if(modal.kind==='currency')return {title:'汇总金额说明',body:`<p class="sheet-description">沿用已确认的跨账本汇总规则。</p>${infoRow('显示币种','CNY · 当前账本币种')}${infoRow('每笔原账本金额','保留记账时的历史折算')}${infoRow('跨账本转换','查询时汇率')}${infoRow('本稿汇率','USD → CNY 7.10（固定合成）')}<p class="sheet-description" style="margin-top:15px">下方交易行仍保留原币金额和历史折算。不改变账单、币种或记账时间。</p>`};
    if(modal.kind==='transaction') {
      const row=rows.find(r=>r.id===modal.id);
      return {title:'账单详情',body:`${infoRow('备注',row.note)}${infoRow('分类',categories[row.category].name)}${infoRow('金额',(categories[row.category].kind==='income'?'+':'−')+(row.currency==='USD'?'US$':'¥')+money(row.amount))}${row.currency!=='CNY'?infoRow('历史折算','≈ ¥'+money(row.native)):''}${infoRow('账户',row.account)}${infoRow('账本',row.book)}${infoRow('日期',row.date+' '+row.time)}${row.tag?infoRow('标签',row.tag):''}${row.attachments?infoRow('附件',row.attachments+' 张'):''}`};
    }
    if(modal.kind==='record')return {title:'记一笔',body:`<p class="sheet-description">进入记账页时预选当前分类，沿用原记账流程。</p>${infoRow('收支类型',kindLabel())}${infoRow('预选分类',cat.name)}${infoRow('账本','日常生活')}<p class="sheet-description" style="margin-top:15px">本页只演示分类详情与入口，未创建真实账单。</p><button class="primary-button" data-action="close">返回分类详情</button>`};
    return {title:'分类详情',body:''};
  }
  function wheel(key,values,selected,suffix) { return `<div class="wheel" data-wheel="${key}" role="spinbutton" tabindex="0" aria-label="${key==='year'?'年份':'月份'}" aria-valuemin="${values[0]}" aria-valuemax="${values.at(-1)}" aria-valuenow="${selected}"><div class="wheel-list">${values.map(value=>`<button class="wheel-item" data-action="wheel:${key}:${value}" tabindex="-1" aria-selected="${value===selected}">${value} ${suffix}</button>`).join('')}</div></div>`; }
  function renderModal() {
    const content=modalContent();
    $('#overlay-host').innerHTML=`<div class="overlay" data-backdrop><section class="sheet" role="dialog" aria-modal="true" aria-label="${esc(content.title)}"><div class="sheet-grabber"></div><div class="sheet-heading"><h3>${esc(content.title)}</h3><button class="icon-button" data-action="close" data-close aria-label="关闭弹窗">${icon('close')}</button></div><div class="sheet-body">${content.body}</div></section></div>`;
    if(modal.kind==='date'&&modal.draft.period!=='all') {
      document.querySelectorAll('[data-wheel]').forEach(element=>{
        const key=element.dataset.wheel,min=key==='year'?2000:1;
        element.scrollTop=(modal.draft[key]-min)*36;
        element.addEventListener('scroll',()=>{
          if(!modal||modal.kind!=='date')return;
          const selected=Math.max(min,Math.min(key==='year'?2100:12,Math.round(element.scrollTop/36)+min));
          modal.draft[key]=selected;element.setAttribute('aria-valuenow',selected);
          element.querySelectorAll('.wheel-item').forEach(item=>item.setAttribute('aria-selected',String(Number(item.dataset.action.split(':')[2])===selected)));
          $('#wheel-status').textContent=`${modal.draft.year} 年${modal.draft.period==='month'?' '+modal.draft.month+' 月':''}`;
        },{passive:true});
      });
    }
  }
  function searchResults(query) {const found=data().rows.filter(row=>row.note.toLowerCase().includes(query.toLowerCase()));return found.length?found.map(row=>menuRow('transaction:'+row.id,row.note+' · ¥'+money(row.native),'search')).join(''):'<p class="sheet-description" style="padding-top:15px">没有找到符合关键词的记录</p>';}
  function handle(action) {
    const [name,arg,value]=action.split(':');
    if(name==='close')return closeModal();
    if(name==='period'){state.period=arg;state.showAll=false;state.selectedTrend=null;render();return;}
    if(name==='date')return openModal('date',{draft:{period:state.period,year:state.year,month:state.month}});
    if(name==='draft-period'){modal.draft.period=arg;renderModal();return;}
    if(name==='wheel'){const element=$(`[data-wheel="${arg}"]`),min=arg==='year'?2000:1;element.scrollTo({top:(Number(value)-min)*36,behavior:'smooth'});return;}
    if(name==='apply-date'){Object.assign(state,modal.draft,{showAll:false,selectedTrend:null});closeModal();render();return;}
    if(name==='previous'||name==='next') {const delta=name==='next'?1:-1;if(state.period==='year')state.year+=delta;else{const date=new Date(state.year,state.month-1+delta,1);state.year=date.getFullYear();state.month=date.getMonth()+1;}state.selectedTrend=null;state.showAll=false;render();return;}
    if(name==='parent'){const id=categories[state.category].parent;if(id)return navigate(id);notify('当前已经是一级分类');return;}
    if(name==='category')return navigate(arg);
    if(name==='back'){if(state.history.length){state.category=state.history.pop();state.showAll=false;render({resetScroll:true});}else openModal('manage');return;}
    if(name==='menu'||name==='manage'||name==='sort'||name==='edit'||name==='search'||name==='migrate'||name==='currency'||name==='record')return openModal(name);
    if(name==='sort-value'){state.sort=arg;closeModal();render();return;}
    if(name==='all-records'){state.showAll=!state.showAll;render();return;}
    if(name==='trend'){state.selectedTrend=arg;render();return;}
    if(name==='transaction')return openModal('transaction',{id:arg});
    if(name==='save-name'){const field=$('#name-field'),name=field.value.trim();if(!name){$('#name-error').textContent='请输入分类名称';field.focus();return;}categories[state.category].name=name;closeModal();render();notify('已更新本页示例名称');return;}
    if(name==='migration-target')return openModal('migration-target');
    if(name==='migration-choose')return openModal('migrate',{target:categories[arg].name});
    if(name==='migration-next')return openModal('migration-preview',{target:modal.target});
  }
  document.addEventListener('click',event=>{
    const action=event.target.closest('[data-action]');if(action&&!action.disabled){handle(action.dataset.action);return;}
    const selectedCase=event.target.closest('[data-case]');if(selectedCase){selectCase(selectedCase.dataset.case);return;}
    const mode=event.target.closest('[data-mode]');if(mode){state.mode=mode.dataset.mode;render();return;}
    const review=event.target.closest('[data-review]');if(review){if(review.dataset.review==='parent'&&!categories[state.category].parent)selectCase('child');handle(review.dataset.review);return;}
    if(event.target.matches('[data-backdrop]'))closeModal();
  });
  document.addEventListener('input',event=>{if(event.target.id==='search-field')$('#search-results').innerHTML=searchResults(event.target.value);});
  document.addEventListener('keydown',event=>{
    if(!modal)return;
    if(event.key==='Escape'){event.preventDefault();closeModal();return;}
    if(event.target.matches('[data-wheel]')&&['ArrowUp','ArrowDown','Home','End'].includes(event.key)) {
      event.preventDefault();const element=event.target,key=element.dataset.wheel,min=key==='year'?2000:1,max=key==='year'?2100:12;
      const value=event.key==='Home'?min:event.key==='End'?max:Math.max(min,Math.min(max,modal.draft[key]+(event.key==='ArrowDown'?1:-1)));
      element.scrollTo({top:(value-min)*36,behavior:'auto'});return;
    }
    if(event.key==='Tab') {const nodes=[...$('#overlay-host').querySelectorAll('button:not([disabled]):not([tabindex="-1"]),input,[tabindex="0"]')].filter(n=>n.getClientRects().length);if(event.shiftKey&&document.activeElement===nodes[0]){event.preventDefault();nodes.at(-1).focus();}else if(!event.shiftKey&&document.activeElement===nodes.at(-1)){event.preventDefault();nodes[0].focus();}}
  });
  $('#viewport').addEventListener('change',event=>{[state.width,state.height]=event.target.value.split('x').map(Number);render();});
  $('#font-size').addEventListener('change',event=>{state.scale=Number(event.target.value);render();});
  $('#reset').addEventListener('click',()=>{Object.keys(categories).forEach(id=>Object.assign(categories[id],initialCategories[id]));selectCase(state.case);notify('已重置当前案例');});
  $('#status-icons').innerHTML=icon('signal')+icon('wifi')+icon('battery');$('#back-button').innerHTML=icon('left');$('#menu-button').innerHTML=icon('more');
  const params=new URLSearchParams(location.search);
  if(cases.some(c=>c.id===params.get('case'))){state.case=params.get('case');state.category=currentCase().category;}
  if(['month','year','all'].includes(params.get('period')))state.period=params.get('period');
  if(['398x844','320x568','398x900'].includes(params.get('viewport'))){$('#viewport').value=params.get('viewport');[state.width,state.height]=params.get('viewport').split('x').map(Number);}
  if(params.get('mode')==='dark')state.mode='dark';
  if(params.get('font')==='1.3'){state.scale=1.3;$('#font-size').value='1.3';}
  if(params.get('phone')==='1')document.body.dataset.phoneOnly='true';
  render();
  window.categoryDetailReview={state,data,selectCase,openDate:()=>handle('date'),close:closeModal};
})();
