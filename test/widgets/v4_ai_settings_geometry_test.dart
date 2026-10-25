import 'dart:convert';
import 'dart:io';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final f = jsonDecode(
          File('test/fixtures/v4-ai-settings-geometry.json').readAsStringSync())
      as Map;
  test('AI设置使用的线性图标均实际随包提供', () {
    for (final name in [
      'MessageSquare',
      'Images',
      'Mic',
      'Cloud',
      'Sparkles',
      'Circle',
      'CircleCheck',
      'Pencil'
    ]) {
      final file = File('packages/beecount_ui/assets/icons/$name.svg');
      expect(file.existsSync(), isTrue, reason: name);
      expect(file.readAsStringSync(), contains('viewBox="0 0 24 24"'));
    }
  });
  for (final size in [const Size(398, 844), const Size(320, 568)]) {
    testWidgets('能力行与授权正文对齐冻结HTML $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          theme: beeTheme(),
          home: Scaffold(
              body: Column(children: [
            BeeSurface(
                padding: EdgeInsets.symmetric(
                    horizontal: (f['cardPadding'] as num).toDouble()),
                child: BeeAICapabilityRow(
                    title: '文本对话',
                    description: '选择文本能力',
                    providerName: '用于检查换行的很长的服务商名称',
                    icon: const BeeLineIcon('MessageSquare'),
                    onSelect: () {})),
            BeeAIConsentContent(
                description: '完整原授权内容', policyLabel: '隐私政策', onPolicy: () {}),
          ]))));
      expect(t.widget<Text>(find.text('文本对话')).style!.fontSize, f['titleFont']);
      expect(t.widget<Text>(find.text('选择文本能力')).style!.fontSize,
          f['descriptionFont']);
      final provider = find.text('用于检查换行的很长的服务商名称');
      expect(t.widget<Text>(provider).style!.fontSize, f['providerFont']);
      expect(
          t
              .getSize(find
                  .ancestor(of: provider, matching: find.byType(SizedBox))
                  .first)
              .width,
          f['providerControlWidth']);
      expect(t.widget<Text>(find.text('完整原授权内容')).style!.fontSize,
          f['consentFont']);
      expect(t.widget<Text>(find.text('完整原授权内容')).style!.height,
          f['consentLineHeight']);
      expect(t.takeException(), isNull);
    });
  }
}
