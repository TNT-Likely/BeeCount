// ExchangeRateRepository 契约:
//  - upsertAutoRates 同日覆盖、getLatestAutoRates 取每 quote 最新日期
//  - setOverride 按币对 upsert(复用 syncId)并记 user-global change;
//    removeOverride 记 delete change
//  - 自动汇率写入【绝不】记 change(防 sync_changes 膨胀回归,README D2)
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late ChangeTracker tracker;
  late LocalRepository repo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
  });

  tearDown(() async {
    await db.close();
  });

  test('upsertAutoRates 同日覆盖 + getLatestAutoRates 取最新日期,且不记 change', () async {
    await repo.upsertAutoRates(
      base: 'CNY', rateDate: '2026-06-09',
      rates: {'USD': '7.10', 'JPY': '0.047'},
      source: 'fawazahmed0', fetchedAt: DateTime.utc(2026, 6, 9),
    );
    await repo.upsertAutoRates(
      base: 'CNY', rateDate: '2026-06-10',
      rates: {'USD': '7.20'},
      source: 'frankfurter', fetchedAt: DateTime.utc(2026, 6, 10),
    );
    final latest = await repo.getLatestAutoRates('CNY');
    final usd = latest.firstWhere((r) => r.quoteCurrency == 'USD');
    final jpy = latest.firstWhere((r) => r.quoteCurrency == 'JPY');
    expect(usd.rate, '7.20');
    expect(usd.rateDate, '2026-06-10');
    expect(jpy.rate, '0.047'); // 06-10 没有 JPY → 最新仍是 06-09
    expect((await repo.getLastFetchedAt('CNY'))?.toUtc(),
        DateTime.utc(2026, 6, 10));
    expect(await tracker.getUnpushedChangesForLedger(0), isEmpty); // 红线
  });

  test('setOverride 币对 upsert 复用 syncId;removeOverride 记 delete', () async {
    await repo.setOverride(base: 'CNY', quote: 'USD', rate: '7.5');
    var rows = await repo.getOverrides('CNY');
    expect(rows.length, 1);
    final firstSyncId = rows.first.syncId;
    expect(firstSyncId, isNotNull);

    await repo.setOverride(base: 'CNY', quote: 'USD', rate: '7.8');
    rows = await repo.getOverrides('CNY');
    expect(rows.length, 1);
    expect(rows.first.rate, '7.8');
    expect(rows.first.syncId, firstSyncId);

    await repo.removeOverride(base: 'CNY', quote: 'USD');
    expect(await repo.getOverrides('CNY'), isEmpty);

    final changes = await tracker.getUnpushedChangesForLedger(0);
    expect(changes.map((c) => c.action).toList(), ['create', 'update', 'delete']);
    expect(changes.every((c) => c.entityType == 'exchange_rate_override'), isTrue);
    expect(changes.every((c) => c.ledgerId == 0), isTrue);
  });

  test('getUsedCurrencies 去重大写', () async {
    await db.into(db.accounts).insert(AccountsCompanion.insert(
        ledgerId: 1, name: 'A', currency: const d.Value('CNY')));
    await db.into(db.accounts).insert(AccountsCompanion.insert(
        ledgerId: 1, name: 'B', currency: const d.Value('usd')));
    expect(await repo.getUsedCurrencies(), {'CNY', 'USD'});
  });
}
