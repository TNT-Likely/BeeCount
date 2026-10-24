# V4 组件包与验收

分支：`v4`。两个包提供当前设计规范的 58 组样例对应组件，以及表单、反馈、图表、账户、预算、详情、AI 消息和安全输入的展示能力。**目录映射不等于视觉验收通过，也不等于所有旧控件和业务页面已经迁移。**

数据边界：`beecount_ui` 只处理样式与通用交互；`beecount_business_ui` 接收展示数据、`ImageProvider` 和回调。Riverpod、仓库请求、账本权限、汇率查询、持久化、导入解析、系统相册与分享均留在 App binding/controller 中。弹窗关闭不提交草稿；成功确认再由调用方写入。

## App 内 Flutter 验收页

验收入口位于现有 App 的 `lib/presentation/v4/gallery/component_gallery_page.dart`，在同一个 Navigator 中打开两张普通 Flutter 页面。没有第二个 `main`、嵌套 MaterialApp、WebView 或单独应用工程。

- 调试版：我的 → 关于 → V4 组件验收。
- 打开 `BEECOUNT_V4_RECORDING=true` 的调试版：首页右上更多 → V4 组件验收；深浅色切换也收在此菜单。
- 基础页 19 个分区，业务页 40 个分区，全部平铺，支持黄／绿／紫主题和深浅色切换。顶部目录通过分区标签快速滚动定位，保留已操作状态；支持直接连续上下浏览。
- 示例金额、图片和昵称均为合成数据。测试页操作不修改当前账本。

```sh
flutter run --flavor dev --dart-define=BEECOUNT_V4_RECORDING=true
flutter test test/widgets/v4_component_gallery_test.dart
python3 tool/v4/verify_component_coverage.py
```

## 本轮与定稿的校正

依据 `docs/design/card-refresh/components/product.css` 和 `samples.json`，不以 Material 默认样式替代定稿。

| 场景 | 修正后的约定 | 源稿参照 |
| --- | --- | --- |
| 账单行 | 中性分类图标独立点击；金额在右，折算及标签位于金额下方；普通模式隐藏批量复选框 | `.v-entry` / `.v-entry-secondary` |
| 汇总卡 | 月份、币种、支出、收入/结余、预算分层；货币符号缩小；隐私同时遮蔽金额 | `.bc-summary` / `.bc-hero-value` |
| 账本卡 | 当前账本描边与浅底；预算、编辑/成员和右下更多；长按与更多同菜单 | `.j-ledger-card` / `.j-ledger-actions` |
| 同步 | 与菜单行一致，状态副文案、异常原因、进行中反馈、重试由宿主提供 | `.j-sync-row` |
| 资料与余额 | 昵称与编辑入口；两行紧凑余额/笔数/天数，支持账本切换及隐私 | `.u-profile` / `.u-ledger-compact` |
| 标签 | 横排多选与搜索，局部草稿；语义色保留；选中边框/勾选 | `.j-tag-cloud` / `.j-tag-chip` |
| 附件 | 单张 1.8 比例，双/三列；顶部裁切、9 间距、12 圆角，点击查看原图 | `.u-attachment-grid` |
| 确认弹窗 | 自定义卡片：20 外边距、18 内边距、23 圆角、16 标题、双操作等宽 | `.bc-modal` |
| 记账金额 | 金额/元信息固定、只滚动分类；计算器和保存操作固定底部；系统键盘出现时隐藏计算器 | `editor` 页面布局 |

Flutter 与浏览器字体的栅格化存在差异；不能只靠目录映射脚本宣称像素一致。修改时同时看源稿、Flutter 截图和真机交互。

## 设计覆盖表

