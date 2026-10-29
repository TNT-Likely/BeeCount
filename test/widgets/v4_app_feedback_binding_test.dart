import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App 原有轻提示入口使用基础组件，保留焦点且同层替换', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        theme: beeTheme(),
        home: Builder(
            builder: (context) => Scaffold(
                    body: Column(children: [
                  TextField(focusNode: focus),
                  TextButton(
                      onPressed: () =>
                          showBeeToast(context, '保存成功', tone: BeeTone.success),
                      child: const Text('显示结果')),
                ])))));
    focus.requestFocus();
    await tester.pump();
    await tester.tap(find.text('显示结果'));
    await tester.pump();
    expect(
        tester.widget<BeeToast>(find.byType(BeeToast)).tone, BeeTone.success);
    expect(focus.hasFocus, isTrue);
    showBeeToastOnOverlay(nav.currentState!.overlay!, '保存失败', tone: BeeTone.error);
    await tester.pump();
    expect(find.byType(BeeToast), findsOneWidget);
    expect(find.text('保存成功'), findsNothing);
    expect(tester.widget<BeeToast>(find.byType(BeeToast)).tone, BeeTone.error);
    expect(tester.getTopLeft(find.byType(BeeToast)).dy, 12);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(BeeToast), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('全局提示可指定深色，页面与 Overlay 卸载后计时器安全退出', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
        MaterialApp(navigatorKey: nav, home: const Scaffold(body: Text('页面'))));
    showBeeToastOnOverlay(nav.currentState!.overlay!, '测试完成', brightness: Brightness.dark);
    await tester.pump();
    final context = tester.element(find.byType(BeeToast));
    expect(Theme.of(context).brightness, Brightness.dark);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
