const path = require('path'), assert = require('node:assert/strict');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright');
const root = path.resolve(__dirname, '..');
(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  try {
    for (const width of [1440, 390, 320]) {
      const page = await browser.newPage({ viewport: { width, height: 1000 } });
      await page.goto(pathToFileURL(path.join(root, 'components/ui-components.html')).href);
      const create = page.locator('[data-account-types]').first();
      const edit = page.locator('[data-account-types]').last();
      assert.equal(await create.locator('[data-account-type]').count(), 12);
      await create.locator('[data-account-group="valuation"]').click();
      assert.match(await create.locator('[data-account-draft]').textContent(), /现金/);
      await create.locator('[data-account-type="loan"]').click();
      assert.match(await create.locator('[data-account-draft]').textContent(), /贷款/);
      await create.locator('[data-account-group="daily"]').click();
      assert.equal(await create.locator('[data-account-type="loan"]').getAttribute('aria-pressed'), 'true');
      await edit.locator('[data-account-group="valuation"]').click();
      assert.equal(await edit.locator('[data-account-panel="valuation"] button:disabled').count(), 6);
      assert.match(await edit.locator('[data-account-draft]').textContent(), /现金/);
      const adjustment = page.locator('[data-balance-adjustment]');
      await adjustment.locator('[data-balance-mode="true"]').click();
      await adjustment.locator('[data-balance-confirm]').click();
      assert.match(await adjustment.locator('[data-balance-result]').textContent(), /新增平账记录/);
      await adjustment.locator('[data-balance-mode="false"]').click();
      await adjustment.locator('[data-balance-confirm]').click();
      assert.match(await adjustment.locator('[data-balance-result]').textContent(), /只修改余额/);
      for (const mode of ['light', 'dark']) {
        await page.locator('#spec-mode').selectOption(mode);
        assert.equal(await create.evaluate(el => el.scrollWidth > el.clientWidth), false);
        assert.equal(await create.locator('img').evaluateAll(images => images.every(image => image.complete && image.naturalWidth > 0)), true);
      }
      await page.close();
    }
    console.log(JSON.stringify({ status: 'PASS', widths: [1440, 390, 320], originalTypes: 12, draftPreservedOnGroupBrowse: true, editRestrictions: true, originalSvgIcons: true }));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
