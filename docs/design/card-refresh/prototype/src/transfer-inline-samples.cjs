const accounts=[
 {id:'cny-cash',name:'现金',currency:'CNY',type:'cash',hidden:false,tradable:true,balance:1000},
 {id:'cny-bank',name:'招商银行',currency:'CNY',type:'bank_card',hidden:false,tradable:true,balance:50},
 {id:'usd-cash',name:'美元现金',currency:'USD',type:'cash',hidden:false,tradable:true,balance:100},
 {id:'usd-bank',name:'美元银行卡',currency:'USD',type:'bank_card',hidden:false,tradable:true,balance:5},
 {id:'eur-bank',name:'欧元账户',currency:'EUR',type:'bank_card',hidden:false,tradable:true,balance:0},
 {id:'usd-hidden',name:'已隐藏的美元账户',currency:'USD',type:'cash',hidden:true,tradable:true,balance:20},
 {id:'valuation',name:'房产估值',currency:'CNY',type:'real_estate',hidden:false,tradable:false,balance:0},
];
const blank={mode:'create',from:null,to:null,expression:'0',note:'',date:'2026-10-25T12:30',tags:[],attachments:[],pins:[],rateOverride:null,busy:false};
const pair={from:'usd-cash',to:'usd-bank',expression:'10'};
const history={mode:'edit',editId:'qa-source',from:'usd-cash',to:'cny-bank',expression:'12',originalFrom:'usd-cash',originalTo:'cny-bank',originalCurrency:'USD',rateOverride:7.1,note:'QA 历史跨币种记录',date:'2025-01-02T09:30',tags:['QA 历史标签'],excludeFromStats:true,excludeFromBudget:true};
const scenes=[
 ['transfer-inline','转账 · 同屏空草稿',{}],
 ['transfer-inline-cny','转账 · CNY → CNY',{from:'cny-cash',to:'cny-bank',expression:'10'}],
 ['transfer-inline-usd','转账 · CNY账本内 USD → USD',pair],
 ['transfer-inline-from-empty','转账 · 转出为空',{to:'usd-bank',expression:'10'}],
 ['transfer-inline-to-empty','转账 · 转入为空',{from:'usd-cash',expression:'10'}],
 ['transfer-inline-same-account','转账 · 同账户禁止',{from:'usd-cash',to:'usd-cash',expression:'10'}],
 ['transfer-inline-different','转账 · 新增跨币种禁止',{from:'usd-cash',to:'cny-bank',expression:'10'}],
 ['transfer-inline-no-rate','转账 · 缺汇率',{...pair,missingQuotes:['USD']}],
 ['transfer-inline-invalid-rate','转账 · 非法汇率',{...pair,rateOverride:0}],
 ['transfer-inline-history','转账 · 历史跨币种编辑',history],
 ['transfer-inline-history-copy','转账 · 历史跨币种复制需改同币种',{...history,mode:'copy',editId:null,date:'2026-10-25T12:30'}],
 ['transfer-inline-hidden-history','转账 · 隐藏账户历史编辑',{...history,from:'usd-hidden',to:'usd-bank',originalFrom:'usd-hidden',originalTo:'usd-bank',pins:['usd-hidden']}],
 ['transfer-inline-hidden-new','转账 · 新建排除隐藏账户',{}],
 ['transfer-inline-fields','转账 · 备注日期标签附件',{...pair,note:'QA 原位备注，切换账户后保留金额、日期、标签和附件',tags:['QA 旅行','QA 家庭','QA 外币'],attachments:[{name:'QA-payment.png',synthetic:true},{name:'QA-invoice.png',synthetic:true}]}],
 ['transfer-inline-saving','转账 · 防重复保存',{...pair,busy:true}],
 ['transfer-inline-save-error','转账 · 元信息失败原身份重试',{...pair,tags:['QA 旅行'],failNextMetadata:true}],
 ['transfer-inline-empty-accounts','转账 · 无可交易账户',{emptyAccounts:true}],
 ['transfer-inline-note','转账 · 小屏展开备注',{...pair,note:'QA 保留的原位备注',noteExpanded:true}],
].map(([key,title,patch])=>({key,title,draft:{...blank,...patch}}));
const guide=`<div class="ti93-guide"><article class="ti93-guide-card"><b>账户与金额在主记账同一页面</b><p>允许 CNY→CNY，也允许在 CNY 账本内选择 USD→USD。转入候选必须与转出同币种；转出和转入不能是同一账户。</p><p>USD 原币金额用于两账户余额流转，CNY 折算保存为独立快照。缺失或非法汇率阻止保存。旧跨币种原账户对仍可编辑；复制为新记录时必须改成同币种。</p><p>切换账户保留金额、备注、日期、标签和附件；币种变化只清旧汇率。账户区独立滚动，元信息两行，区域间距 8px，键盘贴底。</p></article><div class="v4-wrap">${scenes.map(scene=>`<a href="../prototype/demo.html?page=flow-${scene.key}">${scene.title}</a>`).join('')}</div><p class="bc-small">这些页面使用局部合成数据，不连接真实账本；原生权限、附件选择器、保存与设备展示由 App 验收。</p></div>`;
module.exports={accounts,rates:{CNY:1,USD:7.2,EUR:8},scenes,guide};
