library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/widget/views/bee_trail_view.dart';
import 'package:beecount/widget/widget_data_service.dart';

void main() {
  const size = Size(155, 155);

  List<DailyWidgetActivity> activity({bool empty = false}) => List.generate(
        30,
        (index) => DailyWidgetActivity(
          date: DateTime(2026, 8, index + 1),
          expenseTotal: 0,
          hasRecord: !empty && index >= 25,
        ),
      );

  Widget wrap(Widget child) => Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: size.width, height: size.height, child: child),
      );

  /// 与 HomeWidget.renderFlutterWidget 一致的离屏布局结构。固定 SizedBox
  /// 冒烟测试无法暴露 Column 给子节点松散横向约束时 CustomPaint 宽度归零。
  Widget renderHarness(Widget child) => Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [child],
        ),
      );

  for (final dark in [false, true]) {
    testWidgets('155x155 ${dark ? "暗色" : "亮色"}显示连续记账和完成率', (tester) async {
      await tester.pumpWidget(wrap(BeeTrailView(
        activity: activity(),
        themeColor: const Color(0xFFF5A623),
        dark: dark,
        titleLabel: '记账连续蜂迹',
        streakSuffix: '天',
        completionLabel: '本月完成率',
        emptyLabel: '今天记一笔，点亮第一格',
        width: size.width,
        height: size.height,
      )));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('记账连续蜂迹'), findsOneWidget);
      expect(find.text('5 天'), findsOneWidget);
      expect(find.text('本月完成率'), findsOneWidget);
    });
  }

  testWidgets('没有记账历史时显示引导文案', (tester) async {
    await tester.pumpWidget(wrap(BeeTrailView(
      activity: activity(empty: true),
      themeColor: const Color(0xFFF5A623),
      dark: false,
      titleLabel: '记账连续蜂迹',
      streakSuffix: '天',
      completionLabel: '本月完成率',
      emptyLabel: '今天记一笔，点亮第一格',
      width: size.width,
      height: size.height,
    )));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('今天记一笔，点亮第一格'), findsOneWidget);
  });

  testWidgets('home_widget 离屏布局下蜂巢画布宽高均大于 0', (tester) async {
    await tester.pumpWidget(renderHarness(BeeTrailView(
      activity: activity(),
      themeColor: const Color(0xFFF5A623),
      dark: false,
      titleLabel: '记账连续蜂迹',
      streakSuffix: '天',
      completionLabel: '本月完成率',
      emptyLabel: '今天记一笔，点亮第一格',
      width: size.width,
      height: size.height,
    )));
    await tester.pump();

    final paint = tester.renderObject<RenderBox>(find.byType(CustomPaint));
    expect(paint.size.width, greaterThan(0));
    expect(paint.size.height, greaterThan(0));
  });

  testWidgets('仅最早两天有记录时，28 天蜂巢显示为空状态', (tester) async {
    final oldestOnly = List.generate(
      30,
      (index) => DailyWidgetActivity(
        date: DateTime(2026, 8, index + 1),
        expenseTotal: 0,
        hasRecord: index < 2,
      ),
    );
    await tester.pumpWidget(wrap(BeeTrailView(
      activity: oldestOnly,
      themeColor: const Color(0xFFF5A623),
      dark: false,
      titleLabel: '记账连续蜂迹',
      streakSuffix: '天',
      completionLabel: '本月完成率',
      emptyLabel: '今天记一笔，点亮第一格',
      width: size.width,
      height: size.height,
    )));
    await tester.pump();

    expect(find.text('今天记一笔，点亮第一格'), findsOneWidget);
    expect(find.text('7%'), findsNothing);
  });
}
