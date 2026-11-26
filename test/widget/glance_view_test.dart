import 'package:beecount/widget/views/glance_view.dart';
import 'package:beecount/widget/views/widget_view_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const largeExpense = 'HK\$9,999,999.99';

Widget card(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    );

Finder money(String value) =>
    find.byWidgetPredicate((w) => w is WidgetCardMoney && w.amount == value);

void main() {
  testWidgets('小号底栏完整显示英文月份标签', (tester) async {
    const labels = ["Month's Expense", "Month's Income"];
    await tester.pumpWidget(card(GlanceView.small(
      todayExpense: '¥24.85',
      monthExpense: '¥100.25',
      monthIncome: '¥50.00',
      themeColor: Colors.cyan,
      redForIncome: false,
      dark: false,
      todayLabel: 'Today',
      todayExpenseLabel: 'Expense',
      monthExpenseLabel: labels.first,
      monthIncomeLabel: labels.last,
      width: 155,
      height: 155,
    )));
    expect(tester.takeException(), isNull);
    for (final label in labels) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, isNull);
      expect(tester.getSize(find.text(label)).height, greaterThan(16));
    }
    expect(tester.getRect(money('¥100.25')).bottom,
        closeTo(tester.getRect(money('¥50.00')).bottom, 0.01));
  });
  for (final dark in [false, true]) {
    testWidgets('中号按系统画布居中，收支分栏、实际币种与语义色 ($dark)', (tester) async {
      final height = dark ? 182.0 : 169.0;
      await tester.pumpWidget(card(GlanceView.medium(
        todayExpense: largeExpense,
        todayIncome: 'HK\$0.00',
        monthExpense: 'HK\$32,456.78',
        monthIncome: 'HK\$100,000.00',
        themeColor: Colors.indigo,
        redForIncome: !dark,
        dark: dark,
        titleLabel: 'Overview',
        monthSuffix: '',
        periodLabel: 'Nov',
        currencyCode: 'HKD',
        todayExpenseLabel: "Today's expense",
        todayIncomeLabel: "Today's income",
        monthExpenseLabel: 'Monthly expense',
        monthIncomeLabel: 'Monthly income',
        width: 364,
        height: height,
      )));

      expect(tester.takeException(), isNull);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Nov · HKD'), findsOneWidget);
      final surface = tester.getRect(find.byType(WidgetCardSurface));
      expect(surface.size, const Size(364, 169));
      expect(surface.center, tester.getRect(find.byType(GlanceView)).center);
      expect(tester.getCenter(money(largeExpense)).dx,
          lessThan(surface.center.dx));
      expect(tester.getCenter(money('HK\$0.00')).dx,
          greaterThan(surface.center.dx));
      expect(tester.getTopLeft(money('HK\$32,456.78')).dy,
          greaterThan(tester.getTopLeft(money(largeExpense)).dy));
      final colors = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.shape == BoxShape.circle)
          .map((d) => d.color);
      expect(colors, [
        widgetExpenseColor(!dark, dark: dark),
        widgetIncomeColor(!dark, dark: dark)
      ]);
      expect(tester.widget<WidgetCardMoney>(money(largeExpense)).color, isNull);
    });

    testWidgets('小号突出今日支出并保留长金额和两个月度字段 ($dark)', (tester) async {
      await tester.pumpWidget(card(GlanceView.small(
        todayExpense: largeExpense,
        monthExpense: 'HK\$100,000.00',
        monthIncome: 'HK\$0.00',
        themeColor: Colors.indigo,
        redForIncome: true,
        dark: dark,
        todayLabel: 'Today',
        titleLabel: dark ? 'Overview' : '',
        todayExpenseLabel: "Today's expense",
        monthExpenseLabel: 'Monthly expense',
        monthIncomeLabel: 'Monthly income',
        width: 155,
        height: 155,
      )));
      expect(tester.takeException(), isNull);
      expect(find.text(dark ? 'Overview' : 'Today'), findsOneWidget);
      final primary = tester.widget<WidgetCardMoney>(money(largeExpense));
      final monthly = tester.widget<WidgetCardMoney>(money('HK\$100,000.00'));
      expect(primary.fontSize, greaterThan(monthly.fontSize));
      expect(tester.getRect(money(largeExpense)).bottom,
          lessThan(tester.getRect(money('HK\$100,000.00')).top));
      expect(tester.getCenter(money('HK\$100,000.00')).dx,
          lessThan(tester.getCenter(money('HK\$0.00')).dx));
    });
  }
}
