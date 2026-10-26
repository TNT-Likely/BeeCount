const fs = require('fs'), path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  try {
    const geometry = [];
    for (const [width, height] of [[398, 844], [320, 568]]) {
      const page = await browser.newPage({ viewport: { width, height: 1500 } });
      await page.goto(pathToFileURL(path.join(root, 'prototype/demo.html')).href +
        `?page=mine&viewport=${width}x${height}`);
      await page.waitForFunction(() => window.beeImmersiveDemo);
      const values = await page.locator('.u-ledger-summary').evaluate(el => {
        const css = getComputedStyle(el);
        const font = selector => parseFloat(getComputedStyle(el.querySelector(selector)).fontSize);
        return {
          padding: [css.paddingLeft, css.paddingTop, css.paddingRight, css.paddingBottom].map(parseFloat),
          radius: parseFloat(css.borderRadius),
          amountFont: font('.u-ledger-balance'),
          prefixFont: font('.u-ledger-balance>span'),
          statsValueFont: font('.u-ledger-stats strong'),
          statsLabelFont: font('.u-ledger-stats span'),
          height: el.getBoundingClientRect().height
        };
      });
      assert.ok(values.height < 110, 'Compact ledger summary must stay compact');
      assert.equal(await page.locator('.u-ledger-stats [data-action="page:home"]').count(), 1);
      geometry.push({ viewport: `${width}x${height}`, ...values });
      await page.close();
    }
    const result = { source: 'docs/design/card-refresh/prototype/demo.html?page=mine', measuredWith: 'Chromium computed styles, default skin, approved task F/A, 2026-10-26', geometry };
    if (process.argv.includes('--freeze')) {
      fs.writeFileSync(path.resolve(root, '../../../test/fixtures/v4-profile-geometry.json'), JSON.stringify(result, null, 2) + '\n');
    }
    console.log(JSON.stringify(result));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
