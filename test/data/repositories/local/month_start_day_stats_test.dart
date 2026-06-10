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

  Future<int> seedLedger({int monthStartDay = 1}) {
    return db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: '测试账本',
          monthStartDay: Value(monthStartDay),
        ));
  }

  Future<void> addTx(int lid, String type, double amount, DateTime at) =>
      repo.addTransaction(
          ledgerId: lid, type: type, amount: amount, happenedAt: at);

  test('monthlyTotals 按起始日聚合: 6月标签 = [6.15, 7.15)', () async {
    final lid = await seedLedger(monthStartDay: 15);
    await addTx(lid, 'expense', 10, DateTime(2026, 6, 14, 23, 59)); // 5月周期
    await addTx(lid, 'expense', 20, DateTime(2026, 6, 15));          // 6月周期
    await addTx(lid, 'expense', 40, DateTime(2026, 7, 14, 23, 59)); // 6月周期
    await addTx(lid, 'expense', 80, DateTime(2026, 7, 15));          // 7月周期

    final (_, expense) =
        await repo.monthlyTotals(ledgerId: lid, month: DateTime(2026, 6, 1));
    expect(expense, 60); // 20 + 40
  });

  test('monthlyTotals 起始日=1 退化为自然月(回归红线)', () async {
    final lid = await seedLedger();
    await addTx(lid, 'expense', 10, DateTime(2026, 6, 1));
    await addTx(lid, 'expense', 20, DateTime(2026, 6, 30, 23, 59));
    await addTx(lid, 'expense', 40, DateTime(2026, 7, 1));
    final (_, expense) =
        await repo.monthlyTotals(ledgerId: lid, month: DateTime(2026, 6, 1));
    expect(expense, 30);
  });

  test('totalsByMonth 年视图 12 桶按周期标签归位', () async {
    final lid = await seedLedger(monthStartDay: 10);
    await addTx(lid, 'expense', 30, DateTime(2027, 1, 5)); // 2026-12 标签
    await addTx(lid, 'expense', 99, DateTime(2026, 1, 9)); // 2025-12 标签 → 范围外
    await addTx(lid, 'expense', 7, DateTime(2026, 1, 10)); // 2026-01 标签

    final rows =
        await repo.totalsByMonth(ledgerId: lid, type: 'expense', year: 2026);
    expect(rows.length, 12);
    expect(rows.firstWhere((r) => r.month.month == 1).total, 7);
    expect(rows.firstWhere((r) => r.month.month == 12).total, 30);
    expect(rows.fold<double>(0, (s, r) => s + r.total), 37);
  });

  test('yearlyTotals = 12 个周期之和(与 totalsByMonth 恒等)', () async {
    final lid = await seedLedger(monthStartDay: 10);
    await addTx(lid, 'expense', 30, DateTime(2027, 1, 5));
    await addTx(lid, 'expense', 99, DateTime(2026, 1, 9));
    final (_, expense) = await repo.yearlyTotals(ledgerId: lid, year: 2026);
    expect(expense, 30);
  });

  test('watchTransactionsInMonth 按周期过滤', () async {
    final lid = await seedLedger(monthStartDay: 15);
    await addTx(lid, 'expense', 10, DateTime(2026, 6, 14)); // 5月周期
    await addTx(lid, 'expense', 20, DateTime(2026, 6, 20)); // 6月周期
    final txs = await repo
        .watchTransactionsInMonth(ledgerId: lid, month: DateTime(2026, 6, 1))
        .first;
    expect(txs.length, 1);
    expect(txs.single.amount, 20);
  });

  test('预算周期跟随账本起始日,无视 budget.startDay', () async {
    final lid = await seedLedger(monthStartDay: 25);
    final now = DateTime.now();
    // 手算包含 now 的 [25日, 次月25日) 周期起点(不引工具函数,独立交叉验证)
    const day = 25;
    final periodStart = now.day >= day
        ? DateTime(now.year, now.month, day)
        : DateTime(now.year, now.month - 1, day);
    await addTx(lid, 'expense', 50, periodStart.add(const Duration(hours: 1)));
    await addTx(
        lid, 'expense', 70, periodStart.subtract(const Duration(hours: 1)));

    await repo.createBudget(
        ledgerId: lid, type: 'total', amount: 1000, startDay: 1);
    final budget = await repo.getTotalBudget(lid);
    final usage = await repo.getBudgetUsage(budget!.id, now);
    expect(usage.used, 50); // 只算当前周期,budget.startDay=1 被忽略

    final overview = await repo.getBudgetOverview(lid, now);
    final periodEnd = DateTime(periodStart.year, periodStart.month + 1, day);
    expect(overview.daysRemaining, periodEnd.difference(now).inDays);
  });
}