| 设计样例 | 组件 | 验收页 / 目录索引 |
| --- | --- | --- |
| `primary` | `BeeButton` | foundation / 0 |
| `nav` | `BeeBottomBar` | foundation / 7 |
| `entry` | `BeeTransactionRow` | business / 2 |
| `entryForeign` | `BeeTransactionRow, BeeMoney` | business / 2 |
| `brand` | `BeeHomeIdentity` | business / 0 |
| `brandOff` | `BeeHomeIdentity` | business / 0 |
| `summary` | `BeeSummaryCard, BeeProgress` | business / 1 |
| `categories` | `RecordingCategoryTile, RecordingSubcategoryChip, BeeCategoryRanking` | business / 3 |
| `keypad` | `RecordingKeypad, RecordingAmountCard, RecordingHeader` | business / 5 |
| `metadata` | `RecordingDetailsCard, BeeTag` | business / 5 |
| `menu` | `BeeMenuRow, BeeActionMenu` | foundation / 3 |
| `segments` | `BeeSegmented` | foundation / 1 |
| `mapping` | `BeeImportMapping` | business / 14 |
| `auth` | `BeeAuthorization, BeeField` | business / 16 |
| `wheel` | `BeeWheel, BeeDateWheels` | business / 17 |
| `fields` | `BeeField, BeeSearchField, BeeToggleRow, BeeCheckTile` | foundation / 2 |
| `receipt` | `BeeReceipt, BeeAnnualSummary` | business / 18 |
| `onboarding` | `BeeOnboardingStep` | business / 15 |
| `tags` | `BeeTagPicker, BeeTag` | business / 6 |
| `ledger` | `BeeLedgerCard` | business / 9 |
| `ledgerMenu` | `BeeActionMenu` | business / 9 |
| `sync` | `BeeSyncStatus` | business / 10 |
| `customIcons` | `BeeCategoryIcon` | business / 3 |
| `quickAdd` | `BeeQuickAddTrigger, BeeQuickAdd` | business / 20 |
| `currency` | `BeeCurrencyPicker, BeeChoicePicker` | business / 7 |
| `rate` | `BeeValidatedInput, BeeStatus` | business / 8 |
| `mineProfile` | `BeeProfile` | business / 11 |
| `ledgerBalance` | `BeeLedgerBalance` | business / 11 |
| `nickname` | `BeeValidatedInput` | business / 12 |
| `attachments` | `BeeAttachments` | business / 13 |
| `attachmentViewer` | `BeeAttachmentViewer` | business / 13 |

## 状态与交互检查

- 浅色、深色、320 宽屏、1.4 倍字体遍历全部目录；检查布局异常。
- 标签横排、多选、搜索、取消不提交；确认和清空由局部草稿管理。
- 分类图标点击与账单内容点击分离；批量选择、左滑请求和可见菜单。
- 账本当前状态、卡片长按与更多按钮进入同一菜单；危险操作二次确认。
- 汇率拒绝零、负数、NaN、Infinity 和非数字；昵称取消与 trim 后保存。
- 自定义图标保留颜色、失败回退；附件单张、双列、三列及缩略图切换。
- 日期滚轮月末／闰年夹取；按住 480ms、滑动松手选择和未命中取消。
- 11 种同步状态展示、错误原因及重试入口；示例不发起真实同步。

测试页中的回调会显示操作结果，持久化只在主 App 的记账流程测试和同一 BeeCount App 的隔离 Android 安装中验证。年度卡片、分享卡片只提供布局与输入数据契约；导出图片和系统分享由宿主继续复用现有服务。

## 后续页面接入

先让 App binding 将现有实体映射为这些展示参数，保留现有权限与提交控制器。每迁移一页，复用目录中的状态样例补上真实数据闭环验收。包中禁止读取全局 provider 或发请求；不要为迁移 UI 同时更改数据库模型。新增设计样例时同步更新 `tool/v4/component_coverage.json` 和测试页，覆盖脚本会检查遗漏。

## 仍由后续页面迁移负责

此处完成的是展示组件和合成状态的验收入口。首页/我的/账户/统计等完整页面的真实数据 binding、导入任务、AI 请求、应用锁认证、系统附件和分享仍使用原业务实现，逐页迁移后分别验证。包内的 PinPad 只是输入展示，不能代替认证或安全存储。同步样例不代表已执行网络同步。

平铺容器位于 `gallery/gallery_catalog.dart`。测试的 `isolatedCase` 只用于单组件布局截图与状态测试；真实 App 默认平铺全部分区。后台页通过 TickerMode 暂停动效。

## 基础组件盘点与 HTML 分组（2026-10-23）

此前的 12 个分区只提供少量默认样例，不代表基础组件全面。当前扩展到 **19 个 Flutter 分区、37 个公开基础 Widget**，每个 Widget 的展示位置与支持状态记录在 `tool/v4/foundation_inventory.json`。覆盖脚本会拒绝未登记的新公开 Widget；此清单是能力与样例索引，不把“登记了”视为所有状态都已真机验收。

新增图标按钮、角标、通用选择块、分隔线、固定底部操作栏；补齐 Form 校验、只读与禁用区分、密码切换、输入过滤、计数、搜索清空、复选半选和加载状态。`BeeChoicePicker`、`BeeValidatedInput`、`BeeDateWheels` 下沉基础包，业务包继续重导出原符号，原调用可继续使用。

