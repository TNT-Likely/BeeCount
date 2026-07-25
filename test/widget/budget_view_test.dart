/// 预算进度([BudgetView])headless 冒烟测试:小/中两档 × 明暗、有/无总预算、
/// 有/无分类用量、超支(rate>1)等边界数据下都不应抛异常(尤其 RenderFlex
/// 溢出——分类用量卡是等分 Row,超长分类名靠 ellipsis 兜底,这里验证确实生效)。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/repositories/budget_repository.dart'
    show BudgetOverview, BudgetUsage, CategoryBudgetUsage;
import 'package:beecount/widget/views/budget_view.dart';
import 'package:beecount/widget/widget_spec.dart' show HWSize;

void main() {
  Widget wrap(Widget child, Size size) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: size.width, height: size.height, child: child),
    );
  }

  // 兜底占比排(无分类预算时):见 BudgetView.fallbackShares 文档。
  testWidgets('medium:无分类预算但有支出占比兜底 → 渲染占比小卡', (tester) async {
    const size = Size(364, 169);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: BudgetView(
          size: HWSize.medium,
          overview: BudgetOverview(
            totalBudget: BudgetUsage(used: 3200, budget: 5000),
            categoryBudgets: const [], // 用户只设了总预算
            daysRemaining: 10,
            dailyAvailable: 180,
          ),
          currencyCode: 'CNY',
          themeColor: const Color(0xFFF5A623),
          redForIncome: true,
          dark: false,
          fallbackShares: const [
            (name: '餐饮', share: 0.52),
            (name: '购物', share: 0.31),
            (name: '交通', share: 0.17),
          ],
          width: size.width,
          height: size.height,
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('52%'), findsOneWidget);
    expect(find.text('17%'), findsOneWidget);
  });

  CategoryBudgetUsage category(String name, double used, double budget) {
    return CategoryBudgetUsage(
      budgetId: name.hashCode,
      categoryId: name.hashCode,
      categoryName: name,
      usage: BudgetUsage(used: used, budget: budget),
    );
  }

  for (final dark in [false, true]) {
    group('BudgetView.small(${dark ? "暗色" : "亮色"})', () {
      testWidgets('155x155 正常用量(未超支)不抛异常', (tester) async {
        const size = Size(155, 155);
        await tester.pumpWidget(wrap(
          BudgetView(
            size: HWSize.small,
            overview: BudgetOverview(
              totalBudget: BudgetUsage(used: 3200, budget: 5000),
              categoryBudgets: const [],
              daysRemaining: 10,
              dailyAvailable: 180,
            ),
            currencyCode: 'CNY',
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
        expect(find.text('64%'), findsOneWidget);
      });

      testWidgets('超支(rate>1)不抛异常,百分比按真实值显示', (tester) async {
        const size = Size(155, 155);
        await tester.pumpWidget(wrap(
          BudgetView(
            size: HWSize.small,
            overview: BudgetOverview(
              totalBudget: BudgetUsage(used: 6400, budget: 5000),
              categoryBudgets: const [],
              daysRemaining: 0,
              dailyAvailable: 0,
            ),
            currencyCode: 'CNY',
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
        expect(find.text('128%'), findsOneWidget);
      });

      testWidgets('未设总预算时显示占位文案,不抛异常', (tester) async {
        const size = Size(155, 155);
        await tester.pumpWidget(wrap(
          BudgetView(
            size: HWSize.small,
            overview: const BudgetOverview(
              totalBudget: null,
              categoryBudgets: [],
              daysRemaining: 0,
              dailyAvailable: 0,
            ),
            currencyCode: 'CNY',
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
        expect(find.text('未设预算'), findsOneWidget);
      });
    });
  }

  group('BudgetView.medium(364x169)', () {
    testWidgets('总预算 + 3 个分类用量正常渲染,不抛异常', (tester) async {
      const size = Size(364, 169);
      await tester.pumpWidget(wrap(
        BudgetView(
          size: HWSize.medium,
          overview: BudgetOverview(
            totalBudget: BudgetUsage(used: 3200, budget: 5000),
            categoryBudgets: [
              category('餐饮', 900, 1000),
              category('交通', 200, 500),
              category('一个非常非常长的分类名称用于测试溢出', 50, 100),
            ],
            daysRemaining: 10,
            dailyAvailable: 180,
          ),
          currencyCode: 'CNY',
          themeColor: const Color(0xFFF5A623),
          redForIncome: false,
          dark: false,
          width: size.width,
          height: size.height,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('餐饮'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);
    });

    testWidgets('有分类预算但无总预算:总览退化提示,分类用量照常展示', (tester) async {
      const size = Size(364, 169);
      await tester.pumpWidget(wrap(
        BudgetView(
          size: HWSize.medium,
          overview: BudgetOverview(
            totalBudget: null,
            categoryBudgets: [category('餐饮', 900, 1000)],
            daysRemaining: 10,
            dailyAvailable: 180,
          ),
          currencyCode: 'USD',
          themeColor: const Color(0xFFF5A623),
          redForIncome: true,
          dark: true,
          width: size.width,
          height: size.height,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('未设预算'), findsOneWidget);
      expect(find.text('餐饮'), findsOneWidget);
    });

    testWidgets('完全没有预算数据时显示占位文案,不抛异常', (tester) async {
      const size = Size(364, 169);
      await tester.pumpWidget(wrap(
        BudgetView(
          size: HWSize.medium,
          overview: const BudgetOverview(
            totalBudget: null,
            categoryBudgets: [],
            daysRemaining: 0,
            dailyAvailable: 0,
          ),
          currencyCode: 'CNY',
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
      expect(find.text('未设预算'), findsOneWidget);
    });

    testWidgets('分类用量超过 3 个时按 take(3) 截断,不抛异常', (tester) async {
      const size = Size(364, 169);
      await tester.pumpWidget(wrap(
        BudgetView(
          size: HWSize.medium,
          overview: BudgetOverview(
            totalBudget: BudgetUsage(used: 100, budget: 1000),
            categoryBudgets: [
              category('餐饮', 10, 100),
              category('交通', 10, 100),
              category('购物', 10, 100),
              category('娱乐', 10, 100),
              category('医疗', 10, 100),
            ],
            daysRemaining: 10,
            dailyAvailable: 90,
          ),
          currencyCode: 'CNY',
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
      expect(find.text('医疗'), findsNothing);
    });
  });
}
