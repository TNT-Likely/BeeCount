const fs = require('fs'), path = require('path');
const types = [
  ['cash', '现金', 'daily'], ['bank_card', '银行卡', 'daily'],
  ['credit_card', '信用卡', 'daily'], ['alipay', '支付宝', 'daily'],
  ['wechat', '微信', 'daily'], ['other', '其他', 'daily'],
  ['real_estate', '房产', 'valuation'], ['vehicle', '车辆', 'valuation'],
  ['investment', '投资', 'valuation'], ['insurance', '保险', 'valuation'],
  ['social_fund', '社保公积金', 'valuation'], ['loan', '贷款', 'valuation']
];
function sample(locked) {
  const tabs = [['daily', '日常账户'], ['valuation', '估值账户']].map(([id, label]) =>
    `<button data-account-group="${id}" aria-pressed="${id === 'daily'}">${label}</button>`).join('');
  const panels = ['daily', 'valuation'].map(group => {
    const choices = types.filter(item => item[2] === group).map(([id, label]) => {
      const file = id === 'other' ? 'other_account' : id;
      const image = fs.readFileSync(path.resolve(__dirname, '../../../../../assets/icons', file + '.svg')).toString('base64');
      return `<button data-account-type="${id}" aria-pressed="${id === 'cash'}" ${locked && group === 'valuation' ? 'disabled' : ''}><img src="data:image/svg+xml;base64,${image}" alt=""><span>${label}</span></button>`;
    }).join('');
    return `<div class="g-account-type-grid" data-account-panel="${group}" ${group === 'daily' ? '' : 'hidden'}>${choices}</div>`;
  }).join('');
  return `<div data-account-types data-locked="${locked}"><h4>${locked ? '编辑已有日常账户' : '新建账户'}</h4><div class="g-choice-tabs">${tabs}</div>${panels}<p class="v4-small" data-account-draft>当前草稿：现金</p><p class="v4-small">${locked ? '允许浏览其他分组；已有账户不能跨日常与估值分组改变类型。' : '共 12 种原有类型；浏览分组不会修改选择。'}</p></div>`;
}
module.exports = `<div class="v4-stack">${sample(false)}<div class="v4-divider"></div>${sample(true)}</div>`;
