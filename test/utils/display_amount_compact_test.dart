import 'package:beecount/widgets/biz/format_money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('简写数字与外层币种前缀独立，负金额不会重复带币种', () {
    expect(
        formatDisplayAmount(120000,
            currencyCode: 'CNY', useCompactFormat: true, signed: false),
        '12万');
    expect(
        formatDisplayAmount(-120000,
            currencyCode: 'CNY', useCompactFormat: true, signed: false),
        '-12万');
    expect(
        formatDisplayAmount(-1200000,
            currencyCode: 'USD',
            useCompactFormat: true,
            isChineseLocale: false,
            signed: false),
        '-1.2M');
    expect(
        formatDisplayAmount(-120000,
            currencyCode: 'CNY',
            useCompactFormat: true,
            showCurrency: true,
            signed: false),
        '-¥12万');
  });
}
