from pathlib import Path
import re,json,subprocess,hashlib,tarfile,io,collections
root=Path(__file__).resolve().parents[2];d=root/'.docs/v4-ui-migration';d.mkdir(exist_ok=True,parents=True)
config=json.loads((root/'tool/v4/migration-status.json').read_text())
flows=json.loads((root/'docs/design/card-refresh/tokens/flow-sources.json').read_text());manifest=json.loads((root/'docs/design/card-refresh/screens/manifest.json').read_text())
manual={
'ai/ai_chat_page.dart':['ai'],'budget/budget_edit_page.dart':['flow-budget-edit','flow-budget-edit-existing-total','flow-budget-edit-total','flow-budget-edit-category','flow-budget-edit-custom','flow-budget-edit-empty-categories','flow-budget-edit-loading','flow-budget-edit-error','flow-budget-edit-write-error','flow-budget-edit-readonly','flow-bge-category','flow-bge-delete'],'budget/budget_page.dart':['budget'],'tag/tag_detail_page.dart':['tagDetail','flow-tag-foreign-detail','flow-tag-all-ledgers-detail','flow-tag-empty-detail'],'transaction/category_detail_page.dart':['categoryDetail'],'transaction/search_page.dart':['search','batch'],
'main/home_page.dart':['home'],'main/analytics_page.dart':['report','flow-analytics-income','flow-analytics-balance','flow-analytics-year','flow-analytics-all','flow-analytics-empty','flow-analytics-loading','flow-analytics-error','flow-analytics-pie','flow-analytics-foreign'],'main/mine_page.dart':['mine'],'main/ledgers_page_new.dart':['ledgers','flow-ledger-edit','flow-ledger-actions','flow-ledger-create','flow-ledger-period','flow-ledger-currencies','flow-ledger-remote-actions','flow-ledgers-empty','flow-ledgers-remote','flow-ledgers-loading','flow-ledgers-error','flow-ledgers-editor','flow-ledger-conflict'],
'tag/tag_manage_page.dart':['flow-tag-management','flow-tag-management-empty','flow-tag-management-error','flow-tag-management-loading','flow-tag-tools'],
'account/accounts_page.dart':['assets','flow-assets-single','flow-assets-missing','flow-assets-empty','flow-assets-hidden','flow-assets-valuation','flow-account-settings','flow-asset-default','flow-asset-conversion'],'account/account_detail_page.dart':['accountDetail','flow-account-credit-detail','flow-account-overpayment-detail','flow-account-no-limit-detail','flow-account-valuation-detail','flow-account-loan-detail','flow-account-empty-detail'],'calendar/calendar_page.dart':['calendar','flow-calendar','flow-calendar-unselected','flow-calendar-empty','flow-calendar-loading','flow-calendar-error','flow-calendar-earliest','flow-calendar-latest','flow-cl-month'],'transaction/transaction_editor_page.dart':['editor','flow-foreign-editor'],
'auth/welcome_page.dart':['welcome','welcomeCurrency','welcomeCategories','welcomeCloud','welcomePrivacy','welcomeImport','welcomeAttachments','welcomeDone','flow-welcome-currency-picker'],
'category/category_manage_page.dart':['flow-category-management','flow-category-children','flow-category-tools','flow-category-share','flow-taxonomy-import','flow-category-defaults','flow-category-clear','flow-category-empty'],'settings/about_page.dart':['about'],'settings/data_management_page.dart':['data','flow-attachment-transfer','flow-attachment-import-confirm','flow-data-import-running','flow-data-import-success','flow-data-import-partial','flow-attachment-export-progress','flow-attachment-import-progress'],
'settings/reminder_settings_page.dart':['flow-reminder','flow-reminder-ios','flow-reminder-time','flow-reminder-battery','flow-reminder-channel','flow-reminder-battery-warning','flow-reminder-channel-warning'],
'settings/app_lock_settings_page.dart':['flow-lock-settings','flow-lock-settings-on','flow-lock-settings-no-bio','flow-lock-timeout','flow-pin-verify'],
'settings/smart_billing_page.dart':['smart'],'settings/automation_page.dart':['automation'],'settings/personalize_page.dart':['colors','flow-theme-custom','flow-theme-locked'],
'settings/appearance_settings_page.dart':['appearance','flow-appearance-mode','flow-appearance-amount','flow-appearance-note','flow-appearance-history','flow-appearance-scheme','flow-appearance-currency'],'settings/header_skin_page.dart':['skins','flow-skins-animated','flow-skins-static','flow-skins-debug'],'settings/language_settings_page.dart':['flow-language'],
'settings/privacy_policy_page.dart':['leaf:隐私政策'],'report/annual_report_page.dart':['annual'],
'donation/donation_page.dart':['flow-donation'],'settings/attachment_preview_page.dart':['flow-attachment-library','flow-attachment-library-archive','flow-attachment-library-empty','flow-attachment-library-empty-group','flow-attachment-library-broken','flow-attachment-library-loading','flow-attachment-library-long'],
'attachment/attachment_preview_page.dart':['flow-attachment-viewer'],
}
# Migration batches include every Page/Screen source; helper files remain alongside consumers.
def batch(rel):
 name=Path(rel).name
 if name in ['transaction_editor_page.dart','recurring_transaction_edit_page.dart','recurring_transaction_page.dart']:return 'M1 记账闭环'
 if name in ['home_page.dart','mine_page.dart','ledgers_page_new.dart','search_page.dart']:return 'M2 首页与列表'
 if (rel.startswith(('category/','tag/','account/','currency/')) and name!='net_worth_trend_page.dart') or name=='category_detail_page.dart':return 'M3 资源管理与详情'
 if rel.startswith(('budget/','calendar/','report/')) or name in ['analytics_page.dart','net_worth_trend_page.dart']:return 'M4 统计与分享'
 if rel.startswith('cloud/'):return 'M5 云与共享'
 if rel.startswith(('ai/','automation/')) or name in ['smart_billing_page.dart','shortcuts_guide_page.dart','automation_page.dart']:return 'M6 AI与自动化'
 if rel.startswith(('data/','auth/','attachment/','maintenance/')) or name in ['config_import_export_page.dart','data_management_page.dart','attachment_preview_page.dart','storage_management_page.dart']:return 'M7 初始化与数据'
 return 'M8 设置与收尾'
