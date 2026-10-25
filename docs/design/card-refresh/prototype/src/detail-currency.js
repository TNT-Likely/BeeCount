/* r97: independent read-only currency projection. Inject after tag-detail.js,
   before const views. Both placeholders are supplied by the host build. */
const dc97Texts=__DETAIL_CURRENCY_TEXTS__;
const dc97Fixtures=__DETAIL_CURRENCY_FIXTURES__;
function dc97Copy(value){return JSON.parse(JSON.stringify(value));}
function dc97Known(code){return /^[A-Z]{3}$/.test(code||'')&&dc97Fixtures.currencyCodes.includes(code);}
function dc97Quote(data,source,target){
 if(source===target)return {rate:1};
 const direct=data.rates[target]?.[source];
 if(direct!==undefined){const n=Number(direct.rate);return Number.isFinite(n)&&n>0?{...direct,rate:n}:null;}
 const reverse=data.rates[source]?.[target],n=Number(reverse?.rate);
 return reverse&&Number.isFinite(n)&&n>0?{...reverse,rate:1/n}:null;
}
function dc97Project(data,rows){
 const target=data.books.find(b=>b.id===data.target)?.currency,values={},missing=[],currencies=new Set(),dates=[];
 for(const row of rows){
   const source=data.books.find(b=>b.id===row.book)?.currency,original=row.currency?.trim().toUpperCase();
   const mark=code=>{missing.push(row.id);currencies.add(code);};
   if(!dc97Known(source)||!dc97Known(target)){mark('?');continue;}
   if(original&&!dc97Known(original)){mark(original);continue;}
   let native=row.native;
   if(native==null){if(original&&original!==source){mark(original+'→'+source);continue;}native=row.amount;}
   const quote=dc97Quote(data,source,target);
   if(!Number.isFinite(native)||!quote||!Number.isFinite(native*quote.rate)){mark(source);continue;}
   values[row.id]=native*quote.rate;
   if(source!==target&&quote.date)dates.push(quote.date);
 }
 dates.sort();return {target,values,missing,currencies:[...currencies].sort(),date:dates[0]||null,complete:missing.length===0&&dc97Known(target)};
}
function dc97Summary(data,kind){
 const inPeriod=row=>{
   if(data.period==='all')return true;
   const [year,month]=data.anchor.split('-').map(Number),day=kind==='tag'?Math.max(1,Math.min(28,data.monthStartDay||1)):1;
   const start=new Date(year,data.period==='year'?0:month-1,day),end=new Date(data.period==='year'?year+1:year,data.period==='year'?0:month,day),date=new Date(row.date+'T12:00:00');
   return date>=start&&date<end;
 };
 const scoped=data.rows.map(row=>({...row,...data.rowPatch?.[row.id]})).filter(row=>(data.scope==='all'||row.book===data.target)&&inPeriod(row));
 const rows=scoped.filter(row=>kind==='category'?row.category===(data.category||'餐饮')&&row.type===(data.kind||'expense')&&(!data.child||row.child===data.child):row.tag===(data.tag||'旅行'));
 rows.sort((a,b)=>data.sort==='amountAsc'?a.amount-b.amount:data.sort==='amountDesc'?b.amount-a.amount:data.sort==='timeAsc'?a.date.localeCompare(b.date):b.date.localeCompare(a.date));
 const projection=dc97Project(data,rows),sum=list=>list.reduce((s,r)=>s+(projection.values[r.id]||0),0);
 const expenseRows=rows.filter(r=>r.type==='expense'&&(kind==='category'||!r.excludeStats)),incomeRows=rows.filter(r=>r.type==='income'&&(kind==='category'||!r.excludeStats));
 const denominator=scoped.filter(r=>r.type===(data.kind||'expense')),base=dc97Project(data,denominator),baseTotal=denominator.reduce((s,r)=>s+(base.values[r.id]||0),0);
 const measuredRows=kind==='category'&&data.kind==='income'?incomeRows:expenseRows,expense=sum(measuredRows),income=sum(incomeRows),groups=new Map();
 for(const row of measuredRows){const name=kind==='category'?row.child:row.child||row.category;if(!name)continue;const g=groups.get(name)||{name,count:0,amount:0};g.count++;g.amount+=projection.values[row.id]||0;groups.set(name,g);}
 return{rows,projection,expense,income,count:rows.length,average:rows.length?expense/rows.length:0,share:projection.complete&&base.complete&&baseTotal?expense/baseTotal:null,groups:[...groups.values()].sort((a,b)=>b.amount-a.amount)};
}
let dc97Active=null,dc97SceneKey=null,dc97DirectSignature=null;
function dc97Use(key,kind){if(dc97SceneKey!==key){const scene=dc97Fixtures.scenes.find(s=>s.key===key);dc97Active=dc97Copy(scene?.scenario||{...dc97Fixtures.defaults,scope:'current'});dc97SceneKey=key;state.dCategory='餐饮';state.dSub='';state.dTag='旅行';state.dPeriod=dc97Active.period;state.tdPeriod=dc97Active.period;}return dc97Render(kind);}
function dc97Text(key,args={}){return String(dc97Texts[key]||key).replace(/\{(\w+)\}/g,(_,name)=>args[name]??'');}
function dc97Format(amount){return Number(amount).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});}
function dc97Symbol(code){return code==='USD'?'US$':code==='CNY'?'¥':code==='EUR'?'€':code+' ';}
function dc97Render(kind){
 const data=dc97Active,d=dc97Summary(data,kind),p=d.projection,book=data.books.find(b=>b.id===data.target),hidden=data.privacy||state.hide===true;
 const n=value=>hidden?'••••':p.complete?dc97Format(value):'—',money=value=>hidden?'••••':p.complete?dc97Symbol(p.target)+dc97Format(value):'—';
 const metric=(label,value)=>`<div><span>${esc(label)}</span><b>${esc(value)}</b></div>`;
 const typeLabel=data.kind==='income'?'收入':'支出';
 const title=kind==='tag'?(data.tag||'旅行'):data.child||data.category||'餐饮',scope=data.scope==='all'?'全部账本':book?.name||'未知账本';
 const date=p.date,stale=date&&new Date('2026-10-25')-new Date(date)>7*86400000;
 const notice=`<aside class="dc97-notice ${p.missing.length||stale?'dc97-warning':''}" role="status"><span>${icon(p.missing.length||stale?'triangle-alert':'info')}</span><div><p>${esc(dc97Text('v4DetailConvertedScope',{currency:p.target||'—'}))}</p>${p.missing.length?`<p class="dc97-missing">${esc(dc97Text('v4DetailMissingConversion',{count:p.missing.length,currencies:p.currencies.map(c=>c==='?'?'未知账本':c).join(' / ')}))}</p>`:''}${date?`<p>${esc(dc97Text(stale?'v4DetailRatesStale':'v4DetailRateDate',{date}))}</p>`:''}</div></aside>`;
 const ratio=value=>hidden?'••••':p.complete&&value!=null?(value*100).toFixed(1)+'%':'—';
 const groups=d.groups.map(g=>`<button data-dc97="child:${esc(g.name)}" class="dc97-group"><span class="dc97-group-copy"><b>${esc(g.name)}</b><small>${g.count}笔${kind==='category'?' · '+ratio(d.expense?g.amount/d.expense:0):''}</small><i><em style="width:${hidden||!p.complete||!d.expense?0:g.amount/d.expense*100}%"></em></i></span><span>${money(g.amount)}</span>${icon('chevron-right')}</button>`).join('');
 const sortedDates=[...new Set(d.rows.map(r=>r.date.slice(0,data.period==='month'?10:7)))].sort(),buckets=sortedDates.map(date=>d.rows.filter(r=>r.date.startsWith(date)).reduce((s,r)=>s+(p.values[r.id]||0),0));let running=0;const trend=buckets.map(v=>running+=v),max=Math.max(1,...trend);
 const chart=kind==='category'?`<article class="dc97-card"><header><h3>累计支出趋势</h3><small>${esc(p.target||'—')}</small></header><div class="dc97-trend" aria-label="累计支出趋势">${hidden||!p.complete?'<span>—</span>':trend.map((v,i)=>`<i style="height:${Math.max(1,v/max*100)}%" aria-label="${sortedDates[i]} ${money(v)}"></i>`).join('')}</div><div class="dc97-axis"><span>${hidden||!p.complete?'':sortedDates[0]||''}</span><span>${hidden||!p.complete?'':sortedDates.at(-1)||''}</span></div></article>`:'';
 const days=new Map();for(const row of d.rows){const old=days.get(row.date)||{expense:0,income:0};if(row.type==='expense')old.expense+=p.values[row.id]||0;if(row.type==='income')old.income+=p.values[row.id]||0;days.set(row.date,old);}
 let lastDate=null;const rows=d.rows.map(row=>{const source=data.books.find(b=>b.id===row.book);const day=lastDate===row.date?'':`<div class="dc97-day"><span>${row.date}</span><small>支出 ${money(days.get(row.date).expense)}${days.get(row.date).income?' · 收入 '+money(days.get(row.date).income):''}</small></div>`;lastDate=row.date;return `${day}${cDetailCurrencyTransaction(row,data,source,hidden)}`;}).join('');
 return `<section class="dc97-detail" data-dc97-kind="${kind}" data-dc97-complete="${p.complete}"><header class="dc97-header"><button data-action="back" aria-label="返回">${icon('chevron-left')}</button><h2>${kind==='category'?'分类':'标签'}详情</h2>${kind==='tag'?'<button data-dc97="tag-edit" aria-label="编辑标签">'+icon('pencil-line')+'</button><button data-dc97="tag-delete" aria-label="删除标签">'+icon('trash-2')+'</button>':'<button data-action="d-category-menu" aria-label="更多">'+icon('ellipsis')+'</button>'}</header><nav class="dc97-period">${[['month','月'],['year','年'],['all','全部']].map(([id,label])=>`<button data-dc97="period:${id}" aria-pressed="${data.period===id}">${label}</button>`).join('')}</nav>${data.period==='all'?'':`<label class="dc97-date">${icon('calendar-days')}<input aria-label="选择周期" type="${data.period==='year'?'number':'month'}" data-dc97-date value="${data.period==='year'?data.anchor.slice(0,4):data.anchor}"></label>`}${data.child?`<button data-dc97="parent" class="dc97-parent">${icon('chevron-left')}餐饮</button>`:''}<article class="dc97-card dc97-hero"><div class="dc97-identity"><span>${icon(kind==='tag'?'tag':'utensils')}</span><div><h3>${kind==='tag'?`<span class="dc97-tag">${title}</span>`:esc(title)}</h3><small>${kind==='category'?(data.child?esc((data.category||'餐饮')+' / 二级分类'):'一级分类 · 2个二级分类')+' · ':''}${esc(scope)}</small></div></div><p>${kind==='tag'?'总支出':data.period==='month'?'本月'+typeLabel:data.period==='year'?'本年'+typeLabel:'累计'+typeLabel}</p><div class="dc97-amount"><span>${hidden||!p.complete?'':esc(dc97Symbol(p.target))}</span><b>${n(d.expense)}</b></div><div class="dc97-metrics">${kind==='tag'?metric('总收入',money(d.income))+metric('关联分类',new Set(d.rows.map(r=>r.child||r.category)).size)+metric('交易笔数',d.count+'笔'):metric('记录笔数',d.count+'笔')+metric('单笔均额',money(d.average))+metric('占总'+typeLabel,ratio(d.share))}</div></article>${notice}${groups&&!data.child?`<article class="dc97-card"><h3>${kind==='category'?'二级分类':'分类分布'}</h3>${groups}</article>`:''}${chart}${kind==='category'?`<div class="dc97-sorts">${[['timeDesc','时间降序'],['timeAsc','时间升序'],['amountDesc','金额降序'],['amountAsc','金额升序']].map(([key,label])=>`<button data-dc97="sort:${key}" aria-pressed="${data.sort===key}">${label}</button>`).join('')}</div>`:''}<header class="dc97-list-heading"><h3>关联交易</h3><span>${d.count}笔</span></header><article class="dc97-card dc97-list c3-consumer-list">${rows||'<div class="dc97-empty"><b>暂无关联记录</b><p>符合当前筛选的账单将在此显示</p></div>'}</article><button class="dc97-record" data-dc97="record">${icon('plus')}使用此${kind==='tag'?'标签':'分类'}记一笔</button></section>`;
}
function dc97DeleteTag(){
 const dialog=document.createElement('dialog');dialog.className='dc97-dialog';dialog.setAttribute('aria-label','删除标签');dialog.innerHTML='<h3>删除标签</h3><p>删除标签及关联关系，账单保留。</p><footer><button data-dc97-cancel>取消</button><button data-dc97-confirm>删除</button></footer>';phone.appendChild(dialog);dialog.showModal();const close=()=>{dialog.close();dialog.remove();};dialog.addEventListener('click',e=>{if(e.target.closest('[data-dc97-cancel]'))close();if(e.target.closest('[data-dc97-confirm]')){dc97Active.rows=dc97Active.rows.map(r=>({...r,tag:null}));close();render();}});dialog.addEventListener('cancel',close);
}
const dc97ComponentState={status:'complete',privacy:false};
function dc97Component(){
 const s=dc97ComponentState,missing=s.status==='missing',stale=s.status==='stale',amount=s.privacy?'••••':missing?'—':'152.00';
 return `<section class="dc97-detail dc97-component"><p class="bc-small">局部合成示例 · 当前账本 CNY；不更改真实汇率和历史账单</p><nav class="dc97-sorts">${[['complete','完整'],['missing','缺失'],['stale','陈旧']].map(([id,label])=>`<button data-dc97="component:${id}" aria-pressed="${s.status===id}">${label}</button>`).join('')}<button data-dc97="component-privacy" aria-pressed="${s.privacy}">隐私 ${s.privacy?'开启':'关闭'}</button></nav><article class="dc97-card dc97-hero"><div class="dc97-identity"><span>${icon('chart-no-axes-combined')}</span><div><h3>QA 分类 / 标签汇总</h3><small>全部账本 · CNY / USD</small></div></div><p>总支出</p><div class="dc97-amount"><span>${s.privacy||missing?'':'¥'}</span><b>${amount}</b></div><div class="dc97-metrics"><div><span>交易笔数</span><b>2笔</b></div><div><span>单笔均额</span><b>${s.privacy?'••••':missing?'—':'¥76.00'}</b></div><div><span>占比</span><b>${s.privacy?'••••':missing?'—':'100.0%'}</b></div></div></article><aside class="dc97-notice ${missing||stale?'dc97-warning':''}" role="status"><span>${icon(missing||stale?'triangle-alert':'info')}</span><div><p>${esc(dc97Text('v4DetailConvertedScope',{currency:'CNY'}))}</p>${missing?'<p class="dc97-missing">'+esc(dc97Text('v4DetailMissingConversion',{count:1,currencies:'USD'}))+'</p>':''}${stale?'<p>'+esc(dc97Text('v4DetailRatesStale',{date:'2020-01-01'}))+'</p>':''}</div></aside></section>`;
}
if(typeof window!=='undefined'){
 const categoryOriginal=dCategoryDetail,tagOriginal=dTagDetail;
 function dc97Direct(kind){
   const key='direct-'+kind,signature=JSON.stringify([kind,state.dCategory,state.dSub,state.dCategoryType,state.dTag,state.tdScenario,state.tdScope,state.ledger]);
   if(dc97SceneKey!==key||dc97DirectSignature!==signature){
     const source=kind==='tag'?tdRows():dRows();
     dc97Active=dc97Copy({...dc97Fixtures.defaults,scope:kind==='tag'&&state.tdScope==='all'?'all':'current',period:kind==='tag'?state.tdPeriod||'all':state.dPeriod||'all',anchor:String(state.year||2026)+'-'+String(state.month||10).padStart(2,'0'),category:state.dCategory||'餐饮',kind:state.dCategoryType||'expense',child:state.dSub||null,tag:state.dTag||source[0]?.tag||'日常',rows:source.map(r=>({id:r.id,book:r.ledgerId||r.book||1,type:r.type||'expense',amount:r.amount,currency:r.currency||null,native:r.nativeAmount??null,category:dParentOf(r),child:r.subcategory||(dSubOf(r)==='未细分'?null:dSubOf(r)),tag:r.tag,note:r.title||'',date:String(r.year||2026)+'-'+String(r.month||state.month||10).padStart(2,'0')+'-'+String(r.day||1).padStart(2,'0'),account:r.account||'',excludeStats:r.excludeStats,excludeBudget:r.excludeBudget,attachments:r.attachment?1:0}))});
     dc97SceneKey=key;dc97DirectSignature=signature;
   }
   return dc97Render(kind);
 }
 dCategoryDetail=()=>dc97Direct('category');dTagDetail=()=>dc97Direct('tag');
 for(const scene of dc97Fixtures.scenes)fDefine(scene.key,scene.title,'分类与标签 · 汇总币种',scene.kind==='tag'?'tag/tag_detail_page.dart':'transaction/category_detail_page.dart',()=>dc97Use(scene.key,scene.kind));
 fDefine('detail-currency-component','汇总币种提示 · 受控状态','分类与标签 · 汇总币种','presentation/v4/gallery/detail_currency_sample.dart',dc97Component);
 const dc97PreviousRender=fRender;fRender=function(key){return key==='detail-currency-component'||dc97Fixtures.scenes.some(s=>s.key===key)?fDefs[key].body():dc97PreviousRender(key);};
 const group=document.createElement('optgroup');group.label='分类与标签 · 汇总币种';for(const scene of dc97Fixtures.scenes)group.appendChild(new Option(scene.title,'flow-'+scene.key));group.appendChild(new Option('汇总币种提示 · 受控状态','flow-detail-currency-component'));picker.appendChild(group);
 root.addEventListener('click',event=>{const el=event.target.closest('[data-dc97]');if(!el)return;event.preventDefault();event.stopImmediatePropagation();const [action,arg]=el.dataset.dc97.split(':'),kind=phone.querySelector('.dc97-detail')?.dataset.dc97Kind||'category';if(action==='component'){dc97ComponentState.status=arg;render();return;}else if(action==='component-privacy'){dc97ComponentState.privacy=!dc97ComponentState.privacy;render();return;}else if(action==='tag-edit'){navigate('leaf:编辑标签:'+(dc97Active.tag||'旅行'));return;}else if(action==='tag-delete'){dc97DeleteTag();return;}else if(action==='period'){dc97Active.period=arg;state.dPeriod=arg;state.tdPeriod=arg;}else if(action==='sort')dc97Active.sort=arg;else if(action==='parent')dc97Active.child=null;else if(action==='child'){if(kind==='tag'){const target=dc97Summary(dc97Active,'tag').rows.find(row=>(row.child||row.category)===arg);dc97Active.category=target?.category||'餐饮';dc97Active.kind=target?.type||'expense';dc97Active.child=target?.child||null;state.dCategory=dc97Active.category;state.dCategoryType=dc97Active.kind;state.dSub=dc97Active.child||'';dc97SceneKey='direct-category';dc97DirectSignature=JSON.stringify(['category',state.dCategory,state.dSub,state.dCategoryType,state.dTag,state.tdScenario,state.tdScope,state.ledger]);dGo('categoryDetail');return;}else dc97Active.child=arg;}else if(action==='edit'){const row=dc97Summary(dc97Active,kind).rows.find(r=>String(r.id)===arg);state.recordType=row.type;state.note=row.note;state.amount=String(row.amount);state.expression=state.amount;state.category=row.child||row.category;state.tag=row.tag||'';state.fRecordCurrency=row.currency||dc97Active.books.find(b=>b.id===row.book)?.currency;navigate('editor');return;}else if(action==='record'){state.recordType='expense';state.category=dc97Active.child||dc97Active.category||'餐饮';state.tag=kind==='tag'?(dc97Active.tag||'旅行'):'';state.amount='0';state.expression='0';navigate('editor');return;}else if(action==='menu'){if(kind==='tag')sheet('标签操作',menuRow('leaf:编辑标签','pencil-line','编辑标签')+menuRow('leaf:删除标签','trash-2','删除标签'));else sheet('分类操作',menuRow('leaf:编辑分类','pencil-line','编辑分类')+menuRow('leaf:迁移分类','arrow-left-right','迁移分类'));}render();},true);
 root.addEventListener('change',event=>{if(!event.target.matches('[data-dc97-date]'))return;dc97Active.anchor=dc97Active.period==='year'?event.target.value+'-01':event.target.value;state.year=Number(dc97Active.anchor.slice(0,4));state.month=Number(dc97Active.anchor.slice(5,7));render();},true);
 window.beeDetailCurrencyPreview={get data(){return dc97Copy(dc97Active);},get summary(){return dc97Summary(dc97Active,phone.querySelector('.dc97-detail')?.dataset.dc97Kind||'category');},setTarget(id){dc97Active.target=id;render();},setRate(target,quote,rate){dc97Active.rates[target]||={};dc97Active.rates[target][quote]={rate,manual:true};render();},restore(){dCategoryDetail=categoryOriginal;dTagDetail=tagOriginal;Object.assign(views,{categoryDetail:categoryOriginal,tagDetail:tagOriginal});}};
}
