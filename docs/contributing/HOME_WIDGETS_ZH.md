# 桌面小组件开发规范

本文约定 BeeCount 新增和维护 iOS WidgetKit、Android App Widget 时必须遵循的结构、预览、测试与验收流程。目标是让两端展示一致，并避免“单测通过但桌面空白”“添加页没有预览”等回归。

## 1. 架构与数据流

BeeCount 的桌面小组件采用统一图片方案：

1. `WidgetDataService` 从当前账本读取数据。
2. `WidgetManager` 用 Flutter View 离屏渲染 PNG。
3. `home_widget` 将 PNG 路径写入共享存储。
4. iOS WidgetKit / Android AppWidgetProvider 读取并展示 PNG。
5. App 内发生记账、切账本、主题或语言变化时，重新生成图片并通知原生组件刷新。

因此，原生层“成功显示图片”不代表 Flutter 内容正确；验收时必须同时检查生成的 PNG 和真实桌面组件。

## 2. 新增组件的必改清单

### Flutter

- 在 `lib/widget/widget_spec.dart` 登记类型、尺寸、图片 key、iOS kind 和 Android provider。
- 在 `lib/widget/widget_data_service.dart` 增加可复用的数据模型与查询；一次更新批次内应复用查询结果。
- 在 `lib/widget/views/` 创建纯展示 View，不直接访问数据库、Provider、网络或插件。
- 在 `lib/widget/widget_manager.dart` 接入取数、渲染、图片落盘和原生刷新。
- 补齐 ARB 文案，并通过项目现有本地化生成流程更新生成文件。
- 在 `lib/pages/settings/widget_management_page.dart` 补充组件说明。

### iOS

- 在 `ios/BeeCountWidget/` 添加或扩展 `Widget`、`TimelineProvider` 和 EntryView。
- 在 `BeeCountWidgetBundle.swift` 注册新 kind。
- `placeholder` 和 `context.isPreview` 的 snapshot 必须使用 `WidgetPreviewAssets` 中的 bundle 静态图片；不要依赖 App Group 运行时图片。
- 在 `WidgetPreviewAssets.swift` 登记 image key 到预览资源名的映射。
- 确认 URL Scheme、App Group、supportedFamilies 和 Flutter spec 完全一致。

### Android

- 添加 `AppWidgetProvider`、Manifest receiver、RemoteViews layout 和 `appwidget-provider` XML。
- XML 必须声明 `initialLayout`、`previewImage`、`resizeMode`、`widgetCategory`、`description` 和正确的最小尺寸。
- 默认与英文预览图必须同时存在于 `drawable-nodpi`、`drawable-en-nodpi`。
- Provider 读取的共享存储 key 必须与 `WidgetSpec.imageKey` 完全一致。

## 3. 离屏渲染约束

`HomeWidget.renderFlutterWidget` 使用独立的渲染树，结构近似：

```text
RenderView
└── Directionality
    └── Column(mainAxisAlignment: center)
        └── 业务 View
```

它和 App 页面中的常规布局不同，必须遵守以下规则：

- View 根节点必须有明确的 `width` 和 `height`。
- `CustomPaint` 没有 child 时必须用 `SizedBox.expand`、明确 `size` 或等价方式同时约束宽高。
- 无 child 的 `DecoratedBox`、`ColoredBox` 等必须拿到宽高约束；放在 `Row` 中时通常需要 `crossAxisAlignment: CrossAxisAlignment.stretch` 或 `SizedBox.expand`。
- 不要使用依赖 `View.of(context)` 的 `Scrollable`；内容溢出使用 `WidgetOverflowClip` 等离屏安全方案。
- 不依赖动画下一帧、异步加载、网络图片或平台通道完成首帧绘制。
- 文字之外的画布、图表、进度条必须有尺寸断言，不能只断言 Widget 或文案存在。

## 4. 添加页预览图

预览图必须由真实 View 和示例数据生成，禁止单独手绘一套容易漂移的 UI。

在 `test/widget/widget_preview_generator_test.dart` 中：

- 导入新 View。
- 增加中英文示例文案和稳定的示例数据。
- 为每个公开尺寸生成预览 PNG。
- 使用与 Android drawable 和 iOS `WidgetPreviewAssets` 一致的资源名。

在 macOS 运行：

```bash
GEN_WIDGET_PREVIEWS=1 flutter test \
  test/widget/widget_preview_generator_test.dart
```

生成器会写入 Android 默认/英文资源目录，并同步到 `ios/BeeCountWidget/Previews/`。提交前应人工打开新 PNG，确认文字、图形、圆角和尺寸完整。

## 5. 自动化测试

每个新 View 至少覆盖：

- 有数据和空数据。
- 亮色和暗色。
- 支持的每个尺寸。
- 文案不会抛出布局异常。
- 使用与 `renderFlutterWidget` 相同的 `Directionality > Column(center)` harness，断言所有关键 `RenderBox` 宽高大于 0。

建议命令：

```bash
flutter test test/widget --no-pub
flutter analyze <本次改动的 Dart 文件>
flutter build ios --simulator --debug --no-pub
flutter build apk --debug --flavor dev --target-platform android-arm64 --no-pub
```

## 6. 模拟器/真机验收

iOS 和 Android 必须分别完成：

1. 打开系统小组件添加页，确认名称、描述和静态预览正确。
2. 把所有新增尺寸添加到桌面。
3. 打开 BeeCount 触发重新渲染，再回桌面确认内容刷新。
4. 分别检查有数据、空数据、亮色、暗色以及至少中英文两种语言。
5. 检查标题、核心图形、数字、底部文案和圆角，无空白、裁切、红屏或拉伸。
6. 点击组件，确认深链进入预期页面。
7. 修改一笔交易后确认组件能再次刷新，而不是只显示安装时快照。

PR 描述应附两端添加页预览和桌面实际展示截图。任何一端缺少预览、核心内容为空或依赖手动重装才能刷新，都不满足合并条件。

## 7. 提交前自检

- [ ] Flutter spec、iOS kind、Android provider、图片 key 一致。
- [ ] 两端原生入口均已注册。
- [ ] 中英文预览图已生成并纳入资源。
- [ ] iOS preview 使用 bundle 资产，不读取 App Group。
- [ ] Android XML 配置了 `previewImage`。
- [ ] 离屏 harness 中所有关键绘制区域宽高大于 0。
- [ ] Widget 单测、iOS 构建、Android 构建通过。
- [ ] 两端桌面已实际添加并验证刷新与深链。
