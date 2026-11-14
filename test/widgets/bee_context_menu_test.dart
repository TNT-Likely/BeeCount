import 'package:beecount/theme.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const label = '复制为新交易';
const rowKey = ValueKey('source-row');

Future<({Rect row, Future<String?> result})> openMenu(WidgetTester tester,
    {required ThemeData theme,
    double top = 350,
    double screenWidth = 390,
    double textScale = 1,
    TextDirection direction = TextDirection.ltr,
    String actionLabel = label}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(screenWidth, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  late Future<String?> result;
  await tester.pumpWidget(MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 48, bottom: 24),
              textScaler: TextScaler.linear(textScale)),
          child: Directionality(textDirection: direction, child: child!)),
      home: Scaffold(
          body: Stack(children: [
        Positioned(
            left: 0,
            right: 0,
            top: top,
            child: Builder(
                builder: (context) => GestureDetector(
                    key: rowKey,
                    onLongPress: () {
                      final row = context.findRenderObject() as RenderBox;
                      result = showBeeContextMenu<String>(context,
                          anchor: row.localToGlobal(
                              Offset(row.size.width, row.size.height)),
                          items: [
                            BeeMenuAction(
                                value: 'copy',
                                icon: const Icon(Icons.copy_outlined, size: 20),
                                label: actionLabel)
                          ]);
                    },
                    child: const SizedBox(
                        height: 80, child: Center(child: Text('Source'))))))
      ]))));
  final row = tester.getRect(find.byKey(rowKey));
  await tester.longPress(find.byKey(rowKey));
  await tester.pumpAndSettle();
  return (row: row, result: result);
}

Finder menuSurface() => find
    .ancestor(
        of: find.byType(PopupMenuItem<String>), matching: find.byType(Material))
    .first;

void main() {
  final themes = {
    'light': BeeTheme.lightTheme(),
    'dark': BeeTheme.darkTheme(),
    'custom primary': BeeTheme.lightTheme().copyWith(
        colorScheme:
            BeeTheme.lightTheme().colorScheme.copyWith(primary: Colors.blue))
  };
  for (final theme in themes.entries) {
    testWidgets('${theme.key}: 当前卡片面板、16圆角与单项动作回调', (tester) async {
      final opened = await openMenu(tester, theme: theme.value);
      final context = tester.element(find.byKey(rowKey));
      final material = tester.widget<Material>(menuSurface());
      expect(material.color, BeeCardTheme.of(context).surface);
      expect(material.surfaceTintColor, Colors.transparent);
      expect((material.shape as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(16));
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
      expect(find.byType(PopupMenuItem<String>), findsOneWidget);
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.fontSize, 13);
      final ink = text.style?.color ??
          DefaultTextStyle.of(tester.element(find.text(label))).style.color;
      expect(ink, isNot(material.color));
      final bounds = tester.getRect(menuSurface());
      expect(bounds.top, greaterThanOrEqualTo(opened.row.bottom));
      expect(bounds.right, lessThanOrEqualTo(390 - 8));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(await opened.result, 'copy');
    });
  }
  for (final top in [60.0, 730.0]) {
    testWidgets('当前点锚菜单在屏幕边缘 $top 保留安全区和取消结果', (tester) async {
      final opened =
          await openMenu(tester, theme: BeeTheme.lightTheme(), top: top);
      final bounds = tester.getRect(menuSurface());
      expect(bounds.top, greaterThanOrEqualTo(48));
      expect(bounds.bottom, lessThanOrEqualTo(820));
      // The live API takes a point, not the retired Rect avoid-region. Preserve
      // safe-area assertions; it does not promise to avoid an entire source row.
      if (top == 60) {
        expect(bounds.top, greaterThanOrEqualTo(opened.row.bottom));
      }
      await tester.tapAt(const Offset(8, 500));
      await tester.pumpAndSettle();
      expect(await opened.result, isNull);
    });
  }
  testWidgets('窄屏大号英文文字可换行且菜单仍可操作', (tester) async {
    final opened = await openMenu(tester,
        theme: BeeTheme.darkTheme(),
        screenWidth: 320,
        textScale: 2,
        actionLabel: 'Copy as new transaction');
    final bounds = tester.getRect(menuSurface());
    expect(bounds.left, greaterThanOrEqualTo(8));
    expect(bounds.right, lessThanOrEqualTo(312));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Copy as new transaction'));
    await tester.pumpAndSettle();
    expect(await opened.result, 'copy');
  });
  testWidgets('RTL点锚菜单保持视口边界与动作回调', (tester) async {
    final opened = await openMenu(tester,
        theme: BeeTheme.lightTheme(), direction: TextDirection.rtl);
    final bounds = tester.getRect(menuSurface());
    expect(bounds.left, greaterThanOrEqualTo(8));
    expect(bounds.right, lessThanOrEqualTo(382));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    expect(await opened.result, 'copy');
  });
  testWidgets('当前菜单按钮保留独立触控和选中回调', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BeeMenuButton<String>(
                label: '更多操作',
                items: const [
                  BeeMenuAction(
                      value: 'copy',
                      icon: Icon(Icons.copy_outlined),
                      label: label)
                ],
                onSelected: (value) => selected = value))));
    expect(tester.getSize(find.byType(BeeMenuButton<String>)).height,
        greaterThanOrEqualTo(44));
    await tester.tap(find.byType(BeeMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    expect(selected, 'copy');
    expect(tester.takeException(), isNull);
  });
}
