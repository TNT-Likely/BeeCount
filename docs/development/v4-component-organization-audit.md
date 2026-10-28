# v4 组件目录收敛审计与实施计划

审计日期：2026-10-29。基线提交：`b24859e3`；同时读取当前工作树中的主线修正，因此它不是该提交的严格快照。本次只做代码、测试及工具入口静态审计，没有移动、删除或修改任何运行代码，也没有进行真机验收。

## 结论

建议最终消除 `lib/widgets` 与 `lib/presentation/v4` 两个长期并行目录，但不要把它们整体搬进业务包：

1. **纯展示只保留一份**：通用控件进 `beecount_ui`，领域展示进 `beecount_business_ui`；已存在等价组件的旧实现复用后退役。
2. **真实业务适配回到页面旁边**：数据库、Provider、权限、路由、本地化、文件选择、系统分享与保存流程归 `pages/<feature>` 的 `bindings` / `controllers`；组件包不反向依赖 App。
3. **现有页面入口保持不变**：`lib/pages` 已是实际路由入口。这里只收回配套代码，不再新建一套 V4 页面或路由。
4. **开发验收单独归档**：gallery 和仅供 gallery 使用的 preview 放 `lib/dev/component_gallery`，不混进生产页面目录。
5. **先退役再删除，不永久保留兼容层**：原页面源码备份继续保留；上线前是否删备份另行处理。

`lib/widget`（单数）是桌面小组件体系，与 `lib/widgets`（复数）不同。本轮不删除、不强行并入业务 UI 包。

## 核对范围与可信度

| 范围 | 当前 Dart 文件数 | 静态核对结果 | 最终方向 |
| --- | ---: | --- | --- |
| `lib/widget` | 12 | 12 个在主入口导入图内，包含桌面布局、规格、数据服务、管理器 | 保留独立平台能力；以后可单独改为 `platform/home_widgets` |
| `lib/widgets` | 74 | 64 个在主入口导入图内；另外 10 个不可达候选 | 按下面逐文件清单拆分、归位或退役 |
| `beecount_ui/lib/src` | 23 | 已有基础控件和交互容器 | 延续基础职责，避免重复控件 |
| `beecount_business_ui/lib/src` | 77 | 平铺文件中混有跨领域大文件 | 10 个业务分组，聚合文件先拆职责 |
| `presentation/v4/bindings` | 166 | 133 个生产适配/分块，33 个仅开发 preview | 生产回 pages，preview 回 dev |
| `presentation/v4/gallery` | 40 | 组件验收、样例、真实数据演示 | 回 dev |
| `presentation/v4/sections` | 2 | 字号、外观页面分块 | 回对应 pages |
| `presentation/v4` 合计 | 208 | 135 个生产文件、73 个开发文件 | 完成后删除空目录 |

方法：解析 Dart `import`、`export`、`part` URI（包含条件 URI），从 `lib/main.dart` 遍历，并反查测试和工具。**导入图可达不等于组件仍在使用**：`biz.dart`、`ui.dart` 大桶导出会把未构造的旧实现一起带入；也不能只搜索类名，`showWheelTimePicker`、`showCategorySelector`、`composeTransactionRowTitle` 等顶层入口仍有实际调用。

逐文件机器清单：[v4-component-organization-audit.json](v4-component-organization-audit.json)。包含 74 个旧组件的目标、原因、直接 lib / test 引用和源码摘要；77 个包文件的目标；208 个 presentation 文件的完整一对一路径映射。引用清单是静态证据，不是“可直接删除”的许可。

## 一、`lib/widgets` 怎么处理

### 判断规则

| 内容 | 归属 | 边界 |
| --- | --- | --- |
| 按钮、标签、弹窗、滚轮、提示、通用动画、纯布局 | `packages/beecount_ui` | 只接收值、状态、样式和回调 |
| 交易行、账户卡、分类选择、预算卡、账本选择、分享海报布局 | `packages/beecount_business_ui` | 接收受控视图数据、已格式化金额、图片和回调 |
| 选择器真实查询、默认账户选择、汇率时点、保存、权限与路由 | `lib/pages/<feature>/bindings` / `controllers` | 继续使用现有 Provider / Repository / 服务 |
| 金额格式工具、原生桌面小组件、导出编码与系统服务 | 对应 `utils` / `widget` / `services` | 不是因为文件名叫 widget 就装进 UI 包 |
| Agent SDK 的公共展示与 App 绑定 | 现有 `flutter_agent_ui` 与 `pages/ai` | 保留已有 SDK 边界，不复制到 BeeCount 业务包 |
| 已无生产使用的旧布局、兼容包装 | 迁移测试或调用方后删除 | 不为旧代码再制造一个新组件 |