| 现有控件 / 需求 | 基础包与边界 |
| --- | --- |
| `FeatureDot` | `BeeBadge` 负责红点 / 数字 / 隐藏；原 Provider 决定是否显示 |
| 胶囊切换、多选 | `BeeSegmented` / `BeeChoiceChip`；长标签滚动、禁用、选择由宿主持有 |
| 可搜索下拉 | `BeeSelectField` 用于短选项；`BeeChoicePicker` 用于可搜索长列表与加载/错误 |
| 确认、表单、菜单 | `BeeDialog` / `BeeValidatedInput` / `BeeSheet` / `showBeeContextMenu` |
| 日期、时间、月份 | 基础包 `BeeDateWheels` 组合 `BeeWheel`，日期业务约束仍由宿主提供 |
| 页头与固定操作 | `BeePageHeader` / `BeeSection` / `BeeActionBar`；路由、保存、键盘策略归 App |
| 动态皮肤、系统附件、分享、鉴权 | 仍由原 App 管理；不因盘点基础组件而放入纯 UI 包 |

HTML 规范同样拆成 **基础 22 组、业务 36 组视觉样例**，合计 58 组。视觉样例数与 Widget 数不同：主题/字体等单独成组，组合样例也可包含多个 Widget。所有样例平铺，桌面侧边目录、手机定位选择、搜索、浅深色与 27 个主题色共用；不再用瀑布流混排。

- [HTML 组件目录](../design/card-refresh/components/ui-components.html)
- [基础浅色大图](../design/card-refresh/boards/ui-foundation-light.png) / [业务浅色大图](../design/card-refresh/boards/ui-business-light.png)，均有 dark 版本。
- `components/catalog.json` 记录 HTML 分组与 Flutter 目录索引；旧 `#spec-*` 锚点保留。
- 原有页面还没有全部替换成新基础控件，动态皮肤与平台服务也不在本轮基础组件覆盖声明中。


## 选择器与真实数据验收补充

- 分类、账户、账本选择器是独立公开业务组件，目录 Flutter 28 / 29 / 32；HTML 对应 B23 / B24 / B27。支持搜索、当前态；分类支持二级图标、自定义图片、展开和草稿确认/取消，账户按记账币种筛选。
- 交易行状态全集（Flutter 30 / HTML B25）共用 `assets/v4_gallery/transaction-states.json` 的 48 个合成样例，覆盖收支、转账、外币、标签附件、统计排除、共享记录人、长文本、隐私、批量勾选、只读、自定义图片和最简行。只读行保留查看，禁用修改入口。
- “真实账本联动”（Flutter 31 / HTML B26）由 App 的 `bindings/live_business_preview.dart` 接现有 Repository / Provider，读取当前账本、余额、分类、同币种账户、最近 12 笔交易、标签、附件数和统计标记。切换账本更新同一上下文；所选分类和账户可带入原记账页。返回后或点击刷新重新读取，沿用现有刷新 tick；不是额外同步引擎。
- 本地个人账户使用原账户余额查询。共享镜像账户不属于个人账户表，无法用该查询计算余额时显示“余额暂不可用”，不显示虚假的 0。共享选择继续走现有权限资源过滤。实际共享 Cloud 联调不在本轮范围。
- HTML 始终为明确标注的固定设计数据，不将 App 数据库导出到浏览器；AI、导入任务、同步、系统分享、认证的目录样例仍为合成展示，尚未迁移成真实服务绑定。

后续全部页面的逐页批次与备份方式见 [全量翻新计划](../../.docs/v4-ui-migration/all-pages-plan.md) 和 [组件覆盖核查](../../.docs/v4-ui-migration/component-audit.md)。

`RecordingConversionSummary` 是两列紧布局的折算摘要，左侧说明、右侧金额与箭头；数据和汇率仍由 App 提供。完整剩余页面与优先级见 [迁移清单](v4-page-migration.md)。

搜索页新增 `BeeSearchSummary`、`BeeBatchSelection`、`BeeBatchActionBar`，Flutter 第 35 分区与 HTML B30 同步展示。真实检索、标签/附件关系及筛选草稿留在 App binding；批量更新继续沿用原 Repository 与同步队列。

搜索组件已从 HTML 实测冻结尺寸：汇总卡 362×142.5、17 内边距、19 号金额与分隔线；Flutter 字段排版允许 1px 取整差异。紧凑 `BeeChoiceChip` 视觉 34、高度 44 的触控区，并支持尾部图标。批量底栏保留 17 页面留边与 17 圆角。对应实际渲染与边缘点击回归。

