// Local, fixed-data prototype checks. No device, App database or Cloud requests.
const fs=require('fs'),path=require('path'),os=require('os'),crypto=require('crypto');
const assert=require('assert/strict'),{pathToFileURL}=require('url');
const {chromium}=require('playwright');
const cases=require('./transaction-row-consumer-cases.json');
const incremental=process.env.BEECOUNT_CONSUMER_NEW_STATUS_ONLY==='1';
const root=path.resolve(__dirname,'../..');
const base=process.env.BEECOUNT_DESIGN_BASE||pathToFileURL(root).href;
const out=process.env.BEECOUNT_TRANSACTION_CONSUMER_QA_DIR||fs.mkdtempSync(path.join(os.tmpdir(),'beecount-c3-consumers-'));
const sha=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');

function audit(row){
  const r=BeeTransactionRows.record(row),issues=[],b=row.getBoundingClientRect();
  const lines=[...row.querySelectorAll('.line-slot')].filter(e=>e.children.length);
  if(lines.length>3)issues.push('fourth-line');
  if(b.height>170)issues.push('stretched-row');
  if(getComputedStyle(row).overflowY==='hidden')issues.push('vertical-clipping');
  for(const line of lines){
    const lb=line.getBoundingClientRect();
    const children=[...line.children].map(e=>({e,b:e.getBoundingClientRect()})).sort((a,b)=>a.b.left-b.b.left);
    if(getComputedStyle(line).flexWrap!=='nowrap')issues.push('wrapping-line');
    for(let i=0;i<children.length;i++){
      const c=children[i];
      if(c.b.left<lb.left-.8||c.b.right>lb.right+.8)issues.push('outside-slot:'+c.e.className);
      if(i&&children[i-1].b.right>c.b.left+.8)issues.push('overlap:'+c.e.className);
    }
  }
  for(let i=1;i<lines.length;i++)if(lines[i-1].getBoundingClientRect().bottom>lines[i].getBoundingClientRect().top+.8)issues.push('vertical-overlap');
  for(const selector of ['.amount','.converted','.status-label','.timestamp']){
    for(const e of row.querySelectorAll(selector)){
      const eb=e.getBoundingClientRect(),range=document.createRange();range.selectNodeContents(e);
      const text=range.getBoundingClientRect();
      if(eb.left<b.left-.8||eb.right>b.right+.8||text.left<eb.left-.8||text.right>eb.right+.8)issues.push('clipped-text:'+selector);
    }
  }
  if(row.querySelector('.amount').textContent!==(r.hidden?'••••':r.amount))issues.push('changed-amount');
  if(r.converted&&row.querySelector('.converted')?.textContent!==(r.hidden?'••••':r.converted))issues.push('changed-snapshot');
  if(r.ledgerName&&!row.querySelector('.ledger-chip'))issues.push('ledger-is-not-chip');
  if((r.status||[]).some(s=>![...row.querySelectorAll('.status-label')].some(e=>e.textContent===s)))issues.push('literal-flag-missing');
  for(const pill of row.querySelectorAll('.tag,.ledger-chip')){const font=parseFloat(getComputedStyle(pill).fontSize),scale=parseFloat(getComputedStyle(row).getPropertyValue('--type-scale'));if(pill.getBoundingClientRect().height>font*1.2+5||Math.abs(font-10*scale)>.2)issues.push('enlarged-inline-chip');}
  if(row.querySelector('.primary').getBoundingClientRect().width<25)issues.push('unreadable-description');
  if(r._rawNote&&row.querySelector('.account-text')?.textContent===r.categoryLabel)issues.push('category-repeated-below-note');
  return {id:row.closest('[data-source-id]')?.dataset.sourceId||r._hostId,width:b.width,lines:lines.length,issues};
}

