import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/pages/report/share_card_page.dart';
import 'package:beecount/presentation/v4/bindings/share_card_controls.dart';
import 'package:beecount/presentation/v4/bindings/share_card_platform.dart';
import 'package:beecount/presentation/v4/bindings/share_card_renderer.dart';
import 'package:beecount/presentation/v4/bindings/share_card_preview.dart';
import 'package:beecount/presentation/v4/gallery/share_card_sample.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/export/share_poster_service.dart';
import 'package:beecount/services/export/share_poster_types.dart';
import 'package:beecount/widgets/posters/year_summary_poster.dart';
import 'package:beecount/widgets/posters/user_profile_poster.dart';
import 'package:beecount/widgets/posters/app_promo_poster.dart';
import 'package:beecount/widgets/posters/month_summary_poster.dart';
import 'package:beecount_business_ui/share_card.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';

final _png = File('assets/v4_gallery/attachment-payment.png').readAsBytesSync();

class _Renderer extends ShareCardRenderer {
  final calls = <(PosterType, bool, int, int?, int?)>[];
  Completer<Uint8List?>? gate;
  bool fail = false;
  @override
  Future<Uint8List?> generate(BuildContext context, WidgetRef ref,
      {required PosterType type,
      required bool hideIncome,
      required int ledgerId,
      int? year,
      int? month}) async {
    calls.add((type, hideIncome, ledgerId, year, month));
    if (gate != null) return gate!.future;
    if (fail) throw StateError('QA generation failure');
    return _png;
  }
}

class _CaptureRenderer extends ShareCardRenderer {
  _CaptureRenderer({this.ratio = .25});
  final double ratio;
  bool started = false;
  Uint8List? bytes;
  @override
  Future<Uint8List?> capture(BuildContext context, Widget poster,
      {double pixelRatio = 3}) async {
    started = true;
    bytes = await super.capture(context, poster, pixelRatio: ratio);
    return bytes;
  }
}

class _Platform extends ShareCardPlatform {
  int saves = 0, shares = 0;
  SavePosterResult result = SavePosterResult.failed;
  ShareResultStatus status = ShareResultStatus.dismissed;
  Completer<void>? gate;
  bool fail = false;
  Rect? anchor;
  @override
  Future<SavePosterResult> save(Uint8List bytes) async {
    saves++;
    await gate?.future;
    if (fail) throw StateError('QA save failed');
    return result;
  }

