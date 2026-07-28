// v31 专项预算 LocalBudgetRepository 行为(冻结合同见
// local-artifacts/special-budget/plans/2026-07-23-app-phase3-contract.md)。
//
// 覆盖点(Phase 3A RED 的六项对应修复):
// - R1 create/read 5 project 字段
// - R2 tx projectBudgetSyncId 落地(在 sync_engine_apply_project_test 里)
// - R3/R4 snapshot v7(在 full_snapshot_v7_round_trip_test 里)
// - R5 getBudgetUsage project 分支 + 剔除;else 收窄不 crash
// - R6 delete(total) 不再连坐 project
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';

import 'package:beecount/data/repositories/local/local_budget_repository.dart';

void main() {
  late BeeDatabase db;
  late LocalBudgetRepository repo;
  const ledgerSyncId = 'ledger-t';

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalBudgetRepository(db);
    await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L',
          currency: const Value('CNY'),
          syncId: const Value(ledgerSyncId),
        ));
  });

  tearDown(() async => db.close());

  Future<int> totalBudget({double amount = 5000}) => repo.createBudget(
        ledgerId: 1,
        type: 'total',
        amount: amount,
      );

  Future<int> categoryBudget({required int catId, double amount = 800}) async {
    // 预先建 category
    await db.customStatement(
        "INSERT OR IGNORE INTO categories (id, name, kind) VALUES (?, ?, 'expense')",
        [catId, 'Food-$catId']);
    return repo.createBudget(
      ledgerId: 1,
      type: 'category',
      categoryId: catId,
      amount: amount,
    );
  }

  Future<int> projectBudget({
    double amount = 2400,
    DateTime? startAt,
    DateTime? endAt,
    bool excludeMonthly = true,
    String status = 'active',
  }) =>
      repo.createBudget(
        ledgerId: 1,
        type: 'project',
        amount: amount,
        name: 'Studio refresh',
        startAt: startAt ?? DateTime.utc(2026, 8, 1),
        endAt: endAt ?? DateTime.utc(2026, 10, 1),
        excludeFromMonthlyTotal: excludeMonthly,
        status: status,
      );

  test('project create:5 字段落地,name trim,syncId 分配', () async {
    final id = await projectBudget();
    final row = await (db.select(db.budgets)..where((b) => b.id.equals(id)))
        .getSingle();
    expect(row.type, 'project');
    expect(row.name, 'Studio refresh');
    // Drift 用 unix 秒存 DateTime,取回时是 local 时区表示;这里用
    // isAtSameMomentAs 消除表示差异,保证语义(同一 UTC 时刻)。
    expect(row.startAt!.isAtSameMomentAs(DateTime.utc(2026, 8, 1)), isTrue);
    expect(row.endAt!.isAtSameMomentAs(DateTime.utc(2026, 10, 1)), isTrue);
    expect(row.excludeFromMonthlyTotal, isTrue);
    expect(row.status, 'active');
    expect(row.syncId, isNotNull);
  });

  test('project create:name 空/日期缺失/日期倒置/非法 status 全部 ArgumentError', () async {
    // 空 name
    expect(
      () => repo.createBudget(
        ledgerId: 1,
        type: 'project',
        amount: 100,
        name: '   ',
        startAt: DateTime.utc(2026, 8, 1),
        endAt: DateTime.utc(2026, 10, 1),
      ),
      throwsArgumentError,
    );
    // 缺日期
    expect(
      () => repo.createBudget(
        ledgerId: 1,
        type: 'project',
        amount: 100,
        name: 'x',
      ),
      throwsArgumentError,
    );
    // startAt >= endAt
    expect(
      () => repo.createBudget(
        ledgerId: 1,
        type: 'project',
        amount: 100,
        name: 'x',
        startAt: DateTime.utc(2026, 10, 1),
        endAt: DateTime.utc(2026, 8, 1),
      ),
      throwsArgumentError,
    );
    // 非法 status
    expect(
      () => repo.createBudget(
        ledgerId: 1,
        type: 'project',
        amount: 100,
        name: 'x',
        startAt: DateTime.utc(2026, 8, 1),
        endAt: DateTime.utc(2026, 10, 1),
        status: 'weird',
      ),
      throwsArgumentError,
    );
  });

  test('project amount 必须 finite 且大于零(create/update/restore)', () async {
    for (final invalid in <double>[0, -1, double.nan, double.infinity]) {
      await expectLater(
        repo.createBudget(
          ledgerId: 1,
          type: 'project',
          amount: invalid,
          name: 'x',
          startAt: DateTime.utc(2026, 8, 1),
          endAt: DateTime.utc(2026, 10, 1),
        ),
        throwsArgumentError,
      );
    }

    final id = await projectBudget();
    await expectLater(repo.updateBudget(id, amount: 0), throwsArgumentError);
    await expectLater(
      repo.restoreBudgetBySyncId(
        syncId: 'invalid-project-amount',
        ledgerId: 1,
        type: 'project',
        amount: double.negativeInfinity,
        name: 'x',
        startAt: DateTime.utc(2026, 8, 1),
        endAt: DateTime.utc(2026, 10, 1),
      ),
      throwsArgumentError,
    );
    final unchanged = await (db.select(db.budgets)
          ..where((budget) => budget.id.equals(id)))
        .getSingle();
    expect(unchanged.amount, 2400);
  });

  test('project update 校验有效写后 name 与日期区间', () async {
    final id = await projectBudget();
    await expectLater(repo.updateBudget(id, name: '   '), throwsArgumentError);
    await expectLater(
      repo.updateBudget(id, startAt: DateTime.utc(2026, 11, 1)),
      throwsArgumentError,
    );
  });

  test('getProjectBudgets / getProjectBudgetBySyncId', () async {
    final pid = await projectBudget();
    final projects = await repo.getProjectBudgets(1);
    expect(projects, hasLength(1));
    expect(projects.single.id, pid);

    final row = await (db.select(db.budgets)..where((b) => b.id.equals(pid)))
        .getSingle();
    final byId = await repo.getProjectBudgetBySyncId(row.syncId!);
    expect(byId, isNotNull);
    expect(byId!.id, pid);
    // total 预算不应命中 project 查询
    final tid = await totalBudget();
    final rowT = await (db.select(db.budgets)..where((b) => b.id.equals(tid)))
        .getSingle();
    final missT = await repo.getProjectBudgetBySyncId(rowT.syncId!);
    expect(missT, isNull);
  });

  test(
      'getBudgetUsage(project):按 [startAt, endAt) 半开区间 + link 匹配 + '
      'exclude_from_budget 过滤', () async {
    final pid = await projectBudget();
    final row = await (db.select(db.budgets)..where((b) => b.id.equals(pid)))
        .getSingle();
    final syncId = row.syncId!;

    // 挂载 3 笔交易:命中 / 区间外 / exclude_from_budget=1。
    // Drift 用 unix 秒(second-since-epoch, INTEGER)存 DateTime;直接用 ISO 字符串
    // 插会被当成 TEXT 存,SQLite 比较时不匹配。所以这里用 Value 与 companion。
    Future<void> insertTx(DateTime happenedAt, double amount,
        {bool excludeFromBudget = false, String? projectSyncId}) async {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: amount,
            happenedAt: Value(happenedAt),
            excludeFromBudget: Value(excludeFromBudget),
            projectBudgetSyncId: Value(projectSyncId),
            nativeAmount: Value(amount),
          ));
    }

    await insertTx(DateTime.utc(2026, 8, 1), 10,
        projectSyncId: syncId); // startAt 包含
    await insertTx(DateTime.utc(2026, 8, 15), 100, projectSyncId: syncId);
    await insertTx(DateTime.utc(2026, 10, 1), 888,
        projectSyncId: syncId); // endAt 排除
    await insertTx(DateTime.utc(2026, 12, 1), 999,
        projectSyncId: syncId); // 超出 endAt
    await insertTx(DateTime.utc(2026, 8, 20), 50,
        excludeFromBudget: true, projectSyncId: syncId); // 剔除

    final usage = await repo.getBudgetUsage(pid, DateTime.utc(2026, 8, 15));
    expect(usage.used, 110.0);
    expect(usage.budget, 2400.0);
  });

  test('getBudgetUsage(project):数据不全时返回 used=0,不 crash', () async {
    // 直接绕过 createBudget 校验,插入一条 startAt=null 的 project 行,模拟异常态。
    await db.customStatement(
      "INSERT INTO budgets (sync_id, ledger_id, type, amount, period, "
      "start_day, enabled, created_at, updated_at, exclude_from_monthly_total, "
      "status) VALUES ('bad-p', 1, 'project', 100, 'monthly', 1, 1, 0, 0, 0, 'active')",
    );
    final row = await (db.select(db.budgets)
          ..where((b) => b.syncId.equals('bad-p')))
        .getSingle();
    final usage = await repo.getBudgetUsage(row.id, DateTime.utc(2026, 8, 1));
    expect(usage.used, 0.0);
    expect(usage.budget, 100.0);
  });

  test('getBudgetUsage(total):剔除 excludeFromMonthlyTotal=true 的 project 支出',
      () async {
    final tid = await totalBudget();
    final pid = await projectBudget();
    final pRow = await (db.select(db.budgets)..where((b) => b.id.equals(pid)))
        .getSingle();
    // 挂到 project 的支出,理应不计入 total usage(excludeFromMonthlyTotal=true)
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: 1,
          type: 'expense',
          amount: 200,
          happenedAt: Value(DateTime.utc(2026, 8, 15)),
          projectBudgetSyncId: Value(pRow.syncId!),
          nativeAmount: const Value(200),
        ));
    // 一笔无关支出应计入 total
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: 1,
          type: 'expense',
          amount: 300,
          happenedAt: Value(DateTime.utc(2026, 8, 15)),
          nativeAmount: const Value(300),
        ));
    final usage = await repo.getBudgetUsage(tid, DateTime.utc(2026, 8, 15));
    expect(usage.used, 300.0);
  });

  test('getBudgetUsage(total):计入 excludeFromMonthlyTotal=false 的 project 支出',
      () async {
    final tid = await totalBudget();
    final pid = await projectBudget(excludeMonthly: false);
    final project = await (db.select(db.budgets)
          ..where((b) => b.id.equals(pid)))
        .getSingle();
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: 1,
          type: 'expense',
          amount: 200,
          happenedAt: Value(DateTime.utc(2026, 8, 15)),
          projectBudgetSyncId: Value(project.syncId!),
          nativeAmount: const Value(200),
        ));
    final usage = await repo.getBudgetUsage(tid, DateTime.utc(2026, 8, 15));
    expect(usage.used, 200.0);
  });

  test('getBudgetUsage(category):categoryId 缺失 → used=0 (不再 categoryId! crash)',
      () async {
    // 手工插入一条 category 行,但 category_id=NULL(理论上不该发生,此处覆盖防御)
    await db.customStatement(
      "INSERT INTO budgets (sync_id, ledger_id, type, amount, period, "
      "start_day, enabled, created_at, updated_at) "
      "VALUES ('bad-c', 1, 'category', 500, 'monthly', 1, 1, 0, 0)",
    );
    final row = await (db.select(db.budgets)
          ..where((b) => b.syncId.equals('bad-c')))
        .getSingle();
    final usage = await repo.getBudgetUsage(row.id, DateTime.utc(2026, 8, 15));
    expect(usage.used, 0.0);
  });

  test('getBudgetUsage(category):有效 project link 剔除，未关联支出保留', () async {
    final categoryId = await categoryBudget(catId: 10);
    final projectId = await projectBudget();
    final project = await (db.select(db.budgets)
          ..where((b) => b.id.equals(projectId)))
        .getSingle();

    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: 1,
          type: 'expense',
          amount: 100,
          categoryId: const Value(10),
          happenedAt: Value(DateTime.utc(2026, 8, 15)),
          nativeAmount: const Value(100),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: 1,
          type: 'expense',
          amount: 200,
          categoryId: const Value(10),
          happenedAt: Value(DateTime.utc(2026, 8, 15)),
          nativeAmount: const Value(200),
          projectBudgetSyncId: Value(project.syncId!),
        ));

    expect(
      (await repo.getBudgetUsage(categoryId, DateTime.utc(2026, 8, 15))).used,
      100.0,
    );
    expect(
      (await repo.getBudgetUsage(projectId, DateTime.utc(2026, 8, 15))).used,
      200.0,
    );
  });

  test('getBudgetUsage(category):隔离不依赖 total 排除标志', () async {
    final totalId = await totalBudget();
    final categoryId = await categoryBudget(catId: 10);
    final projectId = await projectBudget(excludeMonthly: false);
    final project = await (db.select(db.budgets)
          ..where((b) => b.id.equals(projectId)))
        .getSingle();

    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: 1,
          type: 'expense',
          amount: 300,
          categoryId: const Value(10),
          happenedAt: Value(DateTime.utc(2026, 8, 15)),
          nativeAmount: const Value(300),
          projectBudgetSyncId: Value(project.syncId!),
        ));

    expect(
      (await repo.getBudgetUsage(categoryId, DateTime.utc(2026, 8, 15))).used,
      0.0,
    );
    expect(
      (await repo.getBudgetUsage(projectId, DateTime.utc(2026, 8, 15))).used,
      300.0,
    );
    expect(
      (await repo.getBudgetUsage(totalId, DateTime.utc(2026, 8, 15))).used,
      300.0,
    );
  });

  test('getBudgetUsage(category):畸形 project link 仍计入普通分类', () async {
    final categoryId = await categoryBudget(catId: 10);
    final nonProjectId = await totalBudget();
    final nonProject = await (db.select(db.budgets)
          ..where((b) => b.id.equals(nonProjectId)))
        .getSingle();
    await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'Other ledger',
          currency: const Value('CNY'),
          syncId: const Value('ledger-other'),
        ));
    final crossLedgerProjectId = await repo.createBudget(
      ledgerId: 2,
      type: 'project',
      amount: 100,
      name: 'Other project',
      startAt: DateTime.utc(2026, 8, 1),
      endAt: DateTime.utc(2026, 10, 1),
    );
    final crossLedgerProject = await (db.select(db.budgets)
          ..where((b) => b.id.equals(crossLedgerProjectId)))
        .getSingle();

    // 模拟 v34 insert guard 安装前遗留的三类畸形 link；独立 trigger tests
    // 已验证这些值在 fresh DB 上均无法写入。
    await db.customStatement(
      'DROP TRIGGER IF EXISTS trg_transactions_project_link_insert',
    );
    for (final entry in <(double, String)>[
      (10, 'orphan-project-sync-id'),
      (20, nonProject.syncId!),
      (30, crossLedgerProject.syncId!),
    ]) {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: entry.$1,
            categoryId: const Value(10),
            happenedAt: Value(DateTime.utc(2026, 8, 15)),
            nativeAmount: Value(entry.$1),
            projectBudgetSyncId: Value(entry.$2),
          ));
    }

    expect(
      (await repo.getBudgetUsage(categoryId, DateTime.utc(2026, 8, 15))).used,
      60.0,
    );
  });

  test('deleteBudget(total):只级联删 total/category,project 保留', () async {
    final tid = await totalBudget();
    final cid = await categoryBudget(catId: 10);
    final pid = await projectBudget();

    await repo.deleteBudget(tid);

    final rows = await db.select(db.budgets).get();
    final ids = rows.map((r) => r.id).toSet();
    expect(ids.contains(tid), isFalse);
    expect(ids.contains(cid), isFalse); // total 联动清 category
    expect(ids.contains(pid), isTrue); // project 保留
  });

  test('updateBudget:project 字段选择性更新(null 保留)', () async {
    final pid = await projectBudget();
    await repo.updateBudget(pid, amount: 3000, status: 'archived');
    final row = await (db.select(db.budgets)..where((b) => b.id.equals(pid)))
        .getSingle();
    expect(row.amount, 3000);
    expect(row.status, 'archived');
    expect(row.name, 'Studio refresh'); // 未传保留
  });

  test('被 transaction 引用的 project 不能硬删除', () async {
    final pid = await projectBudget();
    final project = await (db.select(db.budgets)
          ..where((b) => b.id.equals(pid)))
        .getSingle();
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: 1,
          type: 'expense',
          amount: 1,
          happenedAt: Value(DateTime.utc(2026, 8, 1)),
          projectBudgetSyncId: Value(project.syncId),
        ));
    await expectLater(repo.deleteBudget(pid), throwsStateError);
  });

  test('archived project 只允许重新激活为 active', () async {
    final pid = await projectBudget(status: 'archived');
    await expectLater(repo.updateBudget(pid, amount: 1), throwsStateError);
    await expectLater(
        repo.updateBudget(pid, status: 'planned'), throwsStateError);
    await repo.updateBudget(pid, status: 'active');
    final row = await (db.select(db.budgets)..where((b) => b.id.equals(pid)))
        .getSingle();
    expect(row.status, 'active');
  });

  test('restoreBudgetBySyncId 拒绝把被引用 project 降级为 total', () async {
    final pid = await projectBudget();
    final project = await (db.select(db.budgets)
          ..where((b) => b.id.equals(pid)))
        .getSingle();
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: 1,
          type: 'expense',
          amount: 1,
          happenedAt: Value(DateTime.utc(2026, 8, 1)),
          projectBudgetSyncId: Value(project.syncId),
        ));

    await expectLater(
      repo.restoreBudgetBySyncId(
        syncId: project.syncId!,
        ledgerId: 1,
        type: 'total',
        amount: 999,
      ),
      throwsStateError,
    );

    final row = await repo.getBudgetBySyncId(project.syncId!);
    expect(row!.type, 'project');
    expect(row.amount, 2400);
  });

  test('overwriteBudgetSyncId 拒绝重写被引用 project identity', () async {
    final pid = await projectBudget();
    final project = await (db.select(db.budgets)
          ..where((b) => b.id.equals(pid)))
        .getSingle();
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: 1,
          type: 'expense',
          amount: 1,
          happenedAt: Value(DateTime.utc(2026, 8, 1)),
          projectBudgetSyncId: Value(project.syncId),
        ));

    await expectLater(
      repo.overwriteBudgetSyncId(pid, 'replacement-project-sync-id'),
      throwsStateError,
    );

    expect((await repo.getBudgetBySyncId(project.syncId!))!.id, pid);
  });

  /// E4-S2 L1: project update rejects every invalid effective terminal state
  /// unchanged. Each invalid patch must throw ArgumentError and leave the
  /// complete Drift row equal to the original.
  test(
      'project update rejects every invalid effective terminal state unchanged',
      () async {
    final pid = await projectBudget();
    final original = await (db.select(db.budgets)
          ..where((b) => b.id.equals(pid)))
        .getSingle();

    final invalidPatches = <String, Future<void> Function()>{
      'amount-nan': () => repo.updateBudget(pid, amount: double.nan),
      'amount-infinity': () => repo.updateBudget(pid, amount: double.infinity),
      'name-whitespace': () => repo.updateBudget(pid, name: '   '),
      'end-before-start': () => repo.updateBudget(
            pid,
            endAt: DateTime.utc(2026, 7, 1),
          ),
      'start-after-end': () => repo.updateBudget(
            pid,
            startAt: DateTime.utc(2026, 11, 1),
          ),
      'status-paused': () => repo.updateBudget(pid, status: 'paused'),
    };

    for (final entry in invalidPatches.entries) {
      await expectLater(
        entry.value(),
        throwsArgumentError,
        reason: '${entry.key} should throw ArgumentError',
      );
      final row = await (db.select(db.budgets)..where((b) => b.id.equals(pid)))
          .getSingle();
      expect(row, equals(original),
          reason: '${entry.key} must not mutate the row');
    }
  });

  /// E4-S2 L2: project restore rejects every invalid terminal state without
  /// insertion. Each invalid restore must throw ArgumentError and no budget
  /// with that sync ID should exist.
  test('project restore rejects every invalid terminal state without insertion',
      () async {
    final invalidRestores = <String, Future<int> Function()>{
      'amount-zero': () => repo.restoreBudgetBySyncId(
            syncId: 'restore-amount-zero',
            ledgerId: 1,
            type: 'project',
            amount: 0,
            name: 'x',
            startAt: DateTime.utc(2026, 8, 1),
            endAt: DateTime.utc(2026, 10, 1),
          ),
      'amount-neg-inf': () => repo.restoreBudgetBySyncId(
            syncId: 'restore-amount-neg-inf',
            ledgerId: 1,
            type: 'project',
            amount: double.negativeInfinity,
            name: 'x',
            startAt: DateTime.utc(2026, 8, 1),
            endAt: DateTime.utc(2026, 10, 1),
          ),
      'name-whitespace': () => repo.restoreBudgetBySyncId(
            syncId: 'restore-name-whitespace',
            ledgerId: 1,
            type: 'project',
            amount: 100,
            name: '   ',
            startAt: DateTime.utc(2026, 8, 1),
            endAt: DateTime.utc(2026, 10, 1),
          ),
      'start-null': () => repo.restoreBudgetBySyncId(
            syncId: 'restore-start-null',
            ledgerId: 1,
            type: 'project',
            amount: 100,
            name: 'x',
            endAt: DateTime.utc(2026, 10, 1),
          ),
      'end-null': () => repo.restoreBudgetBySyncId(
            syncId: 'restore-end-null',
            ledgerId: 1,
            type: 'project',
            amount: 100,
            name: 'x',
            startAt: DateTime.utc(2026, 8, 1),
          ),
      'start-gte-end': () => repo.restoreBudgetBySyncId(
            syncId: 'restore-start-gte-end',
            ledgerId: 1,
            type: 'project',
            amount: 100,
            name: 'x',
            startAt: DateTime.utc(2026, 10, 1),
            endAt: DateTime.utc(2026, 10, 1),
          ),
      'status-paused': () => repo.restoreBudgetBySyncId(
            syncId: 'restore-status-paused',
            ledgerId: 1,
            type: 'project',
            amount: 100,
            name: 'x',
            startAt: DateTime.utc(2026, 8, 1),
            endAt: DateTime.utc(2026, 10, 1),
            status: 'paused',
          ),
    };

    for (final entry in invalidRestores.entries) {
      await expectLater(
        entry.value(),
        throwsArgumentError,
        reason: '${entry.key} should throw ArgumentError',
      );
      final syncId = 'restore-${entry.key}';
      final row = await (db.select(db.budgets)
            ..where((b) => b.syncId.equals(syncId)))
          .getSingleOrNull();
      expect(row, isNull, reason: '${entry.key} must not insert a budget');
    }
  });
}
