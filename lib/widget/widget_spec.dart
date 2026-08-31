import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart' show HomeWidgetInfo;

/// 桌面小组件内容类型。
///
/// 各类型合法尺寸组合(`HWType` × `HWSize`,见 `.docs/home-widget/plan.md`
/// §二「逐组件 spec」):
/// - glance    (收支速览)  : small, medium
/// - netWorth  (净资产)    : small, medium, large
/// - quickAdd  (快速记账)  : small, medium
/// - budget    (预算进度)  : small, medium
/// - recent    (最近交易)  : medium, large
/// - dashboard (综合仪表盘): large
///
/// P1(本阶段)只落地了 [WidgetSpec.glanceMedium] 的真实取数/渲染,其余
/// 类型仅登记目录条目,渲染管线会按 Phase B(P2)前的约定跳过它们。
enum HWType {
  glance,
  netWorth,
  quickAdd,
  budget,
  recent,
  dashboard,
  consumptionRhythm,
  beeTrail,
}

/// 桌面小组件尺寸档位,对应 iOS `systemSmall/Medium/Large`、Android 对应
/// 网格尺寸。
enum HWSize { small, medium, large }

/// 单个"内容类型 + 尺寸"的渲染规格。
///
/// 渲染管线(`WidgetManager.updateAllWidgets`)按 [catalog] 匹配用户"已安装"
/// 的组件(`HomeWidget.getInstalledWidgets()`),只对已安装的 spec 取数、
/// 渲染成图片,写入 [imageKey] 对应的共享存储位置,原生壳按 key 读取展示。
@immutable
class WidgetSpec {
  final HWType type;
  final HWSize size;

  /// 渲染时使用的逻辑尺寸(pt/dp,对应 `HomeWidget.renderFlutterWidget` 的
  /// `logicalSize`)。
  ///
  /// 全部 12 个 spec 均按此尺寸渲染;唯一例外是 [glanceMedium]——其渲染
  /// 尺寸按平台(iOS 364×169 / Android 364×182)分叉、不直接取用这里的值
  /// (见 `WidgetManager._renderGlance` 注释,属 D2 back-compat)。取值接近
  /// iOS systemSmall/Medium/Large 的常见尺寸。
  final Size logicalSize;

  /// iOS Widget `kind` 标识(对应 [HomeWidgetInfo.iOSKind])。只有已在原生壳
  /// (`BeeCountWidgetBundle.swift`)注册的类型才有值;未注册类型此字段为
  /// null,天然不会被 [matchInstalled] 匹配到——这正是 D5「只渲已安装」在
  /// 新类型还没有原生壳时的自然表现,不需要额外的"是否已实现"开关。
  final String? iosKind;

  /// iOS Widget family 字符串(如 `systemMedium`),仅已注册类型有值。
  final String? iosFamily;

  /// Android `AppWidgetProvider` 主类名(对应
  /// [HomeWidgetInfo.androidClassName]),仅已注册类型有值。
  ///
  /// Android 没有 iOS family 按尺寸分发的机制,多尺寸类型靠两层配合:
  /// ① [matchInstalledAll] 对命中类名的类型返回**全部尺寸 spec**(管线把
  ///   各档图都渲出来);② 原生壳按 `getAppWidgetOptions` 真实尺寸选图。
  /// 另有按尺寸拆分的入口子类([androidExtraClassNames]),让每个档位在
  /// 选择器里直接可加。
  final String? androidClassName;

  /// 同类型其它可承载本 spec 的 Android provider 类名(按尺寸拆分的空子类
  /// 入口,见 `BeeCountSizedWidgetProviders.kt`)。所有入口都继承父类"按
  /// 实际尺寸选图"的逻辑、可自由拉伸,故**类型下任一 provider 被安装,该
  /// 类型全部尺寸的图都要渲染**——[matchInstalledAll] 据此用
  /// [androidAllClassNames] 匹配,原生刷新触发也要覆盖这些子类。
  final List<String> androidExtraClassNames;

  /// 本 spec 在 Android 侧的全部宿主 provider 类名(主类名 + 尺寸入口子类)。
  List<String> get androidAllClassNames => [
        if (androidClassName != null) androidClassName!,
        ...androidExtraClassNames,
      ];

  const WidgetSpec._({
    required this.type,
    required this.size,
    required this.logicalSize,
    this.iosKind,
    this.iosFamily,
    this.androidClassName,
    this.androidExtraClassNames = const [],
  });

