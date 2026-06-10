// v28 schema 契约:两张多币种表可写可读;override 币对唯一索引生效。
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';

void main() {
  late BeeDatabase db;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('exchange_rates 主键 (base,quote,date) upsert 幂等', () async {
    final row = ExchangeRatesCompanion.insert(
      baseCurrency: 'CNY',
      quoteCurrency: 'USD',
      rateDate: '2026-06-10',
      rate: '7.2034',
      source: 'fawazahmed0',
      fetchedAt: DateTime.utc(2026, 6, 10),
    );
    await db.into(db.exchangeRates).insertOnConflictUpdate(row);
    await db.into(db.exchangeRates).insertOnConflictUpdate(
        row.copyWith(rate: const d.Value('7.30')));
    final all = await db.select(db.exchangeRates).get();
    expect(all.length, 1);
    expect(all.first.rate, '7.30');
  });

  test('exchange_rates 不同日期同币对可共存(rateDate 属主键)', () async {
    ExchangeRatesCompanion mk(String date) => ExchangeRatesCompanion.insert(
          baseCurrency: 'CNY',
          quoteCurrency: 'USD',
          rateDate: date,
          rate: '7.2',
          source: 'fawazahmed0',
          fetchedAt: DateTime.utc(2026, 6, 10),
        );
    await db.into(db.exchangeRates).insert(mk('2026-06-10'));
    await db.into(db.exchangeRates).insert(mk('2026-06-11'));
    expect((await db.select(db.exchangeRates).get()).length, 2);
  });

  test('exchange_rate_overrides 同币对唯一索引拦截重复插入', () async {
    ExchangeRateOverridesCompanion mk(String rate) =>
        ExchangeRateOverridesCompanion.insert(
          baseCurrency: 'CNY',
          quoteCurrency: 'USD',
          rate: rate,
          syncId: const d.Value('rate-a'),
          updatedAt: d.Value(DateTime.utc(2026, 6, 10)),
        );
    await db.into(db.exchangeRateOverrides).insert(mk('7.2'));
    expect(
      () => db.into(db.exchangeRateOverrides).insert(mk('7.5')),
      throwsA(isA<SqliteException>()),
    );
  });
}
