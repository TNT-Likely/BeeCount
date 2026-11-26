import 'package:flutter/material.dart';

import '../data/db.dart' show Account, Category, Transaction;
import '../data/repositories/budget_repository.dart';
import '../l10n/app_localizations.dart';
import 'widget_card_builder.dart';
import 'widget_data_service.dart';
import 'widget_spec.dart';

/// Fixed sample ledger for the in-app gallery and the platform widget pickers.
Widget buildWidgetPreview({
  required WidgetSpec spec,
  required Size canvas,
  required AppLocalizations l,
  required bool dark,
  required Color themeColor,
  required bool redForIncome,
}) {
  final date = DateTime(2026, 7, 20);
  final card = WidgetCardBuilder(
      spec: spec,
      canvas: canvas,
      l: l,
      dark: dark,
      color: themeColor,
      redForIncome: redForIncome,
      today: date);
  final currency = l.localeName.startsWith('zh') ? 'CNY' : 'USD';
  const glance = GlanceWidgetData(
      todayExpenseTotal: 128.5,
      todayIncomeTotal: 0,
      monthExpenseTotal: 6842.3,
      monthIncomeTotal: 18500);
  final categories = [
    for (final (index, (name, icon)) in const [
      ('dining', 'restaurant'),
      ('transport', 'directions_car'),
      ('shopping', 'shopping_cart'),
      ('entertainment', 'movie'),
      ('medical', 'local_hospital'),
      ('home', 'home'),
      ('communication', 'phone'),
    ].indexed)
      QuickAddCategoryItem(
          categoryId: index + 1,
          name: name,
          icon: icon,
          total: 100 - index.toDouble()),
  ];
  final bank = Account(
      id: 1,
      ledgerId: 1,
      name: l.accountTypeBankCard,
      type: 'bank_card',
      currency: currency,
      initialBalance: 0,
      sortOrder: 1,
      hidden: false);
  final cash = Account(
      id: 2,
      ledgerId: 1,
      name: l.accountTypeCash,
      type: 'cash',
      currency: currency,
      initialBalance: 0,
      sortOrder: 2,
      hidden: false);
  const points = [
    82000,
    82300,
    82100,
    83000,
    83400,
    83200,
    84100,
    84600,
    84400,
    85200,
    85600,
    85400,
    86100,
    86420
  ];
  final trend = [
    for (final (index, net) in points.indexed)
      (
        date: date.subtract(Duration(days: (points.length - index - 1) * 2)),
        assets: net + 5680.0,
        liabilities: -5680.0,
        net: net.toDouble()
      ),
  ];
  List<RecentTransactionItem> transactions() {
    const entries = [
      ('expense', 32.0, 'dining', 'restaurant', 0),
      ('income', 18500.0, 'salary', 'work', 1),
      ('expense', 156.8, 'shopping', 'shopping_cart', 1),
      ('expense', 24.0, 'transport', 'directions_car', 2),
      ('expense', 18.0, 'dining', 'restaurant', 2),
      ('expense', 68.0, 'shopping', 'shopping_cart', 3),
    ];
    return [
      for (final (index, (type, amount, name, icon, age)) in entries.indexed)
        RecentTransactionItem(
            transaction: Transaction(
                id: index + 1,
                ledgerId: 1,
                type: type,
                amount: amount,
                happenedAt: DateTime(2026, 7, date.day - age, 9, 12),
                excludeFromStats: false,
                excludeFromBudget: false),
            category: Category(
                id: index + 1,
                name: name,
                kind: type,
                icon: icon,
                sortOrder: index,
                level: 1,
                iconType: 'material'),
            account: index.isEven ? cash : bank),
    ];
  }

  List<DailyWidgetActivity> activity() => [
        for (var i = 0; i < 30; i++)
          DailyWidgetActivity(
              date: date.subtract(Duration(days: 29 - i)),
              expenseTotal: const [0.0, 28.0, 96.0, 42.0, 180.0, 68.0][i % 6],
              hasRecord: i >= 25 || i % 4 != 0),
      ];

  switch (spec.type) {
    case HWType.glance:
      return card.glance(glance, currency);
    case HWType.netWorth:
      return card.netWorth(
          const NetWorthBreakdownData(
              netWorth: 86420,
              totalAssets: 92100,
              totalLiabilities: -5680,
              hasAccounts: true),
          currency,
          trend,
          [
            NetWorthAccountItem(
                account: bank, balance: 48200, convertedBalance: 48200),
            NetWorthAccountItem(
                account: cash, balance: 12650, convertedBalance: 12650),
          ]);
    case HWType.quickAdd:
      return card.quickAdd(categories);
    case HWType.budget:
      return card.budget(
          BudgetOverview(
              totalBudget: BudgetUsage(used: 6842, budget: 8000),
              categoryBudgets: [
                for (final (i, (used, total)) in const [
                  (1620.0, 1800.0),
                  (480.0, 1000.0),
                  (2350.0, 3000.0)
                ].indexed)
                  CategoryBudgetUsage(
                      budgetId: i + 1,
                      categoryId: categories[i].categoryId,
                      categoryName: categories[i].name,
                      usage: BudgetUsage(used: used, budget: total)),
              ],
              daysRemaining: 11,
              dailyAvailable: 105.3),
          currency,
          const []);
    case HWType.recent:
      return card.recent(transactions(), currency);
    case HWType.dashboard:
      return card.dashboard(
          DashboardWidgetData(
              glance: glance,
              netWorthTrend: trend,
              recent: transactions(),
              quickAdd: const []),
          currency);
    case HWType.consumptionRhythm:
      return card.rhythm(activity());
    case HWType.beeTrail:
      return card.trail(activity());
  }
}
