import 'dart:async';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/pages/main/home/bindings/transaction_list.dart';
import 'package:beecount/pages/shared/transactions/transaction_list_item.dart';
import 'package:beecount/pages/main/home/widgets/day_section_header.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _Row = ({
  Transaction t,
  Category? category,
  Account? account,
  Account? toAccount
});

class _DelayedRepository extends LocalRepository {
  _DelayedRepository(super.db);
  Completer<void>? tagGate, attachmentGate;
  bool failTags = false;
  final tagReads = <List<int>>[], attachmentReads = <List<int>>[];

  @override
  Future<Map<int, List<Tag>>> getTagsForTransactions(List<int> ids) async {
    tagReads.add(List.of(ids));
    final gate = tagGate;
    if (gate != null) await gate.future;
    if (failTags) throw StateError('Synthetic metadata read failure');
    return super.getTagsForTransactions(ids);
  }

  @override
  Future<Map<int, int>> getAttachmentCountsForTransactions(
      List<int> ids) async {
    attachmentReads.add(List.of(ids));
    final gate = attachmentGate;
    if (gate != null) await gate.future;
    return super.getAttachmentCountsForTransactions(ids);
  }
}

void main() {
  late BeeDatabase db;
  late _DelayedRepository repo;
  late ProviderContainer providers;
  late List<_Row> first, second;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _DelayedRepository(db);
    for (var ledger = 1; ledger <= 2; ledger++) {
      await db.customStatement(
          'INSERT INTO ledgers(id,name,currency) VALUES(?,?,?)',
          [ledger, 'QA atomic $ledger', 'CNY']);
      final category = await repo.createCategory(
          name: 'Atomic category $ledger', kind: 'expense');
      final tag = await repo.createTag(name: 'Atomic tag $ledger');
      final id = await repo.addTransaction(
          ledgerId: ledger,
          type: 'expense',
          amount: 10,
          categoryId: category,
          happenedAt: DateTime(2026, 10, 26, 12),
          note: 'Atomic note $ledger');
      await repo.updateTransactionTags(transactionId: id, tagIds: [tag]);
      await db.customStatement(
          'INSERT INTO transaction_attachments(transaction_id,file_name,sort_order) VALUES(?,?,?)',
          [id, 'qa-metadata-only-$ledger.png', 0]);
    }
    first =
        await repo.getRecentTransactionsWithCategory(ledgerId: 1, limit: 20);
    second =
        await repo.getRecentTransactionsWithCategory(ledgerId: 2, limit: 20);
    providers = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
    ]);
  });
  tearDown(() async {
    providers.dispose();
    await db.close();
  });

  Widget host(Widget child) => UncontrolledProviderScope(
      container: providers,
      child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child)));

  Future<void> flush(WidgetTester tester) async {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump();
  }

  Future<void> awaitRows(WidgetTester tester) async {
    for (var i = 0;
        i < 30 &&
            find
                .byType(TransactionListItem, skipOffstage: false)
                .evaluate()
                .isEmpty;
        i++) {
      await flush(tester);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
      'first visible row includes tags and attachments in the same paint',
      (tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    });
    repo.tagGate = Completer<void>();
    repo.attachmentGate = Completer<void>();
    await tester.pumpWidget(host(
        TransactionList(ledgerId: 1, transactions: first, hideAmounts: false)));
    await flush(tester);
    expect(find.byType(TransactionListItem, skipOffstage: false), findsNothing);
    repo.tagGate!.complete();
    await flush(tester);
    expect(find.byType(TransactionListItem, skipOffstage: false), findsNothing,
        reason: 'Tags alone cannot publish a partially populated row');
    repo.attachmentGate!.complete();
    await awaitRows(tester);
    final row = tester.widget<BeeTransactionRow>(
        find.byType(BeeTransactionRow, skipOffstage: false));
    expect(row.tags.single.label, 'Atomic tag 1');
    expect(row.attachmentCount, 1);
    final before =
        tester.getRect(find.byType(BeeTransactionRow, skipOffstage: false));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.getRect(find.byType(BeeTransactionRow, skipOffstage: false)),
        before);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a late previous-ledger request never replaces the current ledger',
      (tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    });
    final oldTags = Completer<void>(), oldAttachments = Completer<void>();
    repo.tagGate = oldTags;
    repo.attachmentGate = oldAttachments;
    final selected = ValueNotifier(1);
    addTearDown(selected.dispose);
    await tester.pumpWidget(host(ValueListenableBuilder<int>(
        valueListenable: selected,
        builder: (_, ledger, __) => TransactionList(
            ledgerId: ledger,
            transactions: ledger == 1 ? first : second,
            hideAmounts: false))));
    await flush(tester);
    repo.tagGate = null;
    repo.attachmentGate = null;
    selected.value = 2;
    await awaitRows(tester);
    expect(
        tester
            .widget<BeeTransactionRow>(
                find.byType(BeeTransactionRow, skipOffstage: false))
            .tags
            .single
            .label,
        'Atomic tag 2');
    oldTags.complete();
    oldAttachments.complete();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<BeeTransactionRow>(
                find.byType(BeeTransactionRow, skipOffstage: false))
            .tags
            .single
            .label,
        'Atomic tag 2');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a failed relationship read is recoverable and does not fake no tags',
      (tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    });
    repo.failTags = true;
    await tester.pumpWidget(host(
        TransactionList(ledgerId: 1, transactions: first, hideAmounts: false)));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionListItem, skipOffstage: false), findsNothing);
    expect(find.text('重试'), findsOneWidget);
    repo.failTags = false;
    await tester.tap(find.text('重试'));
    await awaitRows(tester);
    expect(
        tester
            .widget<BeeTransactionRow>(
                find.byType(BeeTransactionRow, skipOffstage: false))
            .tags
            .single
            .label,
        'Atomic tag 1');
    expect((await db.select(db.transactions).get()).length, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
      'a complete preview renders full day totals before the full collection',
      (tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    });
    for (var i = 0; i < 40; i++) {
      await repo.addTransaction(
          ledgerId: 1,
          type: 'expense',
          amount: 1,
          happenedAt: DateTime(2026, 10, 26, 12),
          note: 'Full-day record $i');
    }
    final complete =
        await repo.getRecentTransactionsWithCategory(ledgerId: 1, limit: 100);
    expect(complete.length, 41);
    final preview = await repo.getHomeTransactionPreview(ledgerId: 1);
    final ready = ValueNotifier(false);
    addTearDown(ready.dispose);
    await tester.pumpWidget(host(ValueListenableBuilder<bool>(
        valueListenable: ready,
        builder: (_, sourceReady, __) => TransactionList(
            ledgerId: 1,
            sourceReady: sourceReady,
            previewDayTotals: preview.dayTotals,
            transactionsWithDetails: preview.rows,
            transactions: sourceReady ? complete : complete.take(20).toList(),
            hideAmounts: false))));
    repo.tagReads.clear();
    await awaitRows(tester);
    expect(find.byType(TransactionListItem, skipOffstage: false), findsWidgets);
    expect(repo.tagReads, isEmpty,
        reason: 'Complete preview needs no late tag reads');
    expect(
        tester
            .widget<DaySectionHeader>(
                find.byType(DaySectionHeader, skipOffstage: false))
            .expense,
        50,
        reason:
            'Twenty visible records must include the other 21 in the day total');
    ready.value = true;
    await awaitRows(tester);
    expect(find.byType(TransactionListItem, skipOffstage: false), findsWidgets);
    expect(
        tester
            .widget<DaySectionHeader>(
                find.byType(DaySectionHeader, skipOffstage: false))
            .expense,
        50);
    expect(
        tester
            .state<TransactionListState>(find.byType(TransactionList))
            .jumpToMonth(DateTime(2026, 10)),
        isTrue);
  });
}
