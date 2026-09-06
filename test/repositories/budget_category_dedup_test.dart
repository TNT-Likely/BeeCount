import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_budget_repository.dart';

void main() {
  late BeeDatabase db;
  late LocalBudgetRepository repo;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalBudgetRepository(db);
    await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: '测试账本'),
        );
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: '住房',
            kind: 'expense',
            syncId: const Value('cat-housing'),
          ),
        );
  });

  tearDown(() async => db.close());

  test('历史重复分类预算按 Cloud 相同规则只返回 syncId 最大的一条', () async {
    await db.into(db.budgets).insert(
          BudgetsCompanion.insert(
            ledgerId: 1,
            type: const Value('category'),
            categoryId: const Value(1),
            amount: 100,
            syncId: const Value('budget-a'),
          ),
        );
    await db.into(db.budgets).insert(
          BudgetsCompanion.insert(
            ledgerId: 1,
            type: const Value('category'),
            categoryId: const Value(1),
            amount: 200,
            syncId: const Value('budget-z'),
          ),
        );

    final budgets = await repo.getCategoryBudgets(1);
    final byCategory = await repo.getBudgetByCategory(1, 1);

    expect(budgets, hasLength(1));
    expect(budgets.single.syncId, 'budget-z');
    expect(budgets.single.amount, 200);
    expect(byCategory?.syncId, 'budget-z');
  });
}
