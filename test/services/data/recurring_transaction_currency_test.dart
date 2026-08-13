// 周期账单币种(issue #444):模板带 currencyCode → 生成的交易落该币种,
// 并按**生成当日**有效汇率折算 nativeAmount(模板不锁汇率)。
//
// 口径(.docs/multi-currency-ledger 01 §4.1 / §4.5 L12):
//  - 有账户 → 交易币种恒等于账户币种(账户内不混币),模板币种不得覆盖它;
//  - 无账户 → 用模板币种(L12 手选);模板币种为 null → 账本本位币(存量行为)。

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data/recurring_transaction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late int ledgerId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    ledgerId = await repo.createLedger(name: 'test', currency: 'CNY');
  });

  tearDown(() async {
    await db.close();
  });

  /// 插一条自动汇率(方向同 ExchangeRates:1 quote = rate base)。
  Future<void> seedRate(String quote, String rate) async {
    await db.customStatement(
        "INSERT INTO exchange_rates (base_currency, quote_currency, rate_date, "
        "rate, source, fetched_at) VALUES ('CNY', '$quote', '2026-08-01', "
        "'$rate', 'test', ${DateTime.now().millisecondsSinceEpoch ~/ 1000})");
  }

  /// 跑一次生成器,返回唯一那笔交易。
  Future<Transaction> generateOne() async {
    final generated =
        await RecurringTransactionService(repo).generatePendingTransactions();
    expect(generated, hasLength(1));
    return generated.first;
  }

  test('无账户 + 模板币种 JPY → 交易 currencyCode=JPY,按当日汇率折算', () async {
    await seedRate('JPY', '0.05');
    await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 5000,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now(),
      currencyCode: 'JPY',
    );

    final tx = await generateOne();
    expect(tx.currencyCode, 'JPY');
    expect(tx.nativeAmount, closeTo(250.0, 0.001)); // 5000 * 0.05
  });

  test('无账户 + 模板币种 JPY 但本地无汇率 → nativeAmount 回落 =amount(L11 可捞回)',
      () async {
    await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 5000,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now(),
      currencyCode: 'JPY',
    );

    final tx = await generateOne();
    expect(tx.currencyCode, 'JPY');
    expect(tx.nativeAmount, 5000.0);
  });

  test('模板币种为 null → 账本本位币(存量行为不变)', () async {
    await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now(),
    );

    final tx = await generateOne();
    expect(tx.currencyCode, 'CNY');
    expect(tx.nativeAmount, 10.0);
  });

  test('挂外币账户 → 交易跟账户币种(模板币种同为该币种)', () async {
    await seedRate('USD', '7.2');
    final accountId = await repo.createAccount(
        ledgerId: ledgerId, name: 'Chase', currency: 'USD');
    await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      accountId: accountId,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now(),
      currencyCode: 'USD',
    );

    final tx = await generateOne();
    expect(tx.currencyCode, 'USD');
    expect(tx.nativeAmount, closeTo(72.0, 0.001));
  });

  test('模板币种与所挂账户币种漂移 → 以账户币种为准(账户内不混币)', () async {
    await seedRate('USD', '7.2');
    final accountId = await repo.createAccount(
        ledgerId: ledgerId, name: 'Chase', currency: 'USD');
    // 模板存 JPY(例如账户事后被改币种),生成时必须跟账户 USD,
    // 否则 USD 账户里混进一笔 JPY 交易,余额口径就烂了。
    await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      accountId: accountId,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now(),
      currencyCode: 'JPY',
    );

    final tx = await generateOne();
    expect(tx.currencyCode, 'USD');
    expect(tx.nativeAmount, closeTo(72.0, 0.001));
  });

  test('模板 currencyCode 可增改删(编辑页保存路径)', () async {
    final id = await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      frequency: 'monthly',
      interval: 1,
      startDate: DateTime.now(),
      currencyCode: 'usd', // 小写入参也应规整为大写
    );
    var all = await repo.getAllRecurringTransactions();
    expect(all.firstWhere((r) => r.id == id).currencyCode, 'USD');

    Future<void> save(String? currency) => repo.updateRecurringTransaction(
          id: id,
          ledgerId: ledgerId,
          type: 'expense',
          amount: 10,
          frequency: 'monthly',
          interval: 1,
          startDate: DateTime.now(),
          currencyCode: currency,
        );

    await save('JPY');
    all = await repo.getAllRecurringTransactions();
    expect(all.firstWhere((r) => r.id == id).currencyCode, 'JPY');

    await save(null); // 改回本位币 → 落 null
    all = await repo.getAllRecurringTransactions();
    expect(all.firstWhere((r) => r.id == id).currencyCode, isNull);
  });

  test('v32 schema:recurring_transactions 带可空 currency_code 列', () async {
    final cols = await db
        .customSelect("PRAGMA table_info(recurring_transactions)")
        .get();
    final currencyCol = cols
        .where((r) => r.read<String>('name') == 'currency_code')
        .toList();
    expect(currencyCol, hasLength(1));
    expect(currencyCol.first.read<int>('notnull'), 0); // 可空:存量行留 NULL
  });
}
