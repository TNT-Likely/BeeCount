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

/// 桌面小组件近若干日的记账活动:每天至少保留一条(无交易日为 0 / false),
/// 供「消费节奏」与「记账连续蜂迹」共用。
class DailyWidgetActivity {
  final DateTime date;
  final double expenseTotal;
  final bool hasRecord;

  const DailyWidgetActivity({
    required this.date,
    required this.expenseTotal,
    required this.hasRecord,
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

  /// 取以 [now] 当天为终点的连续日活动。使用单个区间查询后在内存中按日
  /// 聚合，避免小组件渲染时按天发出 N 次数据库查询。
  ///
  /// 与统计页口径一致，`excludeFromStats` 的交易完全忽略；其余任何类型的
  /// 交易都代表当天完成过记账，但只有支出计入 [expenseTotal]。
  static Future<List<DailyWidgetActivity>> gatherDailyActivity({
    required BaseRepository repository,
    required int ledgerId,
    int days = 30,
    DateTime? now,
  }) async {
    assert(days > 0);
    final anchor = now ?? DateTime.now();
    final endDay = DateTime(anchor.year, anchor.month, anchor.day);
    final startDay = endDay.subtract(Duration(days: days - 1));
    final endExclusive = endDay.add(const Duration(days: 1));
    final expenses = List<double>.filled(days, 0);
    final records = List<bool>.filled(days, false);

    final transactions = await repository.getTransactionsByLedgerInRange(
      ledgerId: ledgerId,
      start: startDay,
      end: endExclusive,
    );
    for (final transaction in transactions) {
      if (transaction.excludeFromStats) continue;
      final date = DateTime(transaction.happenedAt.year,
          transaction.happenedAt.month, transaction.happenedAt.day);
      final index = date.difference(startDay).inDays;
      if (index < 0 || index >= days) continue;
      records[index] = true;
      if (transaction.type == 'expense') {
        expenses[index] += transaction.amount;
      }
    }

    return List.generate(
      days,
      (index) => DailyWidgetActivity(
        date: startDay.add(Duration(days: index)),
        expenseTotal: expenses[index],
        hasRecord: records[index],
      ),
      growable: false,
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
  ///
  /// **本周期用过的分类不足 [limit] 时,用账本其余可用支出分类(按 sortOrder)
  /// 补足**(补进来的 `total` 记 0)。快速记账组件是"入口"而不是"报表":
  /// 月初刚翻篇、或刚建账本时本周期一笔都还没记,不补的话中号 2×4 网格会
  /// 空出一大片占位格,而用户真正想要的恰恰是这时候有格子可点。默认分类
  /// seed 就有 40+ 个支出分类(见 `SeedService.flatExpenseCategoryKeys`),
  /// 正常账本补得满。
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

    final items = totals
        .where((e) => e.id != null)
        .take(limit)
        .map((e) => QuickAddCategoryItem(
              categoryId: e.id!,
              name: e.name,
              icon: e.icon,
              total: e.total,
            ))
        .toList();
    if (items.length >= limit) return items;

    // 补足(见方法文档):按 sortOrder 取账本可用支出分类,跳过已在列表里的。
    final used = items.map((e) => e.categoryId).toSet();
    final usable = await repository.getUsableCategories('expense');
    for (final c in usable) {
      if (items.length >= limit) break;
      if (used.contains(c.id)) continue;
      items.add(QuickAddCategoryItem(
        categoryId: c.id,
        name: c.name,
        icon: c.icon,
        total: 0,
      ));
    }
    return items;
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

  /// 本月(账本自定义周期)支出 Top-N 分类的**占比**(分类支出 / 周期总支出)。
  ///
  /// 预算中号卡下半排的兜底数据:[gatherBudget] 的 `categoryBudgets` 只包含
  /// **设置过分类预算**的分类,大多数用户只设总预算 → 列表为空 → 下半排整个
  /// 消失(真机反馈"分类占比没渲染出来")。没有分类预算时改用这份"支出
  /// 占比"填充,人人有数据;设了分类预算仍优先显示预算用量(语义更强)。
  ///
  /// 周期口径与 [gatherGlance] 的「本月」一致(账本 monthStartDay);无支出
  /// 返回空列表(View 侧自然不渲染)。
  static Future<List<({String name, double share})>> gatherTopSpendingShares({
    required BaseRepository repository,
    required int ledgerId,
    int top = 3,
  }) async {
    final now = DateTime.now();
    final ledger = await repository.getLedgerById(ledgerId);
    final startDay = (ledger?.monthStartDay ?? 1).clamp(1, 28);
    final range = periodContaining(now, startDay);

    final items = await repository.totalsByCategory(
      ledgerId: ledgerId,
      type: 'expense',
      start: range.start,
      end: range.end,
    );
    final sum = _sumTotals(items);
    if (sum <= 0) return const [];

    final sorted = [...items]..sort((a, b) => b.total.compareTo(a.total));
    return [
      for (final item in sorted.take(top))
        (name: item.name, share: item.total / sum),
    ];
  }

  // ---------------------------------------------------------------------
  // 账本自身币种(单一账本视角的简单金额格式化用)
  // ---------------------------------------------------------------------

  /// 账本自身币种(`Ledger.currency`),供 budget/recent/dashboard 三个
  /// Phase B2b 新增 View 做简单金额格式化用——区别于 netWorth 系列跨账户/
  /// 跨币种折算用的 [gatherNetWorthBreakdown] 的 `baseCurrency` 参数(那是
  /// 用户可选的全局本位币,可能与当前账本自身币种不同)。预算/最近交易都是
  /// "单一账本视角"的数据(预算金额本就没有独立币种列,交易金额格式化取交易
  /// 自身 currencyCode,缺失时兜底到这里),因此用账本自身币种而非全局本位币。
  ///
  /// 取不到账本(理论不应发生)兜底 'CNY',与 [gatherGlance] 的
  /// `monthStartDay` 兜底同一套保守策略。
  static Future<String> gatherLedgerCurrency({
    required BaseRepository repository,
    required int ledgerId,
  }) async {
    final ledger = await repository.getLedgerById(ledgerId);
    return ledger?.currency ?? 'CNY';
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

/// 一次渲染批次(`WidgetManager.updateAllWidgets` 单次调用)内的取数缓存。
///
/// 同一类型多个尺寸的 spec、以及 dashboard 对 glance/趋势/最近交易/常用分类
/// 的复用,原本各自独立调用 `WidgetDataService.gather*`——预热(warm-up)
/// 批次里 12 个 spec 会把 **30 天净值趋势(逐日余额,重查询)重复算 4 遍**
/// (netWorth 小/中/大 + dashboard),是「添加小组件后隔很久才出来」的主要
/// 耗时来源。本类把每种数据在一个批次内压到只查一次:memoize 的是 Future
/// 本身——首个调用者触发查询,后续调用共享同一个 Future,天然并发安全。
///
/// 生命周期 = 一个批次:每次 `updateAllWidgets` 新建一个,批次结束即丢弃,
/// 不做跨批次缓存(数据新鲜度优先,批次间数据本来就可能已变化)。
class WidgetGatherBatch {
  final BaseRepository repository;
  final int ledgerId;
  final String baseCurrency;

  WidgetGatherBatch({
    required this.repository,
    required this.ledgerId,
    required this.baseCurrency,
  });

  Future<GlanceWidgetData>? _glance;
  Future<GlanceWidgetData> glance() => _glance ??=
      WidgetDataService.gatherGlance(repository: repository, ledgerId: ledgerId);

  Future<List<DailyWidgetActivity>>? _dailyActivity30;

  /// 近 30 个自然日的记账/消费活动，两个行为型小组件共用同一份聚合结果。
  Future<List<DailyWidgetActivity>> dailyActivity30() => _dailyActivity30 ??=
      WidgetDataService.gatherDailyActivity(
          repository: repository, ledgerId: ledgerId);

  Future<NetWorthBreakdownData>? _netWorthBreakdown;
  Future<NetWorthBreakdownData> netWorthBreakdown() =>
      _netWorthBreakdown ??= WidgetDataService.gatherNetWorthBreakdown(
          repository: repository, baseCurrency: baseCurrency);

  Future<List<({DateTime date, double assets, double liabilities, double net})>>?
      _trend30;

  /// 近 30 天(含今天)净值趋势,netWorth 三档与 dashboard 共用同一份。
  Future<List<({DateTime date, double assets, double liabilities, double net})>>
      netWorthTrend30() {
    if (_trend30 != null) return _trend30!;
    final end = trendTodayAnchor();
    final start = end.subtract(const Duration(days: 29));
    return _trend30 = WidgetDataService.gatherNetWorthTrend(
        repository: repository,
        baseCurrency: baseCurrency,
        start: start,
        end: end);
  }

  Future<List<NetWorthAccountItem>>? _topAccounts;

  /// 账户明细(净资产大号专用,limit 4);惰性——只有大号 spec 在批次内出现
  /// 时才触发这次查询。
  Future<List<NetWorthAccountItem>> netWorthTopAccounts() =>
      _topAccounts ??= WidgetDataService.gatherNetWorthTopAccounts(
          repository: repository, baseCurrency: baseCurrency, limit: 4);

  Future<List<QuickAddCategoryItem>>? _quickAdd;

  /// 常用支出分类,按批次内最大需求(medium 2×4 网格的 7 个)取一次;
  /// small(3)与 dashboard(3)由 View 自行截断/补位(QuickAddView /
  /// DashboardView 内部都有 take)。
  Future<List<QuickAddCategoryItem>> quickAddCategories() =>
      _quickAdd ??= WidgetDataService.gatherQuickAddCategories(
          repository: repository, ledgerId: ledgerId, limit: 7);

  Future<BudgetOverview>? _budget;
  Future<BudgetOverview> budget() => _budget ??=
      WidgetDataService.gatherBudget(repository: repository, ledgerId: ledgerId);

  Future<List<({String name, double share})>>? _topShares;

  /// 本月支出 Top3 分类占比(预算中号卡无分类预算时的兜底,惰性)。
  Future<List<({String name, double share})>> topSpendingShares() =>
      _topShares ??= WidgetDataService.gatherTopSpendingShares(
          repository: repository, ledgerId: ledgerId);

  Future<String>? _ledgerCurrency;
  Future<String> ledgerCurrency() => _ledgerCurrency ??=
      WidgetDataService.gatherLedgerCurrency(
          repository: repository, ledgerId: ledgerId);

  Future<List<RecentTransactionItem>>? _recent;

  /// 最近交易,按批次内最大需求(large 的 6 笔)取一次;medium(3)与
  /// dashboard(2)由 View 内部 take 截断。
  Future<List<RecentTransactionItem>> recent() => _recent ??=
      WidgetDataService.gatherRecent(
          repository: repository, ledgerId: ledgerId, limit: 6);

  /// dashboard 组合数据:全部由本批次已 memo 的各份数据拼装,不再走
  /// [WidgetDataService.gatherDashboard](那会绕过缓存重复取数,尤其重复算
  /// 30 天趋势)。
  Future<DashboardWidgetData> dashboard() async => DashboardWidgetData(
        glance: await glance(),
        netWorthTrend: await netWorthTrend30(),
        recent: await recent(),
        quickAdd: await quickAddCategories(),
      );
}
