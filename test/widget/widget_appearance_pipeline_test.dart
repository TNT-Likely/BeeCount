import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/widget/widget_manager.dart';
import 'package:beecount/widget/widget_spec.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String> _pngHash(String path) async =>
    sha256.convert(await File(path).readAsBytes()).toString();

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  const widgetChannel = MethodChannel('home_widget');
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  test(
      'renders locale and theme snapshots from the ledger and reuses unchanged PNGs',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('beecount-widget-appearance-');
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    final repo = LocalRepository(db);
    final storage = <String, String>{};
    final notified = <String>[];
    var pngWrites = 0;
    addTearDown(() async {
      messenger.setMockMethodCallHandler(widgetChannel, null);
      messenger.setMockMethodCallHandler(pathChannel, null);
      binding.platformDispatcher.clearLocalesTestValue();
      binding.platformDispatcher.clearPlatformBrightnessTestValue();
      await db.close();
      await directory.delete(recursive: true);
    });

    // Keep the database, shared store and real home_widget PNG writer private
    // to this test. The only installed family is Glance, in both sizes.
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'Widget QA',
        packageName: 'widget.qa',
        version: '4.0.0',
        buildNumber: '1',
        buildSignature: '');
    messenger.setMockMethodCallHandler(pathChannel, (call) async {
      expect(call.method, 'getApplicationSupportDirectory');
      return directory.path;
    });
    messenger.setMockMethodCallHandler(widgetChannel, (call) async {
      switch (call.method) {
        case 'getInstalledWidgets':
          return [
            for (final spec in [
              WidgetSpec.glanceSmall,
              WidgetSpec.glanceMedium
            ])
              {'kind': spec.iosKind, 'family': spec.iosFamily},
          ];
        case 'getWidgetData':
          return storage[call.arguments['id']];
        case 'saveWidgetData':
          final key = call.arguments['id'] as String;
          final value = call.arguments['data'] as String;
          if (value.endsWith('/$key.png')) pngWrites++;
          storage[key] = value;
          return true;
        case 'updateWidget':
          notified.add(call.arguments['qualifiedAndroidName'] as String? ??
              call.arguments['ios'] as String);
          return true;
        default:
          throw UnsupportedError(call.method);
      }
    });

    binding.platformDispatcher.localesTestValue = const [
      Locale('fr'),
      Locale('en')
    ];
    binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    final first = await repo.createLedger(name: 'Sample A');
    final second = await repo.createLedger(name: 'Sample B', currency: 'USD');
    final food = await repo.createCategory(
        name: 'Lunch', kind: 'expense', icon: 'restaurant');
    final account = await repo.createAccount(
        ledgerId: first, name: 'Wallet', initialBalance: 8000);
    await repo.addTransaction(
        ledgerId: first,
        type: 'expense',
        amount: 32.50,
        categoryId: food,
        accountId: account,
        happenedAt: DateTime.now());
    await repo.createBudget(ledgerId: first, type: 'total', amount: 600);
    await repo.addTransaction(
        ledgerId: second,
        type: 'income',
        amount: 75,
        happenedAt: DateTime.now());

    const gold = Color(0xfff8c91c), blue = Color(0xff295fd7);
    Future<void> refresh(
            {Locale? locale,
            ThemeMode theme = ThemeMode.system,
            Color accent = gold,
            int? ledger,
            bool warmUp = false}) =>
        WidgetManager().updateAllWidgetsLocalized(repo, ledger ?? first, accent,
            explicitLocale: locale, themeMode: theme, warmUpAllSpecs: warmUp);
    Map<String, dynamic> manifest(WidgetSpec s) =>
        jsonDecode(storage['${s.imageKey}.appearance.v1']!)
            as Map<String, dynamic>;
    Map<String, String> images(WidgetSpec s) =>
        Map<String, String>.from(manifest(s)['images'] as Map);
    const locales = ['en', 'zh', 'zh-TW', 'ko', 'ru'];
    final variantKeys = {
      for (final lang in locales)
        for (final tone in ['light', 'dark']) '$lang.$tone'
    };
    final evidencePath =
        Platform.environment['BEECOUNT_WIDGET_APPEARANCE_EVIDENCE'];
    final evidence = evidencePath == null
        ? null
        : await Directory(evidencePath).create(recursive: true);
    final watch = Stopwatch()..start();
    await refresh(warmUp: true);
    final warmUpMs = watch.elapsedMilliseconds;

    for (final spec in WidgetSpec.catalog) {
      expect(storage, contains('${spec.imageKey}.appearance.v1'),
          reason: '${spec.imageKey} was not published');
      final variants = images(spec);
      expect(variants.keys.toSet(), variantKeys, reason: spec.imageKey);
      expect(storage[spec.imageKey], variants['en.light']);
      expect(manifest(spec)['fallback'], storage[spec.imageKey]);
      expect(manifest(spec)['locale'], 'system');
      expect(manifest(spec)['theme'], 'system');
      expect(variants.values.toSet(), hasLength(variantKeys.length));
      for (final entry in variants.entries) {
        final file = File(entry.value);
        expect(file.parent.path, '${directory.path}/home_widget');
        final bytes = await file.readAsBytes();
        expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        final header = ByteData.sublistView(bytes);
        expect(header.getUint32(16), (spec.logicalSize.width * 3).round());
        expect(header.getUint32(20), (spec.logicalSize.height * 3).round());
        final exportSample = spec == WidgetSpec.glanceMedium ||
            (spec == WidgetSpec.netWorthMedium &&
                const {'en.light', 'ru.light'}.contains(entry.key)) ||
            (const [WidgetSpec.netWorthLarge, WidgetSpec.beeTrailSmall]
                    .contains(spec) &&
                const {'en.light', 'zh.dark'}.contains(entry.key));
        if (evidence != null && exportSample) {
          await file.copy('${evidence.path}/${spec.imageKey}.${entry.key}.png');
        }
      }
    }
    final initialCount = WidgetSpec.catalog.length * variantKeys.length;
    expect(pngWrites, initialCount);
    final small = images(WidgetSpec.glanceSmall),
        medium = images(WidgetSpec.glanceMedium);
    expect(await _pngHash(medium['en.light']!),
        isNot(await _pngHash(medium['ru.light']!)));
    expect(await _pngHash(medium['en.light']!),
        isNot(await _pngHash(medium['zh.light']!)));
    expect(await _pngHash(medium['en.light']!),
        isNot(await _pngHash(medium['en.dark']!)));
    final light = await _topColor(medium['en.light']!),
        dark = await _topColor(medium['en.dark']!);
    expect(light.computeLuminance(), greaterThan(.8));
    expect(dark.computeLuminance(), lessThan(.15));
    expect(storage['widgetImage'], medium['en.light']);
    final notifyCount = notified.length;
    expect(notifyCount, greaterThan(0));

    watch.reset();
    await refresh(warmUp: true);
    final cachedMs = watch.elapsedMilliseconds;
    expect(pngWrites, initialCount);
    final afterWarmUp = notified.length;
    await refresh();
    expect(pngWrites, initialCount);
    expect(notified, hasLength(afterWarmUp));

    const pinned = Locale('ru');
    await refresh(locale: pinned, theme: ThemeMode.dark);
    expect(pngWrites, initialCount);
    expect(notified.length, greaterThan(afterWarmUp));
    expect(storage['widgetImage'], medium['ru.dark']);
    expect(manifest(WidgetSpec.glanceMedium)['locale'], 'ru');
    expect(manifest(WidgetSpec.glanceMedium)['theme'], 'dark');

    await refresh(locale: pinned, theme: ThemeMode.dark, accent: blue);
    final accentHash =
        await _pngHash(storage[WidgetSpec.glanceSmall.imageKey]!);
    expect(accentHash, isNot(await _pngHash(small['ru.dark']!)));
    expect(images(WidgetSpec.glanceSmall).keys, ['ru.dark']);
    expect(pngWrites, initialCount + 2);

    await repo.addTransaction(
        ledgerId: first,
        type: 'expense',
        amount: 5400,
        categoryId: food,
        accountId: account,
        happenedAt: DateTime.now());
    await refresh(locale: pinned, theme: ThemeMode.dark, accent: blue);
    expect(await _pngHash(storage[WidgetSpec.glanceSmall.imageKey]!),
        isNot(accentHash));
    expect(pngWrites, initialCount + 4);

    final previous = {
      for (final spec in WidgetSpec.catalog) spec: manifest(spec)
    };
    final firstLedgerHash = await _pngHash(storage['widgetImage']!);
    await refresh(
        locale: pinned,
        theme: ThemeMode.dark,
        accent: blue,
        ledger: second,
        warmUp: true);
    for (final spec in WidgetSpec.catalog) {
      final updated = manifest(spec);
      expect(updated['fingerprint'], isNot(previous[spec]!['fingerprint']));
      expect(images(spec).keys, ['ru.dark']);
      expect((previous[spec]!['images'] as Map).values,
          isNot(contains(updated['fallback'])));
      expect(storage[spec.imageKey], updated['fallback']);
    }
    expect(await _pngHash(storage['widgetImage']!), isNot(firstLedgerHash));
    expect(pngWrites, initialCount + 4 + WidgetSpec.catalog.length);
    if (evidence != null) {
      await File('${evidence.path}/result.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert({
        'catalogSizes': WidgetSpec.catalog.length,
        'systemVariantsPerSize': variantKeys.length,
        'firstWarmUpPngs': initialCount,
        'firstWarmUpMs': warmUpMs,
        'unchangedWarmUpPngs': 0,
        'unchangedWarmUpMs': cachedMs,
        'pinnedSettingsPngs': 0,
        'totalPngWrites': pngWrites,
      }));
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

/// Sample the solid card background at the top centre, clear of rounded corners.
Future<Color> _topColor(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  final image = (await codec.getNextFrame()).image;
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final offset = (image.width + image.width ~/ 2) * 4;
    return Color.fromARGB(data.getUint8(offset + 3), data.getUint8(offset),
        data.getUint8(offset + 1), data.getUint8(offset + 2));
  } finally {
    image.dispose();
    codec.dispose();
  }
}
