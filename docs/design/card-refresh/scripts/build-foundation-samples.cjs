const fs=require('fs'),path=require('path'),root=path.resolve(__dirname,'..');
const samples=JSON.parse(fs.readFileSync(path.join(root,'components/samples.json'),'utf8'));Object.assign(samples,require('../prototype/src/foundation-samples.cjs'));samples.executionDepth=require('../prototype/src/execution-depth-samples.cjs');samples.aiPrompt=require('../prototype/src/ai-prompt-samples.cjs');samples.attachmentLibrary=require('../prototype/src/attachment-library-samples.cjs').sample;fs.writeFileSync(path.join(root,'components/samples.json'),JSON.stringify(samples,null,2));
const css=[...fs.readFileSync(path.join(root,'prototype/source.fragment.html'),'utf8').matchAll(/<style>([\s\S]*?)<\/style>/g)].map(m=>m[1]).join('\n');fs.writeFileSync(path.join(root,'components/product.css'),css);

samples.recurringBills=require('../prototype/src/recurring-bills-samples.cjs');fs.writeFileSync(path.join(root,'components/samples.json'),JSON.stringify(samples,null,2));

Object.assign(samples,require('../prototype/src/migrated-page-modules.cjs').samples);fs.writeFileSync(path.join(root,'components/samples.json'),JSON.stringify(samples,null,2));

// Every registered feature contributes both pure states and its page links.
for(const key of ['transactionDetail','cloudBackup','autoBilling','detailCurrency','cloudShared','shareCard','aiAdvanced','support','maintenance'])if(!samples[key])throw Error('Missing integrated feature sample '+key);

// The approved profile A samples come from their source, not captured old avatars.
Object.assign(samples,require('../prototype/src/profile-samples.cjs'));fs.writeFileSync(path.join(root,'components/samples.json'),JSON.stringify(samples,null,2));
