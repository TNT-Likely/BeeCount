import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/cloud/transactions_json.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/data/repositories/local/loan_accounting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  late BeeDatabase db;
  late LocalRepository repo;
  late int ledger, bank, loan;
  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    ledger = await repo.createLedger(name: '贷款测试');
    bank = await repo.createAccount(
        ledgerId: ledger, name: '银行卡', initialBalance: 20000);
    loan = await repo.createAccount(
        ledgerId: ledger, name: '贷款', type: 'loan', initialBalance: -50000);
  });
  tearDown(() => db.close());
  Future<int> repay(double amount) => repo.addTransaction(
      ledgerId: ledger,
      type: 'transfer',
      amount: amount,
      accountId: bank,
      toAccountId: loan,
      happenedAt: DateTime.now());

  test('还本、利息及删除保持现金、负债、净资产和消费口径', () async {
    final tx = await repay(1000);
    expect(await repo.getAccountBalance(bank), 19000);
    expect(await repo.getAccountBalance(loan), -49000);
    expect(
        (await repo.monthlyTotals(
                ledgerId: ledger,
                month: DateTime(DateTime.now().year, DateTime.now().month)))
            .$2,
        0);
    await repo.addTransaction(
        ledgerId: ledger,
        type: 'expense',
        amount: 50,
        accountId: bank,
        happenedAt: DateTime.now());
    expect(await repo.getAccountBalance(bank), 18950);
    expect(
        (await repo.monthlyTotals(
                ledgerId: ledger,
                month: DateTime(DateTime.now().year, DateTime.now().month)))
            .$2,
        50);
    await repo.deleteTransaction(tx);
    expect(await repo.getAccountBalance(bank), 19950);
    expect(await repo.getAccountBalance(loan), -50000);
  });
  test('超额本金与普通收支拒绝，失败不落账', () async {
    await expectLater(repay(50001), throwsA(isA<LoanAccountingException>()));
    await expectLater(
        repo.addTransaction(
            ledgerId: ledger,
            type: 'expense',
            amount: 1,
            accountId: loan,
            happenedAt: DateTime.now()),
        throwsA(isA<LoanAccountingException>()));
    expect(await repo.getTransactionCountByAccount(loan), 0);
    expect(await repo.getAccountBalance(bank), 20000);
  });
  test('双端点编辑一次更新，失败保持原转账', () async {
    final tx = await repay(1000);
    await repo.updateTransferTransaction(
        id: tx,
        amount: 800,
        fromAccountId: bank,
        toAccountId: loan,
        happenedAt: DateTime.now());
    expect(await repo.getAccountBalance(bank), 19200);
    expect(await repo.getAccountBalance(loan), -49200);
    await expectLater(
        repo.updateTransferTransaction(
            id: tx,
            amount: 60000,
            fromAccountId: bank,
            toAccountId: loan,
            happenedAt: DateTime.now()),
        throwsA(isA<LoanAccountingException>()));
    expect((await repo.getTransactionById(tx))!.amount, 800);
  });
  test('旧欠款有历史流水时先核对，接续不会叠加或换身份', () async {
    final legacy = await db.into(db.accounts).insert(AccountsCompanion.insert(
        ledgerId: ledger,
        name: '旧贷款',
        type: const Value('loan'),
        initialBalance: const Value(-50000),
        syncId: const Value('legacy-stable')));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: ledger,
        type: 'transfer',
        amount: 1000,
        accountId: Value(bank),
        toAccountId: Value(legacy),
        happenedAt: Value(DateTime.now().subtract(const Duration(days: 7)))));
    await db.migrateLegacyLoansWithoutTransactions();
    expect((await repo.getAccount(legacy))!.loanBalanceVersion, 0);
    expect(await repo.getAccountBalance(legacy), -50000);
    await repo.activateLoanAccount(legacy, debt: 50000);
    expect((await repo.getAccount(legacy))!.syncId, 'legacy-stable');
    expect(await repo.getAccountBalance(legacy), -50000);
    expect((await repo.getAccount(legacy))!.initialBalance, -50000);
    await repo.addTransaction(
        ledgerId: ledger,
        type: 'transfer',
        amount: 1000,
        accountId: bank,
        toAccountId: legacy,
        happenedAt: DateTime.now());
    expect(await repo.getAccountBalance(legacy), -49000);
  });
  test('无流水旧贷款自动接续，估值资产仍然使用手动金额', () async {
    final legacy = await db.into(db.accounts).insert(AccountsCompanion.insert(
        ledgerId: ledger,
        name: '旧贷款无流水',
        type: const Value('loan'),
        initialBalance: const Value(-30000)));
    final house = await repo.createAccount(
        ledgerId: ledger,
        name: '房产',
        type: 'real_estate',
        initialBalance: 800000);
    await db.migrateLegacyLoansWithoutTransactions();
    expect((await repo.getAccount(legacy))!.loanBalanceVersion, 1);
    expect(await repo.getAccountBalance(legacy), -30000);
    await repo.updateAccountValuation(house, 820000);
    expect(await repo.getAccountBalance(house), 820000);
  });
  test('批量还款累计超额会整批回滚', () async {
    final entries = [30000.0, 30000.0]
        .map((amount) => TransactionsCompanion.insert(
            ledgerId: ledger,
            type: 'transfer',
            amount: amount,
            accountId: Value(bank),
            toAccountId: Value(loan),
            happenedAt: Value(DateTime.now())))
        .toList();
    await expectLater(
        repo.insertTransactionsBatchWithRelations(transactions: entries),
        throwsA(isA<LoanAccountingException>()));
    expect(await repo.getTransactionCountByAccount(loan), 0);
    expect(await repo.getAccountBalance(loan), -50000);
  });
  test('原生账本快照恢复保留本金版本、历史基线与当前欠款', () async {
    await repay(1000);
    final json = await exportTransactionsJson(db, ledger);
    final restoredDb = BeeDatabase.forTesting(NativeDatabase.memory());
    try {
      final restored = LocalRepository(restoredDb);
      final target = await restored.createLedger(name: '恢复');
      expect(
          (await importTransactionsJson(restored, target, json)).inserted, 1);
      final account = (await restored.getAllAccounts())
          .singleWhere((a) => a.type == 'loan');
      expect(account.loanBalanceVersion, 1);
      expect(account.loanBalanceSince, isNotNull);
      expect(await restored.getAccountBalance(account.id), -49000);
    } finally {
      await restoredDb.close();
    }
  });

  test('净资产历史不把接续之后的贷款值错位到过去', () async {
    await repay(1000);
    final now = DateTime.now();
    final series = await repo.getNetWorthTrendSeries(
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now,
        ratesToBase: {'CNY': 1});
    expect(series.length, 1);
    expect(series.single.date, DateTime(now.year, now.month, now.day));
    expect(series.single.net, -30000);
  });
}
