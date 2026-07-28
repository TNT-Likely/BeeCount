import 'dart:convert';

import 'package:drift/drift.dart' as d;

import '../data/db.dart';
import '../data/repositories/base_repository.dart';
import '../data/repositories/budget_repository.dart'
    show BudgetRestoreBySyncIdData;
import '../data/repositories/transaction_repository.dart'
    show
        BatchAttachmentData,
        TransactionRelationsUpdateBySyncIdData,
        TransactionUpdateBySyncIdData;
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
    final attachmentsMap = localTxIds.isNotEmpty &&
            cloudTransactions.any((tx) => tx.attachmentsPresent)
        ? await repo.getAttachmentsForTransactions(localTxIds)
        : <int, List<TransactionAttachment>>{};

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
        final localAttachments = cloudTx.attachmentsPresent
            ? attachmentsMap[localTx.id] ?? const <TransactionAttachment>[]
            : const <TransactionAttachment>[];
        final diffs = _compareTx(
          localTx,
          cloudTx,
          localTagNames: localTagNames,
          localAccountName: localAccountName,
          localToAccountName: localToAccountName,
          localAttachments: localAttachments,
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
    List<TransactionAttachment> localAttachments = const [],
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

    // 比较标签（缺席表示保留本地关系）
    if (cloud.tagNamesPresent) {
      final cloudTagNames = List<String>.from(cloud.tagNames ?? [])..sort();
      if (localTagNames.join(',') != cloudTagNames.join(',')) {
        final from = localTagNames.isEmpty ? '无' : localTagNames.join(', ');
        final to = cloudTagNames.isEmpty ? '无' : cloudTagNames.join(', ');
        diffs.add('标签: $from → $to');
      }
    }

    // v31: 项目预算关联。仅当 payload 显式带键时(v7+)才比较,否则视为"未
    // 提供,保留本地"(避免 v6 备份被误判为清除)。**清除**(local 有 → cloud
    // null)和**关联**(local != cloud)都需报为差异,让 modified 分支进入
    // batch update 路径把关联同步过去。
    if (cloud.projectBudgetSyncIdPresent) {
      final localLink = local.projectBudgetSyncId ?? '';
      final cloudLink = cloud.projectBudgetSyncId ?? '';
      if (localLink != cloudLink) {
        final from = localLink.isEmpty ? '无' : localLink;
        final to = cloudLink.isEmpty ? '无' : cloudLink;
        diffs.add('专项预算: $from → $to');
      }
    }

    if (cloud.attachmentsPresent &&
        !_sameCanonicalAttachments(
            localAttachments, cloud.attachments ?? const [])) {
      diffs.add('附件变更');
    }

    return diffs;
  }

  bool _sameCanonicalAttachments(
    List<TransactionAttachment> local,
    List<ImportAttachment> cloud,
  ) {
    final localTuples = local.map(_canonicalLocalAttachment).toList()..sort();
    final cloudTuples = cloud.map(_canonicalCloudAttachment).toList()..sort();
    if (localTuples.length != cloudTuples.length) return false;
    for (var i = 0; i < localTuples.length; i++) {
      if (localTuples[i] != cloudTuples[i]) return false;
    }
    return true;
  }

  String _canonicalLocalAttachment(TransactionAttachment attachment) =>
      _canonicalAttachment(
        fileName: attachment.fileName,
        originalName: attachment.originalName,
        fileSize: attachment.fileSize,
        width: attachment.width,
        height: attachment.height,
        sortOrder: attachment.sortOrder,
        cloudFileId: attachment.cloudFileId,
        cloudSha256: attachment.cloudSha256,
      );

  String _canonicalCloudAttachment(ImportAttachment attachment) =>
      _canonicalAttachment(
        fileName: attachment.fileName,
        originalName: attachment.originalName,
        fileSize: attachment.fileSize,
        width: attachment.width,
        height: attachment.height,
        sortOrder: attachment.sortOrder,
        cloudFileId: attachment.cloudFileId,
        cloudSha256: attachment.cloudSha256,
      );

  String _canonicalAttachment({
    required String fileName,
    required String? originalName,
    required int? fileSize,
    required int? width,
    required int? height,
    required int sortOrder,
    required String? cloudFileId,
    required String? cloudSha256,
  }) =>
      jsonEncode({
        'fileName': fileName,
        'originalName': originalName,
        'fileSize': fileSize,
        'width': width,
        'height': height,
        'sortOrder': sortOrder,
        'cloudFileId': cloudFileId,
        'cloudSha256': cloudSha256,
      });

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

    // Project payload 只建立索引；metadata dependencies 在每个实际应用单元内
    // 按 selected transaction 的引用最小化导入并随该单元一起提交/回滚。
    final projectBudgetPayloadBySyncId = <String, ImportBudget>{
      for (final budget in importData.budgets)
        if (budget.type == 'project') budget.syncId: budget,
    };

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

    // ============ added:500 条 strict batch fast path,失败后二分隔离 ============
    if (addedChanges.isNotEmpty) {
      const chunkSize = 500;
      final addedTransactions = [
        for (final change in addedChanges) change.cloudTransaction!,
      ];
      for (var offset = 0;
          offset < addedTransactions.length;
          offset += chunkSize) {
        final end = (offset + chunkSize).clamp(0, addedTransactions.length);
        addedCount += await _applyAddedChunkWithIsolation(
          repo: repo,
          ledgerId: ledgerId,
          importData: importData,
          projectBudgetPayloadBySyncId: projectBudgetPayloadBySyncId,
          transactions: addedTransactions.sublist(offset, end),
        );
      }
    }

    // ============ modified: 每条主表 + 关系集合原子更新 ============
    if (modifiedChanges.isNotEmpty) {
      final sw = Stopwatch()..start();
      for (final change in modifiedChanges) {
        final cloud = change.cloudTransaction!;
        try {
          final applied = await repo.runInTransaction(() async {
            final deps = await _importSelectedDependencies(
              repo: repo,
              importData: importData,
              transactions: [cloud],
            );
            BudgetRestoreBySyncIdData? missingProject;
            if (cloud.projectBudgetSyncId != null) {
              final project = await repo
                  .getProjectBudgetBySyncId(cloud.projectBudgetSyncId!);
              if (project == null) {
                final payload =
                    projectBudgetPayloadBySyncId[cloud.projectBudgetSyncId!];
                if (payload == null) {
                  throw StateError(
                      'projectBudgetSyncId 缺少可恢复 payload: ${cloud.projectBudgetSyncId}');
                }
                missingProject = BudgetRestoreBySyncIdData(
                  syncId: payload.syncId,
                  ledgerId: ledgerId,
                  type: payload.type,
                  categoryId: null,
                  amount: payload.amount,
                  period: payload.period,
                  startDay: payload.startDay,
                  enabled: payload.enabled,
                  name: payload.name,
                  startAt: payload.startAt,
                  endAt: payload.endAt,
                  excludeFromMonthlyTotal: payload.excludeFromMonthlyTotal,
                  status: payload.status,
                );
              } else if (project.ledgerId != ledgerId) {
                throw StateError(
                    'projectBudgetSyncId 未解析为同账本 project: ${cloud.projectBudgetSyncId}');
              }
            }
            final categoryId = _resolveCategoryId(cloud, deps.categoryCache);
            final accountId = _resolveAccountId(cloud, deps.accountNameToId);
            final toAccountId =
                _resolveToAccountId(cloud, deps.accountNameToId);
            final tagIds = cloud.tagNamesPresent
                ? _resolveTagIds(cloud, deps.tagNameToId).toSet().toList()
                : null;
            final attachments = cloud.attachmentsPresent
                ? (cloud.attachments ?? const <ImportAttachment>[])
                    .map((attachment) => BatchAttachmentData(
                          fileName: attachment.fileName,
                          originalName: attachment.originalName,
                          fileSize: attachment.fileSize,
                          width: attachment.width,
                          height: attachment.height,
                          sortOrder: attachment.sortOrder,
                          cloudFileId: attachment.cloudFileId,
                          cloudSha256: attachment.cloudSha256,
                        ))
                    .toList(growable: false)
                : null;
            final transactionId = await repo
                .updateTransactionWithRelationsAndOptionalProjectBySyncId(
              TransactionRelationsUpdateBySyncIdData(
                transaction: TransactionUpdateBySyncIdData(
                  syncId: cloud.syncId!,
                  type: cloud.type,
                  amount: cloud.amount,
                  categoryId: cloud.type == 'transfer' ? null : categoryId,
                  accountId: accountId,
                  toAccountId: toAccountId,
                  happenedAt: cloud.happenedAt,
                  note: cloud.note,
                  projectBudgetSyncId: cloud.projectBudgetSyncIdPresent
                      ? d.Value<String?>(cloud.projectBudgetSyncId)
                      : const d.Value<String?>.absent(),
                ),
                tagIds: tagIds,
                attachments: attachments,
              ),
              missingProject: missingProject,
              recordChanges: true,
            );
            if (transactionId == null) {
              throw StateError(
                  'selected modified transaction disappeared: ${cloud.syncId}');
            }
            return true;
          });
          if (applied) modifiedCount++;
        } catch (e, st) {
          logger.error('SyncDiff', '修改交易失败 syncId=${cloud.syncId}', e, st);
        }
      }
      logger.info('SyncDiff',
          '原子更新: size=${modifiedChanges.length} 成功=$modifiedCount 耗时=${sw.elapsedMilliseconds}ms');
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

  Future<int> _applyAddedChunkWithIsolation({
    required BaseRepository repo,
    required int ledgerId,
    required ImportData importData,
    required Map<String, ImportBudget> projectBudgetPayloadBySyncId,
    required List<ImportTransaction> transactions,
  }) async {
    try {
      return await _applyAddedChunkStrict(
        repo: repo,
        ledgerId: ledgerId,
        importData: importData,
        projectBudgetPayloadBySyncId: projectBudgetPayloadBySyncId,
        transactions: transactions,
      );
    } catch (_) {
      if (transactions.length == 1) {
        logger.warning(
          'SyncDiff',
          'selected added item failed syncId=${transactions.single.syncId ?? '<new>'}',
        );
        return 0;
      }
      final middle = transactions.length ~/ 2;
      return await _applyAddedChunkWithIsolation(
            repo: repo,
            ledgerId: ledgerId,
            importData: importData,
            projectBudgetPayloadBySyncId: projectBudgetPayloadBySyncId,
            transactions: transactions.sublist(0, middle),
          ) +
          await _applyAddedChunkWithIsolation(
            repo: repo,
            ledgerId: ledgerId,
            importData: importData,
            projectBudgetPayloadBySyncId: projectBudgetPayloadBySyncId,
            transactions: transactions.sublist(middle),
          );
    }
  }

  Future<int> _applyAddedChunkStrict({
    required BaseRepository repo,
    required int ledgerId,
    required ImportData importData,
    required Map<String, ImportBudget> projectBudgetPayloadBySyncId,
    required List<ImportTransaction> transactions,
  }) {
    return repo.runInTransaction(() async {
      final deps = await _importSelectedDependencies(
        repo: repo,
        importData: importData,
        transactions: transactions,
      );
      final projectSyncIds = transactions
          .map((transaction) => transaction.projectBudgetSyncId)
          .whereType<String>()
          .toSet();
      for (final syncId in projectSyncIds) {
        final existing = await repo.getProjectBudgetBySyncId(syncId);
        if (existing != null) {
          if (existing.ledgerId != ledgerId) {
            throw StateError(
                'projectBudgetSyncId must reference a same-ledger project');
          }
          continue;
        }
        final payload = projectBudgetPayloadBySyncId[syncId];
        if (payload == null) {
          throw StateError('selected project dependency payload is missing');
        }
        final restored = await dataImportService.importBudgets(
          repo,
          ledgerId,
          [payload],
          categoryCache: deps.categoryCache,
          recordChanges: false,
        );
        if (restored != 1) {
          throw StateError('selected project dependency import failed');
        }
      }
      final result = await dataImportService.importTransactions(
        repo,
        ledgerId,
        transactions,
        accountNameToId: deps.accountNameToId,
        categoryCache: deps.categoryCache,
        tagNameToId: deps.tagNameToId,
        strict: true,
      );
      if (result.inserted != transactions.length || result.failed != 0) {
        throw StateError('selected added chunk import failed');
      }
      return result.inserted;
    });
  }

  // --- 辅助方法 ---

  Future<
      ({
        Map<String, int> categoryCache,
        Map<String, int> accountNameToId,
        Map<String, int> tagNameToId,
      })> _importSelectedDependencies({
    required BaseRepository repo,
    required ImportData importData,
    required Iterable<ImportTransaction> transactions,
  }) async {
    final txs = transactions.toList(growable: false);
    final accountNames = <String>{
      for (final tx in txs)
        if (tx.accountName != null) tx.accountName!,
      for (final tx in txs)
        if (tx.fromAccountName != null) tx.fromAccountName!,
      for (final tx in txs)
        if (tx.toAccountName != null) tx.toAccountName!,
    };
    final tagNames = <String>{
      for (final tx in txs) ...?tx.tagNames,
    };
    final categoryKeys = <String>{
      for (final tx in txs)
        if (tx.categoryName != null && tx.categoryKind != null)
          '${tx.categoryKind}|${tx.categoryName}',
    };
    // 二级分类导入依赖父分类；闭包扩展保证任意顺序的 payload 都完整。
    var expanded = true;
    while (expanded) {
      expanded = false;
      for (final category in importData.categories) {
        final key = '${category.kind}|${category.name}';
        if (categoryKeys.contains(key) && category.parentName != null) {
          expanded =
              categoryKeys.add('${category.kind}|${category.parentName}') ||
                  expanded;
        }
      }
    }

    final categories = importData.categories
        .where((category) =>
            categoryKeys.contains('${category.kind}|${category.name}'))
        .toList(growable: false);
    final accounts = importData.accounts
        .where((account) => accountNames.contains(account.name))
        .toList(growable: false);
    final tags = importData.tags
        .where((tag) => tagNames.contains(tag.name))
        .toList(growable: false);

    final categoryCache = await dataImportService.importCategories(
      repo,
      categories,
      strict: true,
    );
    final accountNameToId = await dataImportService.importAccounts(
      repo,
      accounts,
      defaultCurrency: importData.currency ?? 'CNY',
      strict: true,
    );
    final tagNameToId = await dataImportService.importTags(
      repo,
      tags,
      strict: true,
    );
    if (!categoryKeys.every(categoryCache.containsKey)) {
      throw StateError('selected category dependency did not resolve');
    }
    if (!accountNames.every(accountNameToId.containsKey)) {
      throw StateError('selected account dependency did not resolve');
    }
    if (!tagNames.every(tagNameToId.containsKey)) {
      throw StateError('selected tag dependency did not resolve');
    }
    return (
      categoryCache: categoryCache,
      accountNameToId: accountNameToId,
      tagNameToId: tagNameToId,
    );
  }

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
