import 'dart:convert';
import 'dart:io';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final f = jsonDecode(
          File('test/fixtures/v4-analytics-geometry.json').readAsStringSync())
      as Map;
  for (final size in [const Size(398, 844), const Size(320, 568)]) {
    testWidgets('统计汇总对齐独立HTML几何 $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          theme: beeTheme(),
          home: Scaffold(
              body: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: (f['sideInset'] as num).toDouble()),
                  child: BeeAnalyticsSummary(
                      period: '2026-10',
                      viewLabel: '支出',
                      totalLabel: '总支出：',
                      total: '¥3,286.5',
                      countLabel: '记账笔数',
                      count: '27',
                      averageLabel: '日均',
                      average: '¥164.33',
                      onPeriod: () {},
                      onView: () {})))));
      expect(
          t.getSize(find.byType(BeeAnalyticsSummary)).width, size.width - 34);
      expect(
          t.widget<Text>(find.text('¥3,286.5')).style!.fontSize, f['heroFont']);
      expect(t.getSize(find.widgetWithText(TextButton, '2026-10')).height,
          f['selectorHeight']);
      final surface = t.widget<BeeSurface>(find.byType(BeeSurface));
      expect(surface.padding,
          EdgeInsets.all((f['summaryPadding'] as num).toDouble()));
      expect(t.getBottomRight(find.widgetWithText(TextButton, '支出')).dx,
          size.width - 17 - 18);
      expect(t.takeException(), isNull);
    });
  }
}
