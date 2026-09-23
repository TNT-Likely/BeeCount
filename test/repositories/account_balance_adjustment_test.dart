import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Future<int> seedLedger() => db.into(db.ledgers).insert(
        LedgersCompanion.insert(
          name: '测试账本',
          monthStartDay: const Value(1),
        ),
      );

  Future<int> seedAccount(int ledgerId) => db.into(db.accounts).insert(
        AccountsCompanion.insert(
          ledgerId: ledgerId,
          name: '现金',
          initialBalance: const Value(100),
          syncId: const Value('acc-balance-adjustment'),
        ),
      );

  test('只修改余额时调整基线，不产生交易', () async {
    final ledgerId = await seedLedger();
    final accountId = await seedAccount(ledgerId);
    await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 20,
      accountId: accountId,
      happenedAt: DateTime(2026, 9, 23),
    );

    final result = await repo.setAccountBalance(
      ledgerId: ledgerId,
      accountId: accountId,
      targetBalance: 95,
      createBalanceAdjustment: false,
    );

    expect(result.difference, 15);
    expect(result.transactionId, isNull);
    expect(await repo.getAccountBalance(accountId), 95);
    expect(await repo.getTransactionCountByAccount(accountId), 1);
  });

  test('生成平账交易时使用固定类型和标签，且不计入收支统计', () async {
    final ledgerId = await seedLedger();
    final accountId = await seedAccount(ledgerId);

    final result = await repo.setAccountBalance(
      ledgerId: ledgerId,
      accountId: accountId,
      targetBalance: 125,
      createBalanceAdjustment: true,
    );

    expect(result.difference, 25);
    expect(result.transactionId, isNotNull);
    final transaction = await repo.getTransactionById(result.transactionId!);
    expect(transaction!.type, 'balance_adjustment');
    expect(transaction.amount, 25);
    expect(transaction.excludeFromStats, isTrue);
    expect(transaction.excludeFromBudget, isTrue);
    expect(await repo.getAccountBalance(accountId), 125);
    expect((await repo.getAccountStats(accountId)).income, 0);
    expect((await repo.getAccountStats(accountId)).expense, 0);

    final tags = await repo.getTagsForTransaction(result.transactionId!);
    expect(tags.map((tag) => tag.name), contains('平账'));
  });

  test('目标余额没有变化时不写入', () async {
    final ledgerId = await seedLedger();
    final accountId = await seedAccount(ledgerId);

    final result = await repo.setAccountBalance(
      ledgerId: ledgerId,
      accountId: accountId,
      targetBalance: 100,
      createBalanceAdjustment: true,
    );

    expect(result.difference, 0);
    expect(result.transactionId, isNull);
    expect(await repo.getTransactionCountByAccount(accountId), 0);
  });
}
