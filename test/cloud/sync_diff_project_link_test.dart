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
import 'package:beecount/data/repositories/transaction_repository.dart'
    show BatchAttachmentData;
import 'package:beecount/services/data_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late _CountingLocalRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _CountingLocalRepository(db, changeTracker: ChangeTracker(db));
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

  test('alternate diff:失败的 modified transaction 回滚其新建 project 依赖', () async {
    final ts = DateTime.utc(2026, 8, 15, 10);
    await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 30,
      happenedAt: ts,
      syncId: 'tx-project-rollback',
    );
    final cloud = ImportTransaction(
      type: 'income',
      amount: 30,
      happenedAt: ts,
      syncId: 'tx-project-rollback',
      projectBudgetSyncIdPresent: true,
      projectBudgetSyncId: 'project-created-then-rollback',
    );
    final importData = ImportData(
      transactions: [cloud],
      budgets: [
        ImportBudget(
          syncId: 'project-created-then-rollback',
          type: 'project',
          amount: 100,
          name: 'P',
          startAt: DateTime.utc(2026, 8, 1),
          endAt: DateTime.utc(2026, 9, 1),
          excludeFromMonthlyTotal: true,
          status: 'active',
        ),
      ],
    );

    final preview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [cloud],
    );
    final result = await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: 1,
      selectedChanges: preview!.changes,
      importData: importData,
    );

    expect(result.modifiedCount, 0);
    expect(
      await repo.getProjectBudgetBySyncId('project-created-then-rollback'),
      isNull,
      reason: 'selected transaction 失败时不得留下未报告的 project 依赖',
    );
    final local = await repo.getTransactionBySyncId('tx-project-rollback');
    expect(local!.type, 'expense');
    expect(local.projectBudgetSyncId, isNull);
  });

  test('alternate diff:modified transaction 与新建 project 依赖原子成功', () async {
    final ts = DateTime.utc(2026, 8, 16, 10);
    await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 10,
      happenedAt: ts,
      syncId: 'tx-project-atomic-success',
    );
    final cloud = ImportTransaction(
      type: 'expense',
      amount: 20,
      happenedAt: ts,
      syncId: 'tx-project-atomic-success',
      projectBudgetSyncIdPresent: true,
      projectBudgetSyncId: 'project-atomic-success',
    );
    final importData = ImportData(
      transactions: [cloud],
      budgets: [
        ImportBudget(
          syncId: 'project-atomic-success',
          type: 'project',
          amount: 100,
          name: 'P',
          startAt: DateTime.utc(2026, 8, 1),
          endAt: DateTime.utc(2026, 9, 1),
          excludeFromMonthlyTotal: true,
          status: 'active',
        ),
      ],
    );

    final preview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [cloud],
    );
    final result = await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: 1,
      selectedChanges: preview!.changes,
      importData: importData,
    );

    expect(result.modifiedCount, 1);
    expect(await repo.getProjectBudgetBySyncId('project-atomic-success'),
        isNotNull);
    final local =
        await repo.getTransactionBySyncId('tx-project-atomic-success');
    expect(local!.amount, 20);
    expect(local.projectBudgetSyncId, 'project-atomic-success');
  });

  test('alternate diff:同一新 project 的 added siblings 在首项成功后回到 batch', () async {
    final ts = DateTime.utc(2026, 8, 17, 10);
    ImportTransaction cloud(String syncId, double amount) => ImportTransaction(
          type: 'expense',
          amount: amount,
          happenedAt: ts,
          syncId: syncId,
          projectBudgetSyncIdPresent: true,
          projectBudgetSyncId: 'project-shared-added',
        );
    final clouds = [
      for (var i = 0; i < 20; i++) cloud('tx-shared-$i', i + 1),
    ];
    final importData = ImportData(
      transactions: clouds,
      budgets: [
        ImportBudget(
          syncId: 'project-shared-added',
          type: 'project',
          amount: 100,
          name: 'P',
          startAt: DateTime.utc(2026, 8, 1),
          endAt: DateTime.utc(2026, 9, 1),
          excludeFromMonthlyTotal: true,
          status: 'active',
        ),
      ],
    );
    final preview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: clouds,
    );
    repo.getBudgetBySyncIdCalls = 0;
    repo.getProjectBudgetBySyncIdCalls = 0;

    final result = await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: 1,
      selectedChanges: preview!.changes,
      importData: importData,
    );

    expect(result.addedCount, 20);
    expect(repo.getBudgetBySyncIdCalls, 0,
        reason: 'strict chunk 不再使用旧 planning API');
    expect(repo.getProjectBudgetBySyncIdCalls, 2,
        reason:
            'strict existence check + DataImport cache 各一次，不随 sibling 数量增长');
  });

  test('alternate diff:失败的 added transaction 回滚其新建 project 依赖', () async {
    final ts = DateTime.utc(2026, 8, 15, 10);
    final cloud = ImportTransaction(
      type: 'income',
      amount: 30,
      happenedAt: ts,
      syncId: 'tx-added-project-rollback',
      projectBudgetSyncIdPresent: true,
      projectBudgetSyncId: 'project-added-then-rollback',
    );
    final importData = ImportData(
      transactions: [cloud],
      budgets: [
        ImportBudget(
          syncId: 'project-added-then-rollback',
          type: 'project',
          amount: 100,
          name: 'P',
          startAt: DateTime.utc(2026, 8, 1),
          endAt: DateTime.utc(2026, 9, 1),
          excludeFromMonthlyTotal: true,
          status: 'active',
        ),
      ],
    );

    final preview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [cloud],
    );
    final result = await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: 1,
      selectedChanges: preview!.changes,
      importData: importData,
    );

    expect(result.addedCount, 0);
    expect(
        await repo.getTransactionBySyncId('tx-added-project-rollback'), isNull);
    expect(
      await repo.getProjectBudgetBySyncId('project-added-then-rollback'),
      isNull,
      reason: 'selected added transaction 失败时不得留下未报告的 project 依赖',
    );
  });

  test('alternate diff:成功的 selected added 只导入其实际元数据依赖', () async {
    final cloud = ImportTransaction(
      type: 'expense',
      amount: 30,
      happenedAt: DateTime.utc(2026, 8, 18, 9),
      syncId: 'tx-metadata-selected',
      categoryName: 'SelectedCategory',
      categoryKind: 'expense',
      accountName: 'SelectedAccount',
      tagNames: const ['SelectedTag'],
    );
    final preview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [cloud],
    );
    final result = await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: 1,
      selectedChanges: preview!.changes,
      importData: ImportData(
        transactions: [cloud],
        accounts: const [
          ImportAccount(name: 'SelectedAccount'),
          ImportAccount(name: 'UnselectedAccount'),
        ],
        categories: const [
          ImportCategory(name: 'SelectedCategory', kind: 'expense'),
          ImportCategory(name: 'UnselectedCategory', kind: 'expense'),
        ],
        tags: const [
          ImportTag(name: 'SelectedTag'),
          ImportTag(name: 'UnselectedTag'),
        ],
      ),
    );

    expect(result.addedCount, 1);
    expect((await db.select(db.accounts).get()).map((row) => row.name),
        ['SelectedAccount']);
    expect((await db.select(db.categories).get()).map((row) => row.name),
        ['SelectedCategory']);
    expect((await db.select(db.tags).get()).map((row) => row.name),
        ['SelectedTag']);
    final tx = await repo.getTransactionBySyncId('tx-metadata-selected');
    expect(tx!.accountId, isNotNull);
    expect(tx.categoryId, isNotNull);
  });

  test('alternate diff:失败的 selected added 不留下选中或未选元数据依赖', () async {
    final cloud = ImportTransaction(
      type: 'income',
      amount: 30,
      happenedAt: DateTime.utc(2026, 8, 18, 10),
      syncId: 'tx-metadata-rollback',
      categoryName: 'SelectedCategory',
      categoryKind: 'income',
      accountName: 'SelectedAccount',
      tagNames: const ['SelectedTag'],
      projectBudgetSyncIdPresent: true,
      projectBudgetSyncId: 'project-metadata-rollback',
    );
    final preview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [cloud],
    );
    final result = await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: 1,
      selectedChanges: preview!.changes,
      importData: ImportData(
        transactions: [cloud],
        accounts: const [
          ImportAccount(name: 'SelectedAccount'),
          ImportAccount(name: 'UnselectedAccount'),
        ],
        categories: const [
          ImportCategory(name: 'SelectedCategory', kind: 'income'),
          ImportCategory(name: 'UnselectedCategory', kind: 'expense'),
        ],
        tags: const [
          ImportTag(name: 'SelectedTag'),
          ImportTag(name: 'UnselectedTag'),
        ],
        budgets: [
          ImportBudget(
            syncId: 'project-metadata-rollback',
            type: 'project',
            amount: 100,
            name: 'P',
            startAt: DateTime.utc(2026, 8, 1),
            endAt: DateTime.utc(2026, 9, 1),
            status: 'active',
          ),
        ],
      ),
    );

    expect(result.totalCount, 0);
    expect(await db.select(db.accounts).get(), isEmpty);
    expect(await db.select(db.categories).get(), isEmpty);
    expect(await db.select(db.tags).get(), isEmpty);
    expect(await repo.getProjectBudgetBySyncId('project-metadata-rollback'),
        isNull);
  });

  test('alternate diff:valid-invalid-valid selected added 只隔离失败 sibling',
      () async {
    await addProject('project-sibling-isolation');
    ImportTransaction cloud(String syncId, String type) => ImportTransaction(
          type: type,
          amount: 10,
          happenedAt: DateTime.utc(2026, 8, 19, 10),
          syncId: syncId,
          projectBudgetSyncIdPresent: true,
          projectBudgetSyncId: 'project-sibling-isolation',
        );
    final clouds = [
      cloud('valid-a', 'expense'),
      cloud('invalid-b', 'income'),
      cloud('valid-c', 'expense'),
    ];
    final preview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: clouds,
    );

    final result = await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: 1,
      selectedChanges: preview!.changes,
      importData: ImportData(transactions: clouds),
    );

    expect(result.addedCount, 2);
    expect(await repo.getTransactionBySyncId('valid-a'), isNotNull);
    expect(await repo.getTransactionBySyncId('invalid-b'), isNull);
    expect(await repo.getTransactionBySyncId('valid-c'), isNotNull);
  });

  test('alternate diff:post-relation batch failure 二分后只提交健康 siblings',
      () async {
    final failingRepo = _ThrowAfterRelationBatchRepository(
      db,
      failingSyncId: 'relation-invalid-b',
      changeTracker: ChangeTracker(db),
    );
    ImportTransaction cloud(String syncId) => ImportTransaction(
          type: 'expense',
          amount: 10,
          happenedAt: DateTime.utc(2026, 8, 19, 10),
          syncId: syncId,
          tagNames: const ['RelationTag'],
        );
    final clouds = [
      cloud('relation-valid-a'),
      cloud('relation-invalid-b'),
      cloud('relation-valid-c'),
    ];
    final preview = await syncDiffService.computeDiff(
      repo: failingRepo,
      ledgerId: 1,
      cloudTransactions: clouds,
    );

    final result = await syncDiffService.applySyncChanges(
      repo: failingRepo,
      ledgerId: 1,
      selectedChanges: preview!.changes,
      importData: ImportData(
        transactions: clouds,
        tags: const [ImportTag(name: 'RelationTag')],
      ),
    );

    expect(result.addedCount, 2);
    expect(await failingRepo.getTransactionBySyncId('relation-valid-a'),
        isNotNull);
    expect(
        await failingRepo.getTransactionBySyncId('relation-invalid-b'), isNull);
    expect(await failingRepo.getTransactionBySyncId('relation-valid-c'),
        isNotNull);
    expect(await db.select(db.transactionTags).get(), hasLength(2));
    final changes = await db.select(db.localChanges).get();
    expect(changes, hasLength(3));
    expect(
      changes
          .where((change) => change.entityType == 'transaction')
          .map((change) => change.entitySyncId)
          .toSet(),
      {'relation-valid-a', 'relation-valid-c'},
    );
  });

  test('alternate diff:selected account 创建失败不得提交无账户 transaction', () async {
    final tracker = _CountingChangeTracker(db);
    final failingRepo = _ThrowAccountCreateRepository(
      db,
      changeTracker: tracker,
    );
    final cloud = ImportTransaction(
      type: 'expense',
      amount: 987654.321,
      happenedAt: DateTime.utc(2026, 8, 19, 11),
      syncId: 'tx-account-dependency-failure',
      accountName: 'CANARY_ACCOUNT_DO_NOT_LOG_7F4C',
      note: 'CANARY_NOTE_DO_NOT_LOG_7F4C',
    );
    final preview = await syncDiffService.computeDiff(
      repo: failingRepo,
      ledgerId: 1,
      cloudTransactions: [cloud],
    );

    final result = await syncDiffService.applySyncChanges(
      repo: failingRepo,
      ledgerId: 1,
      selectedChanges: preview!.changes,
      importData: ImportData(
        transactions: [cloud],
        accounts: const [
          ImportAccount(name: 'CANARY_ACCOUNT_DO_NOT_LOG_7F4C'),
        ],
      ),
    );

    expect(result.addedCount, 0);
    expect(tracker.recordedCount, greaterThan(0));
    expect(await failingRepo.getTransactionBySyncId(cloud.syncId!), isNull);
    expect(await db.select(db.accounts).get(), isEmpty);
    expect(await db.select(db.localChanges).get(), isEmpty);
    expect(await db.select(db.transactionTags).get(), isEmpty);
    expect(await db.select(db.transactionAttachments).get(), isEmpty);
  });

  test('alternate diff:category/tag/transfer 显式依赖缺 payload 全部 fail closed',
      () async {
    final cases = <ImportTransaction>[
      ImportTransaction(
        type: 'expense',
        amount: 10,
        happenedAt: DateTime.utc(2026, 8, 19, 12),
        syncId: 'tx-missing-category',
        categoryName: 'MissingCategory',
        categoryKind: 'expense',
      ),
      ImportTransaction(
        type: 'expense',
        amount: 10,
        happenedAt: DateTime.utc(2026, 8, 19, 13),
        syncId: 'tx-missing-tag',
        tagNames: const ['MissingTag'],
      ),
      ImportTransaction(
        type: 'transfer',
        amount: 10,
        happenedAt: DateTime.utc(2026, 8, 19, 14),
        syncId: 'tx-missing-transfer-accounts',
        fromAccountName: 'MissingFrom',
        toAccountName: 'MissingTo',
      ),
    ];

    for (final cloud in cases) {
      final preview = await syncDiffService.computeDiff(
        repo: repo,
        ledgerId: 1,
        cloudTransactions: [cloud],
      );
      final result = await syncDiffService.applySyncChanges(
        repo: repo,
        ledgerId: 1,
        selectedChanges: preview!.changes,
        importData: ImportData(transactions: [cloud]),
      );
      expect(result.addedCount, 0, reason: cloud.syncId);
      expect(await repo.getTransactionBySyncId(cloud.syncId!), isNull,
          reason: cloud.syncId);
    }
  });

  test('alternate diff:child category 创建失败会回滚已创建 parent', () async {
    final tracker = _CountingChangeTracker(db);
    final failingRepo = _ThrowNamedDependencyRepository(
      db,
      changeTracker: tracker,
      failCategoryName: 'ChildFailure',
    );
    final cloud = ImportTransaction(
      type: 'expense',
      amount: 10,
      happenedAt: DateTime.utc(2026, 8, 19, 15),
      syncId: 'tx-child-category-failure',
      categoryName: 'ChildFailure',
      categoryKind: 'expense',
    );
    final preview = await syncDiffService.computeDiff(
      repo: failingRepo,
      ledgerId: 1,
      cloudTransactions: [cloud],
    );

    final result = await syncDiffService.applySyncChanges(
      repo: failingRepo,
      ledgerId: 1,
      selectedChanges: preview!.changes,
      importData: ImportData(
        transactions: [cloud],
        categories: const [
          ImportCategory(name: 'ParentCreatedFirst', kind: 'expense'),
          ImportCategory(
            name: 'ChildFailure',
            kind: 'expense',
            level: 2,
            parentName: 'ParentCreatedFirst',
          ),
        ],
      ),
    );

    expect(result.addedCount, 0);
    expect(tracker.recordedCount, greaterThan(0));
    expect(await db.select(db.categories).get(), isEmpty);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.localChanges).get(), isEmpty);
  });

  test('alternate diff:transfer target account 创建失败会回滚 source account',
      () async {
    final tracker = _CountingChangeTracker(db);
    final failingRepo = _ThrowNamedDependencyRepository(
      db,
      changeTracker: tracker,
      failAccountName: 'ToFailure',
    );
    final cloud = ImportTransaction(
      type: 'transfer',
      amount: 10,
      happenedAt: DateTime.utc(2026, 8, 19, 16),
      syncId: 'tx-transfer-account-failure',
      fromAccountName: 'FromCreatedFirst',
      toAccountName: 'ToFailure',
    );
    final preview = await syncDiffService.computeDiff(
      repo: failingRepo,
      ledgerId: 1,
      cloudTransactions: [cloud],
    );

    final result = await syncDiffService.applySyncChanges(
      repo: failingRepo,
      ledgerId: 1,
      selectedChanges: preview!.changes,
      importData: ImportData(
        transactions: [cloud],
        accounts: const [
          ImportAccount(name: 'FromCreatedFirst'),
          ImportAccount(name: 'ToFailure'),
        ],
      ),
    );

    expect(result.addedCount, 0);
    expect(tracker.recordedCount, greaterThan(0));
    expect(await db.select(db.accounts).get(), isEmpty);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.localChanges).get(), isEmpty);
  });

  test('alternate diff:tag 创建失败不会提交 transaction 或 metadata', () async {
    final tracker = _CountingChangeTracker(db);
    final failingRepo = _ThrowNamedDependencyRepository(
      db,
      changeTracker: tracker,
      failTagName: 'TagFailure',
    );
    final cloud = ImportTransaction(
      type: 'expense',
      amount: 10,
      happenedAt: DateTime.utc(2026, 8, 19, 17),
      syncId: 'tx-tag-create-failure',
      tagNames: const ['TagFailure'],
    );
    final preview = await syncDiffService.computeDiff(
      repo: failingRepo,
      ledgerId: 1,
      cloudTransactions: [cloud],
    );

    final result = await syncDiffService.applySyncChanges(
      repo: failingRepo,
      ledgerId: 1,
      selectedChanges: preview!.changes,
      importData: ImportData(
        transactions: [cloud],
        tags: const [ImportTag(name: 'TagFailure')],
      ),
    );

    expect(result.addedCount, 0);
    expect(tracker.recordedCount, greaterThan(0));
    expect(await db.select(db.tags).get(), isEmpty);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.localChanges).get(), isEmpty);
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

