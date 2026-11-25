// 账户「不计入总资产」(issue #651)— Repository 统计口径 + 同步 apply 测试。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/entity_serializer.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';

import '../cloud/sync/_fakes/fake_beecount_cloud_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late ChangeTracker tracker;
  late LocalRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
  });

  tearDown(() async => db.close());

  Future<({int lid, int excludedAsset, int excludedLoan})> seed() async {
    final lid = await repo.createLedger(name: 'L');
    await repo.createAccount(
        ledgerId: lid, name: 'Cash', type: 'cash', initialBalance: 1000);
    final excludedAsset = await repo.createAccount(
        ledgerId: lid,
        name: 'Tax',
        type: 'cash',
        initialBalance: 300,
        excludeFromTotal: true);
    final excludedLoan = await repo.createAccount(
        ledgerId: lid,
        name: 'Loan',
        type: 'loan',
        initialBalance: -200,
        excludeFromTotal: true);
    return (lid: lid, excludedAsset: excludedAsset, excludedLoan: excludedLoan);
  }

  test('净资产 / 按币种 / 资产构成 均跳过不计入账户(资产与负债)', () async {
    final s = await seed();

    final net = await repo.getNetWorthBreakdown();
    expect(net.totalAssets, 1000);
    expect(net.totalLiabilities, 0);
    expect(net.netWorth, 1000);

    final byCurrency = await repo.getNetWorthBreakdownByCurrency();
    expect(byCurrency['CNY']!.netWorth, 1000);

    final composition = await repo.getAssetCompositionByType();
    expect(composition.single.totalBalance, 1000);
    final byTypeCurrency = await repo.getAssetCompositionByTypeAndCurrency();
    expect(byTypeCurrency.single.totalBalance, 1000);

    // 账户自身余额不受影响
    expect(await repo.getAccountBalance(s.excludedAsset), 300);
    expect(await repo.getAccountBalance(s.excludedLoan), -200);
  });

  test('净值趋势序列跳过不计入账户', () async {
    await seed();
    final today = DateTime.now();
    final series = await repo.getNetWorthTrendSeries(
        startDate: today, endDate: today, ratesToBase: {'CNY': 1.0});
    expect(series.last.assets, 1000);
    expect(series.last.liabilities, 0);
    final daily =
        await repo.getNetWorthDailyBalances(startDate: today, endDate: today);
    expect(daily.last.balance, 1000);
  });

  test('updateAccount 切换后统计随之变化,记 change,且只改 name 不动该标记', () async {
    final s = await seed();
    await repo.updateAccount(s.excludedAsset, excludeFromTotal: false);
    expect((await repo.getNetWorthBreakdown()).netWorth, 1300);

    final account = (await repo.getAccount(s.excludedAsset))!;
    final changes = await (db.select(db.localChanges)
          ..where((c) => c.entitySyncId.equals(account.syncId!))
          ..where((c) => c.action.equals('update')))
        .get();
    expect(changes, isNotEmpty);

    await repo.updateAccount(s.excludedLoan, name: 'Loan2');
    expect((await repo.getAccount(s.excludedLoan))!.excludeFromTotal, true);
    expect(
        EntitySerializer.serializeAccount(
            (await repo.getAccount(s.excludedLoan))!)['excludeFromTotal'],
        true);
  });

  group('同步 apply', () {
    late FakeBeeCountCloudProvider provider;
    late SyncEngine engine;

    setUp(() {
      provider = FakeBeeCountCloudProvider();
      engine = SyncEngine(
          db: db, provider: provider, changeTracker: tracker, repo: repo);
    });

    Future<Account> pullAccount(
        int lid, String syncId, Map<String, dynamic> extra) async {
      provider.pushFakeChange(
        entityType: 'account',
        entitySyncId: syncId,
        ledgerId: '$lid',
        payload: {
          'syncId': syncId,
          'name': 'A',
          'type': 'cash',
          'currency': 'CNY',
          'initialBalance': 0.0,
          'sortOrder': 0,
          ...extra,
        },
      );
      await engine.pull('');
      return (db.select(db.accounts)..where((t) => t.syncId.equals(syncId)))
          .getSingle();
    }

    Future<int> ledger() => db.into(db.ledgers).insert(
        LedgersCompanion.insert(name: 'L', monthStartDay: const Value(1)));

    test('远端缺键 → 保留本地 true;显式 false → 覆盖', () async {
      final lid = await ledger();
      await repo.createAccount(
          ledgerId: lid, name: 'A', syncId: 'ax-ex-1', excludeFromTotal: true);

      expect((await pullAccount(lid, 'ax-ex-1', {})).excludeFromTotal, true);
      expect(
          (await pullAccount(lid, 'ax-ex-1', {'excludeFromTotal': false}))
              .excludeFromTotal,
          false);
    });

    test('远端新增账户:带 true 落 true,缺键落 false', () async {
      final lid = await ledger();
      expect(
          (await pullAccount(lid, 'ax-ex-2', {'excludeFromTotal': true}))
              .excludeFromTotal,
          true);
      expect(
          (await pullAccount(lid, 'ax-ex-3', {'name': 'B'})).excludeFromTotal,
          false);
    });
  });
}