  /// 渲染输出图片的存储 key,原生壳按此 key 读取图片文件路径。
  ///
  /// **例外(D2 back-compat)**:现有中号收支速览([glanceMedium])沿用旧 key
  /// `widgetImage`,**不**改成 `widget_glance_medium`——这样现有 iOS
  /// `BeeCountWidget.swift` / Android `BeeCountWidgetProvider.kt` 原生壳
  /// 完全不用改,存量用户桌面已放置的组件 100% 继续工作(原生壳读 key 的
  /// 改动不在本阶段范围,见 plan.md P3/P4)。其余所有新 spec 一律
  /// `widget_<type>_<size>`(枚举名直接拼接,如 `widget_netWorth_small`)。
  String get imageKey {
    if (this == glanceMedium) {
      return 'widgetImage';
    }
    return 'widget_${type.name}_${size.name}';
  }

  // ---- 收支速览(glance):小/中 ----
  /// 小号(补全新增):iOS 挂在**现有** kind `BeeCountWidget` 的 systemSmall
  /// family 下(增量注册,存量中号放置不受影响);Android 因老 provider 不可
  /// 改动(D2),用独立的 GlanceSmall provider 承载。
  static const glanceSmall = WidgetSpec._(
    type: HWType.glance,
    size: HWSize.small,
    logicalSize: Size(155, 155),
    iosKind: 'BeeCountWidget',
    iosFamily: 'systemSmall',
    androidClassName:
        'com.tntlikely.beecount.BeeCountGlanceSmallWidgetProvider',
  );

  /// 现有唯一已上线的组件:中号收支速览。原生标识与升级前完全一致
  /// (iOS kind `BeeCountWidget` / Android provider 类名
  /// `BeeCountWidgetProvider`),存量桌面放置靠这两个标识存活,不可更改。
  static const glanceMedium = WidgetSpec._(
    type: HWType.glance,
    size: HWSize.medium,
    logicalSize: Size(364, 169),
    iosKind: 'BeeCountWidget',
    iosFamily: 'systemMedium',
    androidClassName: 'com.tntlikely.beecount.BeeCountWidgetProvider',
  );

  // ---- 净资产(netWorth):小/中/大 ----
  // iOS 原生壳见 ios/BeeCountWidget/BeeCountNetWorthWidget.swift
  // (kind BeeCountNetWorthWidget,supportedFamilies 小/中/大)。
  static const netWorthSmall = WidgetSpec._(
    type: HWType.netWorth,
    size: HWSize.small,
    logicalSize: Size(155, 155),
    iosKind: 'BeeCountNetWorthWidget',
    iosFamily: 'systemSmall',
    androidClassName: 'com.tntlikely.beecount.BeeCountNetWorthWidgetProvider',
    androidExtraClassNames: [
      'com.tntlikely.beecount.BeeCountNetWorthMediumWidgetProvider',
      'com.tntlikely.beecount.BeeCountNetWorthLargeWidgetProvider',
    ],
  );
  static const netWorthMedium = WidgetSpec._(
    type: HWType.netWorth,
    size: HWSize.medium,
    logicalSize: Size(364, 169),
    iosKind: 'BeeCountNetWorthWidget',
    iosFamily: 'systemMedium',
    androidClassName: 'com.tntlikely.beecount.BeeCountNetWorthWidgetProvider',
    androidExtraClassNames: [
      'com.tntlikely.beecount.BeeCountNetWorthMediumWidgetProvider',
      'com.tntlikely.beecount.BeeCountNetWorthLargeWidgetProvider',
    ],
  );
  static const netWorthLarge = WidgetSpec._(
    type: HWType.netWorth,
    size: HWSize.large,
    logicalSize: Size(364, 382),
    iosKind: 'BeeCountNetWorthWidget',
    iosFamily: 'systemLarge',
    androidClassName: 'com.tntlikely.beecount.BeeCountNetWorthWidgetProvider',
    androidExtraClassNames: [
      'com.tntlikely.beecount.BeeCountNetWorthMediumWidgetProvider',
      'com.tntlikely.beecount.BeeCountNetWorthLargeWidgetProvider',
    ],
  );

