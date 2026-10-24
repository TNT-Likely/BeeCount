const fs=require('fs'),path=require('path'),{chromium}=require('playwright'),root=path.resolve(__dirname,'..');
(async()=>{const b=await chromium.launch({channel:'chrome',headless:true}),p=await b.newPage({viewport:{width:900,height:1200}}),checks=[],errors=[];p.on('pageerror',e=>errors.push(e.message));try{
for(const [size,scale,mode] of [['398x844',1,'light'],['320x568',1.4,'dark']]){
 await p.goto('file://'+path.join(root,'prototype/demo.html')+`?page=flow-quick-add&viewport=${size}&scale=${scale}`);await p.waitForFunction(()=>window.beeImmersiveDemo);await p.locator('#bee-skin-mode').selectOption(mode);
 const geometry=await p.locator('.j-quick-dialog').evaluate(e=>{const close=e.querySelector('.j-quick-close').getBoundingClientRect(),origin={x:close.x+close.width/2,y:close.y+close.height/2};return {close:{width:close.width,height:close.height},actions:[...e.querySelectorAll('.j-quick-action')].map(a=>{const r=a.querySelector('span').getBoundingClientRect();return {method:a.dataset.jMethod,width:r.width,height:r.height,dx:r.x+r.width/2-origin.x,dy:r.y+r.height/2-origin.y};})};});
 if(geometry.actions.length!==3||geometry.actions.some(x=>x.width!==54||x.height!==54))throw Error('Design fan sizes changed');
 checks.push({size,scale,mode,...geometry});
}
if(errors.length)throw Error(errors.join('\n'));
const contract={source:'docs/design/card-refresh/prototype/demo.html?page=flow-quick-add',reference:'existing HTML fan, measured independently of Flutter',...checks[0]};
fs.writeFileSync(path.resolve(root,'../../../test/fixtures/v4-quick-add-design-geometry.json'),JSON.stringify(contract,null,2)+'\n');
fs.writeFileSync(path.join(root,'qa/home-fan-checks.json'),JSON.stringify({checks,errors},null,2));console.log(JSON.stringify({checks,errors}));
}finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
