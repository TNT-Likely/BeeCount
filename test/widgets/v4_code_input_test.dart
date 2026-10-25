import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('代码输入是外置语义的多行字段，行数/字体/内容回调保持受控', (t) async {
    final c = TextEditingController(text: 'one\ntwo');
    addTearDown(c.dispose);
    String? changed;
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(
            body: BeeCodeEditor(
                label: 'Source',
                controller: c,
                minLines: 3,
                maxLines: 6,
                onChanged: (v) => changed = v))));
    final field = t.widget<TextField>(find.byType(TextField));
    expect(field.minLines, 3);
    expect(field.maxLines, 6);
    expect(field.style!.fontFamily, 'monospace');
    expect(field.style!.fontSize, 13);
    expect(field.style!.height, 1.5);
    expect(field.decoration!.labelText, isNull);
    await t.enterText(find.byType(TextField), 'changed\nvalue');
    expect(changed, 'changed\nvalue');
    expect(c.text, changed);
    expect(t.takeException(), isNull);
  });
  testWidgets('默认十行代码输入/可选预览的冻结HTML几何与只读约束', (t) async {
    final c = TextEditingController(text: 'source');
    addTearDown(c.dispose);
    t.view.physicalSize = const Size(398, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(
            body: Column(children: [
          BeeCodeEditor(label: 'Source', controller: c, readOnly: true),
          const BeeCodeBlock(text: 'preview')
        ]))));
    expect(t.getSize(find.byType(TextField)).height, closeTo(224, .6));
    expect(t.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    final text = t.widget<SelectableText>(find.byType(SelectableText));
    expect(text.style!.fontSize, 13);
    expect(text.style!.height, 1.5);
    expect(text.style!.fontFamily, 'monospace');
    expect(t.takeException(), isNull);
  });
}