contracts={
'M1 记账闭环':('金额卡、计算器、分类/账户/币种/日期/标签选择器；补 TransferAccountPair','保存/编辑/复制、再记一笔、历史汇率快照、同币种/跨币种转账、共享权限和草稿'),
'M2 首页与列表':('资料/余额、账单行、汇总、筛选与批量栏、底部导航','当前账本、隐私、分类图标导航、长按/删除、标签/附件入口和批量选择'),
'M3 资源管理与详情':('分类层级、图标编辑、排序、账户/标签卡、详情列表','自定义图片、转账图标设置、隐藏账户历史、余额调整、资源权限与筛选'),
'M4 统计与分享':('趋势/环图/排行/预算；补日历与日期范围组合','日月年统计、本位币合计、隐私、小票/年度/分享实际导出'),
'M5 云与共享':('同步行、配置弹窗、授权；补成员/邀请/角色组合','全部同步状态、重试、远端/本地删除差别、邀请权限和多成员资源'),
'M6 AI与自动化':('消息、执行时间线、授权；补服务商/能力绑定与任务状态','平台/渠道入口、配置草稿、连接测试、授权、记忆/活动、语音触发与静音时长'),
'M7 初始化与数据':('初始化、映射、附件/预览；补导入任务和附件库组合','语言等完整步骤、取消/恢复、部分失败、附件关联、预览/导入/导出/备份'),
'M8 设置与收尾':('分组列表、表单、主题/色板、滚轮、反馈；补日志组合','原菜单/筛选完整、弹窗形态、平台入口、主题/皮肤、检查更新、应用锁与通知'),
}
rows=[];helpers=[]
for p in sorted((root/'lib/pages').rglob('*.dart')):
 s=p.read_text();rel=str(p.relative_to(root/'lib/pages'));classes=re.findall(r'(?:final\s+)?class\s+([A-Z]\w*(?:Page|Screen)\w*)\s+extends',s)
 if not classes:helpers.append(str(p.relative_to(root)));continue
 refs=list(manual.get(rel,[]))
 for f in flows:
  source=f['source'].replace('lib/pages/','').lstrip('./')
  if source==rel:refs.append(f['route'])
 refs=list(dict.fromkeys(refs));known={m['route'] for m in manifest}|{'flow-attachment-viewer'};assert all(r in known or r.startswith('leaf:') for r in refs),(rel,refs);wave=batch(rel);comp,verify=contracts[wave]
 rows.append({'source':str(p.relative_to(root)),'classes':classes,'lines':len(s.splitlines()),'batch':wave,'designRoutes':refs,'designMapping': '已定位' if refs else '待补明确场景映射','components':comp,'acceptance':verify,'status':'试点待新布局确认' if rel=='transaction/transaction_editor_page.dart' else '未迁移'})
