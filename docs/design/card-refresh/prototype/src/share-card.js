  // SC100 SHARE CARD START
  const sc100Text=__SHARE_CARD_TEXTS__;
  const sc100Scenes=['share-card','share-card-app','share-card-month','share-card-year','share-card-ledger','share-card-private','share-card-loading','share-card-error','share-card-long'];
  window.sc100PeriodDivisors=sc100Divisors;
  const sc100Names={profile:sc100Text.v4ShareCardProfile,app:sc100Text.mineShareApp,month:sc100Text.sharePosterMonthTitle,year:sc100Text.sharePosterYearTitle,ledger:sc100Text.sharePosterLedgerTitle};
  function sc100Reset(key='share-card'){
    if(state.sc100Key===key)return;
    state.sc100Key=key;state.sc100Hidden=key.endsWith('-private');state.sc100Busy=false;state.sc100Error=key.endsWith('-error');state.sc100Ready=!key.endsWith('-loading');
    state.sc100Kind=key.endsWith('-app')?'app':key.endsWith('-month')||key.endsWith('-private')?'month':key.endsWith('-year')?'year':key.endsWith('-ledger')?'ledger':'profile';
    state.sc100Options=['profile','app'].includes(state.sc100Kind)?['profile','app']:[state.sc100Kind];
  }
  function sc100Divisors(year,month,sd=1,now=new Date(2026,9,25)){
    sd=Math.max(1,Math.min(28,sd));
    const today=Date.UTC(now.getFullYear(),now.getMonth(),now.getDate()),start=Date.UTC(year,month-1,sd),end=Date.UTC(year,month,sd),yearStart=Date.UTC(year,0,sd),yearEnd=Date.UTC(year+1,0,sd);
    const days=today<start?0:(Math.min(today+86400000,end)-start)/86400000;
    const labelMonth=now.getDate()<sd?(now.getMonth()||12):now.getMonth()+1;
    const months=today<yearStart?0:today>=yearEnd?12:labelMonth;
    return {days,months};
  }
  function sc100Values(){
    const kind=state.sc100Kind,year=state.year||2026,month=state.month||10,rows=pRows(),projection=totals(),expense=projection.expense,income=projection.income,ledgerCount=new Set(['日常生活','家庭账本',state.ledger,...state.additions.map(r=>r.ledger).filter(Boolean)]).size;
    return {kind,year,month,ledgerCount,divisors:sc100Divisors(year,month,state.sc100StartDay||1),expense,income,balance:income-expense,count:rows.length,days:new Set(rows.map(r=>r.day)).size,ledger:state.sc100Key.endsWith('-long')?'QA 共同生活家庭与旅行的完整账本名称':state.ledger};
  }
  function sc100Art(){
    const t=sc100Text,d=sc100Values(),hidden=state.sc100Hidden,m=n=>money(n),stat=(label,value)=>`<div><small>${esc(label)}</small><b>${esc(value)}</b></div>`;
    let content;
    if(d.kind==='profile')content=`<div class="sc100-avatar">${icon('user-round')}</div><h2>${esc(d.ledger)}</h2><div class="sc100-stats">${stat(t.sharePosterRecordDays,d.days+' '+t.sharePosterUnitDay)}${stat(t.sharePosterRecordCount,d.count+' '+t.sharePosterUnitCount)}${stat(t.userProfilePosterLedgerCount,String(d.ledgerCount))}</div><h3>${esc(t.userProfileJourneyStart)}</h3>`;
    else if(d.kind==='app')content=`<img class="sc100-bee" src="${brandImages.bee}" alt=""><h2>${esc(t.sharePosterAppName)}</h2><p>${esc(t.sharePosterSlogan)}</p><div class="sc100-features">${['sharePosterFeature1','sharePosterFeature2','sharePosterFeature3','sharePosterFeature4','sharePosterFeature5','sharePosterFeature6'].map(k=>`<p>${icon('check')}${esc(t[k])}</p>`).join('')}</div>`;
    else content=`<p>${d.kind==='year'?d.year:d.kind==='month'?d.year+'.'+String(d.month).padStart(2,'0'):esc(d.ledger)}</p><h2>${esc(sc100Names[d.kind])}</h2><section class="sc100-totals">${stat(t.sharePosterTotalExpense,'¥'+m(d.expense))}${stat(t.sharePosterTotalIncome,hidden?'**':'¥'+m(d.income))}${stat(t.sharePosterBalance,hidden?'**':'¥'+m(d.balance))}${stat(t.sharePosterRecordCount,String(d.count))}</section>${d.kind==='month'?stat(t.sharePosterAvgDailyExpense,'¥'+m(d.divisors.days?d.expense/d.divisors.days:0)):d.kind==='year'?`${stat(t.sharePosterAvgMonthlyExpense,'¥'+m(d.divisors.months?d.expense/d.divisors.months:0))}${stat(t.sharePosterAvgMonthlyIncome,hidden?'**':'¥'+m(d.divisors.months?d.income/d.divisors.months:0))}`:''}`;
    return `<article class="sc100-art" data-sc100-kind="${d.kind}"><header><img src="${brandImages.bee}" alt="">${esc(t.sharePosterAppName)}</header>${content}<footer>${esc(t.sharePosterSlogan)}<small>github.com/TNT-Likely/BeeCount</small></footer></article>`;
  }
  function sc100Body(key='share-card'){
    sc100Reset(key);const t=sc100Text,busy=state.sc100Busy||!state.sc100Ready,privacy=['month','year','ledger'].includes(state.sc100Kind);
    return `<div class="sc100-body"><nav class="sc100-templates" aria-label="${esc(t.v4ShareCardTitle)}">${state.sc100Options.length>1?state.sc100Options.map(kind=>btn('sc100-kind:'+kind,(kind===state.sc100Kind?icon('check'):'')+esc(sc100Names[kind]),sc100Names[kind],'p-chip',`aria-pressed="${kind===state.sc100Kind}" ${state.sc100Busy?'disabled':''}`)).join(''):''}</nav><div class="sc100-preview">${!state.sc100Ready?`<p role="status">${icon('loader-circle')}${esc(t.sharePosterGenerating)}</p>`:state.sc100Error?`<p role="alert">${esc(t.sharePosterGenerateFailed)}</p>${btn('sc100-retry',esc(t.helpCenterRetry),t.helpCenterRetry,'bc-secondary')}`:sc100Art()}</div>${privacy?btn('sc100-privacy',icon(state.sc100Hidden?'eye-off':'eye')+esc(state.sc100Hidden?t.sharePosterShowIncome:t.sharePosterHideIncome),state.sc100Hidden?t.sharePosterShowIncome:t.sharePosterHideIncome,'sc100-privacy',busy?'disabled':''):''}<div class="sc100-actions">${btn('sc100-save',icon('download')+esc(t.sharePosterSave),t.sharePosterSave,'bc-secondary',busy||state.sc100Error?'disabled':'')}${btn('sc100-share',icon('share-2')+esc(t.sharePosterShare),t.sharePosterShare,'bc-primary',busy||state.sc100Error?'disabled':'')}</div><p class="sc100-event" role="status">${state.sc100Busy?esc(t.sharePosterGenerating):''}</p></div>`;
  }
  xPoster=function(){return subhead(sc100Text.v4ShareCardTitle)+sc100Body('share-card');};
  for(const key of sc100Scenes)fDefine(key,sc100Text.v4ShareCardTitle,'启动与分享','report/share_card_page.dart',()=>sc100Body(key));
  function sc100Open(kind){
    state.sc100Key=null;const key=kind?'share-card-'+kind:'share-card';
    sheet(sc100Text.v4ShareCardTitle,sc100Body(key));
  }
  function sc100Refresh(){
    const modal=phone.querySelector('.sc100-body')?.closest('[role="dialog"],.bc-sheet,.r-modal-layer');
    if(modal){const old=modal.querySelector('.sc100-body');old.outerHTML=sc100Body(state.sc100Key);if(window.lucide)lucide.createIcons();}else render();
  }
  async function sc100Png(){
    const t=sc100Text,d=sc100Values(),canvas=document.createElement('canvas');canvas.width=750;canvas.height=1334;const c=canvas.getContext('2d'),g=c.createLinearGradient(0,0,750,1334);g.addColorStop(0,'#facb16');g.addColorStop(1,'#ad8b0a');c.fillStyle=g;c.fillRect(0,0,750,1334);c.fillStyle='#fff';c.font='bold 33px sans-serif';c.fillText(t.sharePosterAppName,55,90);c.font='bold 40px sans-serif';c.fillText(sc100Names[d.kind],55,190);c.font='24px sans-serif';
    const rows=d.kind==='app'?[t.sharePosterSlogan,t.sharePosterFeature1,t.sharePosterFeature2,t.sharePosterFeature3,t.sharePosterFeature4,t.sharePosterFeature5,t.sharePosterFeature6]:d.kind==='profile'?[d.ledger,t.sharePosterRecordDays+' '+d.days,t.sharePosterRecordCount+' '+d.count]:[t.sharePosterTotalExpense+' ¥'+money(d.expense),t.sharePosterTotalIncome+' '+(state.sc100Hidden?'**':'¥'+money(d.income)),t.sharePosterBalance+' '+(state.sc100Hidden?'**':'¥'+money(d.balance)),t.sharePosterRecordCount+' '+d.count];rows.forEach((line,i)=>c.fillText(line,55,290+i*95,640));c.font='22px sans-serif';c.fillText(t.sharePosterSlogan,55,1190,640);c.fillText('github.com/TNT-Likely/BeeCount',55,1250,640);
    return new Promise(resolve=>canvas.toBlob(resolve,'image/png'));
  }
  document.addEventListener('click',async event=>{
    const el=event.target.closest('[data-action]');if(!el||!el.closest('#bee-immersive-suite'))return;const action=el.dataset.action;
    if(action==='leaf:分享海报'||action==='a79-share'||action==='x-share-year'){
      event.preventDefault();event.stopImmediatePropagation();sc100Open(action==='a79-share'?(state.period==='all'?'ledger':state.period):action==='x-share-year'?'year':null);return;
    }
    if(!action.startsWith('sc100-'))return;event.preventDefault();event.stopImmediatePropagation();
    if(action==='sc100-retry'){state.sc100Error=false;state.sc100Ready=true;sc100Refresh();return;}
    if(action.startsWith('sc100-kind:')){if(state.sc100Busy)return;state.sc100Kind=action.split(':')[1];sc100Refresh();return;}
    if(action==='sc100-privacy'){if(state.sc100Busy)return;state.sc100Hidden=!state.sc100Hidden;sc100Refresh();return;}
    if(state.sc100Busy||!state.sc100Ready||state.sc100Error)return;
    state.sc100Busy=true;sc100Refresh();
    try{
      const blob=await sc100Png(),file=new File([blob],'BeeCount-share.png',{type:'image/png'});
      if(action==='sc100-share'&&navigator.canShare?.({files:[file]}))await navigator.share({files:[file],text:sc100Text.sharePosterAppText});
      else {const a=document.createElement('a'),url=URL.createObjectURL(blob);a.href=url;a.download=file.name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
    }catch(error){if(error.name!=='AbortError')state.sc100Error=true;}finally{state.sc100Busy=false;sc100Refresh();}
  },true);
  // SC100 SHARE CARD END