(async()=>{
  fs.mkdirSync(out,{recursive:true});
  const browser=await chromium.launch({headless:true,channel:'chrome'});
  const page=await browser.newPage({viewport:{width:1440,height:1000}});
  const errors=[],layouts=[],checks=[];
  page.on('pageerror',e=>errors.push(String(e)));
  async function open(route,width=320,scale=1.4,dark=false){
    await page.goto(base+'/prototype/demo.html?page='+route+'&viewport='+width+'x'+(width===320?568:844)+'&scale='+scale);
    await page.selectOption('#bee-skin-mode',dark?'dark':'light');
    await page.evaluate(()=>BeeTransactionRows.hydrate(document));
  }
  async function verify(test,width=320,scale=1.4,dark=false){
    await open(test.route,width,scale,dark);
    const actual=await page.evaluate(()=>{
      const rows=[...document.querySelectorAll('.tx3')];
      return {old:document.querySelectorAll('.ad-transaction,.td-row,.cl-transaction,.dc97-row').length,
        ids:rows.map(e=>Number(e.closest('[data-source-id]')?.dataset.sourceId||BeeTransactionRows.record(e)._hostId)),
        amounts:rows.map(e=>e.querySelector('.amount').textContent),
        dc:document.querySelector('.dc97-detail')?beeDetailCurrencyPreview.data:null,
        summary:document.querySelector('.dc97-amount')?.textContent||document.querySelector('.d-amount')?.textContent};
    });
    assert.equal(actual.old,0,test.route+': old duplicate row template');
    assert.deepEqual(test.consumer==='calendar'?actual.ids.sort((a,b)=>a-b):actual.ids,test.ids,test.route+': original record identities');
    if(test.dataSha256)assert.equal(sha(actual.dc),test.dataSha256,test.route+': original projection inputs');
    if(test.summary!==undefined)assert.equal(actual.summary,test.summary,test.route+': unchanged total');
    if(test.amounts)assert.deepEqual(actual.amounts,test.amounts,test.route+': original displayed amounts');
    const geometry=await page.locator('.tx3').evaluateAll((rows,src)=>rows.map(row=>new Function('return ('+src+')(arguments[0])')(row)),audit.toString());
    const failed=geometry.filter(g=>g.issues.length);
    if(failed.length)fs.writeFileSync(path.join(out,'geometry-failure.json'),JSON.stringify({route:test.route,width,scale,dark,failed},null,2));
    assert.deepEqual(failed,[],test.route+' '+width+' '+scale+' '+dark);
    layouts.push({route:test.route,width,scale,dark,rows:geometry.length,two:geometry.filter(g=>g.lines===2).length,three:geometry.filter(g=>g.lines===3).length});
  }
  async function noteValue(){if(!await page.locator('[data-z-note]').count())await page.locator('[data-action="z-note-toggle"]').click();return page.locator('[data-z-note]').inputValue();}
  async function check(name,run){await run();checks.push(name);console.log('interaction passed: '+name);}
  try{
    // Only the newly adapted routes; the prior C3 44-context evidence stays frozen.
    for(const test of (incremental?cases.filter(c=>c.additionalNoRowScene):cases))for(const dark of [false,true])await verify(test,320,1.4,dark);
    if(!incremental)for(const route of ['flow-account-credit-detail','flow-detail-currency-tag-all','calendar'])for(const dark of [false,true])await verify(cases.find(c=>c.route===route),398,1,dark);
    await check('account income/outgoing filters keep original identities and signed transfer',async()=>{
      await open('flow-account-credit-detail');
      for(const [flow,ids]of [['income',[9002]],['expense',[9001,9003]],['all',[9001,9002,9003]]]){
        await page.locator('[data-action="ad-flow:'+flow+'"]').click();
        assert.deepEqual(await page.locator('[data-c3-consumer="ad"]').evaluateAll(es=>es.map(e=>Number(e.dataset.sourceId))),ids);
      }
      assert.equal(await page.locator('[data-source-id="9002"] .amount').textContent(),'+¥500.00');
      assert.equal(await page.locator('[data-source-id="9002"] .category-target [data-lucide="arrow-left-right"],[data-source-id="9002"] .category-target .lucide-arrow-left-right').count(),1);
      await page.locator('[data-source-id="9001"] .primary').click();
      assert.match(await page.locator('#bee-immersive-phone').innerText(),/示例账单：生产页面直接进入原编辑流程/);
      await page.locator('[data-source-id="9001"] [data-c3-action="category"]').click();
      assert.equal(await page.locator('.dc97-detail[data-dc97-kind="category"]').count(),1);
      assert.equal(await page.locator('[data-z-note]').count(),0);
    });
    await check('actual account row still edits the original transaction',async()=>{
      await open('accountDetail');await page.locator('[data-c3-consumer="ad"][data-source-id="1"] .primary').click();
      assert.equal(await noteValue(),'午间食堂');
      assert.equal(await page.locator('[data-p-field="expression"]').inputValue(),'32');
    });
    await check('calendar additions use their original day, note and amount',async()=>{
      await open('calendar');const original=await page.locator('.tx3').count();
      await page.locator('[data-action="cl-day:19"]').click();assert.equal(await page.locator('[data-c3-consumer="cl"]').count(),0);
      await page.locator('[data-action="cl-day:20"]').click();assert.equal(await page.locator('.tx3').count(),original);
      await page.locator('[data-source-id="74003"] .primary').click();
      assert.equal(await noteValue(),'美元午餐');
      assert.equal(await page.locator('[data-p-field="expression"]').inputValue(),'12');
    });
    await check('calendar error retry and unselected date reach the same original mixed records',async()=>{
      await open('flow-calendar-error');assert.equal(await page.locator('.tx3').count(),0);
      await page.locator('[data-action="cl-retry"]').click();
      const ids=await page.locator('.tx3').evaluateAll(es=>es.map(e=>Number(e.closest('[data-source-id]')?.dataset.sourceId||BeeTransactionRows.record(e)._hostId)).sort((a,b)=>a-b));
      assert.deepEqual(ids,cases.find(c=>c.route==='calendar').ids);
      await open('flow-calendar-unselected');assert.equal(await page.locator('.tx3').count(),0);
      await page.locator('[data-action="cl-day:20"]').click();assert.equal(await page.locator('.tx3').count(),7);
    });
    await check('assets USD account entry preserves its original foreign row and historical snapshot',async()=>{
      await open('assets',398,1);await page.locator('[data-action="av-account:usd"]').click();
      assert.equal(await page.locator('[data-c3-consumer="ad"]').count(),1);
      const row=page.locator('[data-c3-consumer="ad"][data-source-id="2"]');
      assert.equal(await row.locator('.amount').textContent(),'−US$12.00');
      assert.equal(await row.locator('.converted').textContent(),'≈ ¥85.20');
      await row.locator('.primary').click();assert.equal(await noteValue(),'一杯拿铁');
    });
    await check('cross-book rows preserve original EUR and source-book USD snapshot after target change',async()=>{
      await open('flow-detail-currency-tag-all');const records=await page.evaluate(()=>beeDetailCurrencyPreview.data.rows);
      const row=page.locator('[data-source-id="9702"]');
      assert.equal(await row.locator('.amount').textContent(),'−€16.00');
      assert.equal(await row.locator('.converted').textContent(),'≈ US$20.00');
      await page.evaluate(()=>beeDetailCurrencyPreview.setTarget(2));
      assert.equal(await row.locator('.converted').textContent(),'≈ US$20.00');
      await row.locator('.ledger-chip').click();const sheet=page.locator('.bc-sheet');
      for(const value of ['−€16.00','≈ US$20.00','美元旅行','欧元卡','原币 EUR，美元账本快照'])assert((await sheet.innerText()).includes(value),value);
      await sheet.locator('[data-action="close"]').click();
      assert.deepEqual(await page.evaluate(()=>beeDetailCurrencyPreview.data.rows),records);
    });
    await check('current USD book full fields use the source ledger even when its chip is implicit',async()=>{
      await open('flow-detail-currency-tag-current');await page.evaluate(()=>beeDetailCurrencyPreview.setTarget(2));
      const row=page.locator('[data-source-id="9702"]');assert.equal(await row.locator('.ledger-chip').count(),0);
      await row.locator('.account-token').click();const text=await page.locator('.bc-sheet').innerText();
      assert(text.includes('美元旅行'));assert(text.includes('餐饮 / 咖啡'));assert(text.includes('≈ US$20.00'));
      await page.locator('.bc-sheet [data-action="close"]').click();
    });
    await check('literal flags and ledger chips retain complete fields, hold menu and direct edit',async()=>{
      await open('flow-detail-currency-tag-all');const row=page.locator('[data-source-id="9703"]');
      assert.equal(await row.locator('.status-label').allTextContents().then(a=>a.join(' · ')),'不计收支 · 不计预算');
      await row.locator('.fields-more').click();assert.match(await page.locator('.bc-sheet').innerText(),/旅行/);
      await page.locator('.bc-sheet [data-action="close"]').click();
      await row.locator('.primary').scrollIntoViewIfNeeded();const bounds=await row.locator('.primary').boundingBox();await page.mouse.move(bounds.x+bounds.width/2,bounds.y+bounds.height/2);await page.mouse.down();await page.waitForTimeout(550);await page.mouse.up();assert.equal(await page.locator('[data-action^="c3-consumer-fields:"]').count(),1);
      await page.locator('[data-action^="c3-consumer-fields:"]').click();assert.match(await page.locator('.bc-sheet').innerText(),/原快照不随今日汇率改写/);
      await page.locator('.bc-sheet [data-action="close"]').click();
      await row.locator('.primary').click();assert.equal(await noteValue(),'原快照不随今日汇率改写');
    });
    await check('category icon and original sort / period controls still filter source records',async()=>{
      await open('flow-detail-currency-category-all');const original=await page.evaluate(()=>beeDetailCurrencyPreview.data.rows);
      await page.locator('[data-dc97="sort:amountDesc"]').click();
      const amounts=await page.locator('.tx3').evaluateAll(es=>es.map(e=>Number(BeeTransactionRows.record(e).amount.replace(/[^\d.]/g,''))));
      assert.deepEqual(amounts,[...amounts].sort((a,b)=>b-a));
      await page.locator('[data-dc97="period:month"]').click();assert.equal(await page.locator('.tx3').count(),3);
      await page.locator('[data-source-id="9702"] [data-c3-action="category"]').click();
      assert.match(await page.locator('.dc97-identity').innerText(),/咖啡/);
      assert.deepEqual(await page.evaluate(()=>beeDetailCurrencyPreview.data.rows),original);
    });
    await check('original fallback tag renderer shares C3 too',async()=>{
      await open('tagDetail');await page.evaluate(()=>beeDetailCurrencyPreview.restore());
      await page.selectOption('#bee-immersive-pages','flow-tag-foreign-detail');
      assert.equal(await page.locator('[data-c3-consumer="td"]').count(),6);
      assert.equal(await page.locator('.td-row').count(),0);
      await page.locator('[data-source-id="9201"] .primary').click();
      assert.equal(await noteValue(),'一杯拿铁');
    });
    await check('privacy stays masked in rows and the full-field viewer',async()=>{
      await open('flow-detail-currency-tag-privacy');const row=page.locator('[data-source-id="9702"]');
      assert.equal(await row.locator('.amount').textContent(),'••••');assert.equal(await row.locator('.converted').textContent(),'••••');
      await row.locator('.ledger-chip').click();const text=await page.locator('.bc-sheet').innerText();
      assert(!text.includes('16.00')&&!text.includes('20.00'));await page.locator('.bc-sheet [data-action="close"]').click();
    });
    await check('C3 main row edit remains available after consumer routing changes',async()=>{
      await open('home');await page.locator('[data-key="c3-main-2"] .primary').click();
      assert.equal(await noteValue(),'一杯拿铁');
    });
    for(const [route,file]of [['flow-account-credit-detail','account'],['flow-detail-currency-tag-all','tag-all'],['calendar','calendar']]){
      await open(route,320,1.4,false);await page.locator('.tx3').first().scrollIntoViewIfNeeded();
      await page.locator('#bee-immersive-phone').screenshot({path:path.join(out,file+'-320-140-light.png')});
      await page.locator('.tx3').first().screenshot({path:path.join(out,file+'-row-320-140-light.png')});
    }
    await open('flow-detail-currency-tag-all',320,1.4,true);
    await page.locator('[data-source-id="9703"]').screenshot({path:path.join(out,'tag-flags-row-320-140-dark.png')});
    assert.deepEqual(errors,[]);
    fs.writeFileSync(path.join(out,incremental?'consumer-status-incremental.json':'consumer-results.json'),JSON.stringify({scope:'fixed local HTML only',incrementalNewStatusOnly:incremental,baseline:'607bb5b2',routes:cases.length,layouts,checks,errors,presetCorrections:cases.filter(c=>c.presetCorrection)},null,2));
    console.log(JSON.stringify({out,routes:cases.length,layouts:layouts.length,checks:checks.length,errors}));
  }finally{await browser.close();}
})().catch(e=>{fs.writeFileSync(path.join(out,'failure-'+Date.now()+'.log'),String(e.stack));console.error(e);process.exitCode=1;});