业务组件对接真实数据的入口是 **App binding 注入**。例如账户选择器由页面查询当前账本可用账户、计算不可选状态，再传给 `BeeAccountPicker`；组件通过回调返回选择结果。不能让包自己查库，再在页面重复查一次。

### 需要区分的退役证据

- **7 个没有主入口可达路径、没有直接测试的候选**：`biz/pin_entry_pad.dart`、`category/category_selector.dart`、`charts/account_category_pie_chart.dart`、`charts/asset_composition_chart.dart`、`charts/category_pie_chart.dart`、`analytics/analytics_summary.dart`、`analytics/category_rank_row.dart`。旧饼图之间存在内部引用，但不是独立生产入口。它们应优先核对功能后删除，不搬到包里重存一份。
- **3 个主入口不可达、但测试仍依赖的候选**：`ai/agent_entry_card.dart`、`ai/agent_ai_mark.dart`、`charts/line_chart.dart`。先把入口语义/点击、折线等有效断言迁到现用实现，再退役；不能为了删除文件直接删断言。
- **桶导出掩盖的旧实现**：如 `biz/attachment_picker.dart`、`app_empty.dart`、`info_tag.dart`、`section_card.dart`，以及 `ui/searchable_dropdown.dart`、`skeleton.dart`、`wheel_picker.dart`；目前未见生产构造，应连同桶导出一起清查。`app_list_tile.dart`、`bee_popup_menu.dart`、`capsule_switcher.dart` 还有旧测试，需迁移。
- **确实还在用的适配**：`wheel_time_picker.dart` 的类名没有外部构造，但提醒设置调用它导出的 `showWheelTimePicker`；`transaction_row_title.dart` 的实际入口为 `composeTransactionRowTitle`。这些不能按类名“零引用”删除。
- `BeeIcon` 多处被欢迎页、首页、关于页和海报使用；应统一到现有品牌展示，迁完调用方才能删包装。`SpeedDialAction` 是 App 导航 DTO，应归操作编排，而不是为它创建一个业务 UI。

执行删除前仍需核对入口注册、原生/字符串引用、测试、生成器及文档样例；本审计没有运行 tree-shaking 或真机证明，因此这里统一称“候选”。

### 74 个文件的目标

下表路径前缀简写：`APP` = `lib/pages`，`UI` = `packages/beecount_ui/lib/src`，`BIZ` = `packages/beecount_business_ui/lib/src`。目标是最终落点，旧路径不会作为永久第二入口保留。完整引用证据在 JSON。

