// v31 sync_diff_service:
// - (M4) 云端 tx 的 projectBudgetSyncId 与本地不同 → 应报为 modified,让
//   batch update 真正写入本地;
// - (Mn5) v6 payload 未带该键(present=false) → 保留本地关联,不清除。
//
// 这两条 review 里 reviewer 明确标出:老代码的 batch update 是"死代码",
// 差异计算不看这个字段;并且默认把 null 当"清除意图",v6 备份重导入会静默
// 清链接。
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' show Value;

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync_diff_service.dart';
import 'package:beecount/cloud/transactions_json.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db, changeTracker: ChangeTracker(db));
    await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L',
          currency: const Value('CNY'),
        ));
  });

  tearDown(() async => db.close());

  Future<void> addProject(String syncId) async {
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
          syncId: Value(syncId),
          ledgerId: 1,
          type: const Value('project'),
          amount: 1,
          period: const Value('once'),
          startDay: const Value(1),
          enabled: const Value(true),
          name: const Value('P'),
          startAt: Value(DateTime.utc(2026, 1, 1)),
          endAt: Value(DateTime.utc(2026, 12, 31)),
          excludeFromMonthlyTotal: const Value(false),
          status: const Value('active'),
        ));
  }

  test('(M4) 云端 tx 显式清除关联 → 计算出 modified,batch update 会清 local', () async {
    await addProject('proj-1');
    // 本地:一条挂 project 的 expense
    final ts = DateTime(2026, 8, 15, 10);
    await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 30,
      happenedAt: ts,
      syncId: 'tx-diff-1',
      projectBudgetSyncId: 'proj-1',
    );
    // 云端:同 syncId,但 present=true + 值 null(显式清除)
    final cloud = ImportTransaction(
      type: 'expense',
      amount: 30,
      happenedAt: ts,
      syncId: 'tx-diff-1',
      projectBudgetSyncIdPresent: true,
      projectBudgetSyncId: null,
    );

    final preview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [cloud],
    );
    expect(preview, isNotNull);
    final modified = preview!.changes
        .where((c) => c.type == SyncChangeType.modified)
        .toList();
    expect(modified, hasLength(1), reason: '项目关联差异应被识别为 modified');
    expect(modified.single.diffDetails.any((d) => d.contains('专项预算')), isTrue);

    // 应用该变更
    await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: 1,
      selectedChanges: modified,
      importData: ImportData(transactions: [cloud]),
    );
    final localTx = await repo.getTransactionBySyncId('tx-diff-1');
    expect(localTx!.projectBudgetSyncId, isNull, reason: '云端显式清除后,本地关联应被清掉');
  });

  test('(Mn5) v6 payload (present=false) → 保留本地关联,不 modified', () async {
    await addProject('proj-keep');
    final ts = DateTime(2026, 8, 15, 10);
    await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 30,
      happenedAt: ts,
      syncId: 'tx-legacy',
      projectBudgetSyncId: 'proj-keep',
    );
    // v6 payload:parser 给 present=false,值 null(默认)
    final cloudV6 = ImportTransaction(
      type: 'expense',
      amount: 30,
      happenedAt: ts,
      syncId: 'tx-legacy',
      projectBudgetSyncIdPresent: false,
      projectBudgetSyncId: null,
    );
    final preview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [cloudV6],
    );
    expect(preview, isNotNull);
    final modified = preview!.changes
        .where((c) => c.type == SyncChangeType.modified)
        .toList();
    expect(modified, isEmpty, reason: 'v6 payload 不该被误判成清除,应保留本地关联');

    // 即便调用方硬把 unchanged 也拿去应用,本地关联也不应被清
    // (batch update 的 Value.absent 保护)。
    final localTx = await repo.getTransactionBySyncId('tx-legacy');
    expect(localTx!.projectBudgetSyncId, 'proj-keep');
  });

  test('alternate diff:不存在 project link 不得更新本地 transaction', () async {
    final ts = DateTime(2026, 8, 15, 10);
    await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 30,
      happenedAt: ts,
      syncId: 'tx-orphan',
    );
    final cloud = ImportTransaction(
      type: 'expense',
      amount: 30,
      happenedAt: ts,
      syncId: 'tx-orphan',
      projectBudgetSyncIdPresent: true,
      projectBudgetSyncId: 'missing-project',
    );
    final preview = await syncDiffService
        .computeDiff(repo: repo, ledgerId: 1, cloudTransactions: [cloud]);
    final result = await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: 1,
      selectedChanges: preview!.changes,
      importData: ImportData(transactions: [cloud]),
    );
    expect(result.modifiedCount, 0);
    expect(
        (await repo.getTransactionBySyncId('tx-orphan'))!.projectBudgetSyncId,
        isNull);
  });

  test('alternate diff:v7 snapshot 先恢复 budget 再应用 linked transaction',
      () async {
    final snapshot = jsonEncode({
      'version': 7,
      'ledgerName': 'Remote',
      'currency': 'CNY',
      'accounts': const [],
      'categories': const [],
      'tags': const [],
      'budgets': [
        {
          'syncId': 'project-remote',
          'ledgerSyncId': 'ledger-remote',
          'type': 'project',
          'amount': 800.0,
          'period': 'once',
          'startDay': 1,
          'enabled': true,
          'name': 'Remote project',
          'startAt': '2026-08-01T00:00:00.000Z',
          'endAt': '2026-09-01T00:00:00.000Z',
          'excludeFromMonthlyTotal': true,
          'status': 'active',
        },
      ],
      'items': [
        {
          'syncId': 'tx-remote',
          'type': 'expense',
          'amount': 120.0,
          'happenedAt': '2026-08-15T10:00:00.000Z',
          'projectBudgetSyncId': 'project-remote',
        },
      ],
      'count': 1,
    });
    final importData = parseJsonToImportData(snapshot);

    final preview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: importData.transactions,
    );
    expect(preview, isNotNull);
    expect(preview!.addedCount, 1);

    final result = await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: 1,
      selectedChanges: preview.changes,
      importData: importData,
    );

    expect(result.addedCount, 1);
    final project = await repo.getProjectBudgetBySyncId('project-remote');
    final transaction = await repo.getTransactionBySyncId('tx-remote');
    expect(project, isNotNull);
    expect(transaction, isNotNull);
    expect(project!.ledgerId, 1);
    expect(transaction!.ledgerId, project.ledgerId);
    expect(transaction.projectBudgetSyncId, project.syncId);
  });

  test('alternate diff:只应用选中 transaction,不得覆盖或创建未选 budgets', () async {
    await addProject('project-existing');
    final ts = DateTime(2026, 8, 15, 10);
    await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 30,
      happenedAt: ts,
      syncId: 'tx-selected',
      projectBudgetSyncId: 'project-existing',
    );
    final cloud = ImportTransaction(
      type: 'expense',
      amount: 40,
      happenedAt: ts,
      syncId: 'tx-selected',
      projectBudgetSyncIdPresent: true,
      projectBudgetSyncId: 'project-existing',
    );
    final preview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [cloud],
    );
    final selected = preview!.changes
        .where((c) => c.type == SyncChangeType.modified)
        .toList();
    expect(selected, hasLength(1));

    await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: 1,
      selectedChanges: selected,
      importData: ImportData(
        transactions: [cloud],
        budgets: [
          ImportBudget(
            syncId: 'project-existing',
            type: 'project',
            amount: 999,
            name: 'Remote changed project',
            startAt: DateTime.utc(2026, 1, 1),
            endAt: DateTime.utc(2026, 12, 31),
            excludeFromMonthlyTotal: false,
            status: 'active',
          ),
          ImportBudget(
            syncId: 'project-unrelated',
            type: 'project',
            amount: 888,
            name: 'Unrelated project',
            startAt: DateTime.utc(2026, 1, 1),
            endAt: DateTime.utc(2026, 12, 31),
            excludeFromMonthlyTotal: false,
            status: 'active',
          ),
        ],
      ),
    );

    expect((await repo.getTransactionBySyncId('tx-selected'))!.amount, 40);
    expect(
        (await repo.getProjectBudgetBySyncId('project-existing'))!.amount, 1);
    expect(await repo.getBudgetBySyncId('project-unrelated'), isNull);
  });

  test('本地新增 transaction 不得引用不存在的 project budget', () async {
    await expectLater(
      repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 10,
        happenedAt: DateTime.utc(2026, 8, 1),
        projectBudgetSyncId: 'missing-project',
      ),
      throwsStateError,
    );
  });

  test('本地更新 transaction 不得写入不存在的 project budget', () async {
    await addProject('proj-valid');
    final id = await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime.utc(2026, 8, 1),
      projectBudgetSyncId: 'proj-valid',
    );
    await expectLater(
      repo.updateTransaction(
        id: id,
        type: 'expense',
        amount: 10,
        projectBudgetSyncId: 'missing-project',
      ),
      throwsStateError,
    );
    expect(
        (await repo.getTransactionById(id))!.projectBudgetSyncId, 'proj-valid');
  });
}
