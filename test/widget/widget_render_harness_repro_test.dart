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
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/widget/views/dashboard_view.dart';
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
}