| 当前文件（相对 `lib/widgets`） | 处理 | 目标 / 等价入口 |
| --- | --- | --- |
| `ai/agent_ai_mark.dart` | 退役候选 | 现有首页 AI 入口；移植入口尺寸/语义/点击测试后删除旧实现（不是服务商卡） |
| `ai/agent_brand_mark.dart` | 归位 App 适配 | APP/ai/chat/widgets/agent_brand_mark.dart |
| `ai/agent_chat_shell.dart` | 归位 App 适配 | APP/ai/chat/widgets/agent_chat_shell.dart |
| `ai/agent_empty_conversation.dart` | 归位 App 适配 | APP/ai/chat/widgets/agent_empty_conversation.dart |
| `ai/agent_entry_card.dart` | 退役候选 | 现有首页 AI 入口；移植入口尺寸/语义/点击测试后删除旧实现（不是服务商卡） |
| `ai/agent_execution_timeline.dart` | 归位 SDK 适配 | APP/ai/chat/bindings/agent_execution_timeline.dart |
| `ai/agent_follow_up_questions.dart` | 归位 SDK 适配 | APP/ai/chat/bindings/agent_follow_up_questions.dart |
| `ai/agent_markdown_text.dart` | 专项归组 | flutter_agent_ui/src/markdown/agent_markdown_text.dart |
| `ai/agent_tool_authorization_dialog.dart` | 归位授权流程 | APP/ai/bindings/agent_tool_authorization_dialog.dart |
| `ai/ai_privacy_consent_dialog.dart` | 归位授权流程 | APP/ai/bindings/ai_privacy_consent_dialog.dart |
| `ai/bill_card_widget.dart` | 归位 App 适配 | APP/ai/chat/widgets/bill_card_widget.dart |
| `ai/typewriter_text.dart` | 抽纯展示 | UI/motion/typewriter_text.dart |
| `analytics/analytics_summary.dart` | 退役候选 | 复用 business_ui/insights 下 BeeAnalyticsSummary/BeeAnalyticsRankingList 后删除 |
| `analytics/category_rank_row.dart` | 退役候选 | 复用 business_ui/insights 下 BeeAnalyticsSummary/BeeAnalyticsRankingList 后删除 |
| `biz/account_selector.dart` | 归位 App 适配 | APP/shared/selectors/account_selector.dart |
| `biz/amount_editor_sheet.dart` | 归位并分离控制器 | APP/transaction/recording/bindings/amount_editor_sheet.dart |
| `biz/amount_text.dart` | 归位 App 适配 | APP/shared/formatting/amount_text.dart |
| `biz/app_empty.dart` | 复用后退役 | 复用 beecount_ui 的 BeeEmptyState/BeeSurface/BeeInlineLabel；迁完引用删除 |
| `biz/app_list_tile.dart` | 迁移旧测试后退役 | 复用 beecount_ui/BeeMenuRow；更新 smart_billing_attachment_settings_test 的等价断言 |
| `biz/attachment_picker.dart` | 复用后退役 | 复用 BeeAttachments/RecordingAttachmentControl 与 pages/attachment/bindings |
| `biz/bee_icon.dart` | 复用后退役 | 复用 beecount_business_ui/app_profile/brand_mark.dart |
| `biz/biz.dart` | 移除大桶 | 删除；调用方显式导入包 API 或所属 pages 适配文件 |
| `biz/category_selector_dialog.dart` | 归位 App 适配 | APP/shared/selectors/category_selector_dialog.dart |
| `biz/day_section_header.dart` | 归位 App 适配 | APP/main/home/widgets/day_section_header.dart |
| `biz/format_money.dart` | 合并格式工具 | lib/utils/format_utils.dart（或同目录 format_money.dart 的单一入口） |
| `biz/home_budget_summary.dart` | 归位 App 适配 | APP/main/home/widgets/home_budget_summary.dart |
| `biz/info_tag.dart` | 复用后退役 | 复用 beecount_ui 的 BeeEmptyState/BeeSurface/BeeInlineLabel；迁完引用删除 |
| `biz/ledger_card.dart` | 归位 App 适配 | APP/main/ledgers/widgets/ledger_card.dart |
| `biz/ledger_picker_sheet.dart` | 归位 App 适配 | APP/shared/selectors/ledger_picker_sheet.dart |
| `biz/ledger_selector_dialog.dart` | 归位 App 适配 | APP/shared/selectors/ledger_selector_dialog.dart |
| `biz/login_2fa_challenge_view.dart` | 拆分后归位 | APP/auth/bindings/login_2fa_challenge_view.dart + business_ui/app_profile/auth 的受控内容 |
| `biz/note_picker_dialog.dart` | 归位 App 适配 | APP/transaction/recording/bindings/note_picker_dialog.dart |
| `biz/pin_entry_pad.dart` | 退役候选 | 复用 business_ui/BeePinPad，确认无隐式原生入口后删除 |
| `biz/product_promo_card.dart` | 拆分后归位 | business_ui/app_profile/support/promo_card.dart + lib/services/marketing/product_promo_launcher.dart |
| `biz/section_card.dart` | 复用后退役 | 复用 beecount_ui 的 BeeEmptyState/BeeSurface/BeeInlineLabel；迁完引用删除 |
| `biz/tag_chip.dart` | 复用后退役 | 复用 business_ui/resources/tags/tag.dart；必要尺寸枚举在调用方投影 |
| `biz/transaction_list.dart` | 归位 App 适配 | APP/main/home/bindings/transaction_list.dart |
| `biz/transaction_list_item.dart` | 归位 App 适配 | APP/shared/transactions/transaction_list_item.dart |
| `biz/transaction_receipt_dialog.dart` | 归位 App 操作 | APP/transaction/detail/bindings/transaction_receipt_dialog.dart |
| `biz/transaction_row_title.dart` | 抽纯文本组合 | BIZ/transactions/transaction_row_title.dart |
| `category/category_selector.dart` | 退役候选 | 由 pages/shared/selectors + BeeCategoryPicker 替代后删除 |
| `category_icon.dart` | 归位 App 适配 | APP/shared/resources/category_icon_adapter.dart |
| `charts/account_category_pie_chart.dart` | 退役候选 | 已有 BeeDonutChart/BeeAssetComposition/BeeAnalyticsProportion；核对需求后删除旧链 |
| `charts/asset_composition_chart.dart` | 退役候选 | 已有 BeeDonutChart/BeeAssetComposition/BeeAnalyticsProportion；核对需求后删除旧链 |
| `charts/category_pie_chart.dart` | 退役候选 | 已有 BeeDonutChart/BeeAssetComposition/BeeAnalyticsProportion；核对需求后删除旧链 |
| `charts/line_chart.dart` | 迁移旧测试后退役 | 复用 beecount_ui/BeeLineChart；迁移 v4_line_chart_test 断言 |
| `currency/currency_flag.dart` | 拆分映射与展示 | APP/shared/currency/currency_flag.dart + 现有币种选择器的 leading Widget |
| `currency/currency_picker_sheet.dart` | 归位 App 适配 | APP/shared/selectors/currency_picker_sheet.dart |
| `posters/annual_report_poster.dart` | 拆分后归位 | APP/report/annual/bindings/annual_poster_projection.dart + business_ui/sharing/annual_poster.dart |
| `posters/app_promo_poster.dart` | 保留投影，统一纯布局 | APP/shared/sharing/bindings/app_promo_poster.dart + 现有 business_ui/sharing 纯布局 |
| `posters/ledger_summary_poster.dart` | 保留投影，统一纯布局 | APP/shared/sharing/bindings/ledger_summary_poster.dart + 现有 business_ui/sharing 纯布局 |
| `posters/month_summary_poster.dart` | 保留投影，统一纯布局 | APP/shared/sharing/bindings/month_summary_poster.dart + 现有 business_ui/sharing 纯布局 |
| `posters/poster_projection.dart` | 归位 App 投影 | APP/shared/sharing/bindings/poster_projection.dart |
| `posters/transaction_receipt.dart` | 保留投影，统一纯布局 | APP/shared/sharing/bindings/transaction_receipt.dart + 现有 business_ui/sharing 纯布局 |
| `posters/user_profile_poster.dart` | 保留投影，统一纯布局 | APP/shared/sharing/bindings/user_profile_poster.dart + 现有 business_ui/sharing 纯布局 |
| `posters/year_summary_poster.dart` | 保留投影，统一纯布局 | APP/shared/sharing/bindings/year_summary_poster.dart + 现有 business_ui/sharing 纯布局 |
| `transaction/transfer_form.dart` | 归位 App 适配 | APP/transaction/recording/bindings/transfer_form.dart |
| `ui/bee_multi_select.dart` | 复用后退役 | 复用 packages/beecount_ui/lib/multi_select.dart |
| `ui/bee_popup_menu.dart` | 迁移旧测试后退役 | 复用 beecount_ui 的 BeeContextMenu/BeeSegmented 等现有API |
| `ui/capsule_switcher.dart` | 迁移旧测试后退役 | 复用 beecount_ui 的 BeeContextMenu/BeeSegmented 等现有API |
| `ui/dialog.dart` | 归位 App 适配 | APP/shared/dialogs/app_dialogs.dart |
| `ui/feature_dot.dart` | 拆分后归位 | APP/shared/widgets/feature_dot.dart + beecount_ui 的受控提示点 |
| `ui/message_popover_menu.dart` | 兼容入口迁移后删 | 直接调用 beecount_ui/showBeeContextMenu；触觉由页面操作层触发 |
| `ui/page_skin_scope.dart` | 抽纯展示 | UI/appearance/page_skin_scope.dart |
| `ui/primary_header.dart` | 归位 App 适配 | APP/shared/appearance/primary_header.dart |
| `ui/searchable_dropdown.dart` | 复用后退役 | 简单选择复用 BeeSelectField；需要搜索时复用 BeeSearchField + BeeSheet/列表（如现有分类、标签选择器）；旧浮层下拉无使用需求则退役 |
| `ui/skeleton.dart` | 复用后退役 | 复用 beecount_ui/src/form_components.dart 的 BeeSkeleton；旧延迟/呼吸骨架无使用需求，作为退役候选，不为它新造组件 |
| `ui/skin_animation_scope.dart` | 归位 App 适配 | APP/shared/appearance/skin_animation_scope.dart |
| `ui/speed_dial_fab.dart` | 归位导航DTO | APP/shared/navigation/quick_add_actions.dart |
| `ui/toast.dart` | 兼容入口迁移后删 | 直接调用 beecount_ui/showBeeToast 与 showBeeToastOnOverlay |
| `ui/ui.dart` | 移除大桶 | 删除；调用方显式导入基础包或所属 pages 适配文件 |
| `ui/wheel_date_picker.dart` | 归位 App 适配 | APP/shared/pickers/wheel_date_picker.dart |
| `ui/wheel_picker.dart` | 复用后退役 | 复用 beecount_ui/src/foundations.dart 的 BeeWheel<T>；弹层用 BeeSheet/showBeeSheet，草稿与确认/取消结果由 App 适配保留 |
| `ui/wheel_time_picker.dart` | 归位 App 适配 | APP/shared/pickers/wheel_time_picker.dart |

