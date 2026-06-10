// _applyLedgerChange monthStartDay 哨兵语义测试。
//
// 覆盖三个断言：
// (a) payload 带 monthStartDay=15 → 本地 ledger.monthStartDay=15
// (b) 再来一条不带该 key 的改名 change → 本地保持 15(absent 语义)
// (c) syncLedgersFromServer: server 返 monthStartDay=99 → clamp 28

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

  group('_applyLedgerChange monthStartDay', () {
    test('(a) payload 带 monthStartDay=15 → 本地行写入 15', () async {
      provider.pushFakeChange(
        entityType: 'ledger',
        entitySyncId: 'ledger-ms',
        ledgerId: 'ledger-ms',
        payload: {
          'ledgerName': 'MS Test',
          'currency': 'CNY',
          'monthStartDay': 15,
        },
      );

      await engine.pull('');

      final rows = await db.select(db.ledgers).get();
      expect(rows, hasLength(1));
      expect(rows.first.monthStartDay, 15);
    });

    test('(b) 再来不含 monthStartDay 的改名 change → 本地保持 15(absent 语义)', () async {
      // 前置：先建好 monthStartDay=15 的账本
      provider.pushFakeChange(
        entityType: 'ledger',
        entitySyncId: 'ledger-ms',
        ledgerId: 'ledger-ms',
        payload: {
          'ledgerName': 'MS Test',
          'currency': 'CNY',
          'monthStartDay': 15,
        },
      );
      // 改名，payload 不含 monthStartDay（老 server 或精简 payload）
      provider.pushFakeChange(
        entityType: 'ledger',
        entitySyncId: 'ledger-ms',
        ledgerId: 'ledger-ms',
        payload: {
          'ledgerName': 'MS Test Renamed',
          'currency': 'CNY',
        },
      );

      await engine.pull('');

      final rows = await db.select(db.ledgers).get();
      expect(rows, hasLength(1));
      expect(rows.first.name, 'MS Test Renamed');
      expect(rows.first.monthStartDay, 15,
          reason: '不含 monthStartDay 的 change 不应覆盖本地值');
    });

    test('(c) syncLedgersFromServer: server 返 monthStartDay=99 → clamp 28', () async {
      provider.pushFakeLedger(
        ledgerId: 'ledger-clamp',
        ledgerName: 'Clamp Test',
        monthStartDay: 99,
      );

      await engine.syncLedgersFromServer();

      final rows = await db.select(db.ledgers).get();
      expect(rows, hasLength(1));
      expect(rows.first.monthStartDay, 28,
          reason: '超出范围的值应 clamp 到 28');
    });
  });
}
