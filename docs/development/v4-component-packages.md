# V4 组件包与验收

分支：`v4`。两个包提供当前设计规范的 52 组样例对应组件，以及表单、反馈、图表、账户、预算、详情、AI 消息和安全输入的展示能力。**目录映射不等于视觉验收通过，也不等于所有旧控件和业务页面已经迁移。**

数据边界：`beecount_ui` 只处理样式与通用交互；`beecount_business_ui` 接收展示数据、`ImageProvider` 和回调。Riverpod、仓库请求、账本权限、汇率查询、持久化、导入解析、系统相册与分享均留在 App binding/controller 中。弹窗关闭不提交草稿；成功确认再由调用方写入。

## App 内 Flutter 验收页

验收入口位于现有 App 的 `lib/presentation/v4/gallery/component_gallery_page.dart`，在同一个 Navigator 中打开两张普通 Flutter 页面。没有第二个 `main`、嵌套 MaterialApp、WebView 或单独应用工程。

- 调试版：我的 → 关于 → V4 组件验收。
- 打开 `BEECOUNT_V4_RECORDING=true` 的调试版：首页右上更多 → V4 组件验收；深浅色切换也收在此菜单。
- 基础页 19 个分区，业务页 35 个分区，全部平铺，支持黄／绿／紫主题和深浅色切换。顶部目录通过分区标签快速滚动定位，保留已操作状态；支持直接连续上下浏览。
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

HTML 规范同样拆成 **基础 22 组、业务 30 组视觉样例**，合计 52 组。视觉样例数与 Widget 数不同：主题/字体等单独成组，组合样例也可包含多个 Widget。所有样例平铺，桌面侧边目录、手机定位选择、搜索、浅深色与 27 个主题色共用；不再用瀑布流混排。

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
