// Refresh changed routes or scene:<slug> while preserving every other scene and preset.
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

    // QA export/verification never fetches website content. The original iframe
    // URL remains intact; its controlled body visibly states this limitation.
    const qaDocumentResponses=[], qaExternalBlocked=[];
    const qaDocumentNotice='QA 文档占位 · 未请求真实官网正文 / WebView / 法律文案';
    await page.route('**/*', async route=>{
      const request=route.request(),url=new URL(request.url());
      if(!['http:','https:'].includes(url.protocol))return route.continue();
      if(url.origin==='https://count.beejz.com'&&['/privacy','/docs/intro','/docs/changelog'].includes(url.pathname)&&request.resourceType()==='document'&&request.method()==='GET'){
        qaDocumentResponses.push(url.pathname);
        return route.fulfill({status:200,contentType:'text/html; charset=utf-8',body:'<!doctype html><html lang="zh"><meta charset="utf-8"><body style="font:14px sans-serif;padding:16px;color:#777"><p>'+qaDocumentNotice+'</p><p>仅检查原URL、加载/错误状态和页面交互；不代表真实官网或原生WebView验收。</p></body></html>'});
      }
      qaExternalBlocked.push({origin:url.origin,path:url.pathname});return route.abort();
    });

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
    for (const request of routes) {
      const sceneSlug = request.startsWith('scene:') ? request.slice(6) : null;
      const scene = sceneSlug ? manifest.find(m => m.slug === sceneSlug) : null;
      if (sceneSlug && !scene) throw Error('Unknown scene: ' + sceneSlug);
      const route = scene ? scene.route : request;
      const options = await picker.locator('option').evaluateAll(elements => elements.map(e => ({
        route: e.value, title: e.textContent, group: e.parentElement.label || '其他'
      })));
      const target = scene || options.find(o => o.route === route);
      if (!target) throw Error('Unknown route: ' + route);
      const slug = sceneSlug || route.replaceAll(/[^a-zA-Z0-9_-]/g, '-');
      if (scene) {
        const url = new URL(pathToFileURL(path.join(root, 'prototype/demo.html')).href);
        url.search = new URLSearchParams({ page: route, scene: sceneSlug });
        await page.goto(url.href);
        await page.waitForFunction(() => window.beeImmersiveDemo);
      } else {
        if (new URL(page.url()).searchParams.has('scene')) {
          await page.goto(pathToFileURL(path.join(root, 'prototype/demo.html')).href);
          await page.waitForFunction(() => window.beeImmersiveDemo);
        }
        await page.evaluate(baseline => {
        const api = window.beeImmersiveDemo;
        Object.assign(api.state, JSON.parse(JSON.stringify(baseline)));
        api.state.history = [];
        Object.assign(api.settings, { skin: 'none', appearance: 'light', immersive: false, showBrand: true });
        }, baseline);
        await picker.selectOption(route);
      }
      await page.evaluate(() => { window.beeImmersiveDemo.freeze(5); document.activeElement?.blur(); });
      const viewport = await page.evaluate(() => ({ ...window.beeResponsivePreview.value }));
      await phone.locator('iframe[src^="https://count.beejz.com/"]').evaluateAll((frames,notice)=>frames.forEach(frame=>{if(!frame.previousElementSibling?.hasAttribute('data-qa-document-note')){const note=document.createElement('p');note.dataset.qaDocumentNote='true';note.textContent=notice;note.style.cssText='font-size:12px;color:#777;padding:8px;overflow-wrap:anywhere';frame.before(note);}}),qaDocumentNotice);
      const fullStyle = await page.addStyleTag({ content: '#bee-immersive-suite .bc-phone:not([data-modal="true"]) .bc-main:has(.s80-shell){height:auto!important;display:block!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .s80-shell{height:auto;display:block}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .s80-scroll{overflow:visible} #bee-immersive-suite .bc-phone:not([data-modal="true"]) .bc-main:has(.a79-shell){height:auto!important;display:block!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .a79-shell{height:auto;display:block}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .a79-scroll{overflow:visible} #bee-immersive-suite .bc-phone[data-page="home"] .bc-main{height:auto!important;display:block!important}#bee-immersive-suite .bc-phone[data-page="home"] .bc-stream{height:auto!important;display:block!important}#bee-immersive-suite .bc-phone[data-page="home"] .h-journal-list{height:auto!important;overflow:visible!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]){height:auto!important;max-height:none!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .bc-main{max-height:none!important;overflow:visible!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .bc-main:has(.ae-shell){height:auto!important;display:block!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .ae-shell{display:block}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .ae-scroll{overflow:visible}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .bc-main:has(.cm-manager-page){height:auto!important;display:block!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .cm-manager-page{display:block}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .cm-manager-scroll{overflow:visible}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .bc-main:has(.av-shell){height:auto!important;display:block!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .av-shell{display:block}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .av-scroll{overflow:visible}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .bc-main:has(.tl-shell){height:auto!important;display:block!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .tl-shell{display:block}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .tl-scroll{overflow:visible}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .bc-main:has(.fs-shell){height:auto!important;max-height:none!important;display:block!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .fs-shell{display:block}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .fs-scroll{overflow:visible}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .bc-main:has(.nw-scroll){height:auto!important;max-height:none!important;display:block!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .nw-scroll{overflow:visible}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .bc-main:has(.rd-scroll){height:auto!important;max-height:none!important;display:block!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .rd-scroll{overflow:visible}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .bc-main:has(.ap-scroll){height:auto!important;max-height:none!important;display:block!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .ap-scroll{overflow:visible}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .bc-main:has(.bgt-shell){height:auto!important;display:block!important}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .bgt-shell{height:auto;display:block}#bee-immersive-suite .bc-phone:not([data-modal="true"]) .bgt-scroll{overflow:visible}' });
      // Expand long provider forms only for the 'full content' design export.
      // The viewport snapshot below retains the actual scrolling dialog.
      const providerFull = await page.locator('.a82-editor').count() ? await page.addStyleTag({content: '#bee-immersive-suite #bee-immersive-phone.bc-phone[data-modal="true"]{height:auto!important;min-height:844px!important;max-height:none!important;padding-bottom:22px!important}#bee-immersive-suite #bee-immersive-phone.bc-phone[data-modal="true"]>.bc-main{display:none!important}#bee-immersive-suite #bee-immersive-phone .r-modal-layer:has(.a82-editor){position:relative!important;inset:auto!important;width:100%!important;min-height:0!important}#bee-immersive-suite #bee-immersive-phone .r-modal-layer:has(.a82-editor) .bc-sheet{max-height:none!important;overflow:visible!important}#bee-immersive-suite #bee-immersive-phone .a82-editor{overflow:visible!important;flex:none!important}'}) : null;
      const bounds = await phone.boundingBox();
      await phone.screenshot({ path: path.join(root, 'screens/full', slug + '.png') });
      if (providerFull) await providerFull.evaluate(e => e.remove());
      await fullStyle.evaluate(e => e.remove());
      const viewportHeight = Number(viewport.height) || 844;
      const viewportWidth = Number(viewport.width) || 398;
      const viewportStyle = await page.addStyleTag({ content: `#bee-immersive-suite .bc-phone{height:${viewportHeight}px!important;min-height:${viewportHeight}px!important;max-height:${viewportHeight}px!important;overflow:hidden!important}` });
      await phone.screenshot({ path: path.join(root, 'screens/viewport', slug + '.png') });
      const vector = await phone.evaluate(toSvg);
      fs.writeFileSync(path.join(root, 'figma', slug + '.svg'), vector.svg);
      await presets.capture(page, slug);
      const dom = await phone.evaluate(snapshotDom);
      const restore = '<script>for(const e of document.querySelectorAll("[data-snapshot-scroll]"))e.scrollTop=Number(e.dataset.snapshotScroll);</script>';
      const head = '<meta charset="utf-8"><style>' + css + `</style><style>*{box-sizing:border-box}body{margin:0;background:#eceeef;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}#bee-immersive-suite{width:${viewportWidth}px}.bc-phone{height:${viewportHeight}px!important;min-height:${viewportHeight}px!important;max-height:${viewportHeight}px!important;overflow:hidden!important}</style>`;
      fs.writeFileSync(path.join(root, 'figma/html', slug + '.html'), '<!doctype html><html lang="zh-CN">' + head + '<div id="bee-immersive-suite">' + dom + '</div>' + restore + '</html>');
      upsert(snapshots, { slug, title: target.title, group: target.group, dom });
      await viewportStyle.evaluate(e => e.remove());
      upsert(manifest, { ...target, slug, fullHeight: Math.round(bounds.height), viewport: 'screens/viewport/' + slug + '.png', full: 'screens/full/' + slug + '.png', svg: 'figma/' + slug + '.svg' });
      console.log(JSON.stringify({ refreshedScene: slug, route, viewport }));
    }
    if (errors.length) throw Error(errors.join('\n'));
    presets.save();
    fs.writeFileSync(domFile, JSON.stringify(snapshots));
    fs.writeFileSync(path.join(root, 'screens/manifest.json'), JSON.stringify(manifest, null, 2));
    // Source worktrees can refresh only selected resources without rebuilding unrelated boards.
    const boards = process.env.BEE_DESIGN_SKIP_PAGE_BOARDS === '1' ? [] : await require('./build-page-boards.cjs')(root, browser, manifest);
    require('./build-index.cjs');
    fs.writeFileSync(path.join(root, 'qa/selected-export-report.json'), JSON.stringify({ refreshed: routes, retainedOtherScenes: manifest.length - routes.length, total: manifest.length, boards, errors, qaDocumentResponses, qaExternalBlocked, websiteContentAndNativeWebView: 'NOT_RUN' }, null, 2));
    console.log(JSON.stringify({ refreshed: routes.length, scenes: manifest.length, errors, qaDocumentResponseCount:qaDocumentResponses.length, externalBlocked:qaExternalBlocked.length, websiteContentAndNativeWebView:'NOT_RUN' }));
  } finally {
    await browser.close();
  }
})().catch(e => { console.error(e); process.exitCode = 1; });
