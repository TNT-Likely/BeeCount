import 'dart:async';
import 'package:beecount/data/repositories/budget_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/main/home/widgets/home_budget_indicator.dart';
import 'package:beecount/providers/budget_providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(WidgetTester tester, Widget body,
      {double width = 398,
      double scale = 1,
      bool dark = false,
      ProviderContainer? container}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = MaterialApp(
        theme: beeTheme(brightness: dark ? Brightness.dark : Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(
            body: Padding(padding: const EdgeInsets.all(17), child: body)));
    await tester.pumpWidget(container == null
        ? app
        : UncontrolledProviderScope(container: container, child: app));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 398.0]) {
    for (final scale in [1.0, 1.4]) {
      for (final dark in [false, true]) {
        testWidgets('紧凑同屏保留上下层级、右对齐与原有留白 $width $scale $dark', (tester) async {
          var budgets = 0;
          await open(
              tester,
              Column(children: [
                BeeSummaryCard(
                    compact: true,
                    title: '2026年 10月',
                    amountLabel: '本月支出',
                    amount: '74,901,256,000.00',
                    prefix: '¥',
                    currencyLabel: 'CNY',
                    incomeLabel: '本月收入',
                    income: '12,000,000,000.00',
                    expenseLabel: '本月结余',
                    expense: '−74,889,256,000.00',
                    onContextTap: () {},
                    onPrivacyTap: () {},
                    privacyLabel: '隐藏金额',
                    budgetIndicator: BeeHomeBudgetIndicator(
                        diameter: width < 350 ? 72 : 86,
                        value: '34%',
                        label: '预算可用',
                        progress: .34,
                        semanticLabel: '查看预算',
                        onTap: () => budgets++))
              ]),
              width: width,
              scale: scale,
              dark: dark);
          final card = find.byType(BeeSummaryCard);
          expect(find.descendant(of: card, matching: find.byType(Divider)),
              findsNothing);
          expect(tester.getTopLeft(find.text('12,000,000,000.00')).dy,
              greaterThan(tester.getBottomLeft(find.text('本月收入')).dy));
          expect(tester.getTopLeft(find.text('−74,889,256,000.00')).dy,
              greaterThan(tester.getBottomLeft(find.text('本月结余')).dy));
          final labelRight = tester.getTopRight(find.text('本月结余')).dx;
          expect(tester.getTopRight(find.text('−74,889,256,000.00')).dx,
              closeTo(labelRight, 1));
          expect(tester.getSize(find.byType(BeeHomeBudgetIndicator)).width,
              width < 350 ? 72 : 86);
          await tester.tap(find.bySemanticsLabel('查看预算'));
          expect(budgets, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  for (final item in [
    (used: 3286.5, budget: 5000.0, value: '34%'),
    (used: 5000.0, budget: 5000.0, value: '0%'),
    (used: 5328.5, budget: 5000.0, value: '超支'),
  ]) {
    testWidgets('预算环来自真实预算使用率 ${item.value}', (tester) async {
      final container = ProviderContainer(overrides: [
        budgetOverviewProvider.overrideWith((_) async => BudgetOverview(
            totalBudget: BudgetUsage(used: item.used, budget: item.budget),
            daysRemaining: 1,
            dailyAvailable: 0))
      ]);
      addTearDown(container.dispose);
      await open(tester, const HomeBudgetIndicator(diameter: 86),
          container: container);
      final ring = tester
          .widget<BeeHomeBudgetIndicator>(find.byType(BeeHomeBudgetIndicator));
      expect(ring.value, item.value);
      expect(ring.exceeded, item.used > item.budget);
      expect(
          tester
              .widget<CircularProgressIndicator>(
                  find.byType(CircularProgressIndicator))
              .value,
          isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('未设置、加载和失败保留明确入口，不新增首屏转圈', (tester) async {
    final wait = Completer<BudgetOverview?>();
    var calls = 0;
    final container = ProviderContainer(overrides: [
      budgetOverviewProvider.overrideWith((_) {
        calls++;
        return calls == 1 ? wait.future : Future<BudgetOverview?>.value(null);
      })
    ]);
    addTearDown(container.dispose);
    await open(tester, const HomeBudgetIndicator(diameter: 86),
        container: container);
    expect(
        tester
            .widget<BeeHomeBudgetIndicator>(find.byType(BeeHomeBudgetIndicator))
            .value,
        '—');
    expect(
        tester
            .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator))
            .value,
        0);
    wait.completeError(StateError('synthetic budget error'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<BeeHomeBudgetIndicator>(find.byType(BeeHomeBudgetIndicator))
            .value,
        '!');
    await tester.tap(find.byType(BeeHomeBudgetIndicator));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(
        tester
            .widget<BeeHomeBudgetIndicator>(find.byType(BeeHomeBudgetIndicator))
            .value,
        '+');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
