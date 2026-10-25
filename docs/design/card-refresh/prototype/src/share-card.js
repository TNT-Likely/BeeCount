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
  function sc100Art(){const d=sc100Values();return d104ShareArt(d.kind,d104ShareProjection(d));}
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
  async function sc100Png(){return d104CapturePng(phone.querySelector('.sc100-preview .d104-root'));}
  document.addEventListener('click',async event=>{
    const el=event.target.closest('[data-action]');if(!el||!el.closest('#bee-immersive-suite'))return;const action=el.dataset.action;
    if(action==='leaf:分享海报'||action==='a79-share'||action==='x-share-year'){
      event.preventDefault();event.stopImmediatePropagation();sc100Open(action==='a79-share'?(state.period==='all'?'ledger':state.period):action==='x-share-year'?'year':null);return;
    }
    if(!action.startsWith('sc100-'))return;event.preventDefault();event.stopImmediatePropagation();
    if(action==='sc100-open-app'){sc100Open('app');return;}
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