分类、账户与标签详情共用 `BeeResourceHero`、`BeeResourceBreakdown` 和 `BeeResourceTrend`（Flutter 第 36 分区 / HTML B31）。数据查询、历史折算和隐私处理在 App binding；320/398 详情卡尺寸与实际 HTML 计算样式冻结比对。

配置迁移新增 `BeeConfigurationOptions` 与 `BeeConfigurationPreview`（Flutter 第 37 分区 / HTML B32）。选择集合受控，YAML 预览可选择文本且高度受限；解析、文件选取、密钥处理、Repository 和导入刷新都留在 App binding。原生验收页与 HTML 均保留八项范围、选中/取消及内容预览。

安全输入新增 `BeeSecurityPanel`，沿用 `BeePinPad` 的四位、错误、禁用和生物识别插槽（Flutter 第 27 分区 / HTML B33）。数字卡片的高、宽、圆角、字号和间距分别对照 398×844 / 320×568 的实际 HTML 冻结值；认证、旧密码验证、哈希和持久化保留在 App 原服务。关闭应用锁时的原私有验证页属于设置页关联流程，尚待同样迁移，不能因主密码页使用新组件而忽略。

分类图标编辑新增 `BeeCategoryIconEditor`（Flutter 第 38 分区 / HTML B34），基础网格提供隐藏视觉标签但保留无障碍标签的紧凑模式。App 保留原 237 个图标标识和分组，通过 binding 处理真实分类、相册裁剪、重复名称、父分类过滤与文件保存；选图不写数据库，显式保存将名称和图标放在同一数据库事务中，取消不删除原图。

### 账户类型选择

`BeeAccountTypePicker` 组合基础分段与图标网格，受控接收当前分组、类型、原品牌图标及禁用状态。日常 / 估值的 12 个 ID、本地化和已有账户不能跨分组的规则由 App 提供；浏览分组不修改账户草稿。账户编辑保留原类型切换和保存回调，仅先替换选择区域，整页尚未迁移完成。Flutter 业务分区第 39 组与 HTML B35 同时展示；HTML 在 1440/390/320 验证草稿、禁用和原 SVG，37 项相关组件/widget 回归与 4 文件静态检查通过。当前 R35 真机产物在该组件提交前构建，账户编辑整页将在新产物上另行验收。

### 账户余额调整

`BeeAccountBalanceAdjustment` 接收当前值、目标值、差额、两种模式和确认回调，不执行资金计算或写入。App 继续计算差额并等待原布尔结果：`null` 取消、`false` 只调整期初余额、`true` 新增平账记录。原账户编辑已改用标准底部弹层与该组件，删除约 400 行重复展示；保存、币种锁、信用卡符号和余额并发保护仍由原服务处理，整页继续迁移。Flutter 第 40 分区 / HTML B36 均可切换模式，320 大字深色的三个返回值及真实仓储余额行为通过；相关三文件 42 项检查通过，与前序回归重叠不累加。HTML 58 组在 1440/390/320 通过平铺、主题、搜索与无横向溢出。


## 账户编辑消费闭环（R37）

`BeeAccountTypePicker` / `BeeAccountBalanceAdjustment` 已由真实账户编辑页消费；日期、银行资料、提醒和提交均留在 App actions。页面 381 行，固定保存、屏外必填定位、备注可清空和元信息/余额本地原子提交已验证。HTML 有四种完整表单场景，关键几何与真机比较通过；18 项本页用例及 211 项相关回归通过。同一 Android QA 环境实际完成四类账户保存、币种锁、余额取消/双模式、隐藏/恢复和删除，独立报告见完成标准文档。当前环境运行 R37，代码的业务目录 40 分区；R36 的原生 39 分区证据作为单独版本保留。


## 分类管理组件消费与原能力保留（R39）

`BeeCategoryManagementList` 与新增 `BeeCategoryChildrenGrid` 都接收受控分类、真实图标/图片、笔数和回调；包内不读数据库、不选择文件、不导入网络服务。App binding 负责收支分组、原排序写入/同步、子分类加载失败重试、ZIP 分类包导入/导出及默认分类与清理。管理弹窗的添加/编辑操作固定在底部；空列表仍展示转账分类和工具入口。原有双标签页改为共用同一次转账分类初始化，返回编辑后再更新图标。

