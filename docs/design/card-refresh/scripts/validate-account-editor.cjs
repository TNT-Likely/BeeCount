const path = require('path'), assert = require('node:assert/strict');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright');
const root = path.resolve(__dirname, '..');
const fs = require('fs');
const geometryFile = path.resolve(root, '../../../test/fixtures/v4-account-editor-geometry.json');
(async () => {
  const browser = await chromium.launch({channel:'chrome',headless:true});
  const errors=[], geometry=[];
  try {
    for(const [width,height,scale] of [[398,844,1],[320,568,1.4]]) {
      const page=await browser.newPage({viewport:{width:1280,height:1100}});
      page.on('pageerror',error=>errors.push(error.message));
      const url=pathToFileURL(path.join(root,'prototype/demo.html')).href;
      for(const route of ['account-new','account-edit','account-credit','account-valuation']) {
        await page.goto(`${url}?page=flow-${route}&viewport=${width}x${height}&scale=${scale}`);
        const phone=page.locator('.bc-phone');
        await phone.locator('.ae-footer').waitFor();
        assert.equal(await phone.locator('.ae-type-grid button').count(),6);
        assert.equal(await phone.locator('.ae-type-grid img').evaluateAll(images=>images.every(i=>i.complete&&i.naturalWidth)),true);
        assert.equal(await phone.evaluate(el=>el.scrollWidth>el.clientWidth),false);
        assert.equal(await phone.locator('.ae-scroll').evaluate(el=>el.scrollWidth>el.clientWidth),false);
        const frame=await phone.boundingBox(),footer=await phone.locator('.ae-footer').boundingBox();
        assert.ok(footer.y+footer.height<=frame.y+frame.height+1);
        await phone.locator('[data-action="ae-group:valuation"]').click();
        if(route!=='account-new'&&route!=='account-valuation')assert.equal(await phone.locator('.ae-type-grid button:disabled').count(),6);
        await phone.locator('[data-action="ae-group:daily"]').click();
        if(route==='account-new') {
          geometry.push(await phone.evaluate((el, config) => {
            const height = selector => el.querySelector(selector).getBoundingClientRect().height;
            return {...config, typeCardHeight: height('.ae-scroll>.bc-surface'), gridHeight: height('.ae-type-grid'), nameHeight: height('[data-ae-field="name"]'), noteHeight: height('[data-ae-field="note"]'), currencyHeight: height('.ae-menu')};
          }, {width,height,scale}));
          await phone.locator('[data-ae-field="name"]').fill('美元测试');
          await phone.locator('[data-action="ae-currency"]').click();
          await phone.locator('[data-ae-query]').fill('USD');
          await phone.locator('[data-action="ae-pick-currency:USD"]').click();
          assert.match(await phone.locator('.ae-menu').textContent(),/USD/);
        } else if(route==='account-edit') {
          await phone.locator('[data-ae-field="balance"]').fill('30000');
          await phone.locator('[data-action="ae-save"]').click();
          await phone.locator('[data-action="ae-adjust-mode:true"]').click();
          assert.equal(await phone.locator('[data-action="ae-adjust-mode:true"]').getAttribute('aria-pressed'),'true');
          await phone.locator('[data-action="ae-confirm-save"]').click();
          assert.equal(await phone.locator('.ae-footer').count(),1);
        } else if(route==='account-credit') {
          await phone.locator('[data-action="ae-day:billingDay"]').click();
          assert.equal(await phone.locator('.ae-day-grid button').count(),28);
          await phone.locator('[data-action="ae-pick-day:28"]').click();
          assert.match(await phone.locator('.ae-days').textContent(),/28/);
          await phone.locator('[data-action="ae-clear-day:billingDay"]').click();
          await phone.locator('[data-ae-reminder]').check();
          assert.equal(await phone.locator('.ae-lead button').count(),4);
        } else assert.equal(await phone.locator('[data-ae-field="balance"]').count(),0);
      }
      if(width===398)await page.locator('.bc-phone').screenshot({path:'/tmp/beecount-v4-account-editor-html.png'});
      await page.close();
    }
    assert.deepEqual(errors,[]);
    if(process.argv.includes('--freeze')) fs.writeFileSync(geometryFile, JSON.stringify({source:'prototype/demo.html?page=flow-account-new; Chrome rendered values, frame border remains outside Flutter canvas',sizes:geometry},null,2)+'\n');
    else assert.deepEqual(geometry,JSON.parse(fs.readFileSync(geometryFile)).sizes);
    console.log(JSON.stringify({status:'PASS',routes:4,viewports:2,originalTypes:12,dayRange:[1,28],reminderLead:[1,3,5,7],usdSelection:true,balanceModes:true,fixedSave:true}));
  } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
