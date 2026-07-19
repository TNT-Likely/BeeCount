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
enum HWType { glance, netWorth, quickAdd, budget, recent, dashboard }

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
  /// 仅 [glanceMedium] 有真实渲染实现,且其渲染尺寸实际按平台(iOS/Android)
  /// 分叉、不直接取用这里的值(见 `WidgetManager._renderSpec` 注释,属 D2
  /// back-compat)。其余类型此阶段(P1)尚无 View 实现,这里的取值只是 P2
  /// 落地各类型视图前的占位标准尺寸(接近 iOS systemSmall/Medium/Large 的
  /// 常见尺寸),渲染时会重新校准。
  final Size logicalSize;

  /// iOS Widget `kind` 标识(对应 [HomeWidgetInfo.iOSKind])。只有已在原生壳
  /// (`BeeCountWidgetBundle.swift`)注册的类型才有值;未注册类型此字段为
  /// null,天然不会被 [matchInstalled] 匹配到——这正是 D5「只渲已安装」在
  /// 新类型还没有原生壳时的自然表现,不需要额外的"是否已实现"开关。
  final String? iosKind;

  /// iOS Widget family 字符串(如 `systemMedium`),仅已注册类型有值。
  final String? iosFamily;

  /// Android `AppWidgetProvider` 完整类名(对应
  /// [HomeWidgetInfo.androidClassName]),仅已注册类型有值。
  final String? androidClassName;

  const WidgetSpec._({
    required this.type,
    required this.size,
    required this.logicalSize,
    this.iosKind,
    this.iosFamily,
    this.androidClassName,
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
  static const glanceSmall = WidgetSpec._(
    type: HWType.glance,
    size: HWSize.small,
    logicalSize: Size(155, 155),
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
  );
  static const netWorthMedium = WidgetSpec._(
    type: HWType.netWorth,
    size: HWSize.medium,
    logicalSize: Size(364, 169),
    iosKind: 'BeeCountNetWorthWidget',
    iosFamily: 'systemMedium',
  );
  static const netWorthLarge = WidgetSpec._(
    type: HWType.netWorth,
    size: HWSize.large,
    logicalSize: Size(364, 382),
    iosKind: 'BeeCountNetWorthWidget',
    iosFamily: 'systemLarge',
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
  );
  static const quickAddMedium = WidgetSpec._(
    type: HWType.quickAdd,
    size: HWSize.medium,
    logicalSize: Size(364, 169),
    iosKind: 'BeeCountQuickAddWidget',
    iosFamily: 'systemMedium',
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
  );
  static const budgetMedium = WidgetSpec._(
    type: HWType.budget,
    size: HWSize.medium,
    logicalSize: Size(364, 169),
    iosKind: 'BeeCountBudgetWidget',
    iosFamily: 'systemMedium',
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
  );
  static const recentLarge = WidgetSpec._(
    type: HWType.recent,
    size: HWSize.large,
    logicalSize: Size(364, 382),
    iosKind: 'BeeCountRecentWidget',
    iosFamily: 'systemLarge',
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
  ];

  /// 渲染管线拿不到"已安装组件"列表时(home_widget 版本过低 / 平台调用
  /// 异常)的退化默认集。至少保留 [glanceMedium],避免存量用户的组件因升级
  /// 而断更(D5)。
  static const List<WidgetSpec> defaultSet = [glanceMedium];

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
          spec.androidClassName == info.androidClassName) {
        return spec;
      }
    }
    return null;
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
