import 'dart:io';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../data/repositories/base_repository.dart';
import '../services/system/logger_service.dart';
import 'home_widget_view.dart';
import 'widget_data_service.dart';
import 'widget_spec.dart';

const _tag = 'WidgetManager';

/// 把 home_widget 平台 `getInstalledWidgets()` 的原始结果([HomeWidgetInfo]
/// 列表)映射为本地 [WidgetSpec] 目录中的条目;匹配不到目录(如尚未在原生
/// 壳注册的新类型)的条目被丢弃。
///
/// 纯函数,不触碰平台通道,便于单测。
List<WidgetSpec> matchInstalledSpecs(List<HomeWidgetInfo> infos) {
  final result = <WidgetSpec>[];
  for (final info in infos) {
    final spec = WidgetSpec.matchInstalled(info);
    if (spec != null) result.add(spec);
  }
  return result;
}

/// 挑选本次需要渲染的 spec 列表(D5:只渲已安装的,避免盲渲所有类型/尺寸,
/// 省渲染开销与内存)。
///
/// - [installed] 为 `null` 表示"拿不到已安装组件列表"(home_widget 版本
///   过低 / 平台调用异常),退化为默认集([WidgetSpec.defaultSet],至少保留
///   glance-medium),避免存量用户的组件因本次升级而断更。
/// - [installed] 为空列表表示"确实一个组件都没装",按 D5 原则不渲染任何
///   内容。
/// - 其余情况原样返回(按 (type,size) 去重),不做进一步过滤。
///
/// 纯函数,不依赖平台通道,便于单测。
List<WidgetSpec> selectSpecsToRender(List<WidgetSpec>? installed) {
  if (installed == null) {
    return WidgetSpec.defaultSet;
  }
  if (installed.isEmpty) {
    return const [];
  }
  final seen = <WidgetSpec>{};
  final result = <WidgetSpec>[];
  for (final spec in installed) {
    if (seen.add(spec)) {
      result.add(spec);
    }
  }
  return result;
}

