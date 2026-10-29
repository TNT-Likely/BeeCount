import 'dart:async';

import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/models/home_transaction_preview.dart';
import 'package:beecount/pages/auth/splash_page.dart';
import 'package:beecount/pages/main/home_page.dart';
import 'package:beecount/pages/main/home/bindings/home_startup_gate.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/providers/home_startup_preview_provider.dart';
import 'package:beecount/services/system/logger_service.dart';
import 'package:beecount/pages/main/home/widgets/day_section_header.dart';
import 'package:beecount/pages/main/home/bindings/transaction_list.dart';
import 'package:beecount/pages/shared/transactions/transaction_list_item.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _StartupRepository extends LocalRepository {
  _StartupRepository(super.db);
  Completer<void>? previewGate, fullGate;
  bool failPreview = false, failSecondPreview = false;
  int previews = 0;
  final List<int> preparedCounts = [];

  @override
  Future<HomeTransactionPreview> getHomeTransactionPreview(
      {required int ledgerId, int limit = 20}) async {
    previews++;
    await previewGate?.future;
    if (failPreview || (failSecondPreview && previews > 1)) {
      throw StateError('Synthetic preview unavailable');
    }
    final preview =
        await super.getHomeTransactionPreview(ledgerId: ledgerId, limit: limit);
    preparedCounts.add(preview.totalCount);
    return preview;
  }

  @override
  Stream<List<TransactionRowData>> transactionsWithCategoryAll(
      {int? ledgerId}) async* {
    await fullGate?.future;
    yield* super.transactionsWithCategoryAll(ledgerId: ledgerId);
  }
}

