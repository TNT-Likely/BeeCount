import 'dart:async';
import 'dart:convert';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/cloud/sync_service.dart' show SyncDiff;
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes/fake_beecount_cloud_provider.dart';

class _LedgerListProvider extends FakeBeeCountCloudProvider {
  final requested = Completer<void>();
  final release = Completer<void>();
  bool waitForRelease = false;

  @override
  Future<List<BeeCountCloudReadLedger>> readLedgers() async {
    final response = await super.readLedgers();
    if (waitForRelease) {
      requested.complete();
      await release.future;
    }
    return response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late LocalRepository repo;
  late ChangeTracker tracker;
  late _LedgerListProvider provider;
  late SyncEngine engine;
  late int id;
  const remoteId = 'editable-ledger';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
    provider = _LedgerListProvider();
    engine = SyncEngine(
        db: db, repo: repo, provider: provider, changeTracker: tracker);
    id = await db.into(db.ledgers).insert(LedgersCompanion.insert(
        name: 'Original',
        currency: const Value('CNY'),
        syncId: const Value(remoteId)));
  });

  tearDown(() async {
    await engine.dispose();
    await db.close();
  });

  test('remote list and incremental merge update only locally unedited fields',
      () async {
    await repo.updateLedger(id: id, monthStartDay: 17);
    final change = (await tracker.getUnpushedChangesForLedger(id)).single;
    expect(jsonDecode(change.payloadJson!), {'monthStartDay': 17});
    provider.pushFakeLedger(
        ledgerId: remoteId,
        ledgerName: 'Web',
        currency: 'USD',
        monthStartDay: 1,
        memberCount: 2,
        isShared: true);
    await engine.syncLedgersFromServer();
    final read = (await repo.getLedgerById(id))!;
    expect([read.name, read.currency, read.monthStartDay, read.memberCount],
        ['Web', 'USD', 17, 2]);
    provider.pushFakeChange(
        ledgerId: remoteId,
        entitySyncId: remoteId,
        entityType: 'ledger',
        payload: {'ledgerName': 'New Web', 'monthStartDay': 5});
    await engine.pull('');
    final event = (await repo.getLedgerById(id))!;
    expect([event.name, event.monthStartDay], ['New Web', 17]);
  });

  test(
      'legacy dirty row without a patch retains fields and accepts member metadata',
      () async {
    await tracker.recordLedgerChange(
        entityType: 'ledger',
        entityId: id,
        entitySyncId: remoteId,
        ledgerId: id,
        action: 'update');
    provider.pushFakeLedger(
        ledgerId: remoteId,
        ledgerName: 'Web',
        currency: 'USD',
        monthStartDay: 19,
        memberCount: 3,
        isShared: true);
    await engine.syncLedgersFromServer();
    final row = (await repo.getLedgerById(id))!;
    expect([row.name, row.currency, row.monthStartDay, row.memberCount],
        ['Original', 'CNY', 1, 3]);
  });

  test(
      'ack during a slow list request leaves preexisting and new local edits intact',
      () async {
    await repo.updateLedgerName(id: id, name: 'Pending before request');
    provider.pushFakeLedger(
        ledgerId: remoteId,
        ledgerName: 'Old',
        currency: 'USD',
        monthStartDay: 1);
    provider.waitForRelease = true;
    final listing = engine.syncLedgersFromServer();
    await provider.requested.future;
    await repo.updateLedger(id: id, monthStartDay: 17);
    final dirty = await tracker.getUnpushedChangesForLedger(id);
    await tracker.markPushed(dirty.map((c) => c.id).toList());
    provider.release.complete();
    await listing;
    final row = (await repo.getLedgerById(id))!;
    expect([row.name, row.currency, row.monthStartDay],
        ['Pending before request', 'USD', 17]);
  });

  test('base currency, derived amounts and journal roll back together',
      () async {
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: id,
        type: 'expense',
        amount: 12,
        happenedAt: Value(DateTime.utc(2026, 11, 1)),
        syncId: const Value('usd-tx'),
        currencyCode: const Value('USD'),
        nativeAmount: const Value(86.4)));
    await db.customStatement(
        "CREATE TRIGGER fail_tx_journal BEFORE INSERT ON local_changes "
        "WHEN NEW.entity_type='transaction' BEGIN SELECT RAISE(ABORT, 'test interruption'); END");
    await expectLater(
        repo.updateLedgerAndRecalculateAmounts(id: id, currency: 'USD'),
        throwsA(anything));
    expect((await repo.getLedgerById(id))!.currency, 'CNY');
    expect((await repo.getTransactionBySyncId('usd-tx'))!.nativeAmount, 86.4);
    expect(await tracker.getUnpushedCount(), 0);
    await db.customStatement('DROP TRIGGER fail_tx_journal');
    expect(
        await repo.updateLedgerAndRecalculateAmounts(id: id, currency: 'USD'),
        1);
    expect((await repo.getLedgerById(id))!.currency, 'USD');
    expect((await repo.getTransactionBySyncId('usd-tx'))!.nativeAmount, 12);
    expect(await tracker.getUnpushedCount(), 2);
  });

  test('cached ledger status follows changes to the account-wide queue',
      () async {
    provider.pushFakeLedgerSnapshot(ledgerId: remoteId);
    expect((await engine.getStatus(ledgerId: id)).diff, SyncDiff.inSync);
    await tracker.recordUserGlobalChange(
        entityType: 'tag', entityId: 1, entitySyncId: 't', action: 'update');
    expect((await engine.getStatus(ledgerId: id)).diff, SyncDiff.localNewer);
    final pending = (await tracker.getUnpushedChangesForLedger(0)).single;
    await tracker.markPushed([pending.id]);
    expect((await engine.getStatus(ledgerId: id)).diff, SyncDiff.inSync);
  });
}