  // ---- 快速记账(quickAdd):小/中 ----
  // iOS 原生壳见 ios/BeeCountWidget/BeeCountQuickAddWidget.swift
  // (kind BeeCountQuickAddWidget,supportedFamilies 小/中)。
  static const quickAddSmall = WidgetSpec._(
    type: HWType.quickAdd,
    size: HWSize.small,
    logicalSize: Size(155, 155),
    iosKind: 'BeeCountQuickAddWidget',
    iosFamily: 'systemSmall',
    androidClassName: 'com.tntlikely.beecount.BeeCountQuickAddWidgetProvider',
    androidExtraClassNames: [
      'com.tntlikely.beecount.BeeCountQuickAddMediumWidgetProvider',
    ],
  );
  static const quickAddMedium = WidgetSpec._(
    type: HWType.quickAdd,
    size: HWSize.medium,
    logicalSize: Size(364, 169),
    iosKind: 'BeeCountQuickAddWidget',
    iosFamily: 'systemMedium',
    androidClassName: 'com.tntlikely.beecount.BeeCountQuickAddWidgetProvider',
    androidExtraClassNames: [
      'com.tntlikely.beecount.BeeCountQuickAddMediumWidgetProvider',
    ],
  );

  // ---- 预算进度(budget):小/中 ----
  // iOS 原生壳见 ios/BeeCountWidget/BeeCountBudgetWidget.swift
  // (kind BeeCountBudgetWidget,supportedFamilies 小/中)。
  static const budgetSmall = WidgetSpec._(
    type: HWType.budget,
    size: HWSize.small,
    logicalSize: Size(155, 155),
    iosKind: 'BeeCountBudgetWidget',
    iosFamily: 'systemSmall',
    androidClassName: 'com.tntlikely.beecount.BeeCountBudgetWidgetProvider',
    androidExtraClassNames: [
      'com.tntlikely.beecount.BeeCountBudgetMediumWidgetProvider',
    ],
  );
  static const budgetMedium = WidgetSpec._(
    type: HWType.budget,
    size: HWSize.medium,
    logicalSize: Size(364, 169),
    iosKind: 'BeeCountBudgetWidget',
    iosFamily: 'systemMedium',
    androidClassName: 'com.tntlikely.beecount.BeeCountBudgetWidgetProvider',
    androidExtraClassNames: [
      'com.tntlikely.beecount.BeeCountBudgetMediumWidgetProvider',
    ],
  );

  // ---- 最近交易(recent):中/大 ----
  // iOS 原生壳见 ios/BeeCountWidget/BeeCountRecentWidget.swift
  // (kind BeeCountRecentWidget,supportedFamilies 中/大)。
  static const recentMedium = WidgetSpec._(
    type: HWType.recent,
    size: HWSize.medium,
    logicalSize: Size(364, 169),
    iosKind: 'BeeCountRecentWidget',
    iosFamily: 'systemMedium',
    androidClassName: 'com.tntlikely.beecount.BeeCountRecentWidgetProvider',
    androidExtraClassNames: [
      'com.tntlikely.beecount.BeeCountRecentLargeWidgetProvider',
    ],
  );
  static const recentLarge = WidgetSpec._(
    type: HWType.recent,
    size: HWSize.large,
    logicalSize: Size(364, 382),
    iosKind: 'BeeCountRecentWidget',
    iosFamily: 'systemLarge',
    androidClassName: 'com.tntlikely.beecount.BeeCountRecentWidgetProvider',
    androidExtraClassNames: [
      'com.tntlikely.beecount.BeeCountRecentLargeWidgetProvider',
    ],
  );

  // ---- 综合仪表盘(dashboard):仅大 ----
  // iOS 原生壳见 ios/BeeCountWidget/BeeCountDashboardWidget.swift
  // (kind BeeCountDashboardWidget,supportedFamilies 仅大)。
  static const dashboardLarge = WidgetSpec._(
    type: HWType.dashboard,
    size: HWSize.large,
    logicalSize: Size(364, 382),
    iosKind: 'BeeCountDashboardWidget',
    iosFamily: 'systemLarge',
    androidClassName: 'com.tntlikely.beecount.BeeCountDashboardWidgetProvider',
  );

  // ---- 消费节奏(consumptionRhythm):仅中 ----
  static const consumptionRhythmMedium = WidgetSpec._(
    type: HWType.consumptionRhythm,
    size: HWSize.medium,
    logicalSize: Size(364, 169),
    iosKind: 'BeeCountConsumptionRhythmWidget',
    iosFamily: 'systemMedium',
    androidClassName:
        'com.tntlikely.beecount.BeeCountConsumptionRhythmWidgetProvider',
  );

  // ---- 记账连续蜂迹(beeTrail):仅小 ----
  static const beeTrailSmall = WidgetSpec._(
    type: HWType.beeTrail,
    size: HWSize.small,
    logicalSize: Size(155, 155),
    iosKind: 'BeeCountBeeTrailWidget',
    iosFamily: 'systemSmall',
    androidClassName: 'com.tntlikely.beecount.BeeCountBeeTrailWidgetProvider',
  );