class _CountingLocalRepository extends LocalRepository {
  _CountingLocalRepository(super.db, {super.changeTracker});

  int getBudgetBySyncIdCalls = 0;
  int getProjectBudgetBySyncIdCalls = 0;

  @override
  Future<Budget?> getBudgetBySyncId(String syncId) {
    getBudgetBySyncIdCalls++;
    return super.getBudgetBySyncId(syncId);
  }

  @override
  Future<Budget?> getProjectBudgetBySyncId(String syncId) {
    getProjectBudgetBySyncIdCalls++;
    return super.getProjectBudgetBySyncId(syncId);
  }
}

class _ThrowAfterRelationBatchRepository extends LocalRepository {
  _ThrowAfterRelationBatchRepository(
    super.db, {
    required this.failingSyncId,
    super.changeTracker,
  });

  final String failingSyncId;

  @override
  Future<List<int>> insertTransactionsBatchWithRelations({
    required List<TransactionsCompanion> transactions,
    Map<int, List<int>> tagIdsByIndex = const {},
    Map<int, List<BatchAttachmentData>> attachmentsByIndex = const {},
    bool recordChanges = true,
  }) async {
    final ids = await super.insertTransactionsBatchWithRelations(
      transactions: transactions,
      tagIdsByIndex: tagIdsByIndex,
      attachmentsByIndex: attachmentsByIndex,
      recordChanges: recordChanges,
    );
    if (transactions
        .any((tx) => tx.syncId.present && tx.syncId.value == failingSyncId)) {
      throw StateError('forced post-relation batch failure');
    }
    return ids;
  }
}

