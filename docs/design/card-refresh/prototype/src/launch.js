  const lLaunchBee=__LAUNCH_BEE_SVG__;
  const lSafetyFeatures=[['database','数据本地存储','数据本地存储，隐私完全自控'],['code-xml','开源代码透明','开源代码透明，安全值得信赖'],['cloud','可选云端同步','可选云端同步，多设备数据一致']];
  function lSafetyBody(){return `<div class="l-security-details">${lSafetyFeatures.map(([i,title,text])=>`<div><span>${icon(i)}</span><section><strong>${title}</strong><p>${text}</p></section></div>`).join('')}<p>无需账号也能开始记录，云端同步由你选择。</p></div>`;}
  function lLaunchBody(){return `<div class="l-launch l-trail-layout" data-dark="${skinIsDark()}" data-compact="${qPreview.height<650}" data-large="${qPreview.scale>1.2}"><svg class="l-trail" viewBox="0 0 320 220" aria-hidden="true"><path class="l-trail-guide" d="M16 172C22 62 146 28 234 62C322 96 308 146 210 170"/><path class="l-trail-ink" pathLength="1" d="M16 172C22 62 146 28 234 62C322 96 308 146 210 170"/><circle cx="210" cy="170" r="2"/></svg><div class="l-hero"><div class="l-brand" aria-hidden="true">${lLaunchBee}</div><h2>蜜蜂记账</h2><p class="l-slogan">一笔一蜜</p><div class="l-stroke" aria-hidden="true"></div><div class="l-loading"><span class="l-spinner" aria-hidden="true"></span><p class="l-startup-status" role="status">正在初始化数据...</p></div><p class="l-preparing">正在准备你的记录</p></div><footer class="l-security-footer">${btn('l-security',`${icon('shield-check')}<span>本地存储 · 开源透明</span>`,'开源数据安全','l-security-link')}<p>云同步由你选择，数据始终由你掌握</p></footer></div>`;}
  rSpecs['launch-security']={kind:'sheet',title:'开源数据安全'};
  const lPreviousModalBody=rModalBody;
  rModalBody=function(key){return key==='launch-security'?lSafetyBody():lPreviousModalBody(key);};
  root.addEventListener('click',event=>{const el=event.target.closest('[data-action="l-security"]');if(!el)return;event.preventDefault();event.stopImmediatePropagation();rOpenModal('launch-security');},true);
  fDefs.splash.body=lLaunchBody;
  const lPreviousRender=fRender;
  fRender=function(key){return key==='splash'?lLaunchBody():lPreviousRender(key);};
