import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(WidgetTester tester, Widget child,
      {required double width, required double scale}) async {
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(
                size: Size(width, 900), textScaler: TextScaler.linear(scale)),
            child: Scaffold(
                body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(width: width, child: child))))));
    await tester.pump();
  }

  testWidgets('day totals reach the trailing edge for one or both flow totals',
      (tester) async {
    for (final width in [320.0, 398.0]) {
      for (final scale in [1.0, 1.4]) {
        for (final totals in [
          ['支出 32.00'],
          ['收入 125.00', '支出 32.00']
        ]) {
          await show(
              tester,
              BeeTransactionDayHeader(
                  title: '星期一', date: '2026-10-26', totals: totals),
              width: width,
              scale: scale);
          expect(
              tester.getRect(find.text(totals.last)).right, closeTo(width, .1),
              reason: '$width / $scale / $totals');
          expect(tester.takeException(), isNull);
        }
      }
    }
  });

  testWidgets('summary trailing title and value align with and without budget',
      (tester) async {
    for (final width in [320.0, 398.0]) {
      for (final scale in [1.0, 1.4]) {
        for (final withBudget in [false, true]) {
          await show(
              tester,
              BeeSummaryCard(
                  title: '2026年 10月',
                  amountLabel: '本月支出',
                  amount: '3,286.50',
                  incomeLabel: '本月收入',
                  income: '12,000.00',
                  expenseLabel: '本月剩余',
                  expense: '8,713.50',
                  budget: withBudget
                      ? BeeBudgetStrip(
                          label: '月预算 ¥5,000.00',
                          remaining: '剩余 ¥1,713.50',
                          progress: .66,
                          onTap: () {})
                      : null),
              width: width,
              scale: scale);
          final label = tester.getRect(find.text('本月剩余'));
          final amount = tester.getRect(find.text('8,713.50'));
          expect(label.right, closeTo(amount.right, .1));
          expect(label.right, closeTo(width - 18, .1),
              reason: '$width / $scale / budget=$withBudget');
          expect(tester.getRect(find.text('本月收入')).left, closeTo(18, .1));
          if (withBudget) {
            expect(tester.getRect(find.text('剩余 ¥1,713.50')).right,
                closeTo(width - 18 - 17, .1));
          }
          expect(tester.takeException(), isNull);
        }
      }
    }
  });
}
