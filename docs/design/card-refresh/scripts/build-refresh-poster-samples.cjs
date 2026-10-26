// Refresh the component guide's static print samples from the approved D board.
// This reads synthetic HTML only. No account, device or native export is used.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..'),file=path.join(root,'boards/share-cards-task-d-review.html'),prefix='#bee-immersive-suite .rf119-approved-poster';
(async()=>{const browser=await chromium.launch({channel:'chrome',headless:true}),page=await browser.newPage();await page.goto(pathToFileURL(file).href);await page.waitForFunction(()=>window.shareCardsReview);const data=await page.evaluate(()=>{
 const review=window.shareCardsReview;review.state.avatar='default';review.state.motion=false;review.state.skin='none';review.state.private=false;review.render();
 const posters=[];for(const [kind,label]of [['profile','个人档案'],['app','应用分享'],['month','月度总结'],['year','年度总结'],['ledger','账本总结'],['annual','年度长图'],['receipt','账单小票']]){
  const container=document.createElement('div');container.style.cssText='position:absolute;left:-10000px;top:0;width:720px';container.innerHTML=review.poster(kind);document.body.appendChild(container);const rect=container.firstElementChild.getBoundingClientRect();posters.push({kind,label,width:rect.width,height:rect.height,html:container.innerHTML});container.remove();
 }
 function rules(list){return [...list].map(r=>r.type===CSSRule.STYLE_RULE?{selector:r.selectorText,style:r.style.cssText}:r.type===CSSRule.MEDIA_RULE?{condition:r.conditionText,rules:rules(r.cssRules)}:null).filter(Boolean)}
 return {posters,rules:[...document.styleSheets].flatMap(s=>rules(s.cssRules))};
});
function split(selector){let depth=0,start=0,parts=[];for(let i=0;i<selector.length;i++){if('(['.includes(selector[i]))depth++;if(')]'.includes(selector[i]))depth--;if(selector[i]===','&&depth===0){parts.push(selector.slice(start,i));start=i+1;}}parts.push(selector.slice(start));return parts.map(s=>s.trim())}
function scope(rules){return rules.map(r=>r.rules?`@media ${r.condition}{${scope(r.rules)}}`:`${split(r.selector).map(s=>/^(?:body|html|:root)$/.test(s)?prefix:prefix+' '+s).join(',')}{${r.style}}`).join('\n')}
fs.writeFileSync(path.join(root,'prototype/src/refresh-poster-snapshots.json'),JSON.stringify({source:'boards/share-cards-task-d-review.html',sha256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'),posters:data.posters},null,2));
fs.writeFileSync(path.join(root,'prototype/src/refresh-poster-snapshots.css'),scope(data.rules)+`\n${prefix}{--brand:var(--bc-accent,#facb16);--brand-ink:var(--bc-on-accent,#292817);--brand-soft:color-mix(in srgb,var(--bc-accent,#facb16) 12%,#fffefa);font-family:-apple-system,BlinkMacSystemFont,'PingFang SC','Microsoft YaHei',sans-serif;color-scheme:light;background:transparent;margin:0;padding:0}\n`);
console.log(data.posters.map(({kind,width,height})=>({kind,width,height})));await browser.close();})().catch(e=>{console.error(e);process.exit(1)});
