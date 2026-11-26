import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/pages/settings/logs/bindings/log_share_sheet.dart';
import 'package:beecount/services/system/log_export_service.dart';
import 'package:beecount/services/system/logger_service.dart';
import 'package:beecount_ui/beecount_ui.dart';
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

  Future<void> mount(WidgetTester tester,
      {Brightness brightness = Brightness.light, double textScale = 1}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [logExportPlatformProvider.overrideWithValue(platform)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: beeTheme(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
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
      'cold preview and original attachment share one snapshot until reopened',
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
    expect(find.text(l.logShareOriginalHint), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    final preview = find.byKey(const ValueKey('log-share-preview-lines'));
    final firstRecord = find.textContaining(privateNote);
    expect(
        tester.getRect(preview).overlaps(tester.getRect(firstRecord)), isTrue);
    await tester.drag(preview, const Offset(0, 200));
    await tester.pumpAndSettle();
    final header = find.text('=== BeeCount 日志导出 ===');
    expect(tester.getRect(preview).overlaps(tester.getRect(header)), isTrue);

    logger.info('App', 'arrived after preview');
    await tap(tester, 'log-share-send');
    final attachment = platform.shares.single;
    expect(utf8.decode(attachment.bytes), attachment.text);
    expect(attachment.text, contains(privateNote));
    expect(attachment.text, isNot(contains('arrived after preview')));
    expect(find.text(l.logShareTitle), findsNothing);

    platform.result = ShareResultStatus.unavailable;
    await open(tester);
    expect(find.text(l.logShareScope(2)), findsOneWidget);
    await tap(tester, 'log-share-send');
    final original = platform.shares.last;
    expect(utf8.decode(original.bytes), contains(privateNote));
    expect(original.text, contains('arrived after preview'));
    expect(find.text(l.logShareFailed), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
      'native failure keeps the original bytes through save cancellation, errors and retry',
      (tester) async {
    platform.failShare = true;
    await mount(tester);
    await open(tester);
    await tap(tester, 'log-share-send');
    expect(find.text(l.logShareFailed), findsOneWidget);
    final chosen = platform.shares.single;
    expect(find.text(chosen.fileName), findsOneWidget);
    expect(utf8.decode(chosen.bytes), contains(privateNote));

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

  for (final brightness in Brightness.values) {
    testWidgets(
        'neutral preview card collapses on a narrow screen with large text (${brightness.name})',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester, brightness: brightness, textScale: 1.6);
      await open(tester);

      final card = find.byKey(const ValueKey('log-share-preview-card'));
      final header = find.byKey(const ValueKey('log-share-preview-toggle'));
      final lines = find.byKey(const ValueKey('log-share-preview-lines'));
      final send = find.byKey(const ValueKey('log-share-send'));
      final context = tester.element(card);
      final cards = BeeCardTheme.of(context);
      final ink = Theme.of(context).colorScheme.onSurface;
      final material = tester.widget<Material>(card);
      expect(material.color, cards.overlay);
      final outline = material.shape! as RoundedRectangleBorder;
      expect(outline.side.color, cards.divider);
      expect(outline.borderRadius, BorderRadius.circular(13));
      expect(
          tester.widget<Text>(find.text(l.logSharePreview)).style!.color, ink);
      final fileIcon = find.descendant(
          of: header,
          matching: find.byWidgetPredicate(
              (w) => w is BeeLineIcon && w.name == 'FileText'));
      expect(tester.widget<BeeLineIcon>(fileIcon).color, ink);
      expect(tester.getSize(header).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(card).width, tester.getSize(send).width);
      expect(tester.widget<BeeButton>(send).kind, BeeButtonKind.primary);
      expect(tester.getSemantics(header).hasFlag(ui.SemanticsFlag.isExpanded),
          isTrue);
      expect(
          tester
              .getRect(lines)
              .overlaps(tester.getRect(find.textContaining(privateNote))),
          isTrue);

      // The trailing end of the row is also a toggle target.
      final edge = tester.getTopRight(header) +
          Offset(-8, tester.getSize(header).height / 2);
      await tester.tapAt(edge);
      await tester.pumpAndSettle();
      expect(lines, findsNothing);
      expect(tester.getSemantics(header).hasFlag(ui.SemanticsFlag.isExpanded),
          isFalse);
      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(lines, findsOneWidget);
      await tester.ensureVisible(send);
      await tap(tester, 'log-share-send');
      expect(platform.shares.single.text, contains(privateNote));
      expect(tester.takeException(), isNull);
    });
  }

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
