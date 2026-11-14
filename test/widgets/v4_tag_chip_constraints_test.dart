import 'package:beecount_business_ui/beecount_business_ui.dart';
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
        testWidgets('当前紧凑BeeTag有限宽、大字、颜色与全名语义 $brightness $scale $name',
            (t) async {
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
                      for (final interactive in [false, true])
                        SizedBox(
                            width: 96,
                            child: BeeTag(
                                key: ValueKey(interactive),
                                tag: BeeTagData(
                                    '1', name, const Color(0xffcc6600)),
                                compact: true,
                                onTap: interactive ? () => tapped++ : null))
                    ])))));
            await t.pumpAndSettle();
            for (final interactive in [false, true]) {
              final chip = find.byKey(ValueKey(interactive));
              final text = find.descendant(of: chip, matching: find.text(name));
              final label = t.widget<Text>(text);
              expect(label.style!.fontSize, 10);
              expect(
                  label.style!.color,
                  brightness == Brightness.dark
                      ? Color.lerp(const Color(0xffcc6600), Colors.white, .3)
                      : const Color(0xffcc6600));
              expect(label.maxLines, 1);
              expect(label.overflow, TextOverflow.ellipsis);
              expect(t.getSemantics(text).label, name);
              final pill = find.descendant(
                  of: chip,
                  matching: find.byKey(const ValueKey('bee-tag-pill')));
              final height = t.getSize(pill).height;
              expect(height, greaterThanOrEqualTo(21));
              expect(height, lessThanOrEqualTo(32));
              if (scale == 1) expect(height, 21);
              expect(t.getSize(chip).height, interactive ? 44 : height);
            }
            expect(find.byTooltip(name), findsNWidgets(2));
            await t.tap(find.byKey(const ValueKey(true)));
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
  testWidgets('320宽140%当前表单摘要+N与长名点击保留真实回调', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    const name = 'One very long original tag name with spaces';
    const tag = BeeTagData('1', name, Color(0xff123456));
    String? picked;
    var pickerOpened = 0;
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
                          SizedBox(
                              width: 140,
                              child: RecordingMetaControl(
                                  label: '选择标签',
                                  onTap: () => pickerOpened++,
                                  child: const RecordingTagSummary(
                                      first: BeeTag(tag: tag, compact: true),
                                      count: 3))),
                          const SizedBox(height: 16),
                          SizedBox(
                              width: 90,
                              child: Row(children: [
                                Flexible(
                                    child: BeeTag(
                                        tag: tag,
                                        compact: true,
                                        onTap: () =>
                                            picked = '${tag.id}:${tag.label}'))
                              ]))
                        ]))))));
    await t.pumpAndSettle();
    expect(find.text('+2'), findsOneWidget);
    await t.tap(find.text('+2'));
    expect(pickerOpened, 1);
    await t.tap(find.text(name).first);
    expect(pickerOpened, 2);
    await t.tap(find.text(name).last);
    expect(picked, '1:$name');
    expect(t.takeException(), isNull);
  });
}
