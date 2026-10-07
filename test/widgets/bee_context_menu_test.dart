import 'package:beecount/styles/tokens.dart';
import 'package:beecount/theme.dart';
import 'package:beecount/widgets/ui/bee_popup_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const label = '复制为新交易';
const rowKey = ValueKey('source-row');

Future<({Rect row, Future<String?> result})> openMenu(
  WidgetTester tester, {
  required ThemeData theme,
  double top = 350,
  double screenWidth = 390,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
  String actionLabel = label,
}) async {
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
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(textDirection: direction, child: child!),
    ),
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
                      final overlay = Overlay.of(context)
                          .context
                          .findRenderObject() as RenderBox;
                      final row = context.findRenderObject() as RenderBox;
                      result = BeePopupMenu.showForAnchor(
                        context: context,
                        anchor:
                            row.localToGlobal(Offset.zero, ancestor: overlay) &
                                row.size,
                        items: [
                          BeeMenuItem.action(
                              value: 'copy',
                              icon: Icons.copy_outlined,
                              label: actionLabel)
                        ],
                      );
                    },
                    child: const SizedBox(
                        height: 80, child: Center(child: Text('Source'))),
                  )),
        ),
      ]),
    ),
  ));
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
            BeeTheme.lightTheme().colorScheme.copyWith(primary: Colors.blue)),
  };
  for (final theme in themes.entries) {
    testWidgets(
        '${theme.key}: token surface, restrained primary icon and one action',
        (tester) async {
      final opened = await openMenu(tester, theme: theme.value);
      final context = tester.element(find.byKey(rowKey));
      final material = tester.widget<Material>(menuSurface());
      expect(material.color, BeeTokens.surfaceElevated(context));
      expect(material.surfaceTintColor, Colors.transparent);
      expect((material.shape as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(16));
      expect(tester.widget<Icon>(find.byIcon(Icons.copy_outlined)).color,
          theme.value.colorScheme.primary);
      expect(tester.widget<Text>(find.text(label)).style!.color,
          BeeTokens.textPrimary(context));
      expect(find.byType(PopupMenuItem<String>), findsOneWidget);
      final bounds = tester.getRect(menuSurface());
      expect(bounds.bottom, lessThan(opened.row.top));
      expect(bounds.right, closeTo(374, 1));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(await opened.result, 'copy');
    });
  }

  for (final top in [60.0, 730.0]) {
    testWidgets('anchor near screen edge $top stays in safe area',
        (tester) async {
      final opened =
          await openMenu(tester, theme: BeeTheme.lightTheme(), top: top);
      final bounds = tester.getRect(menuSurface());
      expect(bounds.top, greaterThanOrEqualTo(48));
      expect(bounds.bottom, lessThanOrEqualTo(820));
      expect(bounds.overlaps(opened.row), isFalse);
      if (top == 60) expect(bounds.top, greaterThan(opened.row.bottom));
      await tester.tapAt(const Offset(8, 500));
      await tester.pumpAndSettle();
      expect(await opened.result, isNull);
    });
  }

  testWidgets('large English text wraps within a narrow viewport',
      (tester) async {
    final opened = await openMenu(tester,
        theme: BeeTheme.darkTheme(),
        screenWidth: 320,
        textScale: 2,
        actionLabel: 'Copy as new transaction');
    final bounds = tester.getRect(menuSurface());
    expect(bounds.left, greaterThanOrEqualTo(16));
    expect(bounds.right, lessThanOrEqualTo(304));
    expect(bounds.overlaps(opened.row), isFalse);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Copy as new transaction'));
    await tester.pumpAndSettle();
    expect(await opened.result, 'copy');
  });

  testWidgets('RTL anchors the menu to the logical trailing edge',
      (tester) async {
    final opened = await openMenu(tester,
        theme: BeeTheme.lightTheme(), direction: TextDirection.rtl);
    expect(tester.getRect(menuSurface()).left, closeTo(16, 1));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    expect(await opened.result, 'copy');
  });

  testWidgets('existing button menu keeps its action callback', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BeePopupMenu(
      items: const [
        BeeMenuItem.action(
            value: 'copy', icon: Icons.copy_outlined, label: label)
      ],
      onSelected: (value) => selected = value,
    ))));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    expect(selected, 'copy');
    expect(tester.takeException(), isNull);
  });
}
