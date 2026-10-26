import 'dart:ui' as ui;
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('开关保持点击拖动禁用与 44 触控区，轨道对齐 HTML 36×22 $brightness',
        (tester) async {
      var enabled = true, value = true, changes = 0;
      late StateSetter update;
      final capture = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme:
              beeTheme(brightness: brightness, accent: const Color(0xff26a69a)),
          home: Scaffold(body: StatefulBuilder(builder: (_, setState) {
            update = setState;
            return RepaintBoundary(
                key: capture,
                child: BeeToggleRow(
                    title: '开关',
                    subtitle: '说明',
                    value: value,
                    onChanged: enabled
                        ? (v) => setState(() {
                              value = v;
                              changes++;
                            })
                        : null));
          }))));
      await tester.pumpAndSettle();
      final toggle = find.byType(Switch);
      expect(tester.getSize(find.byType(BeeToggleRow)).height,
          greaterThanOrEqualTo(44));
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final raster = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final pixels =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        return (image, pixels);
      });
      final picture = raster!.$1, data = raster.$2;
      final target = tester.getCenter(toggle),
          rect = tester.getRect(find.byType(BeeToggleRow));
      final y = (target.dy - rect.top).floor(), row = <int>[];
      for (var x = (target.dx - rect.left - 30).floor();
          x < (target.dx - rect.left + 30).floor();
          x++) {
        final i = (y * picture.width + x) * 4;
        if ((data.getUint8(i) - 38).abs() < 8 &&
            (data.getUint8(i + 1) - 166).abs() < 8 &&
            (data.getUint8(i + 2) - 154).abs() < 8) {
          row.add(x);
        }
      }
      expect(row, isNotEmpty);
      // HTML frozen stylesheet: 36px track, 22px height, 14px thumb. Allow one
      // antialiased edge pixel on each side of the rasterized track.
      expect(row.last - row.first + 1, inInclusiveRange(34, 38));
      picture.dispose();
      await tester.tap(find.text('开关'));
      await tester.pumpAndSettle();
      expect(value, isFalse);
      expect(changes, 1);
      await tester.drag(toggle, const Offset(35, 0));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(changes, 2);
      update(() => enabled = false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('开关'));
      await tester.pumpAndSettle();
      expect(changes, 2);
      expect(value, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
