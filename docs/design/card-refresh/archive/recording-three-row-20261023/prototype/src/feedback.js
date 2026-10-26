  let feedbackTimer;
  function feedbackToast(text,tone='neutral',sample=false){return `<div class="bc-notice${sample?' bc-notice-sample':''}" data-feedback-tone="${tone}" role="status">${icon(tone==='success'?'circle-check':tone==='error'?'circle-alert':'info')}<span>${esc(text)}</span></div>`;}
  function feedbackStatus(){return `<div class="bc-feedback-status" data-feedback-tone="success">${icon('circle-check')}<div class="bc-feedback-copy">已保存</div></div><div class="bc-feedback-status" data-feedback-tone="warning">${icon('info')}<div class="bc-feedback-copy">本地有更新<small>可以同步到云端</small></div></div><div class="bc-feedback-status" data-feedback-tone="error">${icon('circle-alert')}<div class="bc-feedback-copy">同步失败<small>网络暂时不可用，本地数据已保留</small></div>${btn('feedback-retry','重试','重试同步','bc-secondary')}</div>`;}
  function notice(text,tone='neutral'){
    clearTimeout(feedbackTimer);phone.querySelector('.bc-notice:not(.bc-notice-sample)')?.remove();
    phone.insertAdjacentHTML('beforeend',feedbackToast(text,tone));globalThis.lucide?.createIcons({attrs:{width:20,height:20}});
    const n=phone.querySelector('.bc-notice:not(.bc-notice-sample)');feedbackTimer=setTimeout(()=>n?.remove(),2000);
  }
  fDefine('feedback','成功、失败与持续状态','组件规范','packages/beecount_ui/lib/src/controls.dart',()=>`${surface(`<h3 style="font-size:14px;margin-bottom:16px">轻提示 · 自动消失</h3>${feedbackToast('保存成功','success',true)}${feedbackToast('网络不可用，请重试','error',true)}<div class="bc-inline-actions">${btn('feedback-success','成功提示','显示成功提示','bc-primary')}${btn('feedback-error','失败提示','显示失败提示','bc-secondary')}</div>`)}${surface(`<h3 style="font-size:14px">页面内状态 · 保留处理入口</h3>${feedbackStatus()}`)}<p class="f-caption">轻提示不阻断操作，2 秒后消失，同一时刻只显示一条。需要重试的错误在页面内保留原因与操作。</p>`);
  root.addEventListener('click',e=>{const a=e.target.closest('[data-action]')?.dataset.action;if(!a?.startsWith('feedback-'))return;e.preventDefault();e.stopImmediatePropagation();notice(a==='feedback-success'?'保存成功':a==='feedback-error'?'网络不可用，请重试':'已发起重试',a==='feedback-error'?'error':'success');},true);
  if(new URLSearchParams(location.search).get('page')==='flow-feedback')state.page='flow-feedback';
  window.beeFeedbackSpec={show:notice,samples:()=>({feedbackToast:feedbackToast('保存成功','success',true)+feedbackToast('网络不可用，请重试','error',true),feedbackStatus:feedbackStatus()})};
