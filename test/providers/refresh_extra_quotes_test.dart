/// v30 记账页手选币种的汇率拉取(L12 配套):
/// 手选币种不在 usedCurrencies(账户币种∪主币种)里,常规 refresh 拉回的组
/// 永远没有它 —— refreshExchangeRates 的 extraQuotes 参数把它并入拉取集合。
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/providers/currency_providers.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/services/currency/exchange_rate_service.dart';

/// 假汇率源:固定返回 CNY 基准的几个币种(不打网络)。
class _FakeRateService implements ExchangeRateService {
  int fetchCount = 0;
  @override
  Future<RateFetchResult> fetch(String base) async {
    fetchCount++;
    return const RateFetchResult(
      rateDate: '2026-07-12',
      source: 'fake',
      ratesBaseToQuote: {'USD': '0.139', 'JPY': '20.5', 'EUR': '0.127'},
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  test('extraQuotes:手选币种(JPY)不在使用中币种里,refresh 后其汇率被落库', () async {
    // 单币种环境:无账户、主币种 CNY(usedCurrencies={CNY},常规 refresh 会
    // 因 usedAll<2 直接跳过 —— extraQuotes 撑起集合并把 JPY 带进拉取)。
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    final fake = _FakeRateService();
    final container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      exchangeRateServiceProvider.overrideWithValue(fake),
      usedCurrenciesProvider.overrideWith((ref) => Future.value({'CNY'})),
      // beecountCloudProviderInstance 走真实 provider 链会因未配置返回 null →
      // 下滑到 exchangeRateServiceProvider(fake),正好覆盖公网链路径。
    ]);
    addTearDown(container.dispose);

    final ok = await refreshExchangeRates(
      _RefLike(container),
      force: true,
      extraQuotes: {'JPY'},
    );
    expect(ok, isTrue);
    expect(fake.fetchCount, greaterThan(0));

    final rates = await repo.getLatestAutoRates('CNY');
    final quotes = rates.map((r) => r.quoteCurrency).toSet();
    expect(quotes, contains('JPY'),
        reason: 'extraQuotes 的币种必须进入拉取并落库');
  });
}

/// refreshExchangeRates 需要 Ref;测试里用 ProviderContainer 适配出
/// read / readFuture 两个能力(与 Ref 等价)。
class _RefLike implements Ref {
  final ProviderContainer container;
  _RefLike(this.container);

  @override
  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
