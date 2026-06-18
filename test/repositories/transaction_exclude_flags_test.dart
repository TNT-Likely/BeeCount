import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';

void main() {
  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  Future<int> seedLedger() {
    return db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: '测试账本',
          monthStartDay: const Value(1),
        ));
  }

  test('addTransaction 写入 excludeFromStats / excludeFromBudget', () async {
    final lid = await seedLedger();
    final id = await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 100,
      happenedAt: DateTime(2026, 6, 18),
      excludeFromStats: true,
      excludeFromBudget: false,
    );

    final tx = await repo.getTransactionById(id);
    expect(tx, isNotNull);
    expect(tx!.excludeFromStats, true);
    expect(tx.excludeFromBudget, false);
  });

  test('updateTransaction 仅传 excludeFromBudget 不会清空 excludeFromStats',
      () async {
    final lid = await seedLedger();
    final id = await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 100,
      happenedAt: DateTime(2026, 6, 18),
      excludeFromStats: true,
      excludeFromBudget: false,
    );

    await repo.updateTransaction(
      id: id,
      type: 'expense',
      amount: 100,
      excludeFromBudget: true,
    );

    final tx = await repo.getTransactionById(id);
    expect(tx, isNotNull);
    // excludeFromStats 未传 (null) → 应保持原值 true,不被清空
    expect(tx!.excludeFromStats, true);
    expect(tx.excludeFromBudget, true);
  });
}
