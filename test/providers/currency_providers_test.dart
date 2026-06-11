// 多币种 provider 层纯逻辑单测(不打网络)。
// 覆盖两个纯逻辑触点:
//   ① baseCurrencyInitProvider 的初始化优先级(prefs 兜底链 selected_currency)
//   ② multiCurrencyActiveProvider 的总闸(币种数 ≥2 即恒折算,折算开关已下线)
//
// 拉取链 refreshExchangeRates / effectiveRates 走 IO,不在这里测(由 service /
// repository 层各自的测试覆盖)。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart' show Ledger;
import 'package:beecount/providers/currency_providers.dart';
import 'package:beecount/providers/database_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('baseCurrencyInitProvider 初始化优先级', () {
    test('无 baseCurrency 时按 selected_currency 兜底,并写回 prefs', () async {
      SharedPreferences.setMockInitialValues({
        'selected_currency': 'USD',
        // 故意不放 baseCurrency,触发兜底链 ①
      });
      final container = ProviderContainer(overrides: [
        // baseCurrencyInitProvider 在 selected_currency 命中时不会读 ledger,
        // 但 currentLedgerProvider 依赖真实 db,这里 stub 掉防止实例化。
        currentLedgerProvider.overrideWith((ref) => Stream<Ledger?>.value(null)),
      ]);
      addTearDown(container.dispose);

      // 触发初始化
      await container.read(baseCurrencyInitProvider.future);

      // provider 已落定为大写 USD
      expect(container.read(baseCurrencyProvider), 'USD');
      // prefs 已写回
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('baseCurrency'), 'USD');
    });

    test('已有 baseCurrency 时直接采用(归一大写),不读 selected_currency', () async {
      SharedPreferences.setMockInitialValues({
        'baseCurrency': 'jpy',
        'selected_currency': 'USD', // 应被忽略
      });
      final container = ProviderContainer(overrides: [
        currentLedgerProvider.overrideWith((ref) => Stream<Ledger?>.value(null)),
      ]);
      addTearDown(container.dispose);

      await container.read(baseCurrencyInitProvider.future);

      expect(container.read(baseCurrencyProvider), 'JPY');
    });
  });

  group('multiCurrencyActiveProvider 总闸(折算开关已下线,≥2 币种恒折算)', () {
    Future<bool> evaluate({required Set<String> used}) async {
      final container = ProviderContainer(overrides: [
        usedCurrenciesProvider.overrideWith((ref) => Future.value(used)),
      ]);
      addTearDown(container.dispose);
      // 等 FutureProvider 解析完成,multiCurrencyActiveProvider 才能读到 valueOrNull
      await container.read(usedCurrenciesProvider.future);
      return container.read(multiCurrencyActiveProvider);
    }

    test('单币种 → false', () async {
      expect(await evaluate(used: {'CNY'}), isFalse);
    });

    test('双币种 → 恒为 true(无需开关)', () async {
      expect(await evaluate(used: {'CNY', 'USD'}), isTrue);
    });

    test('三币种 → true', () async {
      expect(await evaluate(used: {'CNY', 'USD', 'JPY'}), isTrue);
    });
  });
}
