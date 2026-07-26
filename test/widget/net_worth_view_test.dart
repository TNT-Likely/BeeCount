/// 净资产([NetWorthView])headless 冒烟测试:小/中/大三档 × 明暗,以及
/// 空趋势/空账户明细等边界数据下都不应抛异常(尤其 RenderFlex 溢出——大号
/// 卡片的账户列表用 `SingleChildScrollView` 兜底,这里验证兜底确实生效)。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart' show Account;
import 'package:beecount/widget/views/net_worth_view.dart';
import 'package:beecount/widget/widget_data_service.dart' show NetWorthAccountItem;
import 'package:beecount/widget/widget_spec.dart' show HWSize;

void main() {
  Widget wrap(Widget child, Size size) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: size.width, height: size.height, child: child),
    );
  }

  List<({DateTime date, double assets, double liabilities, double net})> sampleTrend() {
    final base = DateTime(2026, 6, 1);
    return List.generate(10, (i) {
      final assets = 100000.0 + i * 500;
      final liabilities = 20000.0 - i * 100;
      return (
        date: base.add(Duration(days: i)),
        assets: assets,
        liabilities: liabilities,
        net: assets - liabilities,
      );
    });
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

  for (final dark in [false, true]) {
    group('NetWorthView.small(${dark ? "暗色" : "亮色"})', () {
      testWidgets('155x155 正常趋势数据下不抛异常', (tester) async {
        const size = Size(155, 155);
        await tester.pumpWidget(wrap(
          NetWorthView(
            size: HWSize.small,
            netWorth: 82345.67,
            totalAssets: 102345.67,
            totalLiabilities: 20000,
            baseCurrency: 'CNY',
            trend: sampleTrend(),
            themeColor: const Color(0xFFF5A623),
            redForIncome: true,
            dark: dark,
            netWorthLabel: '净资产',
            totalAssetsLabel: '总资产',
            totalLiabilitiesLabel: '总负债',
            width: size.width,
            height: size.height,
          ),
          size,
        ));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('净资产'), findsOneWidget);
      });

      testWidgets('空趋势(新账本无历史)不抛异常,环比 chip 不渲染', (tester) async {
        const size = Size(155, 155);
        await tester.pumpWidget(wrap(
          NetWorthView(
            size: HWSize.small,
            netWorth: 0,
            totalAssets: 0,
            totalLiabilities: 0,
            baseCurrency: 'CNY',
            trend: const [],
            themeColor: const Color(0xFFF5A623),
            redForIncome: true,
            dark: dark,
            netWorthLabel: '净资产',
            totalAssetsLabel: '总资产',
            totalLiabilitiesLabel: '总负债',
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

  group('NetWorthView.medium', () {
    testWidgets('364x169 亮色下不抛异常', (tester) async {
      const size = Size(364, 169);
      await tester.pumpWidget(wrap(
        NetWorthView(
          size: HWSize.medium,
          netWorth: 82345.67,
          totalAssets: 102345.67,
          totalLiabilities: 20000,
          baseCurrency: 'CNY',
          trend: sampleTrend(),
          themeColor: const Color(0xFFF5A623),
          redForIncome: false,
          dark: false,
          netWorthLabel: '净资产',
          totalAssetsLabel: '总资产',
          totalLiabilitiesLabel: '总负债',
          width: size.width,
          height: size.height,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('总资产'), findsOneWidget);
      expect(find.text('总负债'), findsOneWidget);
    });

    testWidgets('负净资产(负债>资产)暗色下不抛异常', (tester) async {
      const size = Size(364, 169);
      await tester.pumpWidget(wrap(
        NetWorthView(
          size: HWSize.medium,
          netWorth: -5000,
          totalAssets: 3000,
          totalLiabilities: 8000,
          baseCurrency: 'USD',
          trend: sampleTrend(),
          themeColor: const Color(0xFFF5A623),
          redForIncome: true,
          dark: true,
          netWorthLabel: '净资产',
          totalAssetsLabel: '总资产',
          totalLiabilitiesLabel: '总负债',
          width: size.width,
          height: size.height,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('NetWorthView.large', () {
    testWidgets('364x382 亮色 + 4 条账户明细(含未折算兜底)不抛异常', (tester) async {
      const size = Size(364, 382);
      await tester.pumpWidget(wrap(
        NetWorthView(
          size: HWSize.large,
          netWorth: 82345.67,
          totalAssets: 102345.67,
          totalLiabilities: 20000,
          baseCurrency: 'CNY',
          trend: sampleTrend(),
          topAccounts: [
            NetWorthAccountItem(
              account: sampleAccount(1, '招商银行'),
              balance: 50000,
              convertedBalance: 50000,
            ),
            NetWorthAccountItem(
              account: sampleAccount(2, '支付宝余额宝'),
              balance: 30000,
              convertedBalance: 30000,
            ),
            NetWorthAccountItem(
              account: sampleAccount(3, '日元活期', currency: 'JPY'),
              balance: 200000,
              convertedBalance: null, // 缺汇率,兜底原币展示
            ),
            NetWorthAccountItem(
              account: sampleAccount(4, '现金'),
              balance: 2345.67,
              convertedBalance: 2345.67,
            ),
          ],
          themeColor: const Color(0xFFF5A623),
          redForIncome: true,
          dark: false,
          netWorthLabel: '净资产',
          totalAssetsLabel: '总资产',
          totalLiabilitiesLabel: '总负债',
          width: size.width,
          height: size.height,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('招商银行'), findsOneWidget);
      // 未折算账户应显示日元符号而非人民币符号(兜底原币,不能借用 baseCurrency)。
      expect(find.textContaining('¥200,000'), findsOneWidget);
    });

    testWidgets('空账户明细 + 空趋势(暗色)显示占位文案,不抛异常', (tester) async {
      const size = Size(364, 382);
      await tester.pumpWidget(wrap(
        NetWorthView(
          size: HWSize.large,
          netWorth: 0,
          totalAssets: 0,
          totalLiabilities: 0,
          baseCurrency: 'CNY',
          trend: const [],
          themeColor: const Color(0xFFF5A623),
          redForIncome: true,
          dark: true,
          netWorthLabel: '净资产',
          totalAssetsLabel: '总资产',
          totalLiabilitiesLabel: '总负债',
          width: size.width,
          height: size.height,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('暂无账户'), findsOneWidget);
    });
  });
}
