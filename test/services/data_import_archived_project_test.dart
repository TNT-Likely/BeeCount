import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late DataImportService service;

  const syncId = 'archived-project';
  final startAt = DateTime.utc(2026, 1, 1);
  final endAt = DateTime.utc(2026, 12, 31);
  final createdAt = DateTime.utc(2026, 1, 2);
  final updatedAt = DateTime.utc(2026, 1, 3);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    service = DataImportService();
    await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L',
          currency: const Value('CNY'),
        ));
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
          syncId: const Value(syncId),
          ledgerId: 1,
          type: const Value('project'),
          amount: 600,
          period: const Value('once'),
          startDay: const Value(1),
          enabled: const Value(true),
          name: const Value('Archived project'),
          startAt: Value(startAt),
          endAt: Value(endAt),
          excludeFromMonthlyTotal: const Value(true),
          status: const Value('archived'),
          createdAt: Value(createdAt),
          updatedAt: Value(updatedAt),
        ));
  });

  tearDown(() async => db.close());

  ImportBudget payload({
    double amount = 600,
    String status = 'archived',
  }) =>
      ImportBudget(
        syncId: syncId,
        type: 'project',
        amount: amount,
        period: 'once',
        startDay: 1,
        enabled: true,
        name: 'Archived project',
        startAt: startAt,
        endAt: endAt,
        excludeFromMonthlyTotal: true,
        status: status,
      );

  Future<Budget> row() =>
      (db.select(db.budgets)..where((b) => b.syncId.equals(syncId)))
          .getSingle();

  test('archived project with changed business field is rejected unchanged',
      () async {
    final before = await row();

    final applied = await service.importBudgets(
      repo,
      1,
      [payload(amount: 601)],
      recordChanges: false,
    );

    expect(applied, 0);
    expect(await row(), before);
  });

  test('archived project with unchanged fields and active status is allowed',
      () async {
    final archived = await row();
    expect(
      [
        archived.type,
        archived.categoryId,
        archived.amount,
        archived.period,
        archived.startDay,
        archived.enabled,
        archived.name,
        archived.excludeFromMonthlyTotal,
      ],
      [
        'project',
        null,
        600,
        'once',
        1,
        true,
        'Archived project',
        true,
      ],
    );
    expect(archived.startAt!.isAtSameMomentAs(startAt), isTrue);
    expect(archived.endAt!.isAtSameMomentAs(endAt), isTrue);

    final applied = await service.importBudgets(
      repo,
      1,
      [payload(status: 'active')],
      recordChanges: false,
    );

    expect(applied, 1);
    final restored = await row();
    expect(restored.status, 'active');
    expect(restored.amount, 600);
    expect(restored.name, 'Archived project');
  });

  test('identical archived payload replay is an idempotent no-op', () async {
    final before = await row();

    final first = await service.importBudgets(
      repo,
      1,
      [payload()],
      recordChanges: false,
    );
    final second = await service.importBudgets(
      repo,
      1,
      [payload()],
      recordChanges: false,
    );

    expect(first, 1);
    expect(second, 1);
    final matching = await (db.select(db.budgets)
          ..where((b) => b.syncId.equals(syncId)))
        .get();
    expect(matching, hasLength(1));
    expect(matching.single, before);
  });
}
