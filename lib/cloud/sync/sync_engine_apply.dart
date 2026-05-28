part of 'sync_engine.dart';

/// pull 路径上把远端变更应用到本地 Drift 的逻辑。`_applyRemoteChange` 是
/// 总入口分发器,按 entity_type 分到具体的 `_apply*Change` handler。
///
/// 这里所有方法都是 private(以 `_` 开头),只在主 library 内被 `_pull` 调
/// 用,所以 extension 可以保持 private。
extension SyncEngineApplyExt on SyncEngine {
  /// 应用单条远程变更到本地数据库
  /// 返回 true 表示已应用，false 表示跳过
  Future<bool> applyRemoteChange(BeeCountCloudSyncChange change) async {
    // 跳过本设备自己的变更
    final deviceId = await _getDeviceId();
    if (change.updatedByDeviceId == deviceId) return false;

    // 如果没有 payload 且不是删除操作，跳过（无法应用）
    if (change.payload == null && change.action != 'delete') {
      logger.debug('SyncEngine',
          'pull: 跳过无 payload 的变更 ${change.entityType}/${change.entitySyncId}');
      return false;
    }

    switch (change.entityType) {
      case 'transaction':
        await _applyTransactionChange(change);
        return true;
      case 'account':
        await _applyAccountChange(change);
        return true;
      case 'category':
        await _applyCategoryChange(change);
        return true;
      case 'tag':
        await _applyTagChange(change);
        return true;
      case 'budget':
        await _applyBudgetChange(change);
        return true;
      case 'ledger':
        await _applyLedgerChange(change);
        return true;
      case 'ledger_snapshot':
        // 全量快照在 fullPull 中处理，这里跳过
        return false;
      default:
        logger.warning(
            'SyncEngine', '未知 entityType: ${change.entityType}');
        return false;
    }
  }

  // ==================== Apply 方法 ====================

