import 'dart:async';
import 'dart:convert';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/sync_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes/fake_beecount_cloud_provider.dart';

class _Storage extends FakeBeeCountCloudStorageService {
  final downloads = <String>[];
  @override
  Future<String?> download({required String path}) {
    downloads.add(path);
    return super.download(path: path);
  }
}

class _Cloud extends FakeBeeCountCloudProvider {
  final snapshots = _Storage();
  @override
  CloudStorageService get storage => snapshots;
  @override
  Future<BeeCountCloudSharedResources> fetchSharedResources({
    required String ledgerId,
  }) async =>
      const BeeCountCloudSharedResources(
          ownerUserId: 'synthetic-other-owner',
          categories: [],
          accounts: [],
          tags: []);
}

/// Keep normal incremental sync separate from the bootstrap regression. Ledger
/// discovery, old replay and new hydration use the real engine and SQLite.
class _Engine extends SyncEngine {
  _Engine(
      {required super.db,
      required super.provider,
      required super.changeTracker,
      required super.repo});
  final syncCalls = <String>[];
  Completer<void>? syncGate;
  @override
  Future<SyncResult> sync({required String ledgerId}) async {
    syncCalls.add(ledgerId);
    await syncGate?.future;
    return const SyncResult();
  }
}

class _Runtime extends ActiveCloudRuntimeController {
  _Runtime(this.runtime);
  final ActiveCloudRuntime runtime;
  @override
  Future<ActiveCloudRuntime?> build() async => runtime;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late LocalRepository repo;
  late _Cloud cloud;
  late _Engine engine;
  late ActiveCloudRuntime runtime;
  ProviderContainer? container;
  late int own;
  late List<Map<String, Object?>> oldTransactions;

