import 'package:drift/drift.dart' as d;

import '../../../cloud/sync/change_tracker.dart';
import '../../db.dart';
import '../../../utils/date_in_tz.dart';

/// 锁账期间本地仓储(S1-01a)。
///
/// 幂等键是 [LockPeriods.syncId] 的列级 UNIQUE:apply / import 都走
/// [upsertBySyncId],同一 syncId 重复到达不会产生第二行。
/// 有效锁定线 = 该账本 `MAX(lock_date)`;空表返回 null = 无锁账。
class LockPeriodRepository {
  final BeeDatabase db;

  /// 本地新建时登记变更用 getter 注入(与 LocalExchangeRateRepository 同款):
  /// LocalRepository.changeTracker 是构造后才赋值的可变字段,直接传引用
  /// 会捕获 null。apply / import / hydration 不传 → 不反向回流。
  final ChangeTracker? Function()? trackerGetter;

  LockPeriodRepository(this.db, {this.trackerGetter});

  Future<LockPeriod?> getBySyncId(String syncId) =>
      (db.select(db.lockPeriods)..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();

  /// 展示序列:batchNo 大的在前,同号按 lockedAt 排。
  Future<List<LockPeriod>> listForLedger(int ledgerId) =>
      (db.select(db.lockPeriods)
            ..where((t) => t.ledgerId.equals(ledgerId))
            ..orderBy([
              (t) => d.OrderingTerm.desc(t.batchNo),
              (t) => d.OrderingTerm.desc(t.lockedAt),
            ]))
          .get();

  /// 有效锁定线 = MAX(lock_date),无锁账返回 null。
  Future<String?> effectiveLockDate(int ledgerId) async {
    final rows = await db.customSelect(
      'SELECT MAX(lock_date) AS max_date FROM lock_periods WHERE ledger_id = ?',
      variables: [d.Variable<int>(ledgerId)],
    ).get();
    return rows.single.data['max_date'] as String?;
  }

  /// 本账本下一个审计序号 = MAX(batch_no) + 1,空表从 1 开始。
  Future<int> nextBatchNo(int ledgerId) async {
    final rows = await db.customSelect(
      'SELECT MAX(batch_no) AS max_batch FROM lock_periods WHERE ledger_id = ?',
      variables: [d.Variable<int>(ledgerId)],
    ).get();
    return ((rows.single.data['max_batch'] as int?) ?? 0) + 1;
  }

  /// 本地新建一条锁账记录。batchNo 由 MAX+1 生成,lockedAt 取当前 UTC。
  /// 只有本地新建走这里登记 ledger-scoped 变更(不进 user-global 白名单);
  /// apply / import / hydration 直接调 [upsertBySyncId],不回推。
  Future<LockPeriod> createLocal({
    required String syncId,
    required int ledgerId,
    required String lockDate,
    String lockedBy = 'local',
    String? createdByUserId,
    String? lastEditedByUserId,
  }) async {
    final period = await upsertBySyncId(
      syncId: syncId,
      ledgerId: ledgerId,
      lockDate: lockDate,
      batchNo: null,
      lockedBy: lockedBy,
      lockedAt: utcIsoNow(),
      createdByUserId: createdByUserId,
      lastEditedByUserId: lastEditedByUserId,
    );
    await trackerGetter?.call()?.recordLedgerChange(
          entityType: 'lock_period',
          entityId: period.id,
          entitySyncId: period.syncId,
          ledgerId: ledgerId,
          action: 'upsert',
        );
    return period;
  }

  /// 按 syncId upsert。列级 UNIQUE 保证即使并发写也不会产生重复行。
  /// [batchNo] 为 null 时按 MAX(batch_no)+1 生成(仅本地新建用)。
  Future<LockPeriod> upsertBySyncId({
    required String syncId,
    required int ledgerId,
    required String lockDate,
    required int? batchNo,
    required String lockedBy,
    required String lockedAt,
    String? createdByUserId,
    String? lastEditedByUserId,
  }) async {
    return db.transaction(() async {
      final existing = await getBySyncId(syncId);
      final effectiveBatchNo = batchNo ?? await nextBatchNo(ledgerId);
      if (existing == null) {
        await db.into(db.lockPeriods).insert(LockPeriodsCompanion.insert(
              syncId: syncId,
              ledgerId: ledgerId,
              lockDate: lockDate,
              batchNo: effectiveBatchNo,
              lockedBy: lockedBy,
              lockedAt: lockedAt,
              createdByUserId: d.Value(createdByUserId),
              lastEditedByUserId: d.Value(lastEditedByUserId),
            ));
      } else {
        await (db.update(db.lockPeriods)
              ..where((t) => t.id.equals(existing.id)))
            .write(LockPeriodsCompanion(
              ledgerId: d.Value(ledgerId),
              lockDate: d.Value(lockDate),
              batchNo: d.Value(effectiveBatchNo),
              lockedBy: d.Value(lockedBy),
              lockedAt: d.Value(lockedAt),
              createdByUserId: d.Value(createdByUserId),
              lastEditedByUserId: d.Value(lastEditedByUserId),
            ));
      }
      return (await getBySyncId(syncId))!;
    });
  }

  Future<int> deleteBySyncId(String syncId) =>
      (db.delete(db.lockPeriods)..where((t) => t.syncId.equals(syncId))).go();

  Future<int> deleteForLedger(int ledgerId) =>
      (db.delete(db.lockPeriods)..where((t) => t.ledgerId.equals(ledgerId)))
          .go();
}
