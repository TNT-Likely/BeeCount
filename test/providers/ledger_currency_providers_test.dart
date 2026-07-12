/// 交易级多币种 provider 层:
///   ① currentLedgerCurrencyProvider:账本本位币别名(大写/兜底 CNY)
///   ② effectiveRatesForLedgerProvider:以账本本位币为 base 合成有效汇率
///      (与 effectiveRatesProvider 的差异仅在 base 来源)
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/providers/currency_providers.dart';
import 'package:beecount/providers/database_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  Ledger ledgerWith(String currency) => Ledger(
        id: 1,
        name: 'L',
        currency: currency,
        type: 'personal',
        createdAt: DateTime(2026, 1, 1),
        myRole: 'owner',
        memberCount: 1,
        isShared: false,
        monthStartDay: 1,
      );

  test('currentLedgerCurrencyProvider:账本币种大写;无账本兜底 CNY', () async {
    final container = ProviderContainer(overrides: [
      currentLedgerProvider
          .overrideWith((ref) => Stream<Ledger?>.value(ledgerWith('usd'))),
    ]);
    addTearDown(container.dispose);
    await container.read(currentLedgerProvider.future);
    expect(container.read(currentLedgerCurrencyProvider), 'USD');

    final empty = ProviderContainer(overrides: [
      currentLedgerProvider.overrideWith((ref) => Stream<Ledger?>.value(null)),
    ]);
    addTearDown(empty.dispose);
    await empty.read(currentLedgerProvider.future);
    expect(empty.read(currentLedgerCurrencyProvider), 'CNY');
  });

  test('effectiveRatesForLedger 以账本本位币为 base(≠ 用户主币种)', () async {
    // 种两组汇率:base=CNY(主币种)与 base=USD(账本本位币)
    await repo.upsertAutoRates(
      base: 'CNY',
      rateDate: '2026-07-10',
      rates: {'USD': '7.2'},
      source: 'test',
      fetchedAt: DateTime.utc(2026, 7, 10),
    );
    await repo.upsertAutoRates(
      base: 'USD',
      rateDate: '2026-07-10',
      rates: {'CNY': '0.14', 'JPY': '0.0068'},
      source: 'test',
      fetchedAt: DateTime.utc(2026, 7, 10),
    );

    final container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      currentLedgerProvider
          .overrideWith((ref) => Stream<Ledger?>.value(ledgerWith('USD'))),
    ]);
    addTearDown(container.dispose);
    await container.read(currentLedgerProvider.future);
    // 主币种是 CNY,但账本本位币 USD → 应取 base=USD 的组
    container.read(baseCurrencyProvider.notifier).state = 'CNY';

    final rates =
        await container.read(effectiveRatesForLedgerProvider.future);
    expect(rates.keys, containsAll(['CNY', 'JPY']));
    expect(rates['CNY']!.rate, '0.14');
    expect(rates.containsKey('USD'), isFalse); // base 自身不在 quote 里
  });
}
