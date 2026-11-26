import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

class _ReceiptProvider extends FakeBeeCountCloudProvider {
  late Future<BeeCountCloudPushResult> Function(List<Map<String, dynamic>>)
      send;

  @override
  Future<BeeCountCloudPushResult> pushChanges({
    required List<Map<String, dynamic>> changes,
  }) =>
      send(changes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late BeeDatabase db;
  late ChangeTracker tracker;
  late LocalRepository repo;
  late SyncEngine engine;
  late _ReceiptProvider provider;
  late int ledgerId;

  void open() {
    db = BeeDatabase.forTesting(
        NativeDatabase(File('${directory.path}/sync.sqlite')));
    tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
    engine = SyncEngine(
        db: db, provider: provider, changeTracker: tracker, repo: repo);
  }

  Future<int> add(String syncId, double amount) =>
      db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: amount,
          syncId: Value(syncId),
          happenedAt: Value(DateTime.utc(2025))));
  Future<void> edit(int id, double amount) =>
      repo.updateTransaction(id: id, type: 'expense', amount: amount);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('bee-outbox-');
    provider = _ReceiptProvider();
    open();
    ledgerId = await db.into(db.ledgers).insert(
        LedgersCompanion.insert(name: 'L', syncId: const Value('ledger-test')));
  });
  tearDown(() async {
    await engine.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  test('mixed receipts acknowledge only accepted or reconciled operations',
      () async {
    final t1 = await add('one', 1);
    final t2 = await add('two', 2);
    final t3 = await add('three', 3);
    for (final id in [t1, t2, t3]) {
      await edit(id, 35);
    }
    provider.pushFakeLedgerSnapshot(ledgerId: 'ledger-test');
    provider.send = (changes) async {
      expect(
          changes.map((row) => row['entity_sync_id']), ['one', 'two', 'three']);
      return const BeeCountCloudPushResult([
        BeeCountCloudPushItem('accepted', changeId: 6),
        BeeCountCloudPushItem('conflict',
            reason: 'lww',
            changeId: 7,
            winner: BeeCountCloudSyncChange(
                changeId: 7,
                ledgerId: 'ledger-test',
                entityType: 'transaction',
                entitySyncId: 'two',
                action: 'upsert',
                payload: {
                  'type': 'expense',
                  'amount': 22,
                  'happenedAt': '2026-01-01T00:00:00Z'
                })),
        BeeCountCloudPushItem('rejected', reason: 'permission'),
      ]);
    };
    final refreshed = engine.events
        .where((e) => e is PullCompleted)
        .cast<PullCompleted>()
        .first;
    final result = await engine.sync(ledgerId: '$ledgerId');
    expect((await refreshed).applied, 1);
    expect([result.pushed, result.conflicts, result.hasError], [1, 1, true]);
    expect((await repo.getTransactionById(t2))!.amount, 22);
    expect((await tracker.getUnpushedChanges()).single.entitySyncId, 'three');
    final loser = await (db.select(db.localChanges)
          ..where((r) => r.entitySyncId.equals('two')))
        .getSingle();
    expect(jsonDecode(loser.wireJson!)['change']['payload']['amount'], 35);
  });

  test(
      'an old same-second queue survives a lost reply and a full database reopen',
      () async {
    final id = await add('old', 18);
    final second = DateTime.utc(2025, 6, 7, 8, 9);
    for (int i = 0; i < 2; i++) {
      await db.into(db.localChanges).insert(LocalChangesCompanion.insert(
          entityType: 'transaction',
          entityId: id,
          entitySyncId: 'old',
          ledgerId: ledgerId,
          action: 'update',
          createdAt: Value(second)));
    }
    // Reopen an on-disk v36 table, which recorded no operations or immutable
    // edit values. The surviving database row is the recoverable version.
    await db.customStatement('DROP INDEX IF EXISTS idx_local_changes_entity');
    for (final column in [
      'operation_id',
      'write_micros',
      'wire_json',
      'deferred_json',
      'confirmed_change_id',
      'receipt_scope'
    ]) {
      await db.customStatement('ALTER TABLE local_changes DROP COLUMN $column');
    }
    await db.customStatement('PRAGMA user_version = 36');
    await engine.dispose();
    await db.close();
    open();
    late List<Map<String, dynamic>> sent;
    provider.send = (changes) async {
      sent = changes;
      throw CloudStorageException('simulated lost response');
    };
    await expectLater(
        engine.push('$ledgerId'), throwsA(isA<CloudStorageException>()));
    expect(sent.map((row) => row['operation_id']).toSet(), hasLength(2));
    expect(sent.map((row) => row['updated_at']).toSet(), hasLength(2));
    expect(
        DateTime.parse(sent.last['updated_at'])
            .difference(second)
            .inMicroseconds,
        1);
    expect(sent.map((row) => row['payload']['amount']), [18, 18]);
    await engine.dispose();
    await db.close();
    open();
    await edit(id, 31);
    provider.send = (changes) async {
      expect(changes.take(2).toList(), sent);
      expect(changes.last['payload']['amount'], 31);
      return BeeCountCloudPushResult(List.generate(changes.length,
          (i) => BeeCountCloudPushItem('accepted', changeId: i + 1)));
    };
    expect(await engine.push('$ledgerId'), 3);
    expect(await tracker.getUnpushedCount(), 0);
    expect((await repo.getTransactionById(id))!.amount, 31);
  });

  test(
      'full upload settles the captured row, keeps a refused row and an in-flight edit',
      () async {
    final t1 = await add('first', 10);
    final t2 = await add('second', 20);
    await edit(t1, 11);
    await edit(t2, 21);
    final started = Completer<void>(), release = Completer<void>();
    provider.send = (changes) async {
      started.complete();
      await release.future;
      return BeeCountCloudPushResult([
        for (final c in changes)
          c['entity_sync_id'] == 'second'
              ? const BeeCountCloudPushItem('rejected', reason: 'permission')
              : const BeeCountCloudPushItem('accepted', changeId: 12)
      ]);
    };
    final upload = engine.fullPush(ledgerId: ledgerId);
    final expectation =
        expectLater(upload, throwsA(isA<CloudStorageException>()));
    await started.future;
    await edit(t1, 19);
    release.complete();
    await expectation;
    final pending = await tracker.getUnpushedChanges();
    expect(pending.map((c) => c.entitySyncId), ['second', 'first']);
    expect(jsonDecode(pending.last.payloadJson!)['amount'], 19);
    expect((await repo.getTransactionById(t1))!.amount, 19);
  });

  test(
      'interrupted full upload of pre-journal entities can resume incrementally',
      () async {
    await add('historical', 48);
    late List<Map<String, dynamic>> captured;
    provider.send = (changes) async {
      captured = changes;
      throw CloudStorageException('lost acknowledgement');
    };
    await expectLater(engine.fullPush(ledgerId: ledgerId),
        throwsA(isA<CloudStorageException>()));
    await engine.dispose();
    await db.close();
    open();
    provider.send = (changes) async {
      expect(changes, captured);
      return BeeCountCloudPushResult(
          List.filled(changes.length, const BeeCountCloudPushItem('accepted')));
    };
    expect(await engine.push('$ledgerId'), 2);
    expect(await tracker.getUnpushedCount(), 0);
  });

  test(
      'switching account during upload leaves the old operation unacknowledged',
      () async {
    final id = await add('original-account', 10);
    await edit(id, 19);
    provider.send = (changes) async {
      (provider.auth as FakeBeeCountCloudAuthService)
          .setLoggedIn(userId: 'second-user', deviceId: 'second-device');
      return const BeeCountCloudPushResult(
          [BeeCountCloudPushItem('accepted', changeId: 9)]);
    };
    await expectLater(
        engine.push('$ledgerId'), throwsA(isA<CloudStorageException>()));
    expect(await tracker.getUnpushedCount(), 1);
  });

  test(
      'attachment adds, reordering, uploaded IDs and removal queue only attachment fields',
      () async {
    final id = await add('attachment-parent', 10);
    final a = await repo.createAttachment(transactionId: id, fileName: 'a');
    final b = await repo.createAttachment(transactionId: id, fileName: 'b');
    await repo.updateAttachmentSortOrders(
        [(id: b, sortOrder: 0), (id: a, sortOrder: 1)]);
    await repo.updateAttachmentCloudRef(b, cloudFileId: 'cloud-b');
    await repo.deleteAttachmentByFileName('a');
    await repo.deleteAttachmentsByTransaction(id);
    final patches = (await tracker.getUnpushedChanges())
        .map((row) => jsonDecode(row.payloadJson!) as Map<String, dynamic>)
        .toList();
    expect(patches, hasLength(6));
    expect(
        patches.every(
            (patch) => patch.length == 1 && patch.containsKey('attachments')),
        isTrue);
    expect((patches[2]['attachments'] as List).map((a) => a['fileName']),
        ['b', 'a']);
    expect(patches[3]['attachments'][0]['cloudFileId'], 'cloud-b');
    expect((patches[4]['attachments'] as List).single['fileName'], 'b');
    expect(patches.last['attachments'], isEmpty);
  });

  test('truncated and contradictory receipts cannot clear the queue', () {
    for (final malformed in [
      {'accepted': 1, 'rejected': 1},
      {
        'accepted': 1,
        'rejected': 1,
        'results': [
          {'status': 'accepted'}
        ]
      },
      {
        'accepted': 2,
        'rejected': 0,
        'results': [
          {'status': 'accepted'},
          {'status': 'rejected'}
        ]
      },
    ]) {
      expect(() => BeeCountCloudPushResult.fromJson(malformed, 2),
          throwsA(isA<CloudStorageException>()));
    }
  });
}
