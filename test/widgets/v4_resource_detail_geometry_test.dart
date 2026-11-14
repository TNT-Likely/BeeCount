import 'dart:convert';
import 'dart:io';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('详情卡在标准和小屏沿用 HTML 冻结的尺寸与金额层级', (tester) async {
    final fixture = jsonDecode(
        File('test/fixtures/v4-resource-detail-geometry.json')
            .readAsStringSync()) as Map<String, dynamic>;
    for (final raw in fixture['sizes'] as List) {
      final m = raw as Map<String, dynamic>;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize =
          Size((m['viewportWidth'] as num).toDouble(), 844);
      await tester.pumpWidget(MaterialApp(
          theme: beeTheme(),
          home: const Scaffold(
              body: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: BeeResourceHero(
                      title: '餐饮',
                      caption: '一级分类 · 4 个二级分类 · 日常生活',
                      icon: BeeLineIcon('Utensils', size: 22),
                      amountLabel: '本月支出',
                      amount: '1,199.57',
                      prefix: '¥',
                      metrics: [
                        BeeResourceMetric(label: '记录笔数', value: '38笔'),
                        BeeResourceMetric(label: '单笔均额', value: '¥31.57'),
                        BeeResourceMetric(label: '占总支出', value: '36.5%')
                      ])))));
      await tester.pumpAndSettle();
      final surface = find.descendant(
          of: find.byType(BeeResourceHero), matching: find.byType(BeeSurface));
      expect(tester.getSize(surface).width, m['width']);
      expect(
          tester.getTopLeft(find.byType(BeeMoney)).dx -
              tester.getTopLeft(surface).dx,
          m['padding']);
      expect(
          tester.widget<Text>(find.text('餐饮')).style!.fontSize, m['titleFont']);
      final money = tester.widget<BeeMoney>(find.byType(BeeMoney));
      expect(money.size, m['amountFont']);
      expect(money.prefixSize, m['prefixFont']);
      expect(
          money.lineHeight! * money.size, closeTo(m['amountLineHeight'], .001));
      expect(tester.takeException(), isNull);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
