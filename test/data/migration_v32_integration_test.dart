// E6-S2A v32 integration vertical slice — authentic current-main v31 → v32.
//
// 这个测试打开真实的 current-main f74a7f7 v31 fixture（只有 accounts.hidden，
// 没有 Phase 3 专项预算字段），通过当前 BeeDatabase 打开并触发 upgrade，
// 断言升级后：
//   - schemaVersion == 32
//   - PRAGMA user_version == 32
//   - accounts.hidden 仍然存在（current-main v31 行为不丢）
//   - budgets 表 5 个 project 列全部存在
//   - transactions.project_budget_sync_id 存在
//   - idx_transactions_project_budget_sync_id 索引存在
//   - 数据库关闭后重新打开仍成功
//
// RED 预期：当前 target 是 schema 31，缺少 Phase 3 列/索引 → 断言失败。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';

Future<void> expectProjectLinkInvariantSchema(BeeDatabase db) async {
  final triggerRows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='trigger' "
        "AND name LIKE 'trg_%project%'",
      )
      .get();
  expect(
    triggerRows.map((row) => row.read<String>('name')).toSet(),
    containsAll(<String>{
      'trg_transactions_project_link_insert',
      'trg_transactions_project_link_update',
      'trg_project_budget_restrict_delete',
      'trg_project_budget_restrict_identity_update',
    }),
  );
  final budgetIndexRows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND name='idx_budgets_sync_id'",
      )
      .get();
  expect(budgetIndexRows, hasLength(1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('current-main v31 fixture -> v32: schema/columns/index/reopen',
      () async {
    SharedPreferences.setMockInitialValues({});

    final fixture =
        File('test/fixtures/beecount_schema_current_main_v31.sqlite');
    expect(fixture.existsSync(), isTrue,
        reason: 'fixture 必须由 f74a7f7 的 schemaVersion=31 BeeDatabase 生成');

    final tempDir =
        await Directory.systemTemp.createTemp('beecount-v31-v32-integration-');
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    final upgradedFile = File('${tempDir.path}/upgraded.sqlite');
    await fixture.copy(upgradedFile.path);

    var db = BeeDatabase.forTesting(NativeDatabase(upgradedFile));

    // 1. schemaVersion == 32
    expect(db.schemaVersion, 32, reason: '合并后 schemaVersion 必须为 32');

    // 2. PRAGMA user_version == 32（Drift onUpgrade 执行后写入）
    var versionRow = await db.customSelect('PRAGMA user_version').getSingle();
    expect(versionRow.read<int>('user_version'), 32,
        reason: 'fixture user_version 应从 31 升级到 32');

    // 3. accounts.hidden 仍然存在（current-main v31 行为保留）
    final accountCols =
        await db.customSelect('PRAGMA table_info(accounts)').get();
    final accountColNames =
        accountCols.map((r) => r.read<String>('name')).toSet();
    expect(accountColNames, contains('hidden'),
        reason: 'accounts.hidden 必须保留（current-main v31）');

    // 4. budgets 表 5 个 project 列全部存在
    final budgetCols =
        await db.customSelect('PRAGMA table_info(budgets)').get();
    final budgetColNames =
        budgetCols.map((r) => r.read<String>('name')).toSet();
    expect(
        budgetColNames,
        containsAll(<String>[
          'name',
          'start_at',
          'end_at',
          'exclude_from_monthly_total',
          'status',
        ]),
        reason: 'budgets 表必须包含全部 5 个 project 列');

    // 5. transactions.project_budget_sync_id 存在
    final txCols =
        await db.customSelect('PRAGMA table_info(transactions)').get();
    final txColNames = txCols.map((r) => r.read<String>('name')).toSet();
    expect(txColNames, contains('project_budget_sync_id'),
        reason: 'transactions.project_budget_sync_id 必须存在');

    // 6. idx_transactions_project_budget_sync_id 索引存在
    final indexRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND tbl_name='transactions' AND name='idx_transactions_project_budget_sync_id'",
        )
        .get();
    expect(indexRows, hasLength(1),
        reason: 'idx_transactions_project_budget_sync_id 索引必须存在');
    await expectProjectLinkInvariantSchema(db);

    // 7. 数据库关闭后重新打开仍成功，版本仍为 32
    await db.close();
    db = BeeDatabase.forTesting(NativeDatabase(upgradedFile));
    addTearDown(db.close);

    versionRow = await db.customSelect('PRAGMA user_version').getSingle();
    expect(versionRow.read<int>('user_version'), 32,
        reason: '重开后 user_version 仍应为 32');

    // 重开后再验证一次关键列不丢
    final budgetColsReopen =
        await db.customSelect('PRAGMA table_info(budgets)').get();
    final budgetColNamesReopen =
        budgetColsReopen.map((r) => r.read<String>('name')).toSet();
    expect(
        budgetColNamesReopen,
        containsAll(<String>[
          'name',
          'start_at',
          'end_at',
          'exclude_from_monthly_total',
          'status',
        ]));

    final accountColsReopen =
        await db.customSelect('PRAGMA table_info(accounts)').get();
    final accountColNamesReopen =
        accountColsReopen.map((r) => r.read<String>('name')).toSet();
    expect(accountColNamesReopen, contains('hidden'));
  });

  test('protected Phase3 v31 fixture -> v32: 补 hidden 并保留专项 schema', () async {
    SharedPreferences.setMockInitialValues({});

    final fixture = File('test/fixtures/beecount_schema_phase3_v31.sqlite');
    expect(fixture.existsSync(), isTrue,
        reason: 'fixture 必须由 protected Phase 3 commit 3243c7b 生成');

    final tempDir =
        await Directory.systemTemp.createTemp('beecount-phase3-v31-v32-');
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    final upgradedFile = File('${tempDir.path}/upgraded.sqlite');
    await fixture.copy(upgradedFile.path);

    final db = BeeDatabase.forTesting(NativeDatabase(upgradedFile));
    addTearDown(db.close);

    final versionRow = await db.customSelect('PRAGMA user_version').getSingle();
    expect(versionRow.read<int>('user_version'), 32);

    final accountCols =
        await db.customSelect('PRAGMA table_info(accounts)').get();
    expect(accountCols.map((r) => r.read<String>('name')), contains('hidden'),
        reason: 'Phase3-v31 缺少的 accounts.hidden 必须由 v32 补齐');

    final budgetCols =
        await db.customSelect('PRAGMA table_info(budgets)').get();
    expect(
        budgetCols.map((r) => r.read<String>('name')).toSet(),
        containsAll(<String>{
          'name',
          'start_at',
          'end_at',
          'exclude_from_monthly_total',
          'status',
        }));

    final txCols =
        await db.customSelect('PRAGMA table_info(transactions)').get();
    expect(txCols.map((r) => r.read<String>('name')),
        contains('project_budget_sync_id'));

    final indexRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND name='idx_transactions_project_budget_sync_id'",
        )
        .get();
    expect(indexRows, hasLength(1));
    await expectProjectLinkInvariantSchema(db);
  });

  test('v32 幂等：fresh in-memory db 包含 union schema', () async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, 32);

    // fresh db 也有 accounts.hidden
    final accountCols =
        await db.customSelect('PRAGMA table_info(accounts)').get();
    expect(
      accountCols.map((r) => r.read<String>('name')),
      contains('hidden'),
    );

    // fresh db 也有 project budget 列
    final budgetCols =
        await db.customSelect('PRAGMA table_info(budgets)').get();
    final budgetColNames =
        budgetCols.map((r) => r.read<String>('name')).toSet();
    expect(
        budgetColNames,
        containsAll(<String>[
          'name',
          'start_at',
          'end_at',
          'exclude_from_monthly_total',
          'status',
        ]));

    // fresh db 也有 project_budget_sync_id 列
    final txCols =
        await db.customSelect('PRAGMA table_info(transactions)').get();
    expect(
      txCols.map((r) => r.read<String>('name')),
      contains('project_budget_sync_id'),
    );

    // fresh db 也有索引（onCreate 创建）
    final indexRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND name='idx_transactions_project_budget_sync_id'",
        )
        .get();
    expect(indexRows, hasLength(1));
    await expectProjectLinkInvariantSchema(db);
  });
}
