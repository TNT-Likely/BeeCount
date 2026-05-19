part of 'sync_engine.dart';

/// pull 路径上把远端变更应用到本地 Drift 的逻辑。`_applyRemoteChange` 是
/// 总入口分发器,按 entity_type 分到具体的 `_apply*Change` handler。
///
/// 这里所有方法都是 private(以 `_` 开头),只在主 library 内被 `_pull` 调
/// 用,所以 extension 可以保持 private。
extension _SyncEngineApply on SyncEngine {
  /// 应用单条远程变更到本地数据库
  /// 返回 true 表示已应用，false 表示跳过
  Future<bool> _applyRemoteChange(BeeCountCloudSyncChange change) async {
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
      final existing = await (db.select(db.transactions)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();
      if (existing != null) {
        // 先清磁盘附件(原图 + 缩略图),再删 transaction_attachments 行 ——
        // 反过来就查不到 fileName 了。历史 bug:这段只做 db.delete 不清磁盘,
        // 设备 A 删交易时设备 B sync pull 下来只删表,attachments/*.jpg 永远
        // 残留。跟主动删交易路径(LocalTransactionRepository.deleteTransaction)
        // 对齐。
        await _cleanupTxAttachmentFilesOnDisk(existing.id);
        await (db.delete(db.transactionTags)
              ..where((tt) => tt.transactionId.equals(existing.id)))
            .go();
        await (db.delete(db.transactionAttachments)
              ..where((ta) => ta.transactionId.equals(existing.id)))
            .go();
        await (db.delete(db.transactions)
              ..where((t) => t.id.equals(existing.id)))
            .go();
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

    final existing = await (db.select(db.transactions)
          ..where((t) => t.syncId.equals(syncId)))
        .getSingleOrNull();

    // 共享账本(v24):server 注入 createdByUserId / updatedByUserId,本地用来
    // 在 tx 末尾显示"X 记的"。payload 用 camelCase(server snapshot_mutator 出来的
    // 字段是 createdByUserId/updatedByUserId,跟 Drift 列名 createdByUserId /
    // lastEditedByUserId 对齐)。
    final createdByUserId = payload['createdByUserId'] as String?;
    final lastEditedByUserId = (payload['updatedByUserId'] as String?) ?? createdByUserId;

    if (existing != null) {
      // 更新 — createdByUserId 走"本地为 null 就回填,否则保持"的策略:
      //   - 本地已有值:不接受 server 覆盖(避免 server 数据修复路径反过来
      //     污染本地;创建人是稳定属性,本地一旦有值就以本地为准)
      //   - 本地为 null + payload 非 null:从 server 兜底补一次。覆盖
      //     mobile 早期版本本地未填 created_by_user_id 列 + 服务端 SyncChange
      //     enrichment 修复前留下的脏数据
      final shouldBackfillCreator =
          existing.createdByUserId == null && createdByUserId != null;
      await (db.update(db.transactions)
            ..where((t) => t.id.equals(existing.id)))
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
      // 更新标签和附件
      await _syncTransactionTags(existing.id, payload);
      await _syncTransactionAttachments(existing.id, payload);
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
      // 同步标签和附件
      await _syncTransactionTags(id, payload);
      await _syncTransactionAttachments(id, payload);
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

    if (existing != null) {
      final localId = existing.id;
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
      await db.into(db.accounts).insert(
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
      logger.debug('SyncEngine', 'pull: 新增账户 $syncId');
    }
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

    // P3 —— 自定义图标二进制下载。payload.iconCloudFileId 非空说明是 custom
    // 图标，server snapshot 里存着 attachment 引用。本地如果没这张图就下载，
    // 有就 skip（checked by customIconPath 文件是否存在）。Drift Category
    // 表不单独存 cloudFileId/sha256，A push 时是动态上传的，B 这里只需要最终
    // 的 customIconPath 指到本地文件即可。
    String? resolvedCustomIconPath = payload['customIconPath'] as String?;
    final cloudFileId = payload['iconCloudFileId'] as String?;
    if (iconType == 'custom' &&
        cloudFileId != null &&
        cloudFileId.isNotEmpty) {
      // 如果本地已有图片文件，且 path 看起来指向已下载的 fileId（相同 basename），
      // 就 skip 下载。否则重新下。
      bool needsDownload = true;
      if (existing != null && (existing.customIconPath ?? '').isNotEmpty) {
        try {
          final abs = await CustomIconService().resolveIconPath(
              existing.customIconPath!);
          if (await File(abs).exists() &&
              existing.customIconPath!.contains(cloudFileId)) {
            needsDownload = false;
            resolvedCustomIconPath = existing.customIconPath;
          }
        } catch (_) {}
      }
      if (needsDownload) {
        try {
          final bytes = await provider.downloadAttachment(fileId: cloudFileId);
          // 写到 `custom_icons/<fileId>.<ext>`。扩展名按下面优先级解析:
          //   1. payload.customIconPath 末尾的扩展名(设备 A 上传时生成的
          //      规范名 `<categoryId>_<ts>.png` 一般会带)
          //   2. 下载 bytes 的 magic bytes 探测 (PNG/JPEG/WebP)
          //   3. fallback `.png` (历史 custom icon 都是 96x96 PNG)
          // 之前这里直接用 cloudFileId(UUID)做 safeName,导致本地路径无扩展
          // 名;再被 fullPush 用 `split('/').last` 当 fileName 推回 server,
          // 形成 server 端 `<uuid>_<uuid>` 无扩展名的恶性循环。
          final originalPath = payload['customIconPath'] as String?;
          final ext = _detectIconExtension(bytes, originalPath: originalPath);
          final iconDir = await CustomIconService().getIconDirectory();
          final safeName = '${cloudFileId.replaceAll('/', '_')}$ext';
          final absPath = '${iconDir.path}/$safeName';
          await File(absPath).writeAsBytes(bytes);
          resolvedCustomIconPath = 'custom_icons/$safeName';
          logger.info('SyncEngine',
              'pull: custom icon downloaded fileId=$cloudFileId ext=$ext size=${bytes.length}B');
        } catch (e, st) {
          logger.warning('SyncEngine',
              'pull: custom icon download failed fileId=$cloudFileId: $e', st);
        }
      }
    }

    if (existing != null) {
      final localId = existing.id;
      await (db.update(db.categories)
            ..where((c) => c.id.equals(localId)))
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
      await db.into(db.categories).insert(
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
      logger.debug('SyncEngine', 'pull: 新增分类 $syncId');
    }
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

    if (existing != null) {
      final localId = existing.id;
      await (db.update(db.tags)..where((t) => t.id.equals(localId)))
          .write(TagsCompanion(
        name: d.Value(name),
        color: d.Value(color),
        sortOrder: d.Value(sortOrder),
      ));
      logger.debug('SyncEngine', 'pull: 更新标签 $syncId');
    } else {
      await db.into(db.tags).insert(
            TagsCompanion.insert(
              name: name,
              color: d.Value(color),
              sortOrder: d.Value(sortOrder),
              syncId: d.Value(syncId),
            ),
          );
      logger.debug('SyncEngine', 'pull: 新增标签 $syncId');
    }
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
    if (ledgerList.isEmpty) {
      logger.info('SyncEngine',
          'pull: 账本 $syncId 本地未就绪,跳过 meta 更新(等 snapshot 路径)');
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

    final name = payload['ledgerName'] as String?;
    final currency = payload['currency'] as String?;
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
  Future<void> _syncTransactionTags(
      int transactionId, Map<String, dynamic> payload) async {
    // 删除旧关联,按新 payload 重建(主表 + override)
    await (db.delete(db.transactionTags)
          ..where((tt) => tt.transactionId.equals(transactionId)))
        .go();

    // 拿 tx.syncId 用于 override 表
    final txRow = await (db.select(db.transactions)
          ..where((t) => t.id.equals(transactionId)))
        .getSingleOrNull();
    final txSyncId = txRow?.syncId;
    if (txSyncId != null) {
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
        var tag = await (db.select(db.tags)
              ..where((t) => t.syncId.equals(syncId)))
            .getSingleOrNull();
        if (tag != null) {
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
          if (tag != null) linkedLocalIds.add(tag.id);
        }
      }
    } else {
      // 完全没 tagIds 的老 payload:按 name 查,没有就建个带 syncId 的新 tag
      for (final name in tagNamesFromStr) {
        var tag = await (db.select(db.tags)
              ..where((t) => t.name.equals(name)))
            .getSingleOrNull();
        if (tag == null) {
          final id = await db.into(db.tags).insert(
                TagsCompanion.insert(
                  name: name,
                  syncId: d.Value(_uuid.v4()),
                ),
              );
          tag = await (db.select(db.tags)
                ..where((t) => t.id.equals(id)))
              .getSingle();
        }
        linkedLocalIds.add(tag.id);
      }
    }

    for (final tagId in linkedLocalIds) {
      await db.into(db.transactionTags).insert(
            TransactionTagsCompanion.insert(
              transactionId: transactionId,
              tagId: tagId,
            ),
          );
    }
    if (txSyncId != null && overrideSyncIds.isNotEmpty) {
      final now = DateTime.now().toUtc();
      for (final sid in overrideSyncIds) {
        await db.into(db.transactionTagOverrides).insert(
              TransactionTagOverridesCompanion.insert(
                transactionSyncId: txSyncId,
                tagSyncId: sid,
                createdAt: now,
              ),
            );
      }
    }
  }

  /// 同步交易附件关联（pull 时从 payload 创建/更新/删除本地附件记录）
  ///
  /// payload 里 attachments 的三种情况：
  ///   - 缺失（key 不存在）：legacy 调用 / 没附件信息 → 不动本地
  ///   - `[]`（空数组）：A 端把附件全删光了 → 本地同步删光
  ///   - `[...]`：权威列表 → 本地按 fileName 对齐，多余的删，缺的加
  Future<void> _syncTransactionAttachments(
      int transactionId, Map<String, dynamic> payload) async {
    // key 缺失 → legacy 行为，不碰本地
    if (!payload.containsKey('attachments')) return;
    final attachmentsList =
        (payload['attachments'] as List<dynamic>?) ?? const <dynamic>[];

    // 获取现有附件，按 fileName 索引
    final existing = await (db.select(db.transactionAttachments)
          ..where((a) => a.transactionId.equals(transactionId)))
        .get();
    final existingByFileName = {for (final a in existing) a.fileName: a};

    // 远端权威列表里的 fileName 集合
    final remoteFileNames = <String>{};

    for (final att in attachmentsList) {
      final attMap = att as Map<String, dynamic>;
      final fileName = attMap['fileName'] as String? ?? '';
      if (fileName.isEmpty) continue;
      remoteFileNames.add(fileName);

      final cloudFileId = attMap['cloudFileId'] as String?;
      final cloudSha256 = attMap['cloudSha256'] as String?;

      if (existingByFileName.containsKey(fileName)) {
        // 已存在 → 更新 cloudFileId/cloudSha256（如果远端有新值）
        final ex = existingByFileName[fileName]!;
        if (cloudFileId != null && ex.cloudFileId != cloudFileId) {
          await (db.update(db.transactionAttachments)
                ..where((a) => a.id.equals(ex.id)))
              .write(TransactionAttachmentsCompanion(
            cloudFileId: d.Value(cloudFileId),
            cloudSha256: d.Value(cloudSha256),
          ));
        }
      } else {
        // 不存在 → 创建附件记录
        await db.into(db.transactionAttachments).insert(
              TransactionAttachmentsCompanion.insert(
                transactionId: transactionId,
                fileName: fileName,
                originalName: d.Value(attMap['originalName'] as String?),
                fileSize: d.Value(attMap['fileSize'] as int?),
                width: d.Value(attMap['width'] as int?),
                height: d.Value(attMap['height'] as int?),
                sortOrder: d.Value(attMap['sortOrder'] as int? ?? 0),
                cloudFileId: d.Value(cloudFileId),
                cloudSha256: d.Value(cloudSha256),
              ),
            );
      }
    }

    // 本地有但远端没有的附件 → 对端已删，本地也删。同时清掉落地文件，
    // 避免孤立图片占空间。
    for (final ex in existing) {
      if (remoteFileNames.contains(ex.fileName)) continue;
      await (db.delete(db.transactionAttachments)
            ..where((a) => a.id.equals(ex.id)))
          .go();
      try {
        final file = await _getAttachmentFile(ex.fileName);
        if (file != null && file.existsSync()) {
          await file.delete();
        }
      } catch (e, st) {
        logger.warning(
            'SyncEngine', '删除本地孤立附件文件失败: ${ex.fileName}', st);
      }
    }
  }
}

/// 探测分类图标的扩展名,保证本地落地文件名能被正确识别为图片。
///
/// 优先级:
///   1. originalPath 末尾的扩展名(payload.customIconPath 来自上游 saveCustomIcon
///      生成的 `<id>_<ts>.png` 规范名)
///   2. bytes 前几个 magic bytes:
///      - PNG: `89 50 4E 47 0D 0A 1A 0A`
///      - JPEG: `FF D8 FF`
///      - WebP: `52 49 46 46 .. .. .. .. 57 45 42 50` (RIFF....WEBP)
///   3. fallback `.png` (历史分类图标都是 96x96 PNG)
String _detectIconExtension(List<int> bytes, {String? originalPath}) {
  if (originalPath != null && originalPath.isNotEmpty) {
    final dot = originalPath.lastIndexOf('.');
    if (dot >= 0 && dot < originalPath.length - 1) {
      final ext = originalPath.substring(dot).toLowerCase();
      // 防御:扩展名长度合理,且只包含字母/数字
      if (ext.length <= 6 &&
          RegExp(r'^\.[a-z0-9]+$').hasMatch(ext)) {
        return ext;
      }
    }
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return '.png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return '.jpg';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return '.webp';
  }
  return '.png';
}