  @override
  Future<ShareResultStatus?> share(Uint8List bytes, Rect anchor) async {
    shares++;
    this.anchor = anchor;
    await gate?.future;
    if (fail) throw StateError('QA share failed');
    return status;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late LocalRepository repo;
  late _Renderer renderer;
  late _Platform platform;
  final l = AppLocalizationsEn();
  bool previewFont = false;
  setUpAll(() async {
    if (Platform.environment['BEE_SHARE_CARD_EVIDENCE_FONTS'] != 'true') return;
    final font = File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('ShareCardPreview');
      loader
          .addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
      previewFont = true;
    }
    final icons =
        File('build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons');
      loader
          .addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
      await loader.load();
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    renderer = _Renderer();
    platform = _Platform();
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'QA share ledger','CNY')");
    await db.customStatement(
        "INSERT INTO categories(id,name,kind) VALUES(1,'QA Food','expense'),(2,'QA Salary','income')");
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 310,
        categoryId: 1,
        happenedAt: DateTime(2026, 10, 20));
    await repo.addTransaction(
        ledgerId: 1,
        type: 'income',
        amount: 620,
        categoryId: 2,
        happenedAt: DateTime(2026, 10, 20));
  });
  tearDown(() => db.close());
  Future<void> host(WidgetTester t, Widget child,
      {ShareCardRenderer? useRenderer,
      double scale = 1,
      Brightness brightness = Brightness.light,
      Locale locale = const Locale('en'),
      int ledger = 1}) async {
    await t.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo),
          currentLedgerIdProvider.overrideWith((ref) => ledger),
          shareCardRendererProvider.overrideWithValue(useRenderer ?? renderer),
          shareCardPlatformProvider.overrideWithValue(platform),
        ],
        child: MaterialApp(
            theme: previewFont
                ? beeTheme(brightness: brightness).copyWith(
                    textTheme: beeTheme(brightness: brightness)
                        .textTheme
                        .apply(fontFamily: 'ShareCardPreview'))
                : beeTheme(brightness: brightness),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, body) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: body!),
            home: Scaffold(body: child))));
    await t.pump();
  }

  void check(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (t) async {
      try {
        await body(t);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
      }
    });
  }

  check('about recommend app request reaches app poster without a ledger',
      (t) async {
    await host(t, const ShareCardDialog(type: 'app'), ledger: 0);
    await t.pumpAndSettle();
    expect(renderer.calls, [(PosterType.appPromo, false, 0, null, null)]);
    expect(find.byKey(const ValueKey('share-card-save')), findsOneWidget);
    expect(find.text(AppLocalizationsEn().sharePosterGenerateFailed),
        findsNothing);
  });

  check('production carousel dialog keeps profile/app templates and switches',
      (t) async {
    await host(
        t,
        Builder(
            builder: (context) => TextButton(
                onPressed: () =>
                    SharePosterService.showPosterCarouselPreview(context),
                child: const Text('open'))));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BeeShareCard), findsOneWidget);
    expect(renderer.calls.single.$1, PosterType.userProfile);
    expect(find.byKey(const ValueKey('share-card-privacy')), findsNothing);
    await t.tap(find.byKey(const ValueKey('share-card-template-appPromo')));
    await t.pumpAndSettle();
    expect(renderer.calls.last.$1, PosterType.appPromo);
    await t.tap(find.byKey(const ValueKey('share-card-template-userProfile')));
    await t.pumpAndSettle();
    expect(renderer.calls.length, 2);
  });
  for (final type in ['month', 'year', 'ledger']) {
    check('production dynamic $type keeps IDs and privacy regeneration',
        (t) async {
      await host(
          t,
          Consumer(
              builder: (context, ref, _) => TextButton(
                  onPressed: () => SharePosterService.showDynamicPosterPreview(
                      context, ref,
                      type: type,
                      ledgerId: 1,
                      year: 2026,
                      month: type == 'month' ? 10 : null),
                  child: const Text('open'))));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(renderer.calls.single.$3, 1);
      expect(renderer.calls.single.$4, 2026);
      await t.tap(find.byKey(const ValueKey('share-card-privacy')));
      await t.pumpAndSettle();
      expect(renderer.calls.last.$2, isTrue);
      await t.tap(find.byKey(const ValueKey('share-card-privacy')));
      await t.pumpAndSettle();
      expect(renderer.calls.length, 2);
    });
  }
  check('year/month carousel APIs select original single template', (t) async {
    await host(t, const ShareCardControls(year: 2024, month: 2));
    await t.pumpAndSettle();
    expect(renderer.calls.single, (PosterType.monthSummary, false, 1, 2024, 2));
    await host(t, const ShareCardControls(key: ValueKey('year'), year: 2025));
    await t.pumpAndSettle();
    expect(renderer.calls.last.$1, PosterType.yearSummary);
  });
  check('static PNG preview uses same body without template/privacy switches',
      (t) async {
    await host(
        t,
        Builder(
            builder: (context) => TextButton(
                onPressed: () =>
                    SharePosterService.showPosterPreview(context, _png),
                child: const Text('open'))));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(renderer.calls, isEmpty);
    expect(find.byType(BeeShareCard), findsOneWidget);
    expect(find.byKey(const ValueKey('share-card-privacy')), findsNothing);
  });
  check('generation error retries and missing ledger does not invoke generator',
      (t) async {
    renderer.fail = true;
    await host(t, const ShareCardControls(year: 2026));
    await t.pumpAndSettle();
    expect(find.text(l.sharePosterGenerateFailed), findsOneWidget);
    renderer.fail = false;
    await t.tap(find.byKey(const ValueKey('share-card-retry')));
    await t.pumpAndSettle();
    expect(renderer.calls.length, 2);
    expect(find.text(l.sharePosterGenerateFailed), findsNothing);
    await host(
        t,
        const ShareCardControls(
            key: ValueKey('no-ledger'), year: 2026, ledgerId: 0),
        ledger: 0);
    await t.pumpAndSettle();
    expect(find.text(l.sharePosterNoLedger), findsOneWidget);
    expect(renderer.calls.length, 2);
  });
  check('carousel swipe retains template switching', (t) async {
    await host(t, const ShareCardControls());
    await t.pumpAndSettle();
    await t.fling(find.byType(InteractiveViewer), const Offset(-250, 0), 1200);
    await t.pumpAndSettle();
    expect(renderer.calls.last.$1, PosterType.appPromo);
  });
  check('changing template ignores previous pending generation', (t) async {
    final first = Completer<Uint8List?>();
    renderer.gate = first;
    await host(t, const ShareCardControls());
    await t.pump();
    renderer.gate = null;
    await t.tap(find.byKey(const ValueKey('share-card-template-appPromo')));
    await t.pumpAndSettle();
    first.complete(null);
    await t.pumpAndSettle();
    expect(find.text(l.sharePosterGenerateFailed), findsNothing);
    expect(t.widget<BeeShareCard>(find.byType(BeeShareCard)).selected,
        PosterType.appPromo.name);
  });
  check('closing during generation ignores late completion', (t) async {
    renderer.gate = Completer<Uint8List?>();
    await host(
        t,
        Builder(
            builder: (context) => TextButton(
                onPressed: () =>
                    SharePosterService.showPosterCarouselPreview(context),
                child: const Text('open'))));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(const ValueKey('share-card-close')));
    await t.pumpAndSettle();
    renderer.gate!.complete(_png);
    await t.pumpAndSettle();
    expect(find.byType(BeeShareCard), findsNothing);
    expect(t.takeException(), isNull);
  });
  check('share duplicate prevention and dismissed result has no success/error',
      (t) async {
    platform.gate = Completer<void>();
    await host(t, const ShareCardControls(year: 2026));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('share-card-share')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('share-card-share')));
    await t.pump();
    expect(platform.shares, 1);
    expect(platform.anchor!.width, greaterThan(0));
    platform.gate!.complete();
    await t.pumpAndSettle();
    expect(find.text(l.commonError), findsNothing);
    expect(find.text(l.sharePosterSaveSuccess), findsNothing);
    expect(find.byType(BeeShareCard), findsOneWidget);
    platform.fail = true;
    await t.tap(find.byKey(const ValueKey('share-card-share')));
    await t.pumpAndSettle();
    expect(find.text(l.commonError), findsOneWidget);
  });
  check(
      'save duplicate prevention, permission, failure and success closes dialog',
      (t) async {
    platform.gate = Completer<void>();
    platform.result = SavePosterResult.accessDenied;
    await host(
        t,
        Builder(
            builder: (context) => TextButton(
                onPressed: () => SharePosterService.showPosterCarouselPreview(
                    context,
                    year: 2026),
                child: const Text('open'))));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('share-card-save')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('share-card-save')));
    await t.pump();
    expect(platform.saves, 1);
    platform.gate!.complete();
    await t.pumpAndSettle();
    expect(find.text(l.sharePosterPermissionDenied), findsOneWidget);
    platform.gate = null;
    platform.result = SavePosterResult.failed;
    await t.tap(find.byKey(const ValueKey('share-card-save')));
    await t.pumpAndSettle();
    expect(find.text(l.sharePosterSaveFailed), findsOneWidget);
    platform.result = SavePosterResult.success;
    await t.tap(find.byKey(const ValueKey('share-card-save')));
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
  check('thin page reopens with same original request parameters', (t) async {
    await host(t,
        const ShareCardPage(type: 'month', ledgerId: 1, year: 2024, month: 2));
    await t.pumpAndSettle();
    expect(renderer.calls.single, (PosterType.monthSummary, false, 1, 2024, 2));
    await host(t, const SizedBox.shrink());
    await host(t,
        const ShareCardPage(type: 'month', ledgerId: 1, year: 2024, month: 2));
    await t.pumpAndSettle();
    expect(renderer.calls.last, renderer.calls.first);
  });
  for (final locale in [const Locale('en'), const Locale('zh')]) {
    check('${locale.languageCode} 320 140% dark error and sample fit',
        (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await host(
          t,
          const ShareCardDialog(
              type: 'month', ledgerId: 1, year: 2026, month: 10),
          scale: 1.4,
          brightness: Brightness.dark,
          locale: locale);
      await t.pumpAndSettle();
      platform.result = SavePosterResult.accessDenied;
      await t.tap(find.byKey(const ValueKey('share-card-save')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await host(t, const SingleChildScrollView(child: ShareCardSample()),
          scale: 1.4, brightness: Brightness.dark, locale: locale);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
  check('read-only real preview disables save and system share', (t) async {
    await host(t, const SingleChildScrollView(child: ShareCardPreview()));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const ValueKey('share-card-save')));
    await t.tap(find.byKey(const ValueKey('share-card-save')));
    await t.tap(find.byKey(const ValueKey('share-card-share')));
    expect(platform.saves, 0);
    expect(platform.shares, 0);
  });
  for (final type in ['month', 'year', 'ledger', 'profile', 'app']) {
    check('real SQLite $type original template renders PNG', (t) async {
      final capture = _CaptureRenderer();
      await host(
          t,
          ShareCardControls(
              type: ['month', 'year', 'ledger'].contains(type) ? type : null),
          useRenderer: capture,
          scale: 1.4,
          brightness: Brightness.dark);
      if (type == 'app') {
        await t.tap(find.byKey(const ValueKey('share-card-template-appPromo')));
        await t.pump();
      }
      for (var i = 0; i < 150 && capture.bytes == null; i++) {
        await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await t.pump(const Duration(milliseconds: 30));
      }
      expect(capture.bytes, isNotNull);
      final codec =
          await t.runAsync(() => ui.instantiateImageCodec(capture.bytes!));
      final frame = await t.runAsync(() => codec!.getNextFrame());
      expect(frame!.image.width, 188);
      expect(frame.image.height, 334);
      frame.image.dispose();
      codec!.dispose();
    });
  }
  for (final locale in [const Locale('en'), const Locale('zh')]) {
    check(
        '${locale.languageCode} original year long category and income privacy render PNG',
        (t) async {
      Uint8List? rendered;
      final capture = _CaptureRenderer(ratio: 1);
      await host(
          t,
          Builder(
              builder: (context) => TextButton(
                  onPressed: () async {
                    rendered = await capture.capture(
                        context,
                        YearSummaryPoster(
                            primaryColor: Colors.amber,
                            hideIncome: true,
                            data: YearSummaryPosterData(
                                year: 2026,
                                recordDays: 123,
                                recordCount: 456,
                                totalIncome: 987654.32,
                                totalExpense: 123456.78,
                                topExpenseCategories: [
                                  CategoryTotal(
                                      name: locale.languageCode == 'en'
                                          ? 'QA complete category name with family groceries and travel expenses'
                                          : 'QA完整保留家庭与旅行生活支出分类名称',
                                      total: 123456.78,
                                      percentage: 1)
                                ],
                                topIncomeCategories: const [],
                                avgMonthlyExpense: 12345.678,
                                avgMonthlyIncome: 98765.432,
                                maxExpenseMonth: 10,
                                maxExpenseAmount: 123456.78,
                                balance: 864197.54)));
                  },
                  child: const Text('capture'))),
          locale: locale,
          scale: 1.4);
      await t.tap(find.text('capture'));
      await t.pump();
      for (var i = 0; i < 150 && rendered == null; i++) {
        await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await t.pump(const Duration(milliseconds: 30));
        if (i == 5 && find.byType(QrImageView).evaluate().isNotEmpty) {
          expect(t.getSize(find.byType(QrImageView)), const Size(112, 112));
        }
      }
      expect(rendered, isNotNull);
      final codec = await t.runAsync(() => ui.instantiateImageCodec(rendered!));
      final frame = await t.runAsync(() => codec!.getNextFrame());
      expect(frame!.image.width, 750);
      expect(frame.image.height, 1334);
      frame.image.dispose();
      codec!.dispose();
      final evidence = Platform.environment['BEE_SHARE_CARD_EVIDENCE_DIR'];
      if (evidence != null) {
        final stage =
            Platform.environment['BEE_SHARE_CARD_EVIDENCE_STAGE'] ?? 'after';
        await t.runAsync(() =>
            File('$evidence/year-long-${locale.languageCode}-$stage.png')
                .writeAsBytes(rendered!));
      }
      expect(t.takeException(), isNull);
    });
  }
  check('missing profile avatar renders original fallback PNG', (t) async {
    Uint8List? rendered;
    final capture = _CaptureRenderer();
    await host(
        t,
        Builder(
            builder: (context) => TextButton(
                onPressed: () async {
                  rendered = await capture.capture(
                      context,
                      UserProfilePoster(
                          primaryColor: Colors.amber,
                          l10n: AppLocalizations.of(context),
                          data: const UserProfilePosterData(
                              avatarPath: '/qa/missing-avatar.png',
                              recordDays: 120,
                              recordCount: 360,
                              ledgerCount: 2,
                              ledgerName: 'QA missing-avatar ledger')));
                },
                child: const Text('capture'))));
    await t.tap(find.text('capture'));
    await t.pump();
    for (var i = 0; i < 150 && rendered == null; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump(const Duration(milliseconds: 30));
    }
    expect(rendered, isNotNull);
    expect(t.takeException(), isNull);
  });
  check('year privacy masks total, balance and average income text', (t) async {
    final poster = YearSummaryPoster(
        primaryColor: Colors.amber,
        hideIncome: true,
        data: const YearSummaryPosterData(
            year: 2026,
            recordDays: 1,
            recordCount: 1,
            totalIncome: 98765.43,
            totalExpense: 1000,
            topExpenseCategories: [],
            topIncomeCategories: [],
            avgMonthlyExpense: 100,
            avgMonthlyIncome: 9876.54,
            balance: 97765.43));
    await host(
        t,
        FittedBox(
            child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.noScaling),
                child: poster)));
    await t.pumpAndSettle();
    expect(find.textContaining('**'), findsNWidgets(3));
    expect(find.textContaining('9,876.54'), findsNothing);
    expect(find.textContaining('98,765.43'), findsNothing);
  });
  check('original PNG canvas stays 2250 by 4002 at production ratio',
      (t) async {
    Uint8List? rendered;
    final capture = _CaptureRenderer(ratio: 3);
    await host(
        t,
        Builder(
            builder: (context) => TextButton(
                onPressed: () async {
                  rendered = await capture.capture(
                      context,
                      AppPromoPoster(
                          l10n: AppLocalizations.of(context),
                          primaryColor: Colors.amber));
                },
                child: const Text('capture'))));
    await t.tap(find.text('capture'));
    await t.pump();
    for (var i = 0; i < 150 && rendered == null; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump(const Duration(milliseconds: 30));
    }
    expect(rendered, isNotNull);
    final codec = await t.runAsync(() => ui.instantiateImageCodec(rendered!));
    final frame = await t.runAsync(() => codec!.getNextFrame());
    expect(frame!.image.width, 2250);
    expect(frame.image.height, 4002);
    frame.image.dispose();
    codec!.dispose();
    expect(t.takeException(), isNull);
  });
  check('real generation cancellation removes private overlay after close',
      (t) async {
    final capture = _CaptureRenderer();
    await host(
        t,
        Builder(
            builder: (context) => TextButton(
                onPressed: () => SharePosterService.showPosterCarouselPreview(
                    context,
                    year: 2026,
                    month: 10),
                child: const Text('open'))),
        useRenderer: capture);
    await t.tap(find.text('open'));
    await t.pump();
    for (var i = 0; i < 60 && !capture.started; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
      await t.pump(const Duration(milliseconds: 5));
    }
    expect(capture.started, isTrue);
    await t.tap(find.byKey(const ValueKey('share-card-close')));
    await t.pump(const Duration(milliseconds: 350));
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 550)));
    await t.pumpAndSettle();
    expect(find.byType(BeeShareCard), findsNothing);
    expect(find.byType(MonthSummaryPoster), findsNothing);
    expect(t.takeException(), isNull);
  });
  for (final long in [false, true]) {
    check(
        'year fixed canvas ${long ? 'long content shrinks' : 'short content stays original scale'}',
        (t) async {
      final name = long
          ? 'QA complete category name with family groceries and travel expenses'
          : '';
      final data = YearSummaryPosterData(
          year: 2026,
          recordDays: 123,
          recordCount: 456,
          totalIncome: 987654.32,
          totalExpense: 123456.78,
          topExpenseCategories: long
              ? [CategoryTotal(name: name, total: 123456.78, percentage: 1)]
              : [],
          topIncomeCategories: const [],
          avgMonthlyExpense: 12345.678,
          avgMonthlyIncome: 98765.432,
          maxExpenseMonth: long ? 10 : null,
          maxExpenseAmount: long ? 123456.78 : null,
          balance: 864197.54);
      await host(
          t,
          FittedBox(
              child: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.noScaling),
                  child: YearSummaryPoster(
                      primaryColor: Colors.amber,
                      hideIncome: true,
                      data: data))));
      await t.pumpAndSettle();
      final content =
          t.renderObject(find.byKey(const ValueKey('bee-poster-content')));
      final fit = t.renderObject(find.byKey(const ValueKey('bee-poster-fit')));
      final scale = content.getTransformTo(fit).storage[0].abs();
      expect(scale, lessThanOrEqualTo(1));
      expect(scale, greaterThan(.5));
      expect(t.takeException(), isNull);
    });
  }
}
