import 'dart:convert';
import 'dart:io';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('标签主卡对齐独立HTML标准/小屏尺寸和语义色紧凑标签', (tester) async {
    final fixture = jsonDecode(File('test/fixtures/v4-tag-detail-geometry.json')
        .readAsStringSync()) as Map<String, dynamic>;
    for (final raw in fixture['cases'] as List) {
      final p = raw['profile'] as Map<String, dynamic>,
          g = raw['geometry'] as Map<String, dynamic>;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize =
          Size((p['width'] as num).toDouble(), (p['height'] as num).toDouble());
      await tester.pumpWidget(MaterialApp(
          theme: beeTheme(),
          home: Scaffold(
              body: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                      width: (g['width'] as num).toDouble(),
                      child: const BeeResourceHero(
                          title: '旅行',
                          titleWidget: Align(
                              alignment: Alignment.centerLeft,
                              child: BeeTag(
                                  tag: BeeTagData(
                                      'travel', '旅行', Color(0xff219c9c)),
                                  compact: true)),
                          caption: '日常生活',
                          icon: BeeLineIcon('Tag', color: Color(0xff219c9c)),
                          amountLabel: '总支出',
                          prefix: '¥',
                          amount: '85.20',
                          metrics: [
                            BeeResourceMetric(label: '总收入', value: '¥9.00'),
                            BeeResourceMetric(label: '关联分类', value: '3'),
                            BeeResourceMetric(label: '交易笔数', value: '4笔')
                          ]))))));
      await tester.pumpAndSettle();
      final card = find.byType(BeeResourceHero),
          surface =
              find.descendant(of: card, matching: find.byType(BeeSurface));
      expect(tester.getSize(card).width, g['width']);
      expect(tester.getSize(card).height,
          closeTo(g['height'], fixture['glyphMetricHeightTolerancePx']));
      expect(
          tester.getTopLeft(find.byType(BeeMoney)).dx -
              tester.getTopLeft(surface).dx,
          g['padding']);
      final money = tester.widget<BeeMoney>(find.byType(BeeMoney));
      expect(money.size, g['amountFont']);
      expect(money.prefixSize, g['prefixFont']);
      expect(tester.widget<BeeTag>(find.byType(BeeTag)).compact, isTrue);
      expect(tester.widget<BeeTag>(find.byType(BeeTag)).tag.color,
          const Color(0xff219c9c));
      expect(tester.takeException(), isNull);
    }
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}
