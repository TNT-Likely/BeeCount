// ChangeTracker 契约测试。
//
// 锁死 user-global 实体(account / category / tag)的 recordChange 一定走
// ledgerId=0 通道;ledger-scoped 实体(transaction / budget / ledger)拒绝
// ledgerId=0。
//
// 2026-04 踩过一次坑:LocalRepository.updateAccount 历史上用了
// `ledgerId: account.ledgerId`(不是 0),导致当前 active ledger ≠
// account.ledgerId 时,account rename / create / delete 变更被 `_push()`
// 里的 getUnpushedChangesForLedger(currentLedger) + getUnpushedChangesForLedger(0)
// 两个查询同时漏掉,永远卡本地不推。API 化后这类错误编译期 / assert
// 期就能发现。

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/data/db.dart';

void main() {
  // ChangeTracker._insert 会调 logger,logger 初始化时注册原生 channel
  // + 读 SharedPreferences。所以测试先拉起 binding + mock SharedPreferences。
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late ChangeTracker tracker;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    tracker = ChangeTracker(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('recordUserGlobalChange 强制 ledgerId=0', () {
    test('account 走 user-global 通道', () async {
      await tracker.recordUserGlobalChange(
        entityType: 'account',
        entityId: 1,
        entitySyncId: 'acc-sync-id',
        action: 'update',
      );
      final changes = await tracker.getUnpushedChangesForLedger(0);
      expect(changes.length, 1);
      expect(changes.first.entityType, 'account');
      expect(changes.first.ledgerId, 0);
    });

    test('category 走 user-global 通道', () async {
      await tracker.recordUserGlobalChange(
        entityType: 'category',
        entityId: 2,
        entitySyncId: 'cat-sync-id',
        action: 'create',
      );
      final changes = await tracker.getUnpushedChangesForLedger(0);
      expect(changes.length, 1);
      expect(changes.first.ledgerId, 0);
    });

    test('tag 走 user-global 通道', () async {
      await tracker.recordUserGlobalChange(
        entityType: 'tag',
        entityId: 3,
        entitySyncId: 'tag-sync-id',
        action: 'delete',
      );
      final changes = await tracker.getUnpushedChangesForLedger(0);
      expect(changes.length, 1);
      expect(changes.first.ledgerId, 0);
    });

    test('user-global 变更不会出现在具体账本查询里', () async {
      await tracker.recordUserGlobalChange(
        entityType: 'account',
        entityId: 10,
        entitySyncId: 's',
        action: 'update',
      );
      // 具体 ledger 的查询不应该看到 ledgerId=0 的全局变更
      final ledger5 = await tracker.getUnpushedChangesForLedger(5);
      expect(ledger5, isEmpty);
    });

    test('拒绝非 user-global 实体(debug assert)', () {
      expect(
        () => tracker.recordUserGlobalChange(
          entityType: 'transaction', // ← 不在白名单
          entityId: 1,
          entitySyncId: 's',
          action: 'update',
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('recordLedgerChange 要求具体 ledgerId', () {
    test('transaction 记到给定 ledger', () async {
      await tracker.recordLedgerChange(
        entityType: 'transaction',
        entityId: 1,
        entitySyncId: 'tx-sync-id',
        ledgerId: 5,
        action: 'create',
      );
      final changes = await tracker.getUnpushedChangesForLedger(5);
      expect(changes.length, 1);
      expect(changes.first.ledgerId, 5);
    });

    test('budget 记到给定 ledger', () async {
      await tracker.recordLedgerChange(
        entityType: 'budget',
        entityId: 2,
        entitySyncId: 'b-sync',
        ledgerId: 7,
        action: 'update',
      );
      final changes = await tracker.getUnpushedChangesForLedger(7);
      expect(changes.length, 1);
    });

    test('拒绝 user-global 实体(debug assert)', () {
      expect(
        () => tracker.recordLedgerChange(
          entityType: 'account', // ← user-global
          entityId: 1,
          entitySyncId: 's',
          ledgerId: 5,
          action: 'update',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('拒绝 ledgerId=0(debug assert)', () {
      expect(
        () => tracker.recordLedgerChange(
          entityType: 'transaction',
          entityId: 1,
          entitySyncId: 's',
          ledgerId: 0, // ← 必须 > 0
          action: 'update',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('ledger-scoped 变更不会被 getUnpushedChangesForLedger(0) 捞到', () async {
      await tracker.recordLedgerChange(
        entityType: 'transaction',
        entityId: 1,
        entitySyncId: 's',
        ledgerId: 5,
        action: 'create',
      );
      final globals = await tracker.getUnpushedChangesForLedger(0);
      expect(globals, isEmpty);
    });
  });

  group('综合:多账本场景下 user-global 变更被所有账本的 sync 链可见', () {
    test('在任一具体账本触发 sync 时,user-global 变更应通过 getUnpushed(0) 一起带出',
        () async {
      // 模拟真实场景:用户在 mobile 重命名 account(user-global 变更)+
      // 当前账本 5 又改了一笔交易(ledger-scoped 变更)。
      await tracker.recordUserGlobalChange(
        entityType: 'account',
        entityId: 1,
        entitySyncId: 'acc-x',
        action: 'update',
      );
      await tracker.recordLedgerChange(
        entityType: 'transaction',
        entityId: 2,
        entitySyncId: 'tx-y',
        ledgerId: 5,
        action: 'create',
      );

      // 跟 sync_engine._push 相同的取法:当前账本的 + ledgerId=0 的
      final ledger5 = await tracker.getUnpushedChangesForLedger(5);
      final globals = await tracker.getUnpushedChangesForLedger(0);
      final all = [...ledger5, ...globals];
      expect(all.length, 2);
      expect(all.map((c) => c.entityType).toSet(), {'transaction', 'account'});
    });
  });
}
