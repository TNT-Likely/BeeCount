// Scene snapshots contain demo state only. Keep preset generation beside image exports.
const fs=require('fs'),path=require('path');
module.exports=async function createPresets(page,root,{reset=false}={}){
 const file=path.join(root,'prototype/scene-presets.js');
 const previous=reset||!fs.existsSync(file)?{}:JSON.parse(fs.readFileSync(file,'utf8').replace(/^window.beeDesignScenes = /,'').replace(/;\s*$/,''));
 const baseline=await page.evaluate(()=>JSON.parse(JSON.stringify(window.beeImmersiveDemo.state)));
 return {
  async capture(page,slug){previous[slug]=await page.evaluate(baseline=>{
   const a=window.beeImmersiveDemo,state=Object.fromEntries(Object.entries(a.state).filter(([k,v])=>JSON.stringify(v)!==JSON.stringify(baseline[k])));
   state.page=a.state.page;state.rModal=a.state.rModal;state.history=[];
   const toast=a.phone.querySelector('.bc-notice:not(.bc-notice-sample)');
   const context=a.phone.querySelector('[data-action^="x-select:"]');
   return {state,settings:{...a.settings},viewport:window.beeResponsivePreview.value,selected:[...a.selected],...(context?{contextMenu:a.state.detailId}:{}),...(toast?{toast:{text:toast.querySelector('span').textContent,tone:toast.dataset.feedbackTone}}:{})};
  },baseline);},
  save(){fs.writeFileSync(file,'window.beeDesignScenes = '+JSON.stringify(previous)+';\n');}
 };
};
