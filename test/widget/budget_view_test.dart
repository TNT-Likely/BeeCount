/// 预算进度([BudgetView])headless 冒烟测试:小/中两档 × 明暗、有/无总预算、
/// 有/无分类用量、超支(rate>1)等边界数据下都不应抛异常(尤其 RenderFlex
/// 溢出——分类用量卡是等分 Row,超长分类名靠 ellipsis 兜底,这里验证确实生效)。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/repositories/budget_repository.dart'
    show BudgetOverview, BudgetUsage, CategoryBudgetUsage;
import 'package:beecount/widget/views/budget_view.dart';
import 'package:beecount/widget/views/widget_view_style.dart'
    show widgetTextPrimary, widgetExpenseColor;
import 'package:beecount/widget/widget_spec.dart' show HWSize;

void main() {
  Widget wrap(Widget child, Size size) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SizedBox.fromSize(size: size, child: child)),
    );
  }

  // 兜底占比排(无分类预算时):见 BudgetView.fallbackShares 文档。
  testWidgets('medium:无分类预算但有支出占比兜底 → 渲染占比小卡', (tester) async {
    const size = Size(364, 169);
    await tester.pumpWidget(wrap(
      BudgetView(
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
        monthLabel: 'Nov 2026',
        spendingShareLabel: 'Spending share',
        categoryUsageLabel: 'Category budget usage',
        fallbackShares: const [
          (name: '餐饮', share: 0.52),
          (name: '购物', share: 0.31),
          (name: '交通', share: 0.17),
        ],
        width: size.width,
        height: size.height,
      ),
      size,
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('Nov 2026'), findsOneWidget);
    expect(find.text('Spending share'), findsOneWidget);
    expect(find.text('Category budget usage'), findsNothing);
    expect(find.text('52%'), findsOneWidget);
    expect(find.text('17%'), findsOneWidget);
  });

  testWidgets('small:余额、已用和总额保留真实金额', (tester) async {
    const size = Size(155, 155);
    await tester.pumpWidget(wrap(
      BudgetView(
        size: HWSize.small,
        overview: BudgetOverview(
          totalBudget: BudgetUsage(used: 6842, budget: 8000),
          categoryBudgets: const [],
          daysRemaining: 11,
          dailyAvailable: 105.3,
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
    for (final value in ['剩', '已用', '总额', '¥1,158', '¥6,842', '¥8,000']) {
      expect(find.text(value), findsOneWidget);
    }
    expect(tester.getRect(find.text('已用')).left,
        closeTo(tester.getRect(find.text('总额')).left, .01));
    expect(tester.getRect(find.text('¥6,842')).right,
        closeTo(tester.getRect(find.text('¥8,000')).right, .01));
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
    for (final count in [1, 2, 3]) {
      testWidgets('medium aligns $count category columns in dark=$dark',
          (tester) async {
        const canvas = Size(364, 169);
        const title = '分類預算';
        const cases = [('購物', 49.0), ('交通', 36.0), ('餐飲', 21.0)];
        await tester.pumpWidget(wrap(
          BudgetView(
            size: HWSize.medium,
            overview: BudgetOverview(
              totalBudget: BudgetUsage(used: 152.2, budget: 600),
              categoryBudgets: [
                for (final (name, used) in cases.take(count))
                  category(name, used, 100)
              ],
              daysRemaining: 8,
              dailyAvailable: 33,
            ),
            currencyCode: 'CNY',
            themeColor: Colors.amber,
            redForIncome: false,
            dark: dark,
            usedLabel: '已用',
            totalLabel: '總額',
            remainingLabel: '剩餘',
            categoryUsageLabel: title,
            width: canvas.width,
            height: canvas.height,
          ),
          canvas,
        ));
        expect(tester.takeException(), isNull);
        Rect textRect(String label) => tester.getRect(find.text(label));
        double baseline(String label) {
          final box = tester.renderObject<RenderBox>(find.text(label));
          return box
              .localToGlobal(Offset(
                  0,
                  box.getDryBaseline(BoxConstraints.tight(box.size),
                      TextBaseline.alphabetic)!))
              .dy;
        }

        expect(find.text('¥447.8'), findsOneWidget);
        expect(baseline('已用'), closeTo(baseline('總額'), .01));
        expect(textRect(title).top, greaterThan(textRect('總額').bottom));
        final columns = <double>[];
        for (final (name, used) in cases.take(count)) {
          final ratio = '${used.round()}%';
          expect(baseline(name), closeTo(baseline(ratio), .01));
          columns.add(textRect(ratio).right - textRect(name).left);
        }
        expect(columns, everyElement(closeTo(columns.first, .01)));
        final card = tester.getRect(find.byType(BudgetView));
        expect(textRect('${cases[count - 1].$2.round()}%').right,
            closeTo(card.right - 17, .01));
        final tracks = find.byType(FractionallySizedBox);
        expect(tracks, findsNWidgets(count));
        expect(tester.getTopLeft(tracks.first).dy,
            closeTo(tester.getTopLeft(tracks.last).dy, .01));
      });
    }
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
        expect(find.text('¥-1,400'), findsOneWidget);
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
      expect(tester.widget<Text>(find.text('40%')).style?.color,
          widgetTextPrimary(false));
      expect(tester.widget<Text>(find.text('90%')).style?.color,
          widgetExpenseColor(false));
    });

    for (final cardSize in [HWSize.small, HWSize.medium]) {
      testWidgets('只有分类预算时展示真实分类用量 ($cardSize)', (tester) async {
        final size = cardSize == HWSize.small
            ? const Size(155, 155)
            : const Size(364, 169);
        await tester.pumpWidget(wrap(
          BudgetView(
            size: cardSize,
            overview: BudgetOverview(
              categoryBudgets: [
                category('餐饮', 90, 100),
                category('购物', 40, 100)
              ],
              daysRemaining: 10,
              dailyAvailable: 0,
            ),
            fallbackShares: const [(name: '无预算占比', share: .95)],
            currencyCode: 'CNY',
            themeColor: Colors.amber,
            redForIncome: false,
            dark: true,
            categoryUsageLabel: '分类预算',
            remainingLabel: '剩余',
            width: size.width,
            height: size.height,
          ),
          size,
        ));
        expect(tester.takeException(), isNull);
        expect(find.text('未设预算'), findsNothing);
        expect(find.text('无预算占比'), findsNothing);
        expect(find.text('分类预算'), findsOneWidget);
        expect(find.text('餐饮'), findsOneWidget);
        expect(find.text('90%'), findsOneWidget);
        if (cardSize == HWSize.small) {
          expect(find.text('¥10'), findsOneWidget);
          expect(find.text('购物'), findsNothing);
        } else {
          expect(find.text('购物'), findsOneWidget);
          expect(find.text('40%'), findsOneWidget);
          expect(find.text('¥90 / ¥100'), findsOneWidget);
        }
      });
    }

    testWidgets('完全无预算且本月有支出时保留支出占比', (tester) async {
      const size = Size(364, 169);
      await tester.pumpWidget(wrap(
        const BudgetView(
          size: HWSize.medium,
          overview: BudgetOverview(daysRemaining: 0, dailyAvailable: 0),
          fallbackShares: [(name: '餐饮', share: .87)],
          currencyCode: 'CNY',
          themeColor: Colors.amber,
          redForIncome: false,
          dark: true,
          categoryUsageLabel: '分类预算',
          spendingShareLabel: '支出占比',
          width: 364,
          height: 169,
        ),
        size,
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('未设预算'), findsOneWidget);
      expect(find.text('支出占比'), findsOneWidget);
      expect(find.text('分类预算'), findsNothing);
      expect(find.text('87%'), findsOneWidget);
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
