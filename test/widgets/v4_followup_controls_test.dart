import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/shared/pickers/wheel_date_picker.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child) => MaterialApp(
    theme: beeTheme(),
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child));
void main() {
  for (final width in [320.0, 398.0]) {
    testWidgets('账户原币余额左对齐，长金额与大字不溢出 $width', (t) async {
      t.view.physicalSize = Size(width, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      for (final amount in ['320.50', '-999,999,999.99']) {
        await t.pumpWidget(app(MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
            child: Padding(
                padding: const EdgeInsets.all(17),
                child: BeeAccountSummaryCard(
                    title: '美元账户',
                    caption: '现金 · USD',
                    icon: const Icon(Icons.wallet),
                    balanceLabel: '余额',
                    amount: amount,
                    prefix: 'US\$',
                    currency: 'USD',
                    properties: const [])))));
        final text = find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().contains(amount));
        expect(t.getTopLeft(text).dx, closeTo(35, 1));
        expect(t.takeException(), isNull);
      }
    });
  }
  testWidgets('日期时间新弹层保留两步与秒精度，确认按钮整行', (t) async {
    DateTime? result;
    final initial = DateTime(2026, 10, 28, 12, 34, 56);
    await t.pumpWidget(app(Builder(
        builder: (context) => TextButton(
            onPressed: () async {
              result = await showWheelDateTimePicker(context, initial: initial);
            },
            child: const Text('日期')))));
    await t.tap(find.text('日期'));
    await t.pumpAndSettle();
    expect(find.byType(BeeSheet), findsOneWidget);
    expect(t.getSize(find.widgetWithText(BeeButton, '下一步')).width,
        greaterThan(300));
    await t.tap(find.text('下一步'));
    await t.pumpAndSettle();
    expect(find.byType(BeeTimeWheels), findsOneWidget);
    expect(t.widget<BeeTimeWheels>(find.byType(BeeTimeWheels)).second, 56);
    await t.tap(find.widgetWithText(BeeButton, '确定'));
    await t.pumpAndSettle();
    expect(result, initial);
    await t.tap(find.text('日期'));
    await t.pumpAndSettle();
    await t.tap(find.byType(CloseButton).last);
    await t.pumpAndSettle();
    expect(result, isNull);
  });
  testWidgets('日期边界限制年月日并保留闰年修正', (t) async {
    var value = DateTime(2024, 2, 29);
    await t.pumpWidget(app(StatefulBuilder(
        builder: (context, update) => BeeDateWheels(
            value: value,
            minimum: DateTime(2024, 2, 10),
            maximum: DateTime(2025, 3, 2),
            onChanged: (v) => update(() => value = v)))));
    var wheels =
        t.widgetList<BeeWheel<int>>(find.byType(BeeWheel<int>)).toList();
    expect(wheels.first.values, [2024, 2025]);
    expect(wheels[1].values.first, 2);
    expect(wheels[2].values.first, 10);
    wheels.first.onChanged(2025);
    await t.pump();
    expect(value, DateTime(2025, 2, 28));
    wheels = t.widgetList<BeeWheel<int>>(find.byType(BeeWheel<int>)).toList();
    expect(wheels[1].values.last, 3);
    wheels[1].onChanged(3);
    await t.pump();
    expect(value, DateTime(2025, 3, 2));
    expect(t.takeException(), isNull);
  });
  testWidgets('账户流水筛选选择有草稿，取消不提交，确认铺满宽度', (t) async {
    var applied = false, flow = 'all', sort = 'timeDesc';
    await t.pumpWidget(app(Builder(
        builder: (context) => TextButton(
            onPressed: () => showBeeSheet<void>(context,
                title: '筛选流水',
                child: StatefulBuilder(
                    builder: (ctx, update) => BeeAccountFlowFilter(
                        flow: flow,
                        sort: sort,
                        sortLabel: '排序',
                        flows: const [
                          BeeSegment('all', '全部'),
                          BeeSegment('expense', '支出'),
                          BeeSegment('income', '收入')
                        ],
                        sorts: const [
                          BeeSegment('timeDesc', '时间↓'),
                          BeeSegment('amountDesc', '金额↓')
                        ],
                        onFlowChanged: (v) => update(() => flow = v),
                        onSortChanged: (v) => update(() => sort = v),
                        confirmLabel: '确认',
                        onConfirm: () {
                          applied = true;
                          Navigator.pop(ctx);
                        }))),
            child: const Text('筛选')))));
    await t.tap(find.text('筛选'));
    await t.pumpAndSettle();
    await t.tap(find.text('支出'));
    await t.pump();
    expect(flow, 'expense');
    expect(applied, isFalse);
    await t.tap(find.byType(BeeSelectField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('金额↓'));
    await t.pumpAndSettle();
    expect(sort, 'amountDesc');
    expect(applied, isFalse);
    expect(t.getSize(find.widgetWithText(BeeButton, '确认')).width,
        greaterThan(300));
    await t.tap(find.text('确认'));
    await t.pumpAndSettle();
    expect(applied, isTrue);
    expect(t.takeException(), isNull);
  });
}
