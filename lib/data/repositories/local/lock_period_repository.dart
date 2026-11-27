import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';

import '../../../cloud/sync/change_tracker.dart';
import '../../db.dart';
import '../../../utils/date_in_tz.dart';

/// 导入单行(S1-01b-3 会复用):sync_id / batch_no 不由调用方提供,
/// 由 [LockPeriodRepository.importLockPeriods] 统一重生成 / 重排。
typedef LockPeriodImportRow = ({
  String lockDate,
  String lockedBy,
  String lockedAt,
  String? createdByUserId,
  String? lastEditedByUserId,
});

/// 锁账期间本地仓储(S1-01a 交付数据通道,S1-01b-1 补写路径聚合查询)。
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
  ///
  /// S1-01b-1 起的规范入口。旧名 [effectiveLockDate] 只做纯转发,
  /// 不含缓存 / 边界 / 取号逻辑,US-01 已合并的 e2e 断言行为不变。
  Future<String?> getEffectiveLockDate(int ledgerId) async {
    final rows = await db.customSelect(
      'SELECT MAX(lock_date) AS max_date FROM lock_periods WHERE ledger_id = ?',
      variables: [d.Variable<int>(ledgerId)],
    ).get();
    return rows.single.data['max_date'] as String?;
  }

  /// US-01 既有调用方专用别名:只转发,禁止在此加任何逻辑。
  Future<String?> effectiveLockDate(int ledgerId) =>
      getEffectiveLockDate(ledgerId);

  /// 本账本下一个审计序号 = MAX(batch_no) + 1,空表从 1 开始。
  Future<int> nextBatchNo(int ledgerId) async {
    final rows = await db.customSelect(
      'SELECT MAX(batch_no) AS max_batch FROM lock_periods WHERE ledger_id = ?',
      variables: [d.Variable<int>(ledgerId)],
    ).get();
    return ((rows.single.data['max_batch'] as int?) ?? 0) + 1;
  }

  /// 统计「会被 [lockDate] 这条锁定线锁住」的流水数(S1-01b-1 确认弹窗用)。
  ///
  /// 口径(S1-01b 批复 §3):
  ///   - 范围 = 该账本内、且 `businessDateInShanghai(happenedAt) <= lockDate`
  ///     的流水;**不排除已锁定记录**(语义是"该日期及以前共 N 条");
  ///   - `businessDateInShanghai` 是 S1-01a 的唯一判定函数,本方法不再另写
  ///     一套时区换算 —— 边界换算统一走 [shanghaiDayEndUtcExclusive]。
  ///   - 一次 COUNT 聚合查询,**不把流水全量加载到内存再数**。
  ///
  /// [shanghaiDayEndUtcExclusive] 把「业务日 <= lockDate」翻译成
  /// 「UTC 时刻 < 次日上海零点(不含)」,由 Drift 用自己的 DateTime codec
  /// 绑定上界,不假设 happened_at 的存储单位。SQL 只做一次聚合比较。
  Future<int> countTransactionsOnOrBefore(int ledgerId, String lockDate) async {
    final boundary = shanghaiDayEndUtcExclusive(lockDate);
    if (boundary == null) return 0;
    final count = db.transactions.id.count();
    final row = await (db.selectOnly(db.transactions)
          ..addColumns([count])
          ..where(db.transactions.ledgerId.equals(ledgerId) &
              db.transactions.happenedAt.isSmallerThanValue(boundary)))
        .getSingle();
    return row.read(count) ?? 0;
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

  /// 撤销最近一次锁账(S1-01b-1 写路径)。
  ///
  /// 「最近一次」= 该账本 `batch_no` 最大那条(batch_no 是写入时 MAX+1 的
  /// 审计序号,与 [listForLedger] 的展示顺序一致)。撤销 = 删掉这一行,
  /// 于是有效锁定线回退到剩余行的 MAX(lock_date);若一行不剩则回到 null
  /// (完全解锁)。
  ///
  /// 删除与变更登记在**同一事务**内:先删行再登记 `lock_period:delete`
  /// 变更,避免出现"行已删但变更没登记"(云端删不掉)或"变更已登记但行还在"
  /// (本地仍被锁)的中间态。变更登记走 [trackerGetter],与
  /// [createLocal] 同一套 ledger-scoped 通道。
  ///
  /// 返回被撤销的那一行;该账本没有锁账记录时返回 null。
  Future<LockPeriod?> revokeLatest(int ledgerId) async {
    return db.transaction(() async {
      final target = await (db.select(db.lockPeriods)
            ..where((t) => t.ledgerId.equals(ledgerId))
            ..orderBy([(t) => d.OrderingTerm.desc(t.batchNo)])
            ..limit(1))
          .getSingleOrNull();
      if (target == null) return null;
      await (db.delete(db.lockPeriods)..where((t) => t.id.equals(target.id)))
          .go();
      await trackerGetter?.call()?.recordLedgerChange(
            entityType: 'lock_period',
            entityId: target.id,
            entitySyncId: target.syncId,
            ledgerId: ledgerId,
            action: 'delete',
          );
      return target;
    });
  }

  /// 导入锁账记录(S1-01b-1 只落接口 + 单测,真实接入在 1b-3)。
  ///
  /// 唯一性口径:
  ///   - `sync_id` 一律 `Uuid().v4()` 重生成,**不采信**输入里的重复值;
  ///   - `batch_no` 从 `nextBatchNo(targetLedgerId)` 起连续重排,单调且不复用;
  ///   - 只插入新行,不更新 / 覆盖任何既有行 → 原锁定线不会被放松;
  ///   - 不注入 ChangeTracker:导入是 apply / hydration 同类路径,不反向回流。
  Future<List<LockPeriod>> importLockPeriods(
    int targetLedgerId,
    Iterable<LockPeriodImportRow> periods,
  ) async {
    return db.transaction(() async {
      var batchNo = await nextBatchNo(targetLedgerId);
      const uuid = Uuid();
      final inserted = <LockPeriod>[];
      for (final row in periods) {
        final syncId = uuid.v4();
        await db.into(db.lockPeriods).insert(LockPeriodsCompanion.insert(
              syncId: syncId,
              ledgerId: targetLedgerId,
              lockDate: row.lockDate,
              batchNo: batchNo++,
              lockedBy: row.lockedBy,
              lockedAt: row.lockedAt,
              createdByUserId: d.Value(row.createdByUserId),
              lastEditedByUserId: d.Value(row.lastEditedByUserId),
            ));
        inserted.add((await getBySyncId(syncId))!);
      }
      return inserted;
    });
  }
}
