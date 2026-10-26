# V4 组件包与验收

更新：2026-10-26。分支：`v4`。当前 Flutter 目录为基础 **26** 组、业务 **78** 组，HTML 为基础 **29** 卡、业务 **76** 卡，共 **105** 卡；基础包中 **57** 个公开 Widget 均有具体目录位置与状态声明。目录映射、源码可达和 Widget 测试分别提供覆盖证据，**都不等于整页原生验收通过**。原迁移基线与 A–E 后续设计修订的验收分别见[页面完成记录](v4-page-completion.md)。

## 数据与职责边界

`beecount_ui` 负责通用视觉、布局和受控交互；`beecount_business_ui` 接收展示模型、已格式化金额、`ImageProvider` 和回调。Riverpod、Repository、Drift、HTTP、账本权限、汇率时点、持久化、解析、文件选择、相册、分享和认证由 App binding/controller 保持原有实现。页面负责组合与生命周期，不在展示包内新增第二套请求或资金计算。

| 场景 | 展示包负责 | App 负责 |
| --- | --- | --- |
| 选择器、表单与弹窗 | 展示选项、局部草稿、受控选择、校验反馈、确认/取消回调 | 真实资源、筛选与权限、默认值、确认后的原子写入 |
| 交易与汇总 | 原币/历史折算字符串、紧凑标签、统计标记、隐私和独立操作区域 | 查询、历史快照、汇率口径、当前账本、编辑/详情导航、批量提交和同步队列 |
| 资产、洞察与预算 | 紧凑 Tab、柱/线/均线、排行、构成和预算卡 | 原统计口径、平均值分母、净值历史、实际账户与预算字段 |
| 云、AI、导入导出与平台功能 | 任务、权限、错误/重试、配置草稿和结果的可复用视图 | 原服务、连接测试、授权、后台任务、恢复、原生系统操作 |
| 分享、年度与启动 | 七类海报的纯布局、卡片、初始化文案和装饰动效 | 原 DataService/导出服务、图片截取与系统分享、初始化完成与路由时机 |

真实数据由 App 注入现有目录入口。受控默认值是合成状态，不写入金融数据；“打开正式页面”的操作继续进入生产路由及其原确认流程。共享账户无法使用个人余额查询时保留“余额暂不可用”，不伪造为零。HTML 始终使用合成设计数据，不导出用户数据库到浏览器，也不代表执行了 Cloud、模型或系统服务。

## 同一 App 内的 Flutter 验收页

入口是原 App 的 `lib/presentation/v4/gallery/component_gallery_page.dart`，复用同一 Navigator；没有第二个 `main`、MaterialApp、WebView 或独立应用工程。

- 调试版：我的 → 关于 → V4 组件验收。
- `BEECOUNT_V4_RECORDING=true` 调试版：首页更多 → V4 组件验收。
- 基础 26 / 业务 78 组全部平铺；快速定位只滚动，不替换样例。主题和浅深色切换、返回与弹窗关闭保持原状态和滚动位置。
- `isolatedCase` 只用于集中渲染和组件测试。真实入口默认展示全部分区，后台动效通过 TickerMode 暂停。

原基础索引 13「标签块与多选」已补上真实 `BeeMultiSelect` 的集合选择/禁用和 `BeeInlineLabel` 的短文、长文省略/完整提示、局部点击样例；原 26 组及全部索引不变。该补齐属于 R117 待验收候选，不能沿用 R116 产物宣称原生已展示。

## 当前映射的唯一来源

不同数量表达不同层次，不相加为“完成页面数”，也不要求每个 HTML 卡对应一个 Flutter 组。

| 来源 | 内容与用途 |
| --- | --- |
| [component_coverage.json](../../tool/v4/component_coverage.json) | 与 `components/samples.json` 的 **99 个兼容样例 key** 精确对应；声明组件、Flutter 索引、关联规范卡和代表状态 |
| [component_catalog_coverage.json](../../tool/v4/component_catalog_coverage.json) | **105 张 HTML 卡**的精确映射，包含增强卡 `spec-2001–2008`；声明真实类、组/索引、状态和渲染源 |
| [foundation_inventory.json](../../tool/v4/foundation_inventory.json) | **57 个基础 Widget**各自的真实基础目录位置与状态；不包含普通数据模型或 Painter |
| [HTML catalog.json](../design/card-refresh/components/catalog.json) | 基础29 / 业务76卡的分组、中文名、旧锚点及 Flutter 目标 |
| `foundationCases` / `businessCases` | 原 App 两张 Flutter 页的26 / 78个实际组，使用从0开始的机器索引；界面显示从1开始 |
| [A–E 翻新组件覆盖](v4-refresh-component-coverage.md) | 新组件的用途、原组补齐与 `spec-2001–2008` 对应关系；保留原目录索引，不另复制一套清单 |

