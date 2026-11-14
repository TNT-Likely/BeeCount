import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const options = [
    BeeColorOption(value: 0, color: Colors.teal, label: '蓝绿'),
    BeeColorOption(value: 1, color: Colors.orange, label: '橙色')
  ];
  testWidgets('颜色选择受控并提供44触控区', (tester) async {
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, set) => BeeColorPalette(
                    items: options,
                    value: selected,
                    onChanged: (int v) => set(() => selected = v))))));
    expect(tester.getSize(find.byTooltip('橙色')), const Size(44, 44));
    await tester.tap(find.byTooltip('橙色'));
    await tester.pump();
    expect(selected, 1);
    expect(
        tester
            .widget<BeeColorPalette<int>>(find.byType(BeeColorPalette<int>))
            .value,
        1);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
  testWidgets('禁用不调用操作，语义色不受主题变化影响', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(accent: Colors.pink),
        home: const Scaffold(
            body: BeeColorPalette(items: options, value: 0, onChanged: null))));
    await tester.tap(find.byTooltip('橙色'));
    await tester.pump();
    expect(
        tester
            .widget<BeeColorPalette<int>>(find.byType(BeeColorPalette<int>))
            .value,
        0);
    final colors = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color);
    expect(colors, containsAll([Colors.teal, Colors.orange]));
  });
  testWidgets('320大字长语义标签不挤占色块', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.6)),
                child: Scaffold(
                    body: BeeColorPalette<int>(
                        items: List.generate(
                            20,
                            (i) => BeeColorOption(
                                value: i,
                                color: Colors.teal,
                                label: '非常长的颜色名称 $i')),
                        value: 0,
                        onChanged: (_) {}))))));
    expect(find.byType(InkWell), findsNWidgets(20));
    expect(tester.takeException(), isNull);
  });
}