三个旧基础控件需要分别看待：骨架的现有能力是 `form_components.dart` 中的 `BeeSkeleton`，不是选择器；它目前是静态占位，不能声称与旧延迟/呼吸骨架完全等价。旧骨架没有实际消费者，不为保留未使用的动画新增组件。简单选择用 `BeeSelectField`，搜索选择复用 `BeeSearchField` 与现有弹层/列表组合；`BeeSelectField` 自身不提供搜索。滚轮复用受控 `BeeWheel<T>`，确认/取消及 App 本地化继续由适配层负责。

`transaction_row_title.dart` 已核对为纯参数文件：没有 import，只含结果 DTO 和 `composeTransactionRowTitle(mode, categoryName, title)` 的字符串组合，可整体迁入业务包。分类显示名的本地化、账单数据投影及用户偏好读取仍保留在 App 调用方，不随这个辅助函数进入包。

这张表不表示要给每个文件再套一层包装。`toast.dart`、`message_popover_menu.dart` 已是薄转发，最终应让调用方直接使用现有包 API；App 仅负责触觉、本地化和操作结果。已有的 `BeeMultiSelect`、`BeeSurface`、`BeeMenuRow`、`BeeLineChart` 不再复制。

`AnnualReportPoster` 仍包含完整章节组合和 App 数据投影，应先把纯海报章节布局补到 sharing，历史金额与 Q20 已确认的时间口径继续由 App 处理。其他海报包装多已调用 `Bee*Poster`：只归位 App 投影即可，不能把数据库模型、二维码活动链接、`intl` 本地化一起塞进包。真正的捕获、编码、保存、系统分享继续留在现有导出服务。

