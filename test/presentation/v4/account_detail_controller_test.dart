import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/presentation/v4/bindings/account_detail_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('余额历史读取完整账本而不是第一页；时间筛选不改当前余额', () async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'生活','CNY')");
    final id =
        await repo.createAccount(ledgerId: 1, name: '现金', initialBalance: 1000);
    await repo.addTransaction(
        ledgerId: 1,
        type: 'income',
        amount: 100,
        accountId: id,
        happenedAt: DateTime(2026, 9, 20));
    for (var i = 0; i < 55; i++) {
      await repo.addTransaction(
          ledgerId: 1,
          type: 'expense',
          amount: 1,
          accountId: id,
          happenedAt: DateTime(2026, 10, 20, 12, i));
    }
    final original = await repo.getTransactionsByLedger(1);
    final controller = AccountDetailController(
        repository: repo,
        account: (await repo.getAccount(id))!,
        now: DateTime(2026, 10, 26));
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.rows.length, 50);
    expect(controller.totals.count, 55);
    expect(controller.stats.balance, 1045);
    expect(controller.history.last.balance, 1045);
    await controller.loadMore();
    expect(controller.rows.length, 55);
    expect(controller.rows.map((r) => r.id).toSet().length, 55);
    await controller.choosePeriod('all');
    expect(controller.totals.count, 56);
    expect(controller.stats.balance, 1045);
    await controller.filter(direction: 'income', text: '', order: 'timeDesc');
    expect(controller.rows.length, 1);
    expect(controller.stats.balance, 1045);
    expect(controller.totals.expense, 55);
    expect(await repo.getTransactionsByLedger(1), original);
  });
}
