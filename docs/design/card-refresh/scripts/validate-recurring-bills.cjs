const assert=require('assert'),path=require('path'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'..'),base=pathToFileURL(root+'/prototype/demo.html').href;
const scenes=['flow-recurring','flow-recurring-empty','flow-recurring-loading','flow-recurring-error','flow-recurring-saving','flow-recurring-long','flow-recurring-save-error'];
(async()=>{
  const browser=await chromium.launch({channel:'chrome'});
  try {
    const page=await browser.newPage({viewport:{width:900,height:1500}}),errors=[];
    page.on('pageerror',error=>errors.push(error.message));
    let profiles=0;
    for(const [size,scale,mode] of [['398x844','1','light'],['320x568','1.4','dark']]) {
      for(const scene of scenes) {
        await page.goto(base+'?page='+scene+'&viewport='+size);
        await page.waitForFunction(()=>window.beeImmersiveDemo);
        await page.evaluate(mode=>{window.beeImmersiveDemo.settings.appearance=mode;window.beeImmersiveDemo.render()},mode);
        await page.locator('#bee-preview-scale').selectOption(scale);
        assert.equal(await page.locator('[data-action="f-go:recurring-edit"]').count()>0,true);
        for(const element of await page.locator('.r86-list,.r86-rule,.r86-rule-head').all()) {
          assert(!(await element.evaluate(node=>node.scrollWidth>node.clientWidth+1)),scene+' overflow');
        }
        if(!['flow-recurring-empty','flow-recurring-loading','flow-recurring-error'].includes(scene)) {
          assert.equal(await page.locator('.r86-switch').count(),3);
          assert((await page.locator('.r86-list').innerText()).includes('USD'));
          assert((await page.locator('.r86-list').innerText()).includes('JPY'));
          assert((await page.locator('.r86-list').innerText()).includes('最近生成'));
        }
        if(scene==='flow-recurring-saving')assert.equal(await page.locator('.r86-switch:disabled').count(),3);
        profiles++;
      }
    }
    await page.goto(base+'?page=flow-recurring');
    const toggle=page.locator('[data-r86-toggle="coffee"]');
    assert.equal(await toggle.getAttribute('aria-checked'),'true');
    await toggle.click();
    assert.equal(await page.locator('[data-r86-toggle="coffee"]').getAttribute('aria-checked'),'false');
    assert.equal(await page.locator('.r86-list').count(),1,'Toggle must not open the editor');
    await page.locator('.r86-open').first().click();
    assert.equal(await page.locator('.r86-list').count(),0);
    assert.equal(await page.locator('[data-action^="f-save:"]').count(),1);
    await page.goto(base+'?page=flow-recurring-save-error');
    await page.locator('[data-r86-toggle=coffee]').click();
    assert.equal(await page.locator('[data-r86-toggle=coffee]').getAttribute('aria-checked'),'true','Failed save preserves original value');
    await page.goto(base+'?page=flow-recurring-error');
    await page.locator('[data-action="r86-retry"]').click();
    assert.equal(await page.locator('.r86-list').count(),1);
    await page.goto(pathToFileURL(root+'/components/ui-components.html').href);
    const sample=page.locator('#spec-81');
    await sample.locator('[data-r86-demo-toggle]').click();
    assert.equal(await sample.locator('[data-r86-demo-toggle]').getAttribute('aria-checked'),'false');
    assert((await sample.locator('[data-r86-demo-event]').innerText()).includes('不修改真实周期配置'));
    await sample.locator('[data-r86-demo-open]').click();
    assert((await sample.locator('[data-r86-demo-event]').innerText()).includes('示例编辑入口'));
    assert.deepEqual(errors,[]);
    console.log(JSON.stringify({profiles,allLedgerCurrencyFrequencyAndGeneratedDate:true,toggleDoesNotNavigate:true,originalEditorEntry:true,loadRetry:true,actualGuideCallbacks:true,errors}));
  } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exit(1)});
