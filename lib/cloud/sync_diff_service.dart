import '../data/db.dart';
import '../data/repositories/base_repository.dart';
import '../data/repositories/transaction_repository.dart'
    show TransactionUpdateBySyncIdData;
import '../services/data_import_service.dart';
import '../services/system/logger_service.dart';

/// 同步变更类型
enum SyncChangeType { added, modified, deleted }

/// 单条变更
class SyncChange {
  final SyncChangeType type;

  /// 云端版本（added/modified 有值）
  final ImportTransaction? cloudTransaction;

  /// 本地版本（modified/deleted 有值）
  final Transaction? localTransaction;

  /// 用户是否选中，默认 true
  bool selected;

  /// 变更描述（用于 modified 类型显示差异）
  final List<String> diffDetails;

  SyncChange({
    required this.type,
    this.cloudTransaction,
    this.localTransaction,
    this.selected = true,
    this.diffDetails = const [],
  });
}

/// Diff 预览结果
class SyncPreview {
  final List<SyncChange> changes;

  int get addedCount =>
      changes.where((c) => c.type == SyncChangeType.added).length;

  int get modifiedCount =>
      changes.where((c) => c.type == SyncChangeType.modified).length;

  int get deletedCount =>
      changes.where((c) => c.type == SyncChangeType.deleted).length;

  bool get isEmpty => changes.isEmpty;

  int get selectedCount => changes.where((c) => c.selected).length;

  const SyncPreview({required this.changes});
}

/// 应用变更结果
class SyncApplyResult {
  final int addedCount;
  final int modifiedCount;
  final int deletedCount;

  const SyncApplyResult({
    this.addedCount = 0,
    this.modifiedCount = 0,
    this.deletedCount = 0,
  });

  int get totalCount => addedCount + modifiedCount + deletedCount;
}

/// Diff 计算服务
class SyncDiffService {
  /// 计算本地与云端的差异
  ///
  /// [repo] - 数据仓库
  /// [ledgerId] - 账本 ID
  /// [cloudTransactions] - 云端交易列表（含 syncId）
  /// [localTransactions] - 本地交易列表（可选，不传则自动查询）
  ///
  /// 返回 null 表示云端数据不含 syncId，无法计算 diff
  Future<SyncPreview?> computeDiff({
    required BaseRepository repo,
    required int ledgerId,
    required List<ImportTransaction> cloudTransactions,
    List<Transaction>? localTransactions,
  }) async {
    // 检查云端数据是否含有 syncId
    final hasSyncId = cloudTransactions.any((t) => t.syncId != null);
    if (!hasSyncId && cloudTransactions.isNotEmpty) {
      logger.info('SyncDiff', '云端数据不含 syncId，无法计算 diff');
      return null;
    }

    // 获取本地交易
    final local =
        localTransactions ?? await repo.getTransactionsByLedger(ledgerId);

    // 批量获取本地交易的标签
    final localTxIds = local.map((t) => t.id).toList();
    final tagsMap = localTxIds.isNotEmpty
        ? await repo.getTagsForTransactions(localTxIds)
        : <int, List<Tag>>{};

    // 批量获取本地交易涉及的账户名称
    final accountIds = <int>{};
    for (final tx in local) {
      if (tx.accountId != null) accountIds.add(tx.accountId!);
      if (tx.toAccountId != null) accountIds.add(tx.toAccountId!);
    }
    final accounts = accountIds.isNotEmpty
        ? await repo.getAccountsByIds(accountIds.toList())
        : <Account>[];
    final accountIdToName = <int, String>{};
    for (final acc in accounts) {
      accountIdToName[acc.id] = acc.name;
    }

    // 建立映射：syncId → 交易
    final localBySyncId = <String, Transaction>{};
    for (final tx in local) {
      if (tx.syncId != null) {
        localBySyncId[tx.syncId!] = tx;
      }
    }

    final cloudBySyncId = <String, ImportTransaction>{};
    for (final tx in cloudTransactions) {
      if (tx.syncId != null) {
        cloudBySyncId[tx.syncId!] = tx;
      }
    }

    final changes = <SyncChange>[];

    // 1. 遍历云端交易
    for (final entry in cloudBySyncId.entries) {
      final syncId = entry.key;
      final cloudTx = entry.value;
      final localTx = localBySyncId[syncId];

      if (localTx == null) {
        // 云端有、本地无 → added
        changes.add(SyncChange(
          type: SyncChangeType.added,
          cloudTransaction: cloudTx,
        ));
      } else {
        // 都有，检查是否有差异
        final localTagNames =
            (tagsMap[localTx.id] ?? []).map((t) => t.name).toList()..sort();
        final localAccountName = localTx.accountId != null
            ? accountIdToName[localTx.accountId]
            : null;
        final localToAccountName = localTx.toAccountId != null
            ? accountIdToName[localTx.toAccountId]
            : null;
        final diffs = _compareTx(
          localTx,
          cloudTx,
          localTagNames: localTagNames,
          localAccountName: localAccountName,
          localToAccountName: localToAccountName,
        );
        if (diffs.isNotEmpty) {
          changes.add(SyncChange(
            type: SyncChangeType.modified,
            cloudTransaction: cloudTx,
            localTransaction: localTx,
            diffDetails: diffs,
          ));
        }
        // 相同 → unchanged，不加入变更列表
      }
    }

    // 2. 遍历本地交易，查找本地有但云端无的
    for (final entry in localBySyncId.entries) {
      final syncId = entry.key;
      if (!cloudBySyncId.containsKey(syncId)) {
        // 本地有、云端无 → deleted
        changes.add(SyncChange(
          type: SyncChangeType.deleted,
          localTransaction: entry.value,
        ));
      }
    }

    // 按类型排序：新增 → 修改 → 删除
    changes.sort((a, b) => a.type.index.compareTo(b.type.index));

    logger.info(
        'SyncDiff',
        '差异计算完成: 新增=${changes.where((c) => c.type == SyncChangeType.added).length}, '
            '修改=${changes.where((c) => c.type == SyncChangeType.modified).length}, '
            '删除=${changes.where((c) => c.type == SyncChangeType.deleted).length}');

    return SyncPreview(changes: changes);
  }

