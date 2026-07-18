import '../data/db.dart' show Transaction, Category, Account;
import '../data/repositories/base_repository.dart';
import '../data/repositories/budget_repository.dart' show BudgetOverview;
import '../services/currency/rate_math.dart';
import '../utils/month_range.dart';
import '../utils/net_worth_trend_utils.dart' show trendTodayAnchor;

/// 收支速览(glance)小组件所需的原始金额数据:今日 + 本月(账本自定义
/// 记账周期)的收入/支出合计。
class GlanceWidgetData {
  final double todayExpenseTotal;
  final double todayIncomeTotal;
  final double monthExpenseTotal;
  final double monthIncomeTotal;

  const GlanceWidgetData({
    required this.todayExpenseTotal,
    required this.todayIncomeTotal,
    required this.monthExpenseTotal,
    required this.monthIncomeTotal,
  });
}

/// 净资产(netWorth)小组件的总览数据:已折算到主币种(见
/// [WidgetDataService.gatherNetWorthBreakdown])。
class NetWorthBreakdownData {
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;

  /// 折算时因缺有效汇率被整条剔除的币种(ISO 大写);为空表示全部币种(含
  /// 只有一种币种的常见情形)都成功折算。与净资产页 `convertedNetWorthProvider`
  /// 同口径,UI 需要时可用它显式提示"部分资产未计入"。
  final List<String> missingCurrencies;

  const NetWorthBreakdownData({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    this.missingCurrencies = const [],
  });
}

/// 净资产大号小组件"账户明细列表"的单行:账户原币余额 + 折算到主币种后的值。
class NetWorthAccountItem {
  final Account account;

  /// 账户自身币种下的余额(`getAllAccountStats` 口径,未折算)。
  final double balance;

  /// 折算到主币种后的余额;为 null 表示该账户币种缺有效汇率(与净资产总览同
  /// 口径剔除出排序依据,但仍返回原始账户信息,由 UI 决定是否用原币兜底展示)。
  final double? convertedBalance;

  const NetWorthAccountItem({
    required this.account,
    required this.balance,
    required this.convertedBalance,
  });
}

/// 快速记账(quickAdd)小组件的单个分类格:分类 + 本周期支出合计(用于取 top-N)。
class QuickAddCategoryItem {
  final int categoryId;
  final String name;
  final String? icon;
  final double total;

  const QuickAddCategoryItem({
    required this.categoryId,
    required this.name,
    this.icon,
    required this.total,
  });
}

/// 最近交易(recent)小组件的单行:原始交易 + service 层按需拼好的分类/账户
/// (缺失即 null,由 View 决定占位展示,如"未分类"/转账文案交给 i18n)。
class RecentTransactionItem {
  final Transaction transaction;
  final Category? category;
  final Account? account;
  final Account? toAccount;

  const RecentTransactionItem({
    required this.transaction,
    this.category,
    this.account,
    this.toAccount,
  });
}

/// 综合仪表盘(dashboard)小组件的组合数据:收支速览 + 近 30 日净值趋势 +
/// 最近几笔交易 + 快速记账常用分类。
class DashboardWidgetData {
  final GlanceWidgetData glance;
  final List<({DateTime date, double assets, double liabilities, double net})>
      netWorthTrend;
  final List<RecentTransactionItem> recent;
  final List<QuickAddCategoryItem> quickAdd;

  const DashboardWidgetData({
    required this.glance,
    required this.netWorthTrend,
    required this.recent,
    required this.quickAdd,
  });
}

/// 桌面小组件数据服务:按内容类型(`HWType`)从 repo 取数、聚合成渲染所需
/// 的数值,供 `WidgetManager` 渲染各类型 View。
///
/// 全部方法均为纯粹的"repo → 数值"聚合,不依赖 Riverpod `ref`/`BuildContext`,
/// 便于用内存 Drift 库直接单测(见 `test/widget/widget_data_service_test.dart`)。
/// 多币种折算(netWorth 系列)复用 App 现有口径:
/// `services/currency/rate_math.dart` 的 `mergeEffectiveRates` /
/// `computeConvertedNetWorth`,与 `providers/currency_providers.dart` 的
/// `effectiveRatesProvider` / `convertedNetWorthProvider` / `netWorthTrendSeriesProvider`
/// 保持同一套换算逻辑(headless 版本直接读 repo,不走 ref.watch)。
class WidgetDataService {
  const WidgetDataService._();

