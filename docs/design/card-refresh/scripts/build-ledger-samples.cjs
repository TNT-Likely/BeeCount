const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url'),{chromium}=require('playwright'),root=path.resolve(__dirname,'..');
(async()=>{const b=await chromium.launch({channel:'chrome',headless:true}),p=await b.newPage({viewport:{width:1000,height:1600}});try{
await p.goto(pathToFileURL(path.join(root,'prototype/demo.html')).href+'?page=ledgers');await p.waitForFunction(()=>window.beeImmersiveDemo);const phone=p.locator('#bee-immersive-phone'),samples=JSON.parse(fs.readFileSync(path.join(root,'components/samples.json')));
samples.ledger=await phone.locator('.j-ledger-card').evaluateAll(es=>es.map(e=>e.outerHTML).join(''));
await phone.locator('[data-action="j-ledger-menu:日常生活"]').click();samples.ledgerMenu=await phone.locator('.j-ledger-context').evaluate(el=>el.outerHTML)+await phone.locator('.l-ledger-meta').evaluate(el=>el.outerHTML)+await phone.locator('.j-ledger-menu').evaluate(el=>el.outerHTML);
await phone.locator('[data-action="j-ledger-action:edit"]').click();samples.ledger+='<div class="l-gallery-editor">'+await phone.locator('.r-modal-layer .bc-sheet').evaluate(el=>el.innerHTML)+'</div>';
await phone.locator('[data-action="l-period"]').click();samples.ledger+='<div class="l-gallery-editor">'+await phone.locator('.l-day-grid').evaluate(el=>el.outerHTML)+'</div>';
fs.writeFileSync(path.join(root,'components/samples.json'),JSON.stringify(samples,null,2));console.log(JSON.stringify({ledgerCards:2,editor:true,monthStartDays:28,actions:true}));
}finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