  /// 全部合法 (type, size) 组合的目录(见 plan.md §二逐组件 spec)。
  static const List<WidgetSpec> catalog = [
    glanceSmall,
    glanceMedium,
    netWorthSmall,
    netWorthMedium,
    netWorthLarge,
    quickAddSmall,
    quickAddMedium,
    budgetSmall,
    budgetMedium,
    recentMedium,
    recentLarge,
    dashboardLarge,
    consumptionRhythmMedium,
    beeTrailSmall,
  ];

  /// 渲染管线拿不到"已安装组件"列表时(home_widget 版本过低 / 平台调用
  /// 异常)的退化默认集。至少保留 [glanceMedium],避免存量用户的组件因升级
  /// 而断更(D5)。
  static const List<WidgetSpec> defaultSet = [glanceMedium];

  /// Android 已安装类名比对,兼容 home_widget 透传的**短类名**形式。
  ///
  /// home_widget(0.9.x `HomeWidgetPlugin.kt` getInstalledWidgets)返回的是
  /// `ComponentName.shortClassName`:当 applicationId 与类所在包名相同时
  /// (**prod 商店包** `com.tntlikely.beecount` 正是如此),它是带前导点的
  /// 短名 `.BeeCountWidgetProvider` 而**不是**全限定名;dev/debug 因
  /// applicationIdSuffix(`.dev`/`.debug`)与类包名不同才返回全名。此前只按
  /// 全限定名精确比对,商店包上所有条目都匹配不到 → 被当成"一个组件都没装"
  /// → 全部不渲染(dev 真机永远复现不了的发布级缺陷,2026-07 review 发现)。
  ///
  /// 短名以 `.` 开头,`candidate.endsWith(installed)` 自带点号边界,不会把
  /// `XxxBeeCountWidgetProvider` 误匹配成 `BeeCountWidgetProvider`。
  static bool _androidClassMatches(String? installed, List<String> candidates) {
    if (installed == null || installed.isEmpty) return false;
    for (final c in candidates) {
      if (installed == c) return true;
      if (installed.startsWith('.') && c.endsWith(installed)) return true;
    }
    return false;
  }

  /// 把平台 `HomeWidget.getInstalledWidgets()` 返回的单条 [HomeWidgetInfo]
  /// 匹配到 [catalog] 中的 spec;匹配不到(如尚未注册原生壳的新类型,或
  /// 无法识别的 family/class)返回 null,调用方应丢弃该条目。
  static WidgetSpec? matchInstalled(HomeWidgetInfo info) {
    for (final spec in catalog) {
      if (spec.iosKind != null && spec.iosKind == info.iOSKind) {
        if (spec.iosFamily == null || spec.iosFamily == info.iOSFamily) {
          return spec;
        }
      }
      if (spec.androidClassName != null &&
          _androidClassMatches(
              info.androidClassName, [spec.androidClassName!])) {
        return spec;
      }
    }
    return null;
  }

  /// 把平台已安装信息映射到 catalog 里**所有应为它渲染**的 spec。
  ///
  /// - **iOS**:kind + family 精确匹配(通常一条)——WidgetKit 的
  ///   `getInstalledWidgets` 带 family,能定位确切尺寸。
  /// - **Android**:AppWidget 可被用户自由缩放,`getInstalledWidgets` 不带当前
  ///   尺寸信息,故按 `androidClassName` 命中的类型**返回其全部尺寸 spec**——
  ///   这样无论用户把组件拉到哪个尺寸,对应尺寸的图都已被渲染管线写入共享
  ///   存储,原生壳 `resolveImageKey` 按真实尺寸选 key 时不会落空(否则大尺寸
  ///   会因没渲染出对应图而只显示占位)。代价是 Android 多渲该类型其它尺寸图,
  ///   可接受。
  static List<WidgetSpec> matchInstalledAll(HomeWidgetInfo info) {
    final matched = <WidgetSpec>[];
    for (final spec in catalog) {
      final iosHit = spec.iosKind != null &&
          spec.iosKind == info.iOSKind &&
          (spec.iosFamily == null || spec.iosFamily == info.iOSFamily);
      final androidHit = _androidClassMatches(
          info.androidClassName, spec.androidAllClassNames);
      if (iosHit || androidHit) {
        matched.add(spec);
      }
    }
    return matched;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WidgetSpec && other.type == type && other.size == size);

  @override
  int get hashCode => Object.hash(type, size);

  @override
  String toString() =>
      'WidgetSpec(${type.name}, ${size.name}, imageKey: $imageKey)';
}
