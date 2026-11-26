import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/currencies.dart' show getCurrencySymbol;
import '../utils/format_money.dart' show formatMoneyCompact;
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

/// The data and drawing inputs for one size, shared across its appearances.
/// Only their hash is persisted alongside the PNG paths.
class WidgetRenderContent {
  final String fingerprint;
  final Widget Function(AppLocalizations strings, bool dark) build;

  const WidgetRenderContent(this.fingerprint, this.build);
}

List<double> _glanceValues(GlanceWidgetData data) => [
      data.todayExpenseTotal,
      data.todayIncomeTotal,
      data.monthExpenseTotal,
      data.monthIncomeTotal,
    ];

List<Object?> _recentValues(RecentTransactionItem row, DateTime today) => [
      row.transaction.type,
      row.transaction.amount,
      row.transaction.currencyCode,
      row.transaction.happenedAt.toIso8601String(),
      DateUtils.isSameDay(row.transaction.happenedAt, today),
      row.category?.name,
      row.category?.icon,
      row.account?.name,
      row.toAccount?.name,
    ];

List<Object?> _quickAddValues(QuickAddCategoryItem item) =>
    [item.categoryId, item.name, item.icon];

Future<WidgetRenderContent> prepareWidgetContent({
  required WidgetSpec spec,
  required WidgetGatherBatch batch,
  required Size size,
  required Color lightColor,
  required Color darkColor,
  required bool redForIncome,
  required String appVersion,
  required DateTime today,
}) async {
  WidgetRenderContent content(List<Object?> data,
      Widget Function(AppLocalizations, bool, Color) build) {
    final fingerprint = sha256.convert(utf8.encode(jsonEncode([
      appVersion,
      spec.imageKey,
      batch.ledgerId,
      size.width,
      size.height,
      [lightColor.a, lightColor.r, lightColor.g, lightColor.b],
      [darkColor.a, darkColor.r, darkColor.g, darkColor.b],
      redForIncome,
      data,
    ])));
    return WidgetRenderContent(fingerprint.toString(),
        (l, dark) => build(l, dark, dark ? darkColor : lightColor));
  }

  final width = size.width, height = size.height;
  switch (spec.type) {
    case HWType.glance:
      final data = await batch.glance();
      final currency = await batch.ledgerCurrency();
      String money(double value) =>
          '${getCurrencySymbol(currency)}${formatMoneyCompact(value)}';
      return content([
        currency,
        if (spec.size == HWSize.medium) today.month,
        ..._glanceValues(data)
      ], (l, dark, color) {
        if (spec.size == HWSize.small) {
          return GlanceView.small(
            todayExpense: money(data.todayExpenseTotal),
            monthExpense: money(data.monthExpenseTotal),
            monthIncome: money(data.monthIncomeTotal),
            themeColor: color,
            redForIncome: redForIncome,
            dark: dark,
            todayLabel: l.widgetToday,
            todayExpenseLabel: l.widgetTodayExpense,
            monthExpenseLabel: l.widgetMonthExpense,
            monthIncomeLabel: l.widgetMonthIncome,
            width: width,
            height: height,
          );
        }
        return GlanceView.medium(
          todayExpense: money(data.todayExpenseTotal),
          todayIncome: money(data.todayIncomeTotal),
          monthExpense: money(data.monthExpenseTotal),
          monthIncome: money(data.monthIncomeTotal),
          themeColor: color,
          redForIncome: redForIncome,
          dark: dark,
          titleLabel: l.widgetGalleryGlanceTitle,
          monthSuffix: l.widgetMonthSuffix,
          todayLabel: l.widgetToday,
          todayExpenseLabel: l.widgetTodayExpense,
          todayIncomeLabel: l.widgetTodayIncome,
          monthExpenseLabel: l.widgetMonthExpense,
          monthIncomeLabel: l.widgetMonthIncome,
          width: width,
          height: height,
        );
      });
    case HWType.netWorth:
      final data = await batch.netWorthBreakdown();
      final trend = await batch.netWorthTrend30();
      final accounts = spec.size == HWSize.large
          ? await batch.netWorthTopAccounts()
          : const <NetWorthAccountItem>[];
      return content(
          [
            batch.baseCurrency,
            data.netWorth,
            data.totalAssets,
            data.totalLiabilities,
            for (final p in trend) [p.assets, p.liabilities, p.net],
            for (final item in accounts)
              [
                item.account.name,
                item.account.currency,
                item.balance,
                item.convertedBalance
              ],
          ],
          (l, dark, color) => NetWorthView(
                size: spec.size,
                netWorth: data.netWorth,
                totalAssets: data.totalAssets,
                totalLiabilities: data.totalLiabilities,
                baseCurrency: batch.baseCurrency,
                trend: trend,
                topAccounts: accounts,
                themeColor: color,
                redForIncome: redForIncome,
                dark: dark,
                netWorthLabel: l.accountTotalBalance,
                totalAssetsLabel: l.totalAssets,
                totalLiabilitiesLabel: l.totalLiabilities,
                noAccountsLabel: l.widgetNoAccounts,
                width: width,
                height: height,
              ));
    case HWType.quickAdd:
      final categories = await batch.quickAddCategories();
      return content(
          [for (final c in categories) _quickAddValues(c)],
          (l, dark, color) => QuickAddView(
                size: spec.size,
                categories: categories,
                themeColor: color,
                dark: dark,
                addLabel: l.widgetQuickAddLabel,
                titleLabel: l.widgetGalleryQuickAddTitle,
                width: width,
                height: height,
              ));
    case HWType.budget:
      final overview = await batch.budget();
      final currency = await batch.ledgerCurrency();
      final shares = overview.categoryBudgets.isEmpty
          ? await batch.topSpendingShares()
          : const <({String name, double share})>[];
      return content(
          [
            currency,
            overview.totalBudget?.budget,
            overview.totalBudget?.used,
            for (final c in overview.categoryBudgets)
              [c.categoryName, c.usage.budget, c.usage.used],
            for (final c in shares) [c.name, c.share],
          ],
          (l, dark, color) => BudgetView(
                size: spec.size,
                overview: overview,
                currencyCode: currency,
                themeColor: color,
                redForIncome: redForIncome,
                dark: dark,
                budgetLabel: l.budgetMonthlyBudget,
                usedLabel: l.budgetUsed,
                totalLabel: l.widgetBudgetTotal,
                remainingLabel: l.widgetBudgetRemaining,
                noBudgetLabel: l.widgetNoBudget,
                fallbackShares: shares,
                width: width,
                height: height,
              ));
    case HWType.recent:
      final rows = await batch.recent();
      final currency = await batch.ledgerCurrency();
      return content(
          [currency, for (final r in rows) _recentValues(r, today)],
          (l, dark, color) => RecentView(
                size: spec.size,
                items: rows,
                defaultCurrency: currency,
                themeColor: color,
                redForIncome: redForIncome,
                dark: dark,
                uncategorizedLabel: l.commonUncategorized,
                emptyLabel: l.widgetNoTransactions,
                titleLabel: l.widgetRecentTransactions,
                width: width,
                height: height,
              ));
    case HWType.dashboard:
      final data = await batch.dashboard();
      final currency = await batch.ledgerCurrency();
      return content(
          [
            currency,
            ..._glanceValues(data.glance),
            for (final p in data.netWorthTrend) p.net,
            for (final r in data.recent) _recentValues(r, today),
            for (final c in data.quickAdd) _quickAddValues(c),
          ],
          (l, dark, color) => DashboardView(
                data: data,
                defaultCurrency: currency,
                themeColor: color,
                redForIncome: redForIncome,
                dark: dark,
                monthExpenseLabel: l.widgetMonthExpense,
                monthIncomeLabel: l.widgetMonthIncome,
                recentLabel: l.widgetRecentTransactions,
                uncategorizedLabel: l.commonUncategorized,
                noTransactionsLabel: l.widgetNoTransactions,
                quickAddLabel: l.widgetQuickAddLabel,
                titleLabel: l.widgetDashboardTitle,
                width: width,
                height: height,
              ));
    case HWType.consumptionRhythm:
      final activity = await batch.dailyActivity30();
      return content(
          [for (final d in activity) d.expenseTotal],
          (l, dark, color) => ConsumptionRhythmView(
                activity: activity,
                themeColor: color,
                dark: dark,
                titleLabel: l.widgetConsumptionRhythmTitle,
                rangeLabel: l.widgetConsumptionRhythmRange,
                stableLabel: l.widgetConsumptionRhythmStable,
                increaseLabel: l.widgetConsumptionRhythmIncrease,
                decreaseLabel: l.widgetConsumptionRhythmDecrease,
                emptyLabel: l.widgetConsumptionRhythmEmpty,
                width: width,
                height: height,
              ));
    case HWType.beeTrail:
      final activity = await batch.dailyActivity30();
      return content(
          [for (final d in activity) d.hasRecord],
          (l, dark, color) => BeeTrailView(
                activity: activity,
                themeColor: color,
                dark: dark,
                titleLabel: l.widgetBeeTrailTitle,
                streakSuffix: l.widgetBeeTrailStreakSuffix,
                completionLabel: l.widgetBeeTrailCompletion,
                emptyLabel: l.widgetBeeTrailEmpty,
                width: width,
                height: height,
              ));
  }
}
