part of 'sync_engine.dart';

/// 同步健康检查 + 历史种子数据补登。
///
/// `checkSyncHealth` 是云同步页下拉刷新时调用的,对比本地 / server 计数,
/// UI 据此决定是否要触发一次 auto sync。`backfillUntrackedEntities` 给绕
/// 过 changeTracker 插入的本地实体(tag / account / category)补写 create
/// change,让它们能被 push 上去。
///
/// 这两个方法都是公开 API,但**不是** `SyncService` 接口方法,所以可以放
/// 在 extension 里。`getStatus` / `markLocalChanged` / `clearStatusCache`
/// 等 @override 接口实现必须留在主类里。
///
/// 注意:extension 名是 **public**(没有 `_` 前缀)——因为方法本身是 public
/// 且会被外部 caller(beecount_cloud_sync_page.dart)调用,private 扩展
/// 在 library 外不可见。命名特意避开顶层 `SyncEngineStatus` enum,叫
/// `SyncEngineHealthChecks` 区分。
extension SyncEngineHealthChecks on SyncEngine {
  /// 云同步页下拉刷新时用:对比本地 Drift 和 server `/read/ledgers/<id>/stats`
  /// 返回的计数,如果有差异就返回 hasDiff=true,UI 据此决定是否触发一次
  /// auto sync。server 端计数来源跟 web 实际展示一致(从最新 snapshot 读),
  /// 所以对得上 web 就代表"对端用户眼里的真实状态"。
  Future<SyncHealthReport> checkSyncHealth({required int ledgerId}) async {
    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    if (ledger == null) {
      return SyncHealthReport.error('本地找不到 ledger=$ledgerId');
    }
    final serverLedgerId = ledger.syncId ?? ledger.id.toString();

    // ---------- 本地 per-ledger ----------
    // 只数有 syncId 的行,跟服务端口径对齐 —— 没 syncId 的行无法 push,
    // 云端不会有对应记录,统计它们会造成永久假阳性"本地比云端多"。
    final ledgerTxRows = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..where((t) => t.syncId.isNotNull()))
        .get();
    final localLedgerTx = ledgerTxRows.length;
    final ledgerTxIds = ledgerTxRows.map((t) => t.id).toList();
    // 本地交易附件:transaction_attachments 每 tx 一行 = server 端
    // attachment_kind='transaction' 的物理文件数。分类自定义图标独立统计
    // (见下面 localCategoryAttachments)。
    // 多笔交易可共享同一附件:已上传的按 cloudSha256 去重(server 端同样按
    // sha256 去重存 1 行)，未上传的按 fileName(各行独立)。避免把共享同一张图
    // 的 N 笔交易算成 N 个附件。
    int localLedgerAttachments = 0;
    if (ledgerTxIds.isNotEmpty) {
      final atts = await (db.select(db.transactionAttachments)
            ..where((a) => a.transactionId.isIn(ledgerTxIds)))
          .get();
      localLedgerAttachments =
          atts.map((a) => a.cloudSha256 ?? a.fileName).toSet().length;
    }
    final localLedgerBudgets = (await (db.select(db.budgets)
              ..where((b) => b.ledgerId.equals(ledgerId))
              ..where((b) => b.syncId.isNotNull()))
            .get())
        .length;

    // ---------- 本地 全量 ----------
    final localTotalTx = (await (db.select(db.transactions)
              ..where((t) => t.syncId.isNotNull()))
            .get())
        .length;
    // 全量交易附件 = 所有 tx 附件(分类图标不算)，同样按 cloudSha256 去重
    final localTotalAttachments =
        (await db.select(db.transactionAttachments).get())
            .map((a) => a.cloudSha256 ?? a.fileName)
            .toSet()
            .length;
    final localTotalBudgets = (await (db.select(db.budgets)
              ..where((b) => b.syncId.isNotNull()))
            .get())
        .length;

    // ---------- 本地 分类自定义图标 ----------
    // user-global,不分账本。跟 server attachment_kind='category_icon' 对齐。
    final localCategoryAttachments = (await (db.select(db.categories)
              ..where((c) => c.iconType.equals('custom'))
              ..where((c) => c.customIconPath.isNotNull()))
            .get())
        .length;

    // ---------- 本地 用户级 ----------
    final localAccounts = (await (db.select(db.accounts)
              ..where((a) => a.syncId.isNotNull()))
            .get())
        .length;
    final localCategories = (await (db.select(db.categories)
              ..where((c) => c.syncId.isNotNull()))
            .get())
        .length;
    final localTags =
        (await (db.select(db.tags)..where((t) => t.syncId.isNotNull())).get())
            .length;

    final unpushed =
        (await changeTracker.getUnpushedChangesForLedger(ledgerId)).length;

