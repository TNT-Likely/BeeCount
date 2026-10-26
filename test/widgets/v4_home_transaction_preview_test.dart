import 'dart:async';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/models/home_transaction_preview.dart';
import 'package:beecount/presentation/v4/bindings/home_transaction_feed.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/system/logger_service.dart';
import 'package:beecount/widgets/biz/day_section_header.dart';
import 'package:beecount/widgets/biz/transaction_list.dart';
import 'package:beecount/widgets/biz/transaction_list_item.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _FeedRepository extends LocalRepository {
  _FeedRepository(super.db);
  final previewGates = <int, Completer<void>>{};
  final fullGates = <int, Completer<void>>{};
  final subscriptions = <int>[];
  Completer<void>? fullMetadataGate;
  bool failFullSource = false, failFullMetadata = false, failPreview = false;

  @override
  Future<HomeTransactionPreview> getHomeTransactionPreview(
      {required int ledgerId, int limit = 20}) async {
    await previewGates[ledgerId]?.future;
    if (failPreview) throw StateError('Synthetic preview failure');
    return super.getHomeTransactionPreview(ledgerId: ledgerId, limit: limit);
  }

  @override
  Stream<List<TransactionRowData>> transactionsWithCategoryAll(
      {int? ledgerId}) async* {
    subscriptions.add(ledgerId!);
    await fullGates[ledgerId]?.future;
    if (failFullSource) throw StateError('Synthetic full-source failure');
    yield* super.transactionsWithCategoryAll(ledgerId: ledgerId);
  }

  @override
  Future<Map<int, List<Tag>>> getTagsForTransactions(List<int> ids) async {
    if (ids.length > 20) {
      await fullMetadataGate?.future;
      if (failFullMetadata) throw StateError('Synthetic full-metadata failure');
    }
    return super.getTagsForTransactions(ids);
  }
}