  Future<List<Map<String, Object?>>> rows(String table) async =>
      (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((row) => row.data)
          .toList();

  Future<void> eventually(FutureOr<bool> Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (!await condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Bootstrap condition not reached');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<void> remoteLedger(String id, {bool corrupt = false}) async {
    cloud.pushFakeLedger(
        ledgerId: id,
        ledgerName: id,
        role: 'editor',
        isShared: true,
        monthStartDay: 8);
    await cloud.storage.upload(
        path: id,
        data: corrupt
            ? '{broken'
            : jsonEncode({
                'ledgerSyncId': id,
                'ledgerName': id,
                'currency': 'CNY',
                'monthStartDay': 8,
                'count': 1,
                'items': [
                  {
                    'syncId': '$id-tx',
                    'type': 'expense',
                    'amount': 0.31,
                    'happenedAt': '2026-10-25T12:00:00Z',
                    'note': 'target current value',
                    'excludeFromStats': false,
                    'excludeFromBudget': false,
                  }
                ],
                'budgets': [],
              }));
  }

  Future<void> start({bool noCurrentLedger = false}) async {
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => noCurrentLedger ? 0 : own),
      activeCloudRuntimeProvider.overrideWith(() => _Runtime(runtime)),
      beecountCloudProviderInstance.overrideWith((ref) async => null),
    ]);
    await container!.read(activeCloudRuntimeProvider.future);
    expect(container!.read(syncServiceProvider), same(engine));
  }

  Future<void> normalSyncFinished() =>
      eventually(() => container!.read(syncGenerationProvider) > 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    for (final channel in [
      'dev.fluttercommunity.plus/connectivity',
      'dev.fluttercommunity.plus/connectivity_status'
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              MethodChannel(channel), (call) async => null);
    }
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    final tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
    cloud = _Cloud();
    engine =
        _Engine(db: db, provider: cloud, changeTracker: tracker, repo: repo);
    own = await db.into(db.ledgers).insert(LedgersCompanion.insert(
        name: 'original-eight',
        syncId: const Value('original-eight'),
        monthStartDay: const Value(8)));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: own,
        type: 'expense',
        amount: 0.37,
        happenedAt: Value(DateTime.utc(2026, 10, 25, 12, 49)),
        note: const Value('current note [App backpush]'),
        syncId: const Value('original-current-tx')));
    oldTransactions = await rows('transactions');
    cloud.pushFakeLedger(
        ledgerId: 'original-eight',
        ledgerName: 'original-eight',
        monthStartDay: 8);
    // Obsolete remote events are below the acknowledged cursor. Their later
    // self-device corrections are server-filtered: replaying cannot restore them.
    cloud.pushFakeChange(
        entityType: 'ledger',
        entitySyncId: 'original-eight',
        ledgerId: 'original-eight',
        payload: {'ledgerName': 'original-eight', 'monthStartDay': 1});
    cloud.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: 'original-current-tx',
        ledgerId: 'original-eight',
        payload: {
          'syncId': 'original-current-tx',
          'type': 'expense',
          'amount': 0.37,
          'happenedAt': '2026-10-25T12:49:53Z',
          'note': 'obsolete remote note',
        });
    await engine.appCursor.commit(77);
    runtime = ActiveCloudRuntime(
        config: const CloudServiceConfig(
            type: CloudBackendType.beecountCloud,
            name: 'Synthetic bootstrap',
            beecountCloudBaseUrl: 'https://synthetic.invalid'),
        provider: cloud,
        auth: cloud.auth,
        syncService: engine,
        syncEngine: engine,
        identity: 'synthetic-bootstrap-only');
  });

  tearDown(() async {
    if (engine.syncGate case final gate? when !gate.isCompleted) {
      gate.complete();
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));
    container?.dispose();
    container = null;
    await runtime.close();
    await Future<void>.delayed(Duration.zero);
    await db.close();
    for (final channel in [
      'dev.fluttercommunity.plus/connectivity',
      'dev.fluttercommunity.plus/connectivity_status'
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), null);
    }
  });

  test(
      'bootstrap discovers target without replaying existing month note time or cursor',
      () async {
    await remoteLedger('new-shared');
    await start();
    await normalSyncFinished();
    final original = await (db.select(db.ledgers)
          ..where((row) => row.id.equals(own)))
        .getSingle();
    expect(original.monthStartDay, 8);
    expect((await rows('transactions')).where((row) => row['ledger_id'] == own),
        oldTransactions);
    final target = await (db.select(db.transactions)
          ..where((row) => row.syncId.equals('new-shared-tx')))
        .getSingleOrNull();
    expect(target, isNotNull);
    expect(target!.ledgerId, isNot(own));
    expect(target.amount, 0.31);
    expect(cloud.snapshots.downloads, ['new-shared']);
    expect(cloud.pullCalls, isEmpty);
    expect(await engine.appCursor.read(), 77);
    expect(engine.syncCalls, [own.toString()]);
    expect(container!.read(lastSyncErrorProvider), isNull);
  });

  test('bootstrap keeps acknowledged transaction note and exact timestamp',
      () async {
    await remoteLedger('new-shared');
    await start();
    await normalSyncFinished();
    expect((await rows('transactions')).where((row) => row['ledger_id'] == own),
        oldTransactions);
    expect(await engine.appCursor.read(), 77);
  });

  test('bootstrap without current ledger hydrates discovered target only',
      () async {
    await remoteLedger('new-shared');
    await start(noCurrentLedger: true);
    await eventually(
        () async => (await db.select(db.transactions).get()).length > 1);
    expect(cloud.snapshots.downloads, ['new-shared']);
    expect(engine.syncCalls, isEmpty);
    expect(cloud.pullCalls, isEmpty);
    expect(await engine.appCursor.read(), 77);
    expect((await rows('transactions')).where((row) => row['ledger_id'] == own),
        oldTransactions);
  });

  test('bootstrap with no new ledger preserves normal sync and never hydrates',
      () async {
    await start();
    await normalSyncFinished();
    expect(cloud.snapshots.downloads, isEmpty);
    expect(cloud.pullCalls, isEmpty);
    expect(await rows('transactions'), oldTransactions);
    expect(engine.syncCalls, [own.toString()]);
    expect(await engine.appCursor.read(), 77);
  });

  test(
      'bootstrap hydrates each new sync id once and excludes original and null seeds',
      () async {
    await db
        .into(db.ledgers)
        .insert(LedgersCompanion.insert(name: 'local seed'));
    await remoteLedger('new-one');
    await remoteLedger('new-two');
    await start();
    await normalSyncFinished();
    expect(cloud.snapshots.downloads, ['new-one', 'new-two']);
    expect(await db.select(db.transactions).get(), hasLength(3));
    expect(await engine.appCursor.read(), 77);
    expect(engine.syncCalls, [own.toString()]);
  });

  test('one bad new snapshot does not prevent another target or normal sync',
      () async {
    await remoteLedger('new-broken', corrupt: true);
    await remoteLedger('new-good');
    await start();
    await normalSyncFinished();
    expect(cloud.snapshots.downloads, ['new-broken', 'new-good']);
    expect((await db.select(db.transactions).get()).map((row) => row.syncId),
        contains('new-good-tx'));
    expect((await rows('transactions')).where((row) => row['ledger_id'] == own),
        oldTransactions);
    expect(engine.syncCalls, [own.toString()]);
    expect(cloud.pullCalls, isEmpty);
  });

  test('provider rebuild preserves existing bootstrap single flight', () async {
    engine.syncGate = Completer<void>();
    await remoteLedger('new-shared');
    await start();
    await eventually(() => engine.syncCalls.length == 1);
    container!.invalidate(syncServiceProvider);
    expect(container!.read(syncServiceProvider), same(engine));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(engine.syncCalls, hasLength(1));
    expect(cloud.snapshots.downloads, ['new-shared']);
    engine.syncGate!.complete();
    await normalSyncFinished();
    expect(engine.syncCalls, [own.toString()]);
  });
}
