import 'dart:async';
import 'dart:convert';

import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/pages/settings/logs/bindings/log_share_sheet.dart';
import 'package:beecount/services/system/log_export_service.dart';
import 'package:beecount/services/system/logger_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Platform extends LogExportPlatform {
  final shares = <LogExportFile>[];
  final saves = <LogExportFile>[];
  Rect? anchor;
  bool failShare = false;
  bool failSave = false;
  bool saved = false;
  ShareResultStatus result = ShareResultStatus.dismissed;
  Completer<void>? gate;

  @override
  Future<ShareResultStatus> share(
    LogExportFile file, {
    required Rect origin,
    required String subject,
  }) async {
    shares.add(file);
    anchor = origin;
    await gate?.future;
    if (failShare) throw StateError('Synthetic share failure');
    return result;
  }

  @override
  Future<bool> save(LogExportFile file, {String? dialogTitle}) async {
    saves.add(file);
    if (failSave) throw StateError('Synthetic save failure');
    return saved;
  }
}

void main() {
  const privateNote = 'qa-note@example.invalid';
  final l = AppLocalizationsEn();
  late LoggerService logger;
  late _Platform platform;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'app_logs': jsonEncode([
        LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.info,
          platform: LogPlatform.flutter,
          tag: 'App',
          message: privateNote,
        ).toJson(),
      ]),
    });
    prefs = await SharedPreferences.getInstance();
    logger = LoggerService.forTesting(getPreferences: () async => prefs);
    platform = _Platform();
  });

  tearDown(() => logger.disposeForTesting());

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [logExportPlatformProvider.overrideWithValue(platform)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
            body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLogShareSheet(context, logger),
            child: const Text('Open'),
          ),
        )),
      ),
    ));
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'cold preview and file share the same entries and each opening starts in original mode',
      (tester) async {
    final loading = Completer<SharedPreferences>();
    logger = LoggerService.forTesting(getPreferences: () => loading.future);
    await mount(tester);
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text(l.logSharePreparing), findsOneWidget);
    loading.complete(prefs);
    await tester.pumpAndSettle();
    expect(find.text(l.logShareScope(1)), findsOneWidget);
    expect(find.textContaining(privateNote), findsOneWidget);

    logger.info('App', 'arrived after preview');
    await tap(tester, 'log-share-redacted');
    expect(find.textContaining(privateNote), findsNothing);
    expect(find.textContaining('[redacted]'), findsOneWidget);
    await tap(tester, 'log-share-send');
    final redacted = platform.shares.single;
    expect(utf8.decode(redacted.bytes), redacted.text);
    expect(redacted.text, contains('[redacted]'));
    expect(redacted.text, isNot(contains(privateNote)));
    expect(redacted.text, isNot(contains('arrived after preview')));
    expect(find.text(l.logShareTitle), findsNothing);

    platform.result = ShareResultStatus.unavailable;
    await open(tester);
    expect(
        tester
            .widget<ChoiceChip>(
                find.byKey(const ValueKey('log-share-original')))
            .selected,
        isTrue);
    expect(find.text(l.logShareScope(2)), findsOneWidget);
    await tap(tester, 'log-share-send');
    final original = platform.shares.last;
    expect(utf8.decode(original.bytes), contains(privateNote));
    expect(original.text, contains('arrived after preview'));
    expect(find.text(l.logShareFailed), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
      'native failure keeps the selected bytes through save cancellation, errors and retry',
      (tester) async {
    platform.failShare = true;
    await mount(tester);
    await open(tester);
    await tap(tester, 'log-share-redacted');
    await tap(tester, 'log-share-send');
    expect(find.text(l.logShareFailed), findsOneWidget);
    final chosen = platform.shares.single;
    expect(find.text(chosen.fileName), findsOneWidget);

    logger.info('App', 'later entry');
    await tap(tester, 'log-share-save');
    expect(find.text(l.logShareFailed), findsOneWidget);
    platform.failSave = true;
    await tap(tester, 'log-share-save');
    expect(find.text(l.logShareSaveFailed), findsOneWidget);
    platform.failShare = false;
    await tap(tester, 'log-share-send');
    expect(platform.saves, everyElement(same(chosen)));
    expect(platform.shares.last, same(chosen));
    expect(find.text(l.logShareTitle), findsNothing);

    platform.failShare = true;
    platform.failSave = false;
    platform.saved = true;
    await open(tester);
    await tap(tester, 'log-share-send');
    await tap(tester, 'log-share-save');
    expect(platform.saves.last, same(platform.shares.last));
    expect(find.text(l.logShareTitle), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
      'double tap opens one native chooser anchored inside the current window',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    platform.gate = Completer<void>();
    await mount(tester);
    await open(tester);
    final send = find.byKey(const ValueKey('log-share-send'));
    final buttonRect = tester.getRect(send);
    await tester.tap(send);
    await tester.tap(send);
    await tester.pump();
    expect(platform.shares, hasLength(1));
    expect(platform.anchor, buttonRect);
    expect(platform.anchor!.isEmpty, isFalse);
    platform.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text(l.logShareTitle), findsNothing);
  });
}
