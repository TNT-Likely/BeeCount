import 'package:beecount/ai/core/bill_info.dart';
import 'package:beecount/services/ai/bill_card_info_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('转账账单卡片保留账户路径、标签和币种', () {
    final bill = buildBillCardInfoFromTransaction(
      amount: 88,
      time: DateTime(2026, 9, 6, 9, 30),
      transactionType: 'transfer',
      ledgerId: 1,
      fromAccount: '支付宝',
      toAccount: '储蓄卡',
      tags: const ['差旅'],
      currency: 'USD',
    );

    expect(bill.type, BillType.transfer);
    expect(bill.account, isNull);
    expect(bill.fromAccount, '支付宝');
    expect(bill.toAccount, '储蓄卡');
    expect(bill.tags, ['差旅']);
    expect(bill.currency, 'USD');
  });

  test('收入账单卡片保留单一账户和分类', () {
    final bill = buildBillCardInfoFromTransaction(
      amount: 128,
      time: DateTime(2026, 9, 6),
      transactionType: 'income',
      ledgerId: 1,
      category: '工资',
      account: '银行卡',
      currency: 'CNY',
    );

    expect(bill.type, BillType.income);
    expect(bill.category, '工资');
    expect(bill.account, '银行卡');
    expect(bill.fromAccount, isNull);
    expect(bill.toAccount, isNull);
  });
}
