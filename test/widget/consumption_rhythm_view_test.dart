library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/widget/views/consumption_rhythm_view.dart';
import 'package:beecount/widget/widget_data_service.dart';

void main() {
  const size = Size(364, 169);

  List<DailyWidgetActivity> activity() => List.generate(
        30,
        (index) => DailyWidgetActivity(
          date: DateTime(2026, 8, index + 1),
          expenseTotal: switch (index % 4) { 0 => 0, 1 => 12, 2 => 45, _ => 120 },
          hasRecord: index.isEven,
        ),
      );

  Widget wrap(Widget child) => Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: size.width, height: size.height, child: child),
      );

  for (final dark in [false, true]) {
    testWidgets('364x169 ${dark ? "暗色" : "亮色"}显示热力图和节奏提示',
        (tester) async {
      await tester.pumpWidget(wrap(ConsumptionRhythmView(
        activity: activity(),
        themeColor: const Color(0xFFF5A623),
        dark: dark,
        titleLabel: '消费节奏',
        stableLabel: '消费很均匀',
        increaseLabel: '比上周更快',
        decreaseLabel: '比上周更稳',
        emptyLabel: '本月还没有支出',
        width: size.width,
        height: size.height,
      )));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('消费节奏'), findsOneWidget);
      expect(find.byType(ConsumptionRhythmView), findsOneWidget);
    });
  }

  testWidgets('无支出时显示明确的空状态文案', (tester) async {
    final empty = List.generate(
        30,
        (index) => DailyWidgetActivity(
            date: DateTime(2026, 8, index + 1),
            expenseTotal: 0,
            hasRecord: false));
    await tester.pumpWidget(wrap(ConsumptionRhythmView(
      activity: empty,
      themeColor: const Color(0xFFF5A623),
      dark: false,
      titleLabel: '消费节奏',
      stableLabel: '消费很均匀',
      increaseLabel: '比上周更快',
      decreaseLabel: '比上周更稳',
      emptyLabel: '本月还没有支出',
      width: size.width,
      height: size.height,
    )));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('本月还没有支出'), findsOneWidget);
  });
}