class _CountingChangeTracker extends ChangeTracker {
  _CountingChangeTracker(super.db);

  int recordedCount = 0;

  @override
  Future<void> recordUserGlobalChange({
    required String entityType,
    required int entityId,
    required String entitySyncId,
    required String action,
    String? payloadJson,
  }) async {
    recordedCount++;
    await super.recordUserGlobalChange(
      entityType: entityType,
      entityId: entityId,
      entitySyncId: entitySyncId,
      action: action,
      payloadJson: payloadJson,
    );
  }

  @override
  Future<void> recordLedgerChange({
    required String entityType,
    required int entityId,
    required String entitySyncId,
    required int ledgerId,
    required String action,
    String? payloadJson,
  }) async {
    recordedCount++;
    await super.recordLedgerChange(
      entityType: entityType,
      entityId: entityId,
      entitySyncId: entitySyncId,
      ledgerId: ledgerId,
      action: action,
      payloadJson: payloadJson,
    );
  }
}

class _ThrowNamedDependencyRepository extends LocalRepository {
  _ThrowNamedDependencyRepository(
    super.db, {
    super.changeTracker,
    this.failAccountName,
    this.failCategoryName,
    this.failTagName,
  });

  final String? failAccountName;
  final String? failCategoryName;
  final String? failTagName;

