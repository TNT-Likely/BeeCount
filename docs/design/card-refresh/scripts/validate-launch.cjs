const path=require('path'),assert=require('node:assert/strict'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
(async()=>{
  const browser=await chromium.launch({channel:'chrome',headless:true});
  const errors=[];
  try {
    for(const [width,height,scale,mode] of [[398,844,1,'light'],[320,568,1.4,'dark']]) {
      const page=await browser.newPage({viewport:{width:1280,height:1200}});
      page.on('pageerror',error=>errors.push(error.message));
      await page.goto(pathToFileURL(path.resolve(__dirname,'../prototype/demo.html')).href+`?page=flow-splash&viewport=${width}x${height}&scale=${scale}`);
      await page.locator('#bee-skin-mode').selectOption(mode);
      const phone=page.locator('.bc-phone');
      assert.equal(await phone.locator('.bc-subhead').count(),0);
      assert.equal(await phone.locator('.bc-main button').count(),0);
      assert.equal(await phone.locator('.l-launch').getAttribute('aria-busy'),'true');
      for(const text of ['蜜蜂记账','一笔一蜜','开源数据安全','数据本地存储，隐私完全自控','开源代码透明，安全值得信赖','可选云端同步，多设备数据一致','正在初始化数据...'])assert.match(await phone.textContent(),new RegExp(text));
      assert.equal(await phone.locator('.l-brand').evaluate(el=>el.getBoundingClientRect().width),76);
      assert.equal(await phone.locator('.l-brand svg').evaluate(el=>el.getBoundingClientRect().width),48);
      assert.equal(await phone.locator('.l-spinner').evaluate(el=>el.offsetWidth),22);
      assert.equal(await phone.evaluate(el=>el.scrollWidth>el.clientWidth),false);
      await phone.locator('.l-status').scrollIntoViewIfNeeded();
      assert.equal(await phone.locator('.l-status').isVisible(),true);
      await phone.screenshot({path:`/tmp/beecount-v4-launch-${width}.png`});
      await page.close();
    }
    assert.deepEqual(errors,[]);
    console.log(JSON.stringify({status:'PASS',viewports:2,originalSecurityFeatures:3,automaticInitializationStatus:true,noInventedNavigation:true,brand:76,artwork:48,spinner:22}));
  } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1});
