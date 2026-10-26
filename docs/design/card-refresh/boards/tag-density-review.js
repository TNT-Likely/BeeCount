(() => {
  'use strict';
  const {esc,icon,status,toast,bindControls,phone} = SelectionReview;
  const tags = [
    ['work','工作日','#819268'],['coffee','咖啡时间','#ba8a59'],['friends','和朋友','#9a82b4'],['life','日常生活','#5e9d90'],['reimburse','差旅报销','#6b92bd'],['travel','旅行','#69a4b2'],['home','家庭','#ad8970'],['gift','礼物','#c77c93'],['reading','阅读','#7c92a6'],['saving','省钱计划','#779d71'],['pets','宠物','#c19561'],['health','运动健康','#6b9a86'],['learning','学习进修','#8a87b5'],['weekend','周末','#b88966'],['shopping','网购','#aa80a8'],['subscription','订阅服务','#7d94b4'],['commute','通勤','#83a08d'],['holiday','节日','#bd8b70'],['business','项目报销·跨城商务差旅与客户交流','#6e94a9'],['english','Weekend coffee with friends','#9c8caf'],['unicode','旅行计划 / 夏休み / 서울','#8a9d6d'],['old','旧账本·停用','#8b948d',true]
  ].map(([id,label,color,disabled=false]) => ({id,label,color,disabled}));
  const base = ['work','coffee','friends','life','reimburse'];
  const state = {selected:new Set(base),draft:new Set(base),query:'',scene:'detail',case:'normal',overlay:null};
  let returnFocus = null;
  const tag = id => tags.find(t => t.id===id);
  function pill(t, picker=false) {
    const selected = state.draft.has(t.id);
    return `<button class="tag-hit ${t.label.length>18&&picker?'long-tag':''}" data-tag="${t.id}" ${t.disabled?'disabled aria-disabled="true"':''} ${picker?`aria-pressed="${selected}"`:''} title="${esc(t.label)}${t.disabled?'（停用，无法选择）':''}" aria-label="${esc(t.label)}${t.disabled?'，已停用':''}" style="--tag:${t.color}"><span class="tag-pill">${picker&&selected?`<span class="tag-check">${icon('check')}</span>`:''}${t.disabled?icon('lock'):''}<span class="tag-label">${esc(t.label)}</span></span></button>`;
  }
  function renderDetail() {
    const items = [...state.selected].map(tag).filter(Boolean);
    const visible = items.slice(0,5);
    phone.innerHTML = `${status()}<header class="app-header"><button class="icon-button" data-action="back" aria-label="返回">${icon('back')}</button><h2>账单详情</h2><button class="icon-button" data-action="more" aria-label="更多操作">${icon('more')}</button></header>
      <div class="screen-content"><div class="transaction-hero"><div class="category-symbol">${icon('coffee')}</div><div class="category-name">餐饮 · 咖啡</div><div class="transaction-amount number">−38.00<small>CNY</small></div><div class="transaction-kind">支出</div></div>
      <section class="card"><div class="info-row"><span>时间</span><strong>2026.10.26 · 14:32</strong></div><div class="info-row"><span>账本</span><strong>日常生活</strong></div><div class="info-row"><span>账户</span><strong>${icon('wallet')}微信零钱</strong></div></section>
      <section class="card detail-tags"><div class="section-heading"><h3>标签${items.length?` <span class="muted">${items.length}</span>`:''}</h3><button class="text-button" data-action="edit-tags">编辑</button></div>${visible.length?`<div class="tag-wrap">${visible.map(t=>pill(t)).join('')}${items.length>5?`<button class="tag-hit tag-more" data-action="all-tags" aria-label="展开全部 ${items.length} 个标签"><span class="tag-pill">+${items.length-5}</span></button>`:''}</div>`:'<div class="empty-inline">还没有标签，添加一个便于查找</div>'}</section>
      <section class="card"><div class="section-heading" style="margin-top:0"><h3>备注</h3></div><p class="note-content">和朋友在街角喝咖啡，聊聊最近的生活。</p></section><section class="card"><div class="section-heading" style="margin-top:0"><h3>附件 <span class="muted">1</span></h3></div><div class="attachment-label"><button class="attachment-thumb" data-action="attachment" aria-label="预览咖啡收据">${icon('file')}</button><span>咖啡收据</span></div></section></div>
      <footer class="phone-footer"><button class="secondary" data-action="copy">复制账单</button><button class="primary" data-action="edit-tags">编辑账单</button></footer><div class="home-indicator"></div>`;
    phone.querySelectorAll('[data-tag]').forEach(button=>button.addEventListener('click',()=>showTag(button.dataset.tag)));
    phone.querySelector('[data-action=edit-tags]').addEventListener('click',openPicker);
    phone.querySelectorAll('footer [data-action=edit-tags]').forEach(b=>b.addEventListener('click',openPicker));
    phone.querySelector('[data-action=all-tags]')?.addEventListener('click',showAll);
    for (const [action,message] of [['back','这是独立账单预览'],['more','本轮仅确认标签设计'],['attachment','示例收据 · ¥38.00'],['copy','已复制示例账单']]) phone.querySelector(`[data-action=${action}]`)?.addEventListener('click',()=>toast(message));
  }
  function closeOverlay(restore=true) {
    phone.querySelector('.overlay')?.remove(); state.overlay=null;
    if (restore) returnFocus?.focus({preventScroll:true});
  }
  function makeSheet(content,klass='') {
    closeOverlay(false);
    const overlay = document.createElement('div'); overlay.className='overlay';
    overlay.innerHTML=`<section class="sheet ${klass}" role="dialog" aria-modal="true"><div class="grabber"></div>${content}</section>`;
    phone.append(overlay);
    overlay.addEventListener('click',e=>{if(e.target===overlay)cancel();});
    return overlay;
  }
  function setScene(scene) {
    state.scene=scene;
    document.querySelectorAll('[data-scene]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.scene===scene)));
    document.querySelector('#scene-caption').textContent=scene==='picker'?'标签选择器 / 草稿态':'账单详情 / 内容态';
  }
  function cancel() { closeOverlay(); if(state.scene==='picker')setScene('detail'); }
  function openPicker() {
    returnFocus=document.activeElement; state.draft=new Set(state.selected); state.query=''; setScene('picker');
    const overlay=makeSheet(`<div class="sheet-head"><button class="text-button" data-action="cancel">取消</button><h3 id="picker-title">选择标签</h3><span style="width:44px"></span></div><label class="search">${icon('search')}<input id="tag-search" type="search" placeholder="搜索标签" aria-label="搜索标签" autocomplete="off"><button data-action="clear-search" aria-label="清除搜索" hidden>${icon('close')}</button></label><div class="sheet-summary"><span>可多选</span><strong id="selected-count" aria-live="polite"></strong></div><div class="sheet-scroll" id="tag-options"></div><p class="tag-legend"><span><i></i>细框与勾表示已选</span><span>${icon('lock').replace('ui-icon','ui-icon legend-lock')} 停用标签不可选</span></p><div class="sheet-actions"><button class="secondary" data-action="clear">清空</button><button class="primary" data-action="confirm">确认</button></div><button class="tag-create" data-action="create">${icon('plus')}新建标签</button>`,'tag-picker');
    overlay.querySelector('[role=dialog]').setAttribute('aria-labelledby','picker-title'); state.overlay='picker';
    overlay.querySelector('[data-action=cancel]').addEventListener('click',cancel);
    overlay.querySelector('[data-action=clear]').addEventListener('click',()=>{state.draft.clear();renderOptions();});
    overlay.querySelector('[data-action=confirm]').addEventListener('click',()=>{state.selected=new Set(state.draft);closeOverlay(false);setScene('detail');renderDetail();toast(`已保存 ${state.selected.size} 个标签`);});
    overlay.querySelector('[data-action=create]').addEventListener('click',openCreate);
    const input=overlay.querySelector('#tag-search');
    input.addEventListener('input',()=>{state.query=input.value;renderOptions();});
    overlay.querySelector('[data-action=clear-search]').addEventListener('click',()=>{input.value='';state.query='';renderOptions();input.focus();});
    renderOptions();
    overlay.querySelector('[data-action=cancel]').focus({preventScroll:true});
  }
  function renderOptions() {
    const container=phone.querySelector('#tag-options'); if(!container)return;
    const scrollTop=container.scrollTop, query=state.query.trim().toLocaleLowerCase();
    const items=tags.filter(t=>t.label.toLocaleLowerCase().includes(query));
    const recent=tags.filter(t=>['work','coffee','travel','friends'].includes(t.id));
    const group=(label,items)=>`<h4 class="group-title">${label}</h4><div class="tag-wrap">${items.map(t=>pill(t,true)).join('')}</div>`;
    container.innerHTML=items.length?`${!query?group('最近使用',recent):''}${group(query?`搜索结果 <span>${items.length}</span>`:`全部标签 <span>${tags.length}</span>`,items)}`:`<div class="empty">${icon('search')}<strong>没有找到「${esc(state.query)}」</strong>换一个名称，或新建标签</div>`;
    container.scrollTop=scrollTop;
    phone.querySelector('#selected-count').textContent=`已选 ${state.draft.size} 个`;
    phone.querySelector('[data-action=confirm]').textContent=`确认${state.draft.size?`（${state.draft.size}）`:''}`;
    phone.querySelector('[data-action=clear]').disabled=state.draft.size===0;
    phone.querySelector('[data-action=clear-search]').hidden=!state.query;
    container.querySelectorAll('[data-tag]').forEach(button=>button.addEventListener('click',()=>{
      const t=tag(button.dataset.tag);if(t.disabled)return;
      const groupIndex=[...container.querySelectorAll('[data-tag]')].indexOf(button);
      state.draft.has(t.id)?state.draft.delete(t.id):state.draft.add(t.id);renderOptions();
      container.querySelectorAll('[data-tag]')[groupIndex]?.focus({preventScroll:true});
    }));
  }
  function showTag(id) {
    returnFocus=document.activeElement; const t=tag(id);
    const overlay=makeSheet(`<div class="sheet-head"><h3 id="tag-title">标签</h3><button class="icon-button" data-close aria-label="关闭">${icon('close')}</button></div><div class="tag-full-name" style="--tag:${t.color}">${esc(t.label)}</div><p class="tag-meta">完整名称<br>当前账单已关联此标签</p><button class="secondary tag-detail-actions" data-close>知道了</button>`);
    state.overlay='name';overlay.querySelector('[role=dialog]').setAttribute('aria-labelledby','tag-title');overlay.querySelectorAll('[data-close]').forEach(b=>b.addEventListener('click',()=>closeOverlay()));overlay.querySelector('[data-close]').focus({preventScroll:true});
  }
  function showAll() {
    returnFocus=document.activeElement;
    const overlay=makeSheet(`<div class="sheet-head"><h3 id="all-title">全部标签 · ${state.selected.size}</h3><button class="icon-button" data-close aria-label="关闭">${icon('close')}</button></div><div class="sheet-scroll"><div class="tag-wrap">${[...state.selected].map(tag).filter(Boolean).map(t=>pill(t)).join('')}</div></div><button class="primary" data-edit>编辑标签</button>`,'read-all');state.overlay='all';
    overlay.querySelector('[role=dialog]').setAttribute('aria-labelledby','all-title');overlay.querySelector('[data-close]').addEventListener('click',()=>closeOverlay());overlay.querySelector('[data-edit]').addEventListener('click',openPicker);overlay.querySelectorAll('[data-tag]').forEach(b=>b.addEventListener('click',()=>showTag(b.dataset.tag)));overlay.querySelector('[data-close]').focus({preventScroll:true});
  }
  function openCreate() {
    const draft=new Set(state.draft),query=state.query;
    const overlay=makeSheet(`<div class="sheet-head"><button class="text-button" data-back>返回</button><h3 id="create-title">新建标签</h3><span style="width:44px"></span></div><p class="sheet-note">名称保留原样；示例使用松柏绿。</p><input class="tag-name-input" id="new-tag-name" maxlength="40" placeholder="标签名称" aria-label="标签名称"><div class="create-error" role="status"></div><button class="primary" data-save>创建并选中</button>`);state.overlay='create';
    overlay.querySelector('[role=dialog]').setAttribute('aria-labelledby','create-title');
    function back(){openPicker();state.draft=draft;state.query=query;phone.querySelector('#tag-search').value=query;renderOptions();}
    overlay.querySelector('[data-back]').addEventListener('click',back);
    overlay.querySelector('[data-save]').addEventListener('click',()=>{const label=overlay.querySelector('input').value.trim();if(!label){overlay.querySelector('.create-error').textContent='请输入标签名称';return;}if(tags.some(t=>t.label===label)){overlay.querySelector('.create-error').textContent='已经有同名标签';return;}const t={id:`new-${Date.now()}`,label,color:'#729982'};tags.push(t);draft.add(t.id);back();});overlay.querySelector('input').focus({preventScroll:true});
  }
  function changeCase(value) {
    state.case=value;document.querySelector('#tag-case').value=value;
    state.selected=new Set(value==='empty'?[]:value==='many'?tags.filter(t=>!t.disabled).slice(0,18).map(t=>t.id):value==='long'?['business','english','unicode','work']:base);
    const wasPicker=state.scene==='picker';closeOverlay(false);renderDetail();if(wasPicker)openPicker();
  }
  document.querySelectorAll('[data-scene]').forEach(button=>button.addEventListener('click',()=>{if(button.dataset.scene==='picker')openPicker();else{closeOverlay(false);setScene('detail');renderDetail();}}));
  document.querySelector('#tag-case').addEventListener('change',e=>changeCase(e.target.value));
  document.querySelector('#show-hit').addEventListener('click',e=>{const active=e.currentTarget.getAttribute('aria-pressed')!=='true';e.currentTarget.setAttribute('aria-pressed',String(active));phone.classList.toggle('show-hit',active);});
  document.querySelector('#reset').addEventListener('click',()=>{setScene('detail');changeCase('normal');});
  document.querySelectorAll('[data-test]').forEach(button=>button.addEventListener('click',()=>{if(button.dataset.test==='many'){setScene('detail');changeCase('many');showAll();}else if(button.dataset.test==='long'){setScene('detail');changeCase('long');}else{openPicker();const input=phone.querySelector('#tag-search');input.value='旅行';state.query='旅行';renderOptions();input.focus();}}));
  document.addEventListener('keydown',e=>{
    if(e.key==='Escape'&&state.overlay){e.preventDefault();cancel();}
    if(e.key==='Tab'&&state.overlay){const focusable=[...phone.querySelectorAll('.overlay button:not(:disabled),.overlay input')].filter(el=>!el.hidden&&el.getClientRects().length);const first=focusable[0],last=focusable.at(-1);if(e.shiftKey&&document.activeElement===first){e.preventDefault();last?.focus();}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first?.focus();}}
  });
  bindControls();renderDetail();
  const params=new URLSearchParams(location.search);if(['normal','many','long','empty'].includes(params.get('case')))changeCase(params.get('case'));if(params.get('scene')==='picker')openPicker();
})();
