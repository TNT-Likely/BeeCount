function specMix(hex,target,weight){const a=hex.slice(1).match(/../g).map(n=>parseInt(n,16)),b=target.slice(1).match(/../g).map(n=>parseInt(n,16));return '#'+a.map((n,i)=>Math.round(n*(1-weight)+b[i]*weight).toString(16).padStart(2,'0')).join('');}function specContrast(hex){const [r,g,b]=hex.slice(1).match(/../g).map(n=>parseInt(n,16)/255).map(c=>c<=.04045?c/12.92:((c+.055)/1.055)**2.4);return .2126*r+.7152*g+.0722*b>.22?'#262829':'#ffffff';}function specRender(){document.documentElement.style.colorScheme=document.getElementById('spec-mode').value;const accent=document.getElementById('spec-accent').value;for(const p of document.querySelectorAll('.spec-component')){p.style.setProperty('--bc-accent',accent);p.style.setProperty('--bc-tint','color-mix(in srgb,'+accent+' 12%,var(--bc-paper))');p.style.setProperty('--bc-strong','light-dark('+specMix(accent,'#222222',.42)+','+specMix(accent,'#ffffff',.25)+')');p.style.setProperty('--bc-on-accent',specContrast(accent));}for(const w of document.querySelectorAll('.j-wheel')){const options=[...w.children],i=options.findIndex(o=>o.getAttribute('aria-selected')==='true');w.scrollTop=Math.max(0,i)*44;}}document.getElementById('spec-mode').onchange=specRender;document.getElementById('spec-accent').onchange=specRender;lucide.createIcons({attrs:{width:18,height:18}});specRender();

