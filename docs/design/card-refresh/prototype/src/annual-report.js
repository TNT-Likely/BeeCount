  // App parity: seven report chapters; native capture/export stays in App.
  const ar89Text = __ANNUAL_REPORT_TEXTS__;
  const ar89Months = Array.from({length:12},(_,i)=>({month:i+1,income:i<10?12000:0,expense:[2480,2890,3168,2795,3340,3015,3420,3895.25,4125,3286.5,0,0][i]}));
  Object.assign(state,{ar89Year:2026,ar89Chapter:0,ar89HideIncome:false});
  const ar89Routes=new Set(['annual-report','annual-report-loading','annual-report-empty','annual-report-error','annual-report-long']);
  function ar89Label(key,values={}){return Object.entries(values).reduce((s,[k,v])=>s.replaceAll('{'+k+'}',String(v)),(ar89Text[key]||key).replace(/\{count, plural, other\{(.*)\}\}/,'$1'));}
  function ar89Money(v){return 'NT$'+Number(v).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});}
  // Same calendar-day cutoff as elapsedReportDays / elapsedReportYearMonths.
  // Includes today; completed periods keep their full denominator.
  function ar89ElapsedPeriod(year,{now=new Date(),monthStartDay=1}={}){
    const day=Math.max(1,Math.min(28,monthStartDay)),start=Date.UTC(year,0,day),end=Date.UTC(year+1,0,day),today=Date.UTC(now.getFullYear(),now.getMonth(),now.getDate());
    const cutoff=today<start?start:today<end?Date.UTC(now.getFullYear(),now.getMonth(),now.getDate()+1):end;
    const label=new Date(Date.UTC(now.getFullYear(),now.getMonth()-(now.getDate()<day?1:0),1));
    return {days:(cutoff-start)/86400000,months:today<start?0:today>=end?12:label.getUTCMonth()+1};
  }
  function ar89Metric(label,value,description=''){return `<article class="ar89-card ar89-metric"><span>${esc(label)}</span><strong class="bc-num">${esc(value)}</strong>${description?`<p>${esc(description)}</p>`:''}</article>`;}
  function ar89Report(mode='data'){
    const t=ar89Text;
    if(mode==='loading')return `<div class="ar89-state" role="status">${icon('loader-circle')}<p>${esc(t.annualReportGenerating)}</p></div>`;
    if(mode==='error')return `<div class="ar89-state" role="alert">${icon('circle-alert')}<p>${esc(t.commonError)}</p>${btn('ar89-retry',esc(t.helpCenterRetry),t.helpCenterRetry,'bc-primary')}</div>`;
    if(mode==='empty')return `<div class="ar89-state">${icon('inbox')}<p>${esc(ar89Label('annualReportNoData',{year:state.ar89Year}))}</p></div>`;
    const factor=state.ar89Year===2026?1:.92,months=ar89Months.map(m=>({...m,income:m.income*factor,expense:m.expense*factor}));
    const expense=months.reduce((s,m)=>s+m.expense,0),income=months.reduce((s,m)=>s+m.income,0),balance=income-expense,chapter=state.ar89Chapter,elapsed=ar89ElapsedPeriod(state.ar89Year,{monthStartDay:state.ar89MonthStartDay||1});
    const headings=[t.annualReportPage1Title,t.annualReportInsightsTitle,t.annualReportComparisonTitle,t.annualReportPage2Title,t.annualReportPage3Title,t.annualReportPage4Title,t.annualReportPage5Title];
    const subtitles=[ar89Label('annualReportPage1Subtitle',{year:state.ar89Year}),t.annualReportInsightsSubtitle,t.annualReportComparisonSubtitle,t.annualReportPage2Subtitle,t.annualReportPage3Subtitle,t.annualReportPage4Subtitle,t.annualReportPage5Subtitle];
    let body='';
    if(chapter===0)body=`<article class="ar89-card ar89-hero"><div class="ar89-year"><strong>${state.ar89Year}</strong><img src="${brandImages.bee}" alt=""></div><h3>${esc(headings[0])}</h3><p>QA ${mode==='long'?'一个需要完整保留名称的家庭共享账本及个人生活记录':'日常生活账本'} · TWD</p><span>${esc(t.annualReportTotalExpense)}</span><b class="bc-num">${ar89Money(expense)}</b><div class="ar89-grid"><div><span>${esc(t.annualReportTotalIncome)}</span><strong>${ar89Money(income)}</strong></div><div><span>${esc(t.annualReportNetSavings)}</span><strong>+${ar89Money(balance)}</strong></div></div><div class="ar89-d104-stats"><span>${esc(t.annualReportTotalDays)} <b>268${t.sharePosterUnitDay}</b></span><span>${esc(t.annualReportTotalRecords)} <b>391${t.sharePosterUnitCount}</b></span></div></article>`;
    if(chapter===1)body=[['annualReportAveragePerRecord',ar89Money(expense/391),'annualReportAveragePerRecordDesc'],['annualReportDailyAverage',ar89Money(elapsed.days?expense/elapsed.days:0),'annualReportDailyAverageDesc'],['annualReportMonthlyAverage',ar89Money(elapsed.months?expense/elapsed.months:0),'annualReportMonthlyAverageDesc'],['annualReportBusiestMonth','9月','annualReportBusiestMonthDesc'],['annualReportCategoryCount',ar89Label('annualReportCategoryCountValue',{count:5}),'annualReportCategoryCountDesc'],['annualReportSavingsRate',(balance/income*100).toFixed(1)+'%','annualReportSavingsRatePositive']].map(([label,value,desc])=>ar89Metric(t[label],value,t[desc])).join('');
    if(chapter===2)body=months.map(m=>`<article class="ar89-card"><div class="ar89-between"><b>${m.month}月</b><small>${m.month===1?esc(t.annualReportHighestIncome):''} ${m.month===9?esc(t.annualReportHighestExpense):''}</small></div>${[['income',t.analyticsIncome,m.income],['expense',t.analyticsExpense,m.expense]].map(([kind,label,value])=>`<div class="ar89-between ar89-comparison"><span>${esc(label)}</span><span>${ar89Money(value)}</span></div><div class="ar89-track ${kind}"><i style="width:${value/12000*100}%"></i></div>`).join('')}</article>`).join('');
    if(chapter===3)body=[['QA 餐饮',.346],['QA 购物',.258],['QA 居家',.221],['QA 交通',.125],['QA 其他',.05]].map(([name,f],i)=>`<article class="ar89-card"><div class="ar89-between"><strong>${i+1}. ${esc(name)}</strong><strong>${ar89Money(expense*f)}</strong></div><p class="ar89-percentage">${(f*100).toFixed(1)}%</p><div class="ar89-track"><i style="width:${f*100}%"></i></div></article>`).join('');
    if(chapter===4)body=`<div class="ar89-grid">${ar89Metric(t.annualReportHighestMonth,'9月',ar89Money(4125))}${ar89Metric(t.annualReportLowestMonth,'1月',ar89Money(2480))}</div><article class="ar89-card"><div class="ar89-chart" role="img" aria-label="${esc(t.annualReportPage3Title)}">${months.map(m=>`<div title="${m.month}月 ${ar89Money(m.expense)}"><i style="height:${m.expense/4125*140}px"></i><span>${m.month}</span></div>`).join('')}</div></article>`;
    if(chapter===5)body=[['annualReportLargestExpense','$100.00','10/20','QA 原币种 USD 的购物'],['annualReportLargestIncome','NT$12,000.00','1/1','QA 工资'],['annualReportFirstRecord','NT$28.00','1/1','QA 新年的第一笔']].map(([label,value,date,note])=>`<article class="ar89-card"><div class="ar89-between"><span>${esc(t[label])}</span><small>${date}</small></div><strong class="ar89-moment">${value}</strong><p>${esc(mode==='long'?note.repeat(8):note)}</p></article>`).join('');
    if(chapter===6)body=[['annualReportAchievementConsistent',ar89Label('annualReportAchievementConsistentDesc',{days:28})],['annualReportAchievementSaver',t.annualReportAchievementSaverDesc],['annualReportAchievementDetail',ar89Label('annualReportAchievementDetailDesc',{count:391})]].map(([label,desc])=>`<article class="ar89-card ar89-achievement">${icon('circle-check')}<div><b>${esc(t[label])}</b><p>${esc(desc)}</p></div></article>`).join('');
    return `<div class="ar89-report" data-ar89-elapsed-days="${elapsed.days}" data-ar89-elapsed-months="${elapsed.months}"><label class="ar89-year-select">${esc(t.annualReportTitle)} <select data-ar89-year aria-label="${esc(t.annualReportTitle)}">${[2026,2025,2024,2023,2022].map(y=>`<option ${state.ar89Year===y?'selected':''}>${y}</option>`).join('')}</select></label>${chapter?`<h2>${esc(headings[chapter])}</h2><p class="ar89-subtitle">${esc(subtitles[chapter])}</p>`:''}<div class="ar89-stack">${body}</div><nav class="ar89-chapters" aria-label="${esc(t.annualReportTitle)}">${headings.map((title,i)=>`<button data-ar89-chapter="${i}" aria-label="${esc(title)}" aria-current="${i===chapter?'step':'false'}">${i+1}</button>`).join('')}</nav>${btn('ar89-poster',`${icon('image')}${esc(t.annualReportShareButton)}`,t.annualReportShareButton,'bc-primary')}</div>`;
  }
  fDefine('annual-report',ar89Text.annualReportTitle,'年度账单与小票','report/annual_report_page.dart',()=>ar89Report());
  for(const [mode,title]of [['loading','生成中'],['empty','无数据'],['error','错误与重试'],['long','长名称']])fDefine('annual-report-'+mode,ar89Text.annualReportTitle+' · '+title,'年度账单与小票','report/annual_report_page.dart',()=>ar89Report(mode));
  const ar89PreviousRender=fRender;
  fRender=function(key){if(ar89Routes.has(key))return subhead(ar89Text.annualReportTitle)+ar89Report(key==='annual-report'?'data':key.slice('annual-report-'.length));return ar89PreviousRender(key);};
  document.addEventListener('change',event=>{if(event.target.matches('[data-ar89-year]')){state.ar89Year=Number(event.target.value);render();}},true);
  document.addEventListener('click',event=>{
    const chapter=event.target.closest('[data-ar89-chapter]');if(chapter){event.preventDefault();event.stopImmediatePropagation();state.ar89Chapter=Number(chapter.dataset.ar89Chapter);render();return;}
    const action=event.target.closest('[data-action]')?.dataset.action;
    if(action==='ar89-retry'){event.preventDefault();event.stopImmediatePropagation();state.page='flow-annual-report';render();}
    if(action==='ar89-poster'){event.preventDefault();event.stopImmediatePropagation();sheet(ar89Text.annualReportTitle,d104AnnualLong());}
  },true);
