/// `WidgetDataService.gatherGlance` 的今日/本月收支取数(从
/// `WidgetManager.updateWidget()` 迁移而来,P1 渲染管线参数化的一部分)。
/// 用内存 Drift 库验证:自然月 + 账本自定义 monthStartDay 两种口径下,
/// 求和范围与既有 `totalsByCategory` 语义一致。
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/utils/month_range.dart';
import 'package:beecount/widget/widget_data_service.dart';

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

  test('自然月(monthStartDay 默认 1):今日 + 本月收支求和', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 15);

    await repo.addTransaction(
        ledgerId: 1, type: 'expense', amount: 20, happenedAt: now);
    await repo.addTransaction(
        ledgerId: 1, type: 'income', amount: 50, happenedAt: now);
    // 上个月一笔支出,不应计入「本月」
    await repo.addTransaction(
        ledgerId: 1, type: 'expense', amount: 999, happenedAt: lastMonth);

    final data =
        await WidgetDataService.gatherGlance(repository: repo, ledgerId: 1);

    expect(data.todayExpenseTotal, 20);
    expect(data.todayIncomeTotal, 50);
    expect(data.monthExpenseTotal, 20);
    expect(data.monthIncomeTotal, 50);
  });

  test('账本自定义 monthStartDay:按自定义周期而非自然月求和', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency, month_start_day) "
        "VALUES (2, 'L2', 'CNY', 10)");
    final range = periodContaining(DateTime.now(), 10);
    final justBeforeRange = range.start.subtract(const Duration(days: 1));

    // 本周期内一笔支出
    await repo.addTransaction(
        ledgerId: 2, type: 'expense', amount: 30, happenedAt: range.start);
    // 上一周期最后一天一笔支出,不应计入本周期
    await repo.addTransaction(
        ledgerId: 2,
        type: 'expense',
        amount: 999,
        happenedAt: justBeforeRange);

    final data =
        await WidgetDataService.gatherGlance(repository: repo, ledgerId: 2);

    expect(data.monthExpenseTotal, 30);
  });

  test('账本不存在(getLedgerById 返回 null)时按自然月兜底,不抛异常', () async {
    final data = await WidgetDataService.gatherGlance(
        repository: repo, ledgerId: 999);

    expect(data.todayExpenseTotal, 0);
    expect(data.todayIncomeTotal, 0);
    expect(data.monthExpenseTotal, 0);
    expect(data.monthIncomeTotal, 0);
  });

  group('gatherNetWorthBreakdown', () {
    test('单币种:折算口径与直接口径一致(rate=1.0)', () async {
      await repo.createAccount(
          ledgerId: 1,
          name: '现金',
          type: 'cash',
          currency: 'CNY',
          initialBalance: 1000);
      await repo.createAccount(
          ledgerId: 1,
          name: '信用卡',
          type: 'credit_card',
          currency: 'CNY',
          initialBalance: -300);

      final data = await WidgetDataService.gatherNetWorthBreakdown(
          repository: repo, baseCurrency: 'CNY');

      expect(data.totalAssets, 1000);
      expect(data.totalLiabilities, -300);
      expect(data.netWorth, 700);
      expect(data.missingCurrencies, isEmpty);
    });

    test('多币种:有汇率的币种折算求和', () async {
      await repo.createAccount(
          ledgerId: 1,
          name: '现金',
          type: 'cash',
          currency: 'CNY',
          initialBalance: 1000);
      await repo.createAccount(
          ledgerId: 1,
          name: '美元卡',
          type: 'bank_card',
          currency: 'USD',
          initialBalance: 100);
      await repo.upsertAutoRates(
          base: 'CNY',
          rateDate: '2026-07-01',
          rates: {'USD': '7.0'},
          source: 'test',
          fetchedAt: DateTime.now());

      final data = await WidgetDataService.gatherNetWorthBreakdown(
          repository: repo, baseCurrency: 'CNY');

      expect(data.totalAssets, closeTo(1700, 1e-9)); // 1000 + 100×7
      expect(data.netWorth, closeTo(1700, 1e-9));
      expect(data.missingCurrencies, isEmpty);
    });

    test('多币种:缺汇率的币种整条剔除,并列入 missingCurrencies', () async {
      await repo.createAccount(
          ledgerId: 1,
          name: '现金',
          type: 'cash',
          currency: 'CNY',
          initialBalance: 1000);
      await repo.createAccount(
          ledgerId: 1,
          name: '美元卡',
          type: 'bank_card',
          currency: 'USD',
          initialBalance: 100);
      await repo.createAccount(
          ledgerId: 1,
          name: '欧元现金',
          type: 'cash',
          currency: 'EUR',
          initialBalance: 50);
      await repo.upsertAutoRates(
          base: 'CNY',
          rateDate: '2026-07-01',
          rates: {'USD': '7.0'}, // 故意不含 EUR
          source: 'test',
          fetchedAt: DateTime.now());

      final data = await WidgetDataService.gatherNetWorthBreakdown(
          repository: repo, baseCurrency: 'CNY');

      expect(data.totalAssets, closeTo(1700, 1e-9)); // EUR 50 被剔除,不计入
      expect(data.missingCurrencies, ['EUR']);
    });

    test('手动汇率覆盖优先于自动汇率', () async {
      await repo.createAccount(
          ledgerId: 1,
          name: '现金',
          type: 'cash',
          currency: 'CNY',
          initialBalance: 1000);
      await repo.createAccount(
          ledgerId: 1,
          name: '美元卡',
          type: 'bank_card',
          currency: 'USD',
          initialBalance: 100);
      await repo.upsertAutoRates(
          base: 'CNY',
          rateDate: '2026-07-01',
          rates: {'USD': '7.0'},
          source: 'test',
          fetchedAt: DateTime.now());
      await repo.setOverride(base: 'CNY', quote: 'USD', rate: '6.5');

      final data = await WidgetDataService.gatherNetWorthBreakdown(
          repository: repo, baseCurrency: 'CNY');

      expect(data.totalAssets, closeTo(1650, 1e-9)); // 1000 + 100×6.5(override 优先)
    });
  });

  group('gatherNetWorthTrend', () {
    test('多币种折算,缺汇率币种整条剔除(与 breakdown 同口径)', () async {
      await repo.createAccount(
          ledgerId: 1,
          name: '现金',
          type: 'cash',
          currency: 'CNY',
          initialBalance: 1000);
      await repo.createAccount(
          ledgerId: 1,
          name: '美元卡',
          type: 'bank_card',
          currency: 'USD',
          initialBalance: 100);
      await repo.createAccount(
          ledgerId: 1,
          name: '欧元现金',
          type: 'cash',
          currency: 'EUR',
          initialBalance: 50);
      await repo.upsertAutoRates(
          base: 'CNY',
          rateDate: '2026-07-01',
          rates: {'USD': '7.0'},
          source: 'test',
          fetchedAt: DateTime.now());

      final series = await WidgetDataService.gatherNetWorthTrend(
        repository: repo,
        baseCurrency: 'CNY',
        start: DateTime(2026, 7, 10),
        end: DateTime(2026, 7, 10),
      );

      expect(series.length, 1);
      expect(series.first.assets, closeTo(1700, 1e-9));
      expect(series.first.liabilities, 0);
      expect(series.first.net, closeTo(1700, 1e-9));
    });

    test('无账户返回空序列', () async {
      final series = await WidgetDataService.gatherNetWorthTrend(
        repository: repo,
        baseCurrency: 'CNY',
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 3),
      );
      expect(series, isEmpty);
    });
  });

  group('gatherNetWorthTopAccounts', () {
    test('按折算余额降序;隐藏账户排除;缺汇率账户仍返回(用原币余额兜底排序)',
        () async {
      final cnyId = await repo.createAccount(
          ledgerId: 1,
          name: '现金',
          type: 'cash',
          currency: 'CNY',
          initialBalance: 1000);
      final usdId = await repo.createAccount(
          ledgerId: 1,
          name: '美元卡',
          type: 'bank_card',
          currency: 'USD',
          initialBalance: 100);
      final eurId = await repo.createAccount(
          ledgerId: 1,
          name: '欧元现金',
          type: 'cash',
          currency: 'EUR',
          initialBalance: 50);
      final hiddenId = await repo.createAccount(
          ledgerId: 1,
          name: '已隐藏',
          type: 'cash',
          currency: 'CNY',
          initialBalance: 99999);
      await repo.setAccountHidden(hiddenId, true);
      await repo.upsertAutoRates(
          base: 'CNY',
          rateDate: '2026-07-01',
          rates: {'USD': '7.0'},
          source: 'test',
          fetchedAt: DateTime.now());

      final items = await WidgetDataService.gatherNetWorthTopAccounts(
          repository: repo, baseCurrency: 'CNY', limit: 10);

      expect(items.length, 3); // 隐藏账户被排除
      expect(items.map((i) => i.account.id), isNot(contains(hiddenId)));

      expect(items[0].account.id, cnyId);
      expect(items[0].convertedBalance, 1000);
      expect(items[1].account.id, usdId);
      expect(items[1].convertedBalance, closeTo(700, 1e-9));
      expect(items[2].account.id, eurId);
      expect(items[2].convertedBalance, isNull); // 缺汇率
      expect(items[2].balance, 50); // 原币余额仍返回,供 UI 兜底展示
    });

    test('limit 截断', () async {
      for (final balance in [500.0, 400.0, 300.0, 200.0, 100.0]) {
        await repo.createAccount(
            ledgerId: 1,
            name: 'acc$balance',
            type: 'cash',
            currency: 'CNY',
            initialBalance: balance);
      }

      final items = await WidgetDataService.gatherNetWorthTopAccounts(
          repository: repo, baseCurrency: 'CNY', limit: 3);

      expect(items.length, 3);
      expect(items.map((i) => i.balance).toList(), [500.0, 400.0, 300.0]);
    });

    test('无账户返回空列表', () async {
      final items = await WidgetDataService.gatherNetWorthTopAccounts(
          repository: repo, baseCurrency: 'CNY');
      expect(items, isEmpty);
    });
  });

  group('gatherQuickAddCategories', () {
    test('本月支出常用分类 top-N,降序,剔除未分类/收入/非本期', () async {
      final catShopping = await repo.createCategory(
          name: '购物', kind: 'expense', icon: 'shopping');
      final catFood = await repo.createCategory(
          name: '餐饮', kind: 'expense', icon: 'fastfood');
      final catTransport =
          await repo.createCategory(name: '交通', kind: 'expense', icon: 'car');
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 15);

      await repo.addTransaction(
          ledgerId: 1,
          type: 'expense',
          amount: 500,
          categoryId: catShopping,
          happenedAt: now);
      await repo.addTransaction(
          ledgerId: 1,
          type: 'expense',
          amount: 100,
          categoryId: catFood,
          happenedAt: now);
      await repo.addTransaction(
          ledgerId: 1,
          type: 'expense',
          amount: 200,
          categoryId: catFood,
          happenedAt: now);
      await repo.addTransaction(
          ledgerId: 1,
          type: 'expense',
          amount: 150,
          categoryId: catTransport,
          happenedAt: now);
      // 未分类支出:不作为快速记账候选(拿不到 categoryId 无法深链)。
      await repo.addTransaction(
          ledgerId: 1, type: 'expense', amount: 999, happenedAt: now);
      // 收入不计入(type 过滤)。
      await repo.addTransaction(
          ledgerId: 1,
          type: 'income',
          amount: 888,
          categoryId: catShopping,
          happenedAt: now);
      // 上月支出不计入(本期过滤)。
      await repo.addTransaction(
          ledgerId: 1,
          type: 'expense',
          amount: 10000,
          categoryId: catShopping,
          happenedAt: lastMonth);

      final items = await WidgetDataService.gatherQuickAddCategories(
          repository: repo, ledgerId: 1, limit: 2);

      expect(items.length, 2);
      expect(items[0].categoryId, catShopping);
      expect(items[0].total, 500);
      expect(items[0].icon, 'shopping');
      expect(items[1].categoryId, catFood);
      expect(items[1].total, 300); // 100 + 200
    });

    test('账本自定义 monthStartDay:按自定义周期取本期常用分类', () async {
      await db.customStatement(
          "INSERT INTO ledgers (id, name, currency, month_start_day) "
          "VALUES (2, 'L2', 'CNY', 10)");
      final catId = await repo.createCategory(name: '日用', kind: 'expense');
      final range = periodContaining(DateTime.now(), 10);
      final justBeforeRange = range.start.subtract(const Duration(days: 1));

      await repo.addTransaction(
          ledgerId: 2,
          type: 'expense',
          amount: 30,
          categoryId: catId,
          happenedAt: range.start);
      await repo.addTransaction(
          ledgerId: 2,
          type: 'expense',
          amount: 999,
          categoryId: catId,
          happenedAt: justBeforeRange);

      final items = await WidgetDataService.gatherQuickAddCategories(
          repository: repo, ledgerId: 2, limit: 10);

      expect(items.length, 1);
      expect(items.single.total, 30);
    });
  });

  group('gatherBudget', () {
    test('总预算 + 分类预算按用量降序,截断到 topCategoryCount', () async {
      await repo.createBudget(ledgerId: 1, type: 'total', amount: 3000);
      final cat1 = await repo.createCategory(name: '分类1', kind: 'expense');
      final cat2 = await repo.createCategory(name: '分类2', kind: 'expense');
      final cat3 = await repo.createCategory(name: '分类3', kind: 'expense');
      final cat4 = await repo.createCategory(name: '分类4', kind: 'expense');
      await repo.createBudget(
          ledgerId: 1, type: 'category', categoryId: cat1, amount: 500);
      await repo.createBudget(
          ledgerId: 1, type: 'category', categoryId: cat2, amount: 300);
      await repo.createBudget(
          ledgerId: 1, type: 'category', categoryId: cat3, amount: 200);
      await repo.createBudget(
          ledgerId: 1, type: 'category', categoryId: cat4, amount: 100);

      final now = DateTime.now();
      await repo.addTransaction(
          ledgerId: 1, type: 'expense', amount: 490, categoryId: cat1, happenedAt: now);
      await repo.addTransaction(
          ledgerId: 1, type: 'expense', amount: 100, categoryId: cat2, happenedAt: now);
      await repo.addTransaction(
          ledgerId: 1, type: 'expense', amount: 200, categoryId: cat3, happenedAt: now);
      await repo.addTransaction(
          ledgerId: 1, type: 'expense', amount: 10, categoryId: cat4, happenedAt: now);

      final overview = await WidgetDataService.gatherBudget(
          repository: repo, ledgerId: 1, topCategoryCount: 2);

      expect(overview.totalBudget, isNotNull);
      expect(overview.totalBudget!.used, closeTo(800, 1e-9)); // 490+100+200+10
      expect(overview.totalBudget!.budget, 3000);
      expect(overview.totalBudget!.remaining, closeTo(2200, 1e-9));

      expect(overview.categoryBudgets.length, 2); // 4 条截断到 2
      // 按使用率降序:cat3(200/200=1.0) > cat1(490/500=0.98) > cat2(0.33) > cat4(0.1)
      expect(overview.categoryBudgets[0].categoryId, cat3);
      expect(overview.categoryBudgets[1].categoryId, cat1);
    });

    test('无预算:totalBudget 为 null,分类预算为空', () async {
      final overview =
          await WidgetDataService.gatherBudget(repository: repo, ledgerId: 1);
      expect(overview.totalBudget, isNull);
      expect(overview.categoryBudgets, isEmpty);
    });
  });

  group('gatherRecent', () {
    test('拼上分类(支出)与转入转出账户(转账)', () async {
      final cat =
          await repo.createCategory(name: '餐饮', kind: 'expense', icon: 'fastfood');
      final accA = await repo.createAccount(ledgerId: 1, name: 'A', currency: 'CNY');
      final accB = await repo.createAccount(ledgerId: 1, name: 'B', currency: 'CNY');

      await repo.addTransaction(
          ledgerId: 1,
          type: 'expense',
          amount: 30,
          categoryId: cat,
          accountId: accA,
          happenedAt: DateTime(2026, 7, 1));
      await repo.addTransaction(
          ledgerId: 1,
          type: 'transfer',
          amount: 100,
          accountId: accA,
          toAccountId: accB,
          happenedAt: DateTime(2026, 7, 2));

      final items = await WidgetDataService.gatherRecent(
          repository: repo, ledgerId: 1, limit: 10);

      expect(items.length, 2);
      // 降序:转账(7-2)最新排第一。
      expect(items[0].transaction.type, 'transfer');
      expect(items[0].account!.id, accA);
      expect(items[0].toAccount!.id, accB);
      expect(items[0].category, isNull);

      expect(items[1].transaction.type, 'expense');
      expect(items[1].category!.name, '餐饮');
      expect(items[1].category!.icon, 'fastfood');
      expect(items[1].account!.id, accA);
      expect(items[1].toAccount, isNull);
    });

    test('空账本返回空列表', () async {
      final items = await WidgetDataService.gatherRecent(
          repository: repo, ledgerId: 999, limit: 5);
      expect(items, isEmpty);
    });
  });

  group('gatherDashboard', () {
    test('组合 glance/近30日趋势/最近交易/快速记账,各字段符合各自子方法口径', () async {
      // 账户与下面的收支交易刻意不挂钩(不传 accountId),让净值趋势与
      // 收支速览互不干扰,分别验证两边口径。
      await repo.createAccount(
          ledgerId: 1, name: '现金', currency: 'CNY', initialBalance: 1000);

      final cat = await repo.createCategory(name: '餐饮', kind: 'expense');
      final now = DateTime.now();
      await repo.addTransaction(
          ledgerId: 1, type: 'expense', amount: 50, categoryId: cat, happenedAt: now);
      await repo.addTransaction(
          ledgerId: 1, type: 'income', amount: 80, happenedAt: now);

      final data = await WidgetDataService.gatherDashboard(
          repository: repo, ledgerId: 1, baseCurrency: 'CNY');

      expect(data.glance.todayExpenseTotal, 50);
      expect(data.glance.todayIncomeTotal, 80);

      expect(data.netWorthTrend.length, 30); // 近 30 日(含今天)

      expect(data.recent.length, lessThanOrEqualTo(3));
      expect(data.recent, isNotEmpty);

      expect(data.quickAdd.length, lessThanOrEqualTo(4));
      expect(data.quickAdd.any((q) => q.categoryId == cat), isTrue);
    });
  });
}
