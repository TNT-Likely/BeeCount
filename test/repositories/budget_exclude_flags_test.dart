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

  /// D2:预算用量只看 excludeFromBudget。
  /// excludeFromBudget=true 的交易不计入预算用量;
  /// excludeFromStats=true / excludeFromBudget=false 的交易仍计入预算用量。
  test('getBudgetUsage 只按 excludeFromBudget 过滤 (D2)', () async {
    final lid = await seedLedger();

    // 设置总预算
    final budgetId = await repo.createBudget(
      ledgerId: lid,
      type: 'total',
      amount: 1000,
    );

    // (a) 正常支出 100 —— 计入
    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 100,
      happenedAt: DateTime(2026, 6, 18),
      excludeFromStats: false,
      excludeFromBudget: false,
    );
    // (b) 不计入预算的支出 500 —— 排除
    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 500,
      happenedAt: DateTime(2026, 6, 18),
      excludeFromStats: false,
      excludeFromBudget: true,
    );
    // (c) 不计入收支但计入预算的支出 30 —— 仍计入预算
    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 30,
      happenedAt: DateTime(2026, 6, 18),
      excludeFromStats: true,
      excludeFromBudget: false,
    );

    final usage = await repo.getBudgetUsage(budgetId, DateTime(2026, 6, 18));

    // used = 100 + 30 = 130:(b) 被排除,(c) 仍计入
    expect(usage.used, 130.0);
  });
}