`AgentMarkdownText` 依赖 `flutter_markdown_plus`。先核对已有 `flutter_agent_ui` 的 Markdown 能力和依赖许可，再决定复用或迁入该 SDK；它不是给 BeeCount 业务包新增整套 Agent 依赖的理由。

## 二、`beecount_business_ui` 怎么分组

建议 10 个一级目录。目录按用户业务找组件，不按 `card` / `list` / `picker` 把所有领域重新打散。资源下允许 accounts / categories / ledgers 等二级目录。不要求一组件一文件，不以页面行数作为拆分目标。

```text
packages/beecount_business_ui/lib/
  beecount_business_ui.dart      # 保留根公开入口
  transaction_detail.dart       # 已有稳定专题入口继续保留
  share_posters.dart             # 仅调整 export 指向
  src/
    shared/                     # 真正跨业务的展示原语
    recording/                  # 金额键盘、表单、转账、快捷记账
    transactions/               # 交易行、详情、搜索、日历、批量
    resources/
      accounts/ categories/ ledgers/ tags/ attachments/ currency/ detail/
    insights/                   # 洞察、资产图表、预算
    automation/                 # 周期账单、提醒、平台自动记账
    assistant/                  # AI 对话、服务商、授权内容展示
    cloud_data/                 # 云同步、备份、导入导出、维护展示
    sharing/                    # 小票、年度账单、分享卡纯布局
    app_profile/                # 品牌、我的、欢迎、皮肤、安全展示
```

77 个现有 src 文件全部在 JSON 中映射；普通文件保持文件名，进入下表领域目录；6 个历史聚合文件按下一表处理。

