// v31 专项预算 sync apply 路径:
// - transaction:tri-state 语义 —— 键缺失 = 保留;显式 null = 清除;字符串 = 关联
// - budget:type=project payload 5 键落地;缺键/非法值 skip
//
// 与 transaction_exclude_flags_apply_test.dart 同套路,走 engine.pull('')。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' show Value;

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/system/logger_service.dart';

import '_fakes/fake_beecount_cloud_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late ChangeTracker changeTracker;
  late LocalRepository repo;
  late FakeBeeCountCloudProvider provider;
  late SyncEngine engine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    logger.clear();
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    changeTracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: changeTracker);
    provider = FakeBeeCountCloudProvider();
    engine = SyncEngine(
      db: db,
      provider: provider,
      changeTracker: changeTracker,
      repo: repo,
    );
  });

  tearDown(() async => db.close());

  Future<int> seedLedger({String syncId = 'ledger-p'}) {
    return db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: '测试账本',
          monthStartDay: const Value(1),
          syncId: Value(syncId),
        ));
  }

  Future<void> seedProject(int ledgerId, {String syncId = 'proj-1'}) async {
    final id = await repo.createBudget(
      ledgerId: ledgerId,
      type: 'project',
      amount: 1,
      name: 'P',
      startAt: DateTime.utc(2026, 1, 1),
      endAt: DateTime.utc(2026, 12, 31),
    );
    await (db.update(db.budgets)..where((b) => b.id.equals(id))).write(
      BudgetsCompanion(syncId: Value(syncId)),
    );
  }

  Future<void> injectHistoricalInvalidProjectLink(
    int transactionId,
    String projectSyncId,
  ) async {
    // 该 fixture 模拟 v34 triggers 安装前已存在的历史脏行；生产入口禁止这样做。
    // update guard 的行为由独立 direct-SQL/race 测试覆盖。
    await db.customStatement(
      'DROP TRIGGER IF EXISTS trg_transactions_project_link_update',
    );
    await (db.update(db.transactions)
          ..where((transaction) => transaction.id.equals(transactionId)))
        .write(
      TransactionsCompanion(projectBudgetSyncId: Value(projectSyncId)),
    );
  }

  test('远端 project budget upsert → 本地 5 字段落地', () async {
    final lid = await seedLedger();

    provider.pushFakeChange(
      entityType: 'budget',
      entitySyncId: 'proj-1',
      ledgerId: '$lid',
      payload: {
        'syncId': 'proj-1',
        'ledgerSyncId': 'ledger-p',
        'type': 'project',
        'amount': 2400.0,
        'period': 'monthly',
        'startDay': 1,
        'enabled': true,
        'name': 'Studio refresh',
        'startAt': '2026-08-01T00:00:00.000Z',
        'endAt': '2026-10-01T00:00:00.000Z',
        'excludeFromMonthlyTotal': true,
        'status': 'active',
      },
    );
    await engine.pull('');

    final row = await (db.select(db.budgets)
          ..where((b) => b.syncId.equals('proj-1')))
        .getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.type, 'project');
    expect(row.name, 'Studio refresh');
    expect(row.excludeFromMonthlyTotal, isTrue);
    expect(row.status, 'active');
    expect(
      row.startAt!.isAtSameMomentAs(DateTime.utc(2026, 8, 1)),
      isTrue,
    );
    expect(row.endAt!.isAtSameMomentAs(DateTime.utc(2026, 10, 1)), isTrue);
  });

  test('远端 project budget 非法 payload(缺 name)→ skip,本地不写入', () async {
    final lid = await seedLedger();
    provider.pushFakeChange(
      entityType: 'budget',
      entitySyncId: 'proj-bad',
      ledgerId: '$lid',
      payload: {
        'syncId': 'proj-bad',
        'ledgerSyncId': 'ledger-p',
        'type': 'project',
        'amount': 100.0,
        // 缺 name / startAt / endAt / status
      },
    );
    await engine.pull('');
    final row = await (db.select(db.budgets)
          ..where((b) => b.syncId.equals('proj-bad')))
        .getSingleOrNull();
    expect(row, isNull, reason: '非法 project payload 应被 apply 端拒绝');
  });

  test('远端 project budget 缺 excludeFromMonthlyTotal → skip', () async {
    await seedLedger();
    provider.pushFakeChange(
      entityType: 'budget',
      entitySyncId: 'proj-missing-exclude',
      ledgerId: '1',
      payload: {
        'syncId': 'proj-missing-exclude',
        'ledgerSyncId': 'ledger-p',
        'type': 'project',
        'amount': 100.0,
        'period': 'monthly',
        'startDay': 1,
        'enabled': true,
        'name': 'Required fields',
        'startAt': '2026-08-01T00:00:00.000Z',
        'endAt': '2026-10-01T00:00:00.000Z',
        'status': 'active',
      },
    );
    await engine.pull('');
    final row = await (db.select(db.budgets)
          ..where((b) => b.syncId.equals('proj-missing-exclude')))
        .getSingleOrNull();
    expect(row, isNull, reason: 'project required boolean 缺失不能被静默降级为 false');
  });

  test('远端 transaction 省略 link + 保留孤儿 link → 完整行不变', () async {
    final lid = await seedLedger(syncId: 'ledger-orphan');
    final txId = await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 30,
      happenedAt: DateTime.utc(2026, 8, 15),
      note: 'stable orphan note',
      syncId: 'tx-retained-orphan',
      excludeFromStats: false,
      excludeFromBudget: false,
      currencyCode: 'CNY',
      nativeAmount: 30,
    );
    await injectHistoricalInvalidProjectLink(
      txId,
      'missing-retained-project',
    );
    final before = await repo.getTransactionBySyncId('tx-retained-orphan');
    expect(before, isNotNull);

    provider.pushFakeChange(
      entityType: 'transaction',
      entitySyncId: 'tx-retained-orphan',
      ledgerId: 'ledger-orphan',
      payload: {
        'syncId': 'tx-retained-orphan',
        'type': 'expense',
        'amount': 999,
        'happenedAt': '2026-09-16T00:00:00Z',
        'note': 'remote changed orphan note',
        'excludeFromStats': true,
        'excludeFromBudget': true,
        'currencyCode': 'USD',
        'nativeAmount': 888,
        // projectBudgetSyncId intentionally omitted.
      },
    );
    await engine.pull('');

    final after = await repo.getTransactionBySyncId('tx-retained-orphan');
    expect(after, equals(before));
    expect(after!.projectBudgetSyncId, 'missing-retained-project');
  });

  test('远端 transaction 省略 link + 保留跨账本 project → 完整行不变', () async {
    final sourceLedgerId = await seedLedger(syncId: 'ledger-cross-source');
    final targetLedgerId = await seedLedger(syncId: 'ledger-cross-target');
    await seedProject(targetLedgerId, syncId: 'project-retained-cross-ledger');
    final txId = await repo.addTransaction(
      ledgerId: sourceLedgerId,
      type: 'expense',
      amount: 31,
      happenedAt: DateTime.utc(2026, 8, 16),
      note: 'stable cross-ledger note',
      syncId: 'tx-retained-cross-ledger',
      excludeFromStats: false,
      excludeFromBudget: false,
      currencyCode: 'CNY',
      nativeAmount: 31,
    );
    await injectHistoricalInvalidProjectLink(
      txId,
      'project-retained-cross-ledger',
    );
    final before =
        await repo.getTransactionBySyncId('tx-retained-cross-ledger');
    expect(before, isNotNull);

    provider.pushFakeChange(
      entityType: 'transaction',
      entitySyncId: 'tx-retained-cross-ledger',
      ledgerId: 'ledger-cross-source',
      payload: {
        'syncId': 'tx-retained-cross-ledger',
        'type': 'expense',
        'amount': 998,
        'happenedAt': '2026-09-17T00:00:00Z',
        'note': 'remote changed cross-ledger note',
        'excludeFromStats': true,
        'excludeFromBudget': true,
        'currencyCode': 'USD',
        'nativeAmount': 887,
        // projectBudgetSyncId intentionally omitted.
      },
    );
    await engine.pull('');

    final after = await repo.getTransactionBySyncId('tx-retained-cross-ledger');
    expect(after, equals(before));
    expect(after!.projectBudgetSyncId, 'project-retained-cross-ledger');
  });

  test('远端 transaction 省略 link + 保留同账本 total → 完整行不变', () async {
    final lid = await seedLedger(syncId: 'ledger-total-retained');
    final totalId = await repo.createBudget(
      ledgerId: lid,
      type: 'total',
      amount: 500,
    );
    await (db.update(db.budgets)..where((b) => b.id.equals(totalId))).write(
      const BudgetsCompanion(syncId: Value('retained-total')),
    );
    final txId = await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 32,
      happenedAt: DateTime.utc(2026, 8, 17),
      note: 'stable total note',
      syncId: 'tx-retained-total',
      excludeFromStats: false,
      excludeFromBudget: false,
      currencyCode: 'CNY',
      nativeAmount: 32,
    );
    await injectHistoricalInvalidProjectLink(
      txId,
      'retained-total',
    );
    final before = await repo.getTransactionBySyncId('tx-retained-total');
    expect(before, isNotNull);

    provider.pushFakeChange(
      entityType: 'transaction',
      entitySyncId: 'tx-retained-total',
      ledgerId: 'ledger-total-retained',
      payload: {
        'syncId': 'tx-retained-total',
        'type': 'expense',
        'amount': 997,
        'happenedAt': '2026-09-18T00:00:00Z',
        'note': 'remote changed total note',
        'excludeFromStats': true,
        'excludeFromBudget': true,
        'currencyCode': 'USD',
        'nativeAmount': 886,
        // projectBudgetSyncId intentionally omitted.
      },
    );
    await engine.pull('');

    final after = await repo.getTransactionBySyncId('tx-retained-total');
    expect(after, equals(before));
    expect(after!.projectBudgetSyncId, 'retained-total');
  });

  test('远端 transaction upsert 省略 projectBudgetSyncId → 本地已有关联仍保留', () async {
    final lid = await seedLedger();
    await seedProject(lid);

    // 本地先建 project 与关联交易
    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 30,
      happenedAt: DateTime(2026, 8, 15),
      syncId: 'tx-p1',
      projectBudgetSyncId: 'proj-1',
    );

    // 远端只改 amount,不带 projectBudgetSyncId
    provider.pushFakeChange(
      entityType: 'transaction',
      entitySyncId: 'tx-p1',
      ledgerId: '$lid',
      payload: {
        'syncId': 'tx-p1',
        'type': 'expense',
        'amount': 45,
        'happenedAt': '2026-08-15T00:00:00Z',
        // 故意省略 projectBudgetSyncId
      },
    );
    await engine.pull('');

    final tx = await repo.getTransactionBySyncId('tx-p1');
    expect(tx, isNotNull);
    expect(tx!.amount, 45);
    expect(tx.projectBudgetSyncId, 'proj-1',
        reason: '缺键应保留本地关联(与 excludeFrom* 同 D6 语义)');
  });

  test('远端 transaction upsert 显式 projectBudgetSyncId=null → 本地清除关联', () async {
    final lid = await seedLedger();
    await seedProject(lid);
    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 30,
      happenedAt: DateTime(2026, 8, 15),
      syncId: 'tx-p2',
      projectBudgetSyncId: 'proj-1',
    );

    provider.pushFakeChange(
      entityType: 'transaction',
      entitySyncId: 'tx-p2',
      ledgerId: '$lid',
      payload: {
        'syncId': 'tx-p2',
        'type': 'expense',
        'amount': 30,
        'happenedAt': '2026-08-15T00:00:00Z',
        'projectBudgetSyncId': null, // 显式清除
      },
    );
    await engine.pull('');

    final tx = await repo.getTransactionBySyncId('tx-p2');
    expect(tx, isNotNull);
    expect(tx!.projectBudgetSyncId, isNull, reason: '显式 null 应清除本地关联');
  });

  test('远端 income transaction 不可关联 project', () async {
    final lid = await seedLedger();
    await seedProject(lid);

    provider.pushFakeChange(
      entityType: 'transaction',
      entitySyncId: 'tx-income-project',
      ledgerId: '$lid',
      payload: {
        'syncId': 'tx-income-project',
        'type': 'income',
        'amount': 12.0,
        'happenedAt': '2026-08-15T00:00:00Z',
        'projectBudgetSyncId': 'proj-1',
      },
    );
    await engine.pull('');

    expect(await repo.getTransactionBySyncId('tx-income-project'), isNull);
  });

  test('远端 linked expense 省略 link 时不可改成 income', () async {
    final lid = await seedLedger();
    await seedProject(lid);
    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 30,
      happenedAt: DateTime.utc(2026, 8, 15),
      syncId: 'tx-type-change',
      projectBudgetSyncId: 'proj-1',
    );

    provider.pushFakeChange(
      entityType: 'transaction',
      entitySyncId: 'tx-type-change',
      ledgerId: '$lid',
      payload: {
        'syncId': 'tx-type-change',
        'type': 'income',
        'amount': 45.0,
        'happenedAt': '2026-08-16T00:00:00Z',
        // link omitted means preserve, so this update must be rejected.
      },
    );
    await engine.pull('');

    final tx = await repo.getTransactionBySyncId('tx-type-change');
    expect(tx!.type, 'expense');
    expect(tx.amount, 30);
    expect(tx.projectBudgetSyncId, 'proj-1');
  });

  test('远端 linked expense 显式清 link 时可改成 income', () async {
    final lid = await seedLedger();
    await seedProject(lid);
    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 30,
      happenedAt: DateTime.utc(2026, 8, 15),
      syncId: 'tx-type-change-clear',
      projectBudgetSyncId: 'proj-1',
    );

    provider.pushFakeChange(
      entityType: 'transaction',
      entitySyncId: 'tx-type-change-clear',
      ledgerId: '$lid',
      payload: {
        'syncId': 'tx-type-change-clear',
        'type': 'income',
        'amount': 45.0,
        'happenedAt': '2026-08-16T00:00:00Z',
        'projectBudgetSyncId': null,
      },
    );
    await engine.pull('');

    final tx = await repo.getTransactionBySyncId('tx-type-change-clear');
    expect(tx!.type, 'income');
    expect(tx.amount, 45);
    expect(tx.projectBudgetSyncId, isNull);
  });

  test('远端 transaction 带不存在 projectBudgetSyncId → fail-closed 不落库', () async {
    final lid = await seedLedger();

    provider.pushFakeChange(
      entityType: 'transaction',
      entitySyncId: 'tx-p3',
      ledgerId: '$lid',
      payload: {
        'syncId': 'tx-p3',
        'type': 'expense',
        'amount': 12.0,
        'happenedAt': '2026-08-15T00:00:00Z',
        'projectBudgetSyncId': 'proj-9',
      },
    );
    await engine.pull('');

    final tx = await repo.getTransactionBySyncId('tx-p3');
    expect(tx, isNull, reason: 'projectBudgetSyncId 必须指向同账本 type=project 的预算');
  });

  test('远端删除被引用 project → fail-closed 保留 budget 和 transaction link', () async {
    final lid = await seedLedger();
    await seedProject(lid);
    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 20,
      happenedAt: DateTime.utc(2026, 8, 1),
      projectBudgetSyncId: 'proj-1',
    );
    provider.pushFakeChange(
      entityType: 'budget',
      entitySyncId: 'proj-1',
      action: 'delete',
    );
    await engine.pull('');

    expect(await repo.getProjectBudgetBySyncId('proj-1'), isNotNull);
    final tx =
        (await db.select(db.transactions).getSingle()).projectBudgetSyncId;
    expect(tx, 'proj-1');
  });

  test('远端 upsert 同 syncId project 到另一账本时不移动原 project', () async {
    final sourceLedgerId = await seedLedger(syncId: 'ledger-source');
    final targetLedgerId = await seedLedger(syncId: 'ledger-target');
    await seedProject(sourceLedgerId, syncId: 'project-cross-ledger');
    await repo.addTransaction(
      ledgerId: sourceLedgerId,
      type: 'expense',
      amount: 20,
      happenedAt: DateTime.utc(2026, 8, 1),
      syncId: 'tx-existing-project',
      projectBudgetSyncId: 'project-cross-ledger',
    );

    provider.pushFakeChange(
      entityType: 'budget',
      entitySyncId: 'project-cross-ledger',
      ledgerId: '$targetLedgerId',
      payload: {
        'syncId': 'project-cross-ledger',
        'ledgerSyncId': 'ledger-target',
        'type': 'project',
        'amount': 999.0,
        'period': 'monthly',
        'startDay': 1,
        'enabled': true,
        'name': 'Incoming project',
        'startAt': '2026-02-01T00:00:00Z',
        'endAt': '2026-11-01T00:00:00Z',
        'excludeFromMonthlyTotal': false,
        'status': 'active',
      },
    );
    await engine.pull('');

    final projects = await (db.select(db.budgets)
          ..where((b) => b.syncId.equals('project-cross-ledger')))
        .get();
    expect(projects, hasLength(1));
    expect(projects.single.ledgerId, sourceLedgerId);
    expect(projects.single.name, 'P');
    expect(projects.single.amount, 1);

    final tx = await repo.getTransactionBySyncId('tx-existing-project');
    expect(tx, isNotNull);
    expect(tx!.ledgerId, sourceLedgerId);
    expect(tx.projectBudgetSyncId, projects.single.syncId);
  });

  test('远端 upsert 不得附带修改 archived project', () async {
    final lid = await seedLedger();
    await seedProject(lid);
    final project = await repo.getProjectBudgetBySyncId('proj-1');
    await (db.update(db.budgets)..where((b) => b.id.equals(project!.id))).write(
      const BudgetsCompanion(status: Value('archived')),
    );
    provider.pushFakeChange(
      entityType: 'budget',
      entitySyncId: 'proj-1',
      ledgerId: '$lid',
      payload: {
        'syncId': 'proj-1',
        'ledgerSyncId': 'ledger-p',
        'type': 'project',
        'amount': 999.0,
        'period': 'monthly',
        'startDay': 1,
        'enabled': true,
        'name': 'P',
        'startAt': '2026-01-01T00:00:00Z',
        'endAt': '2026-12-31T00:00:00Z',
        'excludeFromMonthlyTotal': false,
        'status': 'archived',
      },
    );
    await engine.pull('');

    final after = await repo.getProjectBudgetBySyncId('proj-1');
    expect(after!.status, 'archived');
    expect(after.amount, 1.0);
  });

  test('远端 upsert 不得把被引用 project 降级为 total', () async {
    final lid = await seedLedger();
    await seedProject(lid);
    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 20,
      happenedAt: DateTime.utc(2026, 8, 1),
      syncId: 'tx-project-type-guard',
      projectBudgetSyncId: 'proj-1',
    );

    provider.pushFakeChange(
      entityType: 'budget',
      entitySyncId: 'proj-1',
      ledgerId: '$lid',
      payload: {
        'syncId': 'proj-1',
        'ledgerSyncId': 'ledger-p',
        'type': 'total',
        'amount': 999.0,
        'period': 'monthly',
        'startDay': 1,
        'enabled': true,
      },
    );
    await engine.pull('');

    final after = await (db.select(db.budgets)
          ..where((b) => b.syncId.equals('proj-1')))
        .getSingle();
    expect(after.type, 'project');
    expect(after.amount, 1.0);
    expect(
      (await repo.getTransactionBySyncId('tx-project-type-guard'))!
          .projectBudgetSyncId,
      'proj-1',
    );
  });

  /// E4-S2 S1: malformed project field types are skipped and valid sibling
  /// survives. Wrong-type fields must be caught before unsafe `as` casts so
  /// that the page is not rolled back and a valid sibling is not blocked.
  test('malformed project field types are skipped and valid sibling survives',
      () async {
    final lid = await seedLedger();

    // Valid project payload factory. All generic non-terminal fields valid so
    // failure attribution is clear.
    Map<String, dynamic> validProject(String syncId) => {
          'syncId': syncId,
          'ledgerSyncId': 'ledger-p',
          'type': 'project',
          'amount': 100.0,
          'period': 'monthly',
          'startDay': 1,
          'enabled': true,
          'name': 'Valid project',
          'startAt': '2026-08-01T00:00:00.000Z',
          'endAt': '2026-10-01T00:00:00.000Z',
          'excludeFromMonthlyTotal': true,
          'status': 'active',
        };

    // Each variant overrides exactly one field with a wrong type.
    final variants = <String, Map<String, dynamic>>{
      'proj-wrong-type': {
        ...validProject('proj-wrong-type'),
        'type': ['CANARY_RAW_TYPE_DO_NOT_LOG_9B1A'],
      },
      'proj-wrong-amount': {
        ...validProject('proj-wrong-amount'),
        'amount': 'CANARY_RAW_AMOUNT_DO_NOT_LOG_9B1A',
      },
      'proj-wrong-name': {...validProject('proj-wrong-name'), 'name': 99},
      'proj-wrong-startAt': {
        ...validProject('proj-wrong-startAt'),
        'startAt': true,
      },
      'proj-wrong-endAt': {
        ...validProject('proj-wrong-endAt'),
        'endAt': [2026, 12, 31],
      },
      'proj-wrong-exclude': {
        ...validProject('proj-wrong-exclude'),
        'excludeFromMonthlyTotal': 'yes',
      },
      'proj-wrong-status': {
        ...validProject('proj-wrong-status'),
        'status': 7,
      },
    };

    for (final entry in variants.entries) {
      provider.pushFakeChange(
        entityType: 'budget',
        entitySyncId: entry.key,
        ledgerId: '$lid',
        payload: entry.value,
      );
    }

    // Valid sibling pushed last.
    provider.pushFakeChange(
      entityType: 'budget',
      entitySyncId: 'proj-valid-sibling',
      ledgerId: '$lid',
      payload: validProject('proj-valid-sibling'),
    );

    await engine.pull('');

    final logText = logger.logs
        .where((entry) => entry.tag == 'SyncEngine')
        .map((entry) => entry.toFormattedString())
        .join('\n');
    expect(logText, isNot(contains('CANARY_RAW_TYPE_DO_NOT_LOG_9B1A')));
    expect(logText, isNot(contains('CANARY_RAW_AMOUNT_DO_NOT_LOG_9B1A')));

    // All malformed budget sync IDs must be absent.
    for (final badSyncId in variants.keys) {
      final row = await (db.select(db.budgets)
            ..where((b) => b.syncId.equals(badSyncId)))
          .getSingleOrNull();
      expect(row, isNull,
          reason: 'malformed budget $badSyncId should be skipped');
    }

    // Valid sibling must exist with correct terminal state.
    final valid = await (db.select(db.budgets)
          ..where((b) => b.syncId.equals('proj-valid-sibling')))
        .getSingleOrNull();
    expect(valid, isNotNull);
    expect(valid!.type, 'project');
    expect(valid.name, 'Valid project');
    expect(valid.amount, 100.0);
    expect(valid.status, 'active');
    expect(valid.excludeFromMonthlyTotal, isTrue);
    expect(
      valid.startAt!.isAtSameMomentAs(DateTime.utc(2026, 8, 1)),
      isTrue,
    );
    expect(
      valid.endAt!.isAtSameMomentAs(DateTime.utc(2026, 10, 1)),
      isTrue,
    );

    // No page-level syncPullErrors for contract-invalid project fields.
    final errors = await db.select(db.syncPullErrors).get();
    expect(errors, isEmpty,
        reason: 'malformed project field types must not create syncPullErrors');
  });

  /// E4-S2 S2: invalid project terminal updates leave complete existing row
  /// unchanged. Push complete project upserts for the same sync ID that each
  /// violate one value invariant (not wrong-type, but wrong-value).
  test('invalid project terminal updates leave complete existing row unchanged',
      () async {
    final lid = await seedLedger();

    // Seed a valid existing active project.
    final projectId = await repo.createBudget(
      ledgerId: lid,
      type: 'project',
      amount: 2400,
      name: 'Existing project',
      startAt: DateTime.utc(2026, 8, 1),
      endAt: DateTime.utc(2026, 10, 1),
      excludeFromMonthlyTotal: true,
      status: 'active',
    );
    await (db.update(db.budgets)..where((b) => b.id.equals(projectId)))
        .write(const BudgetsCompanion(syncId: Value('proj-s2-existing')));

    // Capture the complete Drift row before any pull.
    final before = await (db.select(db.budgets)
          ..where((b) => b.syncId.equals('proj-s2-existing')))
        .getSingle();

    // Base valid payload matching the existing row, to be overridden per case.
    Map<String, dynamic> basePayload() => {
          'syncId': 'proj-s2-existing',
          'ledgerSyncId': 'ledger-p',
          'type': 'project',
          'amount': 2400.0,
          'period': 'monthly',
          'startDay': 1,
          'enabled': true,
          'name': 'Existing project',
          'startAt': '2026-08-01T00:00:00.000Z',
          'endAt': '2026-10-01T00:00:00.000Z',
          'excludeFromMonthlyTotal': true,
          'status': 'active',
        };

    final invalidPayloads = <String, Map<String, dynamic>>{
      'amount-zero': {...basePayload(), 'amount': 0.0},
      'amount-nan': {...basePayload(), 'amount': double.nan},
      'name-whitespace': {...basePayload(), 'name': '   '},
      'start-gte-end': {
        ...basePayload(),
        'startAt': '2026-10-01T00:00:00.000Z',
        'endAt': '2026-10-01T00:00:00.000Z',
      },
      'status-paused': {...basePayload(), 'status': 'paused'},
    };

    for (final entry in invalidPayloads.entries) {
      provider.pushFakeChange(
        entityType: 'budget',
        entitySyncId: 'proj-s2-existing',
        ledgerId: '$lid',
        payload: entry.value,
      );
      await engine.pull('');

      // After each pull, the complete Drift Budget object must equal the
      // pre-pull object.
      final after = await (db.select(db.budgets)
            ..where((b) => b.syncId.equals('proj-s2-existing')))
          .getSingle();
      expect(after, equals(before),
          reason: 'invalid update (${entry.key}) must not mutate the row');

      // No page-level sync pull error.
      final errors = await db.select(db.syncPullErrors).get();
      expect(errors, isEmpty,
          reason:
              'invalid update (${entry.key}) must not create syncPullErrors');
    }
  });
}
