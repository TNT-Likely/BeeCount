import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data_import_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late _ThrowingChangeTracker tracker;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    tracker = _ThrowingChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
    await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'L',
            syncId: const Value('ledger-atomic'),
          ),
        );
  });

  tearDown(() async => db.close());

  test('createBudget rolls back the budget when change tracking fails',
      () async {
    await expectLater(
      repo.createBudget(
        ledgerId: 1,
        type: 'project',
        amount: 100,
        name: 'P',
        startAt: DateTime.utc(2026, 1, 1),
        endAt: DateTime.utc(2026, 2, 1),
        status: 'active',
      ),
      throwsA(isA<StateError>()),
    );

    expect(await db.select(db.budgets).get(), isEmpty);
    expect(await db.select(db.localChanges).get(), isEmpty);
  });

  test('updateBudget rolls back the budget when change tracking fails',
      () async {
    final id = await db.into(db.budgets).insert(
          BudgetsCompanion.insert(
            ledgerId: 1,
            type: const Value('project'),
            amount: 100,
            syncId: const Value('budget-update'),
            name: const Value('P'),
            startAt: Value(DateTime.utc(2026, 1, 1)),
            endAt: Value(DateTime.utc(2026, 2, 1)),
            status: const Value('active'),
          ),
        );

    await expectLater(
      repo.updateBudget(id, amount: 200),
      throwsA(isA<StateError>()),
    );

    final row = await (db.select(db.budgets)..where((b) => b.id.equals(id)))
        .getSingle();
    expect(row.amount, 100);
    expect(await db.select(db.localChanges).get(), isEmpty);
  });

  test('deleteBudget restores the budget when change tracking fails', () async {
    final id = await db.into(db.budgets).insert(
          BudgetsCompanion.insert(
            ledgerId: 1,
            type: const Value('project'),
            amount: 100,
            syncId: const Value('budget-delete'),
            name: const Value('P'),
            startAt: Value(DateTime.utc(2026, 1, 1)),
            endAt: Value(DateTime.utc(2026, 2, 1)),
            status: const Value('active'),
          ),
        );

    await expectLater(
      repo.deleteBudget(id),
      throwsA(isA<StateError>()),
    );

    final row = await (db.select(db.budgets)..where((b) => b.id.equals(id)))
        .getSingleOrNull();
    expect(row == null, isFalse);
    expect(row!.syncId, 'budget-delete');
    expect(await db.select(db.localChanges).get(), isEmpty);
  });

  test(
      'updateTransactionLedger rolls back ledger and native amount when tracking fails',
      () async {
    final targetLedgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'Target',
            syncId: const Value('ledger-atomic-target'),
            currency: const Value('CNY'),
          ),
        );
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: 100,
            syncId: const Value('tx-ledger-atomic'),
            currencyCode: const Value('USD'),
            nativeAmount: const Value(700),
          ),
        );

    final assertingTracker = _AssertingLedgerMoveChangeTracker(
      db,
      transactionId: txId,
      expectedLedgerId: targetLedgerId,
      expectedNativeAmount: 100,
    );
    final ledgerRepo = LocalRepository(db, changeTracker: assertingTracker);

    await expectLater(
      ledgerRepo.updateTransactionLedger(id: txId, ledgerId: targetLedgerId),
      throwsA(isA<StateError>()),
    );

    expect(assertingTracker.observedMovedAndRecalculated, isTrue);
    final row = await (db.select(db.transactions)
          ..where((tx) => tx.id.equals(txId)))
        .getSingle();
    expect(row.ledgerId, 1);
    expect(row.nativeAmount, 700);
    expect(await db.select(db.localChanges).get(), isEmpty);
  });

  test('importBudgets rolls back the upsert when change tracking fails',
      () async {
    final applied = await DataImportService().importBudgets(
      repo,
      1,
      [
        ImportBudget(
          syncId: 'budget-import',
          type: 'project',
          amount: 100,
          name: 'P',
          startAt: DateTime.utc(2026, 1, 1),
          endAt: DateTime.utc(2026, 2, 1),
          excludeFromMonthlyTotal: true,
          status: 'active',
        ),
      ],
      recordChanges: true,
    );

    expect(applied, 0);
    expect(await db.select(db.budgets).get(), isEmpty);
    expect(await db.select(db.localChanges).get(), isEmpty);
  });

  test('importBudgets uses the repository tracker when recordChanges is true',
      () async {
    final trackedRepo = LocalRepository(db, changeTracker: ChangeTracker(db));
    final result = await DataImportService().importBudgets(
      trackedRepo,
      1,
      [
        ImportBudget(
          syncId: 'budget-import-tracked',
          type: 'project',
          amount: 25,
          name: 'Tracked',
          startAt: DateTime.utc(2026, 9, 1),
          endAt: DateTime.utc(2026, 10, 1),
          excludeFromMonthlyTotal: true,
          status: 'active',
        ),
      ],
      recordChanges: true,
    );

    expect(result, 1);
    final changes = await db.select(db.localChanges).get();
    expect(changes, hasLength(1));
    expect(changes.single.entityType, 'budget');
    expect(changes.single.entitySyncId, 'budget-import-tracked');
    expect(changes.single.action, 'create');
  });
}

class _ThrowingChangeTracker extends ChangeTracker {
  _ThrowingChangeTracker(super.db);

  @override
  Future<void> recordLedgerChange({
    required String entityType,
    required int entityId,
    required String entitySyncId,
    required int ledgerId,
    required String action,
    String? payloadJson,
  }) {
    throw StateError('forced change tracking failure');
  }
}

class _AssertingLedgerMoveChangeTracker extends ChangeTracker {
  _AssertingLedgerMoveChangeTracker(
    this.database, {
    required this.transactionId,
    required this.expectedLedgerId,
    required this.expectedNativeAmount,
  }) : super(database);

  final BeeDatabase database;
  final int transactionId;
  final int expectedLedgerId;
  final double expectedNativeAmount;
  bool observedMovedAndRecalculated = false;

  @override
  Future<void> recordLedgerChange({
    required String entityType,
    required int entityId,
    required String entitySyncId,
    required int ledgerId,
    required String action,
    String? payloadJson,
  }) async {
    final row = await (database.select(database.transactions)
          ..where((tx) => tx.id.equals(transactionId)))
        .getSingle();
    if (row.ledgerId != expectedLedgerId ||
        row.nativeAmount != expectedNativeAmount) {
      throw StateError(
        'tracker invoked before ledger move/native amount recalculation',
      );
    }
    observedMovedAndRecalculated = true;
    throw StateError('forced change tracking failure after ledger move');
  }
}
