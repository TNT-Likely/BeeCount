import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount/presentation/v4/gallery/business_page.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(WidgetTester tester, Widget child, {double scale = 1}) =>
      tester.pumpWidget(MaterialApp(
        theme: beeTheme(brightness: Brightness.dark),
        builder: (_, child) => MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ));

  testWidgets('信用卡保留额度进度、银行估算说明和实际还款回调', (tester) async {
    var repays = 0;
    await open(
        tester,
        BeeCreditCardTerms(
            usage: .16,
            estimateHint: '估算值，以银行账单为准',
            billingLabel: '账单日12日 · 还款日28日',
            paymentLabel: '距还款日4天',
            repayLabel: '快速还款',
            onRepay: () => repays++));
    await tester.tap(find.text('快速还款'));
    expect(repays, 1);
    expect(find.text('估算值，以银行账单为准'), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        .16);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未设置额度仍可还款，禁用状态保留说明且不触发操作', (tester) async {
    await open(
        tester,
        const BeeCreditCardTerms(
            paymentLabel: '今天是还款日', repayLabel: '快速还款', onRepay: null));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('今天是还款日'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320深色大字可读取完整账单日期并操作还款', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var repays = 0;
    await open(
        tester,
        BeeCreditCardTerms(
            usage: 1.1,
            estimateHint: '可用额度为估算值，实际欠款和到账时间以银行账单为准。',
            billingLabel: '每月12日出账单，每月28日还款',
            paymentLabel: '今天是还款日，请及时还款',
            repayLabel: '快速还款',
            onRepay: () => repays++),
        scale: 1.4);
    await tester.ensureVisible(find.text('快速还款'));
    await tester.tap(find.text('快速还款'));
    expect(repays, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('受控环形图保留扇区命中、中心取消和图例选择', (tester) async {
    var selected = -1;
    const items = [
      BeeChartSlice(
          label: '餐饮', value: 60, color: Colors.amber, valueLabel: '60.00'),
      BeeChartSlice(
          label: '购物', value: 40, color: Colors.blue, valueLabel: '40.00')
    ];
    await open(
        tester,
        StatefulBuilder(
            builder: (context, setState) => BeeDonutChart(
                items: items,
                centerLabel: selected < 0 ? '全部' : items[selected].label,
                selected: selected,
                onSelected: (i) => setState(() => selected = i))));
    final paint = find
        .descendant(
            of: find.byType(BeeDonutChart), matching: find.byType(CustomPaint))
        .first;
    final center = tester.getCenter(paint);
    await tester.tapAt(center + const Offset(68, 0));
    await tester.pump();
    expect(selected, 0);
    await tester.tapAt(center + const Offset(-68, 0));
    await tester.pump();
    expect(selected, 1);
    await tester.tapAt(center);
    await tester.pump();
    expect(selected, -1);
    await tester.tap(find.widgetWithText(ActionChip, '餐饮 60.00'));
    await tester.pump();
    expect(selected, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('环形图忽略非有限和非正值，禁用图例时不触发操作', (tester) async {
    var tapped = 0;
    await open(
        tester,
        BeeDonutChart(items: const [
          BeeChartSlice(
              label: '无效',
              value: double.nan,
              color: Colors.red,
              valueLabel: '0')
        ], centerLabel: '无数据', onSelected: (_) => tapped++));
    final paint = find
        .descendant(
            of: find.byType(BeeDonutChart), matching: find.byType(CustomPaint))
        .first;
    await tester.tapAt(tester.getCenter(paint) + const Offset(68, 0));
    await tester.pump();
    expect(tapped, 0);
    await open(tester, const BeeDonutChart(items: [], centerLabel: '无数据'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('App内图表验收示例实际更新选中分类和中心金额', (tester) async {
    await open(tester, const BusinessAcceptancePage(isolatedCase: 21));
    final chip = find.widgetWithText(ActionChip, '购物 ¥920.22');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(tester.widget<BeeDonutChart>(find.byType(BeeDonutChart)).centerLabel,
        '购物\n¥920.22');
    expect(
        tester.widget<BeeDonutChart>(find.byType(BeeDonutChart)).selected, 1);
    expect(tester.widget<ActionChip>(chip).backgroundColor,
        BeeCardTheme.of(tester.element(chip)).soft);
    expect(tester.takeException(), isNull);
  });
}