  /// 比较本地和云端交易的差异
  List<String> _compareTx(
    Transaction local,
    ImportTransaction cloud, {
    List<String> localTagNames = const [],
    String? localAccountName,
    String? localToAccountName,
  }) {
    final diffs = <String>[];

    if (local.type != cloud.type) {
      diffs.add('类型: ${local.type} → ${cloud.type}');
    }
    if ((local.amount - cloud.amount).abs() > 0.001) {
      diffs.add('金额: ${local.amount} → ${cloud.amount}');
    }
    // 比较时间（精确到秒）
    final localTime = DateTime(
      local.happenedAt.year,
      local.happenedAt.month,
      local.happenedAt.day,
      local.happenedAt.hour,
      local.happenedAt.minute,
      local.happenedAt.second,
    );
    final cloudTime = DateTime(
      cloud.happenedAt.year,
      cloud.happenedAt.month,
      cloud.happenedAt.day,
      cloud.happenedAt.hour,
      cloud.happenedAt.minute,
      cloud.happenedAt.second,
    );
    if (localTime != cloudTime) {
      diffs.add('时间变更');
    }
    if ((local.note ?? '') != (cloud.note ?? '')) {
      diffs.add('备注: "${local.note ?? ''}" → "${cloud.note ?? ''}"');
    }

    // 比较账户
    if (cloud.type == 'transfer') {
      if ((localAccountName ?? '') != (cloud.fromAccountName ?? '')) {
        final from = localAccountName ?? '无';
        final to = cloud.fromAccountName ?? '无';
        diffs.add('转出账户: $from → $to');
      }
      if ((localToAccountName ?? '') != (cloud.toAccountName ?? '')) {
        final from = localToAccountName ?? '无';
        final to = cloud.toAccountName ?? '无';
        diffs.add('转入账户: $from → $to');
      }
    } else {
      if ((localAccountName ?? '') != (cloud.accountName ?? '')) {
        final from = localAccountName ?? '无';
        final to = cloud.accountName ?? '无';
        diffs.add('账户: $from → $to');
      }
    }

    // 比较标签
    final cloudTagNames = List<String>.from(cloud.tagNames ?? [])..sort();
    if (localTagNames.join(',') != cloudTagNames.join(',')) {
      final from = localTagNames.isEmpty ? '无' : localTagNames.join(', ');
      final to = cloudTagNames.isEmpty ? '无' : cloudTagNames.join(', ');
      diffs.add('标签: $from → $to');
    }

    return diffs;
  }

