import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../data/repositories/base_repository.dart';
import '../l10n/app_localizations.dart';
import '../services/system/logger_service.dart';
import '../utils/net_worth_trend_utils.dart' show trendTodayAnchor;
import 'views/budget_view.dart';
import 'views/dashboard_view.dart';
import 'views/glance_view.dart';
import 'views/net_worth_view.dart';
import 'views/quick_add_view.dart';
import 'views/recent_view.dart';
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
    // 用 matchInstalledAll:Android 上一个 provider 类名对应多尺寸,返回其全部
    // 尺寸 spec,保证用户缩放到任意尺寸都有对应图(去重在 selectSpecsToRender)。
    result.addAll(WidgetSpec.matchInstalledAll(info));
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
List<WidgetSpec> selectSpecsToRender(
  List<WidgetSpec>? installed, {
  bool warmUpAll = false,
}) {
  // 预热模式:无视"已安装"列表,渲染整个目录(D5「只渲已安装」的显式例外,
  // 动机见 updateAllWidgets 的 warmUpAllSpecs 参数文档)。
  if (warmUpAll) {
    return WidgetSpec.catalog;
  }
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

/// 供没有 [BuildContext] 的调用点(`main.dart` 的 `_WidgetUpdateObserver`、
/// `providers/theme_providers.dart` 的主题色/收支配色监听、
/// `pages/main/ledgers_page_new.dart` 改账本起始日后的即时刷新)解析当前 App
/// 语言,拿到与真正 `AppLocalizations.of(context)` 尽量一致的文案实例——
/// 这些场景改的是主题色/记账周期起始日等与语言无关的东西,但仍应让小组件
/// 文案跟随 App 当前语言,而不是永远显示 [WidgetManager.updateAllWidgets]
/// 参数默认值的中文兜底。
///
/// [explicitLocale] 应传入 `languageProvider`(`providers/language_provider
/// .dart`)的当前状态:非 null 表示用户在语言设置页手动选择过语言,直接采用
/// ——与 `main.dart` `MaterialApp(locale: ref.watch(languageProvider))` 是
/// 同一个值,选项本身就是 [AppLocalizations.supportedLocales] 的成员,这里
/// 必然命中下面的精确匹配分支。为 null 表示"跟随系统",退化为只看
/// `PlatformDispatcher.instance.locale`(系统当前首选 locale)一层匹配——
/// **已知局限**:不是 Flutter `basicLocaleListResolution` 的完整多候选算法
/// (不会遍历 `PlatformDispatcher.instance.locales` 整个偏好列表),但已覆盖
/// 绝大多数真实场景(单一系统语言 UI)。
///
/// 匹配不到任何已支持语言时(如系统语言是法语)兜底
/// `AppLocalizations.supportedLocales.first`(`en`),与 `MaterialApp` 未显式
/// 提供 `localeListResolutionCallback` 时 Flutter 默认解析算法的兜底结果
/// 一致,不会抛异常(`lookupAppLocalizations` 对不在 `isSupported` 列表里的
/// locale 会直接 throw,这里的逐级匹配保证传给它的一定是受支持的 locale)。
AppLocalizations resolveWidgetLocalizations(Locale? explicitLocale) {
  final candidate = explicitLocale ?? PlatformDispatcher.instance.locale;

  for (final supported in AppLocalizations.supportedLocales) {
    if (supported.languageCode == candidate.languageCode &&
        supported.countryCode == candidate.countryCode) {
      return lookupAppLocalizations(supported);
    }
  }
  for (final supported in AppLocalizations.supportedLocales) {
    if (supported.languageCode == candidate.languageCode) {
      return lookupAppLocalizations(supported);
    }
  }
  return lookupAppLocalizations(AppLocalizations.supportedLocales.first);
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
  /// **Phase B2b 完成**:[HWType] 全部 6 种内容类型(glance/netWorth/
  /// quickAdd/budget/recent/dashboard)均已接真实视图并接入本渲染管线。
  ///
  /// **i18n(Phase C)**:本函数不依赖 BuildContext/Riverpod `ref`,下面每个
  /// 文案参数的默认值都只是中文兜底——真正跟随 App 语言靠调用方显式传入:
  /// - 有 `BuildContext` 的调用点(`providers/widget_provider.dart` 的
  ///   `updateAppWidget`)直接用 `AppLocalizations.of(context)`,最准确。
  /// - 没有的调用点(`main.dart`/`providers/theme_providers.dart`/
  ///   `pages/main/ledgers_page_new.dart`)改用
  ///   [WidgetManager.updateAllWidgetsLocalized],内部靠
  ///   [resolveWidgetLocalizations] 还原 `languageProvider` 对应的
  ///   `AppLocalizations`。
  /// - `app.dart` 前台恢复的调用点是本阶段唯一未接入的历史遗留,固定显示
  ///   下面的中文默认值(该文件本次改动范围之外,见 Phase C 任务说明)。
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
    // GlanceView.small 专用的"今日"徽章文案,对应 arb key `widgetToday`。
    String todayLabel = '今日',
    // 净资产系列(netWorth/dashboard)折算用的主币种,默认 'CNY' 兜底旧调用方
    // (见 currency_providers.dart 的 baseCurrencyProvider)。
    String baseCurrency = 'CNY',
    // 净资产视图文案,分别对应 arb key accountTotalBalance/totalAssets/
    // totalLiabilities/widgetNoAccounts(最后一个是大号账户明细列表为空时的
    // 占位文案)。
    String netWorthLabel = '净资产',
    String totalAssetsLabel = '总资产',
    String totalLiabilitiesLabel = '总负债',
    String noAccountsLabel = '暂无账户',
    // 快速记账「记一笔」按钮文案,对应 arb key `widgetQuickAddLabel`。
    String quickAddLabel = '记一笔',
    // 预算进度(budget)视图文案。budgetLabel/budgetUsedLabel 文本与语义都
    // 和预算页已有的 budgetMonthlyBudget/budgetUsed 完全一致,直接复用;
    // budgetTotalLabel/budgetRemainingLabel 是卡片专用短词(budget_page.dart
    // 的 budgetRemaining 是"剩余"这样的完整词,小组件空间紧张需要"剩"这样的
    // 单字),对应新增 arb key widgetBudgetTotal/widgetBudgetRemaining;
    // noBudgetLabel 对应新增 arb key widgetNoBudget。
    String budgetLabel = '本月预算',
    String budgetUsedLabel = '已用',
    String budgetTotalLabel = '总额',
    String budgetRemainingLabel = '剩',
    String noBudgetLabel = '未设预算',
    // 最近交易(recent)视图文案。uncategorizedLabel 直接复用
    // commonUncategorized;noTransactionsLabel 比已有的 accountNoTransactions
    // ("暂无交易记录")更短(卡片空间紧张),对应新增 arb key
    // widgetNoTransactions。
    String uncategorizedLabel = '未分类',
    String noTransactionsLabel = '暂无交易',
    // 综合仪表盘(dashboard)"最近交易"区块标题,对应新增 arb key
    // `widgetRecentTransactions`。其余文案(本月支出/收入、未分类、暂无交易、
    // 记一笔)全部复用上面 glance/recent/quickAdd 已有的同名参数,不重复造词。
    String dashboardRecentLabel = '最近交易',
    // 预热:true 时渲染整个 [WidgetSpec.catalog] 而非仅"已安装"(D5 的显式
    // 例外)。用于 App 启动 / 切账本这类低频时机,把全部类型×尺寸的图先备好
    // ——否则用户添加一个从未渲染过的组件类型时,共享存储里没有对应图片,
    // 原生壳只能显示占位,要等下一次 App 内触发渲染才有内容("添加小组件后
    // 得等一会才渲染好"的根因)。改主题色 / 记一笔等高频数据变化触发仍走
    // "只渲已安装"的快路径,不受影响。
    bool warmUpAllSpecs = false,
  }) async {
    try {
      final specs = warmUpAllSpecs
          ? selectSpecsToRender(null, warmUpAll: true)
          : await _resolveSpecsToRender();
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
            noAccountsLabel: noAccountsLabel,
            quickAddLabel: quickAddLabel,
            budgetLabel: budgetLabel,
            budgetUsedLabel: budgetUsedLabel,
            budgetTotalLabel: budgetTotalLabel,
            budgetRemainingLabel: budgetRemainingLabel,
            noBudgetLabel: noBudgetLabel,
            uncategorizedLabel: uncategorizedLabel,
            noTransactionsLabel: noTransactionsLabel,
            dashboardRecentLabel: dashboardRecentLabel,
          );
        } catch (e, st) {
          // 单个 spec 渲染失败不应阻断其余 spec。
          logger.error(_tag, '渲染 ${spec.imageKey} 失败,跳过', e, st);
        }
      }

      // 触发原生壳刷新:按已渲染 spec 去重出各自的 (iOS kind, Android provider
      // 类名) 逐个触发,让新组件也能像现有 glance 一样在数据变化后即时刷新
      // (否则新 kind 只能等 WidgetKit/AppWidget 自己的 timeline,可能几十分钟)。
      // glance-medium 沿用旧 kind `BeeCountWidget` / 旧 provider 类名(D2);
      // 新组件用各自标识(iosKind/androidClassName 由 P3/P4 回填到 WidgetSpec)。
      final triggered = <String>{};
      for (final spec in specs) {
        if (spec.iosKind == null && spec.androidClassName == null) continue;
        // 同一内容类型的多个尺寸共享同一 kind/provider,去重避免重复触发。
        if (!triggered.add('${spec.iosKind}|${spec.androidClassName}')) continue;
        await HomeWidget.updateWidget(
          qualifiedAndroidName: spec.androidClassName,
          iOSName: spec.iosKind,
        );
      }
      logger.info(
        _tag,
        '小组件更新完成,已渲染 ${specs.length} 个 spec: '
        '${specs.map((s) => s.imageKey).join(', ')}',
      );
    } catch (e, st) {
      logger.error(_tag, '更新小组件失败', e, st);
    }
  }

  /// [updateAllWidgets] 的语言感知封装,供没有 [BuildContext] 的调用点使用
  /// (`main.dart` 的 `_WidgetUpdateObserver`、`providers/theme_providers
  /// .dart` 的主题色/收支配色监听、`pages/main/ledgers_page_new.dart` 改
  /// 账本起始日后的即时刷新)——内部靠 [resolveWidgetLocalizations] 把
  /// [explicitLocale] 还原成 [AppLocalizations],再逐个填入
  /// [updateAllWidgets] 对应的文案参数,取代它们各自的中文默认值。
  ///
  /// 唯一真正有 [BuildContext]、能用 `AppLocalizations.of(context)` 的调用点
  /// 是 `providers/widget_provider.dart` 的 `updateAppWidget`,那里更准确
  /// (与当前 widget 树完全一致),不经过这个封装。
  Future<void> updateAllWidgetsLocalized(
    BaseRepository repository,
    int ledgerId,
    Color themeColor, {
    required Locale? explicitLocale,
    bool redForIncome = true,
    String baseCurrency = 'CNY',
    bool warmUpAllSpecs = false,
  }) {
    final l10n = resolveWidgetLocalizations(explicitLocale);
    return updateAllWidgets(
      repository,
      ledgerId,
      themeColor,
      redForIncome: redForIncome,
      warmUpAllSpecs: warmUpAllSpecs,
      appName: l10n.appTitle,
      monthSuffix: l10n.widgetMonthSuffix,
      todayLabel: l10n.widgetToday,
      todayExpenseLabel: l10n.widgetTodayExpense,
      todayIncomeLabel: l10n.widgetTodayIncome,
      monthExpenseLabel: l10n.widgetMonthExpense,
      monthIncomeLabel: l10n.widgetMonthIncome,
      baseCurrency: baseCurrency,
      netWorthLabel: l10n.accountTotalBalance,
      totalAssetsLabel: l10n.totalAssets,
      totalLiabilitiesLabel: l10n.totalLiabilities,
      noAccountsLabel: l10n.widgetNoAccounts,
      quickAddLabel: l10n.widgetQuickAddLabel,
      budgetLabel: l10n.budgetMonthlyBudget,
      budgetUsedLabel: l10n.budgetUsed,
      budgetTotalLabel: l10n.widgetBudgetTotal,
      budgetRemainingLabel: l10n.widgetBudgetRemaining,
      noBudgetLabel: l10n.widgetNoBudget,
      uncategorizedLabel: l10n.commonUncategorized,
      noTransactionsLabel: l10n.widgetNoTransactions,
      dashboardRecentLabel: l10n.widgetRecentTransactions,
    );
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
    required String noAccountsLabel,
    required String quickAddLabel,
    required String budgetLabel,
    required String budgetUsedLabel,
    required String budgetTotalLabel,
    required String budgetRemainingLabel,
    required String noBudgetLabel,
    required String uncategorizedLabel,
    required String noTransactionsLabel,
    required String dashboardRecentLabel,
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
          noAccountsLabel: noAccountsLabel,
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
        await _renderBudget(
          spec,
          repository: repository,
          ledgerId: ledgerId,
          themeColor: themeColor,
          redForIncome: redForIncome,
          dark: dark,
          budgetLabel: budgetLabel,
          usedLabel: budgetUsedLabel,
          totalLabel: budgetTotalLabel,
          remainingLabel: budgetRemainingLabel,
          noBudgetLabel: noBudgetLabel,
        );
        return;
      case HWType.recent:
        await _renderRecent(
          spec,
          repository: repository,
          ledgerId: ledgerId,
          themeColor: themeColor,
          redForIncome: redForIncome,
          dark: dark,
          uncategorizedLabel: uncategorizedLabel,
          emptyLabel: noTransactionsLabel,
        );
        return;
      case HWType.dashboard:
        await _renderDashboard(
          spec,
          repository: repository,
          ledgerId: ledgerId,
          themeColor: themeColor,
          redForIncome: redForIncome,
          dark: dark,
          baseCurrency: baseCurrency,
          monthExpenseLabel: monthExpenseLabel,
          monthIncomeLabel: monthIncomeLabel,
          recentLabel: dashboardRecentLabel,
          uncategorizedLabel: uncategorizedLabel,
          noTransactionsLabel: noTransactionsLabel,
          quickAddLabel: quickAddLabel,
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
    required String noAccountsLabel,
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
      noAccountsLabel: noAccountsLabel,
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

  /// 渲染预算进度(budget):小/中两档,均已接 [BudgetView] 真实视图。
  Future<void> _renderBudget(
    WidgetSpec spec, {
    required BaseRepository repository,
    required int ledgerId,
    required Color themeColor,
    required bool redForIncome,
    required bool dark,
    required String budgetLabel,
    required String usedLabel,
    required String totalLabel,
    required String remainingLabel,
    required String noBudgetLabel,
  }) async {
    final overview = await WidgetDataService.gatherBudget(
      repository: repository,
      ledgerId: ledgerId,
    );
    // 预算金额没有独立币种列,固定跟随账本自身币种(与全局本位币
    // baseCurrency 是两个不同概念,见 gatherLedgerCurrency 文档)。
    final currencyCode = await WidgetDataService.gatherLedgerCurrency(
      repository: repository,
      ledgerId: ledgerId,
    );

    final view = BudgetView(
      size: spec.size,
      overview: overview,
      currencyCode: currencyCode,
      themeColor: themeColor,
      redForIncome: redForIncome,
      dark: dark,
      budgetLabel: budgetLabel,
      usedLabel: usedLabel,
      totalLabel: totalLabel,
      remainingLabel: remainingLabel,
      noBudgetLabel: noBudgetLabel,
      width: spec.logicalSize.width,
      height: spec.logicalSize.height,
    );

    await _renderView(view, spec: spec, logicalSize: spec.logicalSize);
  }

  /// 渲染最近交易(recent):中/大两档,均已接 [RecentView] 真实视图。
  Future<void> _renderRecent(
    WidgetSpec spec, {
    required BaseRepository repository,
    required int ledgerId,
    required Color themeColor,
    required bool redForIncome,
    required bool dark,
    required String uncategorizedLabel,
    required String emptyLabel,
  }) async {
    // large 更高,多展示几笔(见 RecentView 文档:medium 前 3 笔,large 前
    // 6 笔)。
    final limit = spec.size == HWSize.large ? 6 : 3;
    final items = await WidgetDataService.gatherRecent(
      repository: repository,
      ledgerId: ledgerId,
      limit: limit,
    );
    // 交易金额格式化优先用交易自身 currencyCode,这里只是缺失时的兜底
    // (账本自身币种,与 budget 用同一个 gatherLedgerCurrency)。
    final defaultCurrency = await WidgetDataService.gatherLedgerCurrency(
      repository: repository,
      ledgerId: ledgerId,
    );

    final view = RecentView(
      size: spec.size,
      items: items,
      defaultCurrency: defaultCurrency,
      themeColor: themeColor,
      redForIncome: redForIncome,
      dark: dark,
      uncategorizedLabel: uncategorizedLabel,
      emptyLabel: emptyLabel,
      width: spec.logicalSize.width,
      height: spec.logicalSize.height,
    );

    await _renderView(view, spec: spec, logicalSize: spec.logicalSize);
  }

  /// 渲染综合仪表盘(dashboard):仅大号一档,已接 [DashboardView] 真实视图。
  ///
  /// 至此 [HWType] 全部 6 种类型均已接入真实渲染,Phase B2b 完成
  /// (取数链路早在 Phase B1 就已就绪,本阶段只是逐个补上视图)。
  Future<void> _renderDashboard(
    WidgetSpec spec, {
    required BaseRepository repository,
    required int ledgerId,
    required Color themeColor,
    required bool redForIncome,
    required bool dark,
    required String baseCurrency,
    required String monthExpenseLabel,
    required String monthIncomeLabel,
    required String recentLabel,
    required String uncategorizedLabel,
    required String noTransactionsLabel,
    required String quickAddLabel,
  }) async {
    final data = await WidgetDataService.gatherDashboard(
      repository: repository,
      ledgerId: ledgerId,
      baseCurrency: baseCurrency,
    );
    // 顶部本月支出/收入 + 内嵌最近交易行的金额格式化都是"单一账本视角",跟随
    // 账本自身币种,不是净值趋势用的全局本位币 baseCurrency(两者语义不同,
    // 见 gatherLedgerCurrency 文档;dashboard 是唯一同时需要这两种币种概念
    // 的 spec)。
    final defaultCurrency = await WidgetDataService.gatherLedgerCurrency(
      repository: repository,
      ledgerId: ledgerId,
    );

    final view = DashboardView(
      data: data,
      defaultCurrency: defaultCurrency,
      themeColor: themeColor,
      redForIncome: redForIncome,
      dark: dark,
      monthExpenseLabel: monthExpenseLabel,
      monthIncomeLabel: monthIncomeLabel,
      recentLabel: recentLabel,
      uncategorizedLabel: uncategorizedLabel,
      noTransactionsLabel: noTransactionsLabel,
      quickAddLabel: quickAddLabel,
      width: spec.logicalSize.width,
      height: spec.logicalSize.height,
    );

    await _renderView(view, spec: spec, logicalSize: spec.logicalSize);
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
    // 真正的交互入口是各原生壳拼的 beecount:// 深链,不经过这里。这个回调
    // 只是 `home_widget` 交互式组件 API 的注册要求,当前阶段先落一条日志
    // 占位,预留给未来"组件内即时记账"(不在本阶段范围,见 D8/P5)。
    //
    // 可能在纯后台 isolate 中触发(`@pragma('vm:entry-point')`),`logger`
    // 依赖的插件通道不一定已就绪,这里包一层 try/catch 保证回调本身绝不
    // 因日志失败而抛异常。
    try {
      logger.debug(_tag, '收到小组件交互回调: uri=$uri');
    } catch (_) {
      // 静默忽略,见上方注释。
    }
  }
}
