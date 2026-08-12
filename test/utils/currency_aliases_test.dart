import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/utils/currency_aliases.dart';

/// 智能记账多币种(.docs/multi-currency-ai A4)——口语/符号 → ISO 4217。
///
/// 最重要的一组断言是**歧义符号不猜**:`$` / `¥` 在没有上下文时必须返回 null,
/// 宁可退回账本本位币,也不能把一笔 JPY 记成 CNY(记错币种比不识别贵得多)。
void main() {
  group('ISO 码直通', () {
    test('大小写与空白归一', () {
      expect(currencyCodeFromAlias('USD'), 'USD');
      expect(currencyCodeFromAlias('usd'), 'USD');
      expect(currencyCodeFromAlias('  jpy '), 'JPY');
    });

    test('未知三字母不当作 ISO 码放行', () {
      expect(currencyCodeFromAlias('XYZ'), isNull);
      expect(currencyCodeFromAlias('ZZZ'), isNull);
    });
  });

  group('中文别名', () {
    test('无歧义的常见币种', () {
      expect(currencyCodeFromAlias('美元'), 'USD');
      expect(currencyCodeFromAlias('美金'), 'USD');
      expect(currencyCodeFromAlias('日元'), 'JPY');
      expect(currencyCodeFromAlias('日圆'), 'JPY');
      expect(currencyCodeFromAlias('欧元'), 'EUR');
      expect(currencyCodeFromAlias('英镑'), 'GBP');
      expect(currencyCodeFromAlias('港币'), 'HKD');
      expect(currencyCodeFromAlias('新台币'), 'TWD');
      expect(currencyCodeFromAlias('韩元'), 'KRW');
      expect(currencyCodeFromAlias('泰铢'), 'THB');
      expect(currencyCodeFromAlias('人民币'), 'CNY');
    });

    test('繁体也认', () {
      expect(currencyCodeFromAlias('日圓'), 'JPY');
      expect(currencyCodeFromAlias('歐元'), 'EUR');
      expect(currencyCodeFromAlias('人民幣'), 'CNY');
    });

    test('歧义中文词不猜', () {
      // 卢比:INR / PKR / LKR / NPR / IDR 都叫卢比;比索:PHP / MXN / ARS…
      expect(currencyCodeFromAlias('卢比'), isNull);
      expect(currencyCodeFromAlias('比索'), isNull);
    });

    test('歧义中文词可被上下文消歧', () {
      expect(
        currencyCodeFromAlias('卢比', disambiguateWith: {'CNY', 'INR'}),
        'INR',
      );
      // 上下文里同时有两个候选 → 仍然不猜
      expect(
        currencyCodeFromAlias('卢比', disambiguateWith: {'INR', 'PKR'}),
        isNull,
      );
    });
  });

  group('英文名', () {
    test('全名(来自 currencies.dart 的 151 币种表,大小写无关)', () {
      expect(currencyCodeFromAlias('US Dollar'), 'USD');
      expect(currencyCodeFromAlias('japanese yen'), 'JPY');
      expect(currencyCodeFromAlias('Euro'), 'EUR');
    });

    test('单词 yen / euro 无歧义', () {
      expect(currencyCodeFromAlias('yen'), 'JPY');
      expect(currencyCodeFromAlias('euro'), 'EUR');
    });

    test('dollar 有歧义 → 不猜,除非上下文能定', () {
      expect(currencyCodeFromAlias('dollar'), isNull);
      expect(currencyCodeFromAlias('dollars'), isNull);
      expect(
        currencyCodeFromAlias('dollar', disambiguateWith: {'CNY', 'USD'}),
        'USD',
      );
      expect(
        currencyCodeFromAlias('dollar', disambiguateWith: {'USD', 'HKD'}),
        isNull,
      );
    });
  });

  group('符号', () {
    test('无歧义符号直接映射', () {
      expect(currencyCodeFromAlias('€'), 'EUR');
      expect(currencyCodeFromAlias('£'), 'GBP');
      expect(currencyCodeFromAlias('₩'), 'KRW');
      expect(currencyCodeFromAlias('฿'), 'THB');
    });

    test('带前缀的美元符号无歧义', () {
      expect(currencyCodeFromAlias(r'US$'), 'USD');
      expect(currencyCodeFromAlias(r'HK$'), 'HKD');
      expect(currencyCodeFromAlias(r'NT$'), 'TWD');
    });

    test('RMB 这种非 ISO 但常见的写法', () {
      expect(currencyCodeFromAlias('RMB'), 'CNY');
      expect(currencyCodeFromAlias('rmb'), 'CNY');
    });

    test(r'裸 ¥ 是真歧义(CNY/JPY 都写裸 ¥),无上下文不猜 —— 本文件最关键的一条',
        () {
      expect(currencyCodeFromAlias('¥'), isNull);
      expect(currencyCodeFromAlias('￥'), isNull);
    });

    test(r'裸 $ 默认 USD(要区分 AUD/CAD/… 时惯例写 A$/C$/…)', () {
      // AI 识别出「45 美元」却常把 currency 回成 "$";一律丢弃会让美元记账失效
      expect(currencyCodeFromAlias(r'$'), 'USD');
      expect(currencyCodeFromAlias(r'$', disambiguateWith: {'USD', 'HKD'}), 'USD');
    });

    test('歧义符号可被上下文消歧', () {
      expect(
        currencyCodeFromAlias('¥', disambiguateWith: {'CNY', 'JPY'}),
        isNull, // 两个候选都在场 → 仍不猜
      );
      expect(
        currencyCodeFromAlias('¥', disambiguateWith: {'USD', 'JPY'}),
        'JPY',
      );
    });
  });

  group('健壮性', () {
    test('空/无关输入返 null,不抛', () {
      expect(currencyCodeFromAlias(''), isNull);
      expect(currencyCodeFromAlias('   '), isNull);
      expect(currencyCodeFromAlias('喵喵喵'), isNull);
      expect(currencyCodeFromAlias('12345'), isNull);
    });

    test('isKnownCurrencyCode', () {
      expect(isKnownCurrencyCode('usd'), isTrue);
      expect(isKnownCurrencyCode('KES'), isTrue); // #273 扩到全量 ISO 后新增
      expect(isKnownCurrencyCode('XYZ'), isFalse);
      expect(isKnownCurrencyCode(''), isFalse);
    });
  });
}
