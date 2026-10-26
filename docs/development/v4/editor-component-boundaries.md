# 账户选择与金额编辑的组件边界

这两个 App 入口保留兼容的类名和参数。它们是数据、草稿与业务流程的绑定层，纯视觉组件由 `beecount_business_ui` 提供。

| App 绑定保留 | 组件包负责 |
| --- | --- |
| Repository、共享账本身份、币种过滤、隐藏账户钉住、LRU 顺序和使用记录 | `BeeAccountStrip` 的横向账户、选中、加载、空态；`BeeAccountPicker` 的完整搜索界面 |
| Cloud 作者查询、创建/编辑者角色判断、隐藏自己的头像、解析头像地址 | `RecordingAuthors` 的头像组、回退字形和角色 Tooltip |
| 币种选择、汇率读取与手动修改、历史折算快照 | `RecordingCurrencyControl`、`RecordingConversionSummary`、`RecordingConversionHint` |
| 账本选择与草稿丢弃确认 | `RecordingLedgerControl` |
| 备注控制器、焦点、历史备注读取与选择 | `RecordingNoteField`、`RecordingNoteToggle` |
| 账户与日期选择、标签关联、附件选择/权限/预览 | `RecordingAccountControl`、`RecordingMetaControl`、`RecordingTagSummary`、`RecordingAttachmentControl`、`RecordingTagAttachmentBar` |
| 排除统计/预算的业务可用性与值 | `RecordingFlagControl` |
| 算术状态、除零处理、系统音效、震动、连续记账计时、提交与错误重试 | `RecordingKeypad`、`RecordingLegacyKeypad`、`RecordingActions` |
| 系统键盘是否显示、屏幕密度、返回确认 | `RecordingFrame` 的固定区域、分类滚动区和底部间距；`RecordingAmountCard`、`RecordingDetailsCard` 的卡片样式 |

组件只接收值、Widget 槽位和回调，不读取 Riverpod、Repository、Cloud 服务、持久化偏好或 App 本地化对象。账户和头像图像仍由 App 解析后传入，包内不理解账户类型或用户身份。

## 兼容与验收

- `AccountSelector` 继续支持原有横向入口及 `expandedPicker`；实际筛选、排序与回调行为不变。
- `AmountEditorSheet` 同时保留新版卡片和旧弹窗入口。此次没有把计算器、保存、权限处理搬进 UI 包。
- Flutter 业务组件验收页第 6 组使用这些真实组件，包含固定表单、横向账户、空态、作者、旧键盘与标记。第 29 组保留完整账户选择器。
- HTML 主记账页保留已确认的布局，标明同名组件边界；组件规范的金额、辅助信息、账户选择三组补齐加载、空态和作者示例。
- `v4_presentation_import_boundary_test.dart` 检查两个组件包的 App/状态管理依赖边界；`v4_editor_presentation_boundary_test.dart` 检查受控回调、头像回退、320/398 大字与分类独立滚动；`v4_account_strip_binding_test.dart` 用真实 SQLite 验证筛选、隐藏钉住、顺序和清空。
- 页面中仍然存在的确认弹窗是 App 业务流程，不意味着把整套流程封装为组件。它们继续使用基础包弹窗与表单组件。

本文件记录的是代码边界和局部验证范围，不能代替隔离真机的完整业务验收。
