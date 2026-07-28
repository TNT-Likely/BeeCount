// v31 EntitySerializer 行为(冻结合同要求):
// - transaction 始终发送 `projectBudgetSyncId`(null 也发,让 apply 端能区分
//   omission vs clear);
// - budget type='project' 携带 5 个额外键,其他类型不带。
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;

import 'package:beecount/data/db.dart';
import 'package:beecount/cloud/sync/entity_serializer.dart';

void main() {
  late BeeDatabase db;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async => db.close());

  test('serializeTransaction 始终携带 projectBudgetSyncId(null 也发)', () async {
    final id = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: 12.0,
            happenedAt: Value(DateTime.utc(2026, 8, 15)),
            syncId: const Value('tx-1'),
          ),
        );
    final tx = await (db.select(db.transactions)..where((t) => t.id.equals(id)))
        .getSingle();
    final payload = EntitySerializer.serializeTransaction(tx);
    expect(payload.containsKey('projectBudgetSyncId'), isTrue);
    expect(payload['projectBudgetSyncId'], isNull);
  });

  test('serializeTransaction:关联时把 syncId 落到 payload', () async {
    await db.into(db.budgets).insert(
          BudgetsCompanion.insert(
            ledgerId: 1,
            type: const Value('project'),
            amount: 100,
            syncId: const Value('proj-1'),
          ),
        );
    final id = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: 30.0,
            happenedAt: Value(DateTime.utc(2026, 8, 15)),
            syncId: const Value('tx-2'),
            projectBudgetSyncId: const Value('proj-1'),
          ),
        );
    final tx = await (db.select(db.transactions)..where((t) => t.id.equals(id)))
        .getSingle();
    final payload = EntitySerializer.serializeTransaction(tx);
    expect(payload['projectBudgetSyncId'], 'proj-1');
  });

  test('serializeBudget(project):5 个新键都在,日期是 UTC RFC 3339', () async {
    final id = await db.into(db.budgets).insert(BudgetsCompanion.insert(
          ledgerId: 1,
          type: const Value('project'),
          amount: 2400.0,
          syncId: const Value('proj-1'),
          name: const Value('Studio refresh'),
          startAt: Value(DateTime.utc(2026, 8, 1)),
          endAt: Value(DateTime.utc(2026, 10, 1)),
          excludeFromMonthlyTotal: const Value(true),
          status: const Value('active'),
        ));
    final b = await (db.select(db.budgets)..where((r) => r.id.equals(id)))
        .getSingle();
    final payload = EntitySerializer.serializeBudget(
      b,
      ledgerSyncId: 'ledger-1',
    );
    expect(payload['type'], 'project');
    expect(payload['name'], 'Studio refresh');
    expect(payload['startAt'], '2026-08-01T00:00:00.000Z');
    expect(payload['endAt'], '2026-10-01T00:00:00.000Z');
    expect(payload['excludeFromMonthlyTotal'], isTrue);
    expect(payload['status'], 'active');
  });

  test('serializeBudget(total):不携带 project 专有键', () async {
    final id = await db.into(db.budgets).insert(BudgetsCompanion.insert(
          ledgerId: 1,
          type: const Value('total'),
          amount: 5000.0,
          syncId: const Value('total-1'),
        ));
    final b = await (db.select(db.budgets)..where((r) => r.id.equals(id)))
        .getSingle();
    final payload = EntitySerializer.serializeBudget(b);
    expect(payload.containsKey('name'), isFalse);
    expect(payload.containsKey('startAt'), isFalse);
    expect(payload.containsKey('endAt'), isFalse);
    expect(payload.containsKey('excludeFromMonthlyTotal'), isFalse);
    expect(payload.containsKey('status'), isFalse);
  });
}
