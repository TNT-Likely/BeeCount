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

  /// 收支统计:excludeFromStats=true 的交易应被排除;余额口径不动。
  test('totalsInRange 排除 excludeFromStats=true 的交易', () async {
    final lid = await seedLedger();
    // 正常支出 100
    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 100,
      happenedAt: DateTime(2026, 6, 18),
      excludeFromStats: false,
      excludeFromBudget: false,
    );
    // 不计入收支的支出 500
    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 500,
      happenedAt: DateTime(2026, 6, 18),
      excludeFromStats: true,
      excludeFromBudget: false,
    );

    final (income, expense) = await repo.totalsInRange(
      ledgerId: lid,
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 7, 1),
    );

    expect(income, 0.0);
    // 只算入正常的 100,排除被标记的 500
    expect(expense, 100.0);
  });

  /// D5 反向断言:被排除的交易仍计入余额/净值口径。
  /// getLedgerStats 的 balance 是余额路径,不应被 excludeFromStats 过滤。
  test('getLedgerStats 余额仍包含 excludeFromStats=true 的交易 (D5)', () async {
    final lid = await seedLedger();
    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 100,
      happenedAt: DateTime(2026, 6, 18),
      excludeFromStats: false,
      excludeFromBudget: false,
    );
    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 500,
      happenedAt: DateTime(2026, 6, 18),
      excludeFromStats: true,
      excludeFromBudget: false,
    );

    final stats = await repo.getLedgerStats(ledgerId: lid);

    // 余额 = -(100 + 500) = -600,被排除的 500 仍计入余额
    expect(stats.balance, -600.0);
    expect(stats.transactionCount, 2);
  });
}
