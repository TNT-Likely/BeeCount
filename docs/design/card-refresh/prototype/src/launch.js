  const lLaunchBee=__LAUNCH_BEE_SVG__;
  function lLaunchBody(){return `<div class="l-launch" aria-busy="true"><div class="l-brand" data-dark="${skinIsDark()}" aria-hidden="true">${lLaunchBee}</div><h2>蜜蜂记账</h2><p class="l-slogan">一笔一蜜</p>${surface(`<div class="l-security-title"><span>${icon('shield-check')}</span>开源数据安全</div><p>• 数据本地存储，隐私完全自控<br>• 开源代码透明，安全值得信赖<br>• 可选云端同步，多设备数据一致</p>`,'l-security')}<div class="l-spinner" role="progressbar" aria-label="正在初始化数据"></div><p class="l-status" role="status">正在初始化数据...</p></div>`;}
  fDefs.splash.body=lLaunchBody;
  const lPreviousRender=fRender;
  fRender=function(key){return key==='splash'?lLaunchBody():lPreviousRender(key);};
