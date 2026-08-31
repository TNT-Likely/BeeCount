import 'dart:async' show Completer;
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../data/repositories/base_repository.dart';
import '../l10n/app_localizations.dart';
import '../services/system/logger_service.dart';
import '../utils/currencies.dart' show getCurrencySymbol;
import '../widgets/biz/format_money.dart' show formatMoneyCompact;
import 'views/budget_view.dart';
import 'views/bee_trail_view.dart';
import 'views/consumption_rhythm_view.dart';
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

/// 预热批次的渲染顺序:整个 [WidgetSpec.catalog],但把 [installedFirst]
/// (用户桌面上已放置的组件)排到最前——预热要渲全目录,已安装的先出图,
/// 缩短"打开 App 后桌面组件才刷新"的感知等待。
///
/// [installedFirst] 应来自 `getInstalledWidgets` 的匹配结果(拿不到时退化的
/// 默认集也可,只影响排序不影响覆盖面);纯函数,便于单测。
List<WidgetSpec> orderCatalogForWarmUp(List<WidgetSpec> installedFirst) {
  return [
    ...installedFirst,
    ...WidgetSpec.catalog.where((s) => !installedFirst.contains(s)),
  ];
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

  /// 渲染批次串行门:任意时刻只允许一个 [updateAllWidgets] 批次在跑。
  ///
  /// [_renderView] 在渲染窗口内全局接管 FlutterError.onError /
  /// ErrorWidget.builder,两个批次并发时(各触发点之间没有互斥:记账后、
  /// 前台恢复、系统明暗切换、主题色修改都可能同时到来)交错的 finally 会把
  /// **对方批次的 hook** 当"原值"恢复,主应用的错误处理从此永久指向渲染态
  /// (ErrorWidget 永久透明、onError 永久打小组件日志)。串行化后各批次的
  /// 接管窗口天然不重叠;顺带避免多批次同时离屏渲染的内存峰值。
  Future<void> _renderGate = Future.value();

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
  /// - `app.dart` 前台恢复的调用点也已走 [updateAllWidgetsLocalized],至此
  ///   全部触发路径均跟随 App 语言,下面的中文默认值只是最后的兜底。
  Future<void> updateAllWidgets(
    BaseRepository repository,
    int ledgerId,
    Color themeColor, {
    bool redForIncome = true,
    // 六款组件统一内容标签(2026-07 A 方案):glance 中号从「App 名 header」
    // 改为内容标签(iOS HIG:widget 内不放 App 名),其余三款新增标签。
    // 分别对应 arb widgetGalleryGlanceTitle / widgetGalleryQuickAddTitle /
    // widgetRecentTransactions / widgetDashboardTitle。
    String glanceTitleLabel = '收支速览',
    String quickAddTitleLabel = '快速记账',
    String recentTitleLabel = '最近交易',
    String dashboardTitleLabel = '本月概览',
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
    String consumptionRhythmTitleLabel = '消费节奏',
    String consumptionRhythmRangeLabel = '近 30 天',
    String consumptionRhythmStableLabel = '消费很均匀',
    String consumptionRhythmIncreaseLabel = '比上周更快',
    String consumptionRhythmDecreaseLabel = '比上周更稳',
    String consumptionRhythmEmptyLabel = '本月还没有支出',
    String beeTrailTitleLabel = '记账连续蜂迹',
    String beeTrailStreakSuffix = '天',
    String beeTrailCompletionLabel = '本月完成率',
    String beeTrailEmptyLabel = '今天记一笔，点亮第一格',
    // 预热:true 时渲染整个 [WidgetSpec.catalog] 而非仅"已安装"(D5 的显式
    // 例外)。用于 App 启动 / 切账本这类低频时机,把全部类型×尺寸的图先备好
    // ——否则用户添加一个从未渲染过的组件类型时,共享存储里没有对应图片,
    // 原生壳只能显示占位,要等下一次 App 内触发渲染才有内容("添加小组件后
    // 得等一会才渲染好"的根因)。改主题色 / 记一笔等高频数据变化触发仍走
    // "只渲已安装"的快路径,不受影响。
    bool warmUpAllSpecs = false,
  }) async {
    // 排队进串行门(动机见 _renderGate 文档);gate 在 finally 里必然放行,
    // 前一批次即使异常也不会卡死队列。
    final prev = _renderGate;
    final gate = Completer<void>();
    _renderGate = gate.future;
    await prev;
    try {
      List<WidgetSpec> specs;
      if (warmUpAllSpecs) {
        // 预热渲全目录,但**已安装的组件排前面先出图**:dashboard/netWorth 的
        // 30 天趋势即使有批次缓存也仍是最重的查询,若目录顺序恰好把用户桌面上
        // 已放置的组件排在后面,会拖长"打开 App 后组件才刷新"的感知等待。
        specs = orderCatalogForWarmUp(await _resolveSpecsToRender());
      } else {
        specs = await _resolveSpecsToRender();
      }
      if (specs.isEmpty) {
        logger.debug(_tag, '没有已安装的桌面组件,跳过本次渲染');
        return;
      }

      // 批次取数缓存:同类型多尺寸 + dashboard 复用,一批只查一次(尤其 30 天
      // 净值趋势从 4 次压到 1 次,见 WidgetGatherBatch 文档)。
      final batch = WidgetGatherBatch(
        repository: repository,
        ledgerId: ledgerId,
        baseCurrency: baseCurrency,
      );

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
            batch: batch,
            themeColor: themeColor,
            redForIncome: redForIncome,
            dark: dark,
            glanceTitleLabel: glanceTitleLabel,
            quickAddTitleLabel: quickAddTitleLabel,
            recentTitleLabel: recentTitleLabel,
            dashboardTitleLabel: dashboardTitleLabel,
            monthSuffix: monthSuffix,
            todayLabel: todayLabel,
            todayExpenseLabel: todayExpenseLabel,
            todayIncomeLabel: todayIncomeLabel,
            monthExpenseLabel: monthExpenseLabel,
            monthIncomeLabel: monthIncomeLabel,
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
            consumptionRhythmTitleLabel: consumptionRhythmTitleLabel,
            consumptionRhythmRangeLabel: consumptionRhythmRangeLabel,
            consumptionRhythmStableLabel: consumptionRhythmStableLabel,
            consumptionRhythmIncreaseLabel: consumptionRhythmIncreaseLabel,
            consumptionRhythmDecreaseLabel: consumptionRhythmDecreaseLabel,
            consumptionRhythmEmptyLabel: consumptionRhythmEmptyLabel,
            beeTrailTitleLabel: beeTrailTitleLabel,
            beeTrailStreakSuffix: beeTrailStreakSuffix,
            beeTrailCompletionLabel: beeTrailCompletionLabel,
            beeTrailEmptyLabel: beeTrailEmptyLabel,
          );
        } catch (e, st) {
          // 单个 spec 渲染失败不应阻断其余 spec。
          logger.error(_tag, '渲染 ${spec.imageKey} 失败,跳过', e, st);
        }
      }

      // 触发原生壳刷新:按已渲染 spec 去重出全部 iOS kind / Android provider
      // 类名逐个触发,让组件在数据变化后即时刷新(否则只能等 WidgetKit/
      // AppWidget 自己的 timeline,可能几十分钟)。Android 侧要覆盖**全部**
      // 宿主类名(主类 + 按尺寸拆分的入口子类,见 WidgetSpec.
      // androidExtraClassNames)——用户可能装的是"净资产·大"这类子类入口。
      // 无实例的 kind/provider 触发是无害 no-op。
      if (Platform.isIOS) {
        final kinds = <String>{
          for (final spec in specs)
            if (spec.iosKind != null) spec.iosKind!,
        };
        for (final kind in kinds) {
          await HomeWidget.updateWidget(iOSName: kind);
        }
      } else {
        final names = <String>{
          for (final spec in specs) ...spec.androidAllClassNames,
        };
        for (final name in names) {
          await HomeWidget.updateWidget(qualifiedAndroidName: name);
        }
      }
      logger.info(
        _tag,
        '小组件更新完成,已渲染 ${specs.length} 个 spec: '
        '${specs.map((s) => s.imageKey).join(', ')}',
      );
    } catch (e, st) {
      logger.error(_tag, '更新小组件失败', e, st);
    } finally {
      gate.complete();
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
      glanceTitleLabel: l10n.widgetGalleryGlanceTitle,
      quickAddTitleLabel: l10n.widgetGalleryQuickAddTitle,
      recentTitleLabel: l10n.widgetRecentTransactions,
      dashboardTitleLabel: l10n.widgetDashboardTitle,
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
      consumptionRhythmTitleLabel: l10n.widgetConsumptionRhythmTitle,
      consumptionRhythmRangeLabel: l10n.widgetConsumptionRhythmRange,
      consumptionRhythmStableLabel: l10n.widgetConsumptionRhythmStable,
      consumptionRhythmIncreaseLabel: l10n.widgetConsumptionRhythmIncrease,
      consumptionRhythmDecreaseLabel: l10n.widgetConsumptionRhythmDecrease,
      consumptionRhythmEmptyLabel: l10n.widgetConsumptionRhythmEmpty,
      beeTrailTitleLabel: l10n.widgetBeeTrailTitle,
      beeTrailStreakSuffix: l10n.widgetBeeTrailStreakSuffix,
      beeTrailCompletionLabel: l10n.widgetBeeTrailCompletion,
      beeTrailEmptyLabel: l10n.widgetBeeTrailEmpty,
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
    required WidgetGatherBatch batch,
    required Color themeColor,
    required bool redForIncome,
    required bool dark,
    required String glanceTitleLabel,
    required String quickAddTitleLabel,
    required String recentTitleLabel,
    required String dashboardTitleLabel,
    required String monthSuffix,
    required String todayLabel,
    required String todayExpenseLabel,
    required String todayIncomeLabel,
    required String monthExpenseLabel,
    required String monthIncomeLabel,
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
    required String consumptionRhythmTitleLabel,
    required String consumptionRhythmRangeLabel,
    required String consumptionRhythmStableLabel,
    required String consumptionRhythmIncreaseLabel,
    required String consumptionRhythmDecreaseLabel,
    required String consumptionRhythmEmptyLabel,
    required String beeTrailTitleLabel,
    required String beeTrailStreakSuffix,
    required String beeTrailCompletionLabel,
    required String beeTrailEmptyLabel,
  }) async {
    switch (spec.type) {
      case HWType.glance:
        await _renderGlance(
          spec,
          batch: batch,
          themeColor: themeColor,
          redForIncome: redForIncome,
          dark: dark,
          titleLabel: glanceTitleLabel,
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
          batch: batch,
          themeColor: themeColor,
          redForIncome: redForIncome,
          dark: dark,
          netWorthLabel: netWorthLabel,
          totalAssetsLabel: totalAssetsLabel,
          totalLiabilitiesLabel: totalLiabilitiesLabel,
          noAccountsLabel: noAccountsLabel,
        );
        return;
      case HWType.quickAdd:
        await _renderQuickAdd(
          spec,
          batch: batch,
          themeColor: themeColor,
          dark: dark,
          addLabel: quickAddLabel,
          titleLabel: quickAddTitleLabel,
        );
        return;
      case HWType.budget:
        await _renderBudget(
          spec,
          batch: batch,
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
          batch: batch,
          themeColor: themeColor,
          redForIncome: redForIncome,
          dark: dark,
          uncategorizedLabel: uncategorizedLabel,
          emptyLabel: noTransactionsLabel,
          titleLabel: recentTitleLabel,
        );
        return;
      case HWType.dashboard:
        await _renderDashboard(
          spec,
          batch: batch,
          themeColor: themeColor,
          redForIncome: redForIncome,
          dark: dark,
          monthExpenseLabel: monthExpenseLabel,
          monthIncomeLabel: monthIncomeLabel,
          recentLabel: dashboardRecentLabel,
          uncategorizedLabel: uncategorizedLabel,
          noTransactionsLabel: noTransactionsLabel,
          quickAddLabel: quickAddLabel,
          titleLabel: dashboardTitleLabel,
        );
        return;
      case HWType.consumptionRhythm:
        await _renderConsumptionRhythm(
          spec,
          batch: batch,
          themeColor: themeColor,
          dark: dark,
          titleLabel: consumptionRhythmTitleLabel,
          rangeLabel: consumptionRhythmRangeLabel,
          stableLabel: consumptionRhythmStableLabel,
          increaseLabel: consumptionRhythmIncreaseLabel,
          decreaseLabel: consumptionRhythmDecreaseLabel,
          emptyLabel: consumptionRhythmEmptyLabel,
        );
        return;
      case HWType.beeTrail:
        await _renderBeeTrail(
          spec,
          batch: batch,
          themeColor: themeColor,
          dark: dark,
          titleLabel: beeTrailTitleLabel,
          streakSuffix: beeTrailStreakSuffix,
          completionLabel: beeTrailCompletionLabel,
          emptyLabel: beeTrailEmptyLabel,
        );
        return;
    }
  }

  Future<void> _renderConsumptionRhythm(
    WidgetSpec spec, {
    required WidgetGatherBatch batch,
    required Color themeColor,
    required bool dark,
    required String titleLabel,
    required String rangeLabel,
    required String stableLabel,
    required String increaseLabel,
    required String decreaseLabel,
    required String emptyLabel,
  }) async {
    final view = ConsumptionRhythmView(
      activity: await batch.dailyActivity30(),
      themeColor: themeColor,
      dark: dark,
      titleLabel: titleLabel,
      rangeLabel: rangeLabel,
      stableLabel: stableLabel,
      increaseLabel: increaseLabel,
      decreaseLabel: decreaseLabel,
      emptyLabel: emptyLabel,
      width: spec.logicalSize.width,
      height: spec.logicalSize.height,
    );
    await _renderView(view,
        spec: spec,
        logicalSize: spec.logicalSize,
        themeColor: themeColor,
        dark: dark);
  }

  Future<void> _renderBeeTrail(
    WidgetSpec spec, {
    required WidgetGatherBatch batch,
    required Color themeColor,
    required bool dark,
    required String titleLabel,
    required String streakSuffix,
    required String completionLabel,
    required String emptyLabel,
  }) async {
    final view = BeeTrailView(
      activity: await batch.dailyActivity30(),
      themeColor: themeColor,
      dark: dark,
      titleLabel: titleLabel,
      streakSuffix: streakSuffix,
      completionLabel: completionLabel,
      emptyLabel: emptyLabel,
      width: spec.logicalSize.width,
      height: spec.logicalSize.height,
    );
    await _renderView(view,
        spec: spec,
        logicalSize: spec.logicalSize,
        themeColor: themeColor,
        dark: dark);
  }

  /// 渲染收支速览(glance):小/中两档,均已接 [GlanceView] 真实视图。
  Future<void> _renderGlance(
    WidgetSpec spec, {
    required WidgetGatherBatch batch,
    required Color themeColor,
    required bool redForIncome,
    required bool dark,
    required String titleLabel,
    required String monthSuffix,
    required String todayLabel,
    required String todayExpenseLabel,
    required String todayIncomeLabel,
    required String monthExpenseLabel,
    required String monthIncomeLabel,
  }) async {
    final data = await batch.glance();

    // 金额符号跟随账本自身币种(v30 多币种后账本各有币种),与 budget/
    // recent/dashboard 同一套 getCurrencySymbol + formatMoneyCompact——
    // 历史版这里硬编码 NumberFormat(symbol: '¥'),非 CNY 账本符号错误
    // (2026-07 用户实机反馈),glance 是六款里最后一个接上币种链路的。
    final currency = await batch.ledgerCurrency();
    String fmt(double v) =>
        '${getCurrencySymbol(currency)}${formatMoneyCompact(v)}';
    final todayExpense = fmt(data.todayExpenseTotal);
    final todayIncome = fmt(data.todayIncomeTotal);
    final monthExpense = fmt(data.monthExpenseTotal);
    final monthIncome = fmt(data.monthIncomeTotal);

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
        titleLabel: titleLabel,
        monthSuffix: monthSuffix,
        todayLabel: todayLabel,
        todayExpenseLabel: todayExpenseLabel,
        todayIncomeLabel: todayIncomeLabel,
        monthExpenseLabel: monthExpenseLabel,
        monthIncomeLabel: monthIncomeLabel,
        width: renderSize.width,
        height: renderSize.height,
      );
    }

    await _renderView(view,
        spec: spec,
        logicalSize: renderSize,
        themeColor: themeColor,
        dark: dark);
  }

  /// 渲染净资产(netWorth):小/中/大三档,均已接 [NetWorthView] 真实视图。
  Future<void> _renderNetWorth(
    WidgetSpec spec, {
    required WidgetGatherBatch batch,
    required Color themeColor,
    required bool redForIncome,
    required bool dark,
    required String netWorthLabel,
    required String totalAssetsLabel,
    required String totalLiabilitiesLabel,
    required String noAccountsLabel,
  }) async {
    final breakdown = await batch.netWorthBreakdown();

    // 趋势统一取近 30 天(含今天),小/中/大三档与 dashboard 共用批次内同一份
    // (重查询只算一次,见 WidgetGatherBatch.netWorthTrend30 文档)。
    final trend = await batch.netWorthTrend30();

    // 账户明细只有大号才展示,小/中号不触发这份数据的查询(batch 惰性)。
    final topAccounts = spec.size == HWSize.large
        ? await batch.netWorthTopAccounts()
        : const <NetWorthAccountItem>[];
    final baseCurrency = batch.baseCurrency;

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

    await _renderView(view,
        spec: spec,
        logicalSize: spec.logicalSize,
        themeColor: themeColor,
        dark: dark);
  }

  /// 渲染快速记账(quickAdd):小/中两档,均已接 [QuickAddView] 真实视图。
  Future<void> _renderQuickAdd(
    WidgetSpec spec, {
    required WidgetGatherBatch batch,
    required Color themeColor,
    required bool dark,
    required String addLabel,
    required String titleLabel,
  }) async {
    // 批次内按最大需求取 7 个(medium 2×4 网格用满);small 由 QuickAddView
    // 内部截断到 3 个 + 补位(见 WidgetGatherBatch.quickAddCategories 文档)。
    final categories = await batch.quickAddCategories();

    final view = QuickAddView(
      size: spec.size,
      categories: categories,
      themeColor: themeColor,
      dark: dark,
      addLabel: addLabel,
      titleLabel: titleLabel,
      width: spec.logicalSize.width,
      height: spec.logicalSize.height,
    );

    await _renderView(view,
        spec: spec,
        logicalSize: spec.logicalSize,
        themeColor: themeColor,
        dark: dark);
  }

  /// 渲染预算进度(budget):小/中两档,均已接 [BudgetView] 真实视图。
  Future<void> _renderBudget(
    WidgetSpec spec, {
    required WidgetGatherBatch batch,
    required Color themeColor,
    required bool redForIncome,
    required bool dark,
    required String budgetLabel,
    required String usedLabel,
    required String totalLabel,
    required String remainingLabel,
    required String noBudgetLabel,
  }) async {
    final overview = await batch.budget();
    // 预算金额没有独立币种列,固定跟随账本自身币种(与全局本位币
    // baseCurrency 是两个不同概念,见 gatherLedgerCurrency 文档)。
    final currencyCode = await batch.ledgerCurrency();
    // 中号下半排兜底:没设分类预算时用本月支出 Top3 分类占比填充(惰性,
    // 有分类预算就不触发这次查询;见 BudgetView.fallbackShares 文档)。
    final fallbackShares = overview.categoryBudgets.isEmpty
        ? await batch.topSpendingShares()
        : const <({String name, double share})>[];

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
      fallbackShares: fallbackShares,
      width: spec.logicalSize.width,
      height: spec.logicalSize.height,
    );

    await _renderView(view,
        spec: spec,
        logicalSize: spec.logicalSize,
        themeColor: themeColor,
        dark: dark);
  }

  /// 渲染最近交易(recent):中/大两档,均已接 [RecentView] 真实视图。
  Future<void> _renderRecent(
    WidgetSpec spec, {
    required WidgetGatherBatch batch,
    required Color themeColor,
    required bool redForIncome,
    required bool dark,
    required String uncategorizedLabel,
    required String emptyLabel,
    required String titleLabel,
  }) async {
    // 批次内按最大需求取 6 笔;medium 由 RecentView 内部截断到 2 笔
    // (见 WidgetGatherBatch.recent 文档)。
    final items = await batch.recent();
    // 交易金额格式化优先用交易自身 currencyCode,这里只是缺失时的兜底
    // (账本自身币种,与 budget 共用批次内同一份 ledgerCurrency)。
    final defaultCurrency = await batch.ledgerCurrency();

    final view = RecentView(
      size: spec.size,
      items: items,
      defaultCurrency: defaultCurrency,
      themeColor: themeColor,
      redForIncome: redForIncome,
      dark: dark,
      uncategorizedLabel: uncategorizedLabel,
      emptyLabel: emptyLabel,
      titleLabel: titleLabel,
      width: spec.logicalSize.width,
      height: spec.logicalSize.height,
    );

    await _renderView(view,
        spec: spec,
        logicalSize: spec.logicalSize,
        themeColor: themeColor,
        dark: dark);
  }

  /// 渲染综合仪表盘(dashboard):仅大号一档,已接 [DashboardView] 真实视图。
  ///
  /// 至此 [HWType] 全部 6 种类型均已接入真实渲染,Phase B2b 完成
  /// (取数链路早在 Phase B1 就已就绪,本阶段只是逐个补上视图)。
  Future<void> _renderDashboard(
    WidgetSpec spec, {
    required WidgetGatherBatch batch,
    required Color themeColor,
    required bool redForIncome,
    required bool dark,
    required String monthExpenseLabel,
    required String monthIncomeLabel,
    required String recentLabel,
    required String uncategorizedLabel,
    required String noTransactionsLabel,
    required String quickAddLabel,
    required String titleLabel,
  }) async {
    // 组合数据全部来自批次缓存(glance/趋势/最近交易/常用分类若已被其它 spec
    // 取过则直接复用,见 WidgetGatherBatch.dashboard 文档)。
    final data = await batch.dashboard();
    // 顶部本月支出/收入 + 内嵌最近交易行的金额格式化都是"单一账本视角",跟随
    // 账本自身币种,不是净值趋势用的全局本位币 baseCurrency(两者语义不同,
    // 见 gatherLedgerCurrency 文档;dashboard 是唯一同时需要这两种币种概念
    // 的 spec)。
    final defaultCurrency = await batch.ledgerCurrency();

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
      titleLabel: titleLabel,
      width: spec.logicalSize.width,
      height: spec.logicalSize.height,
    );

    await _renderView(view,
        spec: spec,
        logicalSize: spec.logicalSize,
        themeColor: themeColor,
        dark: dark);
  }

  /// 统一的"渲染 + 落盘日志"收尾,供各类型渲染方法复用。
  ///
  /// **红屏防护(2026-07 真机问题)**:home_widget 的 `renderFlutterWidget`
  /// 用独立 BuildOwner 离屏渲染,视图 build 阶段抛异常不会向外传播为 Dart
  /// 异常,而是被 Flutter 替换成 `ErrorWidget`——debug 构建下就是「整卡红屏」
  /// 被原样渲进 PNG 显示在桌面上(release 下是灰卡),且真实异常堆栈被吞掉,
  /// 无从排查。这里在渲染窗口内临时接管两个全局 hook:
  ///
  /// 1. [FlutterError.onError]:把真实异常 + 堆栈写进日志中心(持久化 48h,
  ///    设置 → 日志中心可导出),这是定位真机红屏根因的关键线索;
  /// 2. [ErrorWidget.builder]:换成透明占位,防止红屏内容进图;渲染结束后若
  ///    确实捕获到异常,补渲一张干净的兜底卡(主题色刷新图标)覆盖落盘。
  ///
  /// 两个 hook 都是全局的,接管窗口仅限单次离屏渲染(毫秒级)并在 finally
  /// 恢复;主应用树恰好同时报错的概率极低,可接受。
  Future<void> _renderView(
    Widget view, {
    required WidgetSpec spec,
    required Size logicalSize,
    required Color themeColor,
    required bool dark,
  }) async {
    logger.debug(
      _tag,
      '渲染 ${spec.imageKey} - Platform: ${Platform.isIOS ? "iOS" : "Android"}, '
      'Size: ${logicalSize.width}x${logicalSize.height}',
    );

    final prevOnError = FlutterError.onError;
    final prevErrorBuilder = ErrorWidget.builder;
    Object? captured;
    FlutterError.onError = (details) {
      captured ??= details.exception;
      logger.error(_tag, '渲染 ${spec.imageKey} 视图内部异常(将改渲兜底卡)',
          details.exception, details.stack);
    };
    ErrorWidget.builder = (details) => const SizedBox.shrink();
    try {
      await HomeWidget.renderFlutterWidget(
        view,
        // spec.imageKey 对 glance-medium 特判为 'widgetImage'(D2 back-compat,
        // 详见 WidgetSpec.imageKey 注释),其余新 spec 才是 'widget_<type>_<size>'。
        key: spec.imageKey,
        logicalSize: logicalSize,
        // 由 4.0 降为 3.0:更省内存,对 iOS 30MB widget 进程内存上限更友好。
        pixelRatio: 3.0,
      );
    } finally {
      FlutterError.onError = prevOnError;
      ErrorWidget.builder = prevErrorBuilder;
    }

    if (captured != null) {
      // 首次渲染已把(残缺的)图落盘,这里补渲一张干净的兜底卡覆盖——组件上
      // 显示"主题色刷新图标卡"而非红屏/空白;真实根因见上面的 error 日志。
      await HomeWidget.renderFlutterWidget(
        _WidgetRenderFallbackCard(
          themeColor: themeColor,
          dark: dark,
          width: logicalSize.width,
          height: logicalSize.height,
        ),
        key: spec.imageKey,
        logicalSize: logicalSize,
        pixelRatio: 3.0,
      );
      logger.warning(_tag, '${spec.imageKey} 渲染出错,已用兜底卡覆盖(根因见上条 error 日志)');
      return;
    }

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

/// 视图渲染出错时的兜底卡(见 [WidgetManager._renderView] 红屏防护注释):
/// 与正常卡片同底色圆角,中央一个主题色刷新图标——语言无关(纯图标,不需要
/// 文案 i18n),点击组件仍走原生壳深链打开 App,打开后下一次渲染自动重试。
class _WidgetRenderFallbackCard extends StatelessWidget {
  final Color themeColor;
  final bool dark;
  final double width;
  final double height;

  const _WidgetRenderFallbackCard({
    required this.themeColor,
    required this.dark,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1A1712) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(Icons.refresh, size: 28, color: themeColor),
    );
  }
}