| 分组 | 现有归类文件数¹ | 内容与资源定位 |
| --- | ---: | --- |
| `shared` | 4 | 仅共享金额/详情/操作等纯展示；不作为“放不下的文件”目录 |
| `recording` | 8 | recording_*、transfer_components、quick_add_*、备注偏好、记账说明 |
| `transactions` | 10 | transaction_*、detail_currency_notice、search、calendar、journal |
| `resources` | 18 | accounts 六文件；categories 三文件；ledgers、tags、attachments、currency 及资源详情 |
| `insights` | 6 | analytics_*、asset_*、budget_components、chart_components |
| `automation` | 5 | auto_billing、recurring_*、reminder_preferences |
| `assistant` | 6 | ai_*、assistant_conversation、execution_depth_picker |
| `cloud_data` | 8 | cloud_*、configuration、file_transfer、maintenance、transaction_import/export |
| `sharing` | 5 | annual_report、receipt、share_card、share_poster_* |
| `app_profile` | 7 | brand_mark、home_layout、onboarding、security、skin_card、splash、support |

¹ 数字是 77 个现有文件的归类，不是拆分后的文件数。finance/detail/workflow 与 card_refinements 暂列 shared，selector/picker 暂列 resources；拆分后各部分进入正确领域。`resource_components`、`resource_parent_link` 归 `resources/detail`。

| 现有聚合文件 | 明确拆分 / 改名目标（相对 src） |
| --- | --- |
| `finance_components.dart` | `shared/money`；`resources/categories/category_icon`；`resources/ledgers/ledger_card`、`ledger_balance`；`cloud_data/sync_status`；`app_profile/home_identity`、`profile`、`home_summary`；`insights/category_ranking` |
| `detail_components.dart` | `shared/detail_list`；`resources/accounts/account_card`；`insights/budget_card`；`assistant/chat_message`、`execution_timeline`；`app_profile/pin_pad` |
| `workflow_components.dart` | `resources/attachments/attachments`；`cloud_data/import_mapping`；`sharing/receipt`、`annual_summary`；`insights/bar_chart`；`shared/action_menu`；`recording/quick_add`；`assistant/authorization`；`transactions/batch_bar` |
| `selector_components.dart` | `resources/categories/category_picker`、`resources/accounts/account_picker`、`resources/ledgers/ledger_picker`；`recording/subcategory_grid` |
| `picker_components.dart` | `resources/tags/tag_picker`；`resources/currency/currency_picker` |
| `card_refinements.dart` | 当前只有 `BeeSyncHealthHeader`，改名为 `cloud_data/sync_health_header.dart`，不保留模糊名字 |

以上是按职责拆文件，不要求改变类名、构造器、状态或业务行为。图表如需保留业务标注可放 insights，完全通用的底层绘制再复用基础包，不同时维护两套折线图。

### 公开 API 与依赖约束

- 保留 `beecount_business_ui.dart` 和现有 `annual_report.dart`、`transaction_detail.dart`、`share_posters.dart` 等专题 barrel 的公开导入路径，只更新 export 指向。以后可加 `accounts.dart` 等领域入口，不删除现有使用者的入口。
- App、测试、gallery 使用包公开入口，不 import `package:.../src/...`。包内部使用明确的相对依赖，避免从内部反向 import 自己的根 barrel，导致无意的大范围循环依赖。
- 不在旧 src 平铺目录永久保留 77 个转发文件：兼容的是公开 API，不是私有实现路径。必要的短期转发只跨一个迁移批次，随后删掉。
- `beecount_ui` 不依赖 business-ui / App；business-ui 只依赖基础包与已有允许的 Flutter 依赖。Riverpod、Drift、HTTP、云 SDK、权限、本地化、系统 I/O 不进入两个展示包。
- 真实数据 gallery 的 binding 在 App / dev 内；包自带示例使用合成状态。真实数据映射仍走现有 Provider / Repository，不增第二套查询、缓存或资金计算。

## 三、`presentation/v4` 回到 pages 的具体落点

共 **135 个生产文件回到 pages，73 个开发文件回到 dev**。JSON 的 `presentation` 数组逐文件列出 source、target、partOwner、直接生产/测试引用，覆盖当前 208 个文件，目标互不冲突。

