import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('4.x 输入区保留快捷按钮和 44 像素触点；中文组词不发送，Shift+Enter 插入换行', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final input = TextEditingController();
    addTearDown(input.dispose);
    var opened = 0;
    final sent = <String>[];
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(
            body: Align(
                alignment: Alignment.bottomCenter,
                child: BeeConversationInput(
                  controller: input,
                  hint: '问账本，或记一笔…',
                  sendLabel: '发送',
                  stopLabel: '停止',
                  busy: false,
                  quickActionsLabel: '快捷操作',
                  onQuickActions: () => opened++,
                  onSend: () => sent.add(input.text),
                  onStop: () {},
                )))));
    final quick = find.byKey(const ValueKey('ai-chat-quick-actions'));
    final send = find.byKey(const ValueKey('ai-chat-send'));
    final field = find.byType(TextField);
    final frame = find.descendant(
        of: find.byType(BeeConversationInput),
        matching: find.byType(BeeSurface));
    expect(t.getRect(frame).left, 13);
    expect(t.widget<BeeSurface>(frame).borderRadius, BorderRadius.circular(22));
    expect(t.getTopLeft(quick).dx - t.getTopLeft(frame).dx, 4);
    expect(t.getSize(send), const Size.square(44));
    expect(t.getSize(quick), const Size.square(44));
    expect(t.getSize(field).height, 44);
    expect(t.widget<BeeIconButton>(send).onPressed, isNull);
    await t.tap(quick);
    expect(opened, 1);
    await t.showKeyboard(field);
    t.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'can',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3)));
    await t.pump();
    expect(t.widget<BeeIconButton>(send).onPressed, isNull);
    await t.testTextInput.receiveAction(TextInputAction.send);
    expect(sent, isEmpty);
    t.testTextInput.updateEditingValue(const TextEditingValue(
        text: '餐饮', selection: TextSelection.collapsed(offset: 1)));
    await t.pump();
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await t.pump();
    expect(input.text, '餐\n饮');
    expect(sent, isEmpty);
    expect(t.getSize(field).height, greaterThan(44));
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sent, ['餐\n饮']);
    await t.testTextInput.receiveAction(TextInputAction.send);
    expect(sent, ['餐\n饮', '餐\n饮']);
    expect(t.takeException(), isNull);
  });
}
