  // Resolve direct page links after all flow views and modal hosts are registered.
  function qApplyPreviewLink(){
    const sceneId=qParams.get('scene'),scene=window.beeDesignScenes?.[sceneId],route=qParams.get('page');
    if(scene){Object.assign(state,structuredClone(scene.state));Object.assign(settings,scene.settings);Object.assign(qPreview,scene.viewport);pSelected.clear();for(const id of scene.selected||[])pSelected.add(id);}
    else if(route&&Object.hasOwn(views,route)){state.page=route;state.rModal=null;state.rTrail=[];state.history=[];}
    const originalSkin=qParams.get('originalSkin');if(['anniversary','anniv_cake'].includes(originalSkin)){settings.skin=originalSkin;settings.accent=skinOptions.find(s=>s.id===originalSkin)?.bound||settings.accent;}
    const appearance=qParams.get('appearance');if(['light','dark'].includes(appearance))settings.appearance=appearance;
    const scale=Number(qParams.get('scale'));if([1,1.4].includes(scale))qPreview.scale=scale;
    if(qParams.get('note')==='expanded')state.zNoteExpanded=true;
    const expanded=qParams.get('expanded');if(expanded)state.expandedCategory=expanded;
    const status=qParams.get('quote');if(['loading','error','ready'].includes(status))state.vQuoteStatus=status;
    return scene;
  }
  function qReplayPreviewScene(scene){
    if(!scene&&(qParams.has('expanded')||qParams.has('quote')||qParams.has('rate'))){if(qParams.has('expanded'))state.expandedCategory=qParams.get('expanded');if(qParams.has('quote'))state.vQuoteStatus=qParams.get('quote');const rate=Number(qParams.get('rate'));if(qParams.has('rate')&&Number.isFinite(rate)&&rate>0&&rate<=1e9){state.fRecordRate=String(rate);state.vQuoteStatus='ready';}render();}
    if(scene?.contextMenu)xContext(scene.contextMenu);
    if(scene?.toast)notice(scene.toast.text,scene.toast.tone);
    if(state.rModal==='category-tools'&&!state.leaf){state.leaf='分类管理';render();}
    const sceneId=qParams.get('scene');if(!sceneId&&!qParams.get('page'))return;
    const bar=document.createElement('p');bar.className='bc-preview-scene';bar.style.cssText='display:flex;align-items:center;justify-content:center;gap:12px;font-size:12px;color:#656b72;margin:12px 0';
    const label=document.createElement('span');label.textContent='当前场景：'+(picker.selectedOptions[0]?.textContent||names[state.page]||state.page);
    const reset=document.createElement('button');reset.type='button';reset.textContent='重置此场景';reset.style.cssText='font:inherit;cursor:pointer;padding:6px 10px;border:1px solid #dedfe1;border-radius:8px;background:#fff;color:#656b72';reset.onclick=()=>location.reload();bar.append(label,reset);root.querySelector('.bc-preview-controls').after(bar);
  }
