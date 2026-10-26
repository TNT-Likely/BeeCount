const assert=require('assert'),path=require('path'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const base=pathToFileURL(path.resolve(__dirname,'../prototype/demo.html')).href;
(async()=>{const b=await chromium.launch({channel:'chrome'});try{const p=await b.newPage({viewport:{width:900,height:1500}}),errors=[],profiles=[];p.on('pageerror',e=>errors.push(e.message));
for(const[size,scale,mode]of [['398x844','1','light'],['320x568','1.4','dark']]){
 for(const scene of ['report','flow-analytics-income','flow-analytics-balance','flow-analytics-year','flow-analytics-all','flow-analytics-empty','flow-analytics-loading','flow-analytics-error','flow-analytics-pie','flow-analytics-foreign']){
 await p.goto(base+'?page='+scene+'&viewport='+size);await p.waitForFunction(()=>window.beeImmersiveDemo);await p.evaluate(mode=>{window.beeImmersiveDemo.settings.appearance=mode;window.beeImmersiveDemo.render()},mode);await p.locator('#bee-preview-scale').selectOption(scale);const phone=p.locator('#bee-immersive-phone'),shell=phone.locator('.a79-shell');assert.equal(await shell.count(),1,scene);
 if(scene.endsWith('loading'))assert.equal(await shell.locator('[role=status]').count(),1);
 else if(scene.endsWith('error')){await shell.locator('[data-action=a79-retry]').click();assert.equal(await shell.locator('.a79-summary').count(),1);}
 else if(!scene.endsWith('empty')){assert.equal(await shell.locator('.a79-summary').count(),1);assert.equal(await shell.locator('.a79-trend').count(),1);if(scene.endsWith('balance'))assert.equal(await shell.getByText('分类排行',{exact:true}).count(),0);}
 const overflow=await shell.evaluate(e=>e.scrollWidth>e.clientWidth+1);assert(!overflow,scene+' horizontal overflow');profiles.push({scene,size,scale,mode});
 }
}
await p.goto(base+'?page=report&viewport=398x844');await p.locator('[data-action=a79-view]').click();await p.locator('[data-action="a79-type:balance"]').click();assert.equal(await p.locator('.a79-total').innerText(),'¥8,713.5');await p.locator('[data-action="a79-scope:all"]').click();assert(await p.locator('[data-action=a79-period]').isDisabled());
await p.goto(base+'?page=flow-analytics-foreign');await p.locator('[data-action=a79-recalc]').click();assert.equal(await p.locator('[role=dialog]').count(),1);await p.locator('[role=dialog] [data-action=r-close]').click();assert.equal(await p.locator('.a79-summary').count(),1);
await p.goto(base+'?page=report&viewport=398x844');await p.addStyleTag({content:'#bee-immersive-phone{border:0!important}'});const g=await p.locator('.a79-summary').evaluate(e=>{const c=getComputedStyle(e),v=e.querySelector('.a79-total');return{width:e.clientWidth,padding:parseFloat(c.paddingLeft),font:parseFloat(getComputedStyle(v).fontSize),selector:e.querySelector('button').clientHeight}});assert.equal(g.width,364);assert.equal(g.padding,18);assert.equal(g.font,34);assert.equal(g.selector,48);assert.deepEqual(errors,[]);await p.locator('#bee-immersive-phone').screenshot({path:'/tmp/beecount-v4-analytics-r79-html.png'});console.log(JSON.stringify({profiles:profiles.length,geometry:g,errors}));
}finally{await b.close();}})().catch(e=>{console.error(e);process.exit(1)});
