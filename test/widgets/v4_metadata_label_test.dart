import 'dart:ui' show SemanticsFlag;
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('静态元信息保持紧凑与非按钮语义，外置字段标题不重复', (t) async {
    final semantics = t.ensureSemantics();
    try {
      await t.pumpWidget(MaterialApp(
          theme: beeTheme(),
          home: const Scaffold(
              body: Column(children: [
            BeeLabel(label: '内置服务', accent: true),
            Text('外置标题'),
            BeeField(label: '外置标题', showLabel: false),
          ]))));
      expect(t.getSize(find.byType(BeeLabel)).height, lessThanOrEqualTo(22));
      expect(t.getSemantics(find.text('内置服务')).hasFlag(SemanticsFlag.isButton),
          isFalse);
      expect(t.widget<TextField>(find.byType(TextField)).decoration!.labelText,
          isNull);
      expect(find.text('外置标题'), findsOneWidget);
      expect(find.bySemanticsLabel('外置标题'), findsWidgets);
      expect(t.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('模型测试结果颜色复用反馈语义色', (t) async {
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(brightness: Brightness.dark),
        home: Builder(
            builder: (context) => Scaffold(
                    body: Column(children: [
                  Text('成功',
                      style: TextStyle(
                          color: beeToneColor(context, BeeTone.success))),
                  const BeeStatus(label: '原成功反馈', tone: BeeTone.success),
                ])))));
    expect(
        t.widget<Text>(find.text('成功')).style!.color, const Color(0xff8bd4aa));
    expect(t.takeException(), isNull);
  });
}
