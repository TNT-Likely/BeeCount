import 'dart:convert';
import 'dart:io';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
