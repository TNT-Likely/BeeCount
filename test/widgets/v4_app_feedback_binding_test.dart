import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('状态图标与语义颜色区分，旧状态 emoji 只移除开头 $brightness', (tester) async {
      const cases = [
        (BeeTone.success, '✅ 记账成功', '记账成功', 'CircleCheck'),
        (BeeTone.error, '❌ 保存失败', '保存失败', 'CircleAlert'),
        (BeeTone.warning, '⚠️ 请先选择分类', '请先选择分类', 'TriangleAlert'),
        (BeeTone.neutral, '暂无记录', '暂无记录', 'Info'),
        (BeeTone.success, '已完成 ✅', '已完成 ✅', 'CircleCheck'),
        (BeeTone.warning, '✅ 已保存，部分折算待补充', '已保存，部分折算待补充', 'TriangleAlert'),
      ];
      final colors = <Color>{};
      for (final (tone, message, display, icon) in cases) {
        await tester.pumpWidget(MaterialApp(
            theme: beeTheme(brightness: brightness),
            home: Scaffold(body: BeeToast(message: message, tone: tone))));
        final glyph = tester.widget<BeeLineIcon>(find.byType(BeeLineIcon));
        expect(glyph.name, icon);
        expect(find.text(display), findsOneWidget);
        colors.add(glyph.color!);
        final background = tester.widget<Material>(find.descendant(
            of: find.byType(BeeToast), matching: find.byType(Material)));
        // Use actual relative luminance; a status color must remain readable
        // against the inverse toast surface in both app appearances.
        final light = glyph.color!.computeLuminance();
        final surface = background.color!.computeLuminance();
        final contrast = (light > surface ? light + .05 : surface + .05) /
            (light > surface ? surface + .05 : light + .05);
        expect(contrast, greaterThanOrEqualTo(3));
        expect(tester.takeException(), isNull);
      }
      expect(colors, hasLength(4));
      await tester.pumpWidget(MaterialApp(
          theme: beeTheme(brightness: brightness),
          home: const Scaffold(
              body: BeeToast(message: '正在导入', tone: BeeTone.busy))));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(BeeLineIcon), findsNothing);
    });
  }

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
    showBeeToastOnOverlay(nav.currentState!.overlay!, '保存失败',
        tone: BeeTone.error);
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
    showBeeToastOnOverlay(nav.currentState!.overlay!, '测试完成',
        brightness: Brightness.dark);
    await tester.pump();
    final context = tester.element(find.byType(BeeToast));
    expect(Theme.of(context).brightness, Brightness.dark);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
