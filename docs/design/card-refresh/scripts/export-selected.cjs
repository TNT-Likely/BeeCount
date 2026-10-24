// Refresh changed routes while preserving every other exported scene and preset.
const fs = require('fs'), path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright');
const toSvg = require('./dom-to-svg.cjs');
const snapshotDom = require('./snapshot-dom.cjs');
const root = path.resolve(__dirname, '..');
const routes = [...new Set(process.argv.slice(2))];
if (!routes.length) throw Error('Pass one or more prototype route IDs');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 736, height: 1900 }, deviceScaleFactor: 2 });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.goto(pathToFileURL(path.join(root, 'prototype/demo.html')).href);
    await page.waitForFunction(() => window.beeImmersiveDemo);
    const phone = page.locator('#bee-immersive-phone');
    const picker = page.locator('#bee-immersive-pages');
    const baseline = await page.evaluate(() => JSON.parse(JSON.stringify(window.beeImmersiveDemo.state)));
    const presets = await require('./scene-presets.cjs')(page, root);
    const manifest = JSON.parse(fs.readFileSync(path.join(root, 'screens/manifest.json')));
    const domFile = path.join(root, 'figma/dom-snapshots.json');
    const snapshots = fs.existsSync(domFile) ? JSON.parse(fs.readFileSync(domFile)) : [];
    const css = [...fs.readFileSync(path.join(root, 'prototype/source.fragment.html'), 'utf8')
      .matchAll(/<style>([\s\S]*?)<\/style>/g)].map(m => m[1]).join('\n');
    for (const dir of ['screens/full', 'screens/viewport', 'figma/html', 'qa']) {
      fs.mkdirSync(path.join(root, dir), { recursive: true });
    }
    function upsert(items, value) {
      const i = items.findIndex(m => m.slug === value.slug);
      if (i < 0) items.push(value); else items[i] = value;
    }
    for (const route of routes) {
      const options = await picker.locator('option').evaluateAll(elements => elements.map(e => ({
        route: e.value, title: e.textContent, group: e.parentElement.label || '其他'
      })));
      const target = options.find(o => o.route === route);
      if (!target) throw Error('Unknown route: ' + route);
      const slug = route.replaceAll(/[^a-zA-Z0-9_-]/g, '-');
      await page.evaluate(baseline => {
        const api = window.beeImmersiveDemo;
        Object.assign(api.state, JSON.parse(JSON.stringify(baseline)));
        api.state.history = [];
        Object.assign(api.settings, { skin: 'none', appearance: 'light', immersive: false, showBrand: true });
      }, baseline);
      await picker.selectOption(route);
      await page.evaluate(() => { window.beeImmersiveDemo.freeze(5); document.activeElement?.blur(); });
      const fullStyle = await page.addStyleTag({ content: '#bee-immersive-suite .bc-phone:not([data-modal="true"]){height:auto!important;max-height:none!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .bc-main{max-height:none!important;overflow:visible!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .bc-main:has(.ae-shell){height:auto!important;display:block!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .ae-shell{display:block}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .ae-scroll{overflow:visible}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .bc-main:has(.cm-manager-page){height:auto!important;display:block!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .cm-manager-page{display:block}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .cm-manager-scroll{overflow:visible}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .bc-main:has(.av-shell){height:auto!important;display:block!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .av-shell{display:block}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .av-scroll{overflow:visible}' });
      const bounds = await phone.boundingBox();
      await phone.screenshot({ path: path.join(root, 'screens/full', slug + '.png') });
      await fullStyle.evaluate(e => e.remove());
      const viewportStyle = await page.addStyleTag({ content: '#bee-immersive-suite .bc-phone{height:844px!important;min-height:844px!important;max-height:844px!important;overflow:hidden!important}' });
      await phone.screenshot({ path: path.join(root, 'screens/viewport', slug + '.png') });
      const vector = await phone.evaluate(toSvg);
      fs.writeFileSync(path.join(root, 'figma', slug + '.svg'), vector.svg);
      await presets.capture(page, slug);
      const dom = await phone.evaluate(snapshotDom);
      const restore = '<script>for(const e of document.querySelectorAll("[data-snapshot-scroll]"))e.scrollTop=Number(e.dataset.snapshotScroll);</script>';
      const head = '<meta charset="utf-8"><style>' + css + '</style><style>*{box-sizing:border-box}body{margin:0;background:#eceeef;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}#bee-immersive-suite{width:398px}.bc-phone{height:844px!important;min-height:844px!important;max-height:844px!important;overflow:hidden!important}</style>';
      fs.writeFileSync(path.join(root, 'figma/html', slug + '.html'), '<!doctype html><html lang="zh-CN">' + head + '<div id="bee-immersive-suite">' + dom + '</div>' + restore + '</html>');
      upsert(snapshots, { slug, title: target.title, group: target.group, dom });
      await viewportStyle.evaluate(e => e.remove());
      upsert(manifest, { ...target, slug, fullHeight: Math.round(bounds.height), viewport: 'screens/viewport/' + slug + '.png', full: 'screens/full/' + slug + '.png', svg: 'figma/' + slug + '.svg' });
    }
    if (errors.length) throw Error(errors.join('\n'));
    presets.save();
    fs.writeFileSync(domFile, JSON.stringify(snapshots));
    fs.writeFileSync(path.join(root, 'screens/manifest.json'), JSON.stringify(manifest, null, 2));
    const boards = await require('./build-page-boards.cjs')(root, browser, manifest);
    require('./build-index.cjs');
    fs.writeFileSync(path.join(root, 'qa/selected-export-report.json'), JSON.stringify({ refreshed: routes, retainedOtherScenes: manifest.length - routes.length, total: manifest.length, boards, errors }, null, 2));
    console.log(JSON.stringify({ refreshed: routes.length, scenes: manifest.length, errors }));
  } finally {
    await browser.close();
  }
})().catch(e => { console.error(e); process.exitCode = 1; });
