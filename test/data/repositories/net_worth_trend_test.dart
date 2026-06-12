import 'package:drift/drift.dart' as d;
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

  test('三值序列:资产账户与负债账户分别累计,net = assets + liabilities', () async {
    final cashId = await db.into(db.accounts).insert(AccountsCompanion.insert(
        ledgerId: 1,
        name: '现金',
        type: const d.Value('cash'),
        initialBalance: const d.Value(1000.0)));
    final ccId = await db.into(db.accounts).insert(AccountsCompanion.insert(
        ledgerId: 1,
        name: '信用卡',
        type: const d.Value('credit_card'),
        initialBalance: const d.Value(0.0)));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: 1,
        type: 'expense',
        amount: 200,
        accountId: d.Value(cashId),
        happenedAt: d.Value(DateTime(2026, 6, 10))));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: 1,
        type: 'expense',
        amount: 300,
        accountId: d.Value(ccId),
        happenedAt: d.Value(DateTime(2026, 6, 10))));

    final series = await repo.getNetWorthTrendSeries(
        startDate: DateTime(2026, 6, 10),
        endDate: DateTime(2026, 6, 10),
        ratesToBase: const {'CNY': 1.0});

    expect(series.length, 1);
    expect(series.first.assets, 800.0);
    expect(series.first.liabilities, -300.0);
    expect(series.first.net, 500.0);
  });

  test('空账户返回空序列', () async {
    final series = await repo.getNetWorthTrendSeries(
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 3),
        ratesToBase: const {'CNY': 1.0});
    expect(series, isEmpty);
  });

  test('多币种折算到主币种:各账户余额 × 汇率,缺汇率币种整条剔除', () async {
    // CNY 现金 1000(主币种,× 1.0)
    await db.into(db.accounts).insert(AccountsCompanion.insert(
        ledgerId: 1,
        name: '现金',
        type: const d.Value('cash'),
        initialBalance: const d.Value(1000.0)));
    // USD 银行卡 100(× 7.0 = 700)
    await db.into(db.accounts).insert(AccountsCompanion.insert(
        ledgerId: 1,
        name: '美元卡',
        type: const d.Value('bank_card'),
        currency: const d.Value('USD'),
        initialBalance: const d.Value(100.0)));
    // EUR 现金 50(ratesToBase 无 EUR → 整条剔除,不计入)
    await db.into(db.accounts).insert(AccountsCompanion.insert(
        ledgerId: 1,
        name: '欧元',
        type: const d.Value('cash'),
        currency: const d.Value('EUR'),
        initialBalance: const d.Value(50.0)));

    final series = await repo.getNetWorthTrendSeries(
        startDate: DateTime(2026, 6, 10),
        endDate: DateTime(2026, 6, 10),
        ratesToBase: const {'CNY': 1.0, 'USD': 7.0}); // 故意不含 EUR

    expect(series.length, 1);
    // 1000(CNY) + 100×7(USD) = 1700;EUR 缺汇率被剔除,不计入
    expect(series.first.assets, 1700.0);
    expect(series.first.liabilities, 0.0);
    expect(series.first.net, 1700.0);
  });

  test('getEarliestTransactionDate 排除以成员身份加入的共享账本', () async {
    // 自己账本(id=1,owner、非共享)
    await db.into(db.ledgers).insert(LedgersCompanion.insert(name: '个人'));
    // 以成员加入的共享账本(id=2,is_shared 且 my_role!=owner)
    await db.into(db.ledgers).insert(LedgersCompanion.insert(
        name: '共享',
        isShared: const d.Value(true),
        myRole: const d.Value('viewer')));
    final acc = await db.into(db.accounts).insert(AccountsCompanion.insert(
        ledgerId: 1, name: '现金', type: const d.Value('cash')));
    // 共享账本(id=2)更早的交易 2026-01 —— 应被排除
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: 2,
        type: 'expense',
        amount: 100,
        accountId: d.Value(acc),
        happenedAt: d.Value(DateTime(2026, 1, 5))));
    // 自己账本(id=1)的交易 2026-03 —— 趋势起点应取这个
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: 1,
        type: 'expense',
        amount: 200,
        accountId: d.Value(acc),
        happenedAt: d.Value(DateTime(2026, 3, 10))));

    final earliest = await repo.getEarliestTransactionDate();
    // 排除共享账本 2026-01,起点 = 自己账本最早 2026-03
    expect(earliest, DateTime(2026, 3, 10));
  });
}
