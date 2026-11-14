import 'package:beecount_business_ui/beecount_business_ui.dart' as business;
import 'package:beecount_business_ui/transaction_detail.dart' as detail;
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('专题与根公开入口保持相同的交易模型身份', () {
    const business.BeeTagData tag =
        detail.BeeTagData('work', '工作', Colors.amber);
    const business.BeeTransactionKind kind = detail.BeeTransactionKind.expense;
    const business.BeeAttachment attachment = detail.BeeAttachment(
        id: 'receipt',
        label: '小票',
        image: AssetImage('synthetic.png'),
        info: '128 KB');
    expect(tag.label, '工作');
    expect(kind, business.BeeTransactionKind.expense);
    expect(attachment.id, 'receipt');
  });

  testWidgets('首页和账本汇总在拆分后共用完整指标布局', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: applyBeeCardTheme(ThemeData()),
        home: Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
          const business.BeeSummaryCard(
              title: '日常账本',
              amount: '3286.50',
              incomeLabel: '本月收入',
              income: '12000.00',
              expenseLabel: '本月结余',
              expense: '8713.50'),
          business.BeeLedgerCard(
              name: '家庭账本',
              subtitle: '共享账本',
              icon: const Icon(Icons.book),
              income: '6000.00',
              expense: '2400.00',
              incomeLabel: '账本收入',
              expenseLabel: '账本支出',
              currentLabel: '当前账本',
              onSelect: () {},
              onMenu: () {})
        ])))));
    await tester.pump();
    for (final value in [
      '本月收入',
      '12000.00',
      '本月结余',
      '8713.50',
      '账本收入',
      '6000.00',
      '账本支出',
      '2400.00'
    ]) {
      expect(find.text(value), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
