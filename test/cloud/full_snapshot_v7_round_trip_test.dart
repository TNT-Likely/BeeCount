// v31 v7 快照全量往返(冻结合同关键点):
// - export 一个含 total/project/交易关联的账本 → v7 payload 结构完整;
// - parseJsonToImportData 恢复 budgets 数组和 items 的 projectBudgetSyncId;
// - DataImportService.importData 恢复顺序:先建 project 行,后插 items,
//   使 items 的 projectBudgetSyncId 与 project 行的 syncId 一致(即"跨端恢复
//   后关联仍指向真正的 project 而非孤儿字符串")。
//
// R3/R4:v6 时 budgets 数组丢失、items 的项目关联无处放。v7 修复该二问题。
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/transactions_json.dart';
import 'package:beecount/services/data_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase srcDb;
  late BeeDatabase dstDb;
  late LocalRepository dstRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    srcDb = BeeDatabase.forTesting(NativeDatabase.memory());
    dstDb = BeeDatabase.forTesting(NativeDatabase.memory());
    dstRepo = LocalRepository(dstDb, changeTracker: ChangeTracker(dstDb));
    // seed 目标账本
    await dstDb.into(dstDb.ledgers).insert(LedgersCompanion.insert(
          name: 'Restored',
          currency: const Value('CNY'),
        ));
  });

  tearDown(() async {
    await srcDb.close();
    await dstDb.close();
  });

  test('v7 export + import 往返:budgets 先于 items 恢复,项目关联保留', () async {
    // ---- src: 建一个账本、一条 total、一条 project、一条挂到 project 的支出 ----
    final srcLid =
        await srcDb.into(srcDb.ledgers).insert(LedgersCompanion.insert(
              name: 'Src',
              currency: const Value('CNY'),
              syncId: const Value('ledger-src'),
            ));
    // total
    await srcDb.into(srcDb.budgets).insert(BudgetsCompanion.insert(
          ledgerId: srcLid,
          type: const Value('total'),
          amount: 5000.0,
          syncId: const Value('total-1'),
        ));
    // project
    await srcDb.into(srcDb.budgets).insert(BudgetsCompanion.insert(
          ledgerId: srcLid,
          type: const Value('project'),
          amount: 2400.0,
          syncId: const Value('proj-1'),
          name: const Value('Studio refresh'),
          startAt: Value(DateTime.utc(2026, 8, 1)),
          endAt: Value(DateTime.utc(2026, 10, 1)),
          excludeFromMonthlyTotal: const Value(true),
          status: const Value('active'),
        ));
    // 一笔挂 project 的支出
    await srcDb.into(srcDb.transactions).insert(TransactionsCompanion.insert(
          ledgerId: srcLid,
          type: 'expense',
          amount: 100.0,
          happenedAt: Value(DateTime.utc(2026, 8, 15)),
          syncId: const Value('tx-1'),
          projectBudgetSyncId: const Value('proj-1'),
        ));

    // ---- export ----
    final jsonStr = await exportTransactionsJson(srcDb, srcLid);
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    expect(decoded['version'], 7);
    expect(decoded['budgets'], isA<List>());
    expect((decoded['budgets'] as List).length, 2); // total + project
    final exportedProject = (decoded['budgets'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((b) => b['type'] == 'project');
    expect(exportedProject['ledgerSyncId'], 'ledger-src',
        reason: 'v7 project budget payload 必须带所属账本 syncId');
    expect((decoded['items'] as List).first, contains('projectBudgetSyncId'));

    // ---- parse ----
    final imported = parseJsonToImportData(jsonStr);
    expect(imported.budgets, hasLength(2));
    expect(imported.transactions.single.projectBudgetSyncId, 'proj-1');
    expect(imported.transactions.single.projectBudgetSyncIdPresent, isTrue);

    // ---- import 到全新目标库 ----
    // 目标账本 id=1(setUp 中插的)
    final result = await dataImportService.importData(
      dstRepo,
      1,
      imported,
      defaultCurrency: 'CNY',
      recordChanges: false,
    );
    expect(result.inserted, 1);

    // 校验:project 已存在,且 tx 的 projectBudgetSyncId 指向的还是同一 syncId
    final dstProject = await (dstDb.select(dstDb.budgets)
          ..where((b) => b.syncId.equals('proj-1')))
        .getSingleOrNull();
    expect(dstProject, isNotNull);
    expect(dstProject!.type, 'project');
    expect(dstProject.name, 'Studio refresh');

    final dstTx = await (dstDb.select(dstDb.transactions)
          ..where((t) => t.syncId.equals('tx-1')))
        .getSingleOrNull();
    expect(dstTx, isNotNull);
    expect(dstTx!.projectBudgetSyncId, 'proj-1');
    // 目的账本的 project.syncId 必须与 tx.projectBudgetSyncId 一致(不是孤儿字符串)
    expect(dstTx.projectBudgetSyncId, dstProject.syncId);
  });

  test('(BL1) importBudgets 用 payload syncId 记 change;不再泄漏临时 UUID', () async {
    // reviewer 报告的场景:importBudgets 曾先 createBudget(生成临时 UUID + 记
    // change)再 overwriteBudgetSyncId 只改 budgets 表 → local_changes 与
    // budgets 分裂。fix 后:走 restoreBudgetBySyncId,同一 syncId 落库并按需
    // 由 importBudgets 手动 recordLedgerChange。此测试确认 local_changes.
    // entity_sync_id 完全等于 payload 里的 syncId。
    const projSyncId = 'proj-payload-1';
    final imported = ImportData(
      budgets: [
        ImportBudget(
          syncId: projSyncId,
          type: 'project',
          amount: 500,
          name: 'X',
          startAt: DateTime.utc(2026, 1, 1),
          endAt: DateTime.utc(2026, 2, 1),
          status: 'active',
        ),
      ],
    );
    // recordChanges=true + 传 changeTracker,模拟 CSV/manual import 路径
    final tracker = dstRepo.changeTracker;
    expect(tracker, isNotNull);
    await dataImportService.importData(
      dstRepo,
      1,
      imported,
      defaultCurrency: 'CNY',
      recordChanges: true,
      changeTracker: tracker,
    );

    final change = await (dstDb.select(dstDb.localChanges)
          ..where((c) => c.entityType.equals('budget'))
          ..where((c) => c.entitySyncId.equals(projSyncId)))
        .getSingleOrNull();
    expect(change, isNotNull,
        reason: 'local_changes 应有一条 entity_sync_id=projSyncId 的 create');
    expect(change!.action, 'create');
    // 且 budgets 表里同 syncId 存在(不是别的临时 UUID)
    final row = await (dstDb.select(dstDb.budgets)
          ..where((b) => b.syncId.equals(projSyncId)))
        .getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.name, 'X');
  });

  test('(BL2) importBudgets 在 recordChanges=false 时不记 change(fullPull 路径)',
      () async {
    final imported = ImportData(
      budgets: [
        ImportBudget(
          syncId: 'proj-pull-1',
          type: 'project',
          amount: 500,
          name: 'X',
          startAt: DateTime.utc(2026, 1, 1),
          endAt: DateTime.utc(2026, 2, 1),
          status: 'active',
        ),
      ],
    );
    final tracker = dstRepo.changeTracker;
    await dataImportService.importData(
      dstRepo,
      1,
      imported,
      defaultCurrency: 'CNY',
      recordChanges: false,
      changeTracker: tracker,
    );
    // budgets 已落库
    final row = await (dstDb.select(dstDb.budgets)
          ..where((b) => b.syncId.equals('proj-pull-1')))
        .getSingleOrNull();
    expect(row, isNotNull);
    // 但 local_changes 应为空(避免反向回推)
    final count = await (dstDb.select(dstDb.localChanges)
          ..where((c) => c.entitySyncId.equals('proj-pull-1')))
        .get();
    expect(count, isEmpty,
        reason: 'recordChanges=false 时不能记 change,否则 fullPull 会反向回推');
  });

  test('(M3) 重复 import 同 syncId 的 total/category 不再 duplicate', () async {
    // 老实现 idempotency 只查了 project;total/category 会被再插一份。
    final imported = ImportData(
      budgets: [
        const ImportBudget(syncId: 't-1', type: 'total', amount: 500),
        const ImportBudget(syncId: 'c-1', type: 'category', amount: 100),
      ],
    );
    await dataImportService.importData(
      dstRepo,
      1,
      imported,
      defaultCurrency: 'CNY',
      recordChanges: false,
    );
    await dataImportService.importData(
      dstRepo,
      1,
      imported,
      defaultCurrency: 'CNY',
      recordChanges: false,
    );
    // 两轮 import 后仍是 1 条 total + 1 条 category(而不是 2+2)
    final all = await dstDb.select(dstDb.budgets).get();
    expect(all, hasLength(2));
    expect(all.where((b) => b.syncId == 't-1').length, 1);
    expect(all.where((b) => b.syncId == 'c-1').length, 1);
  });

  test('import 同 syncId project 到另一账本时跳过并保留原交易关联', () async {
    final sourceLedgerId =
        await dstDb.into(dstDb.ledgers).insert(LedgersCompanion.insert(
              name: 'Existing ledger',
              syncId: const Value('ledger-existing'),
            ));
    await dstDb.into(dstDb.budgets).insert(BudgetsCompanion.insert(
          ledgerId: sourceLedgerId,
          type: const Value('project'),
          amount: 100,
          syncId: const Value('project-cross-ledger'),
          name: const Value('Existing project'),
          startAt: Value(DateTime.utc(2026, 1, 1)),
          endAt: Value(DateTime.utc(2026, 12, 31)),
          status: const Value('active'),
        ));
    await dstDb.into(dstDb.transactions).insert(TransactionsCompanion.insert(
          ledgerId: sourceLedgerId,
          type: 'expense',
          amount: 20,
          happenedAt: Value(DateTime.utc(2026, 6, 1)),
          syncId: const Value('tx-existing-project'),
          projectBudgetSyncId: const Value('project-cross-ledger'),
        ));

    await dataImportService.importData(
      dstRepo,
      1,
      ImportData(
        budgets: [
          ImportBudget(
            syncId: 'project-cross-ledger',
            type: 'project',
            amount: 999,
            name: 'Incoming project',
            startAt: DateTime.utc(2026, 2, 1),
            endAt: DateTime.utc(2026, 11, 1),
            status: 'active',
          ),
        ],
      ),
      recordChanges: false,
    );

    final projects = await (dstDb.select(dstDb.budgets)
          ..where((b) => b.syncId.equals('project-cross-ledger')))
        .get();
    expect(projects, hasLength(1));
    expect(projects.single.ledgerId, sourceLedgerId);
    expect(projects.single.name, 'Existing project');
    expect(projects.single.amount, 100);

    final tx = await (dstDb.select(dstDb.transactions)
          ..where((t) => t.syncId.equals('tx-existing-project')))
        .getSingle();
    expect(tx.ledgerId, sourceLedgerId);
    expect(tx.projectBudgetSyncId, projects.single.syncId);
  });

  test(
      'parseJsonToImportData:v6 快照(无 budgets 键)不 crash,budgets 为空 '
      '+ projectBudgetSyncIdPresent=false(Mn5)', () async {
    // 构造一份 v6 shape 的 JSON:没有 top-level `budgets`,items 不带
    // projectBudgetSyncId。
    final v6 = {
      'version': 6,
      'ledgerName': 'L',
      'currency': 'CNY',
      'accounts': const [],
      'categories': const [],
      'tags': const [],
      'items': [
        {
          'type': 'expense',
          'amount': 10.0,
          'happenedAt': '2026-01-01T00:00:00Z',
          'syncId': 'tx-legacy',
        },
      ],
    };
    final parsed = parseJsonToImportData(jsonEncode(v6));
    expect(parsed.budgets, isEmpty);
    expect(parsed.transactions.single.projectBudgetSyncId, isNull);
    // v6 payload 无键 → present=false,让 sync_diff 走"保留本地关联"
    expect(parsed.transactions.single.projectBudgetSyncIdPresent, isFalse);
  });

  test('v7 transaction 缺 projectBudgetSyncId → fail-closed 丢弃该 item', () {
    final v7 = {
      'version': 7,
      'accounts': const [],
      'categories': const [],
      'tags': const [],
      'budgets': const [],
      'items': [
        {
          'type': 'expense',
          'amount': 10.0,
          'happenedAt': '2026-01-01T00:00:00Z',
          'syncId': 'tx-missing-project-field',
        },
        {
          'type': 'expense',
          'amount': 20.0,
          'happenedAt': '2026-01-02T00:00:00Z',
          'syncId': 'tx-valid',
          'projectBudgetSyncId': null,
        },
      ],
    };

    final parsed = parseJsonToImportData(jsonEncode(v7));

    expect(parsed.transactions.map((tx) => tx.syncId), ['tx-valid']);
    expect(parsed.transactions.single.projectBudgetSyncIdPresent, isTrue);
  });

  test('v7 transaction 非 String projectBudgetSyncId → fail-closed 丢弃该 item',
      () {
    final v7 = {
      'version': 7,
      'accounts': const [],
      'categories': const [],
      'tags': const [],
      'budgets': const [],
      'items': [
        {
          'type': 'expense',
          'amount': 10.0,
          'happenedAt': '2026-01-01T00:00:00Z',
          'syncId': 'tx-wrong-project-field',
          'projectBudgetSyncId': 42,
        },
        {
          'type': 'expense',
          'amount': 20.0,
          'happenedAt': '2026-01-02T00:00:00Z',
          'syncId': 'tx-valid',
          'projectBudgetSyncId': 'project-1',
        },
      ],
    };

    final parsed = parseJsonToImportData(jsonEncode(v7));

    expect(parsed.transactions.map((tx) => tx.syncId), ['tx-valid']);
    expect(parsed.transactions.single.projectBudgetSyncId, 'project-1');
  });

  test('v7 project name/startAt/endAt wrong type → fail-closed per item', () {
    Map<String, dynamic> projectWith(String field, Object value) => {
          'syncId': 'project-wrong-$field',
          'type': 'project',
          'amount': 100,
          'name': 'Project',
          'startAt': '2026-01-01T00:00:00Z',
          'endAt': '2026-02-01T00:00:00Z',
          'excludeFromMonthlyTotal': false,
          'status': 'active',
          field: value,
        };

    for (final malformedProject in [
      projectWith('name', 42),
      projectWith('startAt', false),
      projectWith('endAt', const []),
      projectWith('excludeFromMonthlyTotal', 'false'),
      projectWith('status', 1),
    ]) {
      final v7 = {
        'version': 7,
        'accounts': const [],
        'categories': const [],
        'tags': const [],
        'items': const [],
        'budgets': [malformedProject],
      };

      expect(parseJsonToImportData(jsonEncode(v7)).budgets, isEmpty);
    }
  });

  test(
      'v7 project invalid values → fail-closed per item, valid sibling survives',
      () {
    Map<String, dynamic> project({
      required String syncId,
      String name = 'Project',
      String startAt = '2026-01-01T00:00:00Z',
      String endAt = '2026-02-01T00:00:00Z',
      String status = 'active',
      num amount = 100,
    }) =>
        {
          'syncId': syncId,
          'type': 'project',
          'amount': amount,
          'name': name,
          'startAt': startAt,
          'endAt': endAt,
          'excludeFromMonthlyTotal': false,
          'status': status,
        };

    final v7 = {
      'version': 7,
      'accounts': const [],
      'categories': const [],
      'tags': const [],
      'items': const [],
      'budgets': [
        project(syncId: 'empty-name', name: '  '),
        project(syncId: 'bad-start', startAt: 'not-a-date'),
        project(syncId: 'bad-end', endAt: 'not-a-date'),
        project(
          syncId: 'bad-range',
          startAt: '2026-02-01T00:00:00Z',
          endAt: '2026-01-01T00:00:00Z',
        ),
        project(syncId: 'bad-status', status: 'paused'),
        project(syncId: 'zero-amount', amount: 0),
        project(syncId: 'negative-amount', amount: -1),
        project(syncId: 'valid-project'),
      ],
    };

    final parsed = parseJsonToImportData(jsonEncode(v7));

    expect(parsed.budgets.map((budget) => budget.syncId), ['valid-project']);
  });

  test('unsupported future snapshot version → controlled FormatException', () {
    final futureSnapshot = {
      'version': 8,
      'accounts': const [],
      'categories': const [],
      'tags': const [],
      'items': const [],
      'budgets': const [],
    };

    expect(
      () => parseJsonToImportData(jsonEncode(futureSnapshot)),
      throwsA(isA<FormatException>()),
    );
  });

  test('v7 project 缺关键字段 → parser fail-closed 丢弃 budget', () {
    final v7 = {
      'version': 7,
      'accounts': const [],
      'categories': const [],
      'tags': const [],
      'items': const [],
      'budgets': [
        {
          'syncId': 'project-missing-status',
          'type': 'project',
          'amount': 100,
          'name': '坏项目',
          'startAt': '2026-01-01T00:00:00Z',
          'endAt': '2026-02-01T00:00:00Z',
          'excludeFromMonthlyTotal': false,
        },
      ],
    };
    expect(parseJsonToImportData(jsonEncode(v7)).budgets, isEmpty);
  });

  test('v7 payload:显式 null 键 → present=true,值 null → 意图=清除关联', () async {
    final v7 = {
      'version': 7,
      'ledgerName': 'L',
      'currency': 'CNY',
      'accounts': const [],
      'categories': const [],
      'tags': const [],
      'budgets': const [],
      'items': [
        {
          'type': 'expense',
          'amount': 10.0,
          'happenedAt': '2026-01-01T00:00:00Z',
          'syncId': 'tx-clear',
          'projectBudgetSyncId': null, // 显式 null
        },
      ],
    };
    final parsed = parseJsonToImportData(jsonEncode(v7));
    expect(parsed.transactions.single.projectBudgetSyncIdPresent, isTrue);
    expect(parsed.transactions.single.projectBudgetSyncId, isNull);
  });

  test('已有同 syncId transaction:v6 缺键保留、v7 null 清除且不重复插入', () async {
    await dstDb.into(dstDb.budgets).insert(BudgetsCompanion.insert(
          ledgerId: 1,
          type: const Value('project'),
          amount: 100,
          syncId: const Value('proj-local'),
          name: const Value('Local project'),
          startAt: Value(DateTime.utc(2026, 1, 1)),
          endAt: Value(DateTime.utc(2026, 2, 1)),
          excludeFromMonthlyTotal: const Value(false),
          status: const Value('active'),
        ));
    await dstDb.into(dstDb.transactions).insert(TransactionsCompanion.insert(
          ledgerId: 1,
          type: 'expense',
          amount: 10,
          happenedAt: Value(DateTime.utc(2026, 1, 1)),
          syncId: const Value('tx-existing'),
          projectBudgetSyncId: const Value('proj-local'),
        ));
    ImportData payload({required bool present}) => ImportData(transactions: [
          ImportTransaction(
            type: 'expense',
            amount: 20,
            happenedAt: DateTime.utc(2026, 1, 2),
            syncId: 'tx-existing',
            projectBudgetSyncIdPresent: present,
          ),
        ]);
    await dataImportService.importData(dstRepo, 1, payload(present: false),
        recordChanges: false);
    var rows = await (dstDb.select(dstDb.transactions)
          ..where((t) => t.syncId.equals('tx-existing')))
        .get();
    expect(rows, hasLength(1));
    expect(rows.single.projectBudgetSyncId, 'proj-local');
    await dataImportService.importData(dstRepo, 1, payload(present: true),
        recordChanges: false);
    rows = await (dstDb.select(dstDb.transactions)
          ..where((t) => t.syncId.equals('tx-existing')))
        .get();
    expect(rows, hasLength(1));
    expect(rows.single.projectBudgetSyncId, isNull);
  });

  test('v7 parser 隔离各数组坏 sibling 并保留合法 item', () {
    final parsed = parseJsonToImportData(jsonEncode({
      'version': 7,
      'ledgerName': 'L',
      'currency': 'CNY',
      'accounts': [
        42,
        {'name': 7},
        {'name': 'Cash', 'currency': 'CNY'},
      ],
      'categories': [
        false,
        {'name': 'Food', 'kind': 'expense'},
      ],
      'tags': [
        'bad',
        {'name': 'Trip', 'color': '#fff'},
      ],
      'budgets': [
        42,
        {'syncId': 'bad-budget', 'type': 'total', 'amount': 'bad'},
        {'syncId': 'total-ok', 'type': 'total', 'amount': 100.0},
      ],
      'items': [
        42,
        {
          'type': 'expense',
          'amount': 'bad',
          'happenedAt': '2026-01-01T00:00:00Z',
          'projectBudgetSyncId': null,
        },
        {
          'type': 'expense',
          'amount': 1.0,
          'happenedAt': '2026-01-01T00:00:00Z',
          'projectBudgetSyncId': null,
          'attachments': [42],
        },
        {
          'type': 'expense',
          'amount': 10.0,
          'happenedAt': '2026-01-01T00:00:00Z',
          'syncId': 'tx-ok',
          'projectBudgetSyncId': null,
        },
      ],
    }));

    expect(parsed.accounts.map((e) => e.name), ['Cash']);
    expect(parsed.categories.map((e) => e.name), ['Food']);
    expect(parsed.tags.map((e) => e.name), ['Trip']);
    expect(parsed.budgets.map((e) => e.syncId), ['total-ok']);
    expect(parsed.transactions.map((e) => e.syncId), ['tx-ok']);
  });
}
