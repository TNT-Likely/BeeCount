// 交易同步 apply 路径的 D6「缺键保留」语义测试。
//
// 场景:本地已有一条 excludeFromStats=true 的交易(已上 syncId)。远端推来
// 同 syncId 的 upsert change,只改 amount,payload 里**省略** excludeFromStats
// 键(模拟老客户端 / 不带该字段的同步包)。apply 后:
//   - amount 必须更新
//   - excludeFromStats 必须仍为 true(不能被静默清掉)
//
// 这条用 engine.pull('') 走真实 applyRemoteChange seam(public 入口),
// FakeBeeCountCloudProvider.pushFakeChange 注入远端 change。

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' show Value;

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';

import '../cloud/sync/_fakes/fake_beecount_cloud_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late ChangeTracker changeTracker;
  late LocalRepository repo;
  late FakeBeeCountCloudProvider provider;
  late SyncEngine engine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    changeTracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: changeTracker);
    provider = FakeBeeCountCloudProvider();
    engine = SyncEngine(
      db: db,
      provider: provider,
      changeTracker: changeTracker,
      repo: repo,
    );
  });

  tearDown(() async => db.close());

  Future<int> seedLedger() {
    return db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: '测试账本',
          monthStartDay: const Value(1),
        ));
  }

  test('(D6) 远端 upsert 省略 excludeFromStats 键 → 本地 true 仍保留', () async {
    final lid = await seedLedger();
    const txSyncId = 'tx-exclude-1';

    // 本地先建一条 excludeFromStats=true 的交易(带固定 syncId)
    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 100,
      happenedAt: DateTime(2026, 6, 18),
      syncId: txSyncId,
      excludeFromStats: true,
      excludeFromBudget: false,
    );

    // 远端推同 syncId 的 upsert，只改 amount，**不带** excludeFromStats 键
    provider.pushFakeChange(
      entityType: 'transaction',
      entitySyncId: txSyncId,
      ledgerId: '$lid',
      payload: {
        'syncId': txSyncId,
        'type': 'expense',
        'amount': 250,
        'happenedAt': '2026-06-18T00:00:00Z',
        // 注意:故意省略 excludeFromStats / excludeFromBudget
      },
    );

    await engine.pull('');

    final tx = await repo.getTransactionBySyncId(txSyncId);
    expect(tx, isNotNull);
    expect(tx!.amount, 250, reason: 'amount 应被远端更新');
    expect(tx.excludeFromStats, true,
        reason: '缺键不应清空本地已有的 excludeFromStats(D6)');
  });

  test('(D6) 远端 upsert 显式 excludeFromStats=false → 覆盖本地 true', () async {
    final lid = await seedLedger();
    const txSyncId = 'tx-exclude-2';

    await repo.addTransaction(
      ledgerId: lid,
      type: 'expense',
      amount: 100,
      happenedAt: DateTime(2026, 6, 18),
      syncId: txSyncId,
      excludeFromStats: true,
      excludeFromBudget: true,
    );

    // 远端显式把两个标记都置 false → 应覆盖本地
    provider.pushFakeChange(
      entityType: 'transaction',
      entitySyncId: txSyncId,
      ledgerId: '$lid',
      payload: {
        'syncId': txSyncId,
        'type': 'expense',
        'amount': 100,
        'happenedAt': '2026-06-18T00:00:00Z',
        'excludeFromStats': false,
        'excludeFromBudget': false,
      },
    );

    await engine.pull('');

    final tx = await repo.getTransactionBySyncId(txSyncId);
    expect(tx, isNotNull);
    expect(tx!.excludeFromStats, false, reason: '显式 false 应覆盖本地 true');
    expect(tx.excludeFromBudget, false, reason: '显式 false 应覆盖本地 true');
  });

  test('(insert) 远端新增带 excludeFromBudget=true → 本地插入保留', () async {
    final lid = await seedLedger();
    const txSyncId = 'tx-exclude-3';

    provider.pushFakeChange(
      entityType: 'transaction',
      entitySyncId: txSyncId,
      ledgerId: '$lid',
      payload: {
        'syncId': txSyncId,
        'type': 'expense',
        'amount': 50,
        'happenedAt': '2026-06-18T00:00:00Z',
        'excludeFromStats': false,
        'excludeFromBudget': true,
      },
    );

    await engine.pull('');

    final tx = await repo.getTransactionBySyncId(txSyncId);
    expect(tx, isNotNull);
    expect(tx!.excludeFromStats, false);
    expect(tx.excludeFromBudget, true);
  });
}
