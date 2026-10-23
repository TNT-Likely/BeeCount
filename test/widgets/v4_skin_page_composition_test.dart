import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:beecount/styles/header_skins.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final id in ['anniversary', 'anniv_cake']) {
    testWidgets('整页 $id 只移除会与标题重叠的铭文，旧头部和其余画面保留', (tester) async {
      tester.view.physicalSize = const Size(398, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final skin = headerSkinById(id)!;
      expect(skin.pageBuilder, isNotNull);
      Future<Uint8List> render(Widget child) async {
        final key = GlobalKey();
        await tester.pumpWidget(Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
                data: const MediaQueryData(
                    size: Size(398, 844),
                    padding: EdgeInsets.only(top: 24),
                    disableAnimations: true),
                child: RepaintBoundary(
                    key: key,
                    child: ColoredBox(color: Colors.white, child: child)))));
        await tester.pumpAndSettle();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        return (await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes =
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
                  .buffer
                  .asUint8List();
          image.dispose();
          return bytes;
        }))!;
      }

      final header = await render(skin.builder(const Color(0xfff8c91c), false));
      final page =
          await render(skin.pageBuilder!(const Color(0xfff8c91c), false));
      expect(header.length, 398 * 844 * 4);
      expect(page.length, header.length);
      var changedInTitleBand = 0, changedOutside = 0;
      for (var y = 0; y < 844; y++) {
        for (var x = 0; x < 398; x++) {
          final i = (y * 398 + x) * 4;
          if (header[i] == page[i] &&
              header[i + 1] == page[i + 1] &&
              header[i + 2] == page[i + 2]) {
            continue;
          }
          if (x < 200 && y >= 40 && y <= 90) {
            changedInTitleBand++;
          } else {
            changedOutside++;
          }
        }
      }
      expect(changedInTitleBand, greaterThan(10),
          reason:
              'header inscription must remain in the original header composition');
      expect(changedOutside, 0,
          reason:
              'stars, ribbons, cake and original palette must remain unchanged');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
