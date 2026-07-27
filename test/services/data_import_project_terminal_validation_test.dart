// E4-S2 D1/D2: DataImportService.importBudgets terminal-state validation.
//
// D1: invalid project inserts are skipped, valid sibling is applied,
//     applied count is exactly 1, and recordChanges=false produces no
//     local_changes.
// D2: invalid project updates leave the existing row unchanged, applied
//     count is 0, and recordChanges=false produces no local_changes.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late DataImportService importService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    final changeTracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: changeTracker);
    importService = DataImportService();

    await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L',
          currency: const Value('CNY'),
          syncId: const Value('ledger-d'),
        ));
  });

  tearDown(() async => db.close());

  /// A valid ImportBudget for type=project. Does NOT apply defaults for
  /// startAt/endAt — callers that need null must pass it explicitly via
  /// a direct ImportBudget constructor.
  ImportBudget validProjectImport({
    required String syncId,
    double amount = 100,
    String name = 'Valid project',
    DateTime? startAt,
    DateTime? endAt,
    String status = 'active',
  }) =>
      ImportBudget(
        syncId: syncId,
        type: 'project',
        amount: amount,
        name: name,
        startAt: startAt ?? DateTime.utc(2026, 8, 1),
        endAt: endAt ?? DateTime.utc(2026, 10, 1),
        excludeFromMonthlyTotal: true,
        status: status,
      );

  test('importBudgets skips invalid project inserts and applies valid sibling',
      () async {
    // For start-null / end-null, construct directly so null is preserved
    // (the helper would default null to a valid date).
    final invalidBudgets = <ImportBudget>[
      validProjectImport(syncId: 'imp-amount-zero', amount: 0),
      validProjectImport(syncId: 'imp-amount-nan', amount: double.nan),
      validProjectImport(syncId: 'imp-name-ws', name: '   '),
      ImportBudget(
        syncId: 'imp-start-null',
        type: 'project',
        amount: 100,
        name: 'Valid project',
        startAt: null,
        endAt: DateTime.utc(2026, 10, 1),
        excludeFromMonthlyTotal: true,
        status: 'active',
      ),
      ImportBudget(
        syncId: 'imp-end-null',
        type: 'project',
        amount: 100,
        name: 'Valid project',
        startAt: DateTime.utc(2026, 8, 1),
        endAt: null,
        excludeFromMonthlyTotal: true,
        status: 'active',
      ),
      validProjectImport(
        syncId: 'imp-start-gte-end',
        startAt: DateTime.utc(2026, 10, 1),
        endAt: DateTime.utc(2026, 10, 1),
      ),
      validProjectImport(syncId: 'imp-status-paused', status: 'paused'),
    ];

    // Valid sibling last.
    final validSibling = validProjectImport(syncId: 'imp-valid-sibling');

    final applied = await importService.importBudgets(
      repo,
      1,
      [...invalidBudgets, validSibling],
      recordChanges: false,
    );

    // Returned applied count is exactly 1.
    expect(applied, 1);

    // Only valid sibling exists.
    for (final invalid in invalidBudgets) {
      final row = await (db.select(db.budgets)
            ..where((b) => b.syncId.equals(invalid.syncId)))
          .getSingleOrNull();
      expect(row, isNull,
          reason: '${invalid.syncId} should not have been inserted');
    }

    final validRow = await (db.select(db.budgets)
          ..where((b) => b.syncId.equals('imp-valid-sibling')))
        .getSingleOrNull();
    expect(validRow, isNotNull);
    expect(validRow!.type, 'project');
    expect(validRow.name, 'Valid project');
    expect(validRow.amount, 100.0);
    expect(validRow.status, 'active');

    // No local_changes when recordChanges=false.
    final changes = await db.select(db.localChanges).get();
    expect(changes, isEmpty,
        reason: 'recordChanges=false must not produce local_changes');
  });

  test('importBudgets rejects invalid project updates without partial mutation',
      () async {
    // Seed one valid active project with stable sync ID.
    final seededId = await repo.createBudget(
      ledgerId: 1,
      type: 'project',
      amount: 2400,
      name: 'Seeded project',
      startAt: DateTime.utc(2026, 8, 1),
      endAt: DateTime.utc(2026, 10, 1),
      excludeFromMonthlyTotal: true,
      status: 'active',
    );
    await (db.update(db.budgets)..where((b) => b.id.equals(seededId)))
        .write(const BudgetsCompanion(syncId: Value('imp-d2-seed')));

    // Capture the complete Drift row before any import.
    final before = await (db.select(db.budgets)
          ..where((b) => b.syncId.equals('imp-d2-seed')))
        .getSingle();

    // Capture local_changes count before imports (createBudget via
    // LocalRepository may have recorded a change).
    final changesBefore = await db.select(db.localChanges).get();

    final invalidUpdates = <ImportBudget>[
      ImportBudget(
        syncId: 'imp-d2-seed',
        type: 'project',
        amount: 0,
        name: 'Seeded project',
        startAt: DateTime.utc(2026, 8, 1),
        endAt: DateTime.utc(2026, 10, 1),
        excludeFromMonthlyTotal: true,
        status: 'active',
      ),
      ImportBudget(
        syncId: 'imp-d2-seed',
        type: 'project',
        amount: 2400,
        name: '   ',
        startAt: DateTime.utc(2026, 8, 1),
        endAt: DateTime.utc(2026, 10, 1),
        excludeFromMonthlyTotal: true,
        status: 'active',
      ),
      ImportBudget(
        syncId: 'imp-d2-seed',
        type: 'project',
        amount: 2400,
        name: 'Seeded project',
        startAt: DateTime.utc(2026, 10, 1),
        endAt: DateTime.utc(2026, 10, 1),
        excludeFromMonthlyTotal: true,
        status: 'active',
      ),
      ImportBudget(
        syncId: 'imp-d2-seed',
        type: 'project',
        amount: 2400,
        name: 'Seeded project',
        startAt: DateTime.utc(2026, 8, 1),
        endAt: DateTime.utc(2026, 10, 1),
        excludeFromMonthlyTotal: true,
        status: 'paused',
      ),
    ];

    for (final invalid in invalidUpdates) {
      final applied = await importService.importBudgets(
        repo,
        1,
        [invalid],
        recordChanges: false,
      );

      // Returned applied count is 0.
      expect(applied, 0, reason: 'invalid update should not be applied');

      // Complete row remains equal to original.
      final after = await (db.select(db.budgets)
            ..where((b) => b.syncId.equals('imp-d2-seed')))
          .getSingle();
      expect(after, equals(before),
          reason: 'invalid update must not partially mutate the row');

      // recordChanges=false produces no new local change.
      final changesAfter = await db.select(db.localChanges).get();
      expect(changesAfter.length, changesBefore.length,
          reason: 'recordChanges=false must not produce new local_changes');
    }
  });
}