  @override
  Future<int> createAccount({
    required int ledgerId,
    required String name,
    String type = 'cash',
    String currency = 'CNY',
    double initialBalance = 0.0,
    double? creditLimit,
    int? billingDay,
    int? paymentDueDay,
    String? bankName,
    String? cardLastFour,
    String? note,
    String? syncId,
  }) {
    if (name == failAccountName) {
      throw StateError('forced named account dependency failure');
    }
    return super.createAccount(
      ledgerId: ledgerId,
      name: name,
      type: type,
      currency: currency,
      initialBalance: initialBalance,
      creditLimit: creditLimit,
      billingDay: billingDay,
      paymentDueDay: paymentDueDay,
      bankName: bankName,
      cardLastFour: cardLastFour,
      note: note,
      syncId: syncId,
    );
  }

  @override
  Future<int> createCategory({
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
    int level = 1,
    int? parentId,
    String? syncId,
  }) {
    if (name == failCategoryName) {
      throw StateError('forced named category dependency failure');
    }
    return super.createCategory(
      name: name,
      kind: kind,
      icon: icon,
      sortOrder: sortOrder,
      level: level,
      parentId: parentId,
      syncId: syncId,
    );
  }

  @override
  Future<int> createSubCategory({
    required int parentId,
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
    String? syncId,
  }) {
    if (name == failCategoryName) {
      throw StateError('forced named subcategory dependency failure');
    }
    return super.createSubCategory(
      parentId: parentId,
      name: name,
      kind: kind,
      icon: icon,
      sortOrder: sortOrder,
      syncId: syncId,
    );
  }

