// _applyExchangeRateOverrideChange 按币对收敛 + LWW 语义测试。
//
// 覆盖三个断言:
// (1) upsert change → 表中一行 (CNY,USD,7.5,syncId=rate-x)
// (2) 同币对、不同 syncId(rate-y)第二条 upsert → 仍一行,rate/syncId 吸收为
//     新值(币对收敛,绕开 idx_rate_override_pair 唯一索引撞行)
// (3) delete change(entitySyncId=rate-y)→ 行删除

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';

import '_fakes/fake_beecount_cloud_provider.dart';

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

  group('_applyExchangeRateOverrideChange 按币对收敛', () {
    test('(1) upsert change → 表中一行 (CNY,USD,7.5,syncId=rate-x)', () async {
      provider.pushFakeChange(
        entityType: 'exchange_rate_override',
        entitySyncId: 'rate-x',
        payload: {
          'syncId': 'rate-x',
          'baseCurrency': 'CNY',
          'quoteCurrency': 'USD',
          'rate': '7.5',
          'updatedAt': '2026-06-10T00:00:00Z',
        },
      );

      await engine.pull('');

      final rows = await db.select(db.exchangeRateOverrides).get();
      expect(rows, hasLength(1));
      expect(rows.first.baseCurrency, 'CNY');
      expect(rows.first.quoteCurrency, 'USD');
      expect(rows.first.rate, '7.5');
      expect(rows.first.syncId, 'rate-x');
    });

    test('(2) 同币对、不同 syncId 的第二条 upsert → 仍一行,吸收新值', () async {
      // 第一条:CNY/USD = 7.5 (syncId=rate-x)
      provider.pushFakeChange(
        entityType: 'exchange_rate_override',
        entitySyncId: 'rate-x',
        payload: {
          'syncId': 'rate-x',
          'baseCurrency': 'CNY',
          'quoteCurrency': 'USD',
          'rate': '7.5',
          'updatedAt': '2026-06-10T00:00:00Z',
        },
      );
      // 第二条:同币对 CNY/USD,但 syncId=rate-y,rate=7.2(双端离线各建)
      provider.pushFakeChange(
        entityType: 'exchange_rate_override',
        entitySyncId: 'rate-y',
        payload: {
          'syncId': 'rate-y',
          'baseCurrency': 'CNY',
          'quoteCurrency': 'USD',
          'rate': '7.2',
          'updatedAt': '2026-06-10T01:00:00Z',
        },
      );

      await engine.pull('');

      final rows = await db.select(db.exchangeRateOverrides).get();
      expect(rows, hasLength(1), reason: '按币对收敛,不撞唯一索引');
      expect(rows.first.baseCurrency, 'CNY');
      expect(rows.first.quoteCurrency, 'USD');
      expect(rows.first.rate, '7.2', reason: 'rate 吸收为新值');
      expect(rows.first.syncId, 'rate-y', reason: 'syncId 吸收为来包的');
    });

    test('(3) delete change(entitySyncId=rate-y)→ 行删除', () async {
      // 先 upsert 出一行,落 syncId=rate-y
      provider.pushFakeChange(
        entityType: 'exchange_rate_override',
        entitySyncId: 'rate-y',
        payload: {
          'syncId': 'rate-y',
          'baseCurrency': 'CNY',
          'quoteCurrency': 'USD',
          'rate': '7.2',
          'updatedAt': '2026-06-10T01:00:00Z',
        },
      );
      // delete change 按 entitySyncId 删
      provider.pushFakeChange(
        entityType: 'exchange_rate_override',
        entitySyncId: 'rate-y',
        action: 'delete',
      );

      await engine.pull('');

      final rows = await db.select(db.exchangeRateOverrides).get();
      expect(rows, isEmpty);
    });

    test(
        '(4) 币对收敛后针对旧 syncId 的 delete 是 no-op — 行仍存活且为新值',
        () async {
      // step1: upsert rate-x(CNY/USD = 7.5)
      provider.pushFakeChange(
        entityType: 'exchange_rate_override',
        entitySyncId: 'rate-x',
        payload: {
          'syncId': 'rate-x',
          'baseCurrency': 'CNY',
          'quoteCurrency': 'USD',
          'rate': '7.5',
          'updatedAt': '2026-06-10T00:00:00Z',
        },
      );
      // step2: upsert rate-y 同币对 — 行 syncId 被吸收为 rate-y,rate=7.2
      provider.pushFakeChange(
        entityType: 'exchange_rate_override',
        entitySyncId: 'rate-y',
        payload: {
          'syncId': 'rate-y',
          'baseCurrency': 'CNY',
          'quoteCurrency': 'USD',
          'rate': '7.2',
          'updatedAt': '2026-06-10T01:00:00Z',
        },
      );
      // step3: delete entitySyncId=rate-x — 行 syncId 已是 rate-y,按精确匹配
      //        找不到 rate-x → no-op,行仍存活
      provider.pushFakeChange(
        entityType: 'exchange_rate_override',
        entitySyncId: 'rate-x',
        action: 'delete',
      );

      await engine.pull('');

      final rows = await db.select(db.exchangeRateOverrides).get();
      expect(rows, hasLength(1), reason: '旧 syncId 的 delete 是 no-op,行不应被删除');
      expect(rows.first.syncId, 'rate-y', reason: '行 syncId 为收敛后的新值');
      expect(rows.first.rate, '7.2', reason: 'rate 为 rate-y upsert 的值');
    });
  });
}
