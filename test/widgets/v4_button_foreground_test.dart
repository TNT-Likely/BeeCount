import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final kind in BeeButtonKind.values) {
      for (final enabled in [true, false]) {
        testWidgets('按钮图标与正文同色 $brightness $kind enabled=$enabled', (t) async {
          await t.pumpWidget(MaterialApp(
              theme: applyBeeCardTheme(beeTheme(brightness: brightness)),
              home: Scaffold(
                  body: BeeButton(
                      label: '在该日记账',
                      kind: kind,
                      icon: const BeeLineIcon('Plus'),
                      onPressed: enabled ? () {} : null))));
          final text = t.element(find.text('在该日记账'));
          final svg = t.widget<SvgPicture>(find.byType(SvgPicture));
          final foreground = DefaultTextStyle.of(text).style.color;
          expect(foreground, isNotNull);
          expect(
              svg.colorFilter, ColorFilter.mode(foreground!, BlendMode.srcIn));
          if (enabled) {
            final press = await t.startGesture(t.getCenter(find.text('在该日记账')));
            await t.pump(const Duration(milliseconds: 100));
            final active = t.widget<SvgPicture>(find.byType(SvgPicture));
            expect(
                active.colorFilter,
                ColorFilter.mode(
                    DefaultTextStyle.of(text).style.color!, BlendMode.srcIn));
            await press.up();
            await t.pumpAndSettle();
          }
          expect(t.takeException(), isNull);
        });
      }
    }
  }
}