  /// 应用选中的变更
  ///
  /// [repo] - 数据仓库
  /// [ledgerId] - 账本 ID
  /// [selectedChanges] - 用户选中的变更列表
  /// [importData] - 原始导入数据（用于导入分类/账户/标签）
  Future<SyncApplyResult> applySyncChanges({
    required BaseRepository repo,
    required int ledgerId,
    required List<SyncChange> selectedChanges,
    required ImportData importData,
  }) async {
    if (selectedChanges.isEmpty) {
      return const SyncApplyResult();
    }

    // 分类/账户/标签:复用 DataImportService(同一份 batch 优化只在一处维护)
    final categoryCache =
        await dataImportService.importCategories(repo, importData.categories);
    final accountNameToId = await dataImportService.importAccounts(
      repo,
      importData.accounts,
      defaultCurrency: importData.currency ?? 'CNY',
    );
    final tagNameToId =
        await dataImportService.importTags(repo, importData.tags);

    int addedCount = 0;
    int modifiedCount = 0;
    int deletedCount = 0;

    // 按类型分桶 — added 走批量(WebDAV/Supabase 从远端拉账本场景一次可能上万
    // 条全 added,单条 for 循环要几十分钟;modified/deleted 数量通常小,保持
    // 单条 await)
    final addedChanges = <SyncChange>[];
    final modifiedChanges = <SyncChange>[];
    final deletedChanges = <SyncChange>[];
    for (final c in selectedChanges) {
      switch (c.type) {
        case SyncChangeType.added:
          addedChanges.add(c);
          break;
        case SyncChangeType.modified:
          modifiedChanges.add(c);
          break;
        case SyncChangeType.deleted:
          deletedChanges.add(c);
          break;
      }
    }

    // ============ added: 复用 DataImportService 的批量插入路径 ============
    // 把 SyncChange → ImportTransaction(cloudTransaction 本来就是 ImportTransaction
    // 类型),直接交给 DataImportService.importTransactions 走 batch:500 条 /
    // 批,一个 db.transaction 内 batch insert tx + tag + attachment + local_changes,
    // 把 N 次单条 await(WebDAV 1 万条全 added 要几十分钟)折叠成 N/500 批。
    if (addedChanges.isNotEmpty) {
      final addedTxs =
          addedChanges.map((c) => c.cloudTransaction!).toList(growable: false);
      final result = await dataImportService.importTransactions(
        repo,
        ledgerId,
        addedTxs,
        accountNameToId: accountNameToId,
        categoryCache: categoryCache,
        tagNameToId: tagNameToId,
      );
      addedCount = result.inserted;
    }

    // ============ modified: 主表用批量 UPDATE,tag 关联单条 await ============
    // 主表 update 跨 isolate boundary 是 N 次但 BEGIN/COMMIT 一次。tag 更新仍
    // 是 N 次单条(每条 tx 的 tagIds 不同,需要先 DELETE WHERE tx_id = ? 再
    // INSERT 新关联);如果 modified 量大到 tag update 也成瓶颈,后续可加专
    // 门的 batch tag-update 接口。
    if (modifiedChanges.isNotEmpty) {
      final sw = Stopwatch()..start();
      final updates = <TransactionUpdateBySyncIdData>[];
      final tagIdsBySyncId = <String, List<int>>{};
      for (final change in modifiedChanges) {
        final cloud = change.cloudTransaction!;
        final syncId = cloud.syncId!;
        final categoryId = _resolveCategoryId(cloud, categoryCache);
        final accountId = _resolveAccountId(cloud, accountNameToId);
        final toAccountId = _resolveToAccountId(cloud, accountNameToId);
        final tagIds = _resolveTagIds(cloud, tagNameToId).toSet().toList();
        updates.add(TransactionUpdateBySyncIdData(
          syncId: syncId,
          type: cloud.type,
          amount: cloud.amount,
          categoryId: cloud.type == 'transfer' ? null : categoryId,
          accountId: accountId,
          toAccountId: toAccountId,
          happenedAt: cloud.happenedAt,
          note: cloud.note,
        ));
        tagIdsBySyncId[syncId] = tagIds;
      }
      try {
        final syncIdToTxId =
            await repo.updateTransactionsBatchBySyncId(updates);
        modifiedCount = syncIdToTxId.length;
        // tag 关联逐条 update(tag 数量通常很小,这里没批量接口)
        for (final entry in tagIdsBySyncId.entries) {
          final txId = syncIdToTxId[entry.key];
          if (txId == null) continue;
          try {
            await repo.updateTransactionTags(
              transactionId: txId,
              tagIds: entry.value,
            );
          } catch (e, st) {
            logger.error('SyncDiff', 'tag 关联更新失败 syncId=${entry.key}', e, st);
          }
        }
        logger.info('SyncDiff',
            '批量更新: size=${updates.length} 成功=$modifiedCount 耗时=${sw.elapsedMilliseconds}ms');
      } catch (e, st) {
        logger.error('SyncDiff', '批量更新失败', e, st);
      }
    }

    // ============ deleted: 批量按 syncId 删除 ============
    // 有 syncId 的批量走单条 DELETE WHERE IN;没 syncId 的(老数据)兜底单条
    if (deletedChanges.isNotEmpty) {
      final withSyncIds = <String>[];
      final fallbackIds = <int>[];
      for (final change in deletedChanges) {
        final localTx = change.localTransaction!;
        if (localTx.syncId != null && localTx.syncId!.isNotEmpty) {
          withSyncIds.add(localTx.syncId!);
        } else {
          fallbackIds.add(localTx.id);
        }
      }
      if (withSyncIds.isNotEmpty) {
        try {
          final n = await repo.deleteTransactionsBatchBySyncIds(withSyncIds);
          deletedCount += n;
          logger.info(
              'SyncDiff', '批量删除: syncId 路径 size=${withSyncIds.length} 实删=$n');
        } catch (e, st) {
          logger.error('SyncDiff', '批量删除失败', e, st);
        }
      }
      for (final id in fallbackIds) {
        try {
          await repo.deleteTransaction(id);
          deletedCount++;
        } catch (e, st) {
          logger.error('SyncDiff', '兜底单条删除失败 id=$id', e, st);
        }
      }
    }

    logger.info('SyncDiff',
        '变更已应用: 新增=$addedCount, 修改=$modifiedCount, 删除=$deletedCount');

    return SyncApplyResult(
      addedCount: addedCount,
      modifiedCount: modifiedCount,
      deletedCount: deletedCount,
    );
  }

