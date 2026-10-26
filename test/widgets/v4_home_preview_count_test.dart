import 'dart:async';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/models/home_transaction_preview.dart';
import 'package:beecount/presentation/v4/bindings/home_journal.dart';
import 'package:beecount/presentation/v4/bindings/home_transaction_feed.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/system/logger_service.dart';
import 'package:beecount/widgets/biz/transaction_list.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountFeedRepository extends LocalRepository {
  _CountFeedRepository(super.db);
  final fullGate = Completer<void>();

  @override
  Stream<List<TransactionRowData>> transactionsWithCategoryAll(
      {int? ledgerId}) async* {
    if (ledgerId == 1) await fullGate.future;
    yield* super.transactionsWithCategoryAll(ledgerId: ledgerId);
  }
}

void main() {
  late BeeDatabase db;
  late _CountFeedRepository repo;
  late ProviderContainer container;
  final requests = <({Completer<void> gate, int ledger, int count})>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _CountFeedRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'Synthetic pressure','CNY'),(2,'Empty','CNY')");
    final firstCountRead = Completer<void>();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      countsForLedgerProvider.overrideWith((ref, ledger) async {
        ref.watch(statsRefreshProvider);
        // Capture a genuine repository result, then deliberately delay its
        // delivery. The first request reads 0 before the synthetic import.
        final counts = await repo.getCountsForLedger(ledgerId: ledger);
        final gate = Completer<void>();
        requests.add((gate: gate, ledger: ledger, count: counts.txCount));
        if (!firstCountRead.isCompleted) firstCountRead.complete();
        await gate.future;
        return counts;
      }),
    ]);
    unawaited(container.read(countsForLedgerProvider(1).future));
    await firstCountRead.future;
    expect(requests.single.count, 0);
    final date = DateTime(2026, 10, 26, 12).millisecondsSinceEpoch ~/ 1000;
    await db.customStatement(
        "INSERT INTO tags(id,name) VALUES(1,'Complete synthetic label')");
    await db.batch((batch) {
      for (var i = 1; i <= 15000; i++) {
        batch.customStatement(
            "INSERT INTO transactions(id,ledger_id,type,amount,native_amount,currency_code,happened_at) VALUES(?,1,'expense',2,14,'USD',?)",
            [i, date - i]);
        batch.customStatement(
            'INSERT INTO transaction_tags(transaction_id,tag_id) VALUES(?,1)',
            [i]);
      }
    });
  });
  tearDown(() async {
    container.dispose();
    if (!repo.fullGate.isCompleted) repo.fullGate.complete();
    for (final request in requests) {
      if (!request.gate.isCompleted) request.gate.complete();
    }
    await db.close();
    logger.disposeForTesting();
  });

  testWidgets(
      'first complete 20 atomically show real 15000 count; late stale counts are rejected and live 15001 supersedes preview',
      (tester) async {
    final listKey = GlobalKey<TransactionListState>();
    final controller = FlutterListViewController();
    addTearDown(controller.dispose);
    var sampledInitialRows = false;
    Future<void> flush(
        [int count = 15, bool verifyInitialCount = false]) async {
      for (var i = 0; i < count; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 16));
        if (verifyInitialCount &&
            (listKey.currentState?.loadedTransactionCount ?? 0) > 0) {
          sampledInitialRows = true;
          final l = AppLocalizations.of(
              tester.element(find.byType(HomeJournalFrame)));
          expect(
              tester
                  .widget<BeeTransactionStreamHeader>(
                      find.byType(BeeTransactionStreamHeader))
                  .count,
              l.tagTransactionCount(15000),
              reason:
                  'Every frame with published preview rows must already have its full count');
        }
      }
    }

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
              body: Consumer(
                  builder: (_, ref, __) => HomeJournalFrame(
                        onCalendar: () {},
                        onFilter: () {},
                        onBatch: () {},
                        childBuilder: (onPreviewReady) => HomeTransactionFeed(
                            ledgerId: ref.watch(currentLedgerIdProvider),
                            hideAmounts: false,
                            listKey: listKey,
                            controller: controller,
                            onPreviewReady: onPreviewReady),
                      ))),
        )));
    await flush(30, true);
    expect(sampledInitialRows, isTrue);
    final l =
        AppLocalizations.of(tester.element(find.byType(HomeJournalFrame)));
    String headerCount() => tester
        .widget<BeeTransactionStreamHeader>(
            find.byType(BeeTransactionStreamHeader))
        .count;
    expect(requests, hasLength(2),
        reason: 'Preview invalidates the old in-flight count generation');
    expect(requests[1].count, 15000);
    expect(listKey.currentState!.showingPreview, isTrue);
    expect(listKey.currentState!.loadedTransactionCount, 20);
    expect(headerCount(), l.tagTransactionCount(15000));
    expect(
        tester
            .widgetList<BeeTransactionRow>(
                find.byType(BeeTransactionRow, skipOffstage: false))
            .every(
                (row) => row.tags.single.label == 'Complete synthetic label'),
        isTrue);

    requests[0].gate.complete(); // Old 0 arrives after the complete preview.
    await flush();
    expect(headerCount(), l.tagTransactionCount(15000));
    requests[1].gate.complete();
    await flush();
    expect(headerCount(), l.tagTransactionCount(15000));

    await repo.addTransaction(
        ledgerId: 1,
        type: 'income',
        amount: 1,
        happenedAt: DateTime(2026, 10, 26, 13));
    container.read(statsRefreshProvider.notifier).state++;
    await flush();
    expect(requests, hasLength(3));
    expect(requests[2].count, 15001);
    expect(headerCount(), l.tagTransactionCount(15000),
        reason: 'Loading retains the most recent published count');
    requests[2].gate.complete();
    await flush();
    expect(headerCount(), l.tagTransactionCount(15001),
        reason: 'Live count replaces the initial preview fallback');

    container.read(statsRefreshProvider.notifier).state++;
    await flush();
    expect(requests, hasLength(4));
    expect(headerCount(), l.tagTransactionCount(15001),
        reason: 'Another refresh must not fall back to the old 15000 preview');
    container.read(currentLedgerIdProvider.notifier).state = 2;
    await flush();
    expect(headerCount(), l.tagTransactionCount(0));
    requests[3].gate.complete();
    await flush();
    expect(headerCount(), l.tagTransactionCount(0),
        reason:
            'Late previous-ledger counts cannot replace the current ledger');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    repo.fullGate.complete();
    await flush();
    logger.disposeForTesting();
  });
}
