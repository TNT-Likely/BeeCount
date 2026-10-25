  // Page adapters supply their own records and original actions. They never read
  // the 60 component fixtures, recalculate rates, or change a page's row filters.
  function cRenderConsumer(row,options={}){
    const route=options.route||'page';
    const data={...cRowData(row),_hostId:null,_consumer:route,
      _editTarget:options.editTarget||{attribute:'data-action',value:route+'-row:'+row.id},
      _categoryTarget:options.categoryTarget||null,
      ...options.fields};
    return cRowsAPI.rowHtml(data,'c3-'+route+'-'+row.id)
      .replace('class="tx-shell"',`class="tx-shell c3-consumer" data-c3-consumer="${esc(route)}" data-source-id="${row.id}"`);
  }
  function cDispatchTarget(target){
    if(!target)return;
    const button=document.createElement('button');button.hidden=true;
    button.setAttribute(target.attribute,target.value);phone.appendChild(button);
    button.click();button.remove();
  }
  function cEditConsumer(r){
    if(r.readOnly||!r._editTarget)return cFieldsSheet(r);
    closeSheet();cDispatchTarget(r._editTarget);
  }
  function cCategoryConsumer(r){
    if(r._categoryTarget)return cDispatchTarget(r._categoryTarget);
    if(r.kind==='transfer')return cFieldsSheet(r);
    const parent=r._parentCategory||r.categoryLabel||r.title;
    const child=r.categoryLabel===parent?'':r.categoryLabel||'';
    dOpenCategory(parent,child,r.kind==='income'?'income':'expense');
  }
  function cConsumerMenu(r){
    cSheet('账单操作',menuRow('c3-consumer-fields:'+r.key,'file-text','查看详情')+
      (r.readOnly?'':menuRow('c3-consumer-edit:'+r.key,'pencil','编辑账单')));
  }
  function cAccountTransaction(row,account){
    const sign=row.type==='transfer'?(row.direction==='in'?'+':'−'):row.type==='income'?'+':'−';
    const code=account.currency||'CNY';
    return cRenderConsumer(row,{route:'ad',fields:{
      amount:sign+vSymbol(code)+money(row.amount),ledgerName:row.ledgerName||state.ledger,
      iconHtml:jCategoryVisual(row.subcategory||row.category,row.type==='transfer'?'arrow-left-right':row.icon||pIcon(row.category)),
      showFullDate:true,_parentCategory:dParentOf(row),
    }});
  }
  function cLegacyTagTransaction(row,tagName){
    return cRenderConsumer(row,{route:'td',categoryTarget:{attribute:'data-action',value:'td-category:'+(row.subcategory||row.category)},fields:{
      tags:(row.tags?.length?row.tags:[row.tag||tagName]).filter(Boolean).map(cHostTag),
      ledgerName:state.tdScope==='all'?(row.ledgerName||row.ledger||state.ledger):null,
      showTime:true,_parentCategory:dParentOf(row),
    }});
  }
  function cCalendarTransaction(row){
    return cRenderConsumer(row,{route:'cl',fields:{
      showTime:true,iconHtml:jCategoryVisual(row.subcategory||row.category,row.icon),
      _parentCategory:dParentOf(row),
    }});
  }
  function cDetailCurrencyTransaction(row,data,source,hidden){
    const currency=row.currency||source?.currency||'?',native=row.native;
    const foreign=currency!==source?.currency;
    // Preserve each source book's historical native value. The summary's query-
    // time projection belongs to dc97Project; it is never used as a row snapshot.
    const origin=[...pRows(),...tdFixtures].find(r=>r.id===row.id);
    const [year,month,day]=row.date.split('-').map(Number);
    const record={...row,year,month,day,title:row.note||'',category:row.category,
      subcategory:row.child||'',time:row.time||origin?.time||'00:00:00',
      tags:row.tags||origin?.tags,tag:row.tag,account:row.account,
      attachmentCount:row.attachments||0,readOnly:!!row.readOnly};
    return cRenderConsumer(record,{route:'dc97',
      editTarget:{attribute:'data-dc97',value:'edit:'+row.id},
      categoryTarget:{attribute:'data-dc97',value:'child:'+(row.child||row.category)},
      fields:{
        amount:(row.type==='income'?'+':'−')+dc97Symbol(currency)+dc97Format(row.amount),
        converted:foreign&&native!=null?'≈ '+dc97Symbol(source?.currency||'?')+dc97Format(native):null,
        happenedAt:(row.time||origin?.time)?row.date+'T'+(row.time||origin.time)+(String(row.time||origin.time).length===5?':00':''):row.date,
        hidden,ledgerName:data.scope==='all'?(source?.name||'未知账本'):null,
        _parentCategory:row.category,_ledgerName:source?.name||'未知账本',
        iconHtml:jCategoryVisual(row.child||row.category,row.type==='income'?'wallet':'utensils'),
      }});
  }
