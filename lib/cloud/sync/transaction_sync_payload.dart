import 'package:drift/drift.dart' as d;

import '../../data/db.dart';
import '../../services/system/logger_service.dart';
import 'entity_serializer.dart';

Future<List<Map<String, dynamic>>> readTransactionSyncAttachments(
    BeeDatabase db, int transactionId) async {
  final txAttachments = await (db.select(db.transactionAttachments)
        ..where((a) => a.transactionId.equals(transactionId))
        ..orderBy([
          (a) => d.OrderingTerm.asc(a.sortOrder),
          (a) => d.OrderingTerm.asc(a.id)
        ]))
      .get();
  return txAttachments
      .map((a) => <String, dynamic>{
            'fileName': a.fileName,
            'originalName': a.originalName,
            'fileSize': a.fileSize,
            'width': a.width,
            'height': a.height,
            'sortOrder': a.sortOrder,
            if (a.cloudFileId != null) 'cloudFileId': a.cloudFileId,
            if (a.cloudSha256 != null) 'cloudSha256': a.cloudSha256,
          })
      .toList();
}

Future<Map<String, dynamic>> serializeTransactionForSync(
    BeeDatabase db, Transaction tx, String? parentLedgerSyncId) async {
  // 获取关联数据
  final cat = tx.categoryId != null
      ? await (db.select(db.categories)
            ..where((c) => c.id.equals(tx.categoryId!)))
          .getSingleOrNull()
      : null;
  final acc = tx.accountId != null
      ? await (db.select(db.accounts)..where((a) => a.id.equals(tx.accountId!)))
          .getSingleOrNull()
      : null;
  final toAcc = tx.toAccountId != null
      ? await (db.select(db.accounts)
            ..where((a) => a.id.equals(tx.toAccountId!)))
          .getSingleOrNull()
      : null;

  // 获取标签(连同 tag.syncId,server 端按 id 反查最新名字)
  final txTags = await readTransactionSyncTags(db, tx, parentLedgerSyncId);

  final attMaps = await readTransactionSyncAttachments(db, tx.id);
  // 早期警告:tx 有附件但部分 cloudFileId 缺失。push 出去后 server 端
  // 会把 attachments 当 "仅元数据" 处理,web 预览报错。理论上 sync 顺序
  // upload → push 应该让这里永远不触发;触发了说明 upload 跨 sync 边界
  // 出过 race(参考 sync_engine_attachments.dart::uploadAttachments 注释)。
  if (attMaps.isNotEmpty) {
    final withCloud = attMaps.where((a) => a['cloudFileId'] != null).length;
    if (withCloud < attMaps.length) {
      logger.warning(
        'SyncEngine',
        'push tx=${tx.id}(syncId=${tx.syncId}) attachments=${attMaps.length} '
            'cloud_ready=$withCloud — 部分附件缺 cloudFileId,server 端会报"仅元数据"。'
            '若 uploadAttachments 这轮上传了新附件应已重登记 tx update,此条不应再出现。',
      );
    }
  }

  // §7 v25 共享账本:tx 有 *SyncIdOverride 字段时(Editor 在共享账本下
  // 记的 tx),override 优先 — push 给 server 的 categoryId / accountId
  // 走 override(Owner 的 syncId)。同时反查 SharedLedger* 拿 name/kind
  // 用作 denormalized 文本(server LWW 名字字段)。
  String? finalCategorySyncId = tx.categorySyncIdOverride;
  String? finalCategoryName = cat?.name;
  String? finalCategoryKind = cat?.kind;
  if (finalCategorySyncId != null && finalCategorySyncId.isNotEmpty) {
    final shared = await (db.select(db.sharedLedgerCategories)
          ..where((t) => t.syncId.equals(finalCategorySyncId!)))
        .getSingleOrNull();
    if (shared != null) {
      finalCategoryName = shared.name;
      finalCategoryKind = shared.kind;
    }
  } else {
    finalCategorySyncId = cat?.syncId;
  }
  String? finalAccountSyncId = tx.accountSyncIdOverride;
  String? finalAccountName = acc?.name;
  if (finalAccountSyncId != null && finalAccountSyncId.isNotEmpty) {
    final shared = await (db.select(db.sharedLedgerAccounts)
          ..where((t) => t.syncId.equals(finalAccountSyncId!)))
        .getSingleOrNull();
    if (shared != null) {
      finalAccountName = shared.name;
    }
  } else {
    finalAccountSyncId = acc?.syncId;
  }
  String? finalToAccountSyncId = tx.toAccountSyncIdOverride;
  String? finalToAccountName = toAcc?.name;
  if (finalToAccountSyncId != null && finalToAccountSyncId.isNotEmpty) {
    final shared = await (db.select(db.sharedLedgerAccounts)
          ..where((t) => t.syncId.equals(finalToAccountSyncId!)))
        .getSingleOrNull();
    if (shared != null) {
      finalToAccountName = shared.name;
    }
  } else {
    finalToAccountSyncId = toAcc?.syncId;
  }

  return EntitySerializer.serializeTransaction(
    tx,
    categoryName: finalCategoryName,
    categoryKind: finalCategoryKind,
    categorySyncId: finalCategorySyncId,
    accountName: finalAccountName,
    accountSyncId: finalAccountSyncId,
    fromAccountName: tx.type == 'transfer' ? finalAccountName : null,
    fromAccountSyncId: tx.type == 'transfer' ? finalAccountSyncId : null,
    toAccountName: finalToAccountName,
    toAccountSyncId: finalToAccountSyncId,
    ledgerSyncId: parentLedgerSyncId,
    tagNames: txTags.names,
    tagSyncIds: txTags.ids,
    attachments: attMaps,
  );
}

/// 全量、增量和快照共用同一组标签。空列表表示已经读取并确认没有标签。
Future<({List<String> names, List<String> ids})> readTransactionSyncTags(
  BeeDatabase db,
  Transaction tx,
  String? ledgerSyncId,
) async {
  final local = await (db.select(db.tags).join([
    d.innerJoin(
        db.transactionTags, db.transactionTags.tagId.equalsExp(db.tags.id)),
  ])
        ..where(db.transactionTags.transactionId.equals(tx.id)))
      .get();
  final tags = local.map((row) => row.readTable(db.tags)).toList();
  final names = tags.map((tag) => tag.name).toList();
  final ids = tags
      .map((tag) => tag.syncId)
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet();
  if (tx.syncId != null) {
    final overrides = db.transactionTagOverrides;
    final shared = db.sharedLedgerTags;
    final rows = await (db.select(overrides).join([
      d.leftOuterJoin(
          shared,
          shared.syncId.equalsExp(overrides.tagSyncId) &
              shared.ledgerSyncId.equals(ledgerSyncId ?? '')),
    ])
          ..where(overrides.transactionSyncId.equals(tx.syncId!)))
        .get();
    for (final row in rows) {
      final id = row.readTable(overrides).tagSyncId;
      final name = row.readTableOrNull(shared)?.name;
      if (ids.add(id) && name != null) names.add(name);
    }
  }
  return (names: names, ids: ids.toList());
}
