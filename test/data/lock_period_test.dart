import 'dart:convert';
import 'dart:io';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/cloud/transactions_json.dart';
import 'package:beecount/cloud/transactions_sync_manager.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/data/repositories/local/lock_period_repository.dart';
import 'package:beecount/services/data_import_service.dart';
import 'package:beecount/utils/date_in_tz.dart';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cloud/sync/_fakes/fake_beecount_cloud_provider.dart';

/// S1-01a App 侧数据通道验收。本卡无 UI 入口,所有 lock_period 数据
/// 一律通过仓储 / JSON / 测试脚本构造。

File _sourceFile(String relativePath) {
  var dir = Directory.current;
  while (true) {
    final candidate = File('${dir.path}${Platform.pathSeparator}$relativePath');
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return File(relativePath);
}

Map<String, dynamic> _basePayload() => {
      'items': [
        {
          'syncId': 'tx-1',
          'type': 'expense',
          'amount': 12.34,
          'happenedAt': '2026-11-27T12:00:00Z',
          'note': 'coffee',
        }
      ],
    };

String _snapshot({bool withLockPeriods = true}) {
  final data = <String, dynamic>{
    'ledgerSyncId': 'hydrate-ledger',
    'count': 1,
    'items': [
      {
        'syncId': 'hydrate-tx',
        'type': 'expense',
        'amount': 9.99,
        'happenedAt': '2026-11-27T12:00:00Z',
        'excludeFromStats': false,
        'excludeFromBudget': false,
      }
    ],
    'budgets': [],
  };
  if (withLockPeriods) {
    data['lockPeriods'] = [
      {
        'syncId': 'hydrate-lp',
        'lockDate': '2026-11-27',
        'batchNo': 1,
        'lockedBy': 'local',
        // Cloud 侧 DateTime(timezone=True) 下发的 +08:00 偏移。
        'lockedAt': '2026-11-27T20:00:00+08:00',
      }
    ];
  }
  return jsonEncode(data);
}

class _Storage extends FakeBeeCountCloudStorageService {}

class _Cloud extends FakeBeeCountCloudProvider {
  final storageFake = _Storage();

  @override
  CloudStorageService get storage => storageFake;
}

class _Engine extends SyncEngine {
  _Engine({
    required super.db,
    required super.provider,
    required super.changeTracker,
    required super.repo,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  for (final channel in [
    'dev.fluttercommunity.plus/connectivity',
    'dev.fluttercommunity.plus/connectivity_status'
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            MethodChannel(channel), (call) async => null);
  }

  late BeeDatabase db;
  late LocalRepository repo;
  late LockPeriodRepository lockRepo;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db, changeTracker: ChangeTracker(db));
    lockRepo = LockPeriodRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('fingerprint (§5.3)', () {
    test('missing key == empty list != one row', () {
      final a = _basePayload();
      final b = <String, dynamic>{..._basePayload(), 'lockPeriods': []};
      final c = <String, dynamic>{
        ..._basePayload(),
        'lockPeriods': [
          {
            'syncId': 'lp-1',
            'lockDate': '2026-11-27',
            'batchNo': 1,
            'lockedBy': 'local',
            'lockedAt': '2026-11-27T12:00:00Z',
          }
        ],
      };

      final fpA = contentFingerprintFromPayload(a);
      expect(fpA, contentFingerprintFromPayload(b),
          reason: 'lockPeriods 缺键与空数组必须同指纹');
      expect(fpA, isNot(contentFingerprintFromPayload(c)),
          reason: '非空锁账必须改变指纹');
    });

    test('both fingerprint sites delegate to the shared helper', () {
      final source = _sourceFile('lib/cloud/transactions_sync_manager.dart')
          .readAsStringSync();
      final calls = RegExp(r'contentFingerprintFromPayload\(')
          .allMatches(source)
          .length;
      // 1 处定义 + :870 委托 + :1395 委托
      expect(calls, greaterThanOrEqualTo(3));
    });
  });

  test('lockedAt parser: Z / +08:00 / no suffix normalize identically', () {
    final expected = normalizeUtcIso8601('2026-11-27T12:00:00Z');
    expect(normalizeUtcIso8601('2026-11-27T20:00:00+08:00'), expected);
    expect(normalizeUtcIso8601('2026-11-27T12:00:00'), expected);
    expect(parseUtcIso8601('2026-11-27T12:00:00')?.isUtc, isTrue);
  });

  test('repository CRUD + MAX(lock_date) + MAX(batch_no)+1', () async {
    final first = await lockRepo.upsertBySyncId(
      syncId: 'lp-a',
      ledgerId: 1,
      lockDate: '2026-11-01',
      batchNo: null,
      lockedBy: 'local',
      lockedAt: '2026-11-02T00:00:00Z',
    );
    expect(first.batchNo, 1);

    final second = await lockRepo.createLocal(
      syncId: 'lp-b',
      ledgerId: 1,
      lockDate: '2026-12-15',
    );
    expect(second.batchNo, 2);

    final updated = await lockRepo.upsertBySyncId(
      syncId: 'lp-a',
      ledgerId: 1,
      lockDate: '2026-12-20',
      batchNo: 3,
      lockedBy: 'tester',
      lockedAt: '2026-12-21T00:00:00Z',
    );
    expect(updated.id, first.id, reason: 'upsert by syncId 不产生新行');
    expect((await lockRepo.listForLedger(1)).length, 2);
    expect(await lockRepo.effectiveLockDate(1), '2026-12-20');
    expect(await lockRepo.nextBatchNo(1), 4);

    await lockRepo.deleteBySyncId('lp-b');
    expect(await lockRepo.getBySyncId('lp-b'), isNull);
    expect(await lockRepo.effectiveLockDate(1), '2026-12-20');
    expect(await lockRepo.nextBatchNo(1), 4);

    expect(await lockRepo.deleteForLedger(1), 1);
    expect(await lockRepo.effectiveLockDate(1), isNull);
    expect(await lockRepo.nextBatchNo(1), 1);
  });

  test('local create registers ledger-scoped lock_period change', () async {
    final tracker = ChangeTracker(db);
    final trackedRepo = LockPeriodRepository(db, trackerGetter: () => tracker);
    await trackedRepo.createLocal(
        syncId: 'lp-tracked', ledgerId: 7, lockDate: '2026-11-27');
    final changes = await (db.select(db.localChanges)
          ..where((c) => c.entityType.equals('lock_period')))
        .get();
    expect(changes, hasLength(1));
    expect(changes.single.ledgerId, 7);
    expect(changes.single.entitySyncId, 'lp-tracked');
  });

  test('migration helper rerun does not duplicate lock_periods table', () async {
    final migrator = d.Migrator(db);
    await db.createTableIfMissingForTest(
        migrator, 'lock_periods', db.lockPeriods);
    await db.createTableIfMissingForTest(
        migrator, 'lock_periods', db.lockPeriods);
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='lock_periods'",
        )
        .get();
    expect(tables.length, 1);
  });

  test('hydration (sync path) accepts new lockPeriods key and still imports',
      () async {
    final cloud = _Cloud();
    final engine = _Engine(
      db: db,
      provider: cloud,
      changeTracker: ChangeTracker(db),
      repo: repo,
    );
    final ledgerId = await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'hydrate',
          syncId: const d.Value('hydrate-ledger'),
        ));
    await cloud.storage.upload(
        path: 'hydrate-ledger', data: _snapshot());

    final applied = await engine.hydrateLedgerFromServer('hydrate-ledger');
    expect(applied, 2); // 1 tx + 1 lock period

    final tx = await (db.select(db.transactions)
          ..where((t) => t.syncId.equals('hydrate-tx')))
        .getSingleOrNull();
    expect(tx, isNotNull, reason: '其他实体仍应正常入库');
    expect(tx!.ledgerId, ledgerId);

    final lp = await lockRepo.getBySyncId('hydrate-lp');
    expect(lp, isNotNull);
    expect(lp!.lockDate, '2026-11-27');
    expect(lp.lockedAt, '2026-11-27T12:00:00.000Z');
  });

  test('pull apply: lock_period change with unresolvable ledgerId is skipped, no row', () async {
    final cloud = _Cloud();
    final engine = _Engine(
      db: db,
      provider: cloud,
      changeTracker: ChangeTracker(db),
      repo: repo,
    );
    // 本地没有任何 ledger 行 —— 变更里 ledgerId 又是云端 String uuid
    // (int.tryParse 必失败,也没有可解析的 int payload)—— 三条解析路径
    // 全部失效。旧实现会落 ledgerId=-1 的幽灵行,新实现必须跳过不落库。
    cloud.pushFakeChange(
      entityType: 'lock_period',
      entitySyncId: 'lp-orphan',
      ledgerId: '0f1e2d3c-4b5a-6978-8796-a5b4c3d2e1f0',
      payload: {
        'syncId': 'lp-orphan',
        'ledgerId': '0f1e2d3c-4b5a-6978-8796-a5b4c3d2e1f0',
        'lockDate': '2026-11-27',
        'batchNo': 1,
        'lockedBy': 'local',
        'lockedAt': '2026-11-27T12:00:00Z',
      },
    );

    final applied = await engine.pull('', sinceOverride: 0);
    expect(applied, 1);
    expect(await lockRepo.getBySyncId('lp-orphan'), isNull,
        reason: 'ledgerId 无法解析时不得落库(禁止 -1 孤儿行)');
    final rows = await db.select(db.lockPeriods).get();
    expect(rows, isEmpty, reason: 'lock_periods 表必须保持为空');
  });

  test('pull apply: lock_period change with local ledger syncId resolves', () async {
    final cloud = _Cloud();
    final engine = _Engine(
      db: db,
      provider: cloud,
      changeTracker: ChangeTracker(db),
      repo: repo,
    );
    // 本地有 syncId=ledger-ext 的账本(跨设备本地 int autoIncrement),
    // change.ledgerId 是云端 external_id —— 应解析成本地 int 并落库。
    final localId = await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'local-ledger',
          syncId: const d.Value('ledger-ext'),
        ));
    cloud.pushFakeChange(
      entityType: 'lock_period',
      entitySyncId: 'lp-ok',
      ledgerId: 'ledger-ext',
      payload: {
        'syncId': 'lp-ok',
        'lockDate': '2026-11-27',
        'batchNo': 1,
        'lockedBy': 'local',
        'lockedAt': '2026-11-27T12:00:00Z',
      },
    );

    await engine.pull('', sinceOverride: 0);
    final lp = await lockRepo.getBySyncId('lp-ok');
    expect(lp, isNotNull);
    expect(lp!.ledgerId, localId, reason: '解析到本地 int id,不是云端 external_id');
    expect(lp.lockDate, '2026-11-27');
    expect(await lockRepo.effectiveLockDate(localId), '2026-11-27');
  });

  test('file import (parseJsonToImportData) tolerates lockPeriods', () async {
    final imported = parseJsonToImportData(_snapshot());
    expect(imported.transactions, hasLength(1));
    expect(imported.lockPeriods, hasLength(1));

    // v36 老快照:没有 lockPeriods key 也能解析,不抛异常。
    final legacy = parseJsonToImportData(_snapshot(withLockPeriods: false));
    expect(legacy.transactions, hasLength(1));
    expect(legacy.lockPeriods, isEmpty);

    final ledgerId = await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'import',
          syncId: const d.Value('import-ledger'),
        ));
    await dataImportService.importData(repo, ledgerId, imported);

    final tx = await (db.select(db.transactions)
          ..where((t) => t.syncId.equals('hydrate-tx')))
        .getSingleOrNull();
    expect(tx, isNotNull, reason: '其他实体仍应正常入库');
    final lp = await lockRepo.getBySyncId('hydrate-lp');
    expect(lp, isNotNull);
    expect(lp!.lockDate, '2026-11-27');
    expect(lp.lockedAt, '2026-11-27T12:00:00.000Z');
  });
}
