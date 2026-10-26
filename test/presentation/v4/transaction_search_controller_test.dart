import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/presentation/v4/bindings/transaction_search.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late LocalRepository repo;
  late TransactionSearchController c;
  late int foreign, transfer, parent, child, account, tag;
  Future<void> settle() async {
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      if (!c.loading && c.error == null) return;
    }
    fail('Search projection did not load: ${c.error}');
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'生活','CNY'),(2,'旅行','USD')");
    parent = await repo.createCategory(name: '餐饮', kind: 'expense');
    child = await repo.createCategory(
        name: '咖啡', kind: 'expense', parentId: parent);
    account =
        await repo.createAccount(ledgerId: 1, name: '美元钱包', currency: 'USD');
    final to =
        await repo.createAccount(ledgerId: 1, name: '转入银行卡', currency: 'USD');
    foreign = await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 12,
        currencyCode: 'USD',
        nativeAmount: 85.2,
        accountId: account,
        categoryId: child,
        happenedAt: DateTime(2026, 10, 20, 23, 59, 59),
        note: 'Coffee Shop');
    transfer = await repo.addTransaction(
        ledgerId: 1,
        type: 'transfer',
        amount: 8,
        accountId: to,
        toAccountId: account,
        happenedAt: DateTime(2026, 10, 21),
        note: '另一笔');
    await repo.addTransaction(
        ledgerId: 2,
        type: 'income',
        amount: 99,
        happenedAt: DateTime(2026, 10, 20),
        note: '其他账本');
    tag = await repo.createTag(name: '工作日', color: '#aa8b29');
    await repo.updateTransactionTags(transactionId: foreign, tagIds: [tag]);
    await repo.createAttachment(
        transactionId: foreign, fileName: 'qa.png', fileSize: 12);
    c = TransactionSearchController(
        repository: repo, ledgerId: 1, categoryLabel: (c) => c?.name ?? '未分类');
    await c.start();
    await settle();
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });
  test('普通搜索保留空输入提示，直接批量只加载当前账本', () async {
    expect(c.results, isEmpty);
    expect(c.tags[foreign]!.single.id, tag);
    expect(c.attachments[foreign], 1);
    c.dispose();
    c = TransactionSearchController(
        repository: repo,
        ledgerId: 1,
        initialBatch: true,
        categoryLabel: (c) => c?.name ?? '');
    await c.start();
    await settle();
    expect(c.results.map((r) => r.t.id).toSet(), {foreign, transfer});
  });
  test('关键词可检索原有备注分类金额，并补齐真实标签、币种和双账户', () {
    for (final query in ['COFFEE', '咖啡', '12.0', '工作日']) {
      c.search(query);
      expect(c.results.single.t.id, foreign, reason: query);
    }
    c.search('USD');
    expect(c.results.map((r) => r.t.id).toSet(), {foreign, transfer});
    c.search('美元钱包');
    expect(c.results.map((r) => r.t.id).toSet(), {foreign, transfer});
    c.search('其他账本');
    expect(c.results, isEmpty);
  });
  test('一级分类包含二级，账户匹配转入侧，标签与类型组合不会误包含', () async {
    c.applyFilter(
        TransactionSearchFilter(category: await repo.getCategoryById(parent)));
    expect(c.results.single.t.id, foreign);
    c.applyFilter(TransactionSearchFilter(accountId: account));
    expect(c.results, hasLength(2));
    c.applyFilter(TransactionSearchFilter(
        accountId: account, tagId: tag, kind: 'expense'));
    expect(c.results.single.t.id, foreign);
    c.applyFilter(TransactionSearchFilter(
        accountId: account, tagId: tag, kind: 'transfer'));
    expect(c.results, isEmpty);
  });
  test('原币与本位币金额筛选显式区分，日期包含所选末日并排除次日零点', () {
    c.applyFilter(const TransactionSearchFilter(minimum: 80, maximum: 90));
    expect(c.results, isEmpty);
    c.applyFilter(const TransactionSearchFilter(
        minimum: 80, maximum: 90, basis: SearchAmountBasis.ledger));
    expect(c.results.single.t.id, foreign);
    expect(c.expense, 85.2);
    c.applyFilter(TransactionSearchFilter(
        start: DateTime(2026, 10, 20), end: DateTime(2026, 10, 20)));
    expect(c.results.single.t.id, foreign);
  });
  test('全选反选只作用于结果，实时删除后剪去无效选择', () async {
    c.search('美元钱包');
    c.toggleBatch();
    c.selectAll();
    expect(c.selected, {foreign, transfer});
    expect(c.selectedTotal, 93.2);
    c.invert();
    expect(c.selected, isEmpty);
    c.toggle(foreign);
    c.invert();
    expect(c.selected, {transfer});
    await repo.deleteTransaction(transfer);
    for (var i = 0; i < 100 && c.results.length != 1; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(c.results.single.t.id, foreign);
    expect(c.selected, isEmpty);
  });
  test('最近搜索去重限量且可清除，历史操作不改交易', () async {
    final before = await repo.getTransactionsByLedger(1);
    for (var i = 0; i < 10; i++) {
      c.search('query$i');
      await c.remember();
    }
    c.search('query8');
    await c.remember();
    expect(c.history, hasLength(8));
    expect(c.history.first, 'query8');
    expect(
        (await SharedPreferences.getInstance())
            .getStringList(TransactionSearchController.historyKey),
        c.history);
    await c.clearHistory();
    expect(c.history, isEmpty);
    expect(await repo.getTransactionsByLedger(1), before);
  });
}
