import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/styles/header_skins.dart';
import 'package:beecount/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('冻结原皮肤注册表与亮暗预览，生产绘制代码保持', (t) async {
    final output = Directory(Platform.environment['BEECOUNT_SKIN_EXPORT']!);
    output.createSync(recursive: true);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(398, 844);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    final result = <Map<String, Object?>>[];
    final english = await AppLocalizations.delegate.load(const Locale('en'));
    for (final dark in [false, true]) {
      final items = [
        (id: 'none', skin: null),
        for (final skin in kVisibleHeaderSkins) (id: skin.id, skin: skin)
      ];
      for (final item in items) {
        final skin = item.skin,
            primary = skin?.boundPrimary ?? BeeTheme.honeyGold;
        final key = GlobalKey();
        await t.pumpWidget(MaterialApp(
            theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light),
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
                builder: (context) => Scaffold(
                    body: Center(
                        child: RepaintBoundary(
                            key: key,
                            child: SizedBox(
                                width: 320,
                                height: 176,
                                child: TickerMode(
                                    enabled: false,
                                    child: MediaQuery(
                                        data: const MediaQueryData(
                                            size: Size(320, 176)),
                                        child: ColoredBox(
                                            color:
                                                dark ? Colors.black : primary,
                                            child:
                                                skin?.builder(primary, dark) ??
                                                    const SizedBox
                                                        .expand()))))))))));
        await t.pump(const Duration(milliseconds: 20));
        final context = t.element(find.byType(Scaffold));
        final l = AppLocalizations.of(context);
        final bytes = await t.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return data!.buffer.asUint8List();
        });
        File('${output.path}/${item.id}-${dark ? 'dark' : 'light'}.png')
            .writeAsBytesSync(bytes!);
        if (!dark)
          result.add({
            'id': item.id,
            'name': skin?.nameOf(l) ?? l.headerSkinNone,
            'en': skin?.nameOf(english) ?? english.headerSkinNone,
            'debugOnly': item.id == 'example',
            'group': skin?.group.name ?? 'basic',
            'animated': skin?.isAnimated ?? false,
            'fixed': skin?.hasFixedPalette ?? false,
            'badge': skin?.badge,
            'bound': skin?.boundPrimary == null
                ? null
                : skin!.boundPrimary!.value.toRadixString(16)
          });
      }
    }
    File('${output.path}/registry.json').writeAsStringSync(jsonEncode(result));
    expect(result.length, kDebugMode ? 23 : 22,
        reason: '保留原debug专用SVG示例，release仍为22项含纯色');
  });
}
