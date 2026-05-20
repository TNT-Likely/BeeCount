/// 孤儿数据清理器。
///
/// 接 `List<OrphanRecord>` 按 [OrphanType] dispatch 到具体删除路径,所有 DB
/// 修改统一包在一个 Drift `transaction()` 里。失败的 record 收集到 [OrphanCleanResult.failures]
/// 不阻断其余。
///
/// 删除策略:
/// - **A1/A2/A3/A4/A7/A8/A10**:直接删 DB 行(它们本身就是孤儿,无下游引用)
/// - **A5(tx 失主 account)**:**不删** tx,只把 `account_id`/`to_account_id`
///   置 null(交易本体有用户数据,保留)
/// - **A6(tx 失主 category)**:**不删** tx,只把 `category_id` 置 null
/// - **A9(共享二级分类失父)**:删 SharedLedgerCategories 行(复合主键)
/// - **B1/B2/B3**:删磁盘文件
/// - **C1**:删 local_changes 行
library;

import 'dart:io';

import 'package:drift/drift.dart' as d;

import '../../data/db.dart';
import '../system/logger_service.dart';
import 'orphan_record.dart';

class OrphanCleaner {
  OrphanCleaner({required this.db});

  final BeeDatabase db;

  /// 批量清理。返回 (成功数,失败列表)。
  Future<OrphanCleanResult> clean(List<OrphanRecord> records) async {
    if (records.isEmpty) return OrphanCleanResult.empty;

    final failures = <({OrphanRecord record, String error})>[];
    var success = 0;

    // 分离 DB / 文件 / sync 三类:DB 操作走一个事务,文件单独处理。
    final dbRecords = <OrphanRecord>[];
    final fileRecords = <OrphanRecord>[];
    final syncRecords = <OrphanRecord>[];
    for (final r in records) {
      switch (r.type) {
        case OrphanType.fileOrphanAttachment:
        case OrphanType.fileOrphanCustomIcon:
        case OrphanType.fileOrphanSharedIcon:
          fileRecords.add(r);
        case OrphanType.localChangeMissingEntity:
          syncRecords.add(r);
        default:
          dbRecords.add(r);
      }
    }

    if (dbRecords.isNotEmpty) {
      try {
        await db.transaction(() async {
          for (final r in dbRecords) {
            try {
              await _cleanDb(r);
              success++;
            } catch (e, st) {
              logger.warning('OrphanCleaner',
                  'DB record ${r.uniqueKey} 失败: $e', st);
              failures.add((record: r, error: e.toString()));
            }
          }
        });
      } catch (e, st) {
        // 整个事务失败 — 把 dbRecords 都标失败(success 计数回退)。
        logger.error('OrphanCleaner', 'DB 事务整体失败', e, st);
        // success 反正只在 commit 后才生效,这里事务回滚后 caller 看到的
        // success 是错的 — 重置 + 所有 dbRecords 进 failures。
        success = success - dbRecords.length + failures.length;
        if (success < 0) success = 0;
        for (final r in dbRecords) {
          if (failures.any((f) => f.record.uniqueKey == r.uniqueKey)) continue;
          failures.add((record: r, error: e.toString()));
        }
      }
    }

    for (final r in syncRecords) {
      try {
        await _cleanSync(r);
        success++;
      } catch (e, st) {
        logger.warning('OrphanCleaner',
            'sync record ${r.uniqueKey} 失败: $e', st);
        failures.add((record: r, error: e.toString()));
      }
    }

    for (final r in fileRecords) {
      try {
        await _cleanFile(r);
        success++;
      } catch (e, st) {
        logger.warning('OrphanCleaner',
            'file record ${r.uniqueKey} 失败: $e', st);
        failures.add((record: r, error: e.toString()));
      }
    }

    return OrphanCleanResult(successCount: success, failures: failures);
  }

  // ─────────────────────────── DB ───────────────────────────

  Future<void> _cleanDb(OrphanRecord r) async {
    switch (r.type) {
      case OrphanType.budgetMissingLedger:
      case OrphanType.budgetMissingCategory:
        await _deleteBudget(r);
      case OrphanType.attachmentMissingTx:
        await _deleteAttachmentRow(r);
      case OrphanType.txTagMissingTx:
      case OrphanType.txTagMissingTag:
        await _deleteTxTagLink(r);
      case OrphanType.txMissingAccount:
        await _clearTxAccount(r);
      case OrphanType.txMissingCategory:
        await _clearTxCategory(r);
      case OrphanType.categoryMissingParent:
        await _deleteCategory(r);
      case OrphanType.sharedCategoryMissingParent:
        await _deleteSharedCategory(r);
      case OrphanType.txTagOverrideMissingTx:
        await _deleteTxTagOverride(r);
      case OrphanType.fileOrphanAttachment:
      case OrphanType.fileOrphanCustomIcon:
      case OrphanType.fileOrphanSharedIcon:
      case OrphanType.localChangeMissingEntity:
        throw StateError('_cleanDb 收到非 DB 类型: ${r.type}');
    }
  }

