/// 收支速览([GlanceView])headless 冒烟测试:只断言各尺寸/明暗组合能正常
/// 构建、不抛异常(不依赖真机截图/golden;渲染管线本身见
/// `widget_manager_test.dart`)。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/widget/views/glance_view.dart';

void main() {
  Widget wrap(Widget child, Size size) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: size.width, height: size.height, child: child),
    );
  }

  group('GlanceView.medium', () {
    testWidgets('364x169(iOS)亮色下正常渲染,不抛异常', (tester) async {
      const size = Size(364, 169);
      await tester.pumpWidget(wrap(
        const GlanceView.medium(
          todayExpense: '¥123.45',
          todayIncome: '¥456.78',
          monthExpense: '¥1,234.56',
          monthIncome: '¥7,890.12',
          themeColor: Color(0xFFF5A623),
          redForIncome: true,
          dark: false,
          appName: '蜜蜂记账',
          monthSuffix: '月',
          todayExpenseLabel: '今日支出',
          todayIncomeLabel: '今日收入',
          monthExpenseLabel: '本月支出',
          monthIncomeLabel: '本月收入',
          width: 364,
          height: 169,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('蜜蜂记账'), findsOneWidget);
    });

    testWidgets('364x182(Android 2:1)暗色下正常渲染,不抛异常', (tester) async {
      const size = Size(364, 182);
      await tester.pumpWidget(wrap(
        const GlanceView.medium(
          todayExpense: '¥123.45',
          todayIncome: '¥456.78',
          monthExpense: '¥1,234.56',
          monthIncome: '¥7,890.12',
          themeColor: Color(0xFFF5A623),
          redForIncome: false,
          dark: true,
          appName: '蜜蜂记账',
          monthSuffix: '月',
          todayExpenseLabel: '今日支出',
          todayIncomeLabel: '今日收入',
          monthExpenseLabel: '本月支出',
          monthIncomeLabel: '本月收入',
          width: 364,
          height: 182,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('GlanceView.small', () {
    testWidgets('155x155 亮色下正常渲染,长数字不溢出', (tester) async {
      const size = Size(155, 155);
      await tester.pumpWidget(wrap(
        const GlanceView.small(
          todayExpense: '¥9,999,999.99',
          monthExpense: '¥1,234.56',
          monthIncome: '¥7,890.12',
          themeColor: Color(0xFFF5A623),
          redForIncome: true,
          dark: false,
          todayLabel: '今日',
          todayExpenseLabel: '今日支出',
          monthExpenseLabel: '本月支出',
          monthIncomeLabel: '本月收入',
          width: 155,
          height: 155,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('今日'), findsOneWidget);
    });

    testWidgets('155x155 暗色下正常渲染,不抛异常', (tester) async {
      const size = Size(155, 155);
      await tester.pumpWidget(wrap(
        const GlanceView.small(
          todayExpense: '¥0.00',
          monthExpense: '¥0.00',
          monthIncome: '¥0.00',
          themeColor: Color(0xFFF5A623),
          redForIncome: false,
          dark: true,
          todayLabel: '今日',
          todayExpenseLabel: '今日支出',
          monthExpenseLabel: '本月支出',
          monthIncomeLabel: '本月收入',
          width: 155,
          height: 155,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