class WidgetManager {
  static final WidgetManager _instance = WidgetManager._internal();
  factory WidgetManager() => _instance;
  WidgetManager._internal();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'zh_CN',
    symbol: '¥',
    decimalDigits: 2,
  );

  /// 渲染管线入口(P1 重构):以前的 `updateWidget()` 固定只渲一张
  /// `widgetImage`;现在按 [WidgetSpec] 目录逐个处理,只渲染用户"已安装"
  /// (已放置到桌面)的组件,再统一触发原生刷新。
  ///
  /// **本阶段(P1)只有 glance-medium 接了真实取数/视图**(从旧
  /// `updateWidget()` 迁移到 [WidgetDataService.gatherGlance] +
  /// [HomeWidgetView]);其余类型(netWorth/quickAdd/budget/recent/
  /// dashboard,含 glance-small)的取数与视图留给 Phase B(P2),遇到时会
  /// 直接跳过渲染,不是本阶段的回归。
  Future<void> updateAllWidgets(
    BaseRepository repository,
    int ledgerId,
    Color themeColor, {
    bool redForIncome = true,
    String appName = '蜜蜂记账',
    String monthSuffix = '月',
    String todayExpenseLabel = '今日支出',
    String todayIncomeLabel = '今日收入',
    String monthExpenseLabel = '本月支出',
    String monthIncomeLabel = '本月收入',
    // 净资产系列(netWorth/dashboard)折算用的主币种,默认 'CNY' 兜底旧调用方
    // (见 currency_providers.dart 的 baseCurrencyProvider)。本阶段(Phase B1)
    // 调用处尚未逐个接入真实值——取到的数据当前只用于验证取数链路(见
    // _gatherForType),真正显示给用户要等 Phase B2 补 View 时一并接上。
    String baseCurrency = 'CNY',
  }) async {
    try {
      final specs = await _resolveSpecsToRender();
      if (specs.isEmpty) {
        logger.debug(_tag, '没有已安装的桌面组件,跳过本次渲染');
        return;
      }

      for (final spec in specs) {
        try {
          await _renderSpec(
            spec,
            repository: repository,
            ledgerId: ledgerId,
            themeColor: themeColor,
            redForIncome: redForIncome,
            appName: appName,
            monthSuffix: monthSuffix,
            todayExpenseLabel: todayExpenseLabel,
            todayIncomeLabel: todayIncomeLabel,
            monthExpenseLabel: monthExpenseLabel,
            monthIncomeLabel: monthIncomeLabel,
            baseCurrency: baseCurrency,
          );
        } catch (e, st) {
          // 单个 spec 渲染失败不应阻断其余 spec(P2 起会有多个真实类型)。
          logger.error(_tag, '渲染 ${spec.imageKey} 失败,跳过', e, st);
        }
      }

      // 触发原生壳刷新。
      // 注意(D2 back-compat):iOS kind `BeeCountWidget` / Android provider
      // 类名 `BeeCountWidgetProvider` 保持不变,本阶段仍只有这一个原生组件
      // 需要触发;P3/P4 新增原生壳注册后,需按已渲染的 spec 逐个触发对应
      // kind/provider。
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.tntlikely.beecount.BeeCountWidgetProvider',
        iOSName: 'BeeCountWidget',
      );
      logger.info(
        _tag,
        '小组件更新完成,已渲染 ${specs.length} 个 spec: '
        '${specs.map((s) => s.imageKey).join(', ')}',
      );
    } catch (e, st) {
      logger.error(_tag, '更新小组件失败', e, st);
    }
  }

  /// 获取平台"已安装组件"列表并映射为 spec;调用失败时返回按 `null` 触发
  /// 默认集的 [selectSpecsToRender] 结果。
  Future<List<WidgetSpec>> _resolveSpecsToRender() async {
    List<HomeWidgetInfo> infos;
    try {
      infos = await HomeWidget.getInstalledWidgets();
    } catch (e) {
      logger.warning(
        _tag,
        '获取已安装组件列表失败,退化为默认集(至少 glance-medium): $e',
      );
      return selectSpecsToRender(null);
    }
    return selectSpecsToRender(matchInstalledSpecs(infos));
  }

  Future<void> _renderSpec(
    WidgetSpec spec, {
    required BaseRepository repository,
    required int ledgerId,
    required Color themeColor,
    required bool redForIncome,
    required String appName,
    required String monthSuffix,
    required String todayExpenseLabel,
    required String todayIncomeLabel,
    required String monthExpenseLabel,
    required String monthIncomeLabel,
    required String baseCurrency,
  }) async {
    if (spec != WidgetSpec.glanceMedium) {
      // 其余类型(含 glance-small)尚无 View 实现,渲染留给 Phase B2(见
      // .docs/home-widget/plan.md §三 P2)。数据层(gather* + repo 方法)已在
      // Phase B1 落地——这里按 spec.type 把对应数据取一遍,验证取数链路可用;
      // 取到的数据目前用不上(没有 View 消费),不接渲染。异常会被
      // updateAllWidgets 调用处的 try/catch 捕获,不影响其它 spec。
      await _gatherForType(
        spec,
        repository: repository,
        ledgerId: ledgerId,
        baseCurrency: baseCurrency,
      );
      logger.debug(
        _tag,
        '${spec.imageKey} 数据已就绪(Phase B1),视图待 Phase B2,跳过渲染',
      );
      return;
    }

    final data = await WidgetDataService.gatherGlance(
      repository: repository,
      ledgerId: ledgerId,
    );

    // iOS systemMedium 与 Android 2:1 网格的宽高比不同,渲染尺寸沿用升级前
    // 的平台分叉逻辑,不直接使用 spec.logicalSize——避免改变现有原生壳对
    // 图片像素尺寸的假设,属 D2 back-compat 的一部分。
    final widgetSize = Platform.isIOS
        ? const Size(364, 169) // iOS systemMedium
        : const Size(364, 182); // Android 2:1 比例(364/2=182)

    logger.debug(
      _tag,
      '渲染 ${spec.imageKey} - Platform: ${Platform.isIOS ? "iOS" : "Android"}, '
      'Size: ${widgetSize.width}x${widgetSize.height}',
    );

    await HomeWidget.renderFlutterWidget(
      HomeWidgetView(
        todayExpense: _currencyFormat.format(data.todayExpenseTotal),
        todayIncome: _currencyFormat.format(data.todayIncomeTotal),
        monthExpense: _currencyFormat.format(data.monthExpenseTotal),
        monthIncome: _currencyFormat.format(data.monthIncomeTotal),
        themeColor: themeColor,
        redForIncome: redForIncome,
        appName: appName,
        monthSuffix: monthSuffix,
        todayExpenseLabel: todayExpenseLabel,
        todayIncomeLabel: todayIncomeLabel,
        monthExpenseLabel: monthExpenseLabel,
        monthIncomeLabel: monthIncomeLabel,
        width: widgetSize.width,
        height: widgetSize.height,
      ),
      // spec.imageKey 对 glance-medium 特判为 'widgetImage'(D2 back-compat,
      // 详见 WidgetSpec.imageKey 注释),其余新 spec 才是 'widget_<type>_<size>'。
      key: spec.imageKey,
      logicalSize: widgetSize,
      // 由 4.0 降为 3.0:更省内存,对 iOS 30MB widget 进程内存上限更友好。
      pixelRatio: 3.0,
    );

    final savedPath = await HomeWidget.getWidgetData<String>(spec.imageKey);
    logger.debug(_tag, '${spec.imageKey} 渲染完成,保存路径: $savedPath');
  }

  /// 按 [spec] 的 [HWType] 分派到对应的 `WidgetDataService.gather*`(Phase B1
  /// 落地的数据层,见 `.docs/home-widget/plan.md` §一.3)。除
  /// [WidgetSpec.glanceMedium] 外目前都还没有 View 消费这份数据——这里只是把
  /// 取数链路跑通,为 Phase B2 补 View 时铺路,不做任何渲染或返回值处理。
  Future<void> _gatherForType(
    WidgetSpec spec, {
    required BaseRepository repository,
    required int ledgerId,
    required String baseCurrency,
  }) async {
    switch (spec.type) {
      case HWType.glance:
        // glance-small:取数逻辑与 glance-medium 相同,View 待 Phase B2。
        await WidgetDataService.gatherGlance(
          repository: repository,
          ledgerId: ledgerId,
        );
        return;
      case HWType.netWorth:
        await WidgetDataService.gatherNetWorthBreakdown(
          repository: repository,
          baseCurrency: baseCurrency,
        );
        return;
      case HWType.quickAdd:
        await WidgetDataService.gatherQuickAddCategories(
          repository: repository,
          ledgerId: ledgerId,
        );
        return;
      case HWType.budget:
        await WidgetDataService.gatherBudget(
          repository: repository,
          ledgerId: ledgerId,
        );
        return;
      case HWType.recent:
        await WidgetDataService.gatherRecent(
          repository: repository,
          ledgerId: ledgerId,
        );
        return;
      case HWType.dashboard:
        await WidgetDataService.gatherDashboard(
          repository: repository,
          ledgerId: ledgerId,
          baseCurrency: baseCurrency,
        );
        return;
    }
  }

  /// Register widget update callback
  static Future<void> registerCallback() async {
    try {
      await HomeWidget.registerInteractivityCallback(
        _backgroundCallback,
      );
    } catch (e) {
      logger.warning(_tag, '注册小组件交互回调失败: $e');
      return;
    }
  }

  /// Background callback for widget interactions
  @pragma('vm:entry-point')
  static Future<void> _backgroundCallback(Uri? uri) async {
    // Handle widget tap events
    // Could be used to navigate to specific pages
    // 图片方案下点击目前靠深链跳转(services/platform/app_link_service.dart),
    // 这个交互回调暂时留空占位;补齐属 D8/P5 范围,这里先保证异常不崩溃。
  }
}
