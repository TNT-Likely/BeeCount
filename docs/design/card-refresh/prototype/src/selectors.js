  state.sLedgerQuery='';
  rSpecs['ledger-picker']={title:'选择账本',host:'home',kind:'sheet'};
  fDefine('ledger-picker','账本选择器','交互补充','presentation/v4/bindings/live_business_preview.dart',()=>sLedgerBody());
  function sLedgerBody(){const q=state.sLedgerQuery.trim().toLowerCase(),rows=[['日常生活','CNY','个人账本'],['家庭账本','CNY','共享账本 · 2 位成员']].filter(r=>r.join(' ').toLowerCase().includes(q));return `<label class="p-search-box">${icon('search')}<input data-s-ledger-query value="${esc(state.sLedgerQuery)}" aria-label="搜索账本" placeholder="搜索账本"></label><div class="s-ledger-list">${rows.map(([name,code,detail])=>btn('s-ledger-select:'+name,`<span class="s-ledger-icon">${icon('book-open')}</span><span class="s-ledger-copy"><b>${esc(name)}</b><small>${code} · ${detail}${name===state.ledger?' · 当前账本':''}</small></span>${icon(name===state.ledger?'check':'chevron-right')}`,name===state.ledger?name+'，当前账本':'切换到'+name,'s-ledger-choice',`aria-pressed="${name===state.ledger}"`)).join('')||'<p class="p-empty">没有匹配账本</p>'}</div>`;}
  root.addEventListener('input',e=>{if(!e.target.matches('[data-s-ledger-query]'))return;const pos=e.target.selectionStart;state.sLedgerQuery=e.target.value;rBuildModal();const input=phone.querySelector('[data-s-ledger-query]');input.focus({preventScroll:true});input.setSelectionRange(pos,pos);});
  root.addEventListener('click',e=>{const el=e.target.closest('[data-action]');if(!el)return;const [action,...parts]=el.dataset.action.split(':');if(action!=='ledger'&&action!=='s-ledger-select')return;e.preventDefault();e.stopImmediatePropagation();if(action==='ledger'){state.sLedgerQuery='';rOpenModal('ledger-picker');}else{state.ledger=parts.join(':');rDismiss();render();persist();}},true);
  Object.assign(state,{sCategoryQuery:'',sCategoryParent:'drink'});
  const sCategoryGroups=[
    {id:'blocked',name:'不可选分类',icon:'shapes',enabled:false,count:0,children:[]},
    {id:'food',name:'餐饮',icon:'utensils',enabled:false,count:3,children:[{id:'lunch',name:'午餐',icon:'utensils',enabled:true,count:2},{id:'dinner',name:'晚餐',icon:'utensils',enabled:true,count:1}]},
    {id:'drink',name:'饮品',icon:'coffee',enabled:false,count:1,children:[{id:'coffee',name:'咖啡',icon:'coffee',enabled:true,count:1},{id:'tea',name:'奶茶',icon:'cup-soda',enabled:false,count:0}]},
    {id:'traffic',name:'交通',icon:'train-front',enabled:true,count:2,children:[]}
  ];
  rSpecs['category-select']={title:'支出',host:'editor',kind:'dialog'};
  fDefine('category-select','分类选择 · 即时选择与笔数','记账选择与弹层','widgets/biz/category_selector_dialog.dart',()=>sCategoryBody());
  function sCategoryBody(){
    const q=state.sCategoryQuery.trim().toLowerCase(),groups=sCategoryGroups.filter(g=>g.name.includes(q)||g.children.some(c=>c.name.includes(q))),group=groups.find(g=>g.id===state.sCategoryParent)||groups[0];
    const rootChoice=g=>`<div>${btn('s-category-parent:'+g.id,`<span class="bc-entry-icon">${jCategoryVisual(g.name,g.icon)}</span><span>${esc(g.name)}</span>`,g.name,'p-category',`aria-pressed="${group?.id===g.id}" ${!g.enabled&&!g.children.length?'disabled aria-disabled="true"':''}`)}${g.count?`<small class="bc-small">${g.count}笔</small>`:''}</div>`;
    const children=group?.children.filter(c=>!q||group.name.includes(q)||c.name.includes(q))||[],choices=group&&children.length?[group,...children]:[];
    const childBlock=choices.length?`<div data-s-category-children="${group.id}" style="display:grid;grid-template-columns:repeat(${qPreview.width<=340?2:4},minmax(0,1fr));gap:5px;margin-top:8px;padding:8px;background:var(--bc-soft);border-radius:14px">${choices.map(c=>`<div><button data-action="s-category-child:${c.id}" aria-label="选择${esc(c.name)}" ${c.enabled?'':'disabled aria-disabled="true"'} style="display:flex;align-items:center;gap:5px;width:100%;min-height:44px;padding:7px;border:0;border-radius:12px;background:transparent;color:inherit;opacity:${c.enabled?1:.4}">${jCategoryVisual(c.name,c.icon)}<span style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(c.name)}</span></button>${c.count?`<small class="bc-small">${c.count}笔</small>`:''}</div>`).join('')}</div>`:'';
    let roots='';
    for(let start=0;start<groups.length;start+=4){
      const row=groups.slice(start,start+4);
      roots+=`<div data-s-category-row="${start/4}" style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:4px;text-align:center${start?';margin-top:4px':''}">${row.map(rootChoice).join('')}</div>`;
      if(row.some(g=>g.id===group?.id))roots+=childBlock;
    }
    const bodyHeight=Math.min(440,qPreview.height*.62);
    return `<style>.bc-sheet:has(.s-category-frame)>.bc-sheet-title{height:36px!important;min-height:36px!important}.bc-sheet:has(.s-category-frame)>.bc-sheet-title button{width:36px!important;height:36px!important;min-height:36px!important;min-width:36px!important;padding:0!important}.bc-sheet:has(.s-category-frame)>.bc-sheet-title h3{font-size:calc(16px * var(--q-scale,1));line-height:1.6}.s-category-frame>.p-search-box{height:48px;min-height:48px;margin:0;border-radius:13px;padding:7px 12px;flex:none}.s-category-frame [data-action^="s-category-child"]{font-size:calc(11px * var(--q-scale,1))}.s-category-frame [data-action^="s-category-child"] svg,.s-category-frame [data-action^="s-category-child"] .j-category-image{width:18px;height:18px;flex:none}.s-category-frame .bc-small{font-size:calc(10px * var(--q-scale,1))}</style><div class="s-category-frame" style="height:${bodyHeight}px;display:flex;flex-direction:column;min-height:0"><label class="p-search-box">${icon('search')}<input data-s-category-query value="${esc(state.sCategoryQuery)}" placeholder="搜索分类" aria-label="搜索分类"></label><div style="flex:1;min-height:0;overflow:auto;margin-top:8px"><div class="bc-surface" style="padding:12px">${groups.length?roots:'<p class="bc-small">暂无分类</p>'}</div></div></div>`;
  }
  root.addEventListener('input',e=>{if(!e.target.matches('[data-s-category-query]'))return;const pos=e.target.selectionStart;state.sCategoryQuery=e.target.value;rBuildModal();const field=phone.querySelector('[data-s-category-query]');field?.focus({preventScroll:true});field?.setSelectionRange(pos,pos);});
  root.addEventListener('click',e=>{
    const el=e.target.closest('[data-action]');if(!el)return;const [action,id]=el.dataset.action.split(':');if(!['s-category-parent','s-category-child'].includes(action))return;e.preventDefault();e.stopImmediatePropagation();
    const group=sCategoryGroups.find(g=>g.id===id),child=sCategoryGroups.flatMap(g=>g.children).find(c=>c.id===id),choice=group||child;
    if(!choice)return;if(action==='s-category-parent'&&group?.children.length){state.sCategoryParent=id;rBuildModal();return;}if(!choice.enabled)return;
    state.category=group?.name||sCategoryGroups.find(g=>g.children.some(c=>c.id===id)).name;state.subcategory=child?.name||'';rDismiss();render();
  },true);
