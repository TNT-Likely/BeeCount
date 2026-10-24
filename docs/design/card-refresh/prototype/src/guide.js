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
