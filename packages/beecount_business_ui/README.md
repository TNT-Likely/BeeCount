# beecount_business_ui

V4 业务展示组件包。仅依赖 Flutter 和 `beecount_ui`，不依赖主 App、Riverpod、数据库、HTTP 或 Cloud SDK。

- 记账：`RecordingAmountCard`、`RecordingCategoryTile`、`RecordingSubcategoryChip`、`RecordingKeypad`。
- 明细与统计：`BeeMoney`、`BeeTransactionRow`、`BeeBatchBar`、`BeeSummaryCard`、`BeeCategoryRanking`、`BeeBarChart`、`BeeDonutChart`、`BeeTrendChart`。
- 分类与选择：`BeeCategoryIcon`、`BeeTag`、`BeeTagPicker`、`BeeChoicePicker<T>`、`BeeCurrencyPicker`、`BeeValidatedInput`、`BeeDateWheels`。
- 账本与资料：`BeeLedgerCard`、`BeeLedgerBalance`、`BeeSyncStatus`、`BeeHomeIdentity`、`BeeProfile`。
- 流程：`BeeAttachments`、`BeeAttachmentViewer`、`BeeImportMapping`、`BeeOnboardingStep`、`BeeAuthorization`、`BeeReceipt`、`BeeAnnualSummary`、`BeeActionMenu`、`BeeQuickAdd`、`BeeQuickAddTrigger`。

数据通过不可变展示模型、格式化字符串与 `ImageProvider` 传入，事件通过回调交还宿主。金额、币种精度、汇率快照和余额语义由宿主计算。包内只维护局部 UI 草稿（如标签搜索、多选、有效日期和输入校验）；关闭不提交。

`BeeTransactionRow.onDeleteRequested` 只通知宿主请求删除；宿主负责确认、持久化及从列表移除。分类图标与账单内容是独立点击区。操作菜单由调用方通过长按接入，交易行不显示省略号按钮。滑动露出 78px 删除按钮（12px 圆角裁切），点击后才请求宿主确认；反向滑动或点击行可收回。小票的账户/账本字段可不传以保护分享隐私。

同步状态、加载和失败均由上层传入，不在 widget 中发请求。权限可见性由宿主先过滤操作列表；破坏性操作仍需宿主确认。

App 内验收：[ComponentGalleryPage](../../lib/presentation/v4/gallery/component_gallery_page.dart)。完整映射：[组件覆盖文档](../../docs/development/v4-component-packages.md)。

详情与扩展：`BeeDetailList`、`BeeAccountCard`、`BeeBudgetCard`、`BeeChatMessage`、`BeeExecutionTimeline`、`BeePinPad`。这些组件只处理输入与展示，认证、网络和写入仍由宿主负责。

`RecordingDetailsCard` 提供固定在键盘上方的两行表单，备注、账户、日期、标签、附件由宿主传入；小屏支持备注折叠与直接展开编辑。`BeeTag(compact: true)` 保留 21px 可见色块，选择器默认使用 44px 选择项。

`RecordingConversionSummary` 保持左侧说明、右侧金额/箭头的双列紧布局；短金额、长金额、小屏、大字体均固定右边界。汇率和折算数值由宿主提供。
