const fs=require('fs'),path=require('path'),vm=require('vm'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..'),screens=JSON.parse(fs.readFileSync(path.join(root,'screens/manifest.json')));
const context={window:{}};vm.runInNewContext(fs.readFileSync(path.join(root,'prototype/scene-presets.js'),'utf8'),context);const scenes=context.window.beeDesignScenes;
function assert(value,message){if(!value)throw Error(message)}
(async()=>{const browser=await chromium.launch({channel:'chrome',headless:true}),p=await browser.newPage({viewport:{width:1000,height:1100}}),errors=[],checks=[];p.on('pageerror',e=>errors.push(e.message));await p.emulateMedia({reducedMotion:'reduce'});
    // QA export/verification never fetches website content. The original iframe
    // URL remains intact; its controlled body visibly states this limitation.
    const qaDocumentResponses=[], qaExternalBlocked=[];
    const qaDocumentNotice='QA 文档占位 · 未请求真实官网正文 / WebView / 法律文案';
    await p.route('**/*', async route=>{
      const request=route.request(),url=new URL(request.url());
      if(!['http:','https:'].includes(url.protocol))return route.continue();
      if(url.origin==='https://count.beejz.com'&&['/privacy','/docs/intro','/docs/changelog'].includes(url.pathname)&&request.resourceType()==='document'&&request.method()==='GET'){
        qaDocumentResponses.push(url.pathname);
        return route.fulfill({status:200,contentType:'text/html; charset=utf-8',body:'<!doctype html><html lang="zh"><meta charset="utf-8"><body style="font:14px sans-serif;padding:16px;color:#777"><p>'+qaDocumentNotice+'</p><p>仅检查原URL、加载/错误状态和页面交互；不代表真实官网或原生WebView验收。</p></body></html>'});
      }
      qaExternalBlocked.push({origin:url.origin,path:url.pathname});return route.abort();
    });

 await p.goto(pathToFileURL(path.join(root,'index.html')).href);assert(await p.locator('.screen').count()===screens.length,'index scene count');
 for(const [i,m] of screens.entries()){
  const article=p.locator('.screen').nth(i),href=await article.locator('a.preview-link').getAttribute('href');assert(href===await article.locator('a.preview-title').getAttribute('href')&&href===await article.locator('a.interactive').getAttribute('href'),'inconsistent links '+m.slug);assert(new URL(href,'https://preview.local/').searchParams.get('scene')===m.slug,'wrong scene target');assert(await article.locator(`a[href="${m.full}"]`).count()===1,'image link removed');assert(await article.locator(`a[href="${m.svg}"]`).count()===1,'SVG link removed');assert(scenes[m.slug],'missing state preset '+m.slug);
 }
 const target=await p.locator('.screen[data-title="欢迎 · 币种与默认账本"] a.preview-link').getAttribute('href');await p.locator('.screen[data-title="欢迎 · 币种与默认账本"] a.preview-link').click();assert(p.url().endsWith(target),'thumbnail navigation failed');assert(await p.locator('#bee-immersive-phone').getAttribute('data-page')==='welcomeCurrency','currency welcome route');
 for(const m of screens){
  await p.goto(pathToFileURL(path.join(root,'prototype/demo.html')).href+'?'+new URLSearchParams({page:m.route,scene:m.slug}));await p.waitForFunction(()=>window.beeImmersiveDemo);
  const actual=await p.evaluate(()=>({state:window.beeImmersiveDemo.state,settings:window.beeImmersiveDemo.settings,viewport:window.beeResponsivePreview.value,dialog:!!document.querySelector('#bee-immersive-phone [role=dialog]'),context:!!document.querySelector('#bee-immersive-phone [data-action^="x-select:"]'),toast:document.querySelector('#bee-immersive-phone .bc-notice:not(.bc-notice-sample)')?.textContent})),expected=scenes[m.slug];
  for(const key of ['page','rModal','leaf','jDatePart','ledger','receiptId','expandedCategory','subcategory','jSyncState','displayName','hide','fRecordCurrency','vQuoteStatus','swipedId'])if(Object.hasOwn(expected.state,key))assert(JSON.stringify(actual.state[key])===JSON.stringify(expected.state[key]),m.slug+' mismatched '+key+': '+actual.state[key]+' vs '+expected.state[key]);
  for(const key of ['skin','appearance','immersive','showBrand'])assert(actual.settings[key]===expected.settings[key],m.slug+' settings '+key);
  assert(JSON.stringify(actual.viewport)===JSON.stringify(expected.viewport),m.slug+' size mismatch');if(expected.state.rModal)assert(actual.dialog,'missing modal '+m.slug);if(expected.contextMenu)assert(actual.context,'context menu missing');if(expected.toast)assert(actual.toast?.includes(expected.toast.text),'toast missing');checks.push({slug:m.slug,route:actual.state.page,modal:actual.state.rModal||null,pass:true});
 }
 // Ordinary direct links also work without a scene preset; interactions remain live.
 for(const route of ['welcomeCategories','flow-logs','flow-category-tools','flow-foreign-editor','flow-ledger-picker']){await p.goto(pathToFileURL(path.join(root,'prototype/demo.html')).href+'?page='+route);if(route==='flow-foreign-editor')assert(await p.evaluate(()=>window.beeImmersiveDemo.state.page==='editor'&&window.beeImmersiveDemo.state.fRecordCurrency==='USD'),'plain foreign link ignored');else assert(await p.locator('#bee-immersive-pages').inputValue()===route,'plain page link ignored '+route);}
 await p.goto(pathToFileURL(path.join(root,'prototype/demo.html')).href+'?page=editor&scene=compact-note');await p.locator('[data-z-note]').fill('链接交互验收');assert(await p.evaluate(()=>window.beeImmersiveDemo.state.note)==='链接交互验收','note not interactive');
 await p.goto(pathToFileURL(path.join(root,'prototype/demo.html')).href+'?page=flow-foreign-editor&editorLayout=pinned&viewport=320x568&scale=1.4&expanded='+encodeURIComponent('餐饮')+'&quote=loading');assert(await p.evaluate(()=>window.beeImmersiveDemo.state.vQuoteStatus)==='loading','review rate state lost');assert(await p.evaluate(()=>window.beeImmersiveDemo.state.expandedCategory)==='餐饮','review expanded state lost');
 await p.goto(pathToFileURL(path.join(root,'index.html')).href);await p.locator('#query').fill('欢迎');await p.screenshot({path:path.join(root,'qa/overview-interactive-links.png')});await p.setViewportSize({width:390,height:844});assert(!await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth),'mobile overview overflow');
 assert(!errors.length,errors.join('\n'));fs.writeFileSync(path.join(root,'qa/preview-link-checks.json'),JSON.stringify({scenes:checks.length,thumbnailAndTitle:true,originalImageLinks:true,plainPageLinks:5,interactiveNote:true,pinnedVariants:true,qaDocumentResponses,qaExternalBlocked,websiteContentAndNativeWebView:'NOT_RUN',errors,checks},null,2));console.log(JSON.stringify({scenes:checks.length,errors,links:'image/title/explicit preview',plainPageLinks:5,interactiveNote:true,qaDocumentResponseCount:qaDocumentResponses.length,externalBlocked:qaExternalBlocked.length,websiteContentAndNativeWebView:'NOT_RUN'}));await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
