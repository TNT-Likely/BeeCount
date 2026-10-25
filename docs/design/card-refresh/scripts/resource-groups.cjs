// Display categories are independent of the original scene groups used by filters.
const groups = [
  ['recording', '记账与明细'],
  ['insights', '洞察与预算'],
  ['assets', '资产与账户'],
  ['ledgers', '账本与共享'],
  ['cloud', '云服务与同步'],
  ['data', '数据与分类标签'],
  ['automation', 'AI 与自动化'],
  ['settings', '我的与设置'],
  ['startup', '启动与分享'],
  ['security', '首次使用与安全'],
  ['help', '帮助与支持'],
  ['interactions', '交互与组件'],
].map(([id, title], order) => ({ id, title, order }));

const originalGroups = {
  '启动与分享': 'startup',
  '首次使用与安全': 'security',
  '云服务与同步': 'cloud',
  '共享账本与云同步': 'cloud',
  '账户与资产': 'assets',
  '账本与共享': 'ledgers',
  '导入导出与维护': 'data',
  '维护与本地诊断': 'data',
  '分类标签与预算': 'data',
  '标签与分类': 'data',
  '分类与标签 · 汇总币种': 'data',
  '自动化与识别': 'automation',
  '自动记账 · 平台与错误': 'automation',
  '记账提醒 · 平台与弹窗': 'automation',
  'AI 与助手': 'automation',
  'AI与助手': 'automation',
  'AI高级设置': 'automation',
  '外观与辅助': 'settings',
  '显示与外观 · 原配置弹窗': 'settings',
  '主题色 · 自定义与锁定': 'settings',
  '皮肤 · 筛选与调试': 'settings',
  '动态皮肤': 'settings',
  '汇率管理 · 原流程与状态': 'assets',
  '帮助与信息': 'help',
  '帮助与支持': 'help',
  '年度账单与小票': 'startup',
  '主记账转账': 'recording',
  '账单与详情': 'recording',
  '记账选择与弹层': 'recording',
  '流程状态': 'interactions',
  '交互补充': 'interactions',
  '组件规范': 'interactions',
  '组件验收': 'interactions',
  '交互状态': 'interactions',
  '短屏适配': 'interactions',
  '反馈补充': 'interactions',
  '基础输入 · 输入法兼容': 'interactions',
  // The original “其他” group currently contains only ledger states.
  '其他': 'ledgers',
};

const routes = {
  home: 'recording', editor: 'recording', categoryPicker: 'recording',
  search: 'recording', batch: 'recording', calendar: 'recording', detail: 'recording',
  report: 'insights', budget: 'insights', assets: 'assets', accountDetail: 'assets',
  categoryDetail: 'data', tagDetail: 'data', data: 'data', ledgers: 'ledgers',
  ai: 'automation', smart: 'automation', automation: 'automation', cloud: 'cloud',
  mine: 'settings', appearance: 'settings', colors: 'settings', skins: 'settings',
  about: 'help',
};

function getResourceGroup(scene) {
  const original = scene.group.replace(/^补齐\s*·\s*/, '');
  let id;
  if (/^(?:budget$|report$|flow-(?:budget|bge|analytics)(?:-|$))/.test(scene.route)) {
    id = 'insights';
  } else if (originalGroups[original]) {
    id = originalGroups[original];
  } else if (routes[scene.route]) {
    id = routes[scene.route];
  } else if (/^flow-(?:calendar|cl-month)/.test(scene.route)) {
    id = 'recording';
  } else {
    id = 'interactions';
  }
  return groups.find(group => group.id === id);
}

module.exports = { groups, getResourceGroup };
