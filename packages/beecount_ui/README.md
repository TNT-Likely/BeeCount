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

页面皮肤材质：`BeePageMaterial` 为卡片统一提供40%半透明 surface，`BeeCardTheme.overlay` 保持弹窗/弹层/菜单不透明；普通模式不变。`BeeSceneScope` / `BeeSceneController` 只报告首张大卡的文档坐标，不读取业务文字，不参与布局，滚动和卡片离开缓存时不重置场景。App 自己提供免费皮肤画层、偏好与生命周期。真实材质开关及弹层示例位于基础组件第24组（HTML F27），完整组合见[交互稿](https://github.com/TNT-Likely/BeeCount-Design/blob/main/card-refresh/boards/skins-page-material-review.html)。

悬浮导航使用不透明底色及独立重绘边界，保留原版 Tab 装饰与前景控件，避免动态皮肤、列表和磨砂采样一起重绘时闪烁。页面卡片仍使用统一的半透明材质。

`BeeButton` 的图标与文字共用同一前景色及禁用色，亮暗模式、按下和禁用状态保持一致。

`BeePageMaterial` 接收 `opacity`（0.1–1，默认0.4）与 `blur`（0–16，默认0），只改变皮肤卡片材质。`BeeSurface` 为外层半透明卡片裁切模糊，嵌套卡片不重复滤镜，默认和不透明卡片不创建滤镜。弹层、对话框与底栏保持不透明。`BeeMaterialControls` 是受控滑杆与重置操作；`BeeMaterialPreview` 只在限定示例范围内预览背景和卡片。偏好持久化与导入导出由App绑定负责，基础包不读本地存储。
