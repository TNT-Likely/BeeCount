import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../data/repositories/base_repository.dart';
import '../services/system/logger_service.dart';
import '../utils/net_worth_trend_utils.dart' show trendTodayAnchor;
import 'views/glance_view.dart';
import 'views/net_worth_view.dart';
import 'views/quick_add_view.dart';
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

  /// 渲染管线入口:按 [WidgetSpec] 目录逐个处理,只渲染用户"已安装"(已放置
  /// 到桌面)的组件,再统一触发原生刷新。
  ///
  /// **Phase B2a 现状**:glance(小/中)已接真实视图([GlanceView]);
  /// netWorth/quickAdd/budget/recent/dashboard 的取数链路已就绪
  /// (Phase B1),但视图仍留给后续阶段(Phase B2b),遇到时直接跳过渲染,
  /// 不是回归。
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
    // GlanceView.small 专用的"今日"徽章文案。l10n 暂无独立"今日"key(只有
    // "今日支出"/"今日收入"整词),先用中文默认值占位。
    // TODO(i18n): Phase C 补三语 arb key。
    String todayLabel = '今日',
    // 净资产系列(netWorth/dashboard)折算用的主币种,默认 'CNY' 兜底旧调用方
    // (见 currency_providers.dart 的 baseCurrencyProvider)。
    String baseCurrency = 'CNY',
    // 净资产视图文案。三个 key 均已有对应 arb(accountTotalBalance/
    // totalAssets/totalLiabilities),默认值与其中文文案保持一致——本函数
    // 不依赖 BuildContext/l10n,取不到真正的 AppLocalizations,只能靠调用方
    // (如 widget_provider.dart 的 updateAppWidget)显式传入;其余调用点沿用
    // 这里的默认值兜底(与 appName 等现有参数同一套约定)。
    String netWorthLabel = '净资产',
    String totalAssetsLabel = '总资产',
    String totalLiabilitiesLabel = '总负债',
    // 快速记账「记一笔」按钮文案。l10n 暂无独立 key。
    // TODO(i18n): Phase C 补三语 arb key。
    String quickAddLabel = '记一笔',
  }) async {
    try {
      final specs = await _resolveSpecsToRender();
      if (specs.isEmpty) {
        logger.debug(_tag, '没有已安装的桌面组件,跳过本次渲染');
        return;
      }

      // 图片渲染方案不会随系统明暗切换自动重绘(见 widget_view_style.dart
      // 顶部注释);这里在一次渲染批次开始时取一次当前系统明暗,批次内所有
      // spec 共用同一个值,避免逐个 spec 重复读取平台通道。"更及时跟随系统
      // 切换"的触发时机留 Phase C。
      final dark =
          PlatformDispatcher.instance.platformBrightness == Brightness.dark;

      for (final spec in specs) {
        try {
          await _renderSpec(
            spec,
            repository: repository,
            ledgerId: ledgerId,
            themeColor: themeColor,
            redForIncome: redForIncome,
            dark: dark,
            appName: appName,
            monthSuffix: monthSuffix,
            todayLabel: todayLabel,
            todayExpenseLabel: todayExpenseLabel,
            todayIncomeLabel: todayIncomeLabel,
            monthExpenseLabel: monthExpenseLabel,
            monthIncomeLabel: monthIncomeLabel,
            baseCurrency: baseCurrency,
            netWorthLabel: netWorthLabel,
            totalAssetsLabel: totalAssetsLabel,
            totalLiabilitiesLabel: totalLiabilitiesLabel,
            quickAddLabel: quickAddLabel,
          );
        } catch (e, st) {
          // 单个 spec 渲染失败不应阻断其余 spec。
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

  /// 按 [spec] 的 [HWType] 分派到对应的取数 + 渲染。
  Future<void> _renderSpec(
    WidgetSpec spec, {
    required BaseRepository repository,
    required int ledgerId,
    required Color themeColor,
    required bool redForIncome,
    required bool dark,
    required String appName,
    required String monthSuffix,
    required String todayLabel,
    required String todayExpenseLabel,
    required String todayIncomeLabel,
    required String monthExpenseLabel,
    required String monthIncomeLabel,
    required String baseCurrency,
    required String netWorthLabel,
    required String totalAssetsLabel,
    required String totalLiabilitiesLabel,
    required String quickAddLabel,
  }) async {
    switch (spec.type) {
      case HWType.glance:
        await _renderGlance(
          spec,
          repository: repository,
          ledgerId: ledgerId,
          themeColor: themeColor,
          redForIncome: redForIncome,
          dark: dark,
          appName: appName,
          monthSuffix: monthSuffix,
          todayLabel: todayLabel,
          todayExpenseLabel: todayExpenseLabel,
          todayIncomeLabel: todayIncomeLabel,
          monthExpenseLabel: monthExpenseLabel,
          monthIncomeLabel: monthIncomeLabel,
        );
        return;
      case HWType.netWorth:
        await _renderNetWorth(
          spec,
          repository: repository,
          themeColor: themeColor,
          redForIncome: redForIncome,
          dark: dark,
          baseCurrency: baseCurrency,
          netWorthLabel: netWorthLabel,
          totalAssetsLabel: totalAssetsLabel,
          totalLiabilitiesLabel: totalLiabilitiesLabel,
        );
        return;
      case HWType.quickAdd:
        await _renderQuickAdd(
          spec,
          repository: repository,
          ledgerId: ledgerId,
          themeColor: themeColor,
          dark: dark,
          addLabel: quickAddLabel,
        );
        return;
      case HWType.budget:
      case HWType.recent:
      case HWType.dashboard:
        // 视图待 Phase B2b(budget/recent/dashboard 已在 Phase B1 打通
        // 取数);这里只把取数链路跑一遍验证可用,不做渲染。异常会被
        // updateAllWidgets 调用处的 try/catch 捕获,不影响其它 spec。
        await _gatherAndSkip(
          spec,
          repository: repository,
          ledgerId: ledgerId,
          baseCurrency: baseCurrency,
        );
        logger.debug(
          _tag,
          '${spec.imageKey} 数据已就绪,视图待 Phase B2b,跳过渲染',
        );
        return;
    }
  }

  /// 渲染收支速览(glance):小/中两档,均已接 [GlanceView] 真实视图。
  Future<void> _renderGlance(
    WidgetSpec spec, {
    required BaseRepository repository,
    required int ledgerId,
    required Color themeColor,
    required bool redForIncome,
    required bool dark,
    required String appName,
    required String monthSuffix,
    required String todayLabel,
    required String todayExpenseLabel,
    required String todayIncomeLabel,
    required String monthExpenseLabel,
    required String monthIncomeLabel,
  }) async {
    final data = await WidgetDataService.gatherGlance(
      repository: repository,
      ledgerId: ledgerId,
    );

    final todayExpense = _currencyFormat.format(data.todayExpenseTotal);
    final todayIncome = _currencyFormat.format(data.todayIncomeTotal);
    final monthExpense = _currencyFormat.format(data.monthExpenseTotal);
    final monthIncome = _currencyFormat.format(data.monthIncomeTotal);

    late final Widget view;
    late final Size renderSize;

    if (spec.size == HWSize.small) {
      // 小号两平台同一个方形尺寸,不需要 iOS/Android 分叉。
      renderSize = spec.logicalSize;
      view = GlanceView.small(
        todayExpense: todayExpense,
        monthExpense: monthExpense,
        monthIncome: monthIncome,
        themeColor: themeColor,
        redForIncome: redForIncome,
        dark: dark,
        todayLabel: todayLabel,
        todayExpenseLabel: todayExpenseLabel,
        monthExpenseLabel: monthExpenseLabel,
        monthIncomeLabel: monthIncomeLabel,
        width: renderSize.width,
        height: renderSize.height,
      );
    } else {
      // iOS systemMedium 与 Android 2:1 网格的宽高比不同,渲染尺寸沿用
      // 升级前的平台分叉逻辑,不直接使用 spec.logicalSize——避免改变现有
      // 原生壳对图片像素尺寸的假设,属 D2 back-compat 的一部分。
      renderSize = Platform.isIOS
          ? const Size(364, 169) // iOS systemMedium
          : const Size(364, 182); // Android 2:1 比例(364/2=182)
      view = GlanceView.medium(
        todayExpense: todayExpense,
        todayIncome: todayIncome,
        monthExpense: monthExpense,
        monthIncome: monthIncome,
        themeColor: themeColor,
        redForIncome: redForIncome,
        dark: dark,
        appName: appName,
        monthSuffix: monthSuffix,
        todayExpenseLabel: todayExpenseLabel,
        todayIncomeLabel: todayIncomeLabel,
        monthExpenseLabel: monthExpenseLabel,
        monthIncomeLabel: monthIncomeLabel,
        width: renderSize.width,
        height: renderSize.height,
      );
    }

    await _renderView(view, spec: spec, logicalSize: renderSize);
  }

  /// 渲染净资产(netWorth):小/中/大三档,均已接 [NetWorthView] 真实视图。
  Future<void> _renderNetWorth(
    WidgetSpec spec, {
    required BaseRepository repository,
    required Color themeColor,
    required bool redForIncome,
    required bool dark,
    required String baseCurrency,
    required String netWorthLabel,
    required String totalAssetsLabel,
    required String totalLiabilitiesLabel,
  }) async {
    final breakdown = await WidgetDataService.gatherNetWorthBreakdown(
      repository: repository,
      baseCurrency: baseCurrency,
    );

    // 趋势统一取近 30 天(含今天),小/中/大三档共用同一条口径——首尾两点
    // 近似"当前 vs 一个月前",给 NetWorthView 的环比 chip 用;取数窗口与
    // WidgetDataService.gatherDashboard 的 30 日趋势口径一致。
    final end = trendTodayAnchor();
    final start = end.subtract(const Duration(days: 29));
    final trend = await WidgetDataService.gatherNetWorthTrend(
      repository: repository,
      baseCurrency: baseCurrency,
      start: start,
      end: end,
    );

    // 账户明细只有大号才展示,小/中号不取这份数据,省一次查询。
    final topAccounts = spec.size == HWSize.large
        ? await WidgetDataService.gatherNetWorthTopAccounts(
            repository: repository,
            baseCurrency: baseCurrency,
            limit: 4,
          )
        : const <NetWorthAccountItem>[];

    final view = NetWorthView(
      size: spec.size,
      netWorth: breakdown.netWorth,
      totalAssets: breakdown.totalAssets,
      totalLiabilities: breakdown.totalLiabilities,
      baseCurrency: baseCurrency,
      trend: trend,
      topAccounts: topAccounts,
      themeColor: themeColor,
      redForIncome: redForIncome,
      dark: dark,
      netWorthLabel: netWorthLabel,
      totalAssetsLabel: totalAssetsLabel,
      totalLiabilitiesLabel: totalLiabilitiesLabel,
      width: spec.logicalSize.width,
      height: spec.logicalSize.height,
    );

    await _renderView(view, spec: spec, logicalSize: spec.logicalSize);
  }

  /// 渲染快速记账(quickAdd):小/中两档,均已接 [QuickAddView] 真实视图。
  Future<void> _renderQuickAdd(
    WidgetSpec spec, {
    required BaseRepository repository,
    required int ledgerId,
    required Color themeColor,
    required bool dark,
    required String addLabel,
  }) async {
    // medium 更宽,多展示一个分类格(见 QuickAddView 文档:small 前 3 个 +
    // 记一笔,medium 前 4 个 + 记一笔)。
    final limit = spec.size == HWSize.medium ? 4 : 3;
    final categories = await WidgetDataService.gatherQuickAddCategories(
      repository: repository,
      ledgerId: ledgerId,
      limit: limit,
    );

    final view = QuickAddView(
      size: spec.size,
      categories: categories,
      themeColor: themeColor,
      dark: dark,
      addLabel: addLabel,
      width: spec.logicalSize.width,
      height: spec.logicalSize.height,
    );

    await _renderView(view, spec: spec, logicalSize: spec.logicalSize);
  }

  /// 除 glance/netWorth/quickAdd 外其余类型(P2 起会逐个补 View)的"取数但不
  /// 渲染"占位路径。
  Future<void> _gatherAndSkip(
    WidgetSpec spec, {
    required BaseRepository repository,
    required int ledgerId,
    required String baseCurrency,
  }) async {
    switch (spec.type) {
      case HWType.glance:
        // 不会走到这里(glance 已在 _renderSpec 分派到 _renderGlance)。
        return;
      case HWType.netWorth:
        // 不会走到这里(netWorth 已在 _renderSpec 分派到 _renderNetWorth)。
        return;
      case HWType.quickAdd:
        // 不会走到这里(quickAdd 已在 _renderSpec 分派到 _renderQuickAdd)。
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

  /// 统一的"渲染 + 落盘日志"收尾,供各类型渲染方法复用。
  Future<void> _renderView(
    Widget view, {
    required WidgetSpec spec,
    required Size logicalSize,
  }) async {
    logger.debug(
      _tag,
      '渲染 ${spec.imageKey} - Platform: ${Platform.isIOS ? "iOS" : "Android"}, '
      'Size: ${logicalSize.width}x${logicalSize.height}',
    );

    await HomeWidget.renderFlutterWidget(
      view,
      // spec.imageKey 对 glance-medium 特判为 'widgetImage'(D2 back-compat,
      // 详见 WidgetSpec.imageKey 注释),其余新 spec 才是 'widget_<type>_<size>'。
      key: spec.imageKey,
      logicalSize: logicalSize,
      // 由 4.0 降为 3.0:更省内存,对 iOS 30MB widget 进程内存上限更友好。
      pixelRatio: 3.0,
    );

    final savedPath = await HomeWidget.getWidgetData<String>(spec.imageKey);
    logger.debug(_tag, '${spec.imageKey} 渲染完成,保存路径: $savedPath');
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
