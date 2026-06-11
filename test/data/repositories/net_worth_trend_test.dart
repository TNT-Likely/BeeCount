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
        startDate: DateTime(2026, 6, 10), endDate: DateTime(2026, 6, 10));

    expect(series.length, 1);
    expect(series.first.assets, 800.0);
    expect(series.first.liabilities, -300.0);
    expect(series.first.net, 500.0);
  });

  test('空账户返回空序列', () async {
    final series = await repo.getNetWorthTrendSeries(
        startDate: DateTime(2026, 6, 1), endDate: DateTime(2026, 6, 3));
    expect(series, isEmpty);
  });
}
