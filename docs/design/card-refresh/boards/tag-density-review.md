# 紧凑标签 · 设计确认稿

状态：待用户确认，只新增独立 HTML Demo，没有修改 Flutter 或主交互稿。

打开：<http://127.0.0.1:8374/boards/tag-density-review.html>

建议采用：详情 21px 视觉胶囊，选择器 26px 视觉胶囊；两者的可点击区域均至少高 44px，宽至少 44px。颜色只覆盖胶囊，不把触摸区域画成大色块。

## 依据

- `packages/beecount_business_ui/lib/src/finance_components.dart`：当前 `BeeTag` 可点击且不为 compact 时会进入 44px 的彩色样式。compact / 只读展示为 21px。
- `packages/beecount_business_ui/lib/src/picker_components.dart`：`BeeTagPicker` 具备最近使用、全部、搜索、多选、清空、确认、新建等能力。
- `lib/pages/tag/widgets/tag_selector.dart`：对接真实标签、最近使用、创建权限及本地选择草稿。
- `lib/presentation/v4/bindings/transaction_detail_controls.dart` 与业务 UI 的 `transaction_detail.dart`：详情标签具备独立跳转与只读来源。

## 本稿中的交互

- 账单详情：最多展示 5 个标签，更多使用 `+N`；点击任意标签查看完整名称；点击编辑进入选择器。
- 选择器：保留最近使用 / 全部标签、搜索、多选、选中勾、标签本身的颜色。长标签最多占两行，以完整名称为先。
- 选中状态使用该标签的描边和勾，不只依赖颜色；停用标签使用锁图标与 disabled 属性。停用标签为压力测试示例状态，最终可用性仍由真实业务权限决定。
- 清空只修改草稿；取消、遮罩点击、Escape 不修改详情；确认才回写。可以创建示例标签再确认。
- 很多标签的列表独立滚动；底部操作保持可见；支持键盘 Tab 循环与 Escape。
- 可切换 398×844 / 320×568、浅色 / 深色及 3 个主题色。可开启虚线显示透明点击区域。详情页没有底部导航；没有改变任何底部导航尺寸。

## 验收

Chrome / Playwright 检查 398 与 320 两种宽度 × 浅深主题四个组合：搜索命中与空结果、停用状态、清空取消回滚、确认、18 标签展开、长名换行与滚动、无横向溢出。原始标签名保留，视觉胶囊为 21px / 26px（长名允许到 44px）。

仅使用合成数据。没有接入真实账户、数据库或写入产品设置。
