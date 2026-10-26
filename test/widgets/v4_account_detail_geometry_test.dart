import 'dart:convert';
import 'dart:io';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('账户主卡对齐独立HTML标准/小屏、有/无额度尺寸与层级', (tester) async {
    final fixture = jsonDecode(
        File('test/fixtures/v4-account-detail-geometry.json')
            .readAsStringSync()) as Map<String, dynamic>;
    for (final raw in fixture['cases'] as List) {
      final profile = raw['profile'] as Map<String, dynamic>,
          g = raw['geometry'] as Map<String, dynamic>;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size((profile['width'] as num).toDouble(),
          (profile['height'] as num).toDouble());
      final withLimit = raw['route'] == 'account-credit-detail';
      await tester.pumpWidget(MaterialApp(
          theme: beeTheme(),
          home: Scaffold(
              body: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                      width: (g['width'] as num).toDouble(),
                      child: BeeResourceHero(
                          title: withLimit ? '日常信用卡' : '备用信用卡',
                          caption: '信用卡 · CNY',
                          icon: const BeeLineIcon('CreditCard'),
                          amountLabel: '当前欠款',
                          prefix: '¥',
                          amount: withLimit ? '3,200.00' : '800.00',
                          metrics: withLimit
                              ? const [
                                  BeeResourceMetric(
                                      label: '信用额度', value: '¥20,000.00'),
                                  BeeResourceMetric(
                                      label: '可用额度', value: '¥16,800.00')
                                ]
                              : const []))))));
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
      expect(
          tester.widget<BeeMoney>(find.byType(BeeMoney)).size, g['amountFont']);
      expect(find.byType(Divider), withLimit ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    }
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}
