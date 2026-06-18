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

  Future<int> seedAccount(int ledgerId) {
    return db.into(db.accounts).insert(AccountsCompanion.insert(
          ledgerId: ledgerId,
          name: '现金',
          syncId: const Value('acc-1'),
        ));
  }

  /// 账户维度收支统计:excludeFromStats=true 的交易应被排除。
  test('getAccountStats.expense 排除 excludeFromStats=true 的交易', () async {
    final lid = await seedLedger();
    final aid = await seedAccount(lid);

    // 正常支出 100
    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 100,
      accountId: aid,
      happenedAt: DateTime(2026, 6, 18),
      excludeFromStats: false,
      excludeFromBudget: false,
    );
    // 不计入收支的支出 500
    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 500,
      accountId: aid,
      happenedAt: DateTime(2026, 6, 18),
      excludeFromStats: true,
      excludeFromBudget: false,
    );

    final stats = await repo.getAccountStats(aid);

    // 只算入正常的 100,排除被标记的 500
    expect(stats.expense, 100.0);
  });

  /// D5 反向断言:被排除的交易仍计入账户余额口径。
  test('getAccountBalance 余额仍包含 excludeFromStats=true 的交易 (D5)', () async {
    final lid = await seedLedger();
    final aid = await seedAccount(lid);

    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 100,
      accountId: aid,
      happenedAt: DateTime(2026, 6, 18),
      excludeFromStats: false,
      excludeFromBudget: false,
    );
    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 500,
      accountId: aid,
      happenedAt: DateTime(2026, 6, 18),
      excludeFromStats: true,
      excludeFromBudget: false,
    );

    final balance = await repo.getAccountBalance(aid);

    // 余额 = -(100 + 500) = -600,被排除的 500 仍计入余额
    expect(balance, -600.0);
  });
}
