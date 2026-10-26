const assert=require('assert'),fs=require('fs'),os=require('os'),path=require('path'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..'),moduleSpec=require('../prototype/src/transaction-export-module.cjs');
const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'beecount-export-ui-'));
const harness=path.join(temporary,'demo.html');
let html=fs.readFileSync(path.join(root,'prototype/demo.html'),'utf8');
assert(html.includes('  const views={categoryPicker:'),'Existing demo insertion point is required');
if(html.includes('// EX88 TRANSACTION EXPORT START'))html=html.replace(/  \/\/ EX88 TRANSACTION EXPORT START[\s\S]*?  \/\/ EX88 TRANSACTION EXPORT END/,()=>moduleSpec.javascript);
else html=html.replace('  const views={categoryPicker:',()=>moduleSpec.javascript+'\n  const views={categoryPicker:');
html=html.replace('</head>','<style>'+moduleSpec.css+'</style></head>');
html=html.replace('src="vendor/lucide.min.js"','src="'+pathToFileURL(path.join(root,'prototype/vendor/lucide.min.js')).href+'"').replace('src="scene-presets.js"','src="'+pathToFileURL(path.join(root,'prototype/scene-presets.js')).href+'"');
fs.writeFileSync(harness,html);
(async()=>{
  const browser=await chromium.launch({channel:'chrome'}),errors=[];
  try {
    const page=await browser.newPage({viewport:{width:900,height:1500},acceptDownloads:true});
    page.on('pageerror',error=>errors.push(error.message));
    let profiles=0;
    for(const [viewport,scale,appearance] of [['398x844','1','light'],['320x568','1.4','dark']]) {
      for(const scene of moduleSpec.scenes) {
        await page.goto(pathToFileURL(harness).href+'?page='+scene+'&viewport='+viewport+'&scale='+scale);
        await page.waitForFunction(()=>window.beeImmersiveDemo);
        await page.evaluate(appearance=>{window.beeImmersiveDemo.settings.appearance=appearance;window.beeImmersiveDemo.render()},appearance);
        assert.equal(await page.locator('.ex88-fields>span').count(),12);
        assert.equal(await page.locator('.ex88-stack input,.ex88-stack select').count(),0,'Fixed export must not offer unsupported filters');
        assert.equal(await page.locator('.ex88-export').count(),1);
        for(const node of await page.locator('.ex88-stack,.ex88-card,.ex88-fields').all())assert(!(await node.evaluate(element=>element.scrollWidth>element.clientWidth+1)),scene+' overflow');
        if(scene==='flow-export-running')assert(await page.locator('.ex88-export').isDisabled());
        if(scene==='flow-export-ios')assert.equal((await page.locator('.ex88-export').innerText()).trim(),'导出并分享');
        if(scene==='flow-export-share-error')assert.equal(await page.locator('.ex88-result').count(),2);
        profiles++;
      }
    }
    await page.goto(pathToFileURL(harness).href+'?page=flow-export-error');
    const downloadEvent=page.waitForEvent('download');await page.locator('.ex88-export').click();
    const download=await downloadEvent,downloadPath=await download.path();
    const bytes=fs.readFileSync(downloadPath),csv=bytes.toString('utf8');
    assert.deepEqual([...bytes.subarray(0,3)],[0xef,0xbb,0xbf]);
    assert.equal(download.suggestedFilename(),'beecount_20261025_080910.csv');
    assert.equal(csv.split('\n').length,3);assert(csv.includes('转出账户,转入账户'));assert(csv.includes('qa-receipt.png'));
    assert.equal(await page.locator('.ex88-result').count(),1,'Retry should show saved path');
    await page.locator('.ex88-stack').evaluate((node,sample)=>node.innerHTML=sample,moduleSpec.sample);
    await page.locator('[data-ex88-demo]').click();
    assert((await page.locator('[data-ex88-demo-result]').innerText()).includes('不访问真实数据'));
    assert.deepEqual(errors,[]);
    console.log(JSON.stringify({profiles,fields:12,fixedCurrentLedger:true,busyDisabled:true,retryDownloadsCsvWithBom:true,readOnlyGuide:true,errors}));
  } finally {await browser.close();fs.rmSync(temporary,{recursive:true,force:true});}
})().catch(error=>{console.error(error);fs.rmSync(temporary,{recursive:true,force:true});process.exit(1)});
