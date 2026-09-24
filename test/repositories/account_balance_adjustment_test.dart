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

  test('生成平账交易时使用普通收支类型和固定分类', () async {
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
    expect(transaction!.type, 'income');
    expect(transaction.amount, 25);
    expect(transaction.categoryId, isNotNull);
    final category = await repo.getCategoryById(transaction.categoryId!);
    expect(category!.name, '平账');
    expect(category.kind, 'income');
    expect(transaction.excludeFromStats, isFalse);
    expect(transaction.excludeFromBudget, isFalse);
    expect(await repo.getAccountBalance(accountId), 125);
    expect((await repo.getAccountStats(accountId)).income, 25);
    expect((await repo.getAccountStats(accountId)).expense, 0);
  });

  test('余额减少时生成普通支出和平账分类', () async {
    final ledgerId = await seedLedger();
    final accountId = await seedAccount(ledgerId);

    final result = await repo.setAccountBalance(
      ledgerId: ledgerId,
      accountId: accountId,
      targetBalance: 75,
      createBalanceAdjustment: true,
    );

    final transaction = await repo.getTransactionById(result.transactionId!);
    expect(transaction!.type, 'expense');
    expect(transaction.amount, 25);
    final category = await repo.getCategoryById(transaction.categoryId!);
    expect(category!.name, '平账');
    expect(category.kind, 'expense');
    expect(await repo.getAccountBalance(accountId), 75);
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
