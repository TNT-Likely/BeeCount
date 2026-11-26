import 'dart:convert';
import 'dart:io';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/widget/widget_appearance.dart';
import 'package:beecount/widget/widget_data_service.dart';
import 'package:beecount/widget/widget_render_content.dart';
import 'package:beecount/widget/widget_spec.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

WidgetAppearance appearance(
        {Locale? locale, ThemeMode theme = ThemeMode.system}) =>
    WidgetAppearance(
        explicitLocale: locale,
        theme: theme,
        systemLocales: const [Locale('fr'), Locale('zh', 'TW')],
        systemBrightness: Brightness.dark);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'system language uses preference order, Chinese script before region, then English fallback',
      () {
    expect(
        resolveWidgetLocale(
            const [Locale('fr'), Locale('zh', 'TW'), Locale('en')]),
        const Locale('zh', 'TW'));
    expect(resolveWidgetLocale(const [Locale('zh', 'HK')]),
        const Locale('zh', 'TW'));
    expect(
        resolveWidgetLocale(const [
          Locale.fromSubtags(
              languageCode: 'zh', scriptCode: 'Hans', countryCode: 'TW')
        ]),
        const Locale('zh'));
    expect(
        resolveWidgetLocale(const [
          Locale.fromSubtags(
              languageCode: 'zh', scriptCode: 'Hant', countryCode: 'CN')
        ]),
        const Locale('zh', 'TW'));
    expect(resolveWidgetLocale(const [Locale('de')]), const Locale('en'));
    expect(appearance().variants.first,
        (locale: const Locale('zh', 'TW'), brightness: Brightness.dark));
    final supportedCount = AppLocalizations.supportedLocales.length;
    expect(appearance().variants.toSet(), hasLength(supportedCount * 2));
    expect(appearance(theme: ThemeMode.light).variants.toSet(),
        hasLength(supportedCount));
    expect(appearance(locale: const Locale('zh', 'TW')).variants.toSet(),
        hasLength(2));
  });

  const channel = MethodChannel('home_widget');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final prefs = <String, String>{};
  late Directory directory;
  setUp(() async {
    prefs.clear();
    directory =
        await Directory.systemTemp.createTemp('beecount-widget-cache-test-');
    messenger.setMockMethodCallHandler(channel, (call) async {
      final id = call.arguments['id'] as String;
      if (call.method == 'getWidgetData') return prefs[id];
      if (call.method == 'saveWidgetData') {
        prefs[id] = call.arguments['data'] as String;
        return true;
      }
      throw MissingPluginException();
    });
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });

  const imageKey = 'widgetImage';
  const manifestKey = '$imageKey.appearance.v1';
  Future<String> write(String key, String contents) async =>
      (await File('${directory.path}/$key.png').writeAsString(contents)).path;

  test('an existing 3.x card upgrades once on the same app build', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LocalRepository(db);
    final ledger =
        await repo.createLedger(name: 'Widget upgrade', currency: 'CNY');
    final day = DateTime(2026, 7, 20);
    final spec = WidgetSpec.glanceMedium;
    final size = spec.logicalSize;
    const version = '4.0.2+7';
    // The pre-upgrade fingerprint for an empty CNY ledger. Keep this fixture
    // independent of the current serializer so a layout-only change is tested.
    final old = sha256
        .convert(utf8.encode(jsonEncode([
          version,
          'widgetImage',
          ledger,
          size.width,
          size.height,
          [1.0, 0.0, 0.0, 0.0],
          [1.0, 1.0, 1.0, 1.0],
          false,
          ['CNY', 7, 0.0, 0.0, 0.0, 0.0],
        ])))
        .toString();
    final current = await prepareWidgetContent(
        spec: spec,
        batch: WidgetGatherBatch(
            repository: repo, ledgerId: ledger, baseCurrency: 'CNY'),
        size: size,
        lightColor: Colors.black,
        darkColor: Colors.white,
        redForIncome: false,
        appVersion: version,
        today: day);
    expect(current.fingerprint, isNot(old));
    var renders = 0;
    Future<bool> update(String hash) => cacheWidgetAppearance(
        imageKey: spec.imageKey,
        fingerprint: hash,
        appearance:
            appearance(locale: const Locale('en'), theme: ThemeMode.light),
        render: (key, _) async {
          renders++;
          return (path: await write(key, hash), complete: true);
        });
    await update(old);
    final priorPath = prefs[imageKey]!;
    expect(await update(current.fingerprint), isTrue);
    expect(prefs[imageKey], isNot(priorPath));
    expect(await File(prefs[imageKey]!).readAsString(), current.fingerprint);
    expect(await update(current.fingerprint), isFalse);
    expect(renders, 2);
  });

  test(
      'an interrupted data change leaves the published images intact; retry uses bounded slots',
      () async {
    Future<bool> update(String data, {bool interrupt = false}) =>
        cacheWidgetAppearance(
            imageKey: imageKey,
            fingerprint: data,
            appearance: appearance(locale: const Locale('en')),
            render: (key, variant) async {
              if (interrupt && variant.brightness == Brightness.light) {
                throw const FileSystemException('out of space');
              }
              return (path: await write(key, data), complete: true);
            });

    expect(await update('ledger-A'), isTrue);
    final original = prefs[manifestKey]!;
    final oldPaths = List<String>.from(jsonDecode(original)['images'].values);
    await expectLater(update('ledger-B', interrupt: true),
        throwsA(isA<FileSystemException>()));
    expect(prefs[manifestKey], original);
    for (final path in oldPaths) {
      expect(await File(path).readAsString(), 'ledger-A');
    }
    expect(await update('ledger-B'), isTrue);
    final paths =
        List<String>.from(jsonDecode(prefs[manifestKey]!)['images'].values);
    expect(oldPaths.toSet().intersection(paths.toSet()), isEmpty);
    for (final path in paths) {
      expect(await File(path).readAsString(), 'ledger-B');
    }
    await update('ledger-C');
    expect(List<String>.from(jsonDecode(prefs[manifestKey]!)['images'].values),
        oldPaths);
    expect(await directory.list().length, 4);
  });

  test('a missing older language image cannot hide the current fallback card',
      () async {
    Future<void> update(Locale locale, bool complete) async {
      await cacheWidgetAppearance(
        imageKey: imageKey,
        fingerprint: 'same-ledger',
        appearance: appearance(locale: locale, theme: ThemeMode.light),
        render: (key, _) async =>
            (path: await write(key, 'image'), complete: complete),
      );
    }

    await update(const Locale('en'), true);
    await File(prefs[imageKey]!).delete();
    await update(const Locale('zh', 'TW'), false);
    final fallback = jsonDecode(prefs[manifestKey]!)['fallback'] as String;
    expect(await File(fallback).exists(), isTrue);
    expect(fallback, endsWith('zh-TW.light.png'));
  });

  test(
      'failed render is retried, truncated PNG repaired, cached preference changes require no render',
      () async {
    prefs[manifestKey] = '{';
    var complete = false;
    var renders = 0;
    Future<bool> update(ThemeMode theme) => cacheWidgetAppearance(
        imageKey: imageKey,
        fingerprint: 'data',
        appearance: appearance(locale: const Locale('zh', 'TW'), theme: theme),
        render: (key, variant) async {
          renders++;
          return (path: await write(key, 'image'), complete: complete);
        });
    await update(ThemeMode.dark);
    expect(jsonDecode(prefs[manifestKey]!)['images'], isEmpty);
    expect(await File(prefs[imageKey]!).exists(), isTrue);
    complete = true;
    await update(ThemeMode.system);
    expect(jsonDecode(prefs[manifestKey]!)['images'].keys,
        unorderedEquals(['zh-TW.light', 'zh-TW.dark']));
    expect(renders, 3);
    expect(await update(ThemeMode.light), isTrue);
    expect(renders, 3);
    expect(await update(ThemeMode.light), isFalse);
    await File(prefs[imageKey]!).writeAsBytes([]);
    expect(await update(ThemeMode.light), isTrue);
    expect(renders, 4);
    expect(await File(prefs[imageKey]!).length(), greaterThan(0));
  });
}
