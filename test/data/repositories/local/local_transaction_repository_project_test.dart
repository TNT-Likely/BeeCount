import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/data/repositories/local/local_transaction_repository.dart';
import 'package:beecount/data/repositories/transaction_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late LocalTransactionRepository txRepo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    txRepo = LocalTransactionRepository(db);
  });

  tearDown(() => db.close());

  Future<String> createProject(int ledgerId) async {
    final id = await repo.createBudget(
      ledgerId: ledgerId,
      type: 'project',
      amount: 100,
      name: 'Project',
      startAt: DateTime.utc(2026, 1, 1),
      endAt: DateTime.utc(2026, 2, 1),
    );
    final row = await (db.select(db.budgets)..where((b) => b.id.equals(id)))
        .getSingle();
    return row.syncId!;
  }

  Future<int> insertHistoricalInvalidTransaction({
    required int ledgerId,
    required String syncId,
  }) async {
    // 模拟 v34 insert guard 安装前已存在的 orphan；每个测试使用独立内存 DB。
    await db.customStatement(
      'DROP TRIGGER IF EXISTS trg_transactions_project_link_insert',
    );
    return db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 10,
            happenedAt: Value(DateTime.utc(2026, 1, 1)),
            syncId: Value(syncId),
            projectBudgetSyncId: const Value('missing-project'),
          ),
        );
  }

  test('direct addTransaction 拒绝不存在的 project link', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');

    await expectLater(
      txRepo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 10,
        happenedAt: DateTime.utc(2026, 1, 1),
        projectBudgetSyncId: 'missing-project',
      ),
      throwsStateError,
    );

    expect(await repo.getTransactionsByLedger(ledgerId), isEmpty);
  });

  test('direct addTransaction 拒绝 income 关联 project', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    final projectSyncId = await createProject(ledgerId);

    await expectLater(
      txRepo.addTransaction(
        ledgerId: ledgerId,
        type: 'income',
        amount: 10,
        happenedAt: DateTime.utc(2026, 1, 1),
        projectBudgetSyncId: projectSyncId,
      ),
      throwsStateError,
    );

    expect(await repo.getTransactionsByLedger(ledgerId), isEmpty);
  });

  test('direct updateTransaction 拒绝不存在的 project link', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    final txId = await txRepo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime.utc(2026, 1, 1),
    );

    await expectLater(
      txRepo.updateTransaction(
        id: txId,
        type: 'expense',
        amount: 10,
        projectBudgetSyncId: const Value<String?>('missing-project'),
      ),
      throwsStateError,
    );

    final tx = await repo.getTransactionById(txId);
    expect(tx!.projectBudgetSyncId, isNull);
  });

  test('direct updateTransaction 拒绝保留 project link 时改成非 expense', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    final projectSyncId = await createProject(ledgerId);
    final txId = await txRepo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime.utc(2026, 1, 1),
      projectBudgetSyncId: projectSyncId,
    );

    await expectLater(
      txRepo.updateTransaction(
        id: txId,
        type: 'income',
        amount: 10,
      ),
      throwsStateError,
    );

    final tx = await repo.getTransactionById(txId);
    expect(tx!.type, 'expense');
    expect(tx.projectBudgetSyncId, projectSyncId);
  });

  test('direct updateTransaction 可在同次显式清 link 后改成 income', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    final projectSyncId = await createProject(ledgerId);
    final txId = await txRepo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime.utc(2026, 1, 1),
      projectBudgetSyncId: projectSyncId,
    );

    await txRepo.updateTransaction(
      id: txId,
      type: 'income',
      amount: 10,
      projectBudgetSyncId: const Value<String?>(null),
    );

    final tx = await repo.getTransactionById(txId);
    expect(tx!.type, 'income');
    expect(tx.projectBudgetSyncId, isNull);
  });

  test('direct updateTransaction 拒绝未知 project link 类型', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    final txId = await txRepo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime.utc(2026, 1, 1),
    );

    await expectLater(
      txRepo.updateTransaction(
        id: txId,
        type: 'expense',
        amount: 20,
        projectBudgetSyncId: 42,
      ),
      throwsArgumentError,
    );

    final tx = await repo.getTransactionById(txId);
    expect(tx!.amount, 10);
    expect(tx.projectBudgetSyncId, isNull);
  });

  test('insertTransactionsBatch 拒绝不存在的 project', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    final item = TransactionsCompanion.insert(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      happenedAt: Value(DateTime.utc(2026, 1, 1)),
      projectBudgetSyncId: const Value('missing-project'),
    );

    await expectLater(txRepo.insertTransactionsBatch([item]), throwsStateError);
    expect(await repo.getTransactionsByLedger(ledgerId), isEmpty);
  });

  test('insertTransactionsBatchWithRelations 拒绝跨账本 project', () async {
    final ledgerA = await repo.createLedger(name: 'ledger-a');
    final ledgerB = await repo.createLedger(name: 'ledger-b');
    final projectSyncId = await createProject(ledgerA);
    final item = TransactionsCompanion.insert(
      ledgerId: ledgerB,
      type: 'expense',
      amount: 10,
      happenedAt: Value(DateTime.utc(2026, 1, 1)),
      projectBudgetSyncId: Value(projectSyncId),
    );

    await expectLater(
      txRepo.insertTransactionsBatchWithRelations(transactions: [item]),
      throwsStateError,
    );
    expect(await repo.getTransactionsByLedger(ledgerB), isEmpty);
  });

  test('insertTransactionCompanion 接受同账本 expense project link', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    final projectSyncId = await createProject(ledgerId);
    final txId = await txRepo.insertTransactionCompanion(
      TransactionsCompanion.insert(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 10,
        happenedAt: Value(DateTime.utc(2026, 1, 1)),
        projectBudgetSyncId: Value(projectSyncId),
      ),
    );

    final tx = await repo.getTransactionById(txId);
    expect(tx!.type, 'expense');
    expect(tx.projectBudgetSyncId, projectSyncId);
  });

  test('insertTransactionsBatch 拒绝 income 关联 project', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    final projectSyncId = await createProject(ledgerId);
    final item = TransactionsCompanion.insert(
      ledgerId: ledgerId,
      type: 'income',
      amount: 10,
      happenedAt: Value(DateTime.utc(2026, 1, 1)),
      projectBudgetSyncId: Value(projectSyncId),
    );

    await expectLater(txRepo.insertTransactionsBatch([item]), throwsStateError);
    expect(await repo.getTransactionsByLedger(ledgerId), isEmpty);
  });

  test('insertTransactionsBatchWithRelations 拒绝 income 关联 project', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    final projectSyncId = await createProject(ledgerId);
    final item = TransactionsCompanion.insert(
      ledgerId: ledgerId,
      type: 'income',
      amount: 10,
      happenedAt: Value(DateTime.utc(2026, 1, 1)),
      projectBudgetSyncId: Value(projectSyncId),
    );

    await expectLater(
      txRepo.insertTransactionsBatchWithRelations(transactions: [item]),
      throwsStateError,
    );
    expect(await repo.getTransactionsByLedger(ledgerId), isEmpty);
  });

  test('insertTransactionCompanion 拒绝 income 关联 project', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    final projectSyncId = await createProject(ledgerId);

    await expectLater(
      txRepo.insertTransactionCompanion(
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'income',
          amount: 10,
          happenedAt: Value(DateTime.utc(2026, 1, 1)),
          projectBudgetSyncId: Value(projectSyncId),
        ),
      ),
      throwsStateError,
    );

    expect(await repo.getTransactionsByLedger(ledgerId), isEmpty);
  });

  test('updateTransactionBySyncId 拒绝 linked expense 改成非 expense', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    final projectSyncId = await createProject(ledgerId);
    final txId = await txRepo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime.utc(2026, 1, 1),
      syncId: 'tx-linked',
      projectBudgetSyncId: projectSyncId,
    );

    await expectLater(
      txRepo.updateTransactionBySyncId(
        syncId: 'tx-linked',
        type: 'income',
        amount: 10,
        happenedAt: DateTime.utc(2026, 1, 2),
      ),
      throwsStateError,
    );

    final tx = await repo.getTransactionById(txId);
    expect(tx!.type, 'expense');
    expect(tx.projectBudgetSyncId, projectSyncId);
  });

  test('updateTransactionsBatchBySyncId 拒绝 absent link 时改成非 expense', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    final projectSyncId = await createProject(ledgerId);
    final txId = await txRepo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime.utc(2026, 1, 1),
      syncId: 'tx-linked-batch',
      projectBudgetSyncId: projectSyncId,
    );

    await expectLater(
      txRepo.updateTransactionsBatchBySyncId([
        TransactionUpdateBySyncIdData(
          syncId: 'tx-linked-batch',
          type: 'income',
          amount: 10,
          happenedAt: DateTime.utc(2026, 1, 2),
        ),
      ]),
      throwsStateError,
    );

    final tx = await repo.getTransactionById(txId);
    expect(tx!.type, 'expense');
    expect(tx.projectBudgetSyncId, projectSyncId);
  });

  test('updateTransactionsBatchBySyncId 拒绝显式 Value.absent 时改成非 expense',
      () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    final projectSyncId = await createProject(ledgerId);
    final txId = await txRepo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime.utc(2026, 1, 1),
      syncId: 'tx-linked-batch-value-absent',
      projectBudgetSyncId: projectSyncId,
    );

    await expectLater(
      txRepo.updateTransactionsBatchBySyncId([
        TransactionUpdateBySyncIdData(
          syncId: 'tx-linked-batch-value-absent',
          type: 'income',
          amount: 10,
          happenedAt: DateTime.utc(2026, 1, 2),
          projectBudgetSyncId: const Value<String?>.absent(),
        ),
      ]),
      throwsStateError,
    );

    final tx = await repo.getTransactionById(txId);
    expect(tx!.type, 'expense');
    expect(tx.projectBudgetSyncId, projectSyncId);
  });

  test('updateTransactionsBatchBySyncId 可显式清 link 后改成 income', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    final projectSyncId = await createProject(ledgerId);
    final txId = await txRepo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime.utc(2026, 1, 1),
      syncId: 'tx-linked-batch-clear',
      projectBudgetSyncId: projectSyncId,
    );

    await txRepo.updateTransactionsBatchBySyncId([
      TransactionUpdateBySyncIdData(
        syncId: 'tx-linked-batch-clear',
        type: 'income',
        amount: 10,
        happenedAt: DateTime.utc(2026, 1, 2),
        projectBudgetSyncId: const Value<String?>(null),
      ),
    ]);

    final tx = await repo.getTransactionById(txId);
    expect(tx!.type, 'income');
    expect(tx.projectBudgetSyncId, isNull);
  });

  test('updateTransactionsBatchBySyncId 拒绝未知 project link 类型', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    await txRepo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime.utc(2026, 1, 1),
      syncId: 'tx-invalid-link-type',
    );

    await expectLater(
      txRepo.updateTransactionsBatchBySyncId([
        TransactionUpdateBySyncIdData(
          syncId: 'tx-invalid-link-type',
          type: 'expense',
          amount: 20,
          happenedAt: DateTime.utc(2026, 1, 2),
          projectBudgetSyncId: 42,
        ),
      ]),
      throwsArgumentError,
    );

    final tx = await txRepo.getTransactionBySyncId('tx-invalid-link-type');
    expect(tx!.amount, 10);
    expect(tx.projectBudgetSyncId, isNull);
  });

  test('updateTransactionLedger 拒绝移动仍关联 project 的交易到其他账本', () async {
    final ledgerA = await repo.createLedger(name: 'ledger-a');
    final ledgerB = await repo.createLedger(name: 'ledger-b');
    final projectSyncId = await createProject(ledgerA);
    final txId = await txRepo.addTransaction(
      ledgerId: ledgerA,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime.utc(2026, 1, 1),
      projectBudgetSyncId: projectSyncId,
    );

    await expectLater(
      txRepo.updateTransactionLedger(id: txId, ledgerId: ledgerB),
      throwsStateError,
    );

    final tx = await repo.getTransactionById(txId);
    expect(tx!.ledgerId, ledgerA);
    expect(tx.projectBudgetSyncId, projectSyncId);
  });

  test('direct updateTransaction absent 时拒绝保留历史 orphan link', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    final txId = await insertHistoricalInvalidTransaction(
      ledgerId: ledgerId,
      syncId: 'tx-orphan-direct',
    );

    await expectLater(
      txRepo.updateTransaction(id: txId, type: 'expense', amount: 20),
      throwsStateError,
    );

    expect((await repo.getTransactionById(txId))!.amount, 10);
  });

  test('updateTransactionBySyncId absent 时拒绝保留历史 orphan link', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    await insertHistoricalInvalidTransaction(
      ledgerId: ledgerId,
      syncId: 'tx-orphan-sync-id',
    );

    await expectLater(
      txRepo.updateTransactionBySyncId(
        syncId: 'tx-orphan-sync-id',
        type: 'expense',
        amount: 20,
        happenedAt: DateTime.utc(2026, 1, 2),
      ),
      throwsStateError,
    );

    expect(
        (await txRepo.getTransactionBySyncId('tx-orphan-sync-id'))!.amount, 10);
  });

  test('updateTransactionsBatchBySyncId absent 时拒绝保留历史 orphan link', () async {
    final ledgerId = await repo.createLedger(name: 'ledger-a');
    await insertHistoricalInvalidTransaction(
      ledgerId: ledgerId,
      syncId: 'tx-orphan-batch',
    );

    await expectLater(
      txRepo.updateTransactionsBatchBySyncId([
        TransactionUpdateBySyncIdData(
          syncId: 'tx-orphan-batch',
          type: 'expense',
          amount: 20,
          happenedAt: DateTime.utc(2026, 1, 2),
        ),
      ]),
      throwsStateError,
    );

    expect(
        (await txRepo.getTransactionBySyncId('tx-orphan-batch'))!.amount, 10);
  });
}