  // --- 辅助方法 ---

  int? _resolveCategoryId(
      ImportTransaction tx, Map<String, int> categoryCache) {
    if (tx.categoryId != null) return tx.categoryId;
    if (tx.categoryName != null && tx.categoryKind != null) {
      return categoryCache['${tx.categoryKind}|${tx.categoryName}'];
    }
    return null;
  }

  int? _resolveAccountId(
      ImportTransaction tx, Map<String, int> accountNameToId) {
    if (tx.type == 'transfer') {
      if (tx.fromAccountName != null) {
        return accountNameToId[tx.fromAccountName];
      }
    } else {
      if (tx.accountName != null) {
        return accountNameToId[tx.accountName];
      }
    }
    return null;
  }

  int? _resolveToAccountId(
      ImportTransaction tx, Map<String, int> accountNameToId) {
    if (tx.type == 'transfer' && tx.toAccountName != null) {
      return accountNameToId[tx.toAccountName];
    }
    return null;
  }

  List<int> _resolveTagIds(ImportTransaction tx, Map<String, int> tagNameToId) {
    if (tx.tagNames == null || tx.tagNames!.isEmpty) return [];
    return tx.tagNames!
        .map((name) => tagNameToId[name])
        .whereType<int>()
        .toList();
  }

  // 分类/账户/标签的导入逻辑统一委托给 DataImportService.importCategories /
  // importAccounts / importTags(本文件之前有 3 个"简化版"副本,跟主文件不
  // 一致 + 双份维护成本,2026-05-24 重构合并)。
}

/// 全局单例
final syncDiffService = SyncDiffService();