  @override
  Future<int> createTag({
    required String name,
    String? color,
    int sortOrder = 0,
    String? syncId,
  }) async {
    final id = await super.createTag(
      name: name,
      color: color,
      sortOrder: sortOrder,
      syncId: syncId,
    );
    if (name == failTagName) {
      throw StateError('forced named tag dependency failure after create');
    }
    return id;
  }
}

class _ThrowAccountCreateRepository extends LocalRepository {
  _ThrowAccountCreateRepository(super.db, {super.changeTracker});

  @override
  Future<int> createAccount({
    required int ledgerId,
    required String name,
    String type = 'cash',
    String currency = 'CNY',
    double initialBalance = 0.0,
    double? creditLimit,
    int? billingDay,
    int? paymentDueDay,
    String? bankName,
    String? cardLastFour,
    String? note,
    String? syncId,
  }) async {
    await super.createAccount(
      ledgerId: ledgerId,
      name: name,
      type: type,
      currency: currency,
      initialBalance: initialBalance,
      creditLimit: creditLimit,
      billingDay: billingDay,
      paymentDueDay: paymentDueDay,
      bankName: bankName,
      cardLastFour: cardLastFour,
      note: note,
      syncId: syncId,
    );
    throw StateError('forced account dependency failure after create');
  }
}
