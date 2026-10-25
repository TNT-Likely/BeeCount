import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/presentation/v4/bindings/category_detail.dart';
import 'package:beecount/utils/shared_ledger_picker_filter.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late LocalRepository repo;
  late CategoryDetailController c;
  late int parent, child, direct, foreign, old;
  Future<void> waitFor(bool Function() condition) async {
    for (var i = 0; i < 200; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('Category projection did not settle: ${c.error}');
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency,sync_id) VALUES(1,'日常','CNY','ledger-1'),(2,'旅行','USD','ledger-2')");
    parent = await repo.createCategory(name: '餐饮', kind: 'expense');
    child = await repo.createSubCategory(
        parentId: parent, name: '咖啡', kind: 'expense');
    final other = await repo.createCategory(name: '购物', kind: 'expense');
    direct = await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 3,
        categoryId: parent,
        happenedAt: DateTime(2026, 10, 20),
        note: '一级记录');
    foreign = await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 12,
        currencyCode: 'USD',
        nativeAmount: 85.2,
        categoryId: child,
        happenedAt: DateTime(2026, 10, 21),
        note: '外币咖啡',
        excludeFromBudget: true);
    old = await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 9,
        categoryId: child,
        happenedAt: DateTime(2026, 9, 30));
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 50,
        categoryId: other,
        happenedAt: DateTime(2026, 10, 22));
    await repo.addTransaction(
        ledgerId: 2,
        type: 'expense',
        amount: 20,
        categoryId: child,
        happenedAt: DateTime(2026, 10, 23));
    final tag = await repo.createTag(name: '工作日');
    await repo.updateTransactionTags(transactionId: foreign, tagIds: [tag]);
    await repo.createAttachment(
        transactionId: foreign, fileName: 'qa.png', fileSize: 12);
    c = CategoryDetailController(
        repository: repo,
        categoryId: parent,
        ledgerId: 1,
        now: DateTime(2026, 10, 24));
    await c.start();
    await waitFor(() => !c.loading);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });
  test('默认保留全部时间，父分类包括真实二级，统计使用历史快照且限制账本', () {
    expect(c.count, 3);
    expect(c.amount, closeTo(97.2, .0001));
    expect(c.average, closeTo(32.4, .0001));
    expect(c.children.single.id, child);
    expect(c.childAmounts[child], closeTo(94.2, .0001));
    expect(c.tags[foreign]!.single.name, '工作日');
    expect(c.attachments[foreign], 1);
    expect(c.currencies, {'CNY'});
    expect(c.rows.map((r) => r.t.id), [foreign, direct, old]);
  });
  test('月年范围及累计趋势一致，月末边界不包含下月，原币排序规则保留', () async {
    c.choosePeriod(CategoryDetailPeriod.month);
    await waitFor(() => c.count == 2);
    expect(c.amount, closeTo(88.2, .0001));
    expect(c.share, closeTo(88.2 / 138.2, .0001));
    expect(c.trend, [3, 88.2]);
    c.chooseSort(CategoryDetailSort.amountAsc);
    await waitFor(() => c.rows.first.t.id == direct);
    c.choosePeriod(CategoryDetailPeriod.year);
    await waitFor(() => c.count == 3);
    expect(c.rows.map((r) => r.t.id), [direct, old, foreign]);
    c.chooseAnchor(DateTime(2026, 9));
    c.choosePeriod(CategoryDetailPeriod.month);
    await waitFor(() => c.count == 1);
    expect(c.rows.single.t.id, old);
  });
  test('从统计进入的自定义半开区间保留，二级仅展示自身并解析父级', () async {
    c.dispose();
    c = CategoryDetailController(
        repository: repo,
        categoryId: child,
        ledgerId: 1,
        initialStart: DateTime(2026, 10, 20),
        initialEnd: DateTime(2026, 10, 22));
    await c.start();
    await waitFor(() => !c.loading);
    expect(c.period, CategoryDetailPeriod.custom);
    expect(c.count, 1);
    expect(c.rows.single.t.id, foreign);
    expect(c.parent!.id, parent);
    expect(c.share, closeTo(85.2 / 88.2, .0001));
    expect(c.children, isEmpty);
  });
  test('全部账本保留来源与币种信息，未把其他账本写入当前范围', () async {
    c.dispose();
    c = CategoryDetailController(
        repository: repo, categoryId: parent, ledgerId: null);
    await c.start();
    await waitFor(() => !c.loading);
    expect(c.count, 4);
    expect(c.currencies, {'CNY', 'USD'});
    expect(c.ledgers[2]!.name, '旅行');
    expect(c.summaryComplete, isFalse);
    expect(c.currencyProjection!.missingCurrencies, ['USD']);
    // Q11/Q23: missing quotes must never produce a mixed complete total.
    expect(c.rows.where((r) => r.t.ledgerId == 2), hasLength(1));
  });
  test('分类重命名、实际交易新增删除可刷新，筛选排序不改任何交易字段', () async {
    final before = await repo.getTransactionsByLedger(1);
    await repo.updateCategory(parent, name: '饮食');
    await waitFor(() => c.category?.name == '饮食');
    final id = await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 2,
        categoryId: child,
        happenedAt: DateTime(2026, 10, 24));
    await waitFor(() => c.count == 4);
    await repo.deleteTransaction(id);
    await waitFor(() => c.count == 3);
    c.chooseSort(CategoryDetailSort.amountDesc);
    await waitFor(() => c.rows.first.t.id == foreign);
    expect(await repo.getTransactionsByLedger(1), before);
  });
  test('共享父子分类由 synthetic ID 解析，标签 override 和旧汇率快照保留', () async {
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency,sync_id,is_shared,my_role) VALUES(3,'共享','CNY','ledger-3',1,'editor')");
    await db.customStatement(
        "INSERT INTO shared_ledger_categories(ledger_sync_id,sync_id,name,kind,level,parent_sync_id,updated_at) VALUES('ledger-3','owner-root','共享餐饮','expense',1,NULL,1792713600),('ledger-3','owner-child','共享早餐','expense',2,'owner-root',1792713600)");
    final id = await repo.addTransaction(
        ledgerId: 3,
        type: 'expense',
        amount: 7,
        currencyCode: 'USD',
        nativeAmount: 49.7,
        categorySyncIdOverride: 'owner-child',
        happenedAt: DateTime(2026, 10, 24));
    final tx = (await repo.getTransactionById(id))!;
    await db.customStatement(
        "INSERT INTO shared_ledger_tags(ledger_sync_id,sync_id,name,updated_at) VALUES('ledger-3','owner-tag','共享标签',1792713600)");
    await db.customStatement(
        "INSERT INTO transaction_tag_overrides(transaction_sync_id,tag_sync_id,created_at) VALUES(?,?,1792713600)",
        [tx.syncId, 'owner-tag']);
    c.dispose();
    c = CategoryDetailController(
        repository: repo,
        categoryId: syntheticIdForSyncId('owner-root'),
        ledgerId: 3);
    await c.start();
    await waitFor(() => !c.loading);
    expect(c.category!.name, '共享餐饮');
    expect(c.children.single.id, syntheticIdForSyncId('owner-child'));
    expect(c.rows.single.t.id, id);
    expect(c.amount, 49.7);
    expect(c.tags[id]!.single.syncId, 'owner-tag');
    expect((await repo.getTransactionById(id))!.nativeAmount, 49.7);
  });
}