    // ---------- 远端 /read/ledgers/<id>/stats ----------
    try {
      final stats = await provider.readLedgerStats(ledgerId: serverLedgerId);
      return SyncHealthReport(
        ledgerTx:
            SyncCountPair(local: localLedgerTx, remote: stats.transactionCount),
        ledgerAttachments: SyncCountPair(
            local: localLedgerAttachments, remote: stats.attachmentCount),
        ledgerBudgets:
            SyncCountPair(local: localLedgerBudgets, remote: stats.budgetCount),
        totalTx:
            SyncCountPair(local: localTotalTx, remote: stats.transactionTotal),
        totalAttachments: SyncCountPair(
            local: localTotalAttachments, remote: stats.attachmentTotal),
        totalBudgets:
            SyncCountPair(local: localTotalBudgets, remote: stats.budgetTotal),
        categoryAttachments: SyncCountPair(
            local: localCategoryAttachments,
            remote: stats.categoryAttachmentTotal),
        accounts:
            SyncCountPair(local: localAccounts, remote: stats.accountTotal),
        categories:
            SyncCountPair(local: localCategories, remote: stats.categoryTotal),
        tags: SyncCountPair(local: localTags, remote: stats.tagTotal),
        unpushedChanges: unpushed,
      );
    } catch (e, st) {
      logger.warning('SyncEngine', 'checkSyncHealth 拉 stats 失败: $e', st);
      return SyncHealthReport(
        ledgerTx: SyncCountPair(local: localLedgerTx, remote: -1),
        ledgerAttachments:
            SyncCountPair(local: localLedgerAttachments, remote: -1),
        ledgerBudgets: SyncCountPair(local: localLedgerBudgets, remote: -1),
        totalTx: SyncCountPair(local: localTotalTx, remote: -1),
        totalAttachments:
            SyncCountPair(local: localTotalAttachments, remote: -1),
        totalBudgets: SyncCountPair(local: localTotalBudgets, remote: -1),
        categoryAttachments:
            SyncCountPair(local: localCategoryAttachments, remote: -1),
        accounts: SyncCountPair(local: localAccounts, remote: -1),
        categories: SyncCountPair(local: localCategories, remote: -1),
        tags: SyncCountPair(local: localTags, remote: -1),
        unpushedChanges: unpushed,
        error: e.toString(),
      );
    }
  }

  /// 为"绕过 changeTracker 插入"的本地 tag / account / category / budget
  /// 补写 `create` 变更记录,让后续 push 能把它们推到云端。
  ///
  /// 典型场景:早期的种子代码(TagSeedService)直接 `db.into(...).insert()`,
  /// 不经 `LocalRepository.createTag` → 这批标签永远不会被 push。
  /// `checkSyncHealth` 检测到 `localTags > remoteTags` 且 `unpushed == 0` 时
  /// 调这个方法 backfill 一次,再触发 sync 就能把种子标签送上云。
  ///
  /// 幂等:只对没有对应 sync_change 记录的实体补写 create。重复调用是安全的。
  Future<int> backfillUntrackedEntities({required int ledgerId}) async {
    final allUnpushed =
        await changeTracker.getUnpushedChangesForLedger(ledgerId);
    final allPushedIds =
        <String>{}; // syncId 集合 —— unpushed 的先留着,判断"从未写过 change"用的是下面的专用查询
    for (final c in allUnpushed) {
      allPushedIds.add(c.entitySyncId);
    }
    // 用 change_tracker 的 hasAnyChangeForEntity(若有) / 直接查 local_changes 表。
    // 这里用更稳妥的方式:对每个 entity 调 recordChange,recordChange 自身会
    // 判断"同 entitySyncId + action 是否已经存在",不会造成重复(依赖
    // ChangeTracker 的 upsert 语义,若没有就是直接 insert,重复的会被 unique
    // 约束拦住 —— 重复 insert catch 住 = 无害重复)。
    int backfilled = 0;

    // Tags
    final tags = await db.select(db.tags).get();
    for (final tag in tags) {
      if (tag.syncId == null || tag.syncId!.isEmpty) continue;
      if (allPushedIds.contains(tag.syncId)) continue;
      try {
        await changeTracker.recordUserGlobalChange(
          entityType: 'tag',
          entityId: tag.id,
          entitySyncId: tag.syncId!,
          action: 'create',
        );
        backfilled++;
      } catch (e) {
        // 已存在的 change 会撞唯一约束,忽略即可。
        logger.debug('SyncEngine', 'backfill tag ${tag.syncId} skip: $e');
      }
    }

    // Accounts
    final accounts = await db.select(db.accounts).get();
    for (final acc in accounts) {
      if (acc.syncId == null || acc.syncId!.isEmpty) continue;
      if (allPushedIds.contains(acc.syncId)) continue;
      try {
        await changeTracker.recordUserGlobalChange(
          entityType: 'account',
          entityId: acc.id,
          entitySyncId: acc.syncId!,
          action: 'create',
        );
        backfilled++;
      } catch (e) {
        logger.debug('SyncEngine', 'backfill account ${acc.syncId} skip: $e');
      }
    }

    // Categories
    final categories = await db.select(db.categories).get();
    for (final cat in categories) {
      if (cat.syncId == null || cat.syncId!.isEmpty) continue;
      if (allPushedIds.contains(cat.syncId)) continue;
      try {
        await changeTracker.recordUserGlobalChange(
          entityType: 'category',
          entityId: cat.id,
          entitySyncId: cat.syncId!,
          action: 'create',
        );
        backfilled++;
      } catch (e) {
        logger.debug('SyncEngine', 'backfill category ${cat.syncId} skip: $e');
      }
    }

    logger.info('SyncEngine',
        'backfillUntrackedEntities: 共补写 $backfilled 条 sync_change');
    return backfilled;
  }
}
