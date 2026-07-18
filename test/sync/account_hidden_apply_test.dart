// 账户隐藏(issue #240)同步 apply 路径的 D6「缺键保留」语义测试。
//
// 场景:本地已有一条 hidden=true 的账户(已上 syncId)。远端推来同 syncId 的
// upsert change,只改 name，payload 里**省略** hidden 键（模拟旧客户端/不带
// 该字段的同步包）。apply 后：
//   - name 必须更新
//   - hidden 必须仍为 true（不能被静默清掉）
//
// ⚠️ 账户 apply(`_applyAccountChange`)现有逻辑对 name/type 等字段是**无条件
// 覆盖**（不像交易 flags 已有 containsKey 保护），若 hidden 也无条件覆盖，
// 一条「只改名字、payload 不带 hidden」的远端 partial 更新就会把本地已隐藏
// 抹成 false —— 这是本测试要钉住的回归点。
//
// 这条用 engine.pull('') 走真实 applyRemoteChange seam(public 入口），跟
// test/sync/transaction_exclude_flags_apply_test.dart 同款范式，
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

  test('(D6) 远端 upsert 省略 hidden 键 → 本地 true 仍保留', () async {
    final lid = await seedLedger();
    const accountSyncId = 'ax-hidden-1';

    // 本地先建一条 hidden=true 的账户(带固定 syncId)
    final aid = await repo.createAccount(
      ledgerId: lid,
      name: 'A',
      syncId: accountSyncId,
    );
    await repo.setAccountHidden(aid, true);

    // 远端推同 syncId 的 upsert，只改 name，**不带** hidden 键
    provider.pushFakeChange(
      entityType: 'account',
      entitySyncId: accountSyncId,
      ledgerId: '$lid',
      payload: {
        'syncId': accountSyncId,
        'name': 'A-renamed',
        'type': 'cash',
        'currency': 'CNY',
        'initialBalance': 0.0,
        'sortOrder': 0,
        // 注意:故意省略 hidden
      },
    );

    await engine.pull('');

    final a = await (db.select(db.accounts)
          ..where((t) => t.syncId.equals(accountSyncId)))
        .getSingle();
    expect(a.name, 'A-renamed', reason: 'name 应被远端更新');
    expect(a.hidden, true, reason: '缺键不应清空本地已有的 hidden(D6)');
  });

  test('(D6) 远端 upsert 显式 hidden=false → 覆盖本地 true', () async {
    final lid = await seedLedger();
    const accountSyncId = 'ax-hidden-2';

    final aid = await repo.createAccount(
      ledgerId: lid,
      name: 'A',
      syncId: accountSyncId,
    );
    await repo.setAccountHidden(aid, true);

    // 远端显式把 hidden 置 false → 应覆盖本地
    provider.pushFakeChange(
      entityType: 'account',
      entitySyncId: accountSyncId,
      ledgerId: '$lid',
      payload: {
        'syncId': accountSyncId,
        'name': 'A',
        'type': 'cash',
        'currency': 'CNY',
        'initialBalance': 0.0,
        'sortOrder': 0,
        'hidden': false,
      },
    );

    await engine.pull('');

    final a = await (db.select(db.accounts)
          ..where((t) => t.syncId.equals(accountSyncId)))
        .getSingle();
    expect(a.hidden, false, reason: '显式 false 应覆盖本地 true');
  });

  test('(insert) 远端新增账户带 hidden=true → 本地插入保留', () async {
    final lid = await seedLedger();
    const accountSyncId = 'ax-hidden-3';

    provider.pushFakeChange(
      entityType: 'account',
      entitySyncId: accountSyncId,
      ledgerId: '$lid',
      payload: {
        'syncId': accountSyncId,
        'name': 'B',
        'type': 'cash',
        'currency': 'CNY',
        'initialBalance': 0.0,
        'sortOrder': 0,
        'hidden': true,
      },
    );

    await engine.pull('');

    final a = await (db.select(db.accounts)
          ..where((t) => t.syncId.equals(accountSyncId)))
        .getSingle();
    expect(a.hidden, true);
  });

  test('(insert) 远端新增账户缺 hidden 键 → 本地插入默认 false', () async {
    final lid = await seedLedger();
    const accountSyncId = 'ax-hidden-4';

    provider.pushFakeChange(
      entityType: 'account',
      entitySyncId: accountSyncId,
      ledgerId: '$lid',
      payload: {
        'syncId': accountSyncId,
        'name': 'C',
        'type': 'cash',
        'currency': 'CNY',
        'initialBalance': 0.0,
        'sortOrder': 0,
        // 注意:故意省略 hidden
      },
    );

    await engine.pull('');

    final a = await (db.select(db.accounts)
          ..where((t) => t.syncId.equals(accountSyncId)))
        .getSingle();
    expect(a.hidden, false);
  });
}
