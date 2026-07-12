/// v30 迁移(交易级多币种,.docs/multi-currency-ledger)回填语义:
/// - currency_code = 账户币种(无账户 → 账本本位币 → 'CNY')
/// - native_amount = amount(隐含汇率 1.0);已有值不覆盖
///
/// in-memory db 由 create_all 建出 v30 全 schema,这里用「插 NULL 行 +
/// 执行 onUpgrade 里同一段回填 SQL」验证语义(SQL 与 db.dart v30 迁移块
/// 保持一字不差,改一处必须同步另一处)。
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';

/// 与 db.dart `if (from < 30)` 块内的回填 SQL 一致。
const backfillCurrencyCodeSql = '''
    UPDATE transactions SET currency_code = COALESCE(
      (SELECT a.currency FROM accounts a WHERE a.id = transactions.account_id),
      (SELECT l.currency FROM ledgers l WHERE l.id = transactions.ledger_id),
      'CNY')
    WHERE currency_code IS NULL;''';

const backfillNativeAmountSql =
    'UPDATE transactions SET native_amount = amount WHERE native_amount IS NULL;';

void main() {
  late BeeDatabase db;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<void> seed() async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, currency) VALUES (10, 1, 'Chase', 'USD')");
    // tx1: 挂 USD 账户,两列 NULL(模拟 v29 存量)
    await db.customStatement(
        "INSERT INTO transactions (id, ledger_id, type, amount, account_id) "
        "VALUES (100, 1, 'expense', 12.0, 10)");
    // tx2: 无账户,两列 NULL
    await db.customStatement(
        "INSERT INTO transactions (id, ledger_id, type, amount) "
        "VALUES (101, 1, 'expense', 5.0)");
    // tx3: 已有折算值(不许覆盖)
    await db.customStatement(
        "INSERT INTO transactions (id, ledger_id, type, amount, account_id, "
        "currency_code, native_amount) "
        "VALUES (102, 1, 'expense', 12.0, 10, 'USD', 86.4)");
  }

  Future<Map<int, (String?, double?)>> readBack() async {
    final rows = await db.customSelect(
        'SELECT id, currency_code, native_amount FROM transactions').get();
    return {
      for (final r in rows)
        r.read<int>('id'): (
          r.readNullable<String>('currency_code'),
          r.readNullable<double>('native_amount'),
        ),
    };
  }

  test('回填:currency_code=账户币种、无账户=账本币种;native_amount=amount', () async {
    await seed();
    await db.customStatement(backfillCurrencyCodeSql);
    await db.customStatement(backfillNativeAmountSql);

    final rows = await readBack();
    expect(rows[100], ('USD', 12.0)); // 账户币种 + 隐含汇率 1
    expect(rows[101], ('CNY', 5.0)); // 无账户 → 账本本位币
  });

  test('回填不覆盖已有值(WHERE IS NULL 守卫)', () async {
    await seed();
    await db.customStatement(backfillCurrencyCodeSql);
    await db.customStatement(backfillNativeAmountSql);

    final rows = await readBack();
    expect(rows[102], ('USD', 86.4)); // 已折算行原样
  });

  test('v30 schema:transactions 带两个可空列', () async {
    final cols =
        await db.customSelect("PRAGMA table_info(transactions)").get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('currency_code'));
    expect(names, contains('native_amount'));
  });
}
