/// 最近交易([RecentView] / [RecentTransactionRow])headless 冒烟测试:中/大
/// 两档 × 明暗、分类/账户缺失兜底、转账账户拼接、超长名称、超出上限截断等
/// 边界数据下都不应抛异常(尤其 RenderFlex 溢出——单行用 ellipsis,列表额外
/// 包一层不可滚动的 SingleChildScrollView 兜底,这里验证兜底确实生效)。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart' show Account, Category, Transaction;
import 'package:beecount/widget/views/recent_view.dart';
import 'package:beecount/widget/widget_data_service.dart' show RecentTransactionItem;
import 'package:beecount/widget/widget_spec.dart' show HWSize;

void main() {
  Widget wrap(Widget child, Size size) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: size.width, height: size.height, child: child),
    );
  }

  Transaction sampleTransaction({
    required int id,
    required String type,
    required double amount,
    int? categoryId,
    int? accountId,
    int? toAccountId,
    required DateTime happenedAt,
    String? currencyCode,
  }) {
    return Transaction(
      id: id,
      ledgerId: 1,
      type: type,
      amount: amount,
      categoryId: categoryId,
      accountId: accountId,
      toAccountId: toAccountId,
      happenedAt: happenedAt,
      excludeFromStats: false,
      excludeFromBudget: false,
      currencyCode: currencyCode,
    );
  }

  Category sampleCategory(int id, String name, {String? icon}) {
    return Category(
      id: id,
      name: name,
      kind: 'expense',
      icon: icon,
      sortOrder: id,
      level: 1,
      iconType: 'material',
    );
  }

  Account sampleAccount(int id, String name, {String currency = 'CNY'}) {
    return Account(
      id: id,
      ledgerId: 1,
      name: name,
      type: 'bank',
      currency: currency,
      initialBalance: 0,
      sortOrder: id,
      hidden: false,
    );
  }

  final oldDate = DateTime(2026, 3, 5, 9, 30);

  for (final dark in [false, true]) {
    group('RecentView.medium(${dark ? "暗色" : "亮色"}, 364x169)', () {
      testWidgets('支出/收入/转账混合 3 笔传入,medium 截断渲染前 2 笔', (tester) async {
        const size = Size(364, 169);
        final cat = sampleCategory(1, '餐饮', icon: 'restaurant');
        final accA = sampleAccount(1, '招商银行');
        final accB = sampleAccount(2, '支付宝');

        await tester.pumpWidget(wrap(
          RecentView(
            size: HWSize.medium,
            items: [
              RecentTransactionItem(
                transaction: sampleTransaction(
                  id: 1,
                  type: 'expense',
                  amount: 32.5,
                  categoryId: 1,
                  accountId: 1,
                  happenedAt: oldDate,
                ),
                category: cat,
                account: accA,
              ),
              RecentTransactionItem(
                transaction: sampleTransaction(
                  id: 2,
                  type: 'income',
                  amount: 8000,
                  categoryId: 1,
                  accountId: 1,
                  happenedAt: oldDate,
                ),
                category: cat,
                account: accA,
              ),
              RecentTransactionItem(
                transaction: sampleTransaction(
                  id: 3,
                  type: 'transfer',
                  amount: 500,
                  accountId: 1,
                  toAccountId: 2,
                  happenedAt: oldDate,
                ),
                account: accA,
                toAccount: accB,
              ),
            ],
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
        expect(find.text('餐饮'), findsNWidgets(2));
        expect(find.text('-¥32.5'), findsOneWidget);
        expect(find.text('+¥8,000'), findsOneWidget);
        // medium 只渲最近 2 笔(顶部加统一内容标签后 169 高度装不下 3 行,
        // 见 RecentView 类文档),第 3 笔转账不渲染。
        expect(find.text('招商银行 → 支付宝'), findsNothing);
        expect(find.text('¥500'), findsNothing);
      });

      testWidgets('分类/账户都缺失时用"未分类"兜底,不抛异常', (tester) async {
        const size = Size(364, 169);
        await tester.pumpWidget(wrap(
          RecentView(
            size: HWSize.medium,
            items: [
              RecentTransactionItem(
                transaction: sampleTransaction(
                  id: 1,
                  type: 'expense',
                  amount: 10,
                  happenedAt: oldDate,
                ),
              ),
              RecentTransactionItem(
                transaction: sampleTransaction(
                  id: 2,
                  type: 'transfer',
                  amount: 10,
                  happenedAt: oldDate,
                ),
              ),
            ],
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
        expect(find.text('未分类'), findsNWidgets(2));
      });

      testWidgets('转账只有转出账户(转入账户被删)时只显示转出账户名', (tester) async {
        const size = Size(364, 169);
        final accA = sampleAccount(1, '现金');
        await tester.pumpWidget(wrap(
          RecentView(
            size: HWSize.medium,
            items: [
              RecentTransactionItem(
                transaction: sampleTransaction(
                  id: 1,
                  type: 'transfer',
                  amount: 10,
                  accountId: 1,
                  toAccountId: 99,
                  happenedAt: oldDate,
                ),
                account: accA,
                toAccount: null,
              ),
            ],
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
        expect(find.text('现金'), findsOneWidget);
      });

      testWidgets('超长分类名不抛异常(ellipsis 兜底)', (tester) async {
        const size = Size(364, 169);
        final cat = sampleCategory(1, '一个非常非常长用来测试溢出的分类名称示例文本');
        await tester.pumpWidget(wrap(
          RecentView(
            size: HWSize.medium,
            items: [
              RecentTransactionItem(
                transaction: sampleTransaction(
                  id: 1,
                  type: 'expense',
                  amount: 10,
                  categoryId: 1,
                  happenedAt: oldDate,
                ),
                category: cat,
              ),
            ],
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

      testWidgets('交易自身 currencyCode 为外币时按外币符号显示,不抛异常', (tester) async {
        const size = Size(364, 169);
        await tester.pumpWidget(wrap(
          RecentView(
            size: HWSize.medium,
            items: [
              RecentTransactionItem(
                transaction: sampleTransaction(
                  id: 1,
                  type: 'expense',
                  amount: 20,
                  happenedAt: oldDate,
                  currencyCode: 'USD',
                ),
              ),
            ],
            // defaultCurrency 是 CNY,但交易自身 currencyCode=USD 应优先生效。
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
        expect(find.text('-\$20'), findsOneWidget);
      });

      testWidgets('今天发生的交易显示时:分,更早显示月/日', (tester) async {
        const size = Size(364, 169);
        final now = DateTime.now();
        await tester.pumpWidget(wrap(
          RecentView(
            size: HWSize.medium,
            items: [
              RecentTransactionItem(
                transaction: sampleTransaction(
                  id: 1,
                  type: 'expense',
                  amount: 10,
                  accountId: 1,
                  happenedAt: now,
                ),
                account: sampleAccount(1, '现金'),
              ),
              RecentTransactionItem(
                transaction: sampleTransaction(
                  id: 2,
                  type: 'expense',
                  amount: 10,
                  accountId: 1,
                  happenedAt: oldDate,
                ),
                account: sampleAccount(1, '现金'),
              ),
            ],
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
        final hh = now.hour.toString().padLeft(2, '0');
        final mm = now.minute.toString().padLeft(2, '0');
        expect(find.textContaining('现金 · $hh:$mm'), findsOneWidget);
        expect(find.textContaining('现金 · 3/5'), findsOneWidget);
      });

      testWidgets('空列表显示"暂无交易"占位,不抛异常', (tester) async {
        const size = Size(364, 169);
        await tester.pumpWidget(wrap(
          RecentView(
            size: HWSize.medium,
            items: const [],
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
      });

      testWidgets('超出上限(10 笔)按 take(2) 截断,不抛异常', (tester) async {
        const size = Size(364, 169);
        await tester.pumpWidget(wrap(
          RecentView(
            size: HWSize.medium,
            items: List.generate(
              10,
              (i) => RecentTransactionItem(
                transaction: sampleTransaction(
                  id: i,
                  type: 'expense',
                  amount: 10.0 + i,
                  happenedAt: oldDate,
                ),
              ),
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
        expect(find.byType(RecentTransactionRow), findsNWidgets(2));
      });
    });
  }

  group('RecentView.large(364x382)', () {
    testWidgets('6 笔正常渲染,不抛异常', (tester) async {
      const size = Size(364, 382);
      await tester.pumpWidget(wrap(
        RecentView(
          size: HWSize.large,
          items: List.generate(
            6,
            (i) => RecentTransactionItem(
              transaction: sampleTransaction(
                id: i,
                type: i.isEven ? 'expense' : 'income',
                amount: 10.0 + i,
                happenedAt: oldDate,
              ),
            ),
          ),
          defaultCurrency: 'CNY',
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
      expect(find.byType(RecentTransactionRow), findsNWidgets(6));
    });

    testWidgets('超出上限(10 笔)按 take(6) 截断,不抛异常', (tester) async {
      const size = Size(364, 382);
      await tester.pumpWidget(wrap(
        RecentView(
          size: HWSize.large,
          items: List.generate(
            10,
            (i) => RecentTransactionItem(
              transaction: sampleTransaction(
                id: i,
                type: 'expense',
                amount: 10.0 + i,
                happenedAt: oldDate,
              ),
            ),
          ),
          defaultCurrency: 'CNY',
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
      expect(find.byType(RecentTransactionRow), findsNWidgets(6));
    });
  });

  group('RecentTransactionRow', () {
    testWidgets('转账用 swap_horiz 图标,不复用分类图标兜底', (tester) async {
      await tester.pumpWidget(wrap(
        RecentTransactionRow(
          item: RecentTransactionItem(
            transaction: sampleTransaction(
              id: 1,
              type: 'transfer',
              amount: 10,
              happenedAt: oldDate,
            ),
          ),
          defaultCurrency: 'CNY',
          uncategorizedLabel: '未分类',
          themeColor: const Color(0xFFF5A623),
          redForIncome: true,
          dark: false,
        ),
        const Size(364, 60),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    });

    testWidgets('分类 icon 字段是 emoji 时直接以文字展示', (tester) async {
      await tester.pumpWidget(wrap(
        RecentTransactionRow(
          item: RecentTransactionItem(
            transaction: sampleTransaction(
              id: 1,
              type: 'expense',
              amount: 10,
              categoryId: 1,
              happenedAt: oldDate,
            ),
            category: Category(
              id: 1,
              name: '奶茶',
              kind: 'expense',
              icon: '🧋',
              sortOrder: 1,
              level: 1,
              iconType: 'material',
            ),
          ),
          defaultCurrency: 'CNY',
          uncategorizedLabel: '未分类',
          themeColor: const Color(0xFFF5A623),
          redForIncome: true,
          dark: false,
        ),
        const Size(364, 60),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('🧋'), findsOneWidget);
    });
  });
}
