const fs = require('fs');
const path = require('path');
const arb = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../../../../lib/l10n/app_zh.arb'), 'utf8'));
const read = name => fs.readFileSync(path.join(__dirname, name), 'utf8');
function localized(name, token, includes) {
  const texts = Object.fromEntries(Object.entries(arb).filter(([key]) => !key.startsWith('@') && includes(key)));
  return read(name + '.js').replace(token, () => JSON.stringify(texts));
}
const transfer = require('./transfer-inline-samples.cjs');
const transferJs = read('transfer-inline.js').replace('__TRANSFER_INLINE_TEXTS__', () => JSON.stringify(arb)).replace('__TRANSFER_INLINE_FIXTURES__', () => JSON.stringify(transfer));
const exported = require('./transaction-export-module.cjs');
const recurring = require('./recurring-editor-module.cjs');
const detail = require('./transaction-detail-module.cjs');
const shareCard = require('./share-card-module.cjs');
const autoBilling = require('./auto-billing-module.cjs');
const detailCurrency = require('./detail-currency-module.cjs');
const support = require('./p2-support-module.cjs');
const advanced = localized('ai-advanced', '__AI_ADVANCED_TEXTS__', () => true);
const maintenance = localized('maintenance', '__MAINTENANCE_TEXTS__', () => true);

const p2EntryAliases = `
  // Existing entry routes keep their URLs and use the same frozen feature body.
  const p2EntryBefore=fRender;
  fRender=function(key){const aliases={memory:'advanced-memory',permissions:'advanced-permissions',activity:'advanced-activity',logs:'maintenance-logs','log-detail':'maintenance-log-detail',storage:state.nPlatform==='ios'?'maintenance-storage-ios':'maintenance-storage',orphan:'maintenance-orphans',widgets:state.nPlatform==='ios'?'maintenance-widgets-ios':'maintenance-widgets-android'};return p2EntryBefore(aliases[key]||key);};
`;

const backup = localized('cloud-backup', '__CLOUD_BACKUP_TEXTS__', () => true);
const shared = localized('cloud-shared', '__CLOUD_SHARED_TEXTS__', () => true);
// Render the same pure sample functions without mounting App/native actions.
const vm = require('vm');
const escapeSample = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const sampleContext = javascript => {const context=vm.createContext({state:{hide:false},settings:{},esc:escapeSample,icon:name=>'<i data-lucide="'+name+'"></i>'});vm.runInContext(javascript,context);return context;};
const autoContext=sampleContext(autoBilling.javascript);
const autoStates=vm.runInContext("ab92Use('auto-billing-ios-old');ab92Data.expanded=true;ab92Render(false)+ab92Use('auto-billing-android')",autoContext);
const currencyContext=sampleContext(detailCurrency.javascript);
const currencyStates=['complete','missing','stale'].map(status=>{currencyContext.status=status;return vm.runInContext("dc97ComponentState.status=status;dc97ComponentState.privacy=status==='stale';dc97Component()",currencyContext);}).join('');

const annual = localized('annual-report', '__ANNUAL_REPORT_TEXTS__', key =>
  /^(annualReport|sharePoster|transactionReceipt)/.test(key) || ['commonError', 'commonClose', 'helpCenterRetry', 'homeExpense', 'importFieldCategory', 'importFieldDate', 'importFieldNote', 'importFieldAccount', 'analyticsIncome', 'analyticsExpense'].includes(key));
const imported = localized('transaction-import', '__TRANSACTION_IMPORT_TEXTS__', key =>
  /^(import|exportCsvHeader)/.test(key) || ['categoryExpense', 'categoryIncome', 'commonCancel', 'commonConfirm', 'commonError'].includes(key));
const cloud = localized('cloud-configuration', '__CLOUD_CONFIGURATION_TEXTS__', key =>
  /^(cloud|auth|webdavConfigured|common)/.test(key) || key === 'mineCloudService');
module.exports = {
  javascript: [imported, exported.javascript, recurring.javascript, annual, read('receipt.js'), cloud, transferJs, detail.javascript, backup, autoBilling.javascript, detailCurrency.javascript, shared, shareCard.javascript, advanced, support.javascript, maintenance, p2EntryAliases, 'fDefine("auto-billing",'+JSON.stringify(arb.autoScreenshotBillingTitle)+',"自动化与识别","automation/auto_billing_settings_page.dart",()=>ab92Use(state.nPlatform==="ios"?"auto-billing-ios":"auto-billing-android"));'].join('\n'),
  css: ['transaction-import', 'transaction-export', 'recurring-editor', 'annual-report', 'receipt', 'cloud-configuration', 'transfer-inline'].map(name => read(name + '.css')).concat([detail.css, read('cloud-backup.css'), autoBilling.css, detailCurrency.css, read('cloud-shared.css'), shareCard.css, read('ai-advanced.css'), support.css, read('maintenance.css')]).join('\n'),
  samples: {
    transferInline: transfer.guide,
    transactionDetail: detail.sample,
    shareCard: shareCard.sample,
    aiAdvanced: require('./ai-advanced-samples.cjs'),
    support: support.sample,
    maintenance: require('./maintenance-samples.cjs'),
    cloudBackup: require('./cloud-backup-samples.cjs'),
    autoBilling: '<div class="ab92-integrated-sample"><p data-ab92-demo-event class="bc-small">受控示例，不请求权限或打开外部应用</p>'+autoStates+autoBilling.sample+'</div>',
    detailCurrency: '<div class="dc97-integrated-sample"><p data-dc97-demo-event class="bc-small">完整 / 缺失 / 陈旧与隐私，全部状态平铺</p>'+currencyStates+detailCurrency.sample+'</div>',
    cloudShared: require('./cloud-shared-samples.cjs'),
    transactionImport: require('./transaction-import-samples.cjs'),
    transactionExport: exported.sample,
    recurringEditor: recurring.sample,
    annualReport: require('./annual-report-samples.cjs'),
    receiptOptions: require('./receipt-samples.cjs'),
    cloudConfiguration: require('./cloud-configuration-samples.cjs'),
  },
  guideJavascript: [read('transaction-import-guide.js'), exported.guideJavascript, recurring.guideJavascript, read('cloud-configuration-guide.js'), detail.guideJavascript, shareCard.guideJavascript, read('ai-advanced-guide.js'), support.guideJavascript, read('maintenance-guide.js'), read('cloud-backup-guide.js'), read('cloud-shared-guide.js'), `document.addEventListener('click',event=>{const ab=event.target.closest('.ab92-integrated-sample [data-ab92]');if(ab&&!ab.disabled){const host=ab.closest('.ab92-integrated-sample');host.querySelector('[data-ab92-demo-event]').textContent='局部示例回调：'+ab.dataset.ab92+'，不请求系统权限或打开外部应用';if(ab.dataset.ab92==='monitor'){const on=ab.getAttribute('aria-checked')!=='true';ab.setAttribute('aria-checked',String(on));ab.classList.toggle('selected',on);}}const dc=event.target.closest('.dc97-integrated-sample [data-dc97]');if(dc)dc.closest('.dc97-integrated-sample').querySelector('[data-dc97-demo-event]').textContent='局部受控状态回调：'+dc.dataset.dc97+'；不读取或改写真实汇率';});`].join('\n'),
};