void main() {
  late BeeDatabase db;
  late _FeedRepository repo;
  late ProviderContainer container;
  late ValueNotifier<int> selected;
  late GlobalKey<TransactionListState> listKey;
  late FlutterListViewController controller;
  final day = DateTime(2026, 10, 26, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _FeedRepository(db);
    for (final ledger in [1, 2, 3]) {
      await db.customStatement(
          'INSERT INTO ledgers(id,name,currency) VALUES(?,?,?)',
          [ledger, 'Synthetic $ledger', 'CNY']);
    }
    final category =
        await repo.createCategory(name: 'Synthetic category', kind: 'expense');
    final tag = await repo.createTag(name: 'Complete label');
    final account = await repo.createAccount(
        ledgerId: 1, name: 'USD account', type: 'cash', currency: 'USD');
    for (var i = 0; i < 42; i++) {
      final id = await repo.addTransaction(
          ledgerId: 1,
          type: 'expense',
          amount: 2,
          nativeAmount: 14,
          currencyCode: 'USD',
          categoryId: category,
          accountId: account,
          happenedAt: i == 41
              ? DateTime(2026, 6, 12)
              : day.subtract(Duration(minutes: i)),
          note: 'Complete record $i');
      await repo.updateTransactionTags(transactionId: id, tagIds: [tag]);
      await db.customStatement(
          "INSERT INTO transaction_attachments(transaction_id,file_name,sort_order) VALUES(?,'synthetic.png',0)",
          [id]);
    }
    await repo.addTransaction(
        ledgerId: 2,
        type: 'income',
        amount: 5,
        happenedAt: day,
        note: 'Second ledger');
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo)
    ]);
    selected = ValueNotifier(1);
    listKey = GlobalKey<TransactionListState>();
    controller = FlutterListViewController();
  });
  tearDown(() async {
    selected.dispose();
    controller.dispose();
    container.dispose();
    await db.close();
  });

  Future<void> flush(WidgetTester tester, [int count = 10]) async {
    for (var i = 0; i < count; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
              body: ValueListenableBuilder<int>(
                  valueListenable: selected,
                  builder: (_, ledger, __) => HomeTransactionFeed(
                      ledgerId: ledger,
                      hideAmounts: false,
                      listKey: listKey,
                      controller: controller))),
        )));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      logger.disposeForTesting();
    });
    await flush(tester, 30);
  }

  List<BeeTransactionRow> visible(WidgetTester tester) => tester
      .widgetList<BeeTransactionRow>(
          find.byType(BeeTransactionRow, skipOffstage: false))
      .toList();
  TransactionList list(WidgetTester tester) =>
      tester.widget<TransactionList>(find.byType(TransactionList));

  testWidgets(
      'first 20 are complete and actionable before full rows or metadata; full handoff keeps day totals and position',
      (tester) async {
    repo.fullGates[1] = Completer<void>();
    repo.fullMetadataGate = Completer<void>();
    await open(tester);
    expect(list(tester).sourceReady, isFalse);
    expect(list(tester).transactionsWithDetails, hasLength(20));
    expect(listKey.currentState!.showingPreview, isTrue);
    expect(listKey.currentState!.loadedTransactionCount, 20);
    final row = visible(tester).first;
    expect(row.tags.single.label, 'Complete label');
    expect(row.attachmentCount, 1);
    expect(row.onTap, isNotNull);
    expect(row.onCategoryTap, isNotNull);
    expect(
        tester
            .widget<DaySectionHeader>(
                find.byType(DaySectionHeader, skipOffstage: false))
            .expense,
        41 * 14);
    final firstRect = tester
        .getRect(find.byType(BeeTransactionRow, skipOffstage: false).first);
    repo.fullGates[1]!.complete();
    await flush(tester);
    expect(list(tester).sourceReady, isTrue);
    expect(list(tester).transactions, hasLength(42));
    expect(listKey.currentState!.showingPreview, isTrue);
    expect(listKey.currentState!.loadedTransactionCount, 20);
    expect(visible(tester).first.tags.single.label, 'Complete label',
        reason: 'Full metadata wait keeps complete preview painted');
    expect(
        tester
            .getRect(find.byType(BeeTransactionRow, skipOffstage: false).first),
        firstRect);
    await tester.drag(find.byType(FlutterListView), const Offset(0, -250));
    await tester.pump(const Duration(milliseconds: 600));
    final offset = controller.offset;
    repo.fullMetadataGate!.complete();
    await flush(tester);
    expect(listKey.currentState!.showingPreview, isFalse);
    expect(listKey.currentState!.loadedTransactionCount, 42);
    expect(controller.offset, closeTo(offset, 0.01));
    expect(
        tester
            .widget<DaySectionHeader>(
                find.byType(DaySectionHeader, skipOffstage: false).first)
            .expense,
        41 * 14);
    expect(listKey.currentState!.jumpToMonth(DateTime(2026, 6)), isTrue,
        reason:
            'Background handoff contains the remaining rows, including older months');
    await flush(tester);
    expect(
        find.byWidgetPredicate(
            (widget) =>
                widget is TransactionListItem && widget.happenedAt?.month == 6,
            skipOffstage: false),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'quick ledger switch discards late preview and full source; empty full emission never restores cache',
      (tester) async {
    repo.previewGates[1] = Completer<void>();
    await open(tester);
    expect(repo.subscriptions, isEmpty,
        reason: 'Full query cannot compete with first useful preview');
    selected.value = 2;
    await flush(tester);
    expect(
        tester
            .widget<TransactionListItem>(
                find.byType(TransactionListItem, skipOffstage: false))
            .amount,
        5);
    repo.previewGates[1]!.complete();
    await flush(tester);
    expect(
        tester
            .widget<TransactionListItem>(
                find.byType(TransactionListItem, skipOffstage: false))
            .amount,
        5);
    expect(repo.subscriptions, isNot(contains(1)));
    selected.value = 3;
    await flush(tester);
    expect(list(tester).sourceReady, isTrue);
    expect(visible(tester), isEmpty);
    selected.value = 2;
    await flush(tester);
    await db.customUpdate('DELETE FROM transactions WHERE ledger_id=2',
        updates: {db.transactions});
    await flush(tester);
    expect(visible(tester), isEmpty,
        reason: 'Authoritative empty stream must not fall back to preview');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'background relationship error keeps 20 complete rows and retries at the real list tail',
      (tester) async {
    repo.failFullMetadata = true;
    await open(tester);
    expect(visible(tester).first.tags.single.label, 'Complete label');
    listKey.currentState!.jumpToMonth(DateTime(2026, 6));
    controller.sliverController.jumpToIndex(21);
    await flush(tester);
    expect(
        find.byKey(const ValueKey('transaction-feed-error'),
            skipOffstage: false),
        findsOneWidget);
    expect(find.text('重试', skipOffstage: false), findsOneWidget);
    repo.failFullMetadata = false;
    await tester.tap(find.text('重试', skipOffstage: false));
    await flush(tester);
    expect(listKey.currentState!.showingPreview, isFalse);
    expect(listKey.currentState!.loadedTransactionCount, 42);
    expect(
        find.byWidgetPredicate(
            (widget) =>
                widget is TransactionListItem && widget.happenedAt?.month == 6,
            skipOffstage: false),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    logger.disposeForTesting();
  });

  testWidgets(
      'full-source failure retries without hiding preview; current snapshots do not reuse old splash FX data',
      (tester) async {
    final oldCache = await repo.getHomeTransactionPreview(ledgerId: 1);
    container.read(cachedTransactionsProvider.notifier).state = oldCache.rows;
    await db.customStatement(
        'UPDATE transactions SET native_amount=16 WHERE ledger_id=1');
    repo.failFullSource = true;
    await open(tester);
    expect(
        tester
            .widget<TransactionListItem>(
                find.byType(TransactionListItem, skipOffstage: false).first)
            .nativeAmount,
        16);
    expect(
        tester
            .widget<DaySectionHeader>(
                find.byType(DaySectionHeader, skipOffstage: false))
            .expense,
        41 * 16);
    controller.sliverController.jumpToIndex(21);
    await flush(tester);
    repo.failFullSource = false;
    await tester.tap(find.text('重试', skipOffstage: false));
    await flush(tester);
    expect(list(tester).transactions, hasLength(42));
    expect(listKey.currentState!.jumpToMonth(DateTime(2026, 6)), isTrue);
    await flush(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late old full stream cannot replace a newly selected ledger',
      (tester) async {
    repo.fullGates[1] = Completer<void>();
    await open(tester);
    expect(list(tester).sourceReady, isFalse);
    selected.value = 2;
    await flush(tester);
    expect(
        tester
            .widget<TransactionListItem>(
                find.byType(TransactionListItem, skipOffstage: false))
            .amount,
        5);
    repo.fullGates[1]!.complete();
    await flush(tester);
    expect(list(tester).ledgerId, 2);
    expect(
        tester
            .widget<TransactionListItem>(
                find.byType(TransactionListItem, skipOffstage: false))
            .amount,
        5);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'same-ledger live refresh retains complete old rows until all updated metadata is ready',
      (tester) async {
    await open(tester);
    final before = tester
        .getRect(find.byType(BeeTransactionRow, skipOffstage: false).first);
    repo.fullMetadataGate = Completer<void>();
    final newTag = await repo.createTag(name: 'Updated complete label');
    await db.transaction(() async {
      await db.customUpdate(
          'UPDATE transactions SET native_amount=18 WHERE id=1',
          updates: {db.transactions});
      await repo.updateTransactionTags(transactionId: 1, tagIds: [newTag]);
    });
    await flush(tester);
    expect(
        tester
            .widget<TransactionListItem>(
                find.byType(TransactionListItem, skipOffstage: false).first)
            .nativeAmount,
        14);
    expect(visible(tester).first.tags.single.label, 'Complete label');
    expect(
        tester
            .getRect(find.byType(BeeTransactionRow, skipOffstage: false).first),
        before);
    repo.fullMetadataGate!.complete();
    await flush(tester);
    expect(
        tester
            .widget<TransactionListItem>(
                find.byType(TransactionListItem, skipOffstage: false).first)
            .nativeAmount,
        18);
    expect(visible(tester).first.tags.single.label, 'Updated complete label');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a cold preview read failure offers a real retry before starting a full source',
      (tester) async {
    repo.failPreview = true;
    await open(tester);
    expect(repo.subscriptions, isEmpty);
    expect(find.byType(TransactionList), findsNothing);
    expect(find.text('重试'), findsOneWidget);
    repo.failPreview = false;
    await tester.tap(find.text('重试'));
    await flush(tester);
    expect(list(tester).transactions, hasLength(42));
    expect(visible(tester).first.tags.single.label, 'Complete label');
    expect(tester.takeException(), isNull);
  });
}
