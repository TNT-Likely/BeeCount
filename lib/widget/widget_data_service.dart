import '../data/repositories/base_repository.dart';
import '../utils/month_range.dart';

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

/// 桌面小组件数据服务:按内容类型(`HWType`)从 repo 取数、聚合成渲染所需
/// 的数值,供 `WidgetManager` 渲染各类型 View。
///
/// **本阶段(P1)只实现 [gatherGlance]**——从旧
/// `WidgetManager.updateWidget()` 迁移而来的今日/本月收支逻辑,行为不变。
/// netWorth/quickAdd/budget/recent/dashboard 的取数留给 Phase B(P2),届时
/// 按 `.docs/home-widget/plan.md` §一.3 逐个补齐(含新增 repo 方法如
/// `getRecentTransactions`)。**本阶段不在此新增那些方法。**
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

  static double _sumTotals(
    List<({int? id, String name, String? icon, double total})> items,
  ) {
    return items.fold<double>(0.0, (sum, item) => sum + item.total);
  }
}