部分旧捕获 key 作为兼容数据契约保留；当前交易行从 `transaction-row-samples.cjs`、资产从 `asset-overview-samples.cjs`、基础多选从 `foundation-samples.cjs` 重建，不能把旧捕获片段当成当前有效样式源。多个 key 可合成一张卡，字体/间距等规范也可直接由令牌构建。增强卡来自 `refresh-component-catalog.cjs`，必须在映射中逐项登记，不通过忽略新项维持通过。

`verify_component_coverage.py` 保留样例 key 完全一致、类名存在、索引范围、包依赖边界、基础 Widget 集合完整和状态非空检查；另外核对105卡与渲染源、增强定义、Flutter 中文标签和双向关联。基础库存还检查声明分区能经真实构造/弹层回调链静态到达组件，拒绝只填一个索引而没有样例的映射。此检查不执行回调，也不代替视觉或原生数据验收。

## 交易行 C3 合同

- 普通情况优先两行，复杂情况最多三行。原币金额为主，折算不挤压左侧内容；右侧金额、折算和时间沿用实际展示偏好。
- “不计收支 / 不计预算”用文字；账本名称使用紧凑标签。备注优先的模式不在下方重复分类名，同时保留原“分类优先”偏好。
- 行内标签默认10号字、16视觉高；可点击标签的命中留白不放大色块。与标签选择器的44触控项分开处理。
- 超出密度时使用“更多 N 项”只读字段弹层，保留完整备注、全部标签和原始金额；隐私模式同时遮蔽原币、折算与完整字段中的金额。
- 分类图标独立进入分类详情，普通行点击直接编辑，长按菜单另有详情入口；右侧无省略号。左滑露出78删除区，点击后确认；批量和只读状态不触发编辑或删除。
- 支出/收入/转账、时间开关与秒级格式、原币/历史折算、多标签、附件、统计排除、共享记录人、长文本、隐私、批量、只读和自定义图片共用48个原样例加12个 C3组合，共60个合成用例。数据来自 `assets/v4_gallery/transaction-states.json` 与 `transaction-c3-cases.json`；浏览器和 Flutter 共用该范围，实际数据绑定由 App 验收。

## 其他关键约定

| 场景 | 当前合同 |
| --- | --- |
| 核心记账 | 两行辅助信息；备注直接修改、附件右上角；元信息与计算器间保留8间距。长屏金额/元信息固定、分类独立滚动、键盘和保存贴底；短屏金额压缩、备注可折叠 |
| 分类、账户、账本选择 | 独立业务组件；保留搜索、当前态、二级图标/自定义图片、币种/权限过滤及原取消/确认语义 |
| 标签 | 横排、自动换行、多选/搜索、最近使用与局部草稿；语义色保留，选择状态不改变标签业务色 |
| 附件 | 单张/双列/三列预览，缩略图、大图、缩放与切换；文件/相册/拍照仍由 App 管理 |
| 弹窗与菜单 | 原为弹窗的流程保持弹窗；等宽确认动作、独立滚动、键盘/安全区；关闭不提交草稿。操作菜单与长按复用原行为 |
| 主题与皮肤 | 默认无皮肤，沿用27主题色和原语义色；两款动态皮肤可选。根层系统栏处理主题亮度，内层可覆盖，不改导航栏字段 |
| 分享与年度 | 档案/应用两个默认模板保留；月、年、账本、年度长图及小票使用同一纸面体系，原数据口径/字段/导出由 App 提供 |
| 启动 | 采用已确认 B「一笔成形」；装饰不延迟初始化跳转，减少动效/后台暂停保持可读，安全说明属于当前页面局部弹层 |

## 修改与验证

```sh
python3 tool/v4/verify_component_coverage.py
python3 tool/v4/test_verify_component_coverage.py
flutter test --no-pub test/widgets/v4_component_gallery_test.dart
```

HTML 从 `prototype/src`、样例源和令牌重建，不直接修改生成物。新样例同时更新对应覆盖 JSON；新增基础 Widget 必须补真实目录实例/回调和状态。已有负向夹具检查漏 key、未知类、错索引、漏基础实例、虚假分区、漏增强卡、未知关联、空状态及非法包依赖，不能通过放宽断言或忽略新项消除失败。

- [交互规范与全部平铺样例](../design/card-refresh/components/ui-components.html)
- [完整浅色大图](../design/card-refresh/boards/ui-components-light.png) / [深色大图](../design/card-refresh/boards/ui-components-dark.png)
- [基础浅色](../design/card-refresh/boards/ui-foundation-light.png) / [业务浅色](../design/card-refresh/boards/ui-business-light.png)，同目录保留 dark 版本。
- [设计资源重建说明](../design/card-refresh/README.md) / [完整页面清单](v4-page-migration.md) / [机器页面清单](v4-page-inventory.json)

每页最终仍需对照原字段、入口、默认值、权限、平台条件和异常路径，复用同一隔离环境完成真实读写、取消、返回和正常重启，再保存独立报告。逐页完成情况只从当前机器状态与完成记录读取，不从组件数量、提交量或局部截图推算。
