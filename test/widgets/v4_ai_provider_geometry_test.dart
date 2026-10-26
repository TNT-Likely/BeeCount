import 'dart:convert';
import 'dart:io';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final f = jsonDecode(
          File('test/fixtures/v4-ai-provider-geometry.json').readAsStringSync())
      as Map;
  for (final width in [398.0, 320.0]) {
    testWidgets('服务商元信息与测试行对齐独立HTML几何 $width', (t) async {
      t.view.physicalSize = Size(width, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          theme: beeTheme(),
          home: Scaffold(
              body: Column(children: [
            BeeAIProviderCard(
                name: 'QA服务',
                builtInLabel: '内置',
                capabilities: const [capability],
                editHint: '编辑',
                onEdit: () {}),
            BeeAIModelTestField(
                title: '文本模型',
                testLabel: '测试',
                field: const BeeField(label: '文本模型', showLabel: false),
                onTest: () {}),
          ]))));
      expect(t.widget<Text>(find.text('QA服务')).style!.fontSize, f['nameFont']);
      final label = find.widgetWithText(BeeLabel, '内置');
      expect(
          t.getSize(label).height,
          closeTo((f['labelHeight'] as num).toDouble(),
              (f['fontMetricTolerance'] as num).toDouble()));
      expect(t.widget<Text>(find.text('内置')).style!.fontSize, f['labelFont']);
      expect(t.widget<Text>(find.text('文本模型')).style!.fontSize,
          f['modelTitleFont']);
      expect(t.widget<Text>(find.text('测试')).style!.fontSize, f['testFont']);
      expect(t.widget<TextField>(find.byType(TextField)).style!.fontSize,
          f['inputFont']);
      final surface = t.widget<BeeSurface>(find.byType(BeeSurface));
      expect(surface.padding,
          EdgeInsets.all((f['cardPadding'] as num).toDouble()));
      expect(t.takeException(), isNull);
    });
  }
  test('服务卡与测试控件的所有装饰图标随包提供', () {
    for (final name in [
      'BadgeCheck',
      'Cloud',
      'Trash2',
      'ChevronRight',
      'MessageSquare',
      'Images',
      'Mic',
      'CircleCheck',
      'CircleAlert',
      'Play',
      'Eye',
      'EyeOff'
    ]) {
      expect(File('packages/beecount_ui/assets/icons/$name.svg').existsSync(),
          isTrue,
          reason: name);
    }
  });
}

const capability = BeeAIProviderCapability(
    '文本', BeeLineIcon('MessageSquare', size: 14),
    enabled: true);