| 当前职责 / 文件族 | 归位规则 |
| --- | --- |
| `home_*`、`analytics_*`、`mine_*`、`ledger_*` | `pages/main/{home,analytics,mine,ledgers}/{bindings,widgets}` |
| `account_detail*`、`account_edit*`、`account_sections`、`account_overview`、`assets_card_actions`、`net_worth_trend` | `pages/account/{detail,edit,overview,net_worth}/{bindings,widgets,controllers}` |
| `recording_*`、`transfer_inline_accounts` | `pages/transaction/recording/{bindings,widgets}`；纯分类格子仍在业务包 |
| `transaction_detail*` | `pages/transaction/detail/bindings` |
| `transaction_search*`、`transaction_batch`、`search_results` | `pages/transaction/search/bindings` |
| `recurring_*` | `pages/transaction/recurring/bindings`，与既有周期账单页面同域 |
| `category_detail*` | `pages/transaction/category_detail/bindings`，保持当前分类详情入口路径 |
| `category_management*`、`category_migration*`、分类编辑/icon 目录与草稿 | `pages/category/{manage,migration,editor}/{bindings,controllers}` |
| `tag_*` | `pages/tag/{detail,manage,editor}/{bindings,widgets}` |
| `budget_*`、`calendar_*` | `pages/budget/{overview,editor}`、`pages/calendar/{bindings,widgets}` |
| `ai_*`、`assistant_settings_controls` | `pages/ai/{chat,settings,providers,prompt,activity,memory,permissions,assistant}`，controller 保持同域 |
| `cloud_*` | `pages/cloud/{backup,configuration,shared}/bindings` |
| `import_*`、`export_*`、`exchange_rate_*` | `pages/data/{import,export}/bindings`、`pages/currency/exchange_rates/bindings` |
| `attachment_source`、`attachment_viewer` | `pages/attachment/{bindings,widgets}` |
| 附件库/迁移、维护日志/存储、配置迁移、外观、字号、提醒、关于/帮助/快捷指令 | 对应 `pages/settings/{attachments,logs,storage,configuration,appearance,font,reminders,about,support,shortcuts}` |
| `auto_billing_actions`、`ios_auto_billing_actions` | `pages/automation/{android,ios}/bindings` |
| `welcome_*`、`pin_verification`、`app_lock_settings_actions` | `pages/auth/welcome`、`pages/auth/bindings`、`pages/settings/app_lock/bindings` |
| `annual_report_sections`、`share_card_*`、捐赠与孤儿清理 | `pages/report/{annual,share}`、`pages/donation/bindings`、`pages/maintenance/orphans/bindings` |
| 页面框架、皮肤组合、跨页交易投影、资源周期控制、币种明细 | `pages/shared/{scaffold,appearance,transactions,resources,currency,selectors}`；只放真正跨页的 App 适配 |
| `gallery/**` 40 个文件 | `lib/dev/component_gallery/**`，保留内部相对结构 |
| `bindings/*preview*.dart` 33 个文件 | `lib/dev/component_gallery/bindings/<原名>`；已核对没有 gallery / preview 之外的生产消费者 |
| `sections` 2 个文件 | `pages/settings/font/widgets`、`pages/settings/appearance/widgets` |

实施时使用 JSON 的明确映射，不仅凭名称正则搬文件。例如 `live_business_preview` 虽会查询真实数据，消费者仍是验收页面，属于 dev；`recording_category_icon` 被多个页面使用，落 pages/shared。文件确实只有一个页面消费时就归该页面，不为了目录对称再加 shared。

### 搬迁中不能漏掉的关联

- 当前有 **18 个 `part of` 文件**。必须与所属 library 同一批搬迁，调整 `part` / `part of`；保留私有成员的同库访问。`recurring_editor_actions` 与 editor controls、provider editor 等不能机械改成普通 import 来“消除报错”。
- 现有 Page 类、构造参数、Key、路由、Provider 身份和生命周期保持不变。原页面只有路径 import 需要更新。目录收回与 `V4*` 类名去前缀分开做，避免同时改变符号、路径和行为。
- `bindings` 承担 App 数据和事件适配；`controllers` 只放真实状态/保存编排；`widgets` 是页面专用组合。不规定每个页面三目录齐全，也不为减少行数新增无意义的委托类。
- 保持组件 gallery 的两页 Flutter 入口、平铺与定位、真实数据演示；开发入口只在原有调试条件下提供，不给正式用户增加入口。

## 四、测试、脚本与设计稿关联

单纯改 Dart import 不够，以下已存在路径假设：

