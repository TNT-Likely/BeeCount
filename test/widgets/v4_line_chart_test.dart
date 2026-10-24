import 'package:beecount/widgets/charts/line_chart.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final s in [
    (
      name: 'light-dual',
      dark: false,
      hide: false,
      minimal: false,
      values: <double>[100, 0, -50, 120]
    ),
    (
      name: 'hidden',
      dark: false,
      hide: true,
      minimal: false,
      values: <double>[100, 0, -50, 120]
    ),
    (
      name: 'dark-minimal',
      dark: true,
      hide: false,
      minimal: true,
      values: <double>[-40, -20, -60, -10]
    ),
    (
      name: 'single',
      dark: false,
      hide: false,
      minimal: false,
      values: <double>[30]
    ),
  ]) {
    testWidgets('原绘制基准 ${s.name}：抽离后逐像素一致', (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(400, 240);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      final key = GlobalKey();
      await t.pumpWidget(MaterialApp(
          theme: ThemeData(
              brightness: s.dark ? Brightness.dark : Brightness.light),
          home: Scaffold(
              body: RepaintBoundary(
                  key: key,
                  child: SizedBox(
                      width: 400,
                      height: 240,
                      child: LineChart(
                        values: s.values,
                        secondaryValues: s.name == 'light-dual'
                            ? const [20, 40, 0, 80]
                            : null,
                        secondaryColor: Colors.blue,
                        xLabels: s.values.length == 1
                            ? const ['26/1']
                            : const ['26/1', '26/2', '26/3', '26/4'],
                        highlightIndex: s.values.length - 1,
                        onSwipeLeft: () {},
                        onSwipeRight: () {},
                        showHint: false,
                        themeColor: const Color(0xfff8c91c),
                        isDark: s.dark,
                        whiteBg: !s.dark,
                        minimal: s.minimal,
                        hideAmounts: s.hide,
                      ))))));
      await t.pumpAndSettle();
      await expectLater(find.byKey(key),
          matchesGoldenFile('../fixtures/v4-line-chart-legacy/${s.name}.png'));
    });
  }

  testWidgets('主副线点击与横滑保留，禁用内部手势后外层收到点击', (t) async {
    var primary = 0, secondary = 0, left = 0, right = 0, outer = 0;
    Widget host(bool interactive) => MaterialApp(
            home: Scaffold(
                body: Center(
                    child: GestureDetector(
          onTap: () => outer++,
          child: SizedBox(
              width: 400,
              height: 240,
              child: BeeLineChart(
                values: const [0, 100],
                secondaryValues: const [100, 0],
                secondaryColor: Colors.blue,
                xLabels: const ['1', '2'],
                highlightIndex: 1,
                themeColor: Colors.amber,
                onPrimaryLineTap: () => primary++,
                onSecondaryLineTap: () => secondary++,
                onSwipeLeft: () => left++,
                onSwipeRight: () => right++,
                interactive: interactive,
              )),
        ))));
    await t.pumpWidget(host(true));
    final origin = t.getTopLeft(find.byType(BeeLineChart));
    await t.tapAt(origin + const Offset(388, 12));
    await t.tapAt(origin + const Offset(12, 12));
    expect(primary, 1);
    expect(secondary, 1);
    await t.fling(find.byType(BeeLineChart), const Offset(-100, 0), 800);
    await t.pumpAndSettle();
    await t.fling(find.byType(BeeLineChart), const Offset(100, 0), 800);
    await t.pumpAndSettle();
    expect(left, 1);
    expect(right, 1);
    await t.pumpWidget(host(false));
    await t.tap(find.byType(BeeLineChart));
    expect(outer, 1);
    expect(primary, 1);
    expect(secondary, 1);
  });

  testWidgets('同一列表仅隐私或配色变化必须重绘，空数组安全', (t) async {
    const data = <double>[0, 100];
    Widget host(bool hide, Color color, List<double> values) => MaterialApp(
        home: SizedBox(
            width: 400,
            height: 240,
            child: BeeLineChart(
              values: values,
              xLabels: const ['1', '2'],
              highlightIndex: 1,
              onSwipeLeft: () {},
              onSwipeRight: () {},
              themeColor: color,
              hideAmounts: hide,
            )));
    await t.pumpWidget(host(false, Colors.amber, data));
    final paints = find.descendant(
        of: find.byType(BeeLineChart), matching: find.byType(CustomPaint));
    final initial = t.widget<CustomPaint>(paints).painter!;
    await t.pumpWidget(host(true, Colors.amber, data));
    final hidden = t.widget<CustomPaint>(paints).painter!;
    expect(hidden.shouldRepaint(initial), isTrue);
    await t.pumpWidget(host(true, Colors.red, data));
    expect(
        t.widget<CustomPaint>(paints).painter!.shouldRepaint(hidden), isTrue);
    await t.pumpWidget(host(true, Colors.red, const []));
    expect(t.takeException(), isNull);
  });
}
