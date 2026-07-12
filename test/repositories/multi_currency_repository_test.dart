/// v30 交易级多币种 — Repository 层契约:
///   - addTransaction 带折算兜底(02 §六):同币种=amount;外币先查有效汇率,
///     取不到才 =amount(命中 L11 检测可捞回)
///   - updateTransaction 联动(与 Cloud merge/mutator L14 同规则):不传两字段
///     且 amount 变了 → 按隐含汇率联动;改备注不动快照
///   - recompute/recalc/count:补折算/全量重算/检测,逐笔记 change(L13)
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/cloud/sync/change_tracker.dart';
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

  Future<int> seedLedger({String currency = 'CNY'}) async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', '$currency')");
    return 1;
  }

  Future<int> seedAccount({int id = 10, String currency = 'USD'}) async {
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, currency) "
        "VALUES ($id, 1, 'A$id', '$currency')");
    return id;
  }

  Future<void> seedUsdRates() => repo.upsertAutoRates(
        base: 'CNY',
        rateDate: '2026-07-10',
        rates: {'USD': '7.2'},
        source: 'test',
        fetchedAt: DateTime.utc(2026, 7, 10),
      );

  group('addTransaction 带折算兜底', () {
    test('不传两字段+本位币账户 → currencyCode=账户币种, nativeAmount=amount', () async {
      final lid = await seedLedger();
      final aid = await seedAccount(currency: 'CNY');
      final id = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 100,
        accountId: aid,
        happenedAt: DateTime(2026, 7, 12),
      );
      final tx = await repo.getTransactionById(id);
      expect(tx!.currencyCode, 'CNY');
      expect(tx.nativeAmount, 100);
    });

    test('不传两字段+外币账户+有汇率 → nativeAmount=折算值', () async {
      final lid = await seedLedger();
      final aid = await seedAccount(currency: 'USD');
      await seedUsdRates();
      final id = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 12,
        accountId: aid,
        happenedAt: DateTime(2026, 7, 12),
      );
      final tx = await repo.getTransactionById(id);
      expect(tx!.currencyCode, 'USD');
      expect(tx.nativeAmount, closeTo(86.4, 1e-9));
    });

    test('不传两字段+外币账户+无汇率 → nativeAmount=amount(命中 L11 检测)', () async {
      final lid = await seedLedger();
      final aid = await seedAccount(currency: 'USD');
      final id = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 12,
        accountId: aid,
        happenedAt: DateTime(2026, 7, 12),
      );
      final tx = await repo.getTransactionById(id);
      expect(tx!.currencyCode, 'USD');
      expect(tx.nativeAmount, 12);
      expect(await repo.countUnconvertedForeignTx(lid), 1);
    });

    test('显式传外币两字段 → 原样写入(UI 手改汇率快照)', () async {
      final lid = await seedLedger();
      final aid = await seedAccount(currency: 'USD');
      final id = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 12,
        accountId: aid,
        happenedAt: DateTime(2026, 7, 12),
        currencyCode: 'USD',
        nativeAmount: 87.0, // 用户手改的汇率快照
      );
      final tx = await repo.getTransactionById(id);
      expect(tx!.nativeAmount, 87.0);
    });

    test('无账户交易(L12)显式传币种 → 写入所选;不传 → 本位币', () async {
      final lid = await seedLedger();
      await seedUsdRates();
      final id1 = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 12,
        happenedAt: DateTime(2026, 7, 12),
        currencyCode: 'USD',
        nativeAmount: 86.4,
      );
      expect((await repo.getTransactionById(id1))!.currencyCode, 'USD');

      final id2 = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 5,
        happenedAt: DateTime(2026, 7, 12),
      );
      final tx2 = await repo.getTransactionById(id2);
      expect(tx2!.currencyCode, 'CNY');
      expect(tx2.nativeAmount, 5);
    });
  });

  group('updateTransaction 联动兜底(L14 App 侧镜像)', () {
    test('不传两字段只改金额 → 外币按隐含汇率缩放', () async {
      final lid = await seedLedger();
      final aid = await seedAccount(currency: 'USD');
      final id = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 12,
        accountId: aid,
        happenedAt: DateTime(2026, 7, 12),
        currencyCode: 'USD',
        nativeAmount: 86.4,
      );
      await repo.updateTransaction(id: id, type: 'expense', amount: 24);
      final tx = await repo.getTransactionById(id);
      expect(tx!.amount, 24);
      expect(tx.nativeAmount, closeTo(172.8, 1e-9));
    });

    test('金额未变(改备注)→ 快照不动', () async {
      final lid = await seedLedger();
      final aid = await seedAccount(currency: 'USD');
      final id = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 12,
        accountId: aid,
        happenedAt: DateTime(2026, 7, 12),
        currencyCode: 'USD',
        nativeAmount: 86.4,
      );
      await repo.updateTransaction(
          id: id, type: 'expense', amount: 12, note: '改备注');
      final tx = await repo.getTransactionById(id);
      expect(tx!.note, '改备注');
      expect(tx.nativeAmount, 86.4);
    });

    test('显式传 nativeAmount → 以传入为准(不联动)', () async {
      final lid = await seedLedger();
      final aid = await seedAccount(currency: 'USD');
      final id = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 12,
        accountId: aid,
        happenedAt: DateTime(2026, 7, 12),
        currencyCode: 'USD',
        nativeAmount: 86.4,
      );
      await repo.updateTransaction(
          id: id,
          type: 'expense',
          amount: 24,
          currencyCode: 'USD',
          nativeAmount: 170.0);
      expect((await repo.getTransactionById(id))!.nativeAmount, 170.0);
    });
  });

  group('补折算 / 全量重算 / 检测', () {
    test('recompute 只补「未折算外币」;已折算/本位币不动;返回条数', () async {
      final lid = await seedLedger();
      final aid = await seedAccount(currency: 'USD');
      await seedUsdRates();
      // 未折算外币(native==amount,模拟迁移回填态)
      final unconverted = await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 10, accountId: aid,
        happenedAt: DateTime(2026, 7, 1),
        currencyCode: 'USD', nativeAmount: 10,
      );
      // 已折算外币(不许覆盖)
      final converted = await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 12, accountId: aid,
        happenedAt: DateTime(2026, 7, 2),
        currencyCode: 'USD', nativeAmount: 86.4,
      );
      // 本位币(不动)
      final cny = await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 50,
        happenedAt: DateTime(2026, 7, 3),
      );

      final n = await repo.recomputeForeignTxForLedger(lid);
      expect(n, 1);
      expect((await repo.getTransactionById(unconverted))!.nativeAmount,
          closeTo(72.0, 1e-9)); // 10 × 7.2
      expect((await repo.getTransactionById(converted))!.nativeAmount, 86.4);
      expect((await repo.getTransactionById(cny))!.nativeAmount, 50);
      expect(await repo.countUnconvertedForeignTx(lid), 0); // 横幅消失
    });

    test('纯本位币账本 recompute 返回 0、无改动', () async {
      final lid = await seedLedger();
      await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 50,
        happenedAt: DateTime(2026, 7, 3),
      );
      expect(await repo.recomputeForeignTxForLedger(lid), 0);
    });

    test('recalc 全量按新本位币重算(改本位币 §八)', () async {
      final lid = await seedLedger(); // 本位币 CNY
      final aid = await seedAccount(currency: 'USD');
      // 改本位币为 USD 后:CNY 交易要折 USD、USD 交易对齐 =amount
      await repo.upsertAutoRates(
        base: 'USD',
        rateDate: '2026-07-10',
        rates: {'CNY': '0.14'},
        source: 'test',
        fetchedAt: DateTime.utc(2026, 7, 10),
      );
      final usdTx = await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 12, accountId: aid,
        happenedAt: DateTime(2026, 7, 1),
        currencyCode: 'USD', nativeAmount: 86.4, // 旧本位币 CNY 的快照
      );
      final cnyTx = await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 100,
        happenedAt: DateTime(2026, 7, 2),
        currencyCode: 'CNY', nativeAmount: 100,
      );

      final n = await repo.recalcNativeAmountsForLedger(lid, 'USD');
      expect(n, 2);
      expect((await repo.getTransactionById(usdTx))!.nativeAmount, 12); // 对齐原币
      expect((await repo.getTransactionById(cnyTx))!.nativeAmount,
          closeTo(14.0, 1e-9)); // 100 × 0.14
    });

    test('countUnconvertedForeignTx:currency_code IS NULL 行 join 账户检出', () async {
      final lid = await seedLedger();
      await seedAccount(currency: 'USD');
      // 模拟绕过 repo 的历史写入:两列 NULL、挂外币账户
      await db.customStatement(
          "INSERT INTO transactions (id, ledger_id, type, amount, account_id, native_amount) "
          "VALUES (900, 1, 'expense', 8.0, 10, 8.0)");
      expect(await repo.countUnconvertedForeignTx(lid), 1);
    });

    test('重算逐笔记 change(L13):pending 条数 == 改动笔数', () async {
      db = BeeDatabase.forTesting(NativeDatabase.memory());
      final tracker = ChangeTracker(db);
      repo = LocalRepository(db, changeTracker: tracker);
      final lid = await seedLedger();
      final aid = await seedAccount(currency: 'USD');
      await seedUsdRates();
      await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 10, accountId: aid,
        happenedAt: DateTime(2026, 7, 1),
        currencyCode: 'USD', nativeAmount: 10,
      );
      final before = (await db.select(db.localChanges).get()).length;
      final n = await repo.recomputeForeignTxForLedger(lid);
      expect(n, 1);
      final after = (await db.select(db.localChanges).get()).length;
      expect(after - before, 1, reason: '重算必须逐笔记 change,否则云端投影不更新');
    });
  });
}
