  // Match the existing four-digit PIN contract; this prototype never stores an App credential.
  Object.assign(state,{sPinMode:'',sPinStep:1,sPinError:false,sPinDemo:'1234'});
  function sSecurityMode(){return fCurrent()==='pin-verify'?'verify':fCurrent()==='pin-change'?'change':fCurrent().startsWith('lock')?'lock':'create';}
  function sSecurityReset(mode){state.sPinMode=mode;state.sPinStep=mode==='change'?0:1;state.fPin='';state.fNewPin='';state.sPinError=false;}
  fPinPage=function(locked){
    const mode=sSecurityMode();if(state.sPinMode!==mode)sSecurityReset(mode);
    const compact=qPreview.height-100<620,title=mode==='verify'?'请输入当前密码':locked?'请输入密码':state.sPinStep===0?'请输入当前密码':state.sPinStep===1?'请设置新密码':'请再次输入密码',biometric=locked&&fCurrent()==='lock-bio';
    return `<div class="s-security" data-compact="${compact}" data-invalid="${state.sPinError}" style="min-height:${Math.max(0,qPreview.height-100)}px"><div class="w-symbol">${icon('lock')}</div><h2>${title}</h2><p>PIN码与生物识别保护隐私</p><div class="f-pin-dots" aria-label="${state.fPin.length} / 4">${Array.from({length:4},(_,i)=>`<span class="${i<state.fPin.length?'filled':''}"></span>`).join('')}</div><div class="f-pin-grid">${['1','2','3','4','5','6','7','8','9','bio','0','backspace'].map(k=>k==='bio'&&!biometric?'<span></span>':btn('s-pin:'+k,k==='backspace'?icon('delete'):k==='bio'?icon('fingerprint'):k,k==='backspace'?'删除':k==='bio'?'生物识别解锁':'输入'+k,'',state.sPinError?'disabled':'')).join('')}</div></div>`;
  };
  fDefs.pin.title='设置密码';
  let sPreviewGroup=[...picker.querySelectorAll('optgroup')].find(g=>g.label==='补齐 · 首次使用与安全');if(!sPreviewGroup){sPreviewGroup=document.createElement('optgroup');sPreviewGroup.label='补齐 · 首次使用与安全';picker.appendChild(sPreviewGroup);}
  fDefine('pin-change','修改密码','首次使用与安全','auth/pin_setup_page.dart',()=>fPinPage(false));sPreviewGroup.appendChild(new Option('修改密码 · 验证旧 PIN','flow-pin-change'));
  fDefine('lock-bio','应用锁 · 生物识别可用','首次使用与安全','auth/app_lock_screen.dart',()=>fPinPage(true));sPreviewGroup.appendChild(new Option('应用锁 · 生物识别可用','flow-lock-bio'));
  const sPreviousRender=fRender;
  fRender=function(key){if(key==='lock'||key==='lock-bio')return `<div class="bc-subhead"><h2>应用锁</h2></div>${fPinPage(true)}`;return sPreviousRender(key);};
  let sPinTimer;
  root.addEventListener('click',e=>{
    const el=e.target.closest('[data-action^="s-pin:"]');if(!el)return;
    e.preventDefault();e.stopImmediatePropagation();if(state.sPinError)return;
    const value=el.dataset.action.slice(6),mode=sSecurityMode();
    if(value==='backspace')state.fPin=state.fPin.slice(0,-1);
    else if(value==='bio'){if(fCurrent()==='lock-bio'){state.fPin='';navigate('home');}return;}
    else if(state.fPin.length<4)state.fPin+=value;
    if(state.fPin.length===4){
      if(mode==='lock'||mode==='verify'||state.sPinStep===0){if(state.fPin===state.sPinDemo){state.fPin='';if(mode==='verify'){state.slEnabled=false;state.slBio=false;slReturnFromPin();return;}if(mode==='lock'){navigate('home');return;}state.sPinStep=1;}else state.sPinError=true;}
      else if(state.sPinStep===1){state.fNewPin=state.fPin;state.fPin='';state.sPinStep=2;}
      else if(state.fNewPin===state.fPin){state.sPinDemo=state.fPin;state.slEnabled=true;state.fPin='';state.sPinMode='';fResult('密码设置成功','应用锁现在可以使用新的密码。','lock-settings');return;}
      else state.sPinError=true;
    }
    render();
    if(state.sPinError){clearTimeout(sPinTimer);sPinTimer=setTimeout(()=>{state.fPin='';state.sPinError=false;if(state.sPinStep===2){state.sPinStep=1;state.fNewPin='';}render();},500);}
  },true);
