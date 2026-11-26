import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'widget_card_builder.dart';
import 'widget_data_service.dart';
import 'widget_spec.dart';

// Bump when the drawing changes without a corresponding ledger or build change.
const _widgetLayoutRevision = 'cards-4.0';
const _budgetLayoutRevision = 2;

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
      row.category?.kind,
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
  WidgetRenderContent content(
      List<Object?> data, Widget Function(WidgetCardBuilder) build) {
    final fingerprint = sha256.convert(utf8.encode(jsonEncode([
      _widgetLayoutRevision,
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
    return WidgetRenderContent(
        fingerprint.toString(),
        (l, dark) => build(WidgetCardBuilder(
            spec: spec,
            canvas: size,
            l: l,
            today: today,
            dark: dark,
            redForIncome: redForIncome,
            color: dark ? darkColor : lightColor)));
  }

  switch (spec.type) {
    case HWType.glance:
      final data = await batch.glance();
      final currency = await batch.ledgerCurrency();
      return content([
        currency,
        if (spec.size == HWSize.medium) today.month,
        ..._glanceValues(data)
      ], (card) => card.glance(data, currency));
    case HWType.netWorth:
      final data = await batch.netWorthBreakdown();
      final trend = await batch.netWorthTrend30();
      final accounts = spec.size == HWSize.large
          ? await batch.netWorthTopAccounts()
          : const <NetWorthAccountItem>[];
      return content([
        batch.baseCurrency,
        data.netWorth,
        data.totalAssets,
        data.totalLiabilities,
        data.hasAccounts,
        for (final p in trend) p.net,
        for (final a in accounts)
          [
            a.account.name,
            a.account.type,
            a.account.currency,
            a.balance,
            a.convertedBalance
          ],
      ], (card) => card.netWorth(data, batch.baseCurrency, trend, accounts));
    case HWType.quickAdd:
      final categories = await batch.quickAddCategories();
      return content([for (final c in categories) _quickAddValues(c)],
          (card) => card.quickAdd(categories));
    case HWType.budget:
      final overview = await batch.budget();
      final currency = await batch.ledgerCurrency();
      final shares =
          spec.size == HWSize.medium && overview.categoryBudgets.isEmpty
              ? await batch.topSpendingShares()
              : const <({String name, double share})>[];
      return content([
        _budgetLayoutRevision,
        currency,
        if (spec.size == HWSize.medium) today.month,
        overview.totalBudget?.budget,
        overview.totalBudget?.used,
        for (final c in overview.categoryBudgets)
          [c.categoryName, c.usage.budget, c.usage.used],
        for (final c in shares) [c.name, c.share],
      ], (card) => card.budget(overview, currency, shares));
    case HWType.recent:
      final rows = (await batch.recent())
          .take(spec.size == HWSize.large ? 6 : 3)
          .toList();
      final currency = await batch.ledgerCurrency();
      return content([currency, for (final r in rows) _recentValues(r, today)],
          (card) => card.recent(rows, currency));
    case HWType.dashboard:
      final data = await batch.dashboard();
      final currency = await batch.ledgerCurrency();
      return content([
        currency,
        today.month,
        data.glance.monthExpenseTotal,
        data.glance.monthIncomeTotal,
        for (final p in data.netWorthTrend) p.net,
        for (final r in data.recent.take(2)) _recentValues(r, today),
      ], (card) => card.dashboard(data, currency));
    case HWType.consumptionRhythm:
      final days = await batch.dailyActivity30();
      return content(
          [for (final d in days) d.expenseTotal], (card) => card.rhythm(days));
    case HWType.beeTrail:
      final days = await batch.dailyActivity30();
      return content(
          [for (final d in days) d.hasRecord], (card) => card.trail(days));
  }
}
