import 'package:beecount/data/db.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<BeeDatabase> openDb() async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    addTearDown(db.close);
    return db;
  }

  Future<void> seedLedgerAndProject(BeeDatabase db) async {
    await db.into(db.ledgers).insert(LedgersCompanion.insert(name: 'L1'));
    await db.into(db.ledgers).insert(LedgersCompanion.insert(name: 'L2'));
    await db.into(db.budgets).insert(
          BudgetsCompanion.insert(
            ledgerId: 1,
            type: const Value('project'),
            amount: 100,
            name: const Value('P'),
            startAt: Value(DateTime.utc(2026, 8, 1)),
            endAt: Value(DateTime.utc(2026, 9, 1)),
            status: const Value('active'),
            syncId: const Value('project-guard'),
          ),
        );
  }

  TransactionsCompanion linkedTransaction({
    required int ledgerId,
    required String type,
    required String syncId,
    String projectSyncId = 'project-guard',
  }) =>
      TransactionsCompanion.insert(
        ledgerId: ledgerId,
        type: type,
        amount: 10,
        happenedAt: Value(DateTime.utc(2026, 8, 10)),
        syncId: Value(syncId),
        projectBudgetSyncId: Value(projectSyncId),
      );

  test('fresh v32 installs project-link triggers and budget sync index',
      () async {
    final db = await openDb();
    final rows = await db.customSelect('''
      SELECT type, name FROM sqlite_master
      WHERE name IN (
        'idx_budgets_sync_id',
        'trg_transactions_project_link_insert',
        'trg_transactions_project_link_update',
        'trg_project_budget_restrict_delete',
        'trg_project_budget_restrict_identity_update'
      )
    ''').get();
    expect(rows.map((row) => row.read<String>('name')).toSet(), {
      'idx_budgets_sync_id',
      'trg_transactions_project_link_insert',
      'trg_transactions_project_link_update',
      'trg_project_budget_restrict_delete',
      'trg_project_budget_restrict_identity_update',
    });
  });

  test('direct inserts reject missing, cross-ledger and non-expense links',
      () async {
    final db = await openDb();
    await seedLedgerAndProject(db);

    await expectLater(
      db.into(db.transactions).insert(linkedTransaction(
            ledgerId: 1,
            type: 'expense',
            syncId: 'missing-project',
            projectSyncId: 'missing',
          )),
      throwsA(anything),
    );
    await expectLater(
      db.into(db.transactions).insert(linkedTransaction(
            ledgerId: 2,
            type: 'expense',
            syncId: 'cross-ledger',
          )),
      throwsA(anything),
    );
    await expectLater(
      db.into(db.transactions).insert(linkedTransaction(
            ledgerId: 1,
            type: 'income',
            syncId: 'linked-income',
          )),
      throwsA(anything),
    );
  });

  test('direct transaction update cannot invalidate an existing project link',
      () async {
    final db = await openDb();
    await seedLedgerAndProject(db);
    final id = await db.into(db.transactions).insert(linkedTransaction(
          ledgerId: 1,
          type: 'expense',
          syncId: 'linked-update',
        ));

    await expectLater(
      (db.update(db.transactions)..where((row) => row.id.equals(id))).write(
        const TransactionsCompanion(ledgerId: Value(2)),
      ),
      throwsA(anything),
    );
    await expectLater(
      (db.update(db.transactions)..where((row) => row.id.equals(id))).write(
        const TransactionsCompanion(type: Value('income')),
      ),
      throwsA(anything),
    );
  });

  test('referenced project cannot be deleted or have identity rewritten',
      () async {
    final db = await openDb();
    await seedLedgerAndProject(db);
    await db.into(db.transactions).insert(linkedTransaction(
          ledgerId: 1,
          type: 'expense',
          syncId: 'linked-budget-mutation',
        ));
    final project = await (db.select(db.budgets)
          ..where((row) => row.syncId.equals('project-guard')))
        .getSingle();

    await expectLater(
      (db.delete(db.budgets)..where((row) => row.id.equals(project.id))).go(),
      throwsA(anything),
    );
    await expectLater(
      (db.update(db.budgets)..where((row) => row.id.equals(project.id))).write(
        const BudgetsCompanion(syncId: Value('project-renamed')),
      ),
      throwsA(anything),
    );
    await expectLater(
      (db.update(db.budgets)..where((row) => row.id.equals(project.id))).write(
        const BudgetsCompanion(ledgerId: Value(2)),
      ),
      throwsA(anything),
    );
    await expectLater(
      (db.update(db.budgets)..where((row) => row.id.equals(project.id))).write(
        const BudgetsCompanion(type: Value('category')),
      ),
      throwsA(anything),
    );
  });

  test('legal project link and non-identity project update remain allowed',
      () async {
    final db = await openDb();
    await seedLedgerAndProject(db);
    final txId = await db.into(db.transactions).insert(linkedTransaction(
          ledgerId: 1,
          type: 'expense',
          syncId: 'legal-link',
        ));
    final project = await (db.select(db.budgets)
          ..where((row) => row.syncId.equals('project-guard')))
        .getSingle();
    await (db.update(db.budgets)..where((row) => row.id.equals(project.id)))
        .write(const BudgetsCompanion(amount: Value(200)));

    expect((await db.transactions.select().getSingle()).id, txId);
    expect((await db.budgets.select().getSingle()).amount, 200);
  });
}
