import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/utils/credit_card_amounts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  late BeeDatabase db;
  late LocalRepository repo;
  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });
  tearDown(() async => db.close());

  test('还款为转账，溢缴计资产，消费跨过正余额后重新形成欠款', () async {
    final ledger = await repo.createLedger(name: '合成账本');
    final bank = await repo.createAccount(
        ledgerId: ledger, name: '银行', initialBalance: 10000);
    final card = await repo.createAccount(
        ledgerId: ledger, name: '信用卡', type: 'credit_card');
    Future<void> spend(double amount) => repo.addTransaction(
        ledgerId: ledger,
        type: 'expense',
        amount: amount,
        accountId: card,
        happenedAt: DateTime.now());
    await spend(1000);
    expect((await repo.getNetWorthBreakdown()).netWorth, 9000);
    await repo.addTransaction(
        ledgerId: ledger,
        type: 'transfer',
        amount: 1200,
        accountId: bank,
        toAccountId: card,
        happenedAt: DateTime.now());
    expect(await repo.getAccountBalance(bank), 8800);
    expect(await repo.getAccountBalance(card), 200);
    final overpaid = await repo.getNetWorthBreakdown();
    expect(overpaid.totalAssets, 9000);
    expect(overpaid.totalLiabilities, 0);
    expect(overpaid.netWorth, 9000);
    expect((await repo.getAccountStats(card)).expense, 1000);
    await spend(150);
    expect(await repo.getAccountBalance(card), 50);
    await spend(100);
    expect(await repo.getAccountBalance(card), -50);
    final finalState = await repo.getNetWorthBreakdown();
    expect(finalState.totalAssets, 8800);
    expect(finalState.totalLiabilities, -50);
    expect(finalState.netWorth, 8750);
    final day = DateTime.now();
    final trend = await repo.getNetWorthTrendSeries(
        startDate: day, endDate: day, ratesToBase: {'CNY': 1});
    expect(trend.single.net, 8750);
  });

  test('溢缴不抵其他卡欠款；负资产不按绝对值进入构成', () async {
    final ledger = await repo.createLedger(name: '合成账本');
    for (final a in [
      ('bank_card', 10000.0),
      ('cash', -200.0),
      ('credit_card', -1000.0),
      ('credit_card', 200.0)
    ]) {
      await repo.createAccount(
          ledgerId: ledger,
          name: '${a.$1} ${a.$2}',
          type: a.$1,
          initialBalance: a.$2);
    }
    final summary = (await repo.getNetWorthBreakdownByCurrency())['CNY']!;
    expect(summary.totalAssets, 10000);
    expect(summary.totalLiabilities, -1000);
    expect(summary.netWorth, 9000);
    final composition = await repo.getAssetCompositionByType();
    expect(
        composition
            .singleWhere((a) => a.type == 'credit_card_overpayment')
            .totalBalance,
        200);
    expect(
        composition
            .singleWhere((a) => a.type == '_negative_assets_')
            .totalBalance,
        -200);
    expect(
        composition
            .where((a) => a.totalBalance > 0)
            .fold(0.0, (s, a) => s + a.totalBalance),
        10200);
  });

  test('欠款、溢缴、额度未知与超额使用同一计算定义', () {
    expect(
        const CreditCardAmounts(-1000, limit: 20000).estimatedAvailable, 19000);
    expect(
        const CreditCardAmounts(200, limit: 20000).estimatedAvailable, 20200);
    expect(const CreditCardAmounts(-21000, limit: 20000).estimatedAvailable, 0);
    expect(const CreditCardAmounts(-1000).estimatedAvailable, isNull);
  });
}