assert set(config['pages']) == {r['source'].removeprefix('lib/pages/') for r in rows}, '新增/删除页面须更新 migration-status.json'
for r in rows:
    r.update(config['pages'][r['source'].removeprefix('lib/pages/')])
    r['designLinks'] = ['../../docs/design/card-refresh/prototype/demo.html?page=' + route for route in r['designRoutes']]
for flow in config['associatedFlows']:
    assert (root/flow['source']).is_file(), flow['source']
priority_counts=collections.Counter(r['priority'] for r in rows)
completed_count=sum(r['status']=='已完成' for r in rows)
completed_names='、'.join(r['name'] for r in rows if r['status']=='已完成') or '暂无'
audit={'date':config['updated'],'branch':config['branch'],'pageFiles':len(rows),'helperFiles':helpers,'designSceneExports':len(manifest),'flowDefinitions':len(flows),'priorityCounts':dict(sorted(priority_counts.items())),'plannedPages':config['plannedPages'],'associatedFlows':config['associatedFlows'],'rows':rows}
(d/'page-inventory.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
head=config['baselineCommit'];backup=d/'backup'/('pre-v4-'+head[:12]);
if not (backup/'MANIFEST.json').exists():
 blob=subprocess.check_output(['git','archive','--format=tar',head,'lib/pages','lib/widgets'],cwd=root)
 backup.mkdir(parents=True,exist_ok=True)
 with tarfile.open(fileobj=io.BytesIO(blob)) as tar:
  for member in tar.getmembers():
   assert (member.name == 'lib' or member.name.startswith(('lib/pages','lib/widgets'))) and '..' not in Path(member.name).parts
  tar.extractall(backup,filter='data')
 files=[p for p in backup.rglob('*') if p.is_file()]
 (backup/'MANIFEST.json').write_text(json.dumps({'baselineCommit':head,'kind':'committed-pre-v4-ui-baseline','note':'来自当前 HEAD 的已提交 UI；不声称包含 v4 开始前未提交的状态。当前工作区没有被替换。','files':[{'path':str(p.relative_to(backup)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(files)]},ensure_ascii=False,indent=2)+'\n')
(d/'backup/README.md').write_text(f'''# 旧 UI 代码备份

当前基线为 `{head}`，目录 [pre-v4-{head[:12]}](pre-v4-{head[:12]})，保留 `lib/pages/` 和 `lib/widgets/` 原路径。

这是该提交的已提交 UI 快照，不是“v4 开始前所有未提交文件”的追溯备份。活跃源码没有移动，导入和路由没有改变；此目录在 `.docs` 下，不参与 Flutter 编译，现有规则忽略它。

每迁移一批页面，再把开工时工作区的相关 UI 文件复制到新的 `checkpoint-日期-流程/lib/...`，记录 SHA256 与来源。备份只读，不做业务修复或格式化；修复进入活跃实现。不能通过把全部旧页面放入 `lib/backup` 来维护第二套应用。

逐页比较示例：

```sh
git diff --no-index .docs/v4-ui-migration/backup/pre-v4-{head[:12]}/lib/pages/main/mine_page.dart lib/pages/main/mine_page.dart
```

迁移全流程人工验收通过后，再在一次独立清理中决定归档旧 UI；当前不删除备份，不创建第二个数据库或应用入口。
''')
counts=collections.Counter(r['batch'] for r in rows)
body='''# 全部页面翻新计划

更新日期：2026-10-24。工作分支：`v4`。面向公开 4.0，内部按完整流程分批验收。当前收支记账两行布局已落地，待人工验收；转账与多数页面仍待迁移。完整优先级见受版本控制的 [页面迁移清单](../../docs/development/v4-page-migration.md)。

## 当前结论

不能将组件目录齐全等同于全业务覆盖。两个包的组件与样例数量以 [组件包说明](../../docs/development/v4-component-packages.md) 和当前 HTML/Flutter 目录为准。还存在 [组件缺口](component-audit.md)，必须在对应页面开工前明确状态、交互和真实数据绑定。

页面清单按当前代码自动盘点，辅助文件单列。设计导出场景与页面不是一对一关系，不能用场景数量当完成率。详见 [逐页清单](page-inventory.json)。

## 保留旧代码并原路径翻新

采用 `.docs/v4-ui-migration/backup/<baseline>/lib/...` 只读备份，活跃页面继续在原路径修改。已保存当前 HEAD 的已提交旧 UI，见 [备份与比较](backup/README.md)。每批开工补一份当前工作区的流程快照，避免丢掉用户未提交的修改。

不把旧页面移动到 `lib/backup`：目录仍会参与分析，旧导入和路由需重写，容易同时维护两套 Provider/业务实现。需要短期回退入口的少数高风险页面，可以单独保留 Legacy 视图；保存控制器与数据库共用，验收结束统一清理。

## 页面职责与代码规模

- `Page`：参数、生命周期、加载/失败/权限状态、导航和 Section 组合。只读页面目标 150–250 行；复杂编排页目标 250–400 行，作为评审信号，不用拆文件来凑指标。
- App `bindings`：订阅原有 Provider/Repository，映射展示模型，处理当前账本和权限，调用原有提交/导入/同步服务。
- `beecount_business_ui`：业务展示、可复用本地交互、数据和事件契约；不 import App、Riverpod、Drift 或 HTTP，不内置导航或真实请求。
- `beecount_ui`：通用布局、表单、选择、弹层、反馈、主题令牌。Flutter SDK 已适用的控件按规范组合，避免没有复用价值的一层包装。
- 只有单页使用且没有稳定业务语义的布局，留在页面旁的 `sections/`；出现第二个真实消费者再考虑升级成公共业务组件。

## 实施批次

| 批次 | 范围 | 开工前组件门槛 | 一次验收闭环 |
| --- | --- | --- | --- |
'''
for wave,count in sorted(counts.items()):comp,verify=contracts[wave];body+=f'| {wave}（{count} 个页面源文件） | 见下方逐页清单 | {comp} | {verify} |\n'
body+='''
先完成 P0 的核心收支/转账与主要入口，再推进 P1、P2；批次用于代码分组，不代表优先级。M3 与 M4 复用同一账单行和详情 Section；M5–M8 按数据和导航依赖推进，每批包含关联弹窗及异常状态。缺口只阻塞对应批次，不要求先设计一套没有消费者的大而全组件框架。

## 每批交付标准

1. 对照原页面逐项核对入口、字段、默认值、选项、平台条件、权限和弹窗路径；菜单数量或内容变化必须有产品决定。
2. 组件、HTML 与 Flutter 验收页的状态清单对应；至少验证浅深色、320×568、375×667、长屏、140% 字体及长数据。
3. 用原有真实 Repository 完成读写与返回；选择器取消不改数据，历史折算沿用快照，批量状态不打开详情或触发删除手势。
4. 对应场景的 Widget/单元测试通过，再在隔离安装包走正常入口验收。保持人工测试数据，不重置 fixture；原 App 不重装，不运行 Flutter integration test。
5. 每批出代码 diff、行为差异、复用组件、证据与剩余问题；未迁移和仅样式样例的功能不能标为完成。

## 迭代与 4.0 发布

以完整用户流程为迭代单位：每轮包含设计核对、缺口组件、真实绑定、自动验证、人工验收和修正。首两轮记录实际耗时后再估计全量工期，当前不承诺固定上线周数。公开 4.0 需高频路径与关联弹窗完整统一、全量功能可达性清单通过，再进入 Beta 和 RC。

数据请求包和 Workspace/Melos 不是 4.0 前置条件；此阶段不改数据库 schema、同步协议、金额口径或附件存储。全局基础样式变化要覆盖所有已迁移消费者，不能只测修改目录。

## 逐页清单

行数为当前源码基线，包含业务逻辑，仅用于发现拆分收益；不等于新页承诺长度。`待补映射` 必须在该页开工前补明确设计状态。

| 页面源文件 | 当前行数 | 优先级 | 批次 | 设计入口 | 状态 |
| --- | ---: | --- | --- | --- | --- |
'''
for r in rows:body+=f"| `{r['source']}` | {r['lines']} | {r['priority']} | {r['batch'].split()[0]} | {'、'.join('`'+x+'`' for x in r['designRoutes']) or '待补明确场景映射'} | {r['status']} |\n"
body+='\n辅助文件：\n\n'+''.join(f'- `{h}`\n' for h in helpers)
(d/'all-pages-plan.md').write_text(body)
public=root/'docs/development';public.mkdir(parents=True,exist_ok=True)
(public/'v4-page-inventory.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
counts_text='、'.join(f"{k} {v} 页" for k,v in sorted(priority_counts.items()))
page=f"""# V4 完整页面迁移清单与优先级

更新：{config['updated']}。分支：`v4`。由 `tool/v4/build_migration_inventory.py` 扫描生成，人工决策保存在 [migration-status.json](../../tool/v4/migration-status.json)。

现有 **{len(rows)} 个产品页面源文件**（{counts_text}），另有 **{len(config['plannedPages'])} 个新设计页面待新增**、{len(helpers)} 个页面旁辅助文件和下方关联弹窗/表单。三个开发验收页不计入产品迁移进度。每个源文件均有设计入口，设计场景与代码页面不是一对一关系。

当前完整完成页面为 **{completed_count}**（{completed_names}）。已完整验收的页面按表标记；记账/转账、搜索与分类/标签详情的待确认项保留当前行为，其余页面逐页迁移并独立验收。全局主题变化不计为页面完成。判定条件见 [页面完成标准](v4-page-completion.md)。

## 优先级与顺序

| 优先级 | 范围 | 完成条件 |
| --- | --- | --- |
| P0 | 记账/转账、首页/我的/账本、明细与搜索、启动/初始化/恢复及直接依赖 | 主路径与关联弹窗一致、真实数据读写和返回正常，先交人工验收 |
| P1 | 统计/资产详情/预算/日历、资源管理、导入导出、云共享、AI/自动化和常用设置 | 按完整流程复用组件，覆盖权限、取消、错误与恢复 |
| P2 | 低频诊断、帮助、支持和高级配置 | 保留原有菜单和选项，关联 P0/P1 的弹窗提前随消费者迁移 |

优先级表示内部实施顺序，不代表 4.0 可以丢弃 P2。对外仍按一个完整 4.0 发布，Beta/RC 前核对全部原有能力及平台入口。M1–M8 是领域批次，与 P0–P2 独立；涉及多个领域的 P0 先跨批次完成。

每页的组件依赖及关键验收写在表中。每批开工先核对原字段、默认值、菜单、平台条件和弹窗，再确定可复用 Section；不要按文件名机械重画。

"""
for priority in ['P0','P1','P2']:
    selected=[r for r in rows if r['priority']==priority]
    page+=f"## {priority} · {len(selected)} 个现有页面\n\n| 页面 / 源码 | 状态 | 批次 | 组件与关联流程 | 必须保留 / 验收 |\n| --- | --- | --- | --- | --- |\n"
    for r in selected:
        title=f"**{r['name']}**<br>[{r['source']}](../../{r['source']})"
        routes='、'.join('`'+x+'`' for x in r['designRoutes'])
        page+=f"| {title} | {r['status']} | {r['batch'].split()[0]} | {r['components']} | {r['acceptance']}<br>设计：{routes}<br>优先理由：{r['reason']} |\n"
    page+='\n'
page+='## 待新增页面（不与现有 71 页重复计数）\n\n| 页面 | 优先级 / 状态 | 计划位置 | 原代码与新稿差别 |\n| --- | --- | --- | --- |\n'
for r in config['plannedPages']:
    page+=f"| {r['name']} | {r['priority']} / {r['status']} | `{r['source']}` | {r['reason']}<br>设计：{'、'.join('`'+x+'`' for x in r['designRoutes'])} |\n"
page+='\n## 必须随页面迁移的关联表单与弹窗\n\n这些不是独立 Page，不能从清单遗漏，也不能为了换皮把原弹窗改成新页面。P2 所属的检查升级弹窗可以随关于页后置；若上游提前消费，弹窗随上游一批交付。\n\n| 流程 / 源码 | 优先级 / 状态 | 验收要求 |\n| --- | --- | --- |\n'
for r in config['associatedFlows']:
    page+=f"| **{r['name']}**<br>[{r['source']}](../../{r['source']}) | {r['priority']} / {r['status']} | {r['acceptance']} |\n"
page+='\n## 页面旁辅助文件\n\n'+''.join(f'- [{h}](../../{h})：随直接消费者迁移，不重复计为 Page。\n' for h in helpers)
page+="""
## 备份、拆分与交付

活跃页面继续在原路径修改，开工前将相关文件复制到 `.docs/v4-ui-migration/backup/checkpoint-日期-流程/lib/...`，记录 SHA256；旧代码只读，不放进 `lib/backup` 参与编译。旧提交基线固定为 `6616066247a8738a42996c496e1b99106820e59f`，新增提交后不重新定义“旧版”。原三行记账稿另有 [设计与源码快照](../design/card-refresh/archive/recording-three-row-20261023/index.html)。

Page 负责参数、状态、导航与 Section 组合；App binding 复用当前 Provider/Repository、权限与提交控制器；基础和业务 UI 包接收数据/回调，不直接请求网络或依赖数据库。普通页 150–250 行、复杂页 250–400 行作为评审信号，不为行数拆文件。

每批交付：原行为对照、HTML/Flutter 状态对应、相关测试、独立 App 正常入口验证和人工验收。不得以截图、目录覆盖或代码变短直接标记完成。全量状态见 [机器可读清单](v4-page-inventory.json)，组件契约见 [组件包说明](v4-component-packages.md)，记账试点见 [录入说明](v4-recording-flow.md)。

更新命令：

```sh
python3 tool/v4/build_migration_inventory.py
```

生成器会拒绝未登记的新页面，确保优先级和状态不会悄悄遗漏。
"""
(public/'v4-page-migration.md').write_text(page)
print(json.dumps({'pages':len(rows),'helpers':len(helpers),'mapped':sum(bool(r['designRoutes']) for r in rows),'priorityCounts':dict(sorted(priority_counts.items())),'plannedPages':len(config['plannedPages']),'backup':str(backup)},ensure_ascii=False))
