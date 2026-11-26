import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repositories/budget_repository.dart';
import '../l10n/app_localizations.dart';
import '../services/data/seed_service.dart';
import '../utils/currencies.dart';
import '../utils/format_money.dart';
import 'views/bee_trail_view.dart';
import 'views/budget_view.dart';
import 'views/consumption_rhythm_view.dart';
import 'views/dashboard_view.dart';
import 'views/glance_view.dart';
import 'views/net_worth_view.dart';
import 'views/quick_add_view.dart';
import 'views/recent_view.dart';
import 'widget_data_service.dart';
import 'widget_spec.dart';

/// One presentation path for live ledger snapshots, the in-app gallery and
/// both platforms' bundled picker images. Only the supplied data differs.
class WidgetCardBuilder {
  const WidgetCardBuilder({
    required this.spec,
    required this.canvas,
    required this.l,
    required this.dark,
    required this.color,
    required this.redForIncome,
    required this.today,
  });
  final WidgetSpec spec;
  final Size canvas;
  final AppLocalizations l;
  final bool dark, redForIncome;
  final Color color;
  final DateTime today;

  String get month => DateFormat.MMM(l.localeName).format(today);
  String category(String name, {String kind = 'expense'}) =>
      SeedService.localizedCategoryName(name, kind, l);

  Widget glance(GlanceWidgetData data, String currency) {
    String money(double value) =>
        '${getCurrencySymbol(currency)}${formatMoneyCompact(value)}';
    if (spec.size == HWSize.small) {
      return GlanceView.small(
        todayExpense: money(data.todayExpenseTotal),
        monthExpense: money(data.monthExpenseTotal),
        monthIncome: money(data.monthIncomeTotal),
        themeColor: color,
        dark: dark,
        redForIncome: redForIncome,
        todayLabel: l.widgetToday,
        titleLabel: l.widgetGalleryGlanceTitle,
        todayExpenseLabel: l.widgetTodayExpense,
        monthExpenseLabel: l.widgetMonthExpense,
        monthIncomeLabel: l.widgetMonthIncome,
        width: canvas.width,
        height: canvas.height,
      );
    }
    return GlanceView.medium(
      todayExpense: money(data.todayExpenseTotal),
      todayIncome: money(data.todayIncomeTotal),
      monthExpense: money(data.monthExpenseTotal),
      monthIncome: money(data.monthIncomeTotal),
      themeColor: color,
      dark: dark,
      redForIncome: redForIncome,
      titleLabel: l.widgetGalleryGlanceTitle,
      monthSuffix: l.widgetMonthSuffix,
      periodLabel: month,
      currencyCode: currency,
      todayLabel: l.widgetToday,
      todayExpenseLabel: l.widgetTodayExpense,
      todayIncomeLabel: l.widgetTodayIncome,
      monthExpenseLabel: l.widgetMonthExpense,
      monthIncomeLabel: l.widgetMonthIncome,
      width: canvas.width,
      height: canvas.height,
    );
  }

  Widget netWorth(
    NetWorthBreakdownData data,
    String currency,
    List<({DateTime date, double assets, double liabilities, double net})>
        trend,
    List<NetWorthAccountItem> accounts,
  ) =>
      NetWorthView(
        size: spec.size,
        netWorth: data.netWorth,
        totalAssets: data.totalAssets,
        totalLiabilities: data.totalLiabilities,
        baseCurrency: currency,
        trend: trend,
        topAccounts: accounts,
        hasAccounts: data.hasAccounts,
        themeColor: color,
        dark: dark,
        redForIncome: redForIncome,
        netWorthLabel: l.accountTotalBalance,
        totalAssetsLabel: l.totalAssets,
        totalLiabilitiesLabel: l.totalLiabilities,
        noAccountsLabel: l.widgetNoAccounts,
        rangeLabel: l.widgetConsumptionRhythmRange,
        accountsLabel: l.widgetAccountBalances,
        width: canvas.width,
        height: canvas.height,
      );

  Widget quickAdd(List<QuickAddCategoryItem> categories) => QuickAddView(
        size: spec.size,
        categories: [
          for (final c in categories)
            QuickAddCategoryItem(
                categoryId: c.categoryId,
                name: category(c.name),
                icon: c.icon,
                total: c.total),
        ],
        themeColor: color,
        dark: dark,
        addLabel: l.widgetAddExpense,
        titleLabel: l.widgetGalleryQuickAddTitle,
        frequentLabel: l.widgetFrequentCategories,
        emptyLabel: l.widgetNoFrequentCategories,
        width: canvas.width,
        height: canvas.height,
      );

