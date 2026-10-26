const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '..');
const repo = path.resolve(root, '../../..');
const output = process.env.BEECOUNT_RESOURCE_INDEX_QA_DIR || path.join(repo, '.docs/v4-ui-migration/design-resource-grouping-20261026');
const url = process.env.BEE_DESIGN_INDEX_URL || 'http://127.0.0.1:8374/index.html';
const key = 'beecount.design-resources.layout.v1';
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'screens/manifest.json')));
const checks = [];
const errors = [];

const visibleScenes = page => page.locator('.screen:not([hidden]) .interactive').evaluateAll(
  links => links.map(link => new URL(link.href).searchParams.get('scene')).sort());

function listen(page) {
  page.on('pageerror', error => errors.push(error.message));
}

async function open(context, width = 1440) {
  const page = await context.newPage();
  listen(page);
  await page.setViewportSize({ width, height: 960 });
  await page.goto(url);
  await page.waitForSelector('#screen-list .screen');
  return page;
}

(async () => {
  fs.mkdirSync(output, { recursive: true, mode: 0o700 });
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  try {
    const context = await browser.newContext();
    const page = await open(context);
    const flat = page.getByRole('button', { name: '平铺', exact: true });
    const grouped = page.getByRole('button', { name: '分组', exact: true });
    assert.equal(await flat.getAttribute('aria-pressed'), 'true');
    assert.equal(await page.locator('.screen').count(), manifest.length);
    assert.deepEqual(await page.locator('#group option').evaluateAll(options => options.slice(1).map(option => option.value)),
      [...new Set(manifest.map(scene => scene.group))]);
    const links = await page.locator('.screen').evaluateAll(cards => cards.map(card => ({
      scene: new URL(card.querySelector('.interactive').href).searchParams.get('scene'),
      links: [...card.querySelectorAll('a')].map(link => link.getAttribute('href')),
    })).sort((a, b) => a.scene.localeCompare(b.scene)));
    assert.deepEqual(links.map(item => item.scene).sort(), manifest.map(scene => scene.slug).sort());
    await page.evaluate(() => {
      window.originalResourceCards = [...document.querySelectorAll('.screen')];
      localStorage.setItem('unrelated-design-setting', 'preserved');
    });
    await grouped.click();
    assert.equal(await grouped.getAttribute('aria-pressed'), 'true');
    assert.equal(await page.locator('.resource-group').count(), 12);
    assert.equal(await page.locator('.screen').count(), manifest.length);
    assert.equal(await page.evaluate(() => [...document.querySelectorAll('.screen')].every(
      card => window.originalResourceCards.includes(card))), true);
    const groupedLinks = await page.locator('.screen').evaluateAll(cards => cards.map(card => ({
      scene: new URL(card.querySelector('.interactive').href).searchParams.get('scene'),
      links: [...card.querySelectorAll('a')].map(link => link.getAttribute('href')),
    })).sort((a, b) => a.scene.localeCompare(b.scene)));
    assert.deepEqual(groupedLinks, links);
    assert.equal(await page.evaluate(key => localStorage.getItem(key), key), 'grouped');
    assert.equal(await page.evaluate(() => localStorage.getItem('unrelated-design-setting')), 'preserved');
    checks.push('567 scenes and all original links retained exactly; existing card nodes moved, not cloned');

    await page.reload();
    await page.waitForSelector('.resource-group');
    assert.equal(await grouped.getAttribute('aria-pressed'), 'true');
    const reopened = await open(context);
    assert.equal(await reopened.getByRole('button', { name: '分组', exact: true }).getAttribute('aria-pressed'), 'true');
    await reopened.close();
    checks.push('grouped selection survives refresh and opening a second page on the same origin');

    await page.locator('#query').fill('账户');
    await page.locator('#group').selectOption('补齐 · 账户与资产');
    const filtered = await visibleScenes(page);
    const expected = manifest.filter(scene => scene.group === '补齐 · 账户与资产' && scene.title.includes('账户')).map(scene => scene.slug).sort();
    assert.ok(expected.length > 0);
    assert.deepEqual(filtered, expected);
    await flat.click();
    assert.deepEqual(await visibleScenes(page), expected);
    await grouped.click();
    assert.deepEqual(await visibleScenes(page), expected);
    assert.equal(await page.locator('#query').inputValue(), '账户');
    assert.equal(await page.locator('#group').inputValue(), '补齐 · 账户与资产');
    assert.equal(await page.locator('.resource-group:not([hidden])').count(), 1);
    assert.equal(await page.locator('#group-navigation a:not([hidden])').count(), 1);
    checks.push('search and original group filter combine correctly and survive both layout switches; empty groups hidden');

    await page.locator('#query').fill('不存在的场景-871d');
    assert.equal(await page.locator('.screen:not([hidden])').count(), 0);
    assert.equal(await page.locator('.resource-group:not([hidden])').count(), 0);
    assert.equal(await page.locator('#empty-state').isVisible(), true);
    assert.equal(await page.locator('#group-navigation').isVisible(), false);
    await page.locator('#query').fill('');
    await page.locator('#group').selectOption('');
    assert.equal(await page.locator('.screen:not([hidden])').count(), manifest.length);
    checks.push('zero matches show an explicit empty state and recover all scenes when cleared');

    const layouts = [];
    for (const width of [1440, 390, 320]) {
      await page.setViewportSize({ width, height: 960 });
      for (const layout of ['flat', 'grouped']) {
        await page.locator(`[data-layout="${layout}"]`).click();
        assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
        assert.equal(await page.locator('.screen:not([hidden])').count(), manifest.length);
        await page.locator('.collection-toolbar').scrollIntoViewIfNeeded();
        await page.screenshot({ path: path.join(output, `${layout}-${width}.png`) });
        layouts.push({ width, layout, count: manifest.length, horizontalOverflow: false });
      }
    }
    await flat.focus();
    await flat.press('Enter');
    assert.equal(await flat.getAttribute('aria-pressed'), 'true');
    await page.reload();
    assert.equal(await flat.getAttribute('aria-pressed'), 'true');
    checks.push('flat selection also persists; keyboard activation works; desktop/390/320 have no horizontal overflow');
    await context.close();

    for (const deny of ['all', 'write']) {
      const restricted = await browser.newContext();
      await restricted.addInitScript(deny => {
        if (deny === 'all') Object.defineProperty(window, 'localStorage', {
          configurable: true,
          get() { throw new DOMException('Storage blocked by policy', 'SecurityError'); },
        });
        else Storage.prototype.setItem = function () { throw new DOMException('Quota blocked', 'QuotaExceededError'); };
      }, deny);
      const restrictedPage = await open(restricted, 320);
      assert.equal(await restrictedPage.locator('[data-layout="flat"]').getAttribute('aria-pressed'), 'true');
      await restrictedPage.locator('[data-layout="grouped"]').click();
      assert.equal(await restrictedPage.locator('.resource-group').count(), 12);
      assert.equal(await restrictedPage.locator('.screen:not([hidden])').count(), manifest.length);
      await restrictedPage.reload();
      assert.equal(await restrictedPage.locator('[data-layout="flat"]').getAttribute('aria-pressed'), 'true');
      await restricted.close();
      checks.push(`${deny} storage denial: safe default, functional in-session switch, no exception`);
    }

    const invalid = await browser.newContext();
    await invalid.addInitScript(key => localStorage.setItem(key, 'unsupported-mode'), key);
    const invalidPage = await open(invalid);
    assert.equal(await invalidPage.locator('[data-layout="flat"]').getAttribute('aria-pressed'), 'true');
    await invalid.close();
    checks.push('unrecognized stored layout falls back to flat');

    const localContext = await browser.newContext();
    const localPage = await localContext.newPage();
    listen(localPage);
    await localPage.goto(pathToFileURL(path.join(root, 'index.html')).href);
    await localPage.locator('[data-layout="grouped"]').click();
    await localPage.reload();
    assert.equal(await localPage.locator('[data-layout="grouped"]').getAttribute('aria-pressed'), 'true');
    assert.equal(await localPage.locator('.screen').count(), manifest.length);
    await localContext.close();
    checks.push('opening index.html directly as a local file also retains grouped mode after reload');

    assert.deepEqual(errors, []);
    const report = { scope: 'Design resource index only; no App, device or Cloud operations', scenes: manifest.length, displayGroups: 12, checks, layouts, errors };
    fs.writeFileSync(path.join(output, 'validation.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify(report, null, 2));
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
