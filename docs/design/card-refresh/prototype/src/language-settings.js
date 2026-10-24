  // Reuse the same controlled language choice card as onboarding. App persistence
  // and desktop widget refresh remain in LanguageNotifier / updateAppWidget.
  fDefs.language.body=()=>surface(wLanguages.map(([code,name,detail])=>btn('w-language:'+code,`<span class="o-language-copy"><strong>${name}</strong><small>${detail}</small></span>${oCheck(state.wLanguage===code)}`,'使用'+name,'o-language',`aria-pressed="${state.wLanguage===code}"`)).join(''),'o-language-card');
