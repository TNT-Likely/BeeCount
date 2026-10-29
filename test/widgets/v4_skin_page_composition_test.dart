import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:beecount/styles/header_skins.dart';
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount/pages/shared/appearance/bindings/page_skin_composition.dart';
import 'package:beecount/pages/shared/appearance/skin_animation_scope.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('两款周年原Painter与线上3.9逐字节一致，不再删除铭文', () {
    final hashes = {
      'skin_common.dart':
          '9bf14bce7b857a53ac84952ce149402499b9e109de616f30ae15b8471734773c',
      'anniversary_skin.dart':
          'ed19fed0335529ee3b5f98363171ebf784d0deb1d27142ee706ba0414f7a66e3',
      'anniv_cake_skin.dart':
          'b9953ee141b3f1d387ff82325ba5305c457b0d12156bdfdc7a2bc5aa0336f059',
    };
    for (final e in hashes.entries) {
      expect(
          sha256
              .convert(
                  File('lib/styles/header_skins/${e.key}').readAsBytesSync())
              .toString(),
          e.value);
    }
  });
  for (final id in ['anniversary', 'anniv_cake']) {
    for (final dark in [false, true]) {
      testWidgets('原画直接输出与有界承载像素相同 $id dark=$dark', (t) async {
        t.view.physicalSize = const Size(398, 208);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final c = ProviderContainer(overrides: [
          skinAnimationEnabledProvider.overrideWith((ref) => false)
        ]);
        addTearDown(c.dispose);
        final skin = headerSkinById(id)!;
        Future<Uint8List> render(Widget child) async {
          final key = GlobalKey();
          await t.pumpWidget(UncontrolledProviderScope(
              container: c,
              child: Theme(
                  data: beeTheme(
                      brightness: dark ? Brightness.dark : Brightness.light),
                  child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: MediaQuery(
                          data: const MediaQueryData(
                              size: Size(398, 208),
                              padding: EdgeInsets.zero,
                              disableAnimations: true),
                          child: RepaintBoundary(key: key, child: child))))));
          await t.pumpAndSettle();
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          return (await t.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final result =
                (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
                    .buffer
                    .asUint8List();
            image.dispose();
            return result;
          }))!;
        }

        final original = await render(ColoredBox(
            color: dark ? Colors.black : skin.boundPrimary!,
            child: SkinAnimationScope(
                child: skin.builder(skin.boundPrimary!, dark))));
        final composed = await render(V4OriginalSkinScene(skin: skin));
        expect(composed, orderedEquals(original), reason: '原画不被改色、降低透明度或删除铭文');
        expect(t.getSize(find.byKey(const ValueKey('v4-original-skin-canvas'))),
            const Size(398, 208));
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });
    }
  }
  for (final width in [320.0, 398.0]) {
    testWidgets('卡片背景槽不改变尺寸与操作命中区域 $width', (t) async {
      t.view.physicalSize = Size(width, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = ProviderContainer(overrides: [
        skinAnimationEnabledProvider.overrideWith((ref) => false)
      ]);
      addTearDown(c.dispose);
      var taps = 0;
      Future<Size> render(Widget? background) async {
        await t.pumpWidget(UncontrolledProviderScope(
            container: c,
            child: MaterialApp(
                theme: beeTheme(),
                home: Scaffold(
                    body: Padding(
                        padding: const EdgeInsets.all(17),
                        child: BeeSummaryCard(
                            title: '2026年 10月',
                            amount: '3,286.50',
                            incomeLabel: '本月收入',
                            income: '12,000.00',
                            expenseLabel: '本月结余',
                            expense: '8,713.50',
                            background: background,
                            onContextTap: () => taps++))))));
        await t.pumpAndSettle();
        return t.getSize(find.byType(BeeSummaryCard));
      }

      final plain = await render(null);
      final scene = await render(V4OriginalSkinScene(
          skin: headerSkinById('anniversary')!, inCard: true));
      expect(scene, plain);
      await t.tap(find.text('2026年 10月'));
      expect(taps, 1);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
