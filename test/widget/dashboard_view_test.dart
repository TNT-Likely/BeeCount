/// 综合仪表盘([DashboardView])headless 冒烟测试:亮/暗 × 完整数据/全空数据/
/// 超出上限截断/超长文案等边界数据下都不应抛异常(尤其 RenderFlex 溢出——
/// 大号高度紧张,趋势图与最近交易列表都用 Expanded 吸收剩余空间,这里验证
/// 即使数据拉满也不会溢出)。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart' show Account, Category, Transaction;
import 'package:beecount/widget/views/dashboard_view.dart';
import 'package:beecount/widget/views/recent_view.dart' show RecentTransactionRow;
import 'package:beecount/widget/widget_data_service.dart'
    show DashboardWidgetData, GlanceWidgetData, QuickAddCategoryItem, RecentTransactionItem;
import 'package:beecount/widget/widget_spec.dart' show HWSize;

void main() {
  Widget wrap(Widget child, Size size) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: size.width, height: size.height, child: child),
    );
  }

  const size = Size(364, 382);

  Transaction sampleTransaction({
    required int id,
    required String type,
    required double amount,
    int? categoryId,
    int? accountId,
    required DateTime happenedAt,
  }) {
    return Transaction(
      id: id,
      ledgerId: 1,
      type: type,
      amount: amount,
      categoryId: categoryId,
      accountId: accountId,
      happenedAt: happenedAt,
      excludeFromStats: false,
      excludeFromBudget: false,
    );
  }

  Category sampleCategory(int id, String name) {
    return Category(
      id: id,
      name: name,
      kind: 'expense',
      icon: 'restaurant',
      sortOrder: id,
      level: 1,
      iconType: 'material',
    );
  }

  Account sampleAccount(int id, String name) {
    return Account(
      id: id,
      ledgerId: 1,
      name: name,
      type: 'bank',
      currency: 'CNY',
      initialBalance: 0,
      sortOrder: id,
      hidden: false,
    );
  }

  List<({DateTime date, double assets, double liabilities, double net})>
      sampleTrend(int days) {
    final base = DateTime(2026, 6, 1);
    return List.generate(days, (i) {
      final assets = 100000.0 + i * 300;
      final liabilities = 20000.0 - i * 50;
      return (
        date: base.add(Duration(days: i)),
        assets: assets,
        liabilities: liabilities,
        net: assets - liabilities,
      );
    });
  }

  DashboardWidgetData sampleData({
    int recentCount = 3,
    int quickAddCount = 4,
    int trendDays = 30,
    String longNameSuffix = '',
  }) {
    final cat = sampleCategory(1, '餐饮$longNameSuffix');
    final acc = sampleAccount(1, '现金');
    return DashboardWidgetData(
      glance: const GlanceWidgetData(
        todayExpenseTotal: 88.5,
        todayIncomeTotal: 0,
        monthExpenseTotal: 3200.5,
        monthIncomeTotal: 8000,
      ),
      netWorthTrend: sampleTrend(trendDays),
      recent: List.generate(
        recentCount,
        (i) => RecentTransactionItem(
          transaction: sampleTransaction(
            id: i,
            type: i.isEven ? 'expense' : 'income',
            amount: 10.0 + i,
            categoryId: 1,
            accountId: 1,
            happenedAt: DateTime(2026, 6, 20),
          ),
          category: cat,
          account: acc,
        ),
      ),
      quickAdd: List.generate(
        quickAddCount,
        (i) => QuickAddCategoryItem(
          categoryId: i + 1,
          name: '分类$longNameSuffix$i',
          icon: 'restaurant',
          total: (i + 1) * 100.0,
        ),
      ),
    );
  }

  for (final dark in [false, true]) {
    group('DashboardView(${dark ? "暗色" : "亮色"})', () {
      testWidgets('完整数据(趋势/最近交易/快速记账均拉满)不抛异常', (tester) async {
        await tester.pumpWidget(wrap(
          DashboardView(
            data: sampleData(),
            defaultCurrency: 'CNY',
            themeColor: const Color(0xFFF5A623),
            redForIncome: true,
            dark: dark,
            width: size.width,
            height: size.height,
          ),
          size,
        ));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('最近交易'), findsOneWidget);
        // recent 只取前 2 笔,即便传入了 3 笔。
        expect(find.byType(RecentTransactionRow), findsNWidgets(2));
        // quickAdd 只取前 3 个分类 + 1 个记一笔按钮。
        expect(find.text('记一笔'), findsOneWidget);
      });

      testWidgets('全空数据(全新账本:无趋势/无交易/无快速记账分类)不抛异常', (tester) async {
        await tester.pumpWidget(wrap(
          DashboardView(
            data: const DashboardWidgetData(
              glance: GlanceWidgetData(
                todayExpenseTotal: 0,
                todayIncomeTotal: 0,
                monthExpenseTotal: 0,
                monthIncomeTotal: 0,
              ),
              netWorthTrend: [],
              recent: [],
              quickAdd: [],
            ),
            defaultCurrency: 'CNY',
            themeColor: const Color(0xFFF5A623),
            redForIncome: true,
            dark: dark,
            width: size.width,
            height: size.height,
          ),
          size,
        ));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('暂无交易'), findsOneWidget);
        expect(find.text('记一笔'), findsOneWidget);
        expect(find.byType(RecentTransactionRow), findsNothing);
      });

      testWidgets('趋势只有 1 个数据点(不足画线)不抛异常', (tester) async {
        await tester.pumpWidget(wrap(
          DashboardView(
            data: sampleData(trendDays: 1),
            defaultCurrency: 'CNY',
            themeColor: const Color(0xFFF5A623),
            redForIncome: true,
            dark: dark,
            width: size.width,
            height: size.height,
          ),
          size,
        ));
        await tester.pump();

        expect(tester.takeException(), isNull);
      });

      testWidgets('分类/交易名称超长时不抛异常(ellipsis 兜底)', (tester) async {
        await tester.pumpWidget(wrap(
          DashboardView(
            data: sampleData(longNameSuffix: '一个非常非常长用来测试溢出的名称示例文本'),
            defaultCurrency: 'CNY',
            themeColor: const Color(0xFFF5A623),
            redForIncome: true,
            dark: dark,
            width: size.width,
            height: size.height,
          ),
          size,
        ));
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('quickAdd 为空时只剩记一笔按钮,不抛异常', (tester) async {
    await tester.pumpWidget(wrap(
      DashboardView(
        size: HWSize.large,
        data: sampleData(quickAddCount: 0),
        defaultCurrency: 'CNY',
        themeColor: const Color(0xFFF5A623),
        redForIncome: true,
        dark: false,
        width: size.width,
        height: size.height,
      ),
      size,
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('记一笔'), findsOneWidget);
  });

  testWidgets('负净值(负债>资产)趋势不抛异常', (tester) async {
    final base = DateTime(2026, 6, 1);
    await tester.pumpWidget(wrap(
      DashboardView(
        data: DashboardWidgetData(
          glance: const GlanceWidgetData(
            todayExpenseTotal: 0,
            todayIncomeTotal: 0,
            monthExpenseTotal: 100,
            monthIncomeTotal: 0,
          ),
          netWorthTrend: List.generate(
            10,
            (i) => (
              date: base.add(Duration(days: i)),
              assets: 1000.0,
              liabilities: 5000.0 + i * 10,
              net: 1000.0 - (5000.0 + i * 10),
            ),
          ),
          recent: const [],
          quickAdd: const [],
        ),
        defaultCurrency: 'USD',
        themeColor: const Color(0xFFF5A623),
        redForIncome: false,
        dark: true,
        width: size.width,
        height: size.height,
      ),
      size,
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
