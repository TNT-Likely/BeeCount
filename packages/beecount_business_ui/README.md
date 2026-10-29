# beecount_business_ui

V4 业务展示组件包。仅依赖 Flutter 和 `beecount_ui`，不依赖主 App、Riverpod、数据库、HTTP 或 Cloud SDK。

`lib/src` 按业务领域分组：`shared`、`recording`、`transactions`、`resources`、`insights`、`automation`、`assistant`、`cloud_data`、`sharing`、`app_profile`。`resources` 再按账户、分类、账本、标签、附件、币种和详情组织。

App 和验收页面继续使用根入口 `beecount_business_ui.dart` 或现有专题入口（如 `transaction_detail.dart`、`share_posters.dart`），不直接导入 `src`。包内按实际声明直接依赖领域文件，不依赖根 barrel；旧平铺私有文件已退役，没有保留第二套转发入口。真实查询和保存继续由 App binding 注入。

- 记账：`RecordingHeader`、`RecordingAmountCard`、`RecordingCategoryTile`、`RecordingSubcategoryChip`、`RecordingKeypad`。
- 明细与统计：`BeeMoney`、`BeeTransactionRow`、`BeeBatchBar`、`BeeSummaryCard`、`BeeCategoryRanking`、`BeeBarChart`、`BeeDonutChart`、`BeeTrendChart`。
- 分类与选择：`BeeCategoryIcon`、`BeeTag`、`BeeTagPicker`、`BeeChoicePicker<T>`、`BeeCurrencyPicker`、`BeeValidatedInput`、`BeeDateWheels`。
- 账本与资料：`BeeLedgerCard`、`BeeLedgerBalance`、`BeeSyncStatus`、`BeeHomeIdentity`、`BeeProfile`。
- 流程：`BeeAttachments`、`BeeAttachmentViewer`、`BeeImportMapping`、`BeeOnboardingStep`、`BeeAuthorization`、`BeeReceipt`、`BeeAnnualSummary`、`BeeActionMenu`、`BeeQuickAdd`、`BeeQuickAddTrigger`。

数据通过不可变展示模型、格式化字符串与 `ImageProvider` 传入，事件通过回调交还宿主。金额、币种精度、汇率快照和余额语义由宿主计算。包内只维护局部 UI 草稿（如标签搜索、多选、有效日期和输入校验）；关闭不提交。

`BeeTransactionRow.onDeleteRequested` 只通知宿主请求删除；宿主负责确认、持久化及从列表移除。分类图标与账单内容是独立点击区。操作菜单由调用方通过长按接入，交易行不显示省略号按钮。滑动露出 78px 删除按钮（12px 圆角裁切），点击后才请求宿主确认；反向滑动或点击行可收回。小票的账户/账本字段可不传以保护分享隐私。

同步状态、加载和失败均由上层传入，不在 widget 中发请求。权限可见性由宿主先过滤操作列表；破坏性操作仍需宿主确认。

App 内验收：[ComponentGalleryPage](../../lib/dev/component_gallery/component_gallery_page.dart)。完整映射：[组件覆盖文档](../../docs/architecture/presentation-packages.md)。

详情与扩展：`BeeDetailList`、`BeeAccountCard`、`BeeBudgetCard`、`BeeChatMessage`、`BeeExecutionTimeline`、`BeePinPad`。这些组件只处理输入与展示，认证、网络和写入仍由宿主负责。

`RecordingDetailsCard` 提供固定在键盘上方的两行表单，备注、账户、日期、标签、附件由宿主传入；小屏支持备注折叠与直接展开编辑。`BeeTag(compact: true)` 保留 21px 可见胶囊；选择器为 26px 胶囊，外部使用至少 44px 的透明触控区域。两行长名称可增高，选择颜色、勾、禁用与完整语义保持不变。`BeeTagPicker.disabledIds` 由宿主提供禁用项；清空和选择只改草稿，取消不提交。账户图片由宿主统一传入原色 `AccountTypeIcon`，主题色只标记选中边框。

`RecordingConversionSummary` 保持左侧说明、右侧金额/箭头的双列紧布局；短金额、长金额、小屏、大字体均固定右边界。汇率和折算数值由宿主提供。

`RecordingHeader` 使用基础包的紧凑 `BeeSegmented`，显示收支/转账类型、返回与更多操作。切换草稿前的确认和写入由 App 处理。生产记账页与平铺验收页面使用同一个组件；真实保存、共享资源引用与失败重试放在 App 的 `recording_save.dart` binding。

`BeeAccountFlowFilter` 提供账户流水方向、排序草稿和整行确认操作。App 持有筛选值，确认后才查询；基础 `BeeSelectField` 使用统一选择弹层。`BeeMoney.alignment` 默认右对齐，账户主余额显式左对齐，折算信息继续右对齐。

`RecordingSubcategoryGrid` 使用四列自适应布局：按实际字体与文字缩放测量，短名称一格，溢出名称两格，特别长的名称在两格内自然换行；不重排补洞。与记账页、更多分类和组件验收共用，选中／禁用／图标／分类详情及完整语义均保留；主记账页由 App 限高并独立滚动。

`BeeAccountTransactionTools` 统一账户流水标题、搜索与筛选入口、34px紧凑筛选胶囊及列表前的留白；`BeeAccountTransactionSearch` 在弹层内持有搜索控制器，等弹层完全卸载后释放，支持键盘提交、确认与取消草稿。查询仍由 App 在确认后执行。

账户主卡只在名称下展示一次类型与币种，底部保留净资产与关联账本。`BeeAccountTransactionTools.sortLabel` 明示当前排序，点击回到筛选；`BeeCategoryManagementList` 在分类行右侧显示48×60px抓取区及32×38px可见拖柄，使用立即拖动监听，名称与图标不再承担隐式长按排序。

`BeeTwoFactorChallengeDialog`（`app_profile/auth`）接收输入控制器、方法、错误与忙状态；验证码验证、授权与关闭结果留给 App。`BeePromotionCard` / `BeePromotionCompact` / `BeePromotionDialog` / `BeePromotionScreenshot` / `BeePromotionGallery`（`app_profile/support`）只展示宿主传入的产品与渠道状态，点击、复制、打开截图路由均以回调交还 App。两组使用根公开入口。

`share_posters.dart` 新增 `BeeAnnualReportPoster`、`BeeAnnualPosterChapter`、`BeeAnnualPosterMoment`：完整年度海报章节和间距在业务包，宿主提供已本地化、格式化、隐藏收入处理后的值及页眉页脚。账本年度范围、已发生天/月分母、汇率和原币交易投影仍只在 App 计算；预览和导出使用相同模型。

HTML 设计目录：[BeeCount-Design/card-refresh](https://github.com/TNT-Likely/BeeCount-Design/tree/main/card-refresh)。App 验证使用随源码提交的小型契约，不要求检出设计仓。
