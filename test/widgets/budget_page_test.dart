import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/budget_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/budget/budget_page.dart';
import 'package:beecount/providers/budget_providers.dart';
import 'package:beecount/providers/database_providers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Ledger ledger() => Ledger(
        id: 1,
        name: '测试账本',
        currency: 'CNY',
        type: 'personal',
        createdAt: DateTime(2026, 1, 1),
        syncId: 'ledger-1',
        myRole: 'owner',
        memberCount: 2,
        isShared: true,
        monthStartDay: 1,
      );

  testWidgets('只有分类预算、没有总预算时仍显示分类预算列表', (tester) async {
    final overview = BudgetOverview(
      totalBudget: null,
      categoryBudgets: [
        CategoryBudgetUsage(
          budgetId: 1,
          categoryId: 10,
          categoryName: '住房',
          categoryIcon: 'home',
          usage: BudgetUsage(used: 100, budget: 1000),
        ),
      ],
      daysRemaining: 10,
      dailyAvailable: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentLedgerProvider.overrideWith(
            (ref) => Stream<Ledger?>.value(ledger()),
          ),
          budgetOverviewProvider.overrideWith((ref) async => overview),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const BudgetPage(),
        ),
      ),
    );
    // PrimaryHeader 下包含可持续运行的主题动效；固定推进测试时钟，避免
    // pumpAndSettle 等待无穷动画直到超时。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('分类预算'), findsOneWidget);
    expect(find.text('住房'), findsOneWidget);
    expect(find.text('还没有设置预算'), findsNothing);
  });
}
