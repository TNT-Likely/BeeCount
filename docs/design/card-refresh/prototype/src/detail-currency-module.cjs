const fs=require('fs'),path=require('path'),fixtures=require('./detail-currency-samples.cjs');
const arb=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../../../../../lib/l10n/app_zh.arb'),'utf8'));
const keys=['v4DetailConvertedScope','v4DetailMissingConversion','v4DetailRateDate','v4DetailRatesStale'];
for(const key of keys)if(!Object.hasOwn(arb,key))throw Error('Missing detail currency text '+key);
const texts=Object.fromEntries(keys.map(key=>[key,arb[key]]));
module.exports={
 css:fs.readFileSync(path.join(__dirname,'detail-currency.css'),'utf8'),
 javascript:fs.readFileSync(path.join(__dirname,'detail-currency.js'),'utf8').replace('__DETAIL_CURRENCY_TEXTS__',()=>JSON.stringify(texts)).replace('__DETAIL_CURRENCY_FIXTURES__',()=>JSON.stringify(fixtures)),
 sample:fixtures.guide,
 pureSample:fixtures.componentGuide,
 scenes:[...fixtures.scenes.map(scene=>'flow-'+scene.key),'flow-detail-currency-component'],
};