  Future<void> _deleteBudget(OrphanRecord r) async {
    final id = r.localId;
    if (id == null) throw StateError('budget record 缺 localId');
    await (db.delete(db.budgets)..where((t) => t.id.equals(id))).go();
  }

  Future<void> _deleteAttachmentRow(OrphanRecord r) async {
    final id = r.localId;
    if (id == null) throw StateError('attachment record 缺 localId');
    await (db.delete(db.transactionAttachments)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  Future<void> _deleteTxTagLink(OrphanRecord r) async {
    final id = r.localId;
    if (id == null) throw StateError('tx_tag record 缺 localId');
    await (db.delete(db.transactionTags)..where((t) => t.id.equals(id))).go();
  }

  /// A5:把 tx.account_id / to_account_id 中失主的那个置 null,保留交易本体。
  Future<void> _clearTxAccount(OrphanRecord r) async {
    final id = r.localId;
    if (id == null) throw StateError('tx record 缺 localId');
    final clearAccount = (r.extra?['accountMissing'] as bool?) ?? false;
    final clearToAccount = (r.extra?['toAccountMissing'] as bool?) ?? false;
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        accountId: clearAccount
            ? const d.Value<int?>(null)
            : const d.Value.absent(),
        toAccountId: clearToAccount
            ? const d.Value<int?>(null)
            : const d.Value.absent(),
      ),
    );
  }

  /// A6:把 tx.category_id 置 null,保留交易本体。
  Future<void> _clearTxCategory(OrphanRecord r) async {
    final id = r.localId;
    if (id == null) throw StateError('tx record 缺 localId');
    await (db.update(db.transactions)..where((t) => t.id.equals(id)))
        .write(const TransactionsCompanion(categoryId: d.Value<int?>(null)));
  }

  Future<void> _deleteCategory(OrphanRecord r) async {
    final id = r.localId;
    if (id == null) throw StateError('category record 缺 localId');
    await (db.delete(db.categories)..where((t) => t.id.equals(id))).go();
  }

  /// A9:SharedLedgerCategories 复合主键 (ledger_sync_id, sync_id)。
  Future<void> _deleteSharedCategory(OrphanRecord r) async {
    final syncId = r.syncId;
    final ledgerSyncId = r.extra?['ledgerSyncId'] as String?;
    if (syncId == null || ledgerSyncId == null) {
      throw StateError('shared category record 缺 syncId/ledgerSyncId');
    }
    await (db.delete(db.sharedLedgerCategories)
          ..where((t) =>
              t.ledgerSyncId.equals(ledgerSyncId) & t.syncId.equals(syncId)))
        .go();
  }

  /// A10:TransactionTagOverrides 复合主键 (transaction_sync_id, tag_sync_id)。
  Future<void> _deleteTxTagOverride(OrphanRecord r) async {
    final txSyncId = r.syncId;
    final tagSyncId = r.extra?['tagSyncId'] as String?;
    if (txSyncId == null || tagSyncId == null) {
      throw StateError('tx_tag_override record 缺 txSyncId/tagSyncId');
    }
    await (db.delete(db.transactionTagOverrides)
          ..where((t) =>
              t.transactionSyncId.equals(txSyncId) &
              t.tagSyncId.equals(tagSyncId)))
        .go();
  }

  // ─────────────────────────── Sync ───────────────────────────

  Future<void> _cleanSync(OrphanRecord r) async {
    if (r.type != OrphanType.localChangeMissingEntity) {
      throw StateError('_cleanSync 收到非 sync 类型: ${r.type}');
    }
    final id = r.localId;
    if (id == null) throw StateError('local_change record 缺 localId');
    await (db.delete(db.localChanges)..where((t) => t.id.equals(id))).go();
  }

  // ─────────────────────────── File ───────────────────────────

  Future<void> _cleanFile(OrphanRecord r) async {
    final path = r.filePath;
    if (path == null || path.isEmpty) {
      throw StateError('file record 缺 filePath');
    }
    final file = File(path);
    if (!await file.exists()) return; // 已经没了,视为成功
    await file.delete();
  }
}
