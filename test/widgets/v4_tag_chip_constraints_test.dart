import 'package:beecount/widgets/biz/tag_chip.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.4]) {
      for (final name in [
        'An exceptionally long English tag name',
        '一个需要完整朗读但是视觉可省略的中文标签名称'
      ]) {
        testWidgets('标签有限宽度保留高度字号颜色与完整语义 $brightness $scale $name', (t) async {
          t.view.physicalSize = const Size(320, 568);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          var tapped = 0;
          final semantics = t.ensureSemantics();
          try {
            await t.pumpWidget(MaterialApp(
                theme: beeTheme(brightness: brightness),
                home: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                        body: Column(children: [
                      for (final size in TagChipSize.values)
                        SizedBox(
                            width: 96,
                            child: TagChip(
                                key: ValueKey(size),
                                name: name,
                                color: '#CC6600',
                                size: size,
                                onTap: () => tapped++)),
                    ])))));
            await t.pumpAndSettle();
            final heights = [20.0, 28.0, 36.0], fonts = [11.0, 13.0, 15.0];
            for (var i = 0; i < TagChipSize.values.length; i++) {
              final chip = find.byKey(ValueKey(TagChipSize.values[i]));
              expect(t.getSize(chip).height, heights[i]);
              final text = find.descendant(of: chip, matching: find.text(name));
              final widget = t.widget<Text>(text);
              expect(widget.style!.fontSize, fonts[i]);
              expect(widget.style!.color, const Color(0xffcc6600));
              expect(widget.maxLines, 1);
              expect(widget.overflow, TextOverflow.ellipsis);
              expect(t.getSemantics(text).label, name);
            }
            await t.tap(find.byKey(const ValueKey(TagChipSize.small)));
            expect(tapped, 1);
            expect(t.takeException(), isNull);
          } finally {
            semantics.dispose();
            await t.pumpWidget(const SizedBox.shrink());
          }
        });
      }
    }
  }
  testWidgets('320宽140%多标签加一和compact单标签回调保留完整名称', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    const long = 'One very long original tag name with spaces';
    String? picked;
    var more = 0;
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
            child: Scaffold(
                body: Padding(
                    padding: const EdgeInsets.all(17),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TagChipList(
                              tags: const [
                                (id: 1, name: long, color: '#123456'),
                                (id: 2, name: '中文标签', color: null),
                                (id: 3, name: 'third', color: null)
                              ],
                              maxDisplay: 2,
                              onTagTap: (id, name) => picked = '$id:$name',
                              onMoreTap: () => more++),
                          const SizedBox(height: 16),
                          SizedBox(
                              width: 90,
                              child: Row(children: [
                                Flexible(
                                    child: TagChip(
                                        name: long, onTap: () => picked = long))
                              ])),
                        ]))))));
    await t.pumpAndSettle();
    expect(find.text('+1'), findsOneWidget);
    await t.tap(find.text('+1'));
    expect(more, 1);
    await t.tap(find.text(long).first);
    expect(picked, '1:$long');
    await t.tap(find.text(long).last);
    expect(picked, long);
    expect(t.takeException(), isNull);
  });
}
