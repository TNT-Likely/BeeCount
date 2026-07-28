import 'package:beecount/cloud/sync_diff_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data_import_service.dart';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final spec in const [
    (siblingCount: 1, maxBudgetSelects: 3, expectedTransactions: 1),
    (siblingCount: 20, maxBudgetSelects: 3, expectedTransactions: 1),
    (siblingCount: 100, maxBudgetSelects: 3, expectedTransactions: 1),
    (siblingCount: 500, maxBudgetSelects: 3, expectedTransactions: 1),
    (siblingCount: 501, maxBudgetSelects: 6, expectedTransactions: 2),
  ]) {
    test(
        '${spec.siblingCount} shared-project selected siblings use bounded budget SELECTs',
        () async {
      final siblingCount = spec.siblingCount;
      SharedPreferences.setMockInitialValues({});
      final counter = _BudgetSelectCounter();
      final db = BeeDatabase.forTesting(
        NativeDatabase.memory().interceptWith(counter),
      );
      addTearDown(db.close);
      final repo = _CountingLocalRepository(db);
      final ledgerId = await repo.createLedger(name: 'L');
      await db.into(db.budgets).insert(
            BudgetsCompanion.insert(
              ledgerId: ledgerId,
              type: const d.Value('project'),
              amount: 100,
              name: const d.Value('P'),
              startAt: d.Value(DateTime.utc(2026, 8, 1)),
              endAt: d.Value(DateTime.utc(2026, 9, 1)),
              status: const d.Value('active'),
              syncId: const d.Value('shared-project'),
            ),
          );
      final clouds = [
        for (var i = 0; i < siblingCount; i++)
          ImportTransaction(
            type: 'expense',
            amount: i + 1,
            happenedAt: DateTime.utc(2026, 8, 10),
            syncId: 'tx-$i',
            projectBudgetSyncIdPresent: true,
            projectBudgetSyncId: 'shared-project',
          ),
      ];
      final preview = await syncDiffService.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: clouds,
      );
      counter.count = 0;

      final result = await syncDiffService.applySyncChanges(
        repo: repo,
        ledgerId: ledgerId,
        selectedChanges: preview!.changes,
        importData: ImportData(transactions: clouds),
      );

      expect(result.addedCount, siblingCount);
      expect(repo.runInTransactionCalls, spec.expectedTransactions);
      expect(
        counter.count,
        lessThanOrEqualTo(spec.maxBudgetSelects),
        reason:
            'physical budget SELECTs must scale with chunks/unique projects, not siblings',
      );
    });
  }
}

class _CountingLocalRepository extends LocalRepository {
  _CountingLocalRepository(super.db);

  int runInTransactionCalls = 0;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) {
    runInTransactionCalls++;
    return super.runInTransaction(action);
  }
}

class _BudgetSelectCounter extends d.QueryInterceptor {
  int count = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    d.QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('FROM "budgets"')) count++;
    return executor.runSelect(statement, args);
  }
}