const search=document.getElementById('spec-search');
function specFilter(){let count=0;const query=search.value.trim().toLowerCase();for(const card of document.querySelectorAll('.spec-card')){card.hidden=query&&!card.textContent.toLowerCase().includes(query);const link=document.querySelector('[data-spec-link="'+card.id+'"]');if(link)link.hidden=card.hidden;if(!card.hidden)count++;}for(const group of document.querySelectorAll('.spec-group'))group.hidden=![...group.querySelectorAll('.spec-card')].some(c=>!c.hidden);document.getElementById('spec-result').textContent=count+' 组组件';document.getElementById('spec-empty').hidden=count>0;}
search.addEventListener('input',specFilter);
function specGo(id){search.value='';specFilter();const target=document.getElementById(id);if(!target)return;target.scrollIntoView({behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth',block:'start'});history.replaceState(null,'','#'+id);}
document.getElementById('spec-jump').addEventListener('change',e=>{specGo(e.target.value);e.target.value='';});
for(const a of document.querySelectorAll('.spec-sidebar a,.spec-toolbar>a'))a.addEventListener('click',e=>{e.preventDefault();specGo(a.hash.slice(1));});
const observer=new IntersectionObserver(entries=>{for(const e of entries)if(e.isIntersecting){for(const a of document.querySelectorAll('.spec-sidebar a'))a.removeAttribute('aria-current');document.querySelector('[data-spec-link="'+e.target.id+'"]')?.setAttribute('aria-current','true');}},{rootMargin:'-5% 0px -70% 0px'});document.querySelectorAll('.spec-card').forEach(c=>observer.observe(c));
window.beeComponentCatalog={groups:['foundation','business'],filter:specFilter,go:specGo};

for(const input of document.querySelectorAll('[data-v4-mixed]'))input.indeterminate=true;
for(const input of document.querySelectorAll('.v4-range'))input.addEventListener('input',()=>{input.style.setProperty('--v4-value',input.value+'%');input.closest('.v4-range-field').querySelector('output').textContent=input.value+'%';});

for(const picker of document.querySelectorAll('[data-account-types]'))picker.addEventListener('click',event=>{
 const group=event.target.closest('[data-account-group]');
 if(group){for(const button of picker.querySelectorAll('[data-account-group]'))button.setAttribute('aria-pressed',String(button===group));for(const panel of picker.querySelectorAll('[data-account-panel]'))panel.hidden=panel.dataset.accountPanel!==group.dataset.accountGroup;return;}
 const type=event.target.closest('[data-account-type]');if(!type||type.disabled)return;
 for(const button of picker.querySelectorAll('[data-account-type]'))button.setAttribute('aria-pressed',String(button===type));
 picker.querySelector('[data-account-draft]').textContent='当前草稿：'+type.textContent;
});

for(const adjustment of document.querySelectorAll('[data-balance-adjustment]'))adjustment.addEventListener('click',event=>{
 const mode=event.target.closest('[data-balance-mode]');
 if(mode){for(const button of adjustment.querySelectorAll('[data-balance-mode]'))button.setAttribute('aria-pressed',String(button===mode));for(const description of adjustment.querySelectorAll('[data-balance-description]'))description.hidden=description.dataset.balanceDescription!==mode.dataset.balanceMode;adjustment.querySelector('[data-balance-confirm]').textContent=mode.dataset.confirmLabel;return;}
 if(event.target.closest('[data-balance-confirm]'))adjustment.querySelector('[data-balance-result]').textContent='已确认：'+adjustment.querySelector('[data-balance-mode][aria-pressed=true]').textContent;
});
for(const manager of document.querySelectorAll('[data-category-management]'))manager.addEventListener('click',event=>{
 const expand=event.target.closest('[data-management-expand]');
 if(expand){const on=expand.getAttribute('aria-expanded')!=='true';expand.setAttribute('aria-expanded',String(on));const children=expand.closest('.g-management-parent').nextElementSibling;if(children?.classList.contains('g-management-children'))children.hidden=!on;return;}
 const edit=event.target.closest('[data-management-edit]');
 if(edit)manager.querySelector('[data-management-result]').textContent='已选择：'+edit.dataset.managementEdit+'（示例草稿）';
 if(event.target.closest('[data-management-open]'))manager.querySelector('.g-management-dialog').scrollIntoView({block:'center'});
 if(event.target.closest('[data-management-open-tools]'))manager.querySelector('[data-management-result]').textContent='分类工具：分享分类、新建分类、导入分类 ZIP、生成默认分类、清空未使用分类。完整弹窗见交互预览。';
});
for(const overview of document.querySelectorAll('[data-asset-overview]')){
 overview.addEventListener('click',event=>{
  const privacy=event.target.closest('[data-asset-privacy]');
  if(privacy){const hide=overview.dataset.hidden!=='true';overview.dataset.hidden=String(hide);for(const amount of overview.querySelectorAll('[data-asset-money]'))amount.textContent=hide?'••••':amount.dataset.assetMoney;privacy.setAttribute('aria-label',hide?'显示资产金额':'隐藏资产金额');privacy.innerHTML='<i data-lucide="'+(hide?'eye-off':'eye')+'"></i>';lucide.createIcons({attrs:{width:18,height:18}});return;}
  const chart=event.target.closest('[data-asset-chart]');
  if(chart){for(const tab of overview.querySelectorAll('[data-asset-chart]'))tab.setAttribute('aria-pressed',String(tab===chart));for(const panel of overview.querySelectorAll('[data-asset-chart-panel]'))panel.hidden=panel.dataset.assetChartPanel!==chart.dataset.assetChart;overview.querySelector('[data-asset-chart-title]').textContent=chart.textContent;return;}
  const choice=event.target.closest('[data-asset-default]');
  if(choice)overview.querySelector('[data-asset-result]').textContent='已打开默认'+choice.dataset.assetDefault+'账户选择（示例草稿）';
  if(event.target.closest('[data-asset-detail]'))overview.querySelector('[data-asset-result]').textContent='已选择查看明细；真实 App 保留原折算与净值详情路径。';
 });
 overview.addEventListener('change',event=>{if(event.target.matches('[data-asset-enabled]'))overview.querySelector('[data-asset-defaults]').hidden=!event.target.checked;});
}

for(const palette of document.querySelectorAll('[data-color-palette]'))palette.addEventListener('click',event=>{const button=event.target.closest('button');if(!button||button.disabled)return;for(const item of palette.querySelectorAll('button')){item.setAttribute('aria-pressed',String(item===button));item.querySelector('span').innerHTML=item===button?'<i data-lucide="check"></i>':'';}palette.nextElementSibling.textContent='已选择：'+button.getAttribute('aria-label');lucide.createIcons({attrs:{width:18,height:18}});});

document.addEventListener('click',event=>{const open=event.target.closest('[data-tag-library-open]'),remove=event.target.closest('[data-tag-library-delete]');if(!open&&!remove)return;const host=(open||remove).closest('.g-tag-library'),name=open?.dataset.tagLibraryOpen||remove.dataset.tagLibraryDelete;host.querySelector('[data-tag-library-result]').textContent=open?'查看标签 '+name+'（受控样例）':'删除 '+name+' 需要确认；完整流程见交互页面';});

for(const button of document.querySelectorAll('[data-chart-privacy]'))button.addEventListener('click',()=>{const hidden=button.getAttribute('aria-pressed')!=='true';button.setAttribute('aria-pressed',String(hidden));button.textContent=hidden?'显示图中金额':'隐藏图中金额';for(const amount of button.closest('.spec-component').querySelectorAll('[data-chart-amount]'))amount.textContent=hidden?'**':amount.dataset.chartAmount;});

const fitMoneyObserver=new ResizeObserver(()=>{for(const value of document.querySelectorAll('[data-fit-money]')){value.style.fontSize='14px';if(value.scrollWidth>value.clientWidth)value.style.fontSize=(14*value.clientWidth/value.scrollWidth)+'px';}});for(const value of document.querySelectorAll('[data-fit-money]'))fitMoneyObserver.observe(value.parentElement);

for(const group of document.querySelectorAll('[data-rd-gtime]')){function refresh(){const v={};for(const wheel of group.querySelectorAll('[data-rd-gwheel]')){const options=[...wheel.children],index=Math.max(0,Math.min(options.length-1,Math.round(wheel.scrollTop/44)));options.forEach((option,i)=>option.setAttribute('aria-selected',String(i===index)));v[wheel.dataset.rdGwheel]=Number(options[index].dataset.value);}group.querySelector('[data-rd-gresult]').textContent=String(v.hour).padStart(2,'0')+':'+String(v.minute).padStart(2,'0');}for(const wheel of group.querySelectorAll('[data-rd-gwheel]')){wheel.addEventListener('scroll',refresh);wheel.addEventListener('click',event=>{const option=event.target.closest('[data-value]');if(option)wheel.scrollTop=Number(option.dataset.value)*44;});}}
for(const toggle of document.querySelectorAll('[data-rd-gswitch]'))toggle.addEventListener('change',()=>{toggle.closest('.v4-stack').querySelector('[data-rd-gstate]').textContent=toggle.checked?'示例开启；实际调度留给App。':'示例关闭；HTML不调度系统通知。';});

for(const demo of document.querySelectorAll('[data-nh-demo]')){let valid=20;demo.querySelector('[data-nh-limit]').addEventListener('input',e=>{const text=e.target.value.replace(/\D/g,'');e.target.value=text;const n=Number(text),bad=!text||n<1||n>100;demo.querySelector('[data-nh-error]').hidden=!bad;if(!bad)valid=n;demo.querySelector('[data-nh-result]').textContent='示例有效数量'+valid;});}

for(const demo of document.querySelectorAll('[data-hsv-demo]')){function refresh(){const q=Object.fromEntries([...demo.querySelectorAll('[data-hsv-channel]')].map(e=>[e.dataset.hsvChannel,Number(e.value)])),c=q.v*q.s,x=c*(1-Math.abs((q.h/60)%2-1)),m=q.v-c,raw=q.h<60?[c,x,0]:q.h<120?[x,c,0]:q.h<180?[0,c,x]:q.h<240?[0,x,c]:q.h<300?[x,0,c]:[c,0,x],hex='#'+raw.map(n=>Math.round((n+m)*255).toString(16).padStart(2,'0')).join('').toUpperCase(),preview=demo.querySelector('[data-hsv-preview]');preview.style.background=hex;preview.textContent=hex;for(const key of ['h','s','v'])demo.querySelector('[data-hsv-label="'+key+'"]').textContent=({h:'色相 ',s:'饱和度 ',v:'亮度 '})[key]+Math.round(q[key]*(key==='h'?1:100))+(key==='h'?'°':'%');}for(const input of demo.querySelectorAll('[data-hsv-channel]'))input.addEventListener('input',refresh);for(const choice of demo.querySelectorAll('[data-hsv-color]'))choice.addEventListener('click',()=>{for(const item of demo.querySelectorAll('[data-hsv-color]'))item.setAttribute('aria-pressed',String(item===choice));});refresh();}

document.addEventListener("click",event=>{const card=event.target.closest("[data-skin-card]");if(!card||card.disabled)return;card.closest(".ss-grid").querySelectorAll("[data-skin-card]").forEach(c=>{c.setAttribute("aria-pressed",String(c===card));const old=c.querySelector(".ss-selected");if(old)old.remove();});const check=document.createElement("span");check.className="ss-selected";check.textContent="✓";card.querySelector(".ss-art").appendChild(check);});

document.addEventListener("click",event=>{const choice=event.target.closest("[data-archive-demo] [role=radio]");if(!choice)return;choice.parentElement.querySelectorAll("[role=radio]").forEach(c=>{c.setAttribute("aria-checked",String(c===choice));c.querySelector(".dm-radio").textContent=c===choice?"●":"○";});});

document.addEventListener('input',event=>{if(!event.target.matches('[data-decimal-demo]')||event.isComposing)return;event.target.value=event.target.value.replaceAll('。','.').replaceAll('．','.').replace(/[^0-9.]/g,'');});

document.addEventListener('click',event=>{const button=event.target.closest('[data-a79-sample]');if(!button)return;const demo=button.closest('[data-analytics-demo]'),value=button.dataset.a79Sample;for(const b of demo.querySelectorAll('[data-a79-sample]'))b.setAttribute('aria-pressed',String(b===button));const label={expense:'支出',income:'收入',balance:'结余'}[value];demo.querySelector('[data-a79-view]').textContent=label+' ⌄';demo.querySelector('[data-a79-label]').textContent='总'+label+'：';demo.querySelector('[data-a79-total]').textContent={expense:'¥3,286.50',income:'¥12,000.00',balance:'¥8,713.50'}[value];});

document.addEventListener('click',event=>{const button=event.target.closest('[data-s80-demo-mode]');if(!button)return;const root=button.closest('[data-s80-demo]');for(const item of root.querySelectorAll('[data-s80-demo-mode]'))item.setAttribute('aria-pressed',String(item===button));root.querySelector('[data-s80-demo-slider]').hidden=button.dataset.s80DemoMode!=='auto';});
document.addEventListener('input',event=>{if(event.target.matches('[data-s80-demo-range]'))event.target.closest('label').querySelector('output').textContent=(Number(event.target.value)/1000).toFixed(1)+' 秒';});
document.addEventListener('change',event=>{if(event.target.matches('[data-s80-demo-range]'))event.target.closest('[data-s80-demo]').querySelector('[data-s80-demo-event]').textContent='示例松手提交 '+event.target.value+' ms';});

for(const demo of document.querySelectorAll('[data-a81-demo]'))demo.addEventListener('click',event=>{
 if(event.target.closest('[data-a81-choose-open]'))demo.querySelector('[data-a81-provider-dialog]').showModal();
 if(event.target.closest('[data-a81-consent-open]'))demo.querySelector('[data-a81-consent-dialog]').showModal();
 const choice=event.target.closest('[data-a81-provider]');if(choice){demo.querySelector('[data-a81-provider-label]').textContent=choice.dataset.a81Provider;demo.querySelector('[data-a81-result]').textContent='示例选择 '+choice.dataset.a81Provider;choice.closest('dialog').close();}
 if(event.target.closest('[data-a81-cancel]'))event.target.closest('dialog').close();
 if(event.target.closest('[data-a81-demo-agree]')){demo.querySelector('[data-a81-result]').textContent='示例同意，不写真实授权';event.target.closest('dialog').close();}
});

for(const demo of document.querySelectorAll('[data-a82-demo]')){
 const render=()=>{const stage=demo.querySelector('[data-a82-demo-stage]').value;demo.querySelector('.a82-test').dataset.testTone=stage;const test=demo.querySelector('[data-a82-demo-test]'),detail=demo.querySelector('[data-a82-demo-detail]');test.disabled=stage==='testing';test.textContent={idle:'测试',testing:'测试中',success:'测试成功',failed:'测试失败'}[stage];detail.hidden=!['success','failed'].includes(stage);detail.textContent=stage==='success'?'文本与工具调用可用':stage==='failed'?'合成连接失败，请检查配置':'';demo.querySelector('[data-a82-demo-event]').textContent='示例状态：'+stage+'，不发起请求';};
 demo.querySelector('[data-a82-demo-stage]').addEventListener('change',render);
 demo.querySelector('[data-a82-demo-test]').addEventListener('click',()=>{demo.querySelector('[data-a82-demo-stage]').value='testing';render();});
}
for(const button of document.querySelectorAll('[data-a82-demo-delete]'))button.addEventListener('click',()=>{button.closest('.a82-guide-sample').querySelector('[data-a82-demo-event]').textContent='示例删除入口，实际管理页保留确认弹窗';});
document.addEventListener('input',e=>{if(!e.target.matches('[data-a83-demo-input]'))return;const host=e.target.closest('.a83-guide-sample'),dirty=e.target.value!==(host.dataset.saved||'QA合成模板 {{OCR_TEXT}}');host.querySelector('[data-a83-demo-dirty]').hidden=!dirty;host.querySelector('[data-a83-demo-save]').disabled=!dirty;});
document.addEventListener('click',e=>{const save=e.target.closest('[data-a83-demo-save]'),reset=e.target.closest('[data-a83-demo-reset]');if(!save&&!reset)return;const host=e.target.closest('.a83-guide-sample'),input=host.querySelector('[data-a83-demo-input]');if(save){host.dataset.saved=input.value;host.querySelector('[data-a83-demo-event]').textContent='示例已保存，不写真实配置';}else{input.value='QA合成模板 {{OCR_TEXT}}';host.querySelector('[data-a83-demo-event]').textContent='示例恢复，只改草稿';}input.dispatchEvent(new Event('input',{bubbles:true}));});
document.addEventListener('click',e=>{const el=e.target.closest('[data-a84-demo-value]');if(!el)return;const host=el.closest('.a84-guide-sample');for(const button of host.querySelectorAll('[data-a84-demo-value]')){button.setAttribute('aria-checked',String(button===el));button.querySelector('.a84-radio').classList.toggle('selected',button===el);}host.querySelector('[data-a84-demo-event]').textContent='示例选择 '+el.dataset.a84DemoValue+' 轮，不写真实执行配置';});

document.addEventListener('click',e=>{const sample=e.target.closest('.a85-guide-sample');if(!sample)return;if(e.target.closest('[data-a85-demo-send]')){sample.querySelector('[data-a85-demo-event]').textContent='示例发送：'+sample.querySelector('[data-a85-demo-input]').value+' · 不调用模型';}if(e.target.closest('[data-a85-demo-undo]')){sample.querySelector('[data-a85-demo-event]').textContent='示例撤销，不改真实交易';sample.querySelector('.a85-bill-title b').textContent='已撤销';e.target.disabled=true;}});

// Recurring examples only change local controls; production data stays in App.
document.addEventListener('click',event=>{
  const toggle=event.target.closest('[data-r86-demo-toggle]');
  if(toggle){const checked=toggle.getAttribute('aria-checked')!=='true';toggle.setAttribute('aria-checked',String(checked));toggle.closest('.r86-guide').querySelector('[data-r86-demo-event]').textContent='示例已'+(checked?'启用':'停用')+'，不修改真实周期配置';}
  const open=event.target.closest('[data-r86-demo-open]');
  if(open)open.closest('.r86-guide').querySelector('[data-r86-demo-event]').textContent='示例编辑入口 · 实际页面由App导航';
});
document.addEventListener('click',event=>{const multi=event.target.closest('[data-local-multi]');if(multi&&!multi.disabled){const selected=multi.getAttribute('aria-pressed')!=='true';multi.setAttribute('aria-pressed',String(selected));multi.dataset.selected=String(selected);const host=multi.closest('[data-foundation-multi-select]');host.querySelector('[data-local-multi-result]').textContent='多选示例：'+host.querySelectorAll('[data-local-multi][aria-pressed="true"]').length+' 项';}const inline=event.target.closest('[data-local-inline]');if(inline)inline.closest('[data-foundation-inline-label]').querySelector('[data-local-inline-result]').textContent='点击紧凑标签，只更新示例';});
