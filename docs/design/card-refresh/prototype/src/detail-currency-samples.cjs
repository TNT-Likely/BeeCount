const fs=require('fs'),path=require('path');
const currencyCodes=[...fs.readFileSync(path.resolve(__dirname,'../../../../../lib/utils/currencies.dart'),'utf8').matchAll(/_Cur\('([A-Z]{3})'/g)].map(hit=>hit[1]);
const books=[{id:1,name:'日常生活',currency:'CNY'},{id:2,name:'美元旅行',currency:'USD'},{id:3,name:'共享美元',currency:'USD',shared:true,role:'editor'}];
const rows=[
 {id:9701,book:1,type:'expense',amount:10,currency:null,native:null,category:'餐饮',child:'咖啡',tag:'旅行',note:'旧本币记录',date:'2026-10-24',account:'现金'},
 {id:9702,book:2,type:'expense',amount:16,currency:'EUR',native:20,category:'餐饮',child:'咖啡',tag:'旅行',note:'原币 EUR，美元账本快照',date:'2026-10-23',account:'欧元卡',attachments:1},
 {id:9703,book:1,type:'expense',amount:12,currency:'USD',native:85.2,category:'餐饮',child:'早餐',tag:'旅行',note:'原快照不随今日汇率改写',date:'2026-10-22',account:'美元账户',excludeStats:true,excludeBudget:true},
 {id:9704,book:1,type:'income',amount:9,currency:'CNY',native:9,category:'工资',tag:'旅行',note:'旅行补贴',date:'2026-10-23',account:'银行卡'},
 {id:9705,book:2,type:'expense',amount:4,currency:'USD',native:4,category:'餐饮',child:'早餐',tag:'旅行',note:'上月美元早餐',date:'2026-09-24',account:'美元现金'},
 {id:9706,book:1,type:'expense',amount:7,currency:'CNY',native:7,category:'餐饮',tag:'旅行',note:'上一年记录',date:'2025-01-03',account:'现金'},
 {id:9707,book:1,type:'expense',amount:50,currency:'CNY',native:50,category:'购物',note:'份额分母',date:'2026-10-21',account:'现金'},
];
const defaults={target:1,scope:'all',period:'all',anchor:'2026-10',child:null,sort:'timeDesc',privacy:false,rates:{CNY:{USD:{rate:'7.1',manual:true}},USD:{}},books,rows};
const cases=[
 ['current','当前账本本币与外币历史快照',{scope:'current',rates:{}}],
 ['all','全部账本统一为CNY',{}],
 ['usd','切当前账本为USD与反向汇率',{target:2}],
 ['missing','缺USD汇率禁止完整合计',{rates:{}}],
 ['native-missing','显式外币缺历史native',{rowPatch:{9703:{native:null}}}],
 ['legacy','旧null原币与空native合法本币',{scope:'current',rows:[rows[0]]}],
 ['unknown','来源或币种缺失',{rowPatch:{9701:{book:999},9703:{currency:'UNKNOWN',native:85.2}}}],
 ['stale','陈旧有效缓存与日期',{rates:{CNY:{USD:{rate:'7.1',manual:false,date:'2020-01-01'}}}}],
 ['invalid','无效直接手动率不得回退',{rates:{CNY:{USD:{rate:'NaN',manual:true}},USD:{CNY:{rate:'.14',manual:true}}}}],
 ['shared','共享synthetic分类标签来源',{rows:[{...rows[1],book:3,categoryId:-9701,tagId:-9702,account:'共享欧元卡'}]}],
 ['privacy','隐私不泄露金额与百分比',{privacy:true}],
 ['privacy-missing','隐私保留缺项状态',{privacy:true,rates:{}}],
 ['month','月范围与二级分组',{period:'month'}],
 ['year','年范围',{period:'year'}],
 ['empty','无关联记录',{rows:[]}],
];
const scenes=['category','tag'].flatMap(kind=>cases.map(([id,label,patch])=>({key:`detail-currency-${kind}-${id}`,title:`${kind==='category'?'分类':'标签'}详情 · ${label}`,kind,scenario:{...defaults,...patch}})));
scenes.push({key:'detail-currency-tag-custom-month',title:'标签详情 · 自定义8日月边界',kind:'tag',scenario:{...defaults,scope:'current',period:'month',monthStartDay:8,rows:[{...rows[0],id:9781,date:'2026-10-07',amount:5,native:5,currency:'CNY'},{...rows[0],id:9782,date:'2026-10-08',amount:7,native:7,currency:'CNY'}]}});
const componentSample={key:'detail-currency-component',title:'汇总币种提示 · 完整/缺失/陈旧与隐私',states:['complete','missing','stale']};
const componentGuide=`<section class="dc97-pure-states"><h3>汇总币种提示 · 纯状态</h3><p>纯组件只接收已本地化的范围、缺失笔数/币种和日期说明；不读取数据、不计算汇率、不写入历史。</p><div class="dc97-guide-links">${[['完整','已按当前账本币种 CNY 汇总'],['缺失','1 笔未折算 · USD，暂不显示汇总金额'],['陈旧 + 隐私','汇率已超过 7 天 · 2020-01-01；金额显示 ••••']].map(([name,label])=>`<aside><b>${name}</b><p>${label}</p></aside>`).join('')}</div><p><a href="../prototype/demo.html?page=flow-detail-currency-component">打开受控完整/缺失/陈旧与隐私示例</a></p></section>`;
const guide=`<article class="dc97-guide"><b>以当前账本币种汇总，保留每笔历史快照</b><p>先读取账单来源账本的本位币，再将其历史 native 金额按查询时有效汇率折成当前账本币种。同币种直接累加；手动汇率优先，缺少直接汇率时使用有效反向汇率。历史字段不写回。</p><p>缺汇率、非法率、显式外币缺历史 native 或来源账本缺失时，金额、均值、份额与趋势显示占位，明确未折算笔数及币种。明细的原币、原账本旧快照、标签、附件和标记保留。陈旧有效缓存显示日期提示。</p><p>默认全部时间，保留当前/全部账本、月/年、父子分类和原币金额排序；隐私隐藏所有金额、比例与图形。示例来自本地合成数据。</p><div class="dc97-guide-links">${scenes.map(s=>`<a href="../prototype/demo.html?page=flow-${s.key}">${s.title}</a>`).join('')}</div>${componentGuide}</article>`;
module.exports={books,rows,defaults,scenes,guide,currencyCodes,componentSample,componentGuide};
