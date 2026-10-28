# V4 展示层收口与组件抽离计划

更新：2026-10-28。按用户要求，本轮只列 `presentation/v4` 的归位计划，不搬目录，不删除原页面备份。后续按业务逐批执行。

## 现状与职责

页面入口已经在原 `lib/pages` 修改，例如 `pages/main/analytics_page.dart`、`pages/account/account_detail_page.dart`；没有另一套 V4 页面路由。迁移时把页面数据适配、分块与动作放入 `presentation/v4`，以保持入口简短、便于逐步对照。它是过渡组织，不应成为长期的版本目录。

本次静态 import/export/part 图审计：

| 目录 | Dart 文件 | 从 main 静态可达 | 含义 |
|---|---:|---:|---|
| `lib/widget` | 12 | 12 | 桌面小组件规格、数据服务、管理器和各平台预览；不是旧页面，不删除 |
| `lib/widgets` | 74 | 64 | 通用 UI 包装、业务数据适配、图表、海报及平台桥接混合，须逐项拆分 |
| `lib/presentation/v4` | 208 | 208 | 当前页面正在使用的适配与分块；整体删除会破坏现有路由 |

静态不可达不等于可直接删除：仍需检查测试、原生入口、脚本和字符串引用。原始源码备份继续保留在 `.docs/v4-ui-migration/backup`，准备上线时再决定清理。

## 目标结构与依赖方向

| 内容 | 目标位置 | 可以依赖 |
|---|---|---|
| 页面入口与页面生命周期 | 原 `lib/pages/<feature>/*_page.dart` | 同业务 bindings/widgets、应用服务、组件包 |
| Provider／Repository／权限／路由／提交 | `lib/pages/<feature>/bindings` 或 controllers | App 数据与服务、组件包；不反向进入展示包 |
| 仅该业务使用的页面分块 | `lib/pages/<feature>/widgets` | 同业务适配、组件包 |
| 跨页面复用的业务展示 | `packages/beecount_business_ui` | `beecount_ui`、Flutter 与受控视图模型；不读 App Provider/Repository |
| 通用视觉与交互 | `packages/beecount_ui` | Flutter、图标；不依赖业务包或 App |
| 调试组件验收页 | `lib/dev/component_gallery` | 两个展示包和明确标记的数据适配样例 |
| 桌面小组件 | 保留 `lib/widget`；以后单独评估更名 `home_widgets` | 平台桥接和桌面小组件数据服务 |

不把代码行数减少作为单独目标：页面保留装配职责；不会为了文件更短把查询、同步或权限塞进 business-ui。

## presentation 归位批次（后续执行）

1. **P0：洞察、分类详情、账户详情、记账**：分别归位 analytics、category、account、transaction；保持原 Page 类名、路由参数及 Provider 身份。将 `part` 动作文件先归位到所属 page 目录，再逐步改为明确的控制器／服务，避免跨目录 `part of` 长期存在。
2. **P1：搜索、账本、资产、预算、标签**：按业务整组搬迁，不同时改变财务计算、筛选和分页行为。跨页面相同 UI 先抽组件，数据适配仍归业务。
3. **P1：AI、导入导出、同步和设置**：保留服务与平台分支；分开页面 UI 与服务编排，不把网络凭据和 Cloud 状态移入展示包。
4. **P2：欢迎、分享、年度报告及组件验收**：业务入口保持，纯海报布局进业务包；图像生成、存储、系统分享留 App。gallery 单独放入 dev。
5. **最后清理**：待所有 import/part、测试和原生入口核对后删除空的 `presentation/v4`。备份目录删除另行处理。

每批只调整目录与依赖，功能修复使用独立提交；执行前保存路径映射，完成后跑相关 widget、静态分析及同一隔离环境的正常路由回归。

## lib/widgets 抽离清单

| 类别 | 处理方式 |
|---|---|
| `ui/wheel_date_picker.dart`、`ui/wheel_time_picker.dart` | 本轮已去掉重复旧轮子样式，实际轮子、边界与秒列进入 ui；App 只保留本地化、两步流程、草稿与返回结果 |
| `biz/account_selector.dart` | 横条、选择项和状态视觉已在 business-ui；LRU、共享权限、币种过滤继续留 App |
| `biz/amount_editor_sheet.dart` | 金额、键盘、元信息、标签与附件行已有业务包组件；计算、草稿、汇率、保存和权限保留 App；后续把包装归位 transaction/bindings |
| `biz/transaction_list.dart`、`transaction_list_item.dart` | 行、菜单、滑动视觉在业务包；实时查询、编辑导航、删除与同步留 App；继续审查重复的菜单／列表状态展示 |
| 账户流水筛选 | 本轮新增受控 `BeeAccountFlowFilter`，方向、排序与确认视觉进入业务包；查询只在 App 确认后执行 |
| `charts`、`analytics` | 受控图表和排行适合进 business-ui；先核当前新组件能否覆盖，避免把无消费者旧图表搬进新包 |
| `posters` | 可抽受控海报布局与绘图 DTO；App 的 Repository 查询、合成图片、导出及系统分享不搬 |
| `currency`、`transaction`、`ai` | 分别拆出展示与状态；汇率服务、交易提交、模型请求、工具授权和平台动作继续留 App |

以下 10 个文件当前不从 main 静态可达，列为后续废弃审查候选，**本轮不删除**：

- `widgets/biz/pin_entry_pad.dart`
- `widgets/category/category_selector.dart`
- `widgets/charts/account_category_pie_chart.dart`
- `widgets/charts/asset_composition_chart.dart`
- `widgets/charts/line_chart.dart`
- `widgets/charts/category_pie_chart.dart`
- `widgets/ai/agent_entry_card.dart`
- `widgets/ai/agent_ai_mark.dart`
- `widgets/analytics/category_rank_row.dart`
- `widgets/analytics/analytics_summary.dart`

删除前逐个记录替代组件、所有消费者、测试／脚本引用和回退依据；能确认已有替代的旧实现归档后删源，不为清空目录而再造组件。
