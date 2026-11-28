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

  // US-01 裁决1:证明 #660 重写后的 outbox stage 路径真能把 lock_period
  // 同步出去。原 fork 走 syncChanges.add,stage() 写 localChanges.wire_json,
  // 是两段不同的序列化代码 —— 必须端到端堵死静默断点:
  //   设备A createLocal → fullPush stage → wire_json.change → server →
  //   设备B pull → apply → lock_periods 落地 + effectiveLockDate 生效。
  test('e2e: outbox stage push -> remote pull lands lock_period + effectiveLockDate',
      () async {
    // 设备 A
    final dbA = BeeDatabase.forTesting(NativeDatabase.memory());
    final trackerA = ChangeTracker(dbA);
    final repoA = LocalRepository(dbA, changeTracker: trackerA);
    final lockRepoA = LockPeriodRepository(dbA, trackerGetter: () => trackerA);
    final cloudA = _Cloud();
    final engineA = SyncEngine(
        db: dbA, provider: cloudA, changeTracker: trackerA, repo: repoA);
    addTearDown(dbA.close);

    // 设备 B（复用本 test 的 db / repo / lockRepo）
    final cloudB = _Cloud();
    final engineB = SyncEngine(
        db: db, provider: cloudB, changeTracker: ChangeTracker(db), repo: repo);

    // 两端各有同一 external_id 的账本,但本地 int id 故意错开:
    // A 端先插一条占位账本,使 e2e 账本 int id=2;B 端 e2e 账本 int id=1。
    // 这样 apply 若误用 payload 的 int 或本地 int 直连就会落到错误行 ——
    // 只有按 external_id 解析才能命中 B 端 id=1。
    const extLedger = 'e2e-ledger-ext';
    await dbA.into(dbA.ledgers).insert(
        LedgersCompanion.insert(name: 'A-placeholder', syncId: const d.Value('a-placeholder')));
    final ledgerA = await dbA.into(dbA.ledgers).insert(
        LedgersCompanion.insert(name: 'A', syncId: const d.Value(extLedger)));
    final ledgerB = await db.into(db.ledgers).insert(
        LedgersCompanion.insert(name: 'B', syncId: const d.Value(extLedger)));
    expect(ledgerA, isNot(ledgerB), reason: '两端本地 int id 必须不同,走 external_id 解析');

    // A 端新增锁账(createLocal 登记 ledger-scoped change)
    await lockRepoA.createLocal(
        syncId: 'e2e-lp', ledgerId: ledgerA, lockDate: '2026-11-28');
    expect(await lockRepoA.effectiveLockDate(ledgerA), '2026-11-28');

    // A 端 fullPush:远端无此账本 → 触发 stage 路径
    await engineA.sync(ledgerId: ledgerA.toString());

    // 从 A 推批次里挑出 lock_period change —— 这正是 stage 写出的
    // wire_json.change,断言其字段结构与 pull apply 期望一致。
    final pushed = cloudA.pushedBatches.expand((b) => b).toList();
    final lpChanges = pushed
        .where((c) => c['entity_type'] == 'lock_period')
        .toList();
    expect(lpChanges, isNotEmpty,
        reason: 'stage 路径必须把 lock_period 写进 outbox 并推送');
    final lpChange = lpChanges.first;
    // (a) wire_json/payload 字段对齐 apply 入参
    expect(lpChange['entity_sync_id'], 'e2e-lp');
    expect(lpChange['ledger_id'], extLedger);
    expect(lpChange['action'], 'upsert');
    final payload = lpChange['payload'] as Map<String, dynamic>;
    expect(payload['lockDate'], '2026-11-28',
        reason: 'apply 读 payload.lockDate,stage 必须写同名字段');
    expect(payload['batchNo'], 1);
    expect(payload['lockedAt'], isNotNull);

    // 中转:模拟 server 收到该 change 并下发到设备 B
    cloudB.pushFakeChange(
      entityType: lpChange['entity_type'] as String,
      entitySyncId: lpChange['entity_sync_id'] as String,
      ledgerId: lpChange['ledger_id'] as String,
      action: lpChange['action'] as String,
      payload: payload,
      updatedByDeviceId: 'device-a',
    );

    // B 端 pull → apply
    await engineB.pull('', sinceOverride: 0);
    final landed = await lockRepo.getBySyncId('e2e-lp');
    expect(landed, isNotNull, reason: 'B 端必须落地 A 端推送的锁账');
    expect(landed!.ledgerId, ledgerB,
        reason: '跨设备按 external_id 解析到本地 int id');
    expect(landed.lockDate, '2026-11-28');
    expect(await lockRepo.effectiveLockDate(ledgerB), '2026-11-28',
        reason: '落地后 effectiveLockDate 必须生效');
  });

  // US-01 收口1:真实 v36 → v38 升级链演练。上游 #665 占 37(local_changes
  // 六列),S1-01a 锁账建表顺延到 38。验证 from<37 与 from<38 两个块按序
  // 执行、重复打开幂等。
  test('migration v36 -> v38 runs both blocks and is idempotent on reopen',
      () async {
    final dir = await Directory.systemTemp.createTemp('beecount-us01-upgrade-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/owned-v36.sqlite');

    var upDb = BeeDatabase.forTesting(NativeDatabase(file));
    // 造 v36 形态:删掉 37 的 local_changes 六列 + 38 的 lock_periods 表。
    for (final column in [
      'operation_id', 'write_micros', 'wire_json',
      'deferred_json', 'confirmed_change_id', 'receipt_scope'
    ]) {
      await upDb.customStatement('ALTER TABLE local_changes DROP COLUMN $column');
    }
    await upDb.customStatement('DROP TABLE lock_periods');
    await upDb.customStatement('PRAGMA user_version=36');
    await upDb.close();

    // 首次打开:36 → 37(加列) → 38(建表)
    upDb = BeeDatabase.forTesting(NativeDatabase(file));
    expect(
        (await upDb.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        38,
        reason: '升级后 user_version 必须等于 schemaVersion 38');
    final cols = (await upDb.customSelect('PRAGMA table_info(local_changes)').get())
        .map((r) => r.read<String>('name'))
        .toSet();
    expect(cols, contains('wire_json'), reason: 'from<37 必须加 local_changes 列');
    expect(cols, contains('operation_id'));
    final tables = (await upDb.customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='lock_periods'")
        .get());
    expect(tables, hasLength(1), reason: 'from<38 必须建 lock_periods 表');
    await upDb.close();

    // 二次打开:已是 v38,两个块都跳过,幂等
    upDb = BeeDatabase.forTesting(NativeDatabase(file));
    expect(
        (await upDb.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        38);
    expect(
        (await upDb.customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='lock_periods'")
            .get()),
        hasLength(1),
        reason: '重复打开不得重复建表');
    await upDb.close();
  });
}