Flutter 第 33 组现在实际打开子分类弹窗，展示预设图标及奶茶自定义 PNG，并可切换空分类场景。HTML B28 同时平铺列表、子分类弹窗内容、空状态和转账/工具入口；所有样例仍明确区分固定草稿与真实 App 数据。本轮规范数量仍为 58（基础 22 / 业务 36），Flutter 基础 19 / 业务 40，新增六个页面/交互场景后设计总数 198。整页真机闭环完成前不增加页面完成数。

R39 整页消费和真实 UI / ZIP / 图片 / 正常重启闭环已完成，当前完整页面 9 个；图标数据与 file I/O 仍由 App 提供，独立报告见完成标准文档。


## 资产总览组件准备（账户总览整页尚未完成）

先抽出 `BeeAssetSummary`、`BeeAssetChartSection` 和 `BeeAccountPreferences`：汇总接收 App 已格式化的原币/折算金额和隐私状态；图表接原图表/加载/异常内容及受控模式；设置接账户开关、原默认收支账户和多币种汇率入口。全部计算、请求、偏好读写和导航仍在 App。原 `AmountText` 金额显示提为共用 App 格式函数，保留币种符号、负数、小数、紧凑单位和无币种回退，不让业务组件重复处理财务口径。

Flutter 新增第 41 分区，HTML 新增 B37（总 59 组，基础 22 / 业务 37），平铺展示汇总、趋势/构成、设置。38 项组件及目录检查通过，HTML 1440/390/320 的隐私、切换、开关、默认账户回调及无溢出通过。实际设备仍是 R39 的 40 分区产物；这些新展示组件先准备，尚未用样例替代资产页真实消费或整页验收。


## 资产总览接入真实 App（R40 待真机验收）

原账户总览编排改为 125 行，原统计/净值趋势/构成、默认账户、隐藏/恢复和路由进入独立 App binding；新展示组件已实际消费，原图表仍使用原日期序列与库。补充受控 `BeeAccountConversionRow` 后规范仍为 59 组（同一资产分区），支持原币/折算负号、缺失汇率和隐私。原折算明细的绝对值显示会吞掉负号，已修正为显示真实符号，未改汇率计算和数据。对照原代码还恢复了账户卡整卡进入详情；菜单单独处理，长按仍走原编辑入口。

当前 32 个相关文件 **238 项回归通过**，其中资产页 6 项实际仓库/偏好/新建返回/隐藏恢复用例；10 文件静态检查无问题。HTML 总数 205 个场景，补齐单币种、多币种缺失、隐藏、估值、空态、设置、默认账户与折算明细。设备仍运行 R39；R40 尚未完成逐页真实设备闭环，不计整页完成。


## 资产总览 R42 已完成

R40 接入已在 R42 闭环，资产页计为第 10 个完成页。239 项 / 32 文件回归与同一隔离 App 实际默认账户、隐藏恢复、SQL 汇总和正常重启通过。原 SVG 的图片语义导致平台吞掉菜单节点，已由装饰图片排除、独立菜单容器及统一 BeeIconButton 修正；新增语义回归可让旧组件失败，真实设备已复验。原账户/金额/类型计算及外部目的页仍由 App 管理，不将 P1/P2 目的页计为完成。详情和独立报告见页面完成文档。


## 欢迎流程组件与真实接入（R44 整页完成）

`BeeOnboardingStep` 统一居中品牌/进度、可滚动内容与固定底部动作；`BeeOnboardingChoice`、`BeeOnboardingModeCard` 和 `BeeBackupFileCard` 分别用于语言/币种、三种分类模式及备份草稿。基础包补齐原 Lucide 的归档、配置和层级图标，修正 Grid2x2 大小写。业务包无 Repository/网络/平台文件访问；实际语言偏好、种子初始化、系统文件选择、配置服务与附件服务留在 App。

原附件备份为 TAR.GZ，而非设计旧稿标注的 ZIP；本轮已同步 HTML、真实预选文件/确认路径与原服务测试。初始化沿用原种子身份和三种模式，防止重复点击再建账本；数据库失败事务回滚后保留重试，不提前写完成标记。33 文件共250项回归、9文件静态检查、59组设计映射与37个基础控件清单通过。本页11项是真实本地数据库/文件测试，R44同一隔离包的五步、实际文件选择与YAML/TAR.GZ恢复、独立SQL/文件和正常重启闭环完成；原52笔/5附件/2图片保持，仅新增合成标签。首次种子与失败/防重由真实数据库widget执行，不重置物理设备密集数据。
