// rate_math 契约:手动优先;缺失显式缺失(绝无 1.0 回落,README D5);
// 折算剔除缺失币种并列名;base 自身 =1;脚注取参与折算的最旧日期。
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/services/currency/rate_math.dart';

void main() {
  test('invertRate 12 位有效数字', () {
    expect(invertRate(0.1477), '6.77048070413');
    expect(() => invertRate(0), throwsArgumentError);
    expect(() => invertRate(-1), throwsArgumentError);
  });

  test('mergeEffectiveRates 手动覆盖自动,缺失就是缺失', () {
    final m = mergeEffectiveRates(
      autoRates: [
        (quote: 'USD', rate: '7.20', rateDate: '2026-06-10'),
        (quote: 'JPY', rate: '0.048', rateDate: '2026-06-09'),
      ],
      overrides: [(quote: 'USD', rate: '7.50')],
    );
    expect(m['USD']!.rate, '7.50');
    expect(m['USD']!.manual, isTrue);
    expect(m['JPY']!.manual, isFalse);
    expect(m['JPY']!.rateDate, '2026-06-09');
    expect(m.containsKey('KRW'), isFalse);
  });

  test('computeConvertedNetWorth 折算 + 缺失剔除 + 最旧日期', () {
    final r = computeConvertedNetWorth(
      breakdown: {
        'CNY': (totalAssets: 8000.0, totalLiabilities: 2200.0, netWorth: 5800.0),
        'USD': (totalAssets: 1000.0, totalLiabilities: 0.0, netWorth: 1000.0),
        'KRW': (totalAssets: 500000.0, totalLiabilities: 0.0, netWorth: 500000.0),
      },
      rates: {
        'USD': const EffectiveRate(rate: '7.20', manual: false, rateDate: '2026-06-10'),
      },
      base: 'CNY',
    );
    expect(r.netWorth, closeTo(5800 + 7200, 0.001));
    expect(r.totalAssets, closeTo(8000 + 7200, 0.001));
    expect(r.totalLiabilities, closeTo(2200, 0.001));
    expect(r.netByCurrency['USD'], closeTo(7200, 0.001));
    expect(r.missingCurrencies, ['KRW']); // 绝不按 1.0 折算
    expect(r.oldestRateDate, '2026-06-10');
  });

  test('convertAmountsToBase 混合:可折算累加 + 缺失剔除并列名', () {
    final r = convertAmountsToBase(
      amounts: {'CNY': 5800.0, 'USD': 1000.0, 'KRW': 500000.0},
      rates: {
        'USD': const EffectiveRate(rate: '7.20', manual: false, rateDate: '2026-06-10'),
      },
      base: 'CNY',
    );
    // CNY 自身 1.0 + USD 7200,KRW 无汇率被剔除
    expect(r.total, closeTo(5800 + 7200, 0.001));
    expect(r.convertedByCurrency['CNY'], closeTo(5800, 0.001));
    expect(r.convertedByCurrency['USD'], closeTo(7200, 0.001));
    expect(r.convertedByCurrency.containsKey('KRW'), isFalse);
    expect(r.missingCurrencies, ['KRW']); // 绝不按 1.0 折算
  });

  test('convertAmountsToBase base 自身 rate=1,大小写归一', () {
    final r = convertAmountsToBase(
      amounts: {'usd': 100.0},
      rates: const {},
      base: 'usd',
    );
    expect(r.total, closeTo(100, 0.001));
    expect(r.convertedByCurrency['USD'], closeTo(100, 0.001));
    expect(r.missingCurrencies, isEmpty);
  });

  test('rate 解析失败的币种进 missing,且其日期不计入 oldest', () {
    final r = computeConvertedNetWorth(
      breakdown: {
        'USD': (totalAssets: 100.0, totalLiabilities: 0.0, netWorth: 100.0),
      },
      rates: {
        'USD': const EffectiveRate(rate: 'bad', manual: false, rateDate: '2020-01-01'),
      },
      base: 'CNY',
    );
    expect(r.missingCurrencies, ['USD']);
    expect(r.oldestRateDate, isNull);
  });
}
