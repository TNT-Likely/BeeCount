// Independent reference board; it does not add or rewrite scene presets.
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright');
const root = path.resolve(__dirname, '..');
const cases = [
  ['无账户 · 标准屏', 'flow-transfer-inline-empty-accounts', 398, 844],
  ['尚未选择账户 · 标准屏', 'flow-transfer-inline', 398, 844],
  ['人民币账户已选 · 标准屏', 'flow-transfer-inline-cny', 398, 844],
  ['美元账户已选 · 标准屏', 'flow-transfer-inline-usd', 398, 844],
  ['无账户 · 小屏', 'flow-transfer-inline-empty-accounts', 320, 568],
  ['尚未选择账户 · 小屏', 'flow-transfer-inline', 320, 568],
  ['人民币账户已选 · 小屏', 'flow-transfer-inline-cny', 320, 568],
  ['备注展开 · 小屏', 'flow-transfer-inline-note', 320, 568],
];
const href = (route, width, height) => '../prototype/demo.html?' + new URLSearchParams({ page: route, viewport: `${width}x${height}` });
const cards = cases.map(([name, route, width, height]) => `<article><h2>${name}</h2><p>${width} × ${height} · 默认无皮肤</p><a href="${href(route, width, height)}">打开交互原型 ↗</a><div class="preview" data-width="${width}" data-height="${height}" style="max-width:${width}px"><iframe title="${name}" width="${width}" height="${height}" src="${href(route, width, height)}&embed=1"></iframe></div></article>`).join('');
const html = `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>转账 · 长短屏与空账户</title><style>*{box-sizing:border-box}body{margin:0;padding:28px;background:#eef1f4;color:#25282c;font:14px/1.65 -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}header{max-width:1000px;margin-bottom:24px}h1{font-size:26px;margin:0 0 9px}header p{color:#777c82;margin:0}main{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:22px}article{min-width:0;padding:16px;background:#fff;border-radius:22px}h2{font-size:16px;margin:0 0 4px}article p{margin:0 0 8px;font-size:12px;color:#777c82}a{display:block;color:#887019;margin-bottom:12px}.preview{position:relative;width:100%;margin:auto;overflow:hidden;border-radius:28px}iframe{display:block;max-width:none;border:0;transform-origin:top left}@media(max-width:1100px){main{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:680px){body{padding:18px 14px}main{grid-template-columns:1fr}h1{font-size:23px}}</style><header><h1>转账 · 长短屏与空账户</h1><p>转出、转入账户在同屏选择；表单不预留单账户空槽。日期从左侧开始，标签在右；小屏折叠备注，保留键盘与保存。下方为主 demo 的实际交互页面，采用合成数据；不表示原生设备验收。原 567 个场景预设与顺序保持。</p></header><main>${cards}</main><script>const observer=new ResizeObserver(entries=>{for(const entry of entries){const box=entry.target,w=Number(box.dataset.width),h=Number(box.dataset.height),scale=Math.min(1,box.clientWidth/w);box.style.height=h*scale+'px';box.querySelector('iframe').style.transform='scale('+scale+')';}});document.querySelectorAll('.preview').forEach(box=>observer.observe(box));</script></html>`;
fs.writeFileSync(path.join(root, 'boards/transfer-responsive.html'), html);

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 1200 }, deviceScaleFactor: 1 });
  const errors = [], checks = [];
  page.on('pageerror', error => errors.push(error.message));
  try {
    await page.goto(pathToFileURL(path.join(root, 'boards/transfer-responsive.html')).href);
    await Promise.all(page.frames().slice(1).map(frame => frame.waitForFunction(() => window.beeImmersiveDemo)));
    for (const frame of page.frames().slice(1)) await frame.evaluate(async () => {
      window.beeImmersiveDemo.freeze(5);
      await document.fonts.ready;
      await Promise.all([...document.images].map(image => image.decode().catch(() => {})));
    });
    await page.screenshot({ path: path.join(root, 'boards/transfer-responsive.png'), fullPage: true });
    for (const width of [1440, 390, 320]) {
      await page.setViewportSize({ width, height: 960 });
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false, 'reference board overflow');
    }
    await page.setViewportSize({ width: 1100, height: 1100 });
    for (const [name, route, width, height] of cases) {
      await page.goto(pathToFileURL(path.join(root, 'prototype/demo.html')).href +
        `?page=${route}&viewport=${width}x${height}`);
      await page.waitForFunction(() => window.beeImmersiveDemo);
      const geometry = await page.locator('.ti93-shell').evaluate(shell => {
        const reference = shell.querySelector('.ti93-reference-row');
        const rect = element => { const r = element.getBoundingClientRect(); return { x: r.x, y: r.y, width: r.width, height: r.height }; };
        return { shell: rect(shell), date: rect(reference.querySelector('.ti93-date')), first: rect(reference.firstElementChild),
          expanded: shell.dataset.ti93NoteExpanded === 'true', horizontalOverflow: shell.scrollWidth > shell.clientWidth,
          verticalOverflow: shell.scrollHeight - shell.clientHeight, firstAction: reference.firstElementChild.dataset.ti93Action,
          children: [...reference.children].map(button => button.dataset.ti93Action),
          saveBottom: shell.querySelector('.ti93-footer-actions').getBoundingClientRect().bottom,
          phoneBottom: shell.closest('.bc-phone').getBoundingClientRect().bottom };
      });
      assert.equal(geometry.horizontalOverflow, false, name);
      assert.ok(geometry.verticalOverflow <= 1, name);
      assert.ok(geometry.saveBottom <= geometry.phoneBottom, name);
      assert.equal(geometry.firstAction, geometry.expanded ? 'date' : 'note-toggle', name + ' empty slot');
      assert.deepEqual(geometry.children, geometry.expanded ? ['date', 'tags'] : ['note-toggle', 'date', 'tags', 'attachments']);
      if (route.endsWith('empty-accounts')) assert.equal(await page.locator('.ti93-account-empty').count(), 1);
      checks.push({ name, route, width, height, geometry });
    }
    assert.deepEqual(errors, []);
    fs.writeFileSync(path.join(root, 'qa/transfer-responsive-checks.json'), JSON.stringify({ scope: 'Synthetic HTML only', cases: checks.length, checks, errors }, null, 2));
    console.log(JSON.stringify({ cases: checks.length, board: 'boards/transfer-responsive.png', scenesAdded: 0, presetsRewritten: false, errors }));
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
