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
 if(expand){const on=expand.getAttribute('aria-expanded')!=='true';expand.setAttribute('aria-expanded',String(on));manager.querySelector('.g-management-children').hidden=!on;return;}
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
