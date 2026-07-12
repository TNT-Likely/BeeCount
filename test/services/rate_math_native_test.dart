/// computeNativeAmount(交易级多币种):amount × rate(1 账户币种 = rate 本位币)。
/// 同币种 → amount;缺失/非法 rate → null(L8 红线,绝不静默 1.0)。
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/services/currency/rate_math.dart';

void main() {
  test('账户币种==本位币 → 返回 amount(rate 1,不查表)', () {
    expect(
      computeNativeAmount(
          amount: 100, accountCurrency: 'CNY', ledgerBase: 'CNY', rates: {}),
      100,
    );
    // 大小写不敏感
    expect(
      computeNativeAmount(
          amount: 50, accountCurrency: 'usd', ledgerBase: 'USD', rates: {}),
      50,
    );
  });

  test('外币按 rate 折算(1 USD = 7.2 CNY)', () {
    final rates = {
      'USD': const EffectiveRate(rate: '7.2', manual: false, rateDate: '2026-07-10'),
    };
    expect(
      computeNativeAmount(
          amount: 12, accountCurrency: 'USD', ledgerBase: 'CNY', rates: rates),
      closeTo(86.4, 1e-9),
    );
  });

  test('缺失汇率 → null(L8,要求手填)', () {
    expect(
      computeNativeAmount(
          amount: 12, accountCurrency: 'USD', ledgerBase: 'CNY', rates: {}),
      isNull,
    );
  });

  test('非法/非正 rate → null(不入脏数据)', () {
    expect(
      computeNativeAmount(
          amount: 12,
          accountCurrency: 'USD',
          ledgerBase: 'CNY',
          rates: {'USD': const EffectiveRate(rate: 'abc', manual: true)}),
      isNull,
    );
    expect(
      computeNativeAmount(
          amount: 12,
          accountCurrency: 'USD',
          ledgerBase: 'CNY',
          rates: {'USD': const EffectiveRate(rate: '0', manual: true)}),
      isNull,
    );
  });
}
