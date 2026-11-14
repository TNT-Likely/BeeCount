import 'dart:convert';
import 'dart:io';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('正式智能记账行的所有图标均随包提供', () {
    final entries =
        File('lib/pages/settings/smart_billing/bindings/smart_billing_entries.dart')
            .readAsStringSync();
    final preferences =
        File('lib/pages/settings/smart_billing/bindings/smart_billing_preferences.dart')
            .readAsStringSync();
    final icons = <String>{
      ...RegExp(r"(?:row|guide)\(\s*'([A-Za-z0-9]+)'", multiLine: true)
          .allMatches(entries)
          .map((m) => m[1]!),
      ...RegExp(r"BeeLineIcon\('([A-Za-z0-9]+)'", multiLine: true)
          .allMatches(preferences)
          .map((m) => m[1]!),
    };
    expect(icons, containsAll(['ScanLine', 'Command', 'Paperclip']));
    for (final icon in icons) {
      final asset = File('packages/beecount_ui/assets/icons/$icon.svg');
      expect(asset.existsSync(), isTrue, reason: icon);
      expect(asset.readAsStringSync(), contains('viewBox="0 0 24 24"'));
    }
  });
  final f = jsonDecode(File('test/fixtures/v4-smart-billing-geometry.json')
      .readAsStringSync()) as Map;
  for (final width in [398.0, 320.0]) {
    testWidgets('引导文本和卡片遵循冻结HTML尺寸 $width', (t) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          theme: beeTheme(),
          home: Scaffold(
              body: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: (f['sideInset'] as num).toDouble()),
            child: BeeSurface(
                padding: EdgeInsets.all((f['cardPadding'] as num).toDouble()),
                child: const BeeBillingGuide(
                    description: '完整使用说明',
                    requirement: 'AI能力要求',
                    actionHint: '真实操作提示')),
          ))));
      expect(
          t.getSize(find.byType(BeeSurface)).width, width - 2 * f['sideInset']);
      final description = t.widget<Text>(find.text('完整使用说明'));
      expect(description.style!.fontSize, f['guideFont']);
      expect(description.style!.height, f['guideLineHeight']);
      for (final label in ['AI能力要求', '真实操作提示']) {
        final status = find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first;
        final container = t.widget<Container>(status);
        expect(container.padding,
            EdgeInsets.all((f['statusPadding'] as num).toDouble()));
        expect((container.decoration as BoxDecoration).borderRadius,
            BorderRadius.circular((f['statusRadius'] as num).toDouble()));
      }
      expect(t.takeException(), isNull);
    });
  }
}
