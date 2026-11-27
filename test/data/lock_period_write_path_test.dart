import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/lock_period_repository.dart';
import 'package:beecount/pages/settings/lock_period/bindings/lock_period_settings_actions.dart';
import 'package:beecount/utils/date_in_tz.dart';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// 在 delete 登记阶段抛错,用于验证"删行 + 登记"同事务回滚。
class _ThrowingChangeTracker extends ChangeTracker {
  _ThrowingChangeTracker(super.db);

  @override
  Future<void> recordLedgerChange({
    required String entityType,
    required int entityId,
    required String entitySyncId,
    required int ledgerId,
    required String action,
    String? payloadJson,
  }) async {
    throw StateError('injected delete-registration failure');
  }
}

/// S1-01b-1 锁账写路径验收。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LockPeriodRepository repo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LockPeriodRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  var txSeq = 0;
  Future<void> insertTx({
    required int ledgerId,
    required DateTime happenedAt,
    String? syncId,
  }) async {
    txSeq++;
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 1.0,
          happenedAt: d.Value(happenedAt),
          syncId: d.Value(syncId ?? 'tx-$txSeq'),
        ));
  }

  group('shanghaiDayEndUtcExclusive(§3 边界换算)', () {
    test('非法日期返回 null(不能当成"无边界"而误计数)', () {
      expect(shanghaiDayEndUtcExclusive('2026-02-30'), isNull);
      expect(shanghaiDayEndUtcExclusive('2026-13-01'), isNull);
      expect(shanghaiDayEndUtcExclusive('not-a-date'), isNull);
      expect(shanghaiDayEndUtcExclusive('2026-11'), isNull);
      expect(shanghaiDayEndUtcExclusive(''), isNull);
    });

    test('合法日期返回次日上海零点的 UTC 时刻', () {
      expect(shanghaiDayEndUtcExclusive('2026-11-26')!.toUtc(),
          DateTime.utc(2026, 11, 26, 16));
      expect(shanghaiDayEndUtcExclusive('2026-11-30')!.toUtc(),
          DateTime.utc(2026, 11, 30, 16));
      expect(shanghaiDayEndUtcExclusive('2026-12-31')!.toUtc(),
          DateTime.utc(2026, 12, 31, 16));
    });

    test('与 businessDateInShanghai 严格等价(含 23:00 / 00:00)', () {
      final samples = <DateTime>[
        DateTime.utc(2026, 11, 26, 15, 59),
        DateTime.utc(2026, 11, 26, 16, 0),
        DateTime.utc(2026, 11, 26, 16, 1),
        DateTime.utc(2026, 11, 27, 15, 59),
        DateTime.utc(2026, 11, 27, 16, 0),
        DateTime.utc(2026, 11, 27, 16, 30),
      ];
      const lockDate = '2026-11-27';
      final boundary = shanghaiDayEndUtcExclusive(lockDate)!;
      for (final t in samples) {
        final byBusinessDate =
            businessDateInShanghai(t).compareTo(lockDate) <= 0;
        expect(t.isBefore(boundary), byBusinessDate,
            reason: '时刻 $t 的两种判定必须一致');
      }
    });
  });

  group('countTransactionsOnOrBefore(N 条口径)', () {
    test('只数本账本、且业务日 <= lock_date 的流水', () async {
      await insertTx(
          ledgerId: 1, happenedAt: DateTime.utc(2026, 11, 20, 4));
      await insertTx(
          ledgerId: 1, happenedAt: DateTime.utc(2026, 11, 26, 15));
      await insertTx(
          ledgerId: 1, happenedAt: DateTime.utc(2026, 11, 26, 16));
      await insertTx(
          ledgerId: 1, happenedAt: DateTime.utc(2026, 11, 28, 4));
      await insertTx(ledgerId: 2, happenedAt: DateTime.utc(2026, 11, 10, 4));

      expect(await repo.countTransactionsOnOrBefore(1, '2026-11-26'), 2);
      expect(await repo.countTransactionsOnOrBefore(1, '2026-11-27'), 3);
      expect(await repo.countTransactionsOnOrBefore(1, '2026-11-19'), 0);
      expect(await repo.countTransactionsOnOrBefore(2, '2026-11-27'), 1,
          reason: '按账本分桶');
    });

    test('exclusive 双向边界:23:59:59.999 计入,次日 00:00:00.000 不计入',
        () async {
      // 上海 2026-11-26 23:59:59.999 == UTC 15:59:59.999 → 计入 11-26
      await insertTx(
          ledgerId: 1, happenedAt: DateTime.utc(2026, 11, 26, 15, 59, 59, 999));
      // 上海 2026-11-27 00:00:00.000 == UTC 16:00:00.000 → 不计入 11-26
      await insertTx(
          ledgerId: 1, happenedAt: DateTime.utc(2026, 11, 26, 16, 0, 0, 0));

      expect(await repo.countTransactionsOnOrBefore(1, '2026-11-26'), 1,
          reason: '含当天 23:59:59.999');
      expect(await repo.countTransactionsOnOrBefore(1, '2026-11-27'), 2,
          reason: '次日 00:00:00.000 计入 11-27,证明上界 exclusive');
    });

    test('UTC 00:00 / 23:00 边界各一条', () async {
      await insertTx(
          ledgerId: 1, happenedAt: DateTime.utc(2026, 11, 26, 23, 0));
      await insertTx(
          ledgerId: 1, happenedAt: DateTime.utc(2026, 11, 27, 0, 0));
      await insertTx(
          ledgerId: 1, happenedAt: DateTime.utc(2026, 11, 27, 16, 0));

      expect(await repo.countTransactionsOnOrBefore(1, '2026-11-27'), 2);
      expect(await repo.countTransactionsOnOrBefore(1, '2026-11-26'), 0);
      expect(await repo.countTransactionsOnOrBefore(1, '2026-11-28'), 3);
    });

    test('不排除已锁定记录 + 非法日期返回 0', () async {
      await insertTx(ledgerId: 1, happenedAt: DateTime.utc(2026, 11, 20, 4));
      await insertTx(ledgerId: 1, happenedAt: DateTime.utc(2026, 11, 25, 4));
      await repo.createLocal(
          syncId: 'lp-1', ledgerId: 1, lockDate: '2026-11-20');
      await repo.createLocal(
          syncId: 'lp-2', ledgerId: 1, lockDate: '2026-11-25');

      expect(await repo.countTransactionsOnOrBefore(1, '2026-11-25'), 2);
      expect(await repo.countTransactionsOnOrBefore(1, '2026-02-30'), 0);
    });
  });

  group('getEffectiveLockDate 与严格晚于', () {
    test('effectiveLockDate 纯转发到 getEffectiveLockDate', () async {
      await repo.createLocal(
          syncId: 'lp-a', ledgerId: 1, lockDate: '2026-11-27');
      expect(await repo.getEffectiveLockDate(1), '2026-11-27');
      expect(await repo.effectiveLockDate(1),
          await repo.getEffectiveLockDate(1));
    });

    test('严格晚于:相等拦截,无锁账放行', () {
      expect(isLockDateStrictlyLater('2026-11-27', null), isTrue,
          reason: '首次新增例外');
      expect(isLockDateStrictlyLater('2026-11-28', '2026-11-27'), isTrue);
      expect(isLockDateStrictlyLater('2026-11-27', '2026-11-27'), isFalse,
          reason: '等于即拦截');
      expect(isLockDateStrictlyLater('2026-11-26', '2026-11-27'), isFalse);
    });
  });

  group('revokeLatest(撤销原子性)', () {
    test('删掉 batch_no 最大那条,锁定线回退', () async {
      await repo.createLocal(
          syncId: 'lp-1', ledgerId: 1, lockDate: '2026-11-01');
      await repo.createLocal(
          syncId: 'lp-2', ledgerId: 1, lockDate: '2026-12-15');
      expect(await repo.getEffectiveLockDate(1), '2026-12-15');

      final revoked = await repo.revokeLatest(1);
      expect(revoked!.syncId, 'lp-2');
      expect(await repo.getEffectiveLockDate(1), '2026-11-01');
      expect((await repo.listForLedger(1)).length, 1);

      expect((await repo.revokeLatest(1))!.syncId, 'lp-1');
      expect(await repo.getEffectiveLockDate(1), isNull);
    });

    test('只影响目标账本', () async {
      await repo.createLocal(
          syncId: 'lp-a', ledgerId: 1, lockDate: '2026-11-01');
      await repo.createLocal(
          syncId: 'lp-b', ledgerId: 2, lockDate: '2026-12-01');
      await repo.revokeLatest(1);
      expect(await repo.getEffectiveLockDate(1), isNull);
      expect(await repo.getEffectiveLockDate(2), '2026-12-01');
    });

    test('登记 delete 变更(ledger-scoped)', () async {
      final tracker = ChangeTracker(db);
      final tracked = LockPeriodRepository(db, trackerGetter: () => tracker);
      await tracked.createLocal(
          syncId: 'lp-tracked', ledgerId: 7, lockDate: '2026-11-27');
      await tracked.revokeLatest(7);

      final changes = await (db.select(db.localChanges)
            ..where((c) => c.entityType.equals('lock_period')))
          .get();
      final deletes = changes.where((c) => c.action == 'delete').toList();
      expect(deletes, hasLength(1));
      expect(deletes.single.ledgerId, 7);
      expect(deletes.single.entitySyncId, 'lp-tracked');
    });

    test('P0:登记阶段抛错时整笔回滚,行不被删', () async {
      final good = LockPeriodRepository(db, trackerGetter: () => ChangeTracker(db));
      await good.createLocal(
          syncId: 'lp-atomic', ledgerId: 1, lockDate: '2026-11-27');

      final throwing =
          LockPeriodRepository(db, trackerGetter: () => _ThrowingChangeTracker(db));
      expect(throwing.revokeLatest(1), throwsA(isA<StateError>()));

      expect(await repo.getEffectiveLockDate(1), '2026-11-27',
          reason: '事务回滚后锁定线必须保留');
      expect(await repo.listForLedger(1), hasLength(1));
      final deletes = await (db.select(db.localChanges)
            ..where((c) =>
                c.entityType.equals('lock_period') & c.action.equals('delete')))
          .get();
      expect(deletes, isEmpty, reason: '失败事务不能留下 delete 变更');
    });

    test('没有锁账记录时返回 null', () async {
      expect(await repo.revokeLatest(99), isNull);
    });
  });

  group('importLockPeriods(唯一性接口)', () {
    test('重生成 sync_id / 重排 batch_no,不覆盖原行、不放松锁定线', () async {
      final original = await repo.createLocal(
          syncId: 'original-sync', ledgerId: 1, lockDate: '2026-12-01');

      final imported = await repo.importLockPeriods(1, [
        (
          lockDate: '2026-11-01',
          lockedBy: 'import',
          lockedAt: '2026-11-28T00:00:00.000Z',
          createdByUserId: null,
          lastEditedByUserId: null
        ),
        (
          lockDate: '2026-11-02',
          lockedBy: 'import',
          lockedAt: '2026-11-28T00:00:00.000Z',
          createdByUserId: null,
          lastEditedByUserId: null
        ),
      ]);

      expect(imported, hasLength(2));
      final all = await repo.listForLedger(1);
      expect(all, hasLength(3));
      expect(all.map((r) => r.syncId).toSet(), hasLength(3),
          reason: '重复 sync_id 必须被重生成');
      expect(all.map((r) => r.batchNo).toList()..sort(), [1, 2, 3]);
      expect(all.first.batchNo, 3, reason: 'batch_no 单调重排');
      expect((await repo.getBySyncId('original-sync'))!.lockDate,
          original.lockDate,
          reason: '原行不被覆盖');
      expect(await repo.getEffectiveLockDate(1), '2026-12-01',
          reason: '导入更早日期不得放松锁定线');
    });
  });
}