  /// 取「今日」+「本月」(账本自定义起始日周期)收支合计。
  static Future<GlanceWidgetData> gatherGlance({
    required BaseRepository repository,
    required int ledgerId,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    // 「本月」= 账本自定义记账周期(包含今天的 [起始日, 次月起始日))
    final ledger = await repository.getLedgerById(ledgerId);
    final startDay = (ledger?.monthStartDay ?? 1).clamp(1, 28);
    final range = periodContaining(now, startDay);

    final todayExpense = await repository.totalsByCategory(
      ledgerId: ledgerId,
      type: 'expense',
      start: today,
      end: tomorrow,
    );
    final todayIncome = await repository.totalsByCategory(
      ledgerId: ledgerId,
      type: 'income',
      start: today,
      end: tomorrow,
    );
    final monthExpense = await repository.totalsByCategory(
      ledgerId: ledgerId,
      type: 'expense',
      start: range.start,
      end: range.end,
    );
    final monthIncome = await repository.totalsByCategory(
      ledgerId: ledgerId,
      type: 'income',
      start: range.start,
      end: range.end,
    );

    return GlanceWidgetData(
      todayExpenseTotal: _sumTotals(todayExpense),
      todayIncomeTotal: _sumTotals(todayIncome),
      monthExpenseTotal: _sumTotals(monthExpense),
      monthIncomeTotal: _sumTotals(monthIncome),
    );
  }

  // ---------------------------------------------------------------------
  // 净资产(netWorth)
  // ---------------------------------------------------------------------

  /// 净资产总览:总资产/总负债/净资产,折算到 [baseCurrency]。
  ///
  /// 口径与资产页 `convertedNetWorthProvider` 一致:按币种分组的原始分解
  /// ([BaseRepository.getNetWorthBreakdownByCurrency]) × 有效汇率
  /// ([_effectiveRates]) 折算求和,缺有效汇率的币种整条剔除(绝不按 1.0 兜底)。
  static Future<NetWorthBreakdownData> gatherNetWorthBreakdown({
    required BaseRepository repository,
    required String baseCurrency,
  }) async {
    final breakdown = await repository.getNetWorthBreakdownByCurrency();
    final rates = await _effectiveRates(repository, baseCurrency);
    final converted = computeConvertedNetWorth(
      breakdown: breakdown,
      rates: rates,
      base: baseCurrency,
    );
    return NetWorthBreakdownData(
      totalAssets: converted.totalAssets,
      totalLiabilities: converted.totalLiabilities,
      netWorth: converted.netWorth,
      missingCurrencies: converted.missingCurrencies,
    );
  }

  /// 净值趋势序列([start, end] 每日资产/负债/净值),折算到 [baseCurrency]。
  ///
  /// 口径与 `netWorthTrendSeriesProvider` 一致:这里在 headless 场景下自行
  /// 取 base 币种 + 有效汇率、拼出 `ratesToBase`(base 自身 1.0)喂给
  /// [BaseRepository.getNetWorthTrendSeries] —— provider 版本是从
  /// `ref.watch(baseCurrencyProvider)` / `effectiveRatesProvider` 拿,这里
  /// 直接把 [baseCurrency] 当参数传入,避免依赖 Riverpod。
  static Future<
      List<({DateTime date, double assets, double liabilities, double net})>>
      gatherNetWorthTrend({
    required BaseRepository repository,
    required String baseCurrency,
    required DateTime start,
    required DateTime end,
  }) async {
    final rates = await _effectiveRates(repository, baseCurrency);
    final ratesToBase = _ratesToBaseMap(rates, baseCurrency);
    return repository.getNetWorthTrendSeries(
      startDate: start,
      endDate: end,
      ratesToBase: ratesToBase,
    );
  }

  /// 净资产大号小组件的"账户明细":按折算到 [baseCurrency] 后的余额降序取
  /// 前 [limit] 个账户。已隐藏账户(`Account.hidden`)不进入这份展示列表——
  /// 隐藏账户仍计入净资产总额(见 [gatherNetWorthBreakdown]),但不是"我还在
  /// 用的账户"列表该展示的内容,与账户管理页(`accounts_page.dart`)的显示口径
  /// 一致。缺有效汇率的账户仍返回(`convertedBalance` 为 null),按原币
  /// 余额兜底排序,由 UI 决定是否提示"未折算"。
  static Future<List<NetWorthAccountItem>> gatherNetWorthTopAccounts({
    required BaseRepository repository,
    required String baseCurrency,
    int limit = 5,
  }) async {
    final accounts =
        (await repository.getAllAccounts()).where((a) => !a.hidden).toList();
    if (accounts.isEmpty) return const [];

    final stats = await repository.getAllAccountStats();
    final rates = await _effectiveRates(repository, baseCurrency);
    final base = baseCurrency.toUpperCase();

    final items = accounts.map((a) {
      final balance = stats[a.id]?.balance ?? 0.0;
      final code = a.currency.toUpperCase();
      double? converted;
      if (code == base) {
        converted = balance;
      } else {
        final eff = rates[code];
        final r = eff != null ? double.tryParse(eff.rate) : null;
        if (r != null && r > 0) converted = balance * r;
      }
      return NetWorthAccountItem(
        account: a,
        balance: balance,
        convertedBalance: converted,
      );
    }).toList();

    items.sort((x, y) =>
        (y.convertedBalance ?? y.balance).compareTo(x.convertedBalance ?? x.balance));
    return items.take(limit).toList();
  }

  // ---------------------------------------------------------------------
  // 快速记账(quickAdd)
  // ---------------------------------------------------------------------

  /// 本周期(账本自定义起始日)支出常用分类 top-[limit],按支出合计降序
  /// (复用 [BaseRepository.totalsByCategory] 已有的降序排序)。
  ///
  /// "未分类"桶(`id == null`)被剔除:快速记账格点开即需跳转
  /// `beecount://new?type=expense&category=<id>`,没有具体分类 id 无法深链。
  static Future<List<QuickAddCategoryItem>> gatherQuickAddCategories({
    required BaseRepository repository,
    required int ledgerId,
    int limit = 6,
  }) async {
    final now = DateTime.now();
    final ledger = await repository.getLedgerById(ledgerId);
    final startDay = (ledger?.monthStartDay ?? 1).clamp(1, 28);
    final range = periodContaining(now, startDay);

    final totals = await repository.totalsByCategory(
      ledgerId: ledgerId,
      type: 'expense',
      start: range.start,
      end: range.end,
    );

    return totals
        .where((e) => e.id != null)
        .take(limit)
        .map((e) => QuickAddCategoryItem(
              categoryId: e.id!,
              name: e.name,
              icon: e.icon,
              total: e.total,
            ))
        .toList();
  }

  // ---------------------------------------------------------------------
  // 预算进度(budget)
  // ---------------------------------------------------------------------

  /// 预算总览(总预算已用/剩余/百分比 + 分类用量),分类用量截断到前
  /// [topCategoryCount] 个(`getBudgetOverview` 内部已按使用率降序排列)。
  ///
  /// 直接复用现有 `BudgetRepository.getBudgetOverview`(周期跟随账本
  /// monthStartDay,月份锚点传 `DateTime.now()`),不新增 repo 方法。
  static Future<BudgetOverview> gatherBudget({
    required BaseRepository repository,
    required int ledgerId,
    int topCategoryCount = 3,
  }) async {
    final overview =
        await repository.getBudgetOverview(ledgerId, DateTime.now());
    if (overview.categoryBudgets.length <= topCategoryCount) {
      return overview;
    }
    return BudgetOverview(
      totalBudget: overview.totalBudget,
      categoryBudgets: overview.categoryBudgets.take(topCategoryCount).toList(),
      daysRemaining: overview.daysRemaining,
      dailyAvailable: overview.dailyAvailable,
    );
  }

  // ---------------------------------------------------------------------
  // 最近交易(recent)
  // ---------------------------------------------------------------------

  /// 最近 [limit] 笔交易,按需拼上分类/转入转出账户(缺失即 null)。
  ///
  /// 底层用新增的 [BaseRepository.getRecentTransactions](纯 Transaction 行、
  /// 无 join、不做 exclude 过滤),分类/账户在这里按 id 逐条查—— N 通常很小
  /// (小组件展示 3~4 笔),N+1 查询的开销可忽略,换来的是不需要处理
  /// `getRecentTransactionsWithCategory` 那套共享账本 override hydration。
  static Future<List<RecentTransactionItem>> gatherRecent({
    required BaseRepository repository,
    required int ledgerId,
    int limit = 4,
  }) async {
    final txs = await repository.getRecentTransactions(ledgerId, limit: limit);

    final items = <RecentTransactionItem>[];
    for (final t in txs) {
      final category =
          t.categoryId != null ? await repository.getCategoryById(t.categoryId!) : null;
      final account =
          t.accountId != null ? await repository.getAccount(t.accountId!) : null;
      final toAccount =
          t.toAccountId != null ? await repository.getAccount(t.toAccountId!) : null;
      items.add(RecentTransactionItem(
        transaction: t,
        category: category,
        account: account,
        toAccount: toAccount,
      ));
    }
    return items;
  }

  // ---------------------------------------------------------------------
  // 综合仪表盘(dashboard)
  // ---------------------------------------------------------------------

  /// 组合 [gatherGlance] + 近 30 日净值趋势([gatherNetWorthTrend]) +
  /// [gatherRecent] + [gatherQuickAddCategories]。
  static Future<DashboardWidgetData> gatherDashboard({
    required BaseRepository repository,
    required int ledgerId,
    required String baseCurrency,
    int recentCount = 3,
    int quickAddCount = 4,
  }) async {
    final glance = await gatherGlance(repository: repository, ledgerId: ledgerId);

    final end = trendTodayAnchor();
    final start = end.subtract(const Duration(days: 29)); // 近 30 日(含今天)
    final trend = await gatherNetWorthTrend(
      repository: repository,
      baseCurrency: baseCurrency,
      start: start,
      end: end,
    );

    final recent = await gatherRecent(
      repository: repository,
      ledgerId: ledgerId,
      limit: recentCount,
    );
    final quickAdd = await gatherQuickAddCategories(
      repository: repository,
      ledgerId: ledgerId,
      limit: quickAddCount,
    );

    return DashboardWidgetData(
      glance: glance,
      netWorthTrend: trend,
      recent: recent,
      quickAdd: quickAdd,
    );
  }

  // ---------------------------------------------------------------------
  // 多币种折算共用私有辅助(与 currency_providers.dart 的
  // effectiveRatesProvider / netWorthTrendSeriesProvider 构造逻辑保持一致)
  // ---------------------------------------------------------------------

  /// 有效汇率:手动 override > 最新自动汇率,两者都没有的 quote 不出现在结果里
  /// (`mergeEffectiveRates` 语义)。headless 版本直接读 repo,不依赖 ref。
  static Future<Map<String, EffectiveRate>> _effectiveRates(
    BaseRepository repository,
    String baseCurrency,
  ) async {
    final base = baseCurrency.toUpperCase();
    final autos = await repository.getLatestAutoRates(base);
    final overrides = await repository.getOverrides(base);
    return mergeEffectiveRates(
      autoRates: [
        for (final r in autos) (quote: r.quoteCurrency, rate: r.rate, rateDate: r.rateDate)
      ],
      overrides: [
        for (final o in overrides) (quote: o.quoteCurrency, rate: o.rate)
      ],
    );
  }

  /// [EffectiveRate] 折算表 → `getNetWorthTrendSeries` 需要的 `ratesToBase`
  /// (base 自身恒为 1.0,其余取解析成功且为正的汇率)。
  static Map<String, double> _ratesToBaseMap(
    Map<String, EffectiveRate> rates,
    String baseCurrency,
  ) {
    final base = baseCurrency.toUpperCase();
    final ratesToBase = <String, double>{base: 1.0};
    for (final e in rates.entries) {
      final r = double.tryParse(e.value.rate);
      if (r != null && r > 0) ratesToBase[e.key.toUpperCase()] = r;
    }
    return ratesToBase;
  }

  static double _sumTotals(
    List<({int? id, String name, String? icon, double total})> items,
  ) {
    return items.fold<double>(0.0, (sum, item) => sum + item.total);
  }
}
