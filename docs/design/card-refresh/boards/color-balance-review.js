(() => {
  'use strict';
  const $ = selector => document.querySelector(selector);
  const pages = [
    {id:'home',route:'home',label:'明细首页',symbol:'≋',hint:'高频浏览 · 分类识别',title:'先看到记录，再认出类别',why:'首页最常用，也最容易被大块灰白和同色图标淹没。保留已确认的品牌、汇总卡与 C3 账单行，只给摘要和分类增加轻微层次。',changes:[['汇总卡轻染主题色','用 5% 主题色混入原卡片底，让本月概况自然成为第一视觉落点。大金额保持原色。'],['分类色跨页一致','餐饮用麦穗色、交通用湖蓝、购物用浅紫；只落在图标区域，账单行仍是白底。'],['既有语义优先','标签、自定义图片、收支金额沿用现稿；图标色描述“什么类别”，金额色描述“资金方向”。']],actions:[['切换账本','ledger'],['显示 / 隐藏金额','eye'],['显示 / 隐藏品牌','brand']],caption:'默认带品牌 · C3 账单行 · 合成数据'},
    {id:'assets',route:'assets',label:'资产账户',symbol:'▣',hint:'账户辨识 · 克制摘要',title:'账户要能一眼区分',why:'现有资产卡的账户图片被统一灰度处理，银行卡、微信、支付宝很难扫读。本页适合用最小的颜色恢复识别效率。',changes:[['账户保留原图颜色','移除评审层内的灰度滤镜，原 SVG 的蓝、绿、紫自然保留；不重新设计品牌标识。'],['净资产只用轻底色','汇总卡轻染主题色；资产数值和负债数值保持原样，不让账户色影响金额含义。'],['列表与图表保持安静','账户分组仍是白卡，趋势与构成保留已确认的单主题色。彩色集中在 35px 标识中。']],actions:[['看账户列表','accounts'],['资产币种视图','av-currencies'],['只看负债','av-filter:liabilities']],caption:'已确认资产 B 布局 · 合成多币种账户'},
    {id:'categories',route:'flow-category-management',label:'分类管理',symbol:'◇',hint:'同类同色 · 保留图片',title:'分组有色，名称清楚',why:'分类管理的行图标大多使用 onSurface，一级、二级分类与页面文字同色。借助稳定的类别色，展开前后都能跟住同一组。',changes:[['每个家族一种识别色','餐饮 / 居家用麦穗色，交通用湖蓝，购物 / 数码用浅紫；一级、二级与首页保持一致。'],['自定义图片不套色','咖啡等用户上传图直接保留原图与原裁切方式，不灰化、不覆盖，也不再叠加彩色底。'],['展开组轻轻承接','展开区只加入极淡同族底色，保持现有行高、图标大小与管理按钮位置。']],actions:[['展开交通','d-manage-toggle:交通'],['查看餐饮二级分类','children'],['分类工具','f-go:category-tools']],caption:'一级 / 二级分类 · 含合成自定义图片'},
    {id:'budget',route:'budget',label:'预算管理',symbol:'◔',hint:'焦点聚合 · 状态独立',title:'预算状态仍然最重要',why:'预算既有“对象类别”，也有“接近上限 / 超出上限”的状态。如果所有颜色承担同一含义，读者就容易混淆。',changes:[['总预算更聚焦','只给总预算卡加入轻主题底，仍沿用当前紧凑进度条布局。剩余金额保持清晰。'],['类别色与状态色分工','类别图标沿用首页的家族色；进度条、百分比、超支金额继续沿用现有阈值颜色。'],['异常不被主题稀释','正常、接近上限、超支不因主题切换而改义。可切换超支示例检查红色是否足够明确。']],actions:[['查看超支示例','exceeded'],['恢复正常预算','normal'],['首页预算开关','bgt-home']],caption:'当前紧凑预算布局 · 正常 / 超支可切换'},
    {id:'mine',route:'mine',label:'我的',symbol:'♙',hint:'温暖账户 · 功能分组',title:'让常用入口有辨识度',why:'“我的”菜单数量多，整齐的灰色图标容易连成一片。保留 F / A 顶部布局，靠图标的轻色区分不同任务。',changes:[['账本余额轻染主题色','单层蜜蜂头像和紧凑余额条不变，使用极淡主题底承接个人区域。余额仍按正负规则显示。'],['功能色有固定用途','云同步用湖蓝、智能 / 自动化用浅紫、账本用麦穗色，设置类保持中性。'],['同步状态单独表达','未配置保持中性；失败状态仍用原错误色。蓝色云图标只表示功能，不表示同步成功。']],actions:[['切换账本','ledger'],['同步失败示例','sync-error'],['恢复本地模式','sync-local']],caption:'已确认我的 F / A 布局 · 单层头像'},
    {id:'data',route:'data',label:'数据管理',symbol:'▤',hint:'任务定位 · 分组扫读',title:'多组工具，快速找到',why:'数据管理有账单、分类、配置、附件四个分组，结构已经清楚，缺少的是扫一眼就能记住的视觉标识。',changes:[['按任务家族着色','账单导入 / 导出用湖蓝；分类 / 标签用浅紫；配置 / 存储用麦穗色；附件用薄荷色。'],['只强化第一组任务','账单分组轻染湖蓝，其他卡片保持白底。标题、说明、箭头保持当前层级与尺寸。'],['状态不借用装饰色','导入进度、完成、部分失败使用现有任务反馈；图标色不代替进度文案。']],actions:[['查看附件分组','attachments'],['后台导入示例','importing'],['恢复就绪','import-ready']],caption:'账单 / 分类 / 配置 / 附件 · 合成任务状态'}
  ];
  const themes = {honey:{accent:'#f8c91c',ink:'#785b06',darkInk:'#ecd37b',tint:'#fff8df',darkTint:'#393422'},lilac:{accent:'#7e57c2',ink:'#7954af',darkInk:'#c8acef',tint:'#f1ebfa',darkTint:'#322b3d'}};
  const params = new URLSearchParams(location.search);
  const state = {page:pages.some(p=>p.id===params.get('page'))?params.get('page'):'home',theme:params.get('theme')==='lilac'?'lilac':'honey',mode:params.get('mode')==='dark'?'dark':'light',size:['398x844','375x667','320x568'].includes(params.get('size'))?params.get('size'):'398x844',annotations:false,brand:true};
  const frame = $('#phone-preview');
  let observer,paintScheduled=false,loaded=false;
  const current = () => pages.find(p=>p.id===state.page);
  function writeURL(){const next=new URL(location.href);['page','theme','mode','size'].forEach(key=>next.searchParams.set(key,state[key]));history.replaceState(null,'',next);}
  function chrome(){
    const p=current(),theme=themes[state.theme];
    document.body.dataset.reviewMode=state.mode;
    document.documentElement.style.setProperty('--review-accent',theme.accent);
    document.documentElement.style.setProperty('--review-accent-ink',state.mode==='dark'?theme.darkInk:theme.ink);
    document.documentElement.style.setProperty('--review-tint',state.mode==='dark'?theme.darkTint:theme.tint);
    $('#page-navigation').innerHTML=pages.map(x=>`<button class="page-choice" data-page="${x.id}" ${x.id===state.page?'aria-current="page"':''}><span class="page-symbol" aria-hidden="true">${x.symbol}</span><span><b>${x.label}</b><small>${x.hint}</small></span><span class="choice-arrow" aria-hidden="true">›</span></button>`).join('');
    $('#preview-title').textContent=p.label;$('#rationale-title').textContent=p.title;$('#rationale-copy').textContent=p.why;
    $('#page-changes').innerHTML=p.changes.map((x,i)=>`<div class="change-item"><span class="change-marker">0${i+1}</span><div><h3>${x[0]}</h3><p>${x[1]}</p></div></div>`).join('');
    $('#quick-actions').innerHTML=p.actions.map(x=>`<button data-quick="${x[1]}" ${loaded?'':'disabled'}>${x[0]}</button>`).join('');
    $('#preview-caption').textContent=p.caption;frame.title=p.label+'配色交互预览';
    document.querySelectorAll('[data-theme]').forEach(el=>el.setAttribute('aria-pressed',String(el.dataset.theme===state.theme)));
    document.querySelectorAll('[data-mode]').forEach(el=>el.setAttribute('aria-pressed',String(el.dataset.mode===state.mode)));
    $('#annotations').setAttribute('aria-pressed',String(state.annotations));$('#viewport').value=state.size;
    writeURL();fit();
  }
  function fit(){const [w,h]=state.size.split('x').map(Number),available=Math.max(1,$('#preview-stage').clientWidth-32),scale=Math.min(1,available/w),wrap=$('#phone-wrap');wrap.style.width=w*scale+'px';wrap.style.height=h*scale+'px';frame.style.width=w+'px';frame.style.height=h+'px';frame.style.transform=`scale(${scale})`;}
  function load(route=current().route){loaded=false;frame.style.visibility='hidden';$('#loading').hidden=false;chrome();frame.src=`../prototype/demo.html?page=${encodeURIComponent(route)}&viewport=${state.size}`;}
  function updateFrame(){
    if(!loaded)return;const doc=frame.contentDocument,demo=frame.contentWindow.beeImmersiveDemo;if(!demo)return;
    Object.assign(demo.settings,{appearance:state.mode,accent:themes[state.theme].accent,userAccent:themes[state.theme].accent,skin:'none',immersive:false,animation:false,showBrand:state.brand});
    demo.render();demo.freeze();doc.body.dataset.cbAnnotations=String(state.annotations);
    frame.contentWindow.beeResponsivePreview.set({width:Number(state.size.split('x')[0]),height:Number(state.size.split('x')[1])});
    paint();fit();
  }
  const iconFamilies = {
    amber:['utensils','utensils-crossed','coffee','cup-soda','sandwich','cookie','cake-slice','soup','cooking-pot','house','bed','armchair','lamp','wallet','banknote','coins','book-open-check','file-cog','hard-drive','file-code'],
    blue:['train-front','bus-front','bus','car','car-front','bike','plane','fuel','parking-circle','cloud','cloud-sync','file-up','file-down','download','upload','credit-card','database'],
    plum:['shopping-basket','shopping-bag','shopping-cart','shirt','smartphone','laptop','monitor','clapperboard','gamepad-2','sparkles','bot','wand-sparkles','zap','shapes','tags','tag','arrow-left-right','clock'],
    mint:['book-open','book','graduation-cap','library-big','sprout','leaf','apple','carrot','archive','folder-input','images','image','eye','folder-open','dumbbell','footprints'],
    rose:['heart','heart-pulse','pill','gift','hand-heart','paw-print','flower-2']
  };
  function familyFor(node){const name=node.querySelector('[data-lucide]')?.dataset.lucide;return Object.entries(iconFamilies).find(([,icons])=>icons.includes(name))?.[0]||null;}
  function mark(el,family){if(!el)return;if(el.querySelector('img')&&!el.classList.contains('av-account-icon')){el.dataset.cbCustom='true';delete el.dataset.cbFamily;return;}if(family)el.dataset.cbFamily=family;}
  function paint(){
    if(!loaded)return;const doc=frame.contentDocument,phone=doc?.querySelector('.bc-phone');if(!phone)return;
    // Classification changes only the visual marker; amount/status elements are intentionally excluded.
    phone.querySelectorAll('.category-target:not(.selection-target),.cm-manager-scroll .bc-entry-icon,.cm-child-icon,.n-child-icon,.bgt-category-icon').forEach(el=>mark(el,familyFor(el)));
    phone.querySelectorAll('.bc-menu-symbol').forEach(el=>{
      const row=el.closest('[data-action]'),action=row?.dataset.action||'';
      // Status affordances retain the source's neutral/error/success presentation.
      if(action==='j-sync-detail'||row?.closest('[data-file-state="running"],[data-file-state="success"],[data-file-state="partial"],[data-file-state="error"]'))return;
      mark(el,familyFor(el));
    });
    phone.querySelectorAll('.av-account-icon').forEach(el=>{const id=el.closest('[data-av-card]')?.dataset.avCard||'';mark(el,id==='wechat'?'mint':id==='alipay'||id==='bank'?'blue':id==='credit'?'plum':'amber');});
    // Keep the colour family inherited by second-level categories when an icon is unfamiliar.
    phone.querySelectorAll('.d-rank-item').forEach(row=>{const f=row.querySelector('.bc-entry-icon')?.dataset.cbFamily;if(f){row.dataset.cbGroup=f;row.querySelectorAll('.n-child-icon').forEach(el=>mark(el,f));}});
    doc.body.dataset.cbAnnotations=String(state.annotations);
    document.querySelectorAll('[data-quick]').forEach(el=>el.disabled=false);
  }
  frame.addEventListener('load',()=>{
    if(frame.src==='about:blank')return;const doc=frame.contentDocument;
    if(!frame.contentWindow.beeImmersiveDemo){$('#loading').textContent='预览未完成载入，请重置页面。';return;}
    doc.body.classList.add('color-review-frame');doc.documentElement.style.background='transparent';
    const style=doc.createElement('link');style.rel='stylesheet';style.href='../boards/color-balance-review.css';
    style.addEventListener('load',()=>{loaded=true;observer?.disconnect();observer=new MutationObserver(()=>{if(!paintScheduled){paintScheduled=true;requestAnimationFrame(()=>{paintScheduled=false;paint();});}});observer.observe(doc.querySelector('.bc-phone'),{childList:true,subtree:true});updateFrame();frame.style.visibility='visible';$('#loading').hidden=true;chrome();},{once:true});
    style.addEventListener('error',()=>{$('#loading').textContent='配色样式未完成载入，请重置页面。';},{once:true});
    doc.head.appendChild(style);
  });
  function quick(action){
    if(!loaded)return;const doc=frame.contentDocument,demo=frame.contentWindow.beeImmersiveDemo;
    if(action==='brand'){state.brand=!state.brand;updateFrame();return;}
    if(action==='accounts'){doc.querySelector('.av-b-account-tools')?.scrollIntoView({block:'start',behavior:'smooth'});return;}
    if(action==='attachments'){const cards=doc.querySelectorAll('.bc-main>.bc-menu-card');cards[cards.length-1]?.scrollIntoView({block:'start',behavior:'smooth'});return;}
    if(action==='exceeded'||action==='normal'){load(action==='exceeded'?'flow-budget-exceeded':'budget');return;}
    if(action==='sync-error'||action==='sync-local'){demo.state.jSyncState=action==='sync-error'?'error':'notConfigured';demo.render();return;}
    if(action==='importing'||action==='import-ready'){demo.state.dmImport=action==='importing'?'running':'ready';demo.render();return;}
    if(action==='children'){const expand=doc.querySelector('[data-action="d-manage-toggle:餐饮"]');if(!doc.querySelector('[data-cm-parent="餐饮"][data-action="cm-open-children"]'))expand?.click();doc.querySelector('[data-cm-parent="餐饮"][data-action="cm-open-children"]')?.click();return;}
    doc.querySelector(`[data-action="${action}"]`)?.click();
  }
  document.addEventListener('click',event=>{
    const page=event.target.closest('[data-page]'),theme=event.target.closest('[data-theme]'),mode=event.target.closest('[data-mode]'),action=event.target.closest('[data-quick]');
    if(page){state.page=page.dataset.page;load();return;}
    if(theme){state.theme=theme.dataset.theme;chrome();updateFrame();return;}
    if(mode){state.mode=mode.dataset.mode;chrome();updateFrame();return;}
    if(action)quick(action.dataset.quick);
  });
  $('#annotations').addEventListener('click',()=>{state.annotations=!state.annotations;chrome();paint();});
  $('#reset-page').addEventListener('click',()=>load());
  $('#viewport').addEventListener('change',event=>{state.size=event.target.value;chrome();updateFrame();});
  new ResizeObserver(fit).observe($('#preview-stage'));
  window.colorBalanceReview={state,pages,load,updateFrame,quick,paint,get loaded(){return loaded;}};
  chrome();load();
})();
