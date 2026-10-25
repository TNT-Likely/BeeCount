import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/presentation/v4/bindings/category_detail.dart';
import 'package:beecount/presentation/v4/bindings/detail_currency_totals.dart';
import 'package:beecount/presentation/v4/bindings/tag_detail.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/utils/shared_ledger_picker_filter.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;
  late int category, tag;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency,sync_id) VALUES(1,'人民币','CNY','cny'),(2,'美元','USD','usd')");
    category = await repo.createCategory(name: '餐饮', kind: 'expense');
    tag = await repo.createTag(name: '旅行');
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      currentLedgerProvider.overrideWith(
          (ref) => repo.watchLedger(ref.watch(currentLedgerIdProvider))),
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<Transaction> tx(int ledger, double amount,
      {double? native, String? currency, bool exclude = false}) async {
    final id = await repo.addTransaction(
        ledgerId: ledger,
        type: 'expense',
        amount: amount,
        currencyCode: currency,
        nativeAmount: native,
        categoryId: category,
        happenedAt: DateTime(2026, 10, 24),
        excludeFromStats: exclude);
    await repo.addTagToTransaction(transactionId: id, tagId: tag);
    // Seed the actual legacy fields: normal App writes intentionally resolve them.
    await db.customStatement(
        'UPDATE transactions SET currency_code=?,native_amount=? WHERE id=?',
        [currency, native, id]);
    return (await repo.getTransactionById(id))!;
  }

  Future<DetailCurrencyProjection> project(List<Transaction> rows,
          {int target = 1}) async =>
      projectDetailCurrencyTransactions(
          await loadDetailCurrencyContext(repo, targetLedgerId: target), rows);
  Future<void> settle(
      CategoryDetailController c, bool Function() condition) async {
    for (var i = 0; i < 300; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('projection did not settle: ${c.error}');
  }

  test('真实两本位币和外币历史native按来源账本折算，只改变展示', () async {
    final rows = [
      await tx(1, 10),
      await tx(2, 20, currency: 'USD', native: 20),
      await tx(2, 5, currency: 'EUR', native: 6)
    ];
    final before = await db.select(db.transactions).get();
    await repo.setOverride(base: 'CNY', quote: 'USD', rate: '7.1');
    final first = await project(rows);
    expect(first.complete, isTrue);
    expect(first.total(rows), closeTo(194.6, 1e-9));
    await repo.setOverride(base: 'CNY', quote: 'USD', rate: '7.2');
    expect((await project(rows)).total(rows), closeTo(197.2, 1e-9));
    expect(await db.select(db.transactions).get(), before);
    expect(rows.last.amount, 5);
    expect(rows.last.nativeAmount, 6);
  });
  test('同本位币无需汇率，原币等于来源币的空native和旧隐式本币保留', () async {
    final rows = [await tx(1, 12, currency: 'CNY'), await tx(1, 3)];
    final p = await project(rows);
    expect(p.complete, isTrue);
    expect(p.total(rows), 15);
    expect(p.oldestRateDate, isNull);
  });
  test('外币缺历史native不能用amount冒充，缺quote不显示不完整合计', () async {
    final rows = [
      await tx(1, 12, currency: 'USD'),
      await tx(2, 20, currency: 'USD', native: 20)
    ];
    final p = await project(rows);
    expect(p.complete, isFalse);
    expect(p.total(rows), isNull);
    expect(p.missingCount, 2);
    expect(p.missingCurrencies, ['USD', 'USD→CNY']);
    expect(p.amounts, isEmpty);
  });
  test('来源账本不存在或空币种明确缺项', () async {
    final source = await tx(1, 10, currency: 'CNY');
    final missing = source.copyWith(ledgerId: 999);
    expect((await project([missing])).missingCurrencies, ['?']);
    await db.customStatement("UPDATE ledgers SET currency='' WHERE id=1");
    expect((await project([source], target: 2)).missingCurrencies, ['?']);
    expect((await project([source])).complete, isFalse);
  });
  test('非空非法原币码即使有native也明确缺项，不回写legacy空原币', () async {
    final rows = [
      await tx(1, 2, currency: 'NOT_A_CURRENCY', native: 2),
      await tx(1, 3, currency: ''),
      await tx(1, 4)
    ];
    final before = await db.select(db.transactions).get();
    final p = await project(rows);
    expect(p.missingCount, 1);
    expect(p.missingCurrencies, ['NOT_A_CURRENCY']);
    expect(p.amounts[rows[1].id], 3);
    expect(p.amounts[rows[2].id], 4);
    expect(await db.select(db.transactions).get(), before);
  });
  test('只存在反向汇率时复用倒数，手动优先于自动且不覆盖无效直接值', () async {
    final rows = [await tx(2, 20, currency: 'USD', native: 20)];
    await repo.setOverride(
        base: 'USD', quote: 'CNY', rate: '0.1408450704225352');
    expect((await project(rows)).total(rows), closeTo(142, 1e-8));
    await repo.upsertAutoRates(
        base: 'CNY',
        rateDate: '2026-10-24',
        rates: {'USD': '7'},
        source: 'fixture',
        fetchedAt: DateTime(2026, 10, 24));
    await repo.setOverride(base: 'CNY', quote: 'USD', rate: '7.1');
    expect((await project(rows)).total(rows), 142);
    await repo.setOverride(base: 'CNY', quote: 'USD', rate: 'NaN');
    expect((await project(rows)).complete, isFalse);
  });
  for (final value in ['0', '-1', 'NaN', 'Infinity', 'bad']) {
    test('非法汇率 $value 不可产生汇总', () async {
      final rows = [await tx(2, 20, currency: 'USD', native: 20)];
      await repo.setOverride(base: 'CNY', quote: 'USD', rate: value);
      expect((await project(rows)).total(rows), isNull);
    });
  }
  test('陈旧有效缓存继续折算但提供真实日期，未参与币种不污染日期', () async {
    final rows = [await tx(2, 20, currency: 'USD', native: 20)];
    await repo.upsertAutoRates(
        base: 'CNY',
        rateDate: '2026-10-01',
        rates: {'USD': '7.1', 'EUR': '8'},
        source: 'fixture',
        fetchedAt: DateTime(2026, 10, 24));
    final p = await project(rows);
    expect(p.total(rows), 142);
    expect(p.oldestRateDate, '2026-10-01');
    expect(p.isStaleAt(DateTime(2026, 10, 24)), isTrue);
    expect(p.isStaleAt(DateTime(2026, 10, 7)), isFalse);
  });
  test('标签provider随当前账本和quote信号刷新，历史字段不变且排除标记保留', () async {
    final rows = [
      await tx(1, 10),
      await tx(2, 20, currency: 'USD', native: 20),
      await tx(1, 5, exclude: true)
    ];
    await repo.setOverride(base: 'CNY', quote: 'USD', rate: '7.1');
    final scope = (tagId: tag, ledgerId: null, start: null, end: null);
    final listener =
        container.listen(tagDetailStatsProvider(scope), (_, __) {});
    expect((await container.read(tagDetailStatsProvider(scope).future)).expense,
        152);
    await repo.setOverride(base: 'CNY', quote: 'USD', rate: '7.2');
    container.read(rateRefreshTickProvider.notifier).state++;
    expect((await container.read(tagDetailStatsProvider(scope).future)).expense,
        154);
    container.read(currentLedgerIdProvider.notifier).state = 2;
    expect((await container.read(tagDetailStatsProvider(scope).future)).expense,
        closeTo(20 + 10 / 7.2, 1e-8));
    expect(await db.select(db.transactions).get(), rows);
    listener.close();
  });
  test('分类全部范围转换父子/平均/份额/趋势，切目标保留月年筛选和原币排序', () async {
    final child = await repo.createSubCategory(
        parentId: category, name: '咖啡', kind: 'expense');
    await tx(1, 10);
    final usd = await tx(2, 20, currency: 'USD', native: 20);
    await repo.updateTransaction(
        id: usd.id, type: 'expense', amount: usd.amount, categoryId: child);
    await repo.setOverride(base: 'CNY', quote: 'USD', rate: '7.1');
    final c = CategoryDetailController(
        repository: repo,
        categoryId: category,
        ledgerId: null,
        summaryLedgerId: 1,
        now: DateTime(2026, 10, 24));
    await c.start();
    await settle(c, () => !c.loading);
    expect(c.amount, 152);
    expect(c.average, 76);
    expect(c.share, 1);
    expect(c.childAmounts[child], 142);
    expect(c.trend.last, 152);
    c.choosePeriod(CategoryDetailPeriod.month);
    c.chooseSort(CategoryDetailSort.amountDesc);
    await settle(c, () => c.rows.first.t.id == usd.id);
    await c.setSummaryLedger(2);
    await settle(c, () => !c.loading);
    expect(c.summaryCurrency, 'USD');
    expect(c.amount, closeTo(20 + 10 / 7.1, 1e-8));
    expect(c.period, CategoryDetailPeriod.month);
    expect(c.sort, CategoryDetailSort.amountDesc);
    await repo.removeOverride(base: 'CNY', quote: 'USD');
    await c.refreshResources();
    expect(c.summaryComplete, isFalse);
    expect(c.shareComplete, isFalse);
    expect(c.trend, isEmpty);
    c.dispose();
  });
  test('共享synthetic分类标签身份保留，USD共享账本历史native折算到CNY', () async {
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency,sync_id,is_shared,my_role) VALUES(3,'共享美元','USD','shared',1,'editor')");
    await db.customStatement(
        "INSERT INTO shared_ledger_categories(ledger_sync_id,sync_id,name,kind,level,updated_at) VALUES('shared','shared-food','共享餐饮','expense',1,1792713600)");
    await db.customStatement(
        "INSERT INTO shared_ledger_tags(ledger_sync_id,sync_id,name,updated_at) VALUES('shared','shared-tag','共享标签',1792713600)");
    final id = await repo.addTransaction(
        ledgerId: 3,
        type: 'expense',
        amount: 5,
        currencyCode: 'EUR',
        nativeAmount: 6,
        categorySyncIdOverride: 'shared-food',
        happenedAt: DateTime(2026, 10, 24));
    final raw = (await repo.getTransactionById(id))!;
    await db.customStatement(
        "INSERT INTO transaction_tag_overrides(transaction_sync_id,tag_sync_id,created_at) VALUES(?,?,1792713600)",
        [raw.syncId, 'shared-tag']);
    await repo.setOverride(base: 'CNY', quote: 'USD', rate: '7.1');
    final transactions = await repo
        .watchTransactionsByTag(syntheticIdForSyncId('shared-tag'))
        .first;
    final data =
        await container.read(tagDetailRowsProvider(transactions).future);
    expect(data.rows.single.category!.id, syntheticIdForSyncId('shared-food'));
    expect(data.tags[id]!.single.id, syntheticIdForSyncId('shared-tag'));
    expect(data.currency.total(transactions), closeTo(42.6, 1e-9));
    expect(data.rows.single.t.nativeAmount, 6);
    expect(data.rows.single.t.amount, 5);
  });
}
