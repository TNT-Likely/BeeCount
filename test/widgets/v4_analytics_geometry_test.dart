import 'dart:convert';
import 'dart:io';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final f = jsonDecode(File('test/fixtures/v4-insights-card-geometry.json')
      .readAsStringSync()) as Map;
  for (final item in f['cases'] as List) {
    // Review chrome is a 1px border. Native logical size uses the declared
    // outer phone width; CSS padding/font/optical track values are independent.
    final size = Size(
        (item['width'] as num).toDouble() + 2, item['width'] > 350 ? 844 : 568);
    testWidgets('用户批准A稿：汇总字体/内边距/紧凑Tab光学高度 $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final side = (item['sideInset'] as num).toDouble();
      await t.pumpWidget(MaterialApp(
          theme: beeTheme(),
          home: Scaffold(
              body: Padding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  child: BeeAnalyticsSummary(
                      period: '2026年10月',
                      viewLabel: '支出',
                      totalLabel: '总支出',
                      total: '¥3,286.50',
                      countLabel: '记账笔数',
                      count: '26笔',
                      averageLabel: '日均支出',
                      average: '¥131.46',
                      views: const [
                        BeeSegment('expense', '支出'),
                        BeeSegment('income', '收入'),
                        BeeSegment('balance', '结余')
                      ],
                      selectedView: 'expense',
                      onViewChanged: (_) {},
                      onPeriod: () {})))));
      final summary = find.byType(BeeAnalyticsSummary);
      expect(t.getSize(summary).width, size.width - side * 2);
      final hero = find.descendant(
          of: summary,
          matching: find.byWidgetPredicate(
              (w) => w is Text && w.textSpan?.toPlainText() == '¥3,286.50'));
      expect(t.widget<Text>(hero).style!.fontSize, item['heroFont']);
      expect(
          t.widget<BeeSurface>(find.byType(BeeSurface)).padding,
          EdgeInsets.fromLTRB((item['summaryPadding'] as num).toDouble(), 16,
              (item['summaryPadding'] as num).toDouble(), 17));
      expect(t.getSize(find.byKey(const ValueKey('compact-tab-track'))).height,
          item['metricTrackHeight']);
      expect(t.getSize(find.byType(BeeCompactTabs<String>)).height, 40);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('进度底槽不会继承宿主Material种子的紫色', (t) async {
    await t.pumpWidget(MaterialApp(
        theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple)
                .copyWith(primary: const Color(0xfffacb16))),
        home: const Scaffold(
            body: BeeProgress(value: .365, label: '餐饮', trailing: '1200'))));
    expect(
        t
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .backgroundColor,
        const Color(0xfff3f4f5));
  });
}
