/// 复现「recent / dashboard 桌面组件真机红屏」的全链路测试。
///
/// 与各 view 的冒烟测试不同,这里走**真实管线**:内存 Drift 库播种真实形态的
/// 数据(含转账、adjustment 估值调整、外币、空账本等边界)→ 真实
/// `WidgetDataService.gatherRecent/gatherDashboard` 取数 → 按 home_widget
/// `renderFlutterWidget` 的**同款 harness 结构**包裹渲染(它把 widget 包在
/// `Directionality > Column(mainAxisAlignment: center)` 里,子组件拿到的是
/// 无界高度约束——与冒烟测试的紧约束 SizedBox 包裹不同,见 pub 缓存
/// `home_widget-0.9.2+1/lib/src/home_widget.dart` renderFlutterWidget)。
///
/// 若真机红屏是 build/layout 异常,本测试应能以 `tester.takeException()`
/// 暴露同一异常与堆栈。
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/budget_repository.dart'
    show BudgetOverview, BudgetUsage;
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/widget/views/budget_view.dart';
import 'package:beecount/widget/views/dashboard_view.dart';
import 'package:beecount/widget/views/glance_view.dart';
import 'package:beecount/widget/views/net_worth_view.dart';
import 'package:beecount/widget/views/quick_add_view.dart';
import 'package:beecount/widget/views/recent_view.dart';
import 'package:beecount/widget/widget_data_service.dart';
import 'package:beecount/widget/widget_spec.dart' show HWSize;

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

  /// 按 home_widget renderFlutterWidget 的 harness 结构包裹(Directionality >
  /// Column(center) > widget),外层 Center 模拟其 RenderPositionedBox。
  Widget harnessWrap(Widget view) {
    return Center(
      child: RepaintBoundary(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [view],
          ),
        ),
      ),
    );
  }

  /// 播种一个"真实形态"账本:分类/账户/各类型交易(支出/收入/转账/估值调整/
  /// 外币/大金额/今天与更早)。返回 ledgerId。
  Future<int> seedRealistic() async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    final catFood = await repo.createCategory(name: '餐饮', kind: 'expense');
    final catSalary = await repo.createCategory(name: '工资', kind: 'income');
    final accBank = await repo.createAccount(ledgerId: 1, name: '招商银行');
    final accCash =
        await repo.createAccount(ledgerId: 1, name: '现金', type: 'cash');

    final now = DateTime.now();
    // 今天的支出(走 HH:mm 分支)
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 32.5,
        categoryId: catFood,
        accountId: accBank,
        happenedAt: now);
    // 更早的收入(走 M/d 分支)+ 大金额
    await repo.addTransaction(
        ledgerId: 1,
        type: 'income',
        amount: 1234567.89,
        categoryId: catSalary,
        accountId: accBank,
        happenedAt: now.subtract(const Duration(days: 3)));
    // 转账(无分类,双账户)
    await repo.addTransaction(
        ledgerId: 1,
        type: 'transfer',
        amount: 500,
        accountId: accBank,
        toAccountId: accCash,
        happenedAt: now.subtract(const Duration(days: 1)));
    // 估值调整(真实数据存在的类型:无分类、走中性色分支)
    await repo.addTransaction(
        ledgerId: 1,
        type: 'adjustment',
        amount: 88,
        accountId: accBank,
        happenedAt: now.subtract(const Duration(days: 2)));
    return 1;
  }

  testWidgets('RecentView 真实 gather 数据 + harness 包裹:medium/large 不抛异常',
      (tester) async {
    // 播种/取数走真实 repo 栈,内部可能起一次性定时器(与被测渲染无关);
    // 用 runAsync 跑在真实事件循环,测试尾部再推时钟排干,避免
    // 「Timer is still pending」的框架误报。
    late final List<RecentTransactionItem> items;
    late final String currency;
    await tester.runAsync(() async {
      final ledgerId = await seedRealistic();
      items = await WidgetDataService.gatherRecent(
          repository: repo, ledgerId: ledgerId, limit: 6);
      currency = await WidgetDataService.gatherLedgerCurrency(
          repository: repo, ledgerId: ledgerId);
    });
    expect(items, isNotEmpty);

    for (final (size, w, h) in [
      (HWSize.medium, 364.0, 169.0),
      (HWSize.large, 364.0, 382.0),
    ]) {
      await tester.pumpWidget(harnessWrap(RecentView(
        size: size,
        items: items,
        defaultCurrency: currency,
        themeColor: const Color(0xFFF5A623),
        redForIncome: true,
        dark: false,
        width: w,
        height: h,
      )));
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'RecentView($size) 在 harness 包裹下抛异常(真机红屏根因)');
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10)); // 排干一次性定时器
  });

  testWidgets('DashboardView 真实 gather 数据 + harness 包裹:不抛异常',
      (tester) async {
    late final DashboardWidgetData data;
    late final String currency;
    await tester.runAsync(() async {
      final ledgerId = await seedRealistic();
      data = await WidgetDataService.gatherDashboard(
          repository: repo, ledgerId: ledgerId, baseCurrency: 'CNY');
      currency = await WidgetDataService.gatherLedgerCurrency(
          repository: repo, ledgerId: ledgerId);
    });

    await tester.pumpWidget(harnessWrap(DashboardView(
      data: data,
      defaultCurrency: currency,
      themeColor: const Color(0xFFF5A623),
      redForIncome: true,
      dark: false,
      width: 364,
      height: 382,
    )));
    await tester.pump();
    expect(tester.takeException(), isNull,
        reason: 'DashboardView 在 harness 包裹下抛异常(真机红屏根因)');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10)); // 排干一次性定时器
  });

  testWidgets('全新空账本(无交易/无账户/无预算):recent/dashboard 均不抛异常',
      (tester) async {
    late final List<RecentTransactionItem> items;
    late final DashboardWidgetData data;
    await tester.runAsync(() async {
      await db.customStatement(
          "INSERT INTO ledgers (id, name, currency) VALUES (7, 'Empty', 'CNY')");
      items = await WidgetDataService.gatherRecent(
          repository: repo, ledgerId: 7, limit: 6);
      data = await WidgetDataService.gatherDashboard(
          repository: repo, ledgerId: 7, baseCurrency: 'CNY');
    });

    await tester.pumpWidget(harnessWrap(RecentView(
      size: HWSize.medium,
      items: items,
      defaultCurrency: 'CNY',
      themeColor: const Color(0xFFF5A623),
      redForIncome: true,
      dark: false,
      width: 364,
      height: 169,
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(harnessWrap(DashboardView(
      data: data,
      defaultCurrency: 'CNY',
      themeColor: const Color(0xFFF5A623),
      redForIncome: true,
      dark: false,
      width: 364,
      height: 382,
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('结构断言:所有小组件视图树内禁用 Scrollable(离屏树无 View 会炸,红屏根因)',
      (tester) async {
    // ScrollableState.didChangeDependencies 会调 View.of(context),而
    // home_widget renderFlutterWidget 的离屏树没有 View 祖先 → 必抛
    // "View.of() was called with a context that does not contain a View"
    // (2026-07 真机 recent/dashboard 红屏根因;宿主测试树自带 View,
    // takeException 复现不出,故用结构断言防回归)。防溢出兜底一律用
    // WidgetOverflowClip(ClipRect+OverflowBox),不用 SingleChildScrollView。
    const honey = Color(0xFFF5A623);
    final now = DateTime(2026, 7, 20, 9, 30);
    Transaction tx(int id) => Transaction(
          id: id,
          ledgerId: 1,
          type: 'expense',
          amount: 32,
          categoryId: 1,
          accountId: 1,
          happenedAt: now,
          excludeFromStats: false,
          excludeFromBudget: false,
        );
    const cat = Category(
        id: 1, name: '餐饮', kind: 'expense', icon: 'restaurant',
        sortOrder: 1, level: 1, iconType: 'material');
    const acc = Account(
        id: 1, ledgerId: 1, name: '招商银行', type: 'bank', currency: 'CNY',
        initialBalance: 0, sortOrder: 1, hidden: false);
    final items = [
      for (var i = 1; i <= 6; i++)
        RecentTransactionItem(transaction: tx(i), category: cat, account: acc),
    ];
    final trend = [
      for (var i = 0; i < 10; i++)
        (
          date: DateTime(2026, 7, 1 + i),
          assets: 1000.0 + i,
          liabilities: 100.0,
          net: 900.0 + i,
        ),
    ];
    final quickAdd = const [
      QuickAddCategoryItem(categoryId: 1, name: '餐饮', icon: 'restaurant', total: 10),
      QuickAddCategoryItem(categoryId: 2, name: '交通', icon: 'directions_car', total: 8),
      QuickAddCategoryItem(categoryId: 3, name: '购物', icon: 'shopping_cart', total: 6),
    ];

    final views = <String, Widget>{
      'GlanceView.medium': const GlanceView.medium(
        todayExpense: '¥1', todayIncome: '¥2', monthExpense: '¥3',
        monthIncome: '¥4', themeColor: honey, redForIncome: true, dark: false,
        titleLabel: 'B', monthSuffix: '月', todayExpenseLabel: 'a',
        todayIncomeLabel: 'b', monthExpenseLabel: 'c', monthIncomeLabel: 'd',
        width: 364, height: 169,
      ),
      'NetWorthView.large(含账户明细)': NetWorthView(
        size: HWSize.large, netWorth: 900, totalAssets: 1000,
        totalLiabilities: 100, baseCurrency: 'CNY', trend: trend,
        topAccounts: [
          const NetWorthAccountItem(account: acc, balance: 10, convertedBalance: 10),
        ],
        themeColor: honey, redForIncome: true, dark: false,
        netWorthLabel: 'n', totalAssetsLabel: 'a', totalLiabilitiesLabel: 'l',
        width: 364, height: 382,
      ),
      'QuickAddView.small': QuickAddView(
        size: HWSize.small, categories: quickAdd, themeColor: honey,
        dark: false, addLabel: '+', width: 155, height: 155,
      ),
      'BudgetView.medium': BudgetView(
        size: HWSize.medium,
        overview: BudgetOverview(
            totalBudget: BudgetUsage(used: 5, budget: 10),
            categoryBudgets: const [], daysRemaining: 1, dailyAvailable: 1),
        currencyCode: 'CNY', themeColor: honey, redForIncome: true,
        dark: false, width: 364, height: 169,
      ),
      'RecentView.large(6 行)': RecentView(
        size: HWSize.large, items: items, defaultCurrency: 'CNY',
        themeColor: honey, redForIncome: true, dark: false,
        width: 364, height: 382,
      ),
      'DashboardView': DashboardView(
        data: DashboardWidgetData(
            glance: const GlanceWidgetData(
                todayExpenseTotal: 1, todayIncomeTotal: 2,
                monthExpenseTotal: 3, monthIncomeTotal: 4),
            netWorthTrend: trend, recent: items.take(2).toList(),
            quickAdd: quickAdd),
        defaultCurrency: 'CNY', themeColor: honey, redForIncome: true,
        dark: false, width: 364, height: 382,
      ),
    };

    for (final entry in views.entries) {
      await tester.pumpWidget(harnessWrap(entry.value));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${entry.key} 渲染抛异常');
      expect(find.byType(Scrollable), findsNothing,
          reason: '${entry.key} 树内出现 Scrollable——离屏渲染(无 View 祖先)必炸,'
              '防溢出请改用 WidgetOverflowClip');
    }
  });
}
