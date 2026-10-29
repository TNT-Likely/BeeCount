# beecount_ui

V4 基础组件包。仅依赖 Flutter 和带 ISC 许可的 Lucide SVG（由 flutter_svg 渲染）。不访问 App 状态、数据库或网络。

- 主题与令牌：`beeTheme`、`BeeCardTheme`、`BeeUiTokens`、`BeeSurface`、`BeeLineIcon`。
- 操作与表单：`BeeButton`（主、次、危险、禁用、加载）、`BeeField`、`BeeSearchField`、`BeeToggleRow`、`BeeCheckTile`、`BeeSegmented`。
- 布局与反馈：`BeePageHeader`、`BeeSection`、`BeeMenuRow`、`BeeAvatar`、`BeeStatus`、`BeeEmptyState`、`BeeSkeleton`、`BeeProgress`。
- 弹层与导航：`BeeSheet`、`showBeeSheet`、`showBeeDialog`、`BeeWheel`、`BeeBottomBar`。

`BeeUiTokens` 与主 App 的旧 `BeeTokens` 名称区分，允许渐进混用。调用方可仅提供现有 ThemeData，`BeeCardTheme` 会按 brightness 回退；无须整体替换主题。图片保留原色、业务标签语义色独立于 accent。

所有用户文案由调用方本地化后传入。滚轮支持滚动、点击和上下键。用 `showBeeSheet` 容纳选择草稿，确认后再提交，关闭不写入。

App 内测试页：[ComponentGalleryPage](../../lib/dev/component_gallery/component_gallery_page.dart)。完整映射：[组件覆盖文档](../../docs/architecture/presentation-packages.md)。

补充控件：`BeeDialog` / `showBeeConfirm`、锚定上下文菜单、轻提示、折叠、筛选、单选、选择字段和滑杆。入口为调试版「我的 → 关于 → V4 组件验收」。

HTML 设计目录：[BeeCount-Design/card-refresh](https://github.com/TNT-Likely/BeeCount-Design/tree/main/card-refresh)。App 验证使用随源码提交的小型契约，不要求检出设计仓。

`TypewriterText` 属于基础动效组件：支持逐字播放、立即显示、文字更新、完成回调和卸载时取消计时器。真实示例位于基础组件第25组；宿主负责根据减少动态效果偏好选择播放方式。
