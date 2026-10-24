import 'package:beecount/presentation/v4/gallery/business_page.dart';
import 'package:beecount/widgets/biz/format_money.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('账户卡整卡点击恢复原详情入口，菜单操作不会触发详情', (tester) async {
    var opened = 0, edited = 0;
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(
            body: BeeAccountCard(
                name: '测试卡',
                currency: 'CNY',
                balance: '¥120.00',
                kind: '现金',
                icon: const BeeLineIcon('Wallet'),
                menuLabel: '操作',
                onTap: () => opened++,
                actions: const [BeeMenuAction(value: 'edit', label: '编辑')],
                onAction: (_) => edited++))));
    await tester.tap(find.text('¥120.00', findRichText: true));
    expect(opened, 1);
    await tester.tap(find.byTooltip('操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect([opened, edited], [1, 1]);
    await tester.tap(find.text('测试卡'));
    expect(opened, 2);
  });
  test('共用金额文本保留原币符号、负数、小数、缩写和无币种回退', () {
    expect(
        formatDisplayAmount(12.5,
            currencyCode: 'USD', showCurrency: true, signed: false),
        '\$12.5');
    expect(
        formatDisplayAmount(-12.5,
            currencyCode: 'HKD', showCurrency: true, signed: false),
        'HK\$-12.5');
    expect(
        formatDisplayAmount(12.5,
            currencyCode: 'THB', showCurrency: true, signed: false),
        '฿12.5');
    expect(
        formatDisplayAmount(12500,
            currencyCode: 'CNY',
            showCurrency: true,
            useCompactFormat: true,
            signed: false),
        '¥1.25万');
    expect(
        formatDisplayAmount(12500,
            currencyCode: 'USD',
            showCurrency: true,
            useCompactFormat: true,
            isChineseLocale: false,
            signed: false),
        '\$12.5k');
    expect(formatDisplayAmount(-12.50, showCurrency: true, signed: false),
        '-12.5');
    expect(formatDisplayAmount(0, signed: false), '0');
  });

  testWidgets('业务验收41实际展示资产组件，隐私不泄露汇总文本，设置保留汇率入口', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: const Scaffold(body: BusinessAcceptancePage(isolatedCase: 40))));
    await tester.pumpAndSettle();
    expect(find.byType(BeeAssetSummary), findsOneWidget);
    expect(find.byType(BeeAssetChartSection<int>), findsOneWidget);
    expect(find.byType(BeeAccountPreferences), findsOneWidget);
    expect(find.textContaining('30,890', findRichText: true), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('隐藏资产金额'));
    await tester.tap(find.byTooltip('隐藏资产金额'));
    await tester.pumpAndSettle();
    for (final amount in ['30,890', '32,750', '1,860']) {
      expect(find.textContaining(amount, findRichText: true), findsNothing);
    }
    await tester.ensureVisible(find.text('资产构成'));
    await tester.tap(find.text('资产构成'));
    await tester.pumpAndSettle();
    expect(find.byType(BeeDonutChart), findsOneWidget);
    expect(
        tester
            .widget<BeeDonutChart>(find.byType(BeeDonutChart))
            .items
            .every((item) => item.valueLabel == '••••'),
        true);
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('默认支出账户'), findsNothing);
    expect(find.text('默认收入账户'), findsNothing);
    expect(find.text('汇率管理'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('短屏深色大字多币种与大金额不溢出，明细/隐私由宿主处理', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var details = 0, privacy = 0;
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(brightness: Brightness.dark),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(17),
                child: BeeAssetSummary(
                    title: '原币净资产与缺失汇率回退',
                    balances: const [
                      BeeAssetAmount('HK\$123,456,789,012.50'),
                      BeeAssetAmount('¥-9,876,543.25')
                    ],
                    assetsLabel: '总资产',
                    assets: const ['HK\$123,456,789,012.50', '¥20,000'],
                    liabilitiesLabel: '总负债',
                    liabilities: const ['HK\$999,999', '¥9,999'],
                    hidden: false,
                    privacyLabel: '隐藏',
                    onPrivacy: () => privacy++,
                    detailLabel: '折算详情',
                    onDetails: () => details++)))));
    await tester.tap(find.byTooltip('隐藏'));
    await tester.tap(find.byTooltip('折算详情'));
    expect([privacy, details], [1, 1]);
    expect(tester.takeException(), isNull);
  });
}
