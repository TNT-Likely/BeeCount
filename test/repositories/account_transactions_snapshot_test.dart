import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('账户流水完整保留原币/本位币快照、共享引用、日期和排除标记', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'本地','CNY')");
    final account =
        await repo.createAccount(ledgerId: 1, name: '美元', currency: 'USD');
    final id = await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 12,
        currencyCode: 'USD',
        nativeAmount: 85.2,
        accountId: account,
        categorySyncIdOverride: 'owner-category',
        accountSyncIdOverride: 'owner-account',
        toAccountSyncIdOverride: 'owner-target',
        happenedAt: DateTime(2026, 10, 24, 12, 34, 56),
        note: '历史美元',
        excludeFromStats: true,
        excludeFromBudget: true);
    final original = (await repo.getTransactionById(id))!;
    final fetched = (await repo.getAccountTransactions(account)).single;
    expect(fetched, original);
    expect((await repo.getAccountTransactions(account, flow: 'expense')).single,
        original);
    expect(await repo.getAccountTransactions(account, flow: 'income'), isEmpty);
  });

  test('转入转出筛选保持原账户范围和分页，不修改交易', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'本地','CNY')");
    final from = await repo.createAccount(ledgerId: 1, name: '转出');
    final to = await repo.createAccount(ledgerId: 1, name: '转入');
    final id = await repo.addTransaction(
        ledgerId: 1,
        type: 'transfer',
        amount: 2,
        accountId: from,
        toAccountId: to,
        currencyCode: 'CNY',
        nativeAmount: 2,
        happenedAt: DateTime(2026, 10, 24, 12, 34, 56));
    final original = (await repo.getTransactionById(id))!;
    expect((await repo.getAccountTransactions(from, flow: 'expense')).single,
        original);
    expect((await repo.getAccountTransactions(to, flow: 'income')).single,
        original);
    expect(await repo.getAccountTransactions(to, flow: 'expense'), isEmpty);
    expect(
        await repo.getAccountTransactions(from, limit: 1, offset: 1), isEmpty);
    expect(await repo.getTransactionById(id), original);
  });
}
