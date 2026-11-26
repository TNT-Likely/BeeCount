import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
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
    // to this test. Glance reports money changes, Quick Add shows the accent.
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
              WidgetSpec.quickAddSmall,
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
      Locale('en'),
      Locale('zh', 'TW'),
    ];
    binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    final first = await repo.createLedger(name: 'Sample A');
    final second = await repo.createLedger(name: 'Sample B', currency: 'USD');
    // Exercise built-in category keys and user-entered names in the same PNG.
    final food = await repo.createCategory(
        name: 'dining', kind: 'expense', icon: 'restaurant');
    final account = await repo.createAccount(
        ledgerId: first, name: 'Wallet', initialBalance: 8000);
    await repo.addTransaction(
        ledgerId: first,
        type: 'expense',
        amount: 32.50,
        categoryId: food,
        accountId: account,
        happenedAt: DateTime.now());
    final now = DateTime.now();
    final categories = [
      ('transport', 'directions_car', 18.0),
      ('shopping', 'shopping_cart', 29.50),
      ('Cinema', 'movie', 24.0),
      ('Health', 'local_hospital', 12.50),
      ('Home', 'home', 19.0),
      ('Phone', 'phone', 16.70),
    ];
    for (final (i, item) in categories.indexed) {
      final category = await repo.createCategory(
          name: item.$1, kind: 'expense', icon: item.$2);
      await repo.addTransaction(
          ledgerId: first,
          type: 'expense',
          amount: item.$3,
          categoryId: category,
          accountId: account,
          happenedAt: now.subtract(Duration(days: i + 1)));
      if (i < 2) {
        await repo.createBudget(
            ledgerId: first,
            type: 'category',
            categoryId: category,
            amount: 50 + i * 10);
      }
    }
    final salary = await repo.createCategory(
        name: 'salary', kind: 'income', icon: 'payments');
    await repo.addTransaction(
        ledgerId: first,
        type: 'income',
        amount: 3200,
        categoryId: salary,
        accountId: account,
        happenedAt: now.subtract(const Duration(days: 2)));
    await repo.createAccount(
        ledgerId: first,
        name: 'Travel card',
        type: 'credit_card',
        initialBalance: -320);
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
    const officialLocales = ['zh', 'zh-TW', 'en'];
    final officialVariants = {
      for (final lang in officialLocales)
        for (final tone in Brightness.values) '$lang.${tone.name}'
    };
    final evidencePath =
        Platform.environment['BEECOUNT_WIDGET_APPEARANCE_EVIDENCE'];
    final evidence = evidencePath == null
        ? null
        : await Directory(evidencePath).create(recursive: true);
    final watch = Stopwatch()..start();
    await refresh(warmUp: true);
    final warmUpMs = watch.elapsedMilliseconds;
    var verifiedPngs = 0;
    for (final spec in WidgetSpec.catalog) {
      expect(storage, contains('${spec.imageKey}.appearance.v1'),
          reason: '${spec.imageKey} was not published');
      final variants = images(spec);
      expect(variants.keys, containsAll(officialVariants),
          reason: spec.imageKey);
      expect(storage[spec.imageKey], variants['en.light']);
      expect(manifest(spec)['fallback'], storage[spec.imageKey]);
      expect(manifest(spec)['locale'], 'system');
      expect(manifest(spec)['theme'], 'system');
      final officialPaths = {for (final key in officialVariants) variants[key]};
      expect(officialPaths, hasLength(officialVariants.length));
      for (final key in officialVariants) {
        final file = File(variants[key]!);
        expect(file.parent.path, '${directory.path}/home_widget');
        final bytes = await file.readAsBytes();
        expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        final header = ByteData.sublistView(bytes);
        expect(header.getUint32(16), (spec.logicalSize.width * 3).round());
        expect(header.getUint32(20), (spec.logicalSize.height * 3).round());
        if (evidence != null) {
          await file.copy('${evidence.path}/${spec.imageKey}.$key.png');
        }
        verifiedPngs++;
      }
    }
    // System mode warms all supported locales; inspect/export only official ones.
    expect(verifiedPngs, WidgetSpec.catalog.length * officialVariants.length);
    final initialCount = pngWrites;
    expect(
        initialCount,
        WidgetSpec.catalog.length *
            AppLocalizations.supportedLocales.length *
            Brightness.values.length);
    final quickAdd = images(WidgetSpec.quickAddSmall),
        medium = images(WidgetSpec.glanceMedium);
    final recent = images(WidgetSpec.recentMedium);
    expect(await _pngHash(quickAdd['en.light']!),
        isNot(await _pngHash(quickAdd['zh-TW.light']!)));
    expect(await _pngHash(recent['en.light']!),
        isNot(await _pngHash(recent['zh.light']!)));
    expect(await _pngHash(medium['en.light']!),
        isNot(await _pngHash(medium['zh-TW.light']!)));
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

    const pinned = Locale('zh', 'TW');
    await refresh(locale: pinned, theme: ThemeMode.dark);
    expect(pngWrites, initialCount);
    expect(notified.length, greaterThan(afterWarmUp));
    expect(storage['widgetImage'], medium['zh-TW.dark']);
    expect(manifest(WidgetSpec.glanceMedium)['locale'], 'zh-TW');
    expect(manifest(WidgetSpec.glanceMedium)['theme'], 'dark');

    await refresh(locale: pinned, theme: ThemeMode.dark, accent: blue);
    final accentHash =
        await _pngHash(storage[WidgetSpec.quickAddSmall.imageKey]!);
    expect(accentHash, isNot(await _pngHash(quickAdd['zh-TW.dark']!)));
    expect(images(WidgetSpec.quickAddSmall).keys, ['zh-TW.dark']);
    expect(pngWrites - initialCount, inInclusiveRange(1, 2));
    final beforeExpense = pngWrites;
    final previousGlance = await _pngHash(storage['widgetImage']!);

    await repo.addTransaction(
        ledgerId: first,
        type: 'expense',
        amount: 5400,
        categoryId: food,
        accountId: account,
        happenedAt: DateTime.now());
    await refresh(locale: pinned, theme: ThemeMode.dark, accent: blue);
    expect(await _pngHash(storage['widgetImage']!), isNot(previousGlance));
    expect(pngWrites - beforeExpense, inInclusiveRange(1, 2));

    final previous = {
      for (final spec in WidgetSpec.catalog) spec: manifest(spec)
    };
    final beforeSwitch = pngWrites;
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
      expect(images(spec).keys, ['zh-TW.dark']);
      final oldPaths = previous[spec]!['images'] as Map;
      expect(officialVariants.map((key) => oldPaths[key]),
          isNot(contains(updated['fallback'])));
      expect(storage[spec.imageKey], updated['fallback']);
    }
    expect(await _pngHash(storage['widgetImage']!), isNot(firstLedgerHash));
    expect(pngWrites, beforeSwitch + WidgetSpec.catalog.length);
    if (evidence != null) {
      await File('${evidence.path}/result.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert({
        'catalogSizes': WidgetSpec.catalog.length,
        'officialLocales': officialLocales,
        'officialVariantsPerSize': officialVariants.length,
        'officialPngsVerified': verifiedPngs,
        'firstWarmUpPngWrites': initialCount,
        'firstWarmUpMs': warmUpMs,
        'unchangedWarmUpPngs': 0,
        'unchangedWarmUpMs': cachedMs,
        'pinnedSettingsPngs': 0,
        'pinnedAppearance': 'zh-TW.dark',
        'newAccentPngs': beforeExpense - initialCount,
        'newExpensePngs': beforeSwitch - beforeExpense,
        'ledgerSwitchPngs': pngWrites - beforeSwitch,
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