  Widget budget(BudgetOverview overview, String currency,
          List<({String name, double share})> shares) =>
      BudgetView(
        size: spec.size,
        overview: BudgetOverview(
          totalBudget: overview.totalBudget,
          daysRemaining: overview.daysRemaining,
          dailyAvailable: overview.dailyAvailable,
          categoryBudgets: [
            for (final c in overview.categoryBudgets)
              CategoryBudgetUsage(
                  budgetId: c.budgetId,
                  categoryId: c.categoryId,
                  categoryName: category(c.categoryName),
                  categoryIcon: c.categoryIcon,
                  category: c.category,
                  usage: c.usage),
          ],
        ),
        fallbackShares: [
          for (final s in shares) (name: category(s.name), share: s.share)
        ],
        currencyCode: currency,
        themeColor: color,
        redForIncome: redForIncome,
        dark: dark,
        budgetLabel: l.budgetMonthlyBudget,
        monthLabel: spec.size == HWSize.medium ? month : null,
        usedLabel: l.budgetUsed,
        totalLabel: l.widgetBudgetTotal,
        remainingLabel: l.budgetRemaining,
        noBudgetLabel: l.widgetNoBudget,
        categoryUsageLabel: l.budgetCategoryBudgets,
        spendingShareLabel: l.widgetSpendingShare,
        width: canvas.width,
        height: canvas.height,
      );

  List<RecentTransactionItem> _localizedRows(
          List<RecentTransactionItem> rows) =>
      [
        for (final row in rows)
          RecentTransactionItem(
            transaction: row.transaction,
            account: row.account,
            toAccount: row.toAccount,
            category: row.category?.copyWith(
                name: category(row.category!.name, kind: row.category!.kind)),
          )
      ];

  Widget recent(List<RecentTransactionItem> rows, String currency) =>
      RecentView(
        size: spec.size,
        items: _localizedRows(rows),
        defaultCurrency: currency,
        themeColor: color,
        redForIncome: redForIncome,
        dark: dark,
        referenceDate: today,
        uncategorizedLabel: l.commonUncategorized,
        emptyLabel: l.widgetNoTransactions,
        titleLabel: l.widgetRecentTransactions,
        width: canvas.width,
        height: canvas.height,
      );

  Widget dashboard(DashboardWidgetData data, String currency) => DashboardView(
        data: DashboardWidgetData(
            glance: data.glance,
            netWorthTrend: data.netWorthTrend,
            recent: _localizedRows(data.recent),
            quickAdd: const []),
        defaultCurrency: currency,
        themeColor: color,
        redForIncome: redForIncome,
        dark: dark,
        referenceDate: today,
        periodLabel: month,
        trendLabel: l.netWorthTrendTitle,
        trendRangeLabel: l.widgetConsumptionRhythmRange,
        monthExpenseLabel: l.widgetMonthExpense,
        monthIncomeLabel: l.widgetMonthIncome,
        recentLabel: l.widgetRecentTransactions,
        uncategorizedLabel: l.commonUncategorized,
        noTransactionsLabel: l.widgetNoTransactions,
        quickAddLabel: l.widgetAddExpense,
        titleLabel: l.widgetDashboardTitle,
        width: canvas.width,
        height: canvas.height,
      );

  Widget rhythm(List<DailyWidgetActivity> days) => ConsumptionRhythmView(
        activity: days,
        themeColor: color,
        dark: dark,
        titleLabel: l.widgetConsumptionRhythmTitle,
        rangeLabel: l.widgetConsumptionRhythmRange,
        stableLabel: l.widgetConsumptionRhythmStable,
        increaseLabel: l.widgetConsumptionRhythmIncrease,
        decreaseLabel: l.widgetConsumptionRhythmDecrease,
        emptyLabel: l.widgetConsumptionRhythmEmpty,
        width: canvas.width,
        height: canvas.height,
      );

  Widget trail(List<DailyWidgetActivity> days) => BeeTrailView(
        activity: days,
        themeColor: color,
        dark: dark,
        titleLabel: l.widgetBeeTrailTitle,
        streakSuffix: l.widgetBeeTrailStreakSuffix,
        completionLabel: l.widgetBeeTrailCompletion,
        emptyLabel: l.widgetBeeTrailEmpty,
        width: canvas.width,
        height: canvas.height,
      );
}
