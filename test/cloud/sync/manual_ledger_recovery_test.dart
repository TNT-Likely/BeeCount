import 'dart:convert';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes/fake_beecount_cloud_provider.dart';

class _Storage extends FakeBeeCountCloudStorageService {
  Future<void> Function()? duringDownload;
  final reads = <String>[];
  @override
  Future<String?> download({required String path}) async {
    reads.add(path);
    final content = await super.download(path: path);
    await duringDownload?.call();
    return content;
  }
}

class _Cloud extends FakeBeeCountCloudProvider {
  final snapshots = _Storage();
  @override
  CloudStorageService get storage => snapshots;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late LocalRepository repo;
  late ChangeTracker tracker;
  late SyncEngine engine;
  late _Cloud cloud;
  late int ledger, other, transaction;
  late Map<String, dynamic> snapshot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
    cloud = _Cloud();
    engine =
        SyncEngine(db: db, provider: cloud, changeTracker: tracker, repo: repo);
    ledger = await db.into(db.ledgers).insert(
        LedgersCompanion.insert(name: 'Before', syncId: const Value('target')));
    other = await db.into(db.ledgers).insert(
        LedgersCompanion.insert(name: 'Other', syncId: const Value('other')));
    for (final (id, sid) in [(ledger, 'bill'), (other, 'other-bill')]) {
      final row = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
              ledgerId: id,
              type: 'expense',
              amount: 7,
              syncId: Value(sid),
              note: const Value('obsolete')));
      if (id == ledger) transaction = row;
    }
    final oldTag = await db
        .into(db.tags)
        .insert(TagsCompanion.insert(name: 'Old', syncId: const Value('old')));
    await db.into(db.transactionTags).insert(TransactionTagsCompanion.insert(
        transactionId: transaction, tagId: oldTag));
    snapshot = {
      'ledgerSyncId': 'target',
      'ledgerName': 'Recovered',
      'currency': 'JPY',
      'monthStartDay': 8,
      'count': 1,
      'items': [
        <String, dynamic>{
          'syncId': 'bill',
          'type': 'expense',
          'amount': 24.5,
          'happenedAt': '2026-11-26T00:00:00Z',
          'excludeFromStats': false,
          'excludeFromBudget': false,
          'categoryId': 'child',
          'accountId': 'bank',
        }
      ],
      'accounts': [
        {'syncId': 'bank', 'name': 'Bank', 'initialBalance': 12}
      ],
      'categories': [
        {
          'syncId': 'child',
          'name': 'Child',
          'kind': 'expense',
          'level': 2,
          'parentSyncId': 'parent'
        },
        {'syncId': 'parent', 'name': 'Parent', 'kind': 'expense', 'level': 1}
      ],
      'tags': [
        {'syncId': 'new-tag', 'name': 'New'}
      ],
      'budgets': [],
    };
  });
  tearDown(() async {
    await engine.dispose();
    await db.close();
  });
  Future<void> store(Map<String, dynamic> record) =>
      cloud.storage.upload(path: 'target', data: jsonEncode(record));

  test(
      'manual download repairs a skipped ledger name and an existing amount even when unrelated deltas arrive',
      () async {
    for (var i = 1; i <= 4; i++) {
      cloud.pushFakeChange(
          entityType: 'ledger',
          entitySyncId: 'target',
          ledgerId: 'target',
          payload: {
            'ledgerName': i == 3 ? 'Recovered' : 'older',
            'currency': 'CNY'
          });
    }
    await engine.appCursor.commit(4);
    cloud.pushFakeChange(
        entityType: 'tag',
        entitySyncId: 'unrelated',
        payload: {'name': 'Unrelated'});
    await store(snapshot);
    await engine.downloadAndRestoreToCurrentLedger(ledgerId: ledger);
    expect(cloud.snapshots.reads, ['target']);
    expect(cloud.pullCalls.every((call) => (call.since ?? 0) >= 4), isTrue);
    final restored = (await repo.getLedgerById(ledger))!;
    expect([restored.name, restored.currency, restored.monthStartDay],
        ['Recovered', 'JPY', 8]);
    final bill = (await repo.getTransactionById(transaction))!;
    expect([bill.amount, bill.note], [24.5, null]);
    expect((await repo.getCategoryById(bill.categoryId!))!.name, 'Child');
    expect((await repo.getAccount(bill.accountId!))!.name, 'Bank');
    expect(await repo.getTagsForTransaction(transaction), isEmpty);
    expect((await repo.getAllTags()).map((tag) => tag.name),
        containsAll(['New', 'Unrelated']));
    expect((await repo.getLedgerById(other))!.name, 'Other');
    final untouched = await (db.select(db.transactions)
          ..where((r) => r.ledgerId.equals(other)))
        .getSingle();
    expect([untouched.amount, untouched.note], [7, 'obsolete']);
    expect(await tracker.getUnpushedChanges(), isEmpty);
  });

  test(
      'pending and newly acknowledged edits both prevent stale download overwrite',
      () async {
    await store(snapshot);
    Future<void> edit(double amount) => repo.updateTransaction(
        id: transaction,
        type: 'expense',
        amount: amount,
        nativeAmount: amount,
        currencyCode: 'CNY',
        note: 'edited');
    await edit(17);
    await expectLater(
        engine.downloadAndRestoreToCurrentLedger(ledgerId: ledger),
        throwsStateError);
    expect(cloud.snapshots.reads, isEmpty);
    await tracker.markPushed(
        (await tracker.getUnpushedChanges()).map((r) => r.id).toList());
    cloud.snapshots.duringDownload = () async {
      await edit(37);
      await tracker.markPushed(
          (await tracker.getUnpushedChanges()).map((r) => r.id).toList());
    };
    await expectLater(
        engine.downloadAndRestoreToCurrentLedger(ledgerId: ledger),
        throwsStateError);
    expect((await repo.getTransactionById(transaction))!.amount, 37);
    expect((await repo.getLedgerById(ledger))!.name, 'Before');
  });

  test(
      'invalid relationships roll back metadata and newly restored dictionary identities',
      () async {
    (snapshot['items'] as List).single['accountId'] = 'missing';
    await store(snapshot);
    await expectLater(
        engine.runFullPull(ledgerId: ledger), throwsFormatException);
    expect((await repo.getLedgerById(ledger))!.name, 'Before');
    expect((await repo.getTransactionById(transaction))!.amount, 7);
    expect(await db.select(db.accounts).get(), isEmpty);
    expect(await db.select(db.categories).get(), isEmpty);
    expect((await db.select(db.tags).get()).map((t) => t.name), ['Old']);
  });

  test(
      'old name-only relationships resolve uniquely and missing old flags preserve local flags',
      () async {
    final item = (snapshot['items'] as List).single as Map<String, dynamic>;
    item.remove('categoryId');
    item.remove('accountId');
    item.remove('excludeFromStats');
    item.addAll({
      'categoryName': 'Child',
      'categoryKind': 'expense',
      'accountName': 'Bank',
      'tags': 'New'
    });
    await (db.update(db.transactions)..where((r) => r.id.equals(transaction)))
        .write(const TransactionsCompanion(excludeFromStats: Value(true)));
    await store(snapshot);
    await engine.runFullPull(ledgerId: ledger);
    final bill = (await repo.getTransactionById(transaction))!;
    expect(bill.excludeFromStats, true);
    expect((await repo.getAccount(bill.accountId!))!.name, 'Bank');
    expect((await repo.getCategoryById(bill.categoryId!))!.name, 'Child');
    expect((await repo.getTagsForTransaction(transaction)).single.name, 'New');
  });

  test('unscoped legacy exports retain their append and dedup semantics',
      () async {
    await store({
      'version': 6,
      'currency': 'CNY',
      'items': [
        {
          'syncId': 'legacy-id',
          'type': 'expense',
          'amount': 6,
          'happenedAt': '2026-01-01T00:00:00Z',
          'categoryName': 'Legacy'
        }
      ]
    });
    await engine.runFullPull(ledgerId: ledger);
    await engine.runFullPull(ledgerId: ledger);
    final rows = await (db.select(db.transactions)
          ..where((r) => r.ledgerId.equals(ledger)))
        .get();
    expect(rows.map((r) => r.syncId), unorderedEquals(['bill', 'legacy-id']));
    expect((await repo.getLedgerById(ledger))!.name, 'Before');
    expect(await tracker.getUnpushedChanges(), isEmpty);
  });
}