| 位置 | 必须同步的内容 |
| --- | --- |
| `tool/v4/verify_component_coverage.py`、`test_verify_component_coverage.py` | gallery 路径常量及负向测试复制夹具；包源码已经 rglob 递归扫描，业务包分目录本身无需放宽覆盖规则 |
| `tool/v4/verify_maintenance.py`、`verify_transaction_import.py`、`verify_ai_advanced.py`、`verify_cloud_backup.py`、`verify_cloud_configuration.py`、`verify_cloud_shared.py` | bindings 与包 src 的文件名/目录假设 |
| `tool/v4/generate_category_line_icons.cjs` | 图标数据生成目标归 category/editor，不再写旧 bindings |
| `tool/release/local_apk.py` | 源码路径引用/检查规则，确保本地包验收还在检查新位置 |
| `docs/design/card-refresh/prototype/build.cjs`、`prototype/src/auto-billing-samples.cjs` | 读取主题色选项、iOS 自动记账样例的旧路径 |
| `docs/design/card-refresh/scripts/build-guide.cjs` | gallery 来源与中文标签提取路径；现有解析还假设 switch 的结构，不能搬迁时丢样例 |
| 测试、包 README、组件覆盖文档、设计指南链接 | 公开 API/实际样例入口更新；HTML 应从源文件重建，不手改生成物 |
| 页面迁移清单生成器 | 不把新增 pages/*/bindings、widgets、controllers 文件计成新页面，只统计真实页面入口 |

当前硬编码工具文件列表也保存在 JSON。改脚本应更新路径或集中路径常量，不能通过忽略文件、降低组件数量、删除负向测试来通过检查。

## 五、建议实施顺序与删除门槛

主线视觉修正和真机验收先继续；本计划不在修 bug 的同一提交里大规模搬目录。

| 批次 | 范围 | 可验证结果 |
| --- | --- | --- |
| 0：固定基线 | 保存路径清单与当前引用，确认主线修正已有可回退提交 | 可以按业务批次核对；不覆盖并行改动 |
| 1：包内归组 | 保留公开 barrel，先搬单一职责文件，再按 5 个跨域聚合文件拆分；更新包内引用与覆盖工具 | 公开 API 与组件状态保持；包可独立 analyze / test；不引入 App 依赖 |
| 2：旧兼容退役 | 先处理 7 个无生产/测试候选，迁旧测试；桶导出改显式依赖；toast/menu 等调用方直用现有包 | 确认入口与断言保留，减少重复实现；没有新增第二份 UI |
| 3：按业务一起归位 | 记账/交易 → 资源详情 → 洞察/首页/我的 → 云数据/设置 → AI/分享；每批同时迁本域 widgets 与 presentation | 每批有明确路由和数据回归；避免先挪 widgets 再挪 binding 导致改同一引用两次 |
| 4：开发验收归位 | gallery 40 + preview 33，生成器、设计来源、测试夹具一并更新 | Flutter 两页验收与 HTML 对照仍完整，真实数据只在 App 适配 |
| 5：删空目录与兼容 | 全局检查旧路径引用、native/工具入口及全部测试 | 删除空的 widgets / presentation/v4；不保留长期平铺转发 |

旧源码备份 `.docs/v4-ui-migration/backup` 按用户要求继续保留，不能放回 `lib` 参与运行，也不在本轮审计中删除。Git rename 和分批提交提供代码对照；不需要维护两套活跃页面来对比。备份删除是准备正式上线时的独立动作。

完成标准：

- [ ] `lib/widgets` 与 `lib/presentation/v4` 的生产/开发内容都有唯一归属，目录已空或删除；`lib/widget` 桌面能力仍正常。
- [ ] 旧 import/export/part 路径在代码、测试、脚本、设计生成源中已消除；只有历史备份/迁移记录允许保留旧路径。
- [ ] 现有包公开导入入口保持兼容；两个包没有 App、Provider、数据库、网络或平台权限依赖。
- [ ] 每个退役组件的有效行为断言迁入现用实现；组件覆盖和负向检查继续通过，没有跳过规则。
- [ ] 相关 widget / 单元测试、静态分析、生成器检查通过；按业务批次在现有统一隔离环境回归真实路由、保存与返回状态。
- [ ] HTML 组件规范与 Flutter gallery 同步；分类/账户/标签/账本选择、交易多状态等验收入口可找到。
- [ ] 没有因为目录搬迁改变金融计算、用户偏好、权限或数据；没有移动/清空用户或隔离验收数据。

本文件是后续实施方案，不代表上述迁移或验收已经完成。它补充 [presentation 归位计划](v4-presentation-consolidation-plan.md) 与 [组件包覆盖文档](v4-component-packages.md)；后续实施时以新的逐文件清单重新核对工作树变化。
