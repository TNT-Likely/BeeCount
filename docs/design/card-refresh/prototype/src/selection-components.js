  // Shared account art: preserve source SVG colors for every named account.
  function bcAccountType(value){
    if(typeof value==='string'){
      if(aEditorIcons[value])return value;
      value=accounts.find(a=>a.id===value||a.name===value);
    }
    if(!value)return 'other';
    if(value.type)return aEditorIcons[value.type]?value.type:'other';
    return ({bank:'bank_card',wechat:'wechat',alipay:'alipay',credit:'credit_card',usd:'cash',jpy:'cash'}[value.id])||'other';
  }
  function bcAccountVisual(value,size=24){const type=bcAccountType(value);return `<img class="bc-account-art" data-account-type="${type}" src="${aEditorIcons[type]||aEditorIcons.other}" width="${size}" height="${size}" alt="" style="--account-art-size:${size}px">`;}
  function bcAccountMenu(action,account,detail='',trailing=''){return menuRow(action,'wallet',account.name,detail,trailing).replace(icon('wallet'),bcAccountVisual(account));}
  function bcTagPill(name,{choice=false,selected=false,disabled=false}={}){
    const family=tagColors[name]||'green',tone=family==='amber'?'var(--bc-strong)':`var(--bc-tag-${family},var(--bc-tag-green))`;
    return `<span class="bc-tag-pill" data-choice="${choice}" data-selected="${selected}" style="--tag-ink:${tone}">${disabled?icon('lock'):choice&&selected?icon('check'):''}<span>${esc(name)}</span></span>`;
  }
  function bcTagChoice(name,selected,disabled=false){return btn('j-tag-toggle:'+name,bcTagPill(name,{choice:true,selected,disabled}),name,'j-tag-chip bc-tag-hit',`role="checkbox" aria-checked="${selected}" title="${esc(name)}" ${disabled?'disabled aria-disabled="true"':''}`);}

  root.addEventListener('input',event=>{if(!event.target.matches('[data-v-account-query]'))return;const position=event.target.selectionStart;state.vAccountQuery=event.target.value;rBuildModal();const field=phone.querySelector('[data-v-account-query]');field?.focus({preventScroll:true});if(field?.type!=='search')field?.setSelectionRange(position,position);});