void main() {
  late BeeDatabase db;
  late _StartupRepository repo;
  late ProviderContainer container;
  late DateTime day;

  setUp(() async {
    SharedPreferences.setMockInitialValues(
        {'welcome_shown': true, 'current_ledger_id': 1});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _StartupRepository(db);
    day = DateUtils.dateOnly(DateTime.now()).add(const Duration(hours: 12));
    for (final id in [1, 2, 3]) {
      await db.customStatement(
          'INSERT INTO ledgers(id,name,currency) VALUES(?,?,?)',
          [id, 'Synthetic $id', 'CNY']);
    }
    final category =
        await repo.createCategory(name: 'Category', kind: 'expense');
    final tag = await repo.createTag(name: 'Complete tag');
    final account = await repo.createAccount(
        ledgerId: 1, name: 'USD account', type: 'cash', currency: 'USD');
    for (var i = 0; i < 42; i++) {
      final tx = await repo.addTransaction(
          ledgerId: 1,
          type: 'expense',
          amount: 2,
          nativeAmount: 14,
          currencyCode: 'USD',
          categoryId: category,
          accountId: account,
          happenedAt: day.subtract(Duration(minutes: i)),
          note: 'Complete $i');
      await repo.updateTransactionTags(transactionId: tx, tagIds: [tag]);
      await db.customStatement(
          "INSERT INTO transaction_attachments(transaction_id,file_name,sort_order) VALUES(?,'fixture.png',0)",
          [tx]);
    }
    await repo.addTransaction(
        ledgerId: 2, type: 'income', amount: 5, happenedAt: day);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    logger.disposeForTesting();
  });

  Future<void> tick(WidgetTester tester, [int count = 1]) async {
    for (var i = 0; i < count; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> mount(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(398, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    });
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!),
            home: child)));
  }

  Future<void> waitForHome(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      if (find.byType(HomePage).evaluate().isNotEmpty) return;
      await tick(tester);
    }
    fail('Home never became ready');
  }

  Future<void> close(WidgetTester tester) async {
    if (repo.fullGate?.isCompleted == false) repo.fullGate!.complete();
    await tester.pumpWidget(const SizedBox.shrink());
    await tick(tester, 2);
    await tester.pump(const Duration(seconds: 3));
    logger.disposeForTesting();
  }

  testWidgets(
      'startup stays on Splash; its first Home frame consumes complete '
      '20 rows and full count/day totals without a second preview or spinner',
      (tester) async {
    repo.previewGate = Completer<void>();
    repo.fullGate = Completer<void>();
    repo.failSecondPreview = true;
    await mount(tester,
        const AppStartupGate(child: HomeStartupGate(child: HomePage())));
    await tick(tester, 20);
    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    expect(container.read(appInitStateProvider), isNot(AppInitState.ready));
    expect(repo.previews, 1);
    repo.previewGate!.complete();
    await waitForHome(tester);
    expect(find.byType(SplashPage), findsNothing);
    expect(find.byType(CircularProgressIndicator).hitTestable(), findsNothing);
    final list = tester.widget<TransactionList>(find.byType(TransactionList));
    expect(list.transactionsWithDetails, hasLength(20));
    expect(list.sourceReady, false);
    final row = tester.widget<BeeTransactionRow>(
        find.byType(BeeTransactionRow, skipOffstage: false).first);
    expect(row.tags.single.label, 'Complete tag');
    expect(row.attachmentCount, 1);
    expect(row.accountName, 'USD account');
    expect(row.converted, isNotNull);
    expect(find.text('42笔'), findsOneWidget);
    expect(
        tester
            .widget<DaySectionHeader>(
                find.byType(DaySectionHeader, skipOffstage: false).first)
            .expense,
        42 * 14);
    expect(repo.previews, 1, reason: 'Splash work must not be discarded');
    await tick(tester, 10);
    expect(repo.previews, 1);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets(
      'mutation while waiting for Home invalidates the startup snapshot; '
      'new data is prepared on Splash before any Home frame', (tester) async {
    final cache = container.read(homeStartupPreviewHandoffProvider);
    await tester.runAsync(() async {
      await cache.prepare(repo, 1, db);
      await db.customUpdate(
          'UPDATE transactions SET native_amount=18 WHERE ledger_id=1',
          updates: {db.transactions});
      await Future<void>.delayed(Duration.zero);
    });
    expect(cache.peek(repo, 1), isNull);
    repo.previewGate = Completer<void>();
    repo.fullGate = Completer<void>();
    await mount(tester, const HomeStartupGate(child: HomePage()));
    await tick(tester, 5);
    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    repo.previewGate!.complete();
    await waitForHome(tester);
    expect(
        tester
            .widget<TransactionListItem>(
                find.byType(TransactionListItem, skipOffstage: false).first)
            .nativeAmount,
        18);
    expect(find.text('42笔'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator).hitTestable(), findsNothing);
    expect(repo.previews, 2);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('startup generates due recurring bills before preparing Home',
      (tester) async {
    await repo.addRecurringTransaction(
        ledgerId: 1,
        type: 'income',
        amount: 9,
        note: 'Due before Home',
        frequency: 'daily',
        interval: 1,
        startDate: DateUtils.dateOnly(day));
    await mount(tester,
        const AppStartupGate(child: HomeStartupGate(child: HomePage())));
    await waitForHome(tester);
    expect(repo.preparedCounts, [43],
        reason: 'No obsolete pre-recurring snapshot may reach Home');
    expect(find.text('43笔'), findsOneWidget);
    final list = tester.widget<TransactionList>(find.byType(TransactionList));
    expect(list.previewDayTotals!.values.single.income, 9);
    expect(list.previewDayTotals!.values.single.expense, 42 * 14);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('first Home uses the saved ledger rather than the default ledger',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_ledger_id', 2);
    repo.fullGate = Completer<void>();
    repo.failSecondPreview = true;
    await mount(tester,
        const AppStartupGate(child: HomeStartupGate(child: HomePage())));
    await waitForHome(tester);
    final list = tester.widget<TransactionList>(find.byType(TransactionList));
    expect(list.ledgerId, 2);
    expect(list.transactionsWithDetails, hasLength(1));
    expect(list.transactionsWithDetails!.single.t.ledgerId, 2);
    expect(find.text('1笔'), findsOneWidget);
    expect(repo.preparedCounts, [1]);
    expect(find.byType(CircularProgressIndicator).hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets(
      'failed startup remains retryable instead of entering an empty Home',
      (tester) async {
    repo.failPreview = true;
    repo.fullGate = Completer<void>();
    await mount(tester,
        const AppStartupGate(child: HomeStartupGate(child: HomePage())));
    await tick(tester, 35);
    expect(find.byType(HomePage), findsNothing);
    expect(container.read(appInitStateProvider), isNot(AppInitState.ready));
    expect(find.text('重试').hitTestable(), findsOneWidget);
    repo.failPreview = false;
    await tester.tap(find.text('重试'));
    await waitForHome(tester);
    expect(find.text('42笔'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('a complete empty startup snapshot shows empty state immediately',
      (tester) async {
    container.read(currentLedgerIdProvider.notifier).state = 3;
    final cache = container.read(homeStartupPreviewHandoffProvider);
    await tester.runAsync(() => cache.prepare(repo, 3, db));
    repo.fullGate = Completer<void>();
    repo.failSecondPreview = true;
    await mount(tester, const HomeStartupGate(child: HomePage()));
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('0笔'), findsOneWidget);
    expect(find.byType(BeeEmptyState), findsOneWidget);
    expect(find.byType(CircularProgressIndicator).hitTestable(), findsNothing);
    expect(repo.previews, 1);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  test('ledger restoration completes before appInit returns', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_ledger_id', 2);
    expect(container.read(currentLedgerIdProvider), 1);
    await container.read(appInitProvider.future);
    expect(container.read(currentLedgerIdProvider), 2);
  });

  test('a startup handoff is one-shot, including mismatched scope', () async {
    final preview = await repo.getHomeTransactionPreview(ledgerId: 1);
    final cache = HomeStartupPreviewHandoff();
    cache.publish(repo, preview);
    expect(cache.take(repo, 2), isNull);
    expect(cache.take(repo, 1), isNull);
    cache.publish(repo, preview);
    expect(cache.take(repo, 1)?.preview, same(preview));
    expect(cache.take(repo, 1), isNull);
    cache.dispose();
  });
}
