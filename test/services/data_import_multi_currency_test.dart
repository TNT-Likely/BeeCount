/// v30 CSV/JSON 导入路径的多币种契约(02 §六导入修补,plan Task 10):
///   - 导入到本位币账户/无账户 → currencyCode=本位币, nativeAmount=amount
///   - 导入到外币账户 → currencyCode=账户币种, nativeAmount=折算(有汇率)
///     或 =amount(无汇率,命中 L11 检测),**不落 NULL**
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;
  late DataImportService service;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    service = DataImportService();
  });

  tearDown(() async => db.close());

  Future<void> seed() async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, currency) "
        "VALUES (10, 1, 'Chase', 'USD')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, currency) "
        "VALUES (11, 1, '现金', 'CNY')");
  }

  Future<List<Transaction>> allTx() =>
      (db.select(db.transactions)..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  test('导入:本位币账户/无账户 → currencyCode=CNY, native=amount;外币账户有汇率 → 折算', () async {
    await seed();
    await repo.upsertAutoRates(
      base: 'CNY',
      rateDate: '2026-07-10',
      rates: {'USD': '7.2'},
      source: 'test',
      fetchedAt: DateTime.utc(2026, 7, 10),
    );

    final result = await service.importTransactions(
      repo,
      1,
      [
        ImportTransaction(
            type: 'expense', amount: 100, happenedAt: DateTime(2026, 7, 1)),
        ImportTransaction(
            type: 'expense',
            amount: 50,
            happenedAt: DateTime(2026, 7, 2),
            accountName: '现金'),
        ImportTransaction(
            type: 'expense',
            amount: 12,
            happenedAt: DateTime(2026, 7, 3),
            accountName: 'Chase'),
      ],
      accountNameToId: {'现金': 11, 'Chase': 10},
      categoryCache: {},
      tagNameToId: {},
    );
    expect(result.inserted, 3);

    final txs = await allTx();
    expect(txs[0].currencyCode, 'CNY'); // 无账户 → 本位币
    expect(txs[0].nativeAmount, 100);
    expect(txs[1].currencyCode, 'CNY'); // 本位币账户
    expect(txs[1].nativeAmount, 50);
    expect(txs[2].currencyCode, 'USD'); // 外币账户 → 折算
    expect(txs[2].nativeAmount, closeTo(86.4, 1e-9));
  });

  test('导入:CSV 币种列显式指定(反馈10)→ 优先于账户币种/本位币兜底', () async {
    await seed();
    await repo.upsertAutoRates(
      base: 'CNY',
      rateDate: '2026-07-10',
      rates: {'JPY': '0.0488'},
      source: 'test',
      fetchedAt: DateTime.utc(2026, 7, 10),
    );
    final result = await service.importTransactions(
      repo,
      1,
      [
        // 无账户但 CSV 带币种列 JPY → 按 JPY 折算
        ImportTransaction(
            type: 'expense',
            amount: 1000,
            currencyCode: 'JPY',
            happenedAt: DateTime(2026, 7, 1)),
      ],
      accountNameToId: {},
      categoryCache: {},
      tagNameToId: {},
    );
    expect(result.inserted, 1);
    final txs = await allTx();
    expect(txs[0].currencyCode, 'JPY');
    expect(txs[0].nativeAmount, closeTo(48.8, 1e-9)); // 1000 × 0.0488
  });

  test('导入:外币账户无汇率 → native=amount(非 NULL),L11 检测能捞到', () async {
    await seed();
    final result = await service.importTransactions(
      repo,
      1,
      [
        ImportTransaction(
            type: 'expense',
            amount: 12,
            happenedAt: DateTime(2026, 7, 3),
            accountName: 'Chase'),
      ],
      accountNameToId: {'Chase': 10},
      categoryCache: {},
      tagNameToId: {},
    );
    expect(result.inserted, 1);

    final txs = await allTx();
    expect(txs[0].currencyCode, 'USD');
    expect(txs[0].nativeAmount, 12.0, reason: '不落 NULL,按 1:1 待补折算');
    expect(await repo.countUnconvertedForeignTx(1), 1);
  });
}