  Future<void> _applyTransactionChange(
      BeeCountCloudSyncChange change) async {
    final syncId = change.entitySyncId;

    if (change.action == 'delete') {
      // delete 路径:先看 cache 拿 id(避免 N+1 SELECT);cache miss 再 DB
      final cachedTx = activePullCache?.transaction(syncId);
      int? existingId = cachedTx?.id;
      if (existingId == null && activePullCache == null) {
        final existing = await (db.select(db.transactions)
              ..where((t) => t.syncId.equals(syncId)))
            .getSingleOrNull();
        existingId = existing?.id;
      }
      if (existingId != null) {
        // 先清磁盘附件(原图 + 缩略图),再删 transaction_attachments 行 ——
        // 反过来就查不到 fileName 了。
        await _cleanupTxAttachmentFilesOnDisk(existingId);
        await (db.delete(db.transactionTags)
              ..where((tt) => tt.transactionId.equals(existingId!)))
            .go();
        await (db.delete(db.transactionAttachments)
              ..where((ta) => ta.transactionId.equals(existingId!)))
            .go();
        await (db.delete(db.transactions)
              ..where((t) => t.id.equals(existingId!)))
            .go();
        activePullCache?.removeTransaction(syncId);
        logger.debug('SyncEngine', 'pull: 删除交易 $syncId');
      }
      return;
    }

    // upsert
    final payload = change.payload!;
    // change.ledgerId 是 server 的 external_id（string）。本地 B 设备 auto-
    // increment int id 跟 server 不一致，必须按 syncId 查本地 int id。
    // 只有没命中时才 fallback 到直接 parse（向后兼容老数据 ledger_id 就是
    // int 字符串的场景）。
    final ledgerIdInt =
        await _resolveLedgerIdBySyncId(change.ledgerId) ??
            int.tryParse(change.ledgerId) ??
            -1;

    // 解析 payload 字段
    final type = payload['type'] as String? ?? 'expense';
    final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
    final happenedAtStr = payload['happenedAt'] as String?;
    final happenedAt = happenedAtStr != null
        ? DateTime.tryParse(happenedAtStr)?.toLocal() ?? DateTime.now()
        : DateTime.now();
    final note = payload['note'] as String?;
    final categoryName = payload['categoryName'] as String?;
    final categoryKind = payload['categoryKind'] as String?;
    // web 端创建转账时 account_name/account_id 是 null,只填 from_account_*。
    // mobile 模型用 accountId 表示 from 账户,所以转账 payload 转换:
    //   - account_name = accountName ?? fromAccountName
    //   - accountId = payload.accountId ?? payload.fromAccountId
    // 否则 B 同步 A 转账 tx 时 accountId=null,picker 显示无账户。
    final isTransfer = type == 'transfer';
    final accountName = (payload['accountName'] as String?) ??
        (isTransfer ? payload['fromAccountName'] as String? : null);
    final toAccountName = payload['toAccountName'] as String?;

    // 解析关联实体 ID —— 优先用 syncId 映射（跨设备稳定），fallback 到名字。
    // payload 里的 categoryId / accountId / toAccountId 是 server snapshot.items[i]
    // 存的远端实体 syncId，B 设备 pull 后 category/account 已经上 syncId 了
    // （P1 的 fallback 给 seed 补的，或 pull 新插入带的），按 syncId 查一定命中。
    // 名字 fallback 兜住旧 snapshot payload 没 syncId 的老数据。
    // §7 v25:server payload.categoryId / accountId / toAccountId 是 syncId。
    // 主表反查不到时(Editor 视角看 Owner 的 tx),检查 SharedLedger* 表 —
    // 命中则写 *SyncIdOverride 字段(本地 int id 留 null)。
    final rawCategoryId = payload['categoryId'] as String?;
    int? categoryId = await _resolveCategoryIdBySyncId(rawCategoryId) ??
        await _resolveCategoryId(
          categoryName: categoryName,
          categoryKind: categoryKind,
        );
    String? categorySyncIdOverride;
    if (categoryId == null && rawCategoryId != null && rawCategoryId.isNotEmpty) {
      final shared = await (db.select(db.sharedLedgerCategories)
            ..where((t) => t.syncId.equals(rawCategoryId)))
          .getSingleOrNull();
      if (shared != null) categorySyncIdOverride = shared.syncId;
    }

    final rawAccountId = (payload['accountId'] as String?) ??
        (isTransfer ? payload['fromAccountId'] as String? : null);
    int? accountId = await _resolveAccountIdBySyncId(rawAccountId) ??
        await _resolveAccountId(
          accountName: accountName,
          ledgerId: ledgerIdInt,
        );
    String? accountSyncIdOverride;
    if (accountId == null && rawAccountId != null && rawAccountId.isNotEmpty) {
      final shared = await (db.select(db.sharedLedgerAccounts)
            ..where((t) => t.syncId.equals(rawAccountId)))
          .getSingleOrNull();
      if (shared != null) accountSyncIdOverride = shared.syncId;
    }

    final rawToAccountId = payload['toAccountId'] as String?;
    int? toAccountId = await _resolveAccountIdBySyncId(rawToAccountId) ??
        await _resolveAccountId(
          accountName: toAccountName,
          ledgerId: ledgerIdInt,
        );
    String? toAccountSyncIdOverride;
    if (toAccountId == null && rawToAccountId != null && rawToAccountId.isNotEmpty) {
      final shared = await (db.select(db.sharedLedgerAccounts)
            ..where((t) => t.syncId.equals(rawToAccountId)))
          .getSingleOrNull();
      if (shared != null) toAccountSyncIdOverride = shared.syncId;
    }

    // 查 existing 优先走 LookupCache(prime 时已全表加载 transactions 的
    // syncId / id / createdByUserId),消除 10k 条 = 10k 次 SELECT 的 N+1。
    // miss(冷启动新设备 / 老数据)再走 DB。
    final cachedTx = activePullCache?.transaction(syncId);
    int? existingId = cachedTx?.id;
    String? existingCreatedByUserId = cachedTx?.createdByUserId;
    if (existingId == null && activePullCache == null) {
      final existing = await (db.select(db.transactions)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();
      existingId = existing?.id;
      existingCreatedByUserId = existing?.createdByUserId;
    }

    // 共享账本(v24):server 注入 createdByUserId / updatedByUserId,本地用来
    // 在 tx 末尾显示"X 记的"。payload 用 camelCase(server snapshot_mutator 出来的
    // 字段是 createdByUserId/updatedByUserId,跟 Drift 列名 createdByUserId /
    // lastEditedByUserId 对齐)。
    final createdByUserId = payload['createdByUserId'] as String?;
    final lastEditedByUserId = (payload['updatedByUserId'] as String?) ?? createdByUserId;

    if (existingId != null) {
      // 更新 — createdByUserId 走"本地为 null 就回填,否则保持"的策略。
      final shouldBackfillCreator =
          existingCreatedByUserId == null && createdByUserId != null;
      await (db.update(db.transactions)
            ..where((t) => t.id.equals(existingId!)))
          .write(TransactionsCompanion(
        type: d.Value(type),
        amount: d.Value(amount),
        happenedAt: d.Value(happenedAt),
        note: d.Value(note),
        categoryId: d.Value(categoryId),
        accountId: d.Value(accountId),
        toAccountId: d.Value(toAccountId),
        categorySyncIdOverride: d.Value(categorySyncIdOverride),
        accountSyncIdOverride: d.Value(accountSyncIdOverride),
        toAccountSyncIdOverride: d.Value(toAccountSyncIdOverride),
        createdByUserId: shouldBackfillCreator
            ? d.Value(createdByUserId)
            : const d.Value.absent(),
        lastEditedByUserId: d.Value(lastEditedByUserId),
      ));
      // 更新标签和附件(existing 路径)
      await _syncTransactionTags(existingId, syncId, payload);
      await _syncTransactionAttachments(existingId, payload);
      logger.debug('SyncEngine', 'pull: 更新交易 $syncId');
    } else {
      // 插入
      final id = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerIdInt,
              type: type,
              amount: amount,
              happenedAt: d.Value(happenedAt),
              note: d.Value(note),
              categoryId: d.Value(categoryId),
              accountId: d.Value(accountId),
              toAccountId: d.Value(toAccountId),
              syncId: d.Value(syncId),
              createdByUserId: d.Value(createdByUserId),
              lastEditedByUserId: d.Value(lastEditedByUserId),
              categorySyncIdOverride: d.Value(categorySyncIdOverride),
              accountSyncIdOverride: d.Value(accountSyncIdOverride),
              toAccountSyncIdOverride: d.Value(toAccountSyncIdOverride),
            ),
          );
      // 写回 cache,后续同 syncId 的 update change 能命中
      activePullCache?.putTransaction(syncId, id, createdByUserId);
      // 同步标签和附件(新插入路径 — existing 必空,跳过相关 SELECT/DELETE)
      await _syncTransactionTags(id, syncId, payload, isNewlyInserted: true);
      await _syncTransactionAttachments(id, payload, isNewlyInserted: true);
      logger.debug('SyncEngine', 'pull: 新增交易 $syncId');
    }
  }

  Future<void> _applyAccountChange(BeeCountCloudSyncChange change) async {
    final syncId = change.entitySyncId;
    // ledger_id 也按 syncId 映射到本地 int。account 表 ledgerId 是 legacy
    // 字段，但 insert 时仍需填个有效值；映射失败再 fallback 到旧格式。
    final ledgerIdInt =
        await _resolveLedgerIdBySyncId(change.ledgerId) ??
            int.tryParse(change.ledgerId) ??
            -1;

    if (change.action == 'delete') {
      final existing = await (db.select(db.accounts)
            ..where((a) => a.syncId.equals(syncId)))
          .getSingleOrNull();
      if (existing != null) {
        await (db.delete(db.accounts)
              ..where((a) => a.id.equals(existing.id)))
            .go();
        logger.debug('SyncEngine', 'pull: 删除账户 $syncId');
      }
      return;
    }

    // upsert
    final payload = change.payload!;
    final name = payload['name'] as String? ?? '';
    final type = payload['type'] as String? ?? 'cash';
    final currency = payload['currency'] as String? ?? 'CNY';
    final initialBalance =
        (payload['initialBalance'] as num?)?.toDouble() ?? 0.0;
    final sortOrder = (payload['sortOrder'] as num?)?.toInt() ?? 0;

    var existing = await (db.select(db.accounts)
          ..where((a) => a.syncId.equals(syncId)))
        .getSingleOrNull();

    // Fallback：syncId 查不到 → 本地可能是 seed 默认账户（syncId 为 NULL），
    // 按 name 匹配一条 NULL syncId 的行，把 syncId 补上，后面走 update 分支。
    // 这样 device B 首次 pull 远端账户不会再插第二份同名 seed。
    if (existing == null && name.isNotEmpty) {
      final seeded = await (db.select(db.accounts)
            ..where((a) => a.name.equals(name))
            ..where((a) => a.syncId.isNull()))
          .getSingleOrNull();
      if (seeded != null) {
        await (db.update(db.accounts)..where((a) => a.id.equals(seeded.id)))
            .write(AccountsCompanion(syncId: d.Value(syncId)));
        existing = seeded;
        logger.info('SyncEngine',
            'pull: 收编本地 seed 账户 name="$name" → syncId=$syncId');
      }
    }

    final int localId;
    if (existing != null) {
      localId = existing.id;
      await (db.update(db.accounts)
            ..where((a) => a.id.equals(localId)))
          .write(AccountsCompanion(
        name: d.Value(name),
        type: d.Value(type),
        currency: d.Value(currency),
        initialBalance: d.Value(initialBalance),
        sortOrder: d.Value(sortOrder),
        creditLimit: d.Value((payload['creditLimit'] as num?)?.toDouble()),
        billingDay: d.Value((payload['billingDay'] as num?)?.toInt()),
        paymentDueDay:
            d.Value((payload['paymentDueDay'] as num?)?.toInt()),
        bankName: d.Value(payload['bankName'] as String?),
        cardLastFour: d.Value(payload['cardLastFour'] as String?),
        note: d.Value(payload['note'] as String?),
      ));
      logger.debug('SyncEngine', 'pull: 更新账户 $syncId');
    } else {
      localId = await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              ledgerId: ledgerIdInt,
              name: name,
              type: d.Value(type),
              currency: d.Value(currency),
              initialBalance: d.Value(initialBalance),
              sortOrder: d.Value(sortOrder),
              creditLimit:
                  d.Value((payload['creditLimit'] as num?)?.toDouble()),
              billingDay:
                  d.Value((payload['billingDay'] as num?)?.toInt()),
              paymentDueDay:
                  d.Value((payload['paymentDueDay'] as num?)?.toInt()),
              bankName: d.Value(payload['bankName'] as String?),
              cardLastFour:
                  d.Value(payload['cardLastFour'] as String?),
              note: d.Value(payload['note'] as String?),
              syncId: d.Value(syncId),
            ),
          );
      activePullCache?.putAccount(syncId, localId);
      logger.debug('SyncEngine', 'pull: 新增账户 $syncId');
    }

    // 登记"已从 server 拉到本地"的标记,防止 _backfillLegacyUserGlobalChanges
    // 误把 device B pull 来的实体当 legacy 重推。详见 [ChangeTracker.recordPulledFromServer]。
    await changeTracker.recordPulledFromServer(
      entityType: 'account',
      entityId: localId,
      entitySyncId: syncId,
      ledgerId: 0,
    );
  }

  Future<void> _applyCategoryChange(
      BeeCountCloudSyncChange change) async {
    final syncId = change.entitySyncId;

    if (change.action == 'delete') {
      final existing = await (db.select(db.categories)
            ..where((c) => c.syncId.equals(syncId)))
          .getSingleOrNull();
      if (existing != null) {
        // 先收集自身 + 子分类的 customIconPath 清磁盘。跟 LocalCategoryRepository
        // .deleteCategory 路径对齐,防止 sync pull 下来的分类删除留下孤立图标。
        await _cleanupCategoryIconFilesOnDisk([existing.id]);
        // 先删子分类再删自身(跟 LocalCategoryRepository 一致)
        await (db.delete(db.categories)
              ..where((c) => c.parentId.equals(existing.id)))
            .go();
        await (db.delete(db.categories)
              ..where((c) => c.id.equals(existing.id)))
            .go();
        logger.debug('SyncEngine', 'pull: 删除分类 $syncId');
      }
      return;
    }

    // upsert
    final payload = change.payload!;
    final name = payload['name'] as String? ?? '';
    final kind = payload['kind'] as String? ?? 'expense';
    final level = (payload['level'] as num?)?.toInt() ?? 1;
    final sortOrder = (payload['sortOrder'] as num?)?.toInt() ?? 0;
    final icon = payload['icon'] as String?;
    final iconType = payload['iconType'] as String? ?? 'material';
    final parentName = payload['parentName'] as String?;

    // 解析 parentId
    int? parentId;
    if (parentName != null && parentName.isNotEmpty) {
      final parent = await (db.select(db.categories)
            ..where((c) => c.name.equals(parentName))
            ..where((c) => c.kind.equals(kind))
            ..where((c) => c.level.equals(1)))
          .getSingleOrNull();
      parentId = parent?.id;
    }

    var existing = await (db.select(db.categories)
          ..where((c) => c.syncId.equals(syncId)))
        .getSingleOrNull();

    // Fallback：syncId 查不到 → 本地可能是 seed 默认分类（syncId 为 NULL）。
    // 按 name + kind 匹配 NULL syncId 行，把 syncId 补上。避免 device B 首次
    // pull 远端分类插第二份同名 seed。
    if (existing == null && name.isNotEmpty) {
      final seeded = await (db.select(db.categories)
            ..where((c) => c.name.equals(name))
            ..where((c) => c.kind.equals(kind))
            ..where((c) => c.syncId.isNull()))
          .getSingleOrNull();
      if (seeded != null) {
        await (db.update(db.categories)..where((c) => c.id.equals(seeded.id)))
            .write(CategoriesCompanion(syncId: d.Value(syncId)));
        existing = seeded;
        logger.info('SyncEngine',
            'pull: 收编本地 seed 分类 name="$name" kind=$kind → syncId=$syncId');
      }
    }

    // §Phase 3:自定义图标的 customIconPath 处理。
    //
    // payload.customIconPath 是 **A 端的本地路径**(如 "custom_icons/12_172123.png"),
    // 直接写进本地 categories 表 → B 端 UI 读取时拼绝对路径 → 文件不存在 →
    // 显示无图标。所以**绝不能直接落 server 推下来的 path**。
    //
    // 正确策略:
    //   - 本地已有同 cloudFileId 的图标文件(existing.customIconPath 含 fileId)→
    //     保留 existing.customIconPath,不入队
    //   - 否则:apply 内 customIconPath 写 null(或保持 existing 旧值),把下载
    //     任务入队 [pendingCustomIconJobs];事务 commit 后 drainCustomIconQueue
    //     并发下载,完成时写真正的 B 端路径 "custom_icons/<fileId>.<ext>"
    //
    // 这样即使 drain 半路失败 / app 重启,UI 看到的是"无 icon"(占位)而不是
    // "指向不存在文件的死链接",且下次 sync 同 entity 再来一遍 change 时,
    // 入队条件命中(existing.customIconPath 仍不含 fileId)会重新下载。
    final cloudFileId = payload['iconCloudFileId'] as String?;
    String? resolvedCustomIconPath;
    bool needIconDownload = false;
    if (iconType == 'custom' &&
        cloudFileId != null &&
        cloudFileId.isNotEmpty) {
      if (existing != null &&
          (existing.customIconPath ?? '').contains(cloudFileId)) {
        // 本地已下载,保留路径,不重新下
        resolvedCustomIconPath = existing.customIconPath;
      } else {
        // 还没下载:写 null,等 drain 写本地路径
        resolvedCustomIconPath = null;
        needIconDownload = true;
      }
    } else if (iconType != 'custom') {
      // 非 custom(material / community)— customIconPath 不适用
      resolvedCustomIconPath = null;
    } else {
      // iconType=custom 但没 cloudFileId(老数据):保留 existing path 兜底
      resolvedCustomIconPath = existing?.customIconPath;
    }

    int? localCategoryId;
    if (existing != null) {
      localCategoryId = existing.id;
      await (db.update(db.categories)
            ..where((c) => c.id.equals(localCategoryId!)))
          .write(CategoriesCompanion(
        name: d.Value(name),
        kind: d.Value(kind),
        level: d.Value(level),
        sortOrder: d.Value(sortOrder),
        icon: d.Value(icon),
        iconType: d.Value(iconType),
        customIconPath: d.Value(resolvedCustomIconPath),
        communityIconId:
            d.Value(payload['communityIconId'] as String?),
        parentId: d.Value(parentId),
      ));
      logger.debug('SyncEngine', 'pull: 更新分类 $syncId');
    } else {
      localCategoryId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: name,
              kind: kind,
              level: d.Value(level),
              sortOrder: d.Value(sortOrder),
              icon: d.Value(icon),
              iconType: d.Value(iconType),
              customIconPath: d.Value(resolvedCustomIconPath),
              communityIconId:
                  d.Value(payload['communityIconId'] as String?),
              parentId: d.Value(parentId),
              syncId: d.Value(syncId),
            ),
          );
      activePullCache?.putCategory(syncId, localCategoryId);
      logger.debug('SyncEngine', 'pull: 新增分类 $syncId');
    }

    // §Phase 3:入队下载任务,主事务 commit 后由 drainCustomIconQueue 并发处理。
    // needIconDownload 为 true 说明本地没有同 cloudFileId 的图标文件,
    // 此时 categories.customIconPath 已经写成 null,drain 完成后写真本地路径。
    if (needIconDownload && cloudFileId != null) {
      pendingCustomIconJobs.add(CustomIconDownloadJob(
        categoryId: localCategoryId,
        cloudFileId: cloudFileId,
        expectedPath: payload['customIconPath'] as String?,
      ));
    }

    // 登记"已从 server 拉到本地"标记,见 [_applyAccountChange] 同款注释。
    await changeTracker.recordPulledFromServer(
      entityType: 'category',
      entityId: localCategoryId,
      entitySyncId: syncId,
      ledgerId: 0,
    );
  }

  Future<void> _applyTagChange(BeeCountCloudSyncChange change) async {
    final syncId = change.entitySyncId;

    if (change.action == 'delete') {
      final existing = await (db.select(db.tags)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();
      if (existing != null) {
        // 删除关联的 transactionTags
        await (db.delete(db.transactionTags)
              ..where((tt) => tt.tagId.equals(existing.id)))
            .go();
        await (db.delete(db.tags)..where((t) => t.id.equals(existing.id)))
            .go();
        logger.debug('SyncEngine', 'pull: 删除标签 $syncId');
      }
      return;
    }

    // upsert
    final payload = change.payload!;
    final name = payload['name'] as String? ?? '';
    final color = payload['color'] as String?;
    final sortOrder = (payload['sortOrder'] as num?)?.toInt() ?? 0;

    var existing = await (db.select(db.tags)
          ..where((t) => t.syncId.equals(syncId)))
        .getSingleOrNull();

    // Fallback：syncId 查不到 → 按 name 匹配 NULL syncId 的 seed 行。
    if (existing == null && name.isNotEmpty) {
      final seeded = await (db.select(db.tags)
            ..where((t) => t.name.equals(name))
            ..where((t) => t.syncId.isNull()))
          .getSingleOrNull();
      if (seeded != null) {
        await (db.update(db.tags)..where((t) => t.id.equals(seeded.id)))
            .write(TagsCompanion(syncId: d.Value(syncId)));
        existing = seeded;
        logger.info('SyncEngine',
            'pull: 收编本地 seed 标签 name="$name" → syncId=$syncId');
      }
    }

    final int localId;
    if (existing != null) {
      localId = existing.id;
      await (db.update(db.tags)..where((t) => t.id.equals(localId)))
          .write(TagsCompanion(
        name: d.Value(name),
        color: d.Value(color),
        sortOrder: d.Value(sortOrder),
      ));
      logger.debug('SyncEngine', 'pull: 更新标签 $syncId');
    } else {
      localId = await db.into(db.tags).insert(
            TagsCompanion.insert(
              name: name,
              color: d.Value(color),
              sortOrder: d.Value(sortOrder),
              syncId: d.Value(syncId),
            ),
          );
      activePullCache?.putTag(syncId, localId);
      logger.debug('SyncEngine', 'pull: 新增标签 $syncId');
    }

    // 登记"已从 server 拉到本地"标记,见 [_applyAccountChange] 同款注释。
    await changeTracker.recordPulledFromServer(
      entityType: 'tag',
      entityId: localId,
      entitySyncId: syncId,
      ledgerId: 0,
    );
  }

  /// 应用预算变更。对齐 account/tag:按 syncId upsert,delete 走同样的路径。
  /// ledger/category 的外键在 payload 里以 syncId 形式带来,用
  /// _resolveLedgerIdBySyncId / _resolveCategoryIdBySyncId 换成本地 int id。
  Future<void> _applyBudgetChange(BeeCountCloudSyncChange change) async {
    final syncId = change.entitySyncId;

    if (change.action == 'delete') {
      final existing = await (db.select(db.budgets)
            ..where((b) => b.syncId.equals(syncId)))
          .getSingleOrNull();
      if (existing != null) {
        await (db.delete(db.budgets)..where((b) => b.id.equals(existing.id)))
            .go();
        logger.debug('SyncEngine', 'pull: 删除预算 $syncId');
      }
      return;
    }

    // upsert
    final payload = change.payload!;
    final ledgerSyncId = payload['ledgerSyncId'] as String?;
    final categorySyncId = payload['categoryId'] as String?;
    final type = payload['type'] as String? ?? 'total';
    final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
    final period = payload['period'] as String? ?? 'monthly';
    final startDay = (payload['startDay'] as num?)?.toInt() ?? 1;
    final enabled = payload['enabled'] as bool? ?? true;

    // 先解析外键 —— 本地 ledger 找不到就 skip,等 ledger change 先到再说。
    final localLedgerId = await _resolveLedgerIdBySyncId(ledgerSyncId);
    if (localLedgerId == null) {
      logger.info('SyncEngine',
          'pull: 预算 $syncId 的 ledgerSyncId=$ledgerSyncId 本地未就绪,跳过');
      return;
    }
    final localCategoryId = await _resolveCategoryIdBySyncId(categorySyncId);

    final existing = await (db.select(db.budgets)
          ..where((b) => b.syncId.equals(syncId)))
        .getSingleOrNull();

    if (existing != null) {
      await (db.update(db.budgets)..where((b) => b.id.equals(existing.id)))
          .write(BudgetsCompanion(
        ledgerId: d.Value(localLedgerId),
        type: d.Value(type),
        categoryId: d.Value(localCategoryId),
        amount: d.Value(amount),
        period: d.Value(period),
        startDay: d.Value(startDay),
        enabled: d.Value(enabled),
        updatedAt: d.Value(DateTime.now()),
      ));
      logger.debug('SyncEngine', 'pull: 更新预算 $syncId');
    } else {
      await db.into(db.budgets).insert(BudgetsCompanion.insert(
            ledgerId: localLedgerId,
            type: d.Value(type),
            categoryId: d.Value(localCategoryId),
            amount: amount,
            period: d.Value(period),
            startDay: d.Value(startDay),
            enabled: d.Value(enabled),
            syncId: d.Value(syncId),
          ));
      logger.debug('SyncEngine', 'pull: 新增预算 $syncId');
    }
  }

  /// 应用远程下发的账本元数据变更(名字 / 币种)。
  ///
  /// 跟其他 entity 不同:不在本地"新建"账本 —— 账本的创建走 fullPush /
  /// ledger_snapshot 路径。这里只负责"已存在的账本"的 meta 更新。找不到
  /// 对应的本地账本就跳过,等快照路径把它 seed 出来后再复用。
  Future<void> _applyLedgerChange(BeeCountCloudSyncChange change) async {
    final syncId = change.entitySyncId;
    if (change.action == 'delete') {
      // 账本删除走 'ledger_snapshot' 的 delete change,这里不处理 —— 避免
      // 跟 ledger_snapshot 重复触发。
      return;
    }
    final payload = change.payload;
    if (payload == null) return;

    // 用 get() 不用 getSingleOrNull(): 历史 bug 可能产生过 dup ledger 同
    // syncId,getSingleOrNull 撞多行抛 "Too many elements" 中断 replay。
    // 取第一行 + 清剩余 dup。
    final ledgerList = await (db.select(db.ledgers)
          ..where((l) => l.syncId.equals(syncId)))
        .get();
    final name = payload['ledgerName'] as String?;
    final currency = payload['currency'] as String?;
    if (ledgerList.isEmpty) {
      // 本地未就绪 — 之前的"跳过等 snapshot 路径"会导致 web 端新建账本时
      // app 拉到 ledger change 但永远不 insert,新账本永远不出现。
      //
      // 现在:payload 至少有 name + currency 时,主动 insert 一行本地
      // ledger。payload 缺关键字段时仍 skip(等下次 syncLedgersFromServer
      // 或 snapshot 拉到完整 meta)。
      if (name == null || name.isEmpty) {
        logger.info('SyncEngine',
            'pull: 账本 $syncId 本地未就绪 + payload 无 name,跳过(等 snapshot)');
        return;
      }
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
            name: name,
            currency: d.Value(currency ?? 'CNY'),
            syncId: d.Value(syncId),
          ));
      logger.info('SyncEngine',
          'pull: 新增账本 syncId=$syncId name=$name currency=${currency ?? "CNY"}');
      activePullCache?.putLedger(syncId, (await (db.select(db.ledgers)..where((l) => l.syncId.equals(syncId))).getSingle()).id);
      return;
    }
    final ledger = ledgerList.first;
    if (ledgerList.length > 1) {
      final dupIds = ledgerList.skip(1).map((l) => l.id).toList();
      logger.warning('SyncEngine',
          'pull: ledger.syncId=$syncId 撞多行 ${ledgerList.length},清除 dup id=$dupIds');
      await (db.delete(db.transactions)
            ..where((t) => t.ledgerId.isIn(dupIds)))
          .go();
      await (db.delete(db.localChanges)
            ..where((c) => c.ledgerId.isIn(dupIds)))
          .go();
      await (db.delete(db.ledgers)..where((l) => l.id.isIn(dupIds))).go();
    }

    final comp = LedgersCompanion(
      name: name != null ? d.Value(name) : const d.Value.absent(),
      currency: currency != null ? d.Value(currency) : const d.Value.absent(),
    );
    await (db.update(db.ledgers)..where((l) => l.id.equals(ledger.id)))
        .write(comp);
    logger.debug(
        'SyncEngine', 'pull: 更新账本 $syncId name=$name currency=$currency');
  }

  // ==================== Helper ====================

  /// 同步交易标签关联
  ///
  /// [txSyncId] 是 transaction.syncId(已知,由 caller 传入)— 避免每条 tx
  /// 都 `SELECT FROM transactions WHERE id = ?` 一次拿 syncId,这是 10k 条 =
  /// 10k 次 SELECT 的 N+1 大头。
  /// [isNewlyInserted] 为 true 时表示 transaction 是本次刚 INSERT 的,跳过
  /// "删旧关联"步骤(必然空)。
  Future<void> _syncTransactionTags(
    int transactionId,
    String txSyncId,
    Map<String, dynamic> payload, {
    bool isNewlyInserted = false,
  }) async {
    // 删除旧关联,按新 payload 重建(主表 + override)。新插入路径跳过 — 必空。
    if (!isNewlyInserted) {
      await (db.delete(db.transactionTags)
            ..where((tt) => tt.transactionId.equals(transactionId)))
          .go();
      await (db.delete(db.transactionTagOverrides)
            ..where((t) => t.transactionSyncId.equals(txSyncId)))
          .go();
    }

    final rawTagIds = payload['tagIds'];
    final tagIds = rawTagIds is List
        ? rawTagIds.whereType<String>().toList(growable: false)
        : const <String>[];
    final tagsStr = payload['tags'] as String?;
    final tagNamesFromStr = (tagsStr == null || tagsStr.isEmpty)
        ? const <String>[]
        : tagsStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    final linkedLocalIds = <int>{};
    final overrideSyncIds = <String>{};

    if (tagIds.isNotEmpty) {
      for (var i = 0; i < tagIds.length; i++) {
        final syncId = tagIds[i];
        // 优先查 LookupCache(pull 路径已 prime),消除 N+1 tag SELECT
        final cachedTagId = activePullCache?.tagId(syncId);
        if (cachedTagId != null) {
          linkedLocalIds.add(cachedTagId);
          continue;
        }
        var tag = await (db.select(db.tags)
              ..where((t) => t.syncId.equals(syncId)))
            .getSingleOrNull();
        if (tag != null) {
          activePullCache?.putTag(syncId, tag.id);
          linkedLocalIds.add(tag.id);
          continue;
        }
        // 主表 miss → 查 SharedLedgerTags(Editor 视角看 Owner 的 tx 引用 Owner 的 tag)
        final shared = await (db.select(db.sharedLedgerTags)
              ..where((t) => t.syncId.equals(syncId)))
            .getSingleOrNull();
        if (shared != null) {
          overrideSyncIds.add(syncId);
          continue;
        }
        // 都 miss → name fallback(老协议),建本地 tag
        if (i < tagNamesFromStr.length) {
          final name = tagNamesFromStr[i];
          tag = await (db.select(db.tags)
                ..where((t) => t.name.equals(name)))
              .getSingleOrNull();
          if (tag != null && (tag.syncId ?? '').isEmpty) {
            await (db.update(db.tags)..where((t) => t.id.equals(tag!.id)))
                .write(TagsCompanion(syncId: d.Value(syncId)));
          }
          if (tag != null) {
            activePullCache?.putTag(syncId, tag.id);
            linkedLocalIds.add(tag.id);
          }
        }
      }
    } else {
      // 完全没 tagIds 的老 payload:按 name 查,没有就建个带 syncId 的新 tag
      for (final name in tagNamesFromStr) {
        var tag = await (db.select(db.tags)
              ..where((t) => t.name.equals(name)))
            .getSingleOrNull();
        if (tag == null) {
          final newSyncId = _uuid.v4();
          final id = await db.into(db.tags).insert(
                TagsCompanion.insert(
                  name: name,
                  syncId: d.Value(newSyncId),
                ),
              );
          activePullCache?.putTag(newSyncId, id);
          tag = await (db.select(db.tags)
                ..where((t) => t.id.equals(id)))
              .getSingle();
        }
        linkedLocalIds.add(tag.id);
      }
    }

    // 批量插入 transactionTags + transactionTagOverrides,一次 db.batch
    // (单 fsync) 替代逐条 db.into().insert() (N 次小写入)。
    if (linkedLocalIds.isNotEmpty ||
        (txSyncId.isNotEmpty && overrideSyncIds.isNotEmpty)) {
      final now = DateTime.now().toUtc();
      await db.batch((b) {
        for (final tagId in linkedLocalIds) {
          b.insert(
            db.transactionTags,
            TransactionTagsCompanion.insert(
              transactionId: transactionId,
              tagId: tagId,
            ),
          );
        }
        if (txSyncId.isNotEmpty) {
          for (final sid in overrideSyncIds) {
            b.insert(
              db.transactionTagOverrides,
              TransactionTagOverridesCompanion.insert(
                transactionSyncId: txSyncId,
                tagSyncId: sid,
                createdAt: now,
              ),
            );
          }
        }
      });
    }
  }

  /// 同步交易附件关联（pull 时从 payload 创建/更新/删除本地附件记录）
  ///
  /// payload 里 attachments 的三种情况：
  ///   - 缺失（key 不存在）：legacy 调用 / 没附件信息 → 不动本地
  ///   - `[]`（空数组）：A 端把附件全删光了 → 本地同步删光
  ///   - `[...]`：权威列表 → 本地按 fileName 对齐,多余的删,缺的加
  ///
  /// [isNewlyInserted] 新插入 tx 路径,existing 必空,跳过 SELECT 省 N+1。
  Future<void> _syncTransactionAttachments(
    int transactionId,
    Map<String, dynamic> payload, {
    bool isNewlyInserted = false,
  }) async {
    // key 缺失 → legacy 行为，不碰本地
    if (!payload.containsKey('attachments')) return;
    final attachmentsList =
        (payload['attachments'] as List<dynamic>?) ?? const <dynamic>[];

    // 获取现有附件,按 fileName 索引。新插入路径 existing 必空,跳过 SELECT。
    final existing = isNewlyInserted
        ? const <TransactionAttachment>[]
        : await (db.select(db.transactionAttachments)
              ..where((a) => a.transactionId.equals(transactionId)))
            .get();
    final existingByFileName = {for (final a in existing) a.fileName: a};

    // 远端权威列表里的 fileName 集合
    final remoteFileNames = <String>{};

    // 收集 attachment 增/改/删的操作,统一用 db.batch 一次写,替代逐条
     /// db.into().insert / db.update().write / db.delete().go(N 次小 fsync)。
    final inserts = <TransactionAttachmentsCompanion>[];
    final updates = <({int id, TransactionAttachmentsCompanion data})>[];
    final attachmentsToDeleteFromDisk = <String>[];
    final deleteIds = <int>[];

    for (final att in attachmentsList) {
      final attMap = att as Map<String, dynamic>;
      final fileName = attMap['fileName'] as String? ?? '';
      if (fileName.isEmpty) continue;
      remoteFileNames.add(fileName);

      final cloudFileId = attMap['cloudFileId'] as String?;
      final cloudSha256 = attMap['cloudSha256'] as String?;

      if (existingByFileName.containsKey(fileName)) {
        final ex = existingByFileName[fileName]!;
        if (cloudFileId != null && ex.cloudFileId != cloudFileId) {
          updates.add((
            id: ex.id,
            data: TransactionAttachmentsCompanion(
              cloudFileId: d.Value(cloudFileId),
              cloudSha256: d.Value(cloudSha256),
            ),
          ));
        }
      } else {
        inserts.add(TransactionAttachmentsCompanion.insert(
          transactionId: transactionId,
          fileName: fileName,
          originalName: d.Value(attMap['originalName'] as String?),
          fileSize: d.Value(attMap['fileSize'] as int?),
          width: d.Value(attMap['width'] as int?),
          height: d.Value(attMap['height'] as int?),
          sortOrder: d.Value(attMap['sortOrder'] as int? ?? 0),
          cloudFileId: d.Value(cloudFileId),
          cloudSha256: d.Value(cloudSha256),
        ));
      }
    }

    for (final ex in existing) {
      if (remoteFileNames.contains(ex.fileName)) continue;
      deleteIds.add(ex.id);
      attachmentsToDeleteFromDisk.add(ex.fileName);
    }

    if (inserts.isNotEmpty || updates.isNotEmpty || deleteIds.isNotEmpty) {
      await db.batch((b) {
        if (inserts.isNotEmpty) {
          b.insertAll(db.transactionAttachments, inserts);
        }
        for (final u in updates) {
          b.update<TransactionAttachments, TransactionAttachment>(
            db.transactionAttachments,
            u.data,
            where: ($) => $.id.equals(u.id),
          );
        }
        if (deleteIds.isNotEmpty) {
          b.deleteWhere(
              db.transactionAttachments, ($) => $.id.isIn(deleteIds));
        }
      });
    }

    // 磁盘清理跑在事务外(IO 失败不影响 DB 状态)
    for (final fn in attachmentsToDeleteFromDisk) {
      try {
        final file = await _getAttachmentFile(fn);
        if (file != null && file.existsSync()) {
          await file.delete();
        }
      } catch (e, st) {
        logger.warning('SyncEngine', '删除本地孤立附件文件失败: $fn', st);
      }
    }
  }
}

// §Phase 3:`_detectIconExtension` 搬到 `attachments.dart`,因为自定义图标
// 下载从 _applyCategoryChange 内部移出,主事务只入队下载任务。原位置的函数
// 不再被任何路径调用,直接删除。
