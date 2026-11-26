/// Regenerate the two platforms' picker assets from the real gallery cards:
/// GEN_WIDGET_PREVIEWS=1 flutter test test/widget/widget_preview_generator_test.dart
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/services/data/seed_service.dart';
import 'package:beecount/theme.dart';
import 'package:beecount/widget/widget_preview.dart';
import 'package:beecount/widget/widget_spec.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final _names = {
  WidgetSpec.glanceSmall: 'glance_small',
  WidgetSpec.glanceMedium: 'glance',
  WidgetSpec.netWorthSmall: 'networth_small',
  WidgetSpec.netWorthMedium: 'networth',
  WidgetSpec.netWorthLarge: 'networth_large',
  WidgetSpec.quickAddSmall: 'quickadd',
  WidgetSpec.quickAddMedium: 'quickadd_medium',
  WidgetSpec.budgetSmall: 'budget',
  WidgetSpec.budgetMedium: 'budget_medium',
  WidgetSpec.recentMedium: 'recent',
  WidgetSpec.recentLarge: 'recent_large',
  WidgetSpec.dashboardLarge: 'dashboard',
  WidgetSpec.consumptionRhythmMedium: 'consumption_rhythm',
  WidgetSpec.beeTrailSmall: 'bee_trail',
};

const _pickerLocales = [
  (Locale('zh'), '', 'PickerHans'),
  (Locale('zh', 'TW'), '-b+zh+Hant', 'PickerHant'),
  (Locale('en'), '-en', 'PickerLatin'),
];
const _androidDir = 'android/app/src/main/res';
const _iosDir = 'ios/BeeCountWidget/Previews';

Future<void> _loadFonts() async {
  var root = File(Platform.resolvedExecutable).parent;
  while (!Directory('${root.path}/material_fonts').existsSync() &&
      root.parent.path != root.path) {
    root = root.parent;
  }
  final fonts = '${root.path}/material_fonts';
  final files = {
    'PickerLatin': [
      for (final w in ['Regular', 'Medium', 'Bold']) '$fonts/Roboto-$w.ttf'
    ],
    'PickerHans': ['/System/Library/Fonts/Hiragino Sans GB.ttc'],
    'PickerHant': ['/System/Library/Fonts/STHeiti Medium.ttc'],
    'MaterialIcons': ['$fonts/MaterialIcons-Regular.otf'],
  };
  for (final entry in files.entries) {
    final loader = FontLoader(entry.key);
    for (final name in entry.value) {
      loader.addFont(File(name).readAsBytes().then(ByteData.sublistView));
    }
    await loader.load();
  }
}

Future<Uint8List> _capture(WidgetTester tester, WidgetSpec spec, Size size,
    AppLocalizations l, String font, bool dark) async {
  final key = GlobalKey();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: DefaultTextStyle(
      style: TextStyle(fontFamily: font),
      child: Center(
          child: RepaintBoundary(
              key: key,
              child: SizedBox.fromSize(
                size: size,
                child: buildWidgetPreview(
                    spec: spec,
                    canvas: size,
                    l: l,
                    dark: dark,
                    themeColor: BeeTheme.honeyGold,
                    redForIncome: false),
              ))),
    ),
  ));
  await tester.pump();
  expect(tester.takeException(), isNull,
      reason: '${spec.imageKey} ${l.localeName} $dark');
  return (await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }))!;
}

void _write(String path, Uint8List png) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(png);
}

void main() {
  final enabled = Platform.environment['GEN_WIDGET_PREVIEWS'] == '1';
  setUpAll(() async {
    if (enabled) {
      await _loadFonts();
      await initializeDateFormatting();
    }
  });

  test('every registered size has a picker image', () {
    expect(_names.keys.toSet(), WidgetSpec.catalog.toSet());
  });

  test('cards use localized seed category names and preserve custom labels',
      () {
    final zh = lookupAppLocalizations(const Locale('zh'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(SeedService.localizedCategoryName('dining', 'expense', zh), '餐饮');
    expect(SeedService.localizedCategoryName('transport', 'expense', en),
        'Transport');
    expect(SeedService.localizedCategoryName('salary', 'income', en), 'Salary');
    expect(SeedService.localizedCategoryName('dining_breakfast', 'expense', en),
        'Breakfast');
    expect(
        SeedService.localizedCategoryName('My_trip', 'expense', zh), 'My_trip');
  });

  test('bundled picker images cover the official locales and both appearances',
      () {
    for (final (locale, qualifier, _) in _pickerLocales) {
      for (final dark in [false, true]) {
        for (final spec in WidgetSpec.catalog) {
          final name = 'widget_preview_${_names[spec]}';
          for (final (android, path) in [
            (
              true,
              '$_androidDir/drawable$qualifier${dark ? '-night' : ''}-nodpi/$name.png'
            ),
            (
              false,
              '$_iosDir/${name}_${locale.toString()}${dark ? '_dark' : ''}.png'
            ),
          ]) {
            final bytes = File(path).readAsBytesSync();
            final header = ByteData.sublistView(bytes);
            final canvas = spec.canvasSize(android: android);
            expect(header.getUint32(0), 0x89504e47, reason: path);
            expect(header.getUint32(16), canvas.width * 3, reason: path);
            expect(header.getUint32(20), canvas.height * 3, reason: path);
          }
        }
      }
    }
  }, skip: enabled);

  testWidgets('regenerate the official Android and WidgetKit picker images',
      (tester) async {
    for (final (locale, qualifier, font) in _pickerLocales) {
      final l = lookupAppLocalizations(locale);
      for (final dark in [false, true]) {
        final folder = 'drawable$qualifier${dark ? '-night' : ''}-nodpi';
        for (final spec in WidgetSpec.catalog) {
          final basename = 'widget_preview_${_names[spec]!}';
          final android = spec.canvasSize(android: true);
          final ios = spec.canvasSize(android: false);
          final png = await _capture(tester, spec, android, l, font, dark);
          _write('$_androidDir/$folder/$basename.png', png);
          final iosPng = ios == android
              ? png
              : await _capture(tester, spec, ios, l, font, dark);
          _write(
              '$_iosDir/${basename}_${locale.toString()}${dark ? '_dark' : ''}.png',
              iosPng);
        }
      }
    }
  }, skip: !enabled, timeout: const Timeout(Duration(minutes: 5)));
}
