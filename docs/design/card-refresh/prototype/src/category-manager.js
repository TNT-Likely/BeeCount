  Object.assign(state,{cmParent:'饮品',cmSeedHier:false,cmCleared:[],cmDrag:null});
  const cmOriginalManager=dCategoryManager;
  const cmChildren=name=>state.dManageType==='income'?(name==='工资'?['固定工资']:[]):pCategoryTree[name]||[];
  function cmManager(){
    state.leaf='分类管理';
    const t=document.createElement('template');t.innerHTML=cmOriginalManager();
    const actions=t.content.querySelector('.bc-subhead .bc-row');
    const plus=t.content.querySelector('[data-action="leaf:新建分类"]');
    if(plus){plus.dataset.action='cm-new-category';if(actions)actions.prepend(plus);}
    for(const button of t.content.querySelectorAll('[data-action^="d-manage-detail:"]')){
      const [,parent,child]=button.dataset.action.split(':');button.dataset.action='cm-edit';button.dataset.cmParent=parent;button.dataset.cmChild=child||'';button.setAttribute('aria-label','编辑'+(child||parent)+'分类');
    }
    for(const button of t.content.querySelectorAll('.d-manage-children [data-action^="leaf:编辑分类:"]')){
      button.dataset.cmParent=button.dataset.action.split(':')[2];button.dataset.action='cm-open-children';button.innerHTML=icon('settings-2')+'管理';
    }
    for(const row of t.content.querySelectorAll('.d-rank-item')){
      const toggle=row.querySelector('[data-action^="d-manage-toggle:"]');if(!toggle)continue;
      const name=toggle.dataset.action.split(':')[1];row.dataset.cmCategory=name;
      if(state.cmCleared.includes(name))row.remove();
      const visual=toggle.querySelector('.bc-entry-icon');if(visual){visual.draggable=true;visual.dataset.cmDrag=name;visual.title='长按图标拖动排序';}
    }
    if(state.page==='flow-category-empty'){
      const panel=t.content.querySelector('.bc-menu-card');
      if(panel)panel.innerHTML=`<div class="cm-empty"><p>暂无分类</p>${btn('cm-new-category','新建分类','新建分类','bc-primary')}</div>`;
    }
    const head=t.content.querySelector('.bc-subhead'),tabs=t.content.querySelector('.bc-period');head?.remove();tabs?.remove();
    return `<div class="cm-manager-page">${head?.outerHTML||''}${tabs?.outerHTML||''}<div class="cm-manager-scroll">${t.innerHTML}<input hidden type="file" data-cm-import accept=".zip" aria-label="选择分类 ZIP 包"></div></div>`;
  }
  dCategoryManager=cmManager;
  const cmPreviousBuildModal=rBuildModal;
  rBuildModal=function(){
    cmPreviousBuildModal();
    if(state.rModal==='category-children'){
      const title=phone.querySelector('.bc-sheet-title h3');
      if(title)title.innerHTML=`<span class="cm-parent-icon">${jCategoryVisual(state.cmParent,pIcon(state.cmParent))}</span><span>${esc(state.cmParent)}</span>`;
      if(globalThis.lucide)globalThis.lucide.createIcons({attrs:{width:20,height:20}});
    }
  };
  function cmChildrenBody(){return `<div class="cm-child-grid">${cmChildren(state.cmParent).map((name,index)=>btn('cm-edit',`<span class="cm-child-icon">${jCategoryVisual(name,pIcon(state.cmParent))}</span><span class="cm-child-name">${esc(name)}</span><small>${[8,14,2,0][index]??0}笔</small>`,'编辑'+name,'',`data-cm-parent="${esc(state.cmParent)}" data-cm-child="${esc(name)}"`)).join('')}</div><div class="cm-peer-actions">${btn('cm-new-child',`${icon('plus')}添加`,'添加二级分类','bc-secondary')}${btn('cm-edit-parent',`${icon('pencil-line')}编辑`,'编辑父分类','bc-secondary')}</div>`;}
  function cmToolsBody(){return `<p class="cm-tip">长按分类图标拖动可调整顺序，二级分类跟随父分类展示。</p>${menuCard([['cm-share','share-2','分享分类'],['cm-new-category','plus','新建分类'],['cm-import','download','导入分类'],['cm-default','sparkles','生成默认分类'],['cm-clear','trash-2','清空未使用分类']])}`;}
  const cmPreviousModal=rModalBody;
  rModalBody=function(key){
    if(key==='category-tools')return cmToolsBody();
    if(key==='category-children')return cmChildrenBody();
    if(key==='category-share')return menuCard([['cm-share-choice:current','list-filter',state.dManageType==='income'?'仅收入分类':'仅支出分类'],['cm-share-choice:all','layers','全部分类']])+`<div class="cm-peer-actions">${btn('r-close','取消','取消','bc-secondary')}</div>`;
    if(key==='category-defaults')return `<div class="cm-mode-choices">${[[false,'一级分类'],[true,'二级分类']].map(([value,label])=>`<label><input class="v4-control" type="radio" name="cm-mode" data-cm-mode="${value}" ${state.cmSeedHier===value?'checked':''}><span>${label}</span></label>`).join('')}</div><p class="cm-tip">已有分类会保留，同名的默认分类会跳过。</p>${rModalActions('r-close','取消','cm-default-confirm','确定')}`;
    if(key==='taxonomy-import')return menuCard([['cm-import-choice:merge','git-merge','合并','保留现有分类，新增不存在的'],['cm-import-choice:overwrite','refresh-cw','覆盖','清空未使用分类后导入']])+`<div class="cm-peer-actions">${btn('r-close','取消','取消','bc-secondary')}</div>`;
    if(key==='category-clear')return `<p class="cm-tip">将清空 3 个未使用的分类，有账单的父子分类会保留。</p><div class="cm-clear-list">数码<br>运动<br>宠物</div><div class="cm-danger-actions">${rModalActions('r-close','取消','cm-clear-confirm','删除')}</div>`;
    return cmPreviousModal(key);
  };
  const cmGroup=[...picker.querySelectorAll('optgroup')].find(g=>g.label==='补齐 · 分类标签与预算');
  for(const [key,title] of [['category-management','分类管理'],['category-empty','分类管理 · 空分类'],['category-children','管理二级分类 · 图标与图片'],['category-share','选择分享范围'],['category-defaults','生成默认分类 · 模式'],['category-clear','清空未使用分类']]){
    fDefine(key,title,'分类标签与预算','category/category_manage_page.dart',()=>['category-management','category-empty'].includes(key)?cmManager():rModalBody(key));cmGroup.appendChild(new Option(title,'flow-'+key));
  }
  fDefs['taxonomy-import'].title='导入分类包 · ZIP';fDefs['taxonomy-import'].body=()=>rModalBody('taxonomy-import');
  Object.assign(rSpecs,{'category-tools':{title:'分类工具',host:'flow-category-management',kind:'dialog'},'category-children':{title:'饮品',host:'flow-category-management',kind:'dialog'},'category-share':{title:'选择分享范围',host:'flow-category-management',kind:'dialog'},'category-defaults':{title:'生成默认分类 · 支出',host:'flow-category-management',kind:'dialog'},'taxonomy-import':{title:'选择导入模式',host:'flow-category-management',kind:'dialog'},'category-clear':{title:'清空未使用分类',host:'flow-category-management',kind:'dialog'}});
  const cmPreviousRender=fRender;
  fRender=function(key){return ['category-management','category-empty'].includes(key)?cmManager():cmPreviousRender(key);};
  function cmEdit(parent,child='',creating=false){
    state.dCategoryType=state.dManageType==='income'?'income':'expense';state.dCategory=parent;state.dSub=child;state.cmEditorBack=true;
    if(creating){state.jEditorRoute='';state.jEditorSub=!!parent;if(parent)state.fForm.categoryParent=parent;}
    else {
      const name=child||parent,art=state.jIconOverrides[name]||jSubIconDefinitions[name]||pIcon(parent),groups=jEditorCatalog[state.dCategoryType];
      const hit=groups.flatMap((group,index)=>group.items.map(item=>({item,index}))).find(row=>row.item[1]===art);
      state.fForm.categoryName=name;state.jEditorRoute='category-edit';state.jEditorIcon=hit?.item[0]||'restaurant';state.fIcon=art;state.jEditorGroup=hit?String(hit.index):'common';
      state.jIconMode=state.jCustomIcons[name]?'custom':'preset';if(state.jCustomIcons[name]){state.jIconImage=state.jCustomIcons[name];state.jIconFit=state.jCustomIconFits[name]||'contain';}
    }
    rDismiss();navigate(creating?'flow-category-new':'flow-category-edit');
  }
  const cmPreviousResult=fResult;
  fResult=function(title,description,back){if(back==='categories'&&state.cmEditorBack){back='category-management';state.cmEditorBack=false;}return cmPreviousResult(title,description,back);};
  root.addEventListener('click',event=>{
    const el=event.target.closest('[data-action^="cm-"]');if(!el)return;event.preventDefault();event.stopImmediatePropagation();
    const [action,arg]=el.dataset.action.split(':');
    if(action==='cm-open-children'){state.cmParent=el.dataset.cmParent;rSpecs['category-children'].title=state.cmParent;rOpenModal('category-children');}
    else if(action==='cm-edit')cmEdit(el.dataset.cmParent,el.dataset.cmChild);
    else if(action==='cm-new-category')cmEdit('', '',true);
    else if(action==='cm-new-child')cmEdit(state.cmParent,'',true);
    else if(action==='cm-edit-parent')cmEdit(state.cmParent);
    else if(action==='cm-share'){rDismiss();rOpenModal('category-share');}
    else if(action==='cm-share-choice'){rDismiss();notice('已选择'+(arg==='all'?'全部分类':state.dManageType==='income'?'收入分类':'支出分类')+'分享范围');}
    else if(action==='cm-import'){rDismiss();phone.querySelector('[data-cm-import]')?.click();}
    else if(action==='cm-import-choice'){rDismiss();notice(arg==='merge'?'已选择合并导入':'已选择覆盖导入');}
    else if(action==='cm-default'){rDismiss();state.cmSeedHier=false;rSpecs['category-defaults'].title='生成默认分类 · '+(state.dManageType==='income'?'收入':'支出');rOpenModal('category-defaults');}
    else if(action==='cm-default-confirm'){rDismiss();navigate('flow-category-management');notice('已确认生成'+(state.cmSeedHier?'二级':'一级')+'默认分类');}
    else if(action==='cm-clear'){rDismiss();rOpenModal('category-clear');}
    else if(action==='cm-clear-confirm'){state.cmCleared=['数码','运动','宠物'];rDismiss();render();notice('已清空未使用的分类');}
  },true);
  root.addEventListener('change',event=>{if(event.target.matches('[data-cm-mode]'))state.cmSeedHier=event.target.dataset.cmMode==='true';if(event.target.matches('[data-cm-import]')&&event.target.files.length){const file=event.target.files[0];if(!file.name.toLowerCase().endsWith('.zip')){notice('请选择分类 ZIP 包','error');return;}rOpenModal('taxonomy-import');}});
  root.addEventListener('dragstart',event=>{const el=event.target.closest('[data-cm-drag]');if(el)state.cmDrag=el.dataset.cmDrag;});
  root.addEventListener('dragover',event=>{if(state.cmDrag&&event.target.closest('[data-cm-category]'))event.preventDefault();});
  root.addEventListener('drop',event=>{const target=event.target.closest('[data-cm-category]');if(!state.cmDrag||!target)return;event.preventDefault();const list=state.dManageType==='income'?incomes:pAllCategories,from=list.findIndex(row=>row[0]===state.cmDrag),to=list.findIndex(row=>row[0]===target.dataset.cmCategory);if(from>=0&&to>=0){list.splice(to,0,list.splice(from,1)[0]);render();notice('分类顺序已调整');}state.cmDrag=null;});
