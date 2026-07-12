/// v30 账本维度统计折本位币(02 §五铁律):
///   - builder 路径(totalsByMonth 代表)与 SQL 路径(monthlyTotals/totalsInRange
///     代表)均按 nativeAmount ?? amount 汇总
///   - 单币种账本(native==amount)结果与旧口径一致(回归锁)
///   - 账户维度(getAccountBalance)仍 amount 原币(回归锁,防误改)
///   - NULL native(绕过 repo 的历史写入)COALESCE 回退 amount
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';

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

  /// CNY 账本 + USD 账户;7 月两笔支出:外币 $12(≈86.4)+ 本位币 ¥100。
  Future<(int lid, int usdAccId)> seedMixed() async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, currency) "
        "VALUES (10, 1, 'Chase', 'USD')");
    await repo.addTransaction(
      ledgerId: 1, type: 'expense', amount: 12, accountId: 10,
      happenedAt: DateTime(2026, 7, 5),
      currencyCode: 'USD', nativeAmount: 86.4,
    );
    await repo.addTransaction(
      ledgerId: 1, type: 'expense', amount: 100,
      happenedAt: DateTime(2026, 7, 6),
    );
    return (1, 10);
  }

  test('builder 路径(totalsByMonth):多币种账本按 nativeAmount 汇总', () async {
    final (lid, _) = await seedMixed();
    final rows = await repo.totalsByMonth(
        ledgerId: lid, year: 2026, type: 'expense');
    final july = rows.firstWhere((r) => r.month.month == 7);
    expect(july.total, closeTo(186.4, 1e-9)); // 86.4 + 100,非 112
  });

  test('SQL 路径(monthlyTotals/totalsInRange):按 COALESCE(native,amount)', () async {
    final (lid, _) = await seedMixed();
    final (mi, me) = await repo.monthlyTotals(
        ledgerId: lid, month: DateTime(2026, 7, 1));
    expect(me, closeTo(186.4, 1e-9));
    expect(mi, 0);

    final (ri, re) = await repo.totalsInRange(
        ledgerId: lid,
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 8, 1));
    expect(re, closeTo(186.4, 1e-9));
    expect(ri, 0);
  });

  test('单币种账本:统计与旧口径一致(回归锁)', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (2, 'S', 'CNY')");
    await repo.addTransaction(
        ledgerId: 2, type: 'expense', amount: 30,
        happenedAt: DateTime(2026, 7, 5));
    await repo.addTransaction(
        ledgerId: 2, type: 'income', amount: 50,
        happenedAt: DateTime(2026, 7, 6));
    final (income, expense) =
        await repo.monthlyTotals(ledgerId: 2, month: DateTime(2026, 7, 1));
    expect(income, 50);
    expect(expense, 30);
  });

  test('NULL native(绕过 repo 写入的历史行)COALESCE 回退 amount', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (3, 'N', 'CNY')");
    await db.customStatement(
        "INSERT INTO transactions (id, ledger_id, type, amount, happened_at) "
        "VALUES (300, 3, 'expense', 42.0, ${DateTime(2026, 7, 5).millisecondsSinceEpoch ~/ 1000})");
    final (_, expense) =
        await repo.monthlyTotals(ledgerId: 3, month: DateTime(2026, 7, 1));
    expect(expense, 42.0);
  });

  test('getLedgerStats 账本余额折 nativeAmount(账本维度,反馈:改主币种要更新)', () async {
    final (lid, _) = await seedMixed();
    // CNY 账本 + USD $12(native 86.4) + 本位币支出 100 → 结余 = -(86.4+100)
    final stats = await repo.getLedgerStats(ledgerId: lid);
    expect(stats.balance, closeTo(-186.4, 1e-9),
        reason: '账本余额是账本维度,须折本位币;裸加原币会得 -112');
  });

  test('账户维度回归锁:USD 账户余额仍 Σamount 原币,不折算', () async {
    final (_, usdAccId) = await seedMixed();
    final balance = await repo.getAccountBalance(usdAccId);
    // 支出 $12 → 余额 -12(原币),绝不能是 -86.4
    expect(balance, closeTo(-12.0, 1e-9));
  });
}
