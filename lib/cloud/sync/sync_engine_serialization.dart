part of 'sync_engine.dart';

/// push 路径上把本地实体序列化成 server payload 的逻辑。
///
/// 包括:
/// - `_serializeEntityForPush`: 增量 push,按 entity_type 序列化单个实体
/// - `_pushAllEntities`: fullPush 路径,一次批量序列化全部实体
/// - `_exportLedgerJson`: 生成完整 ledger JSON snapshot
///
/// 所有方法都是 private,只在 library 内被 `_push` / `fullPush` 调用,所以
/// extension 保持 private。
extension _SyncEngineSerialization on SyncEngine {
  /// 从 DB 读取实体并序列化为 push payload
  Future<Map<String, dynamic>> _serializeEntityForPush({
    required String entityType,
    required int entityId,
    required int ledgerId,
  }) async {
    // 取父 ledger 的 syncId，下面 serialize 时塞进 tx payload。对端
    // apply 先用 payload.ledgerSyncId 解析本地 ledger id，跨设备的 int id
    // 不一致问题（如 A 的账本 2 = B 的账本 3）才不会把 tx 错挂到别处。
    final parentLedger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    final parentLedgerSyncId = parentLedger?.syncId;

    switch (entityType) {
      case 'transaction':
        final tx = await (db.select(db.transactions)
              ..where((t) => t.id.equals(entityId)))
            .getSingleOrNull();
        if (tx == null) return <String, dynamic>{};

        // 获取关联数据
        final cat = tx.categoryId != null
            ? await (db.select(db.categories)
                  ..where((c) => c.id.equals(tx.categoryId!)))
                .getSingleOrNull()
            : null;
        final acc = tx.accountId != null
            ? await (db.select(db.accounts)
                  ..where((a) => a.id.equals(tx.accountId!)))
                .getSingleOrNull()
            : null;
        final toAcc = tx.toAccountId != null
            ? await (db.select(db.accounts)
                  ..where((a) => a.id.equals(tx.toAccountId!)))
                .getSingleOrNull()
            : null;

        // 获取标签(连同 tag.syncId,server 端按 id 反查最新名字)
        final txTags = await (db.select(db.transactionTags)
              ..where((tt) => tt.transactionId.equals(tx.id)))
            .get();
        final tagNames = <String>[];
        final tagSyncIds = <String>[];
        for (final tt in txTags) {
          final tag = await (db.select(db.tags)
                ..where((t) => t.id.equals(tt.tagId)))
              .getSingleOrNull();
          if (tag != null) {
            tagNames.add(tag.name);
            if (tag.syncId != null && tag.syncId!.isNotEmpty) {
              tagSyncIds.add(tag.syncId!);
            }
          }
        }
        // §7 共享账本:tx 可能有 TransactionTagOverrides(Editor 选了 Owner
        // 的 tag),并入 push payload。name 走 SharedLedgerTags 反查。
        if (tx.syncId != null) {
          final overrides = await (db.select(db.transactionTagOverrides)
                ..where((t) => t.transactionSyncId.equals(tx.syncId!)))
              .get();
          for (final ov in overrides) {
            if (tagSyncIds.contains(ov.tagSyncId)) continue;
            tagSyncIds.add(ov.tagSyncId);
            final shared = await (db.select(db.sharedLedgerTags)
                  ..where((t) => t.syncId.equals(ov.tagSyncId)))
                .getSingleOrNull();
            if (shared != null) tagNames.add(shared.name);
          }
        }

        // 获取附件
        final txAttachments = await (db.select(db.transactionAttachments)
              ..where((a) => a.transactionId.equals(tx.id)))
            .get();
        final attMaps = txAttachments
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
        // 早期警告:tx 有附件但部分 cloudFileId 缺失。push 出去后 server 端
        // 会把 attachments 当 "仅元数据" 处理,web 预览报错。理论上 sync 顺序
        // upload → push 应该让这里永远不触发;触发了说明 upload 跨 sync 边界
        // 出过 race(参考 sync_engine_attachments.dart::uploadAttachments 注释)。
        if (attMaps.isNotEmpty) {
          final withCloud = attMaps
              .where((a) => a['cloudFileId'] != null)
              .length;
          if (withCloud < attMaps.length) {
            logger.warning(
              'SyncEngine',
              'push tx=$entityId(syncId=${tx.syncId}) attachments=${attMaps.length} '
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
          fromAccountName:
              tx.type == 'transfer' ? finalAccountName : null,
          fromAccountSyncId:
              tx.type == 'transfer' ? finalAccountSyncId : null,
          toAccountName: finalToAccountName,
          toAccountSyncId: finalToAccountSyncId,
          ledgerSyncId: parentLedgerSyncId,
          tagNames: tagNames.isNotEmpty ? tagNames : null,
          tagSyncIds: tagSyncIds.isNotEmpty ? tagSyncIds : null,
          attachments: attMaps,
        );

      case 'account':
        final account = await (db.select(db.accounts)
              ..where((a) => a.id.equals(entityId)))
            .getSingleOrNull();
        if (account == null) return <String, dynamic>{};
        return EntitySerializer.serializeAccount(account);

      case 'category':
        final category = await (db.select(db.categories)
              ..where((c) => c.id.equals(entityId)))
            .getSingleOrNull();
        if (category == null) return <String, dynamic>{};
        String? parentName;
        String? parentSyncId;
        if (category.parentId != null) {
          final parent = await (db.select(db.categories)
                ..where((c) => c.id.equals(category.parentId!)))
              .getSingleOrNull();
          parentName = parent?.name;
          parentSyncId = parent?.syncId;
        }
        // 如果分类是自定义图标，先把图标文件上传到云端拿到 fileId/sha256，
        // 否则增量 push 的 payload 里不会带 iconCloudFileId，web 端永远没图。
        // 走 user-global 的 category icon endpoint —— 跟 ledger 解耦,user-id
        // + sha256 去重,跨账本只占 server 一份存储。
        String? iconCloudFileId;
        String? iconCloudSha256;
        if (category.iconType == 'custom' &&
            category.customIconPath != null &&
            category.customIconPath!.isNotEmpty) {
          try {
            final iconSvc = CustomIconService();
            final abs = await iconSvc.resolveIconPath(category.customIconPath!);
            final file = File(abs);
            if (file.existsSync()) {
              final bytes = await file.readAsBytes();
              final uploaded = await provider.uploadCategoryIcon(
                bytes: bytes,
                fileName: category.customIconPath!.split('/').last,
              );
              iconCloudFileId = uploaded.fileId;
              iconCloudSha256 = uploaded.sha256;
            }
          } catch (e, st) {
            logger.warning(
                'SyncEngine', '分类图标增量上传失败: ${category.name} $e', st);
          }
        }
        return EntitySerializer.serializeCategory(
          category,
          parentName: parentName,
          parentSyncId: parentSyncId,
          iconCloudFileId: iconCloudFileId,
          iconCloudSha256: iconCloudSha256,
        );

      case 'tag':
        final tag = await (db.select(db.tags)
              ..where((t) => t.id.equals(entityId)))
            .getSingleOrNull();
        if (tag == null) return <String, dynamic>{};
        return EntitySerializer.serializeTag(tag);

      case 'budget':
        final budget = await (db.select(db.budgets)
              ..where((b) => b.id.equals(entityId)))
            .getSingleOrNull();
        if (budget == null) return <String, dynamic>{};
        // 分类预算才有 categorySyncId;总预算直接不带。ledgerSyncId 用本 tx
        // 顶上已经取到的 parentLedgerSyncId(对应 budget.ledgerId)。
        String? categorySyncId;
        if (budget.categoryId != null) {
          final cat = await (db.select(db.categories)
                ..where((c) => c.id.equals(budget.categoryId!)))
              .getSingleOrNull();
          categorySyncId = cat?.syncId;
        }
        return EntitySerializer.serializeBudget(
          budget,
          ledgerSyncId: parentLedgerSyncId,
          categorySyncId: categorySyncId,
        );

      case 'ledger':
        // 账本元数据(名字 / 币种)。entityId 是本地 int id,取出后按 syncId
        // 推送,server materialize 时更新 `ledger_snapshot.ledgerName/currency`
        // + `Ledger.name` 自身,web 下次 read 就拿到新名字。
        final ledger = await (db.select(db.ledgers)
              ..where((l) => l.id.equals(entityId)))
            .getSingleOrNull();
        if (ledger == null || ledger.syncId == null || ledger.syncId!.isEmpty) {
          return <String, dynamic>{};
        }
        return EntitySerializer.serializeLedger(ledger);

      default:
        return <String, dynamic>{};
    }
  }




  // 跨设备 ID 解析方法搬到 sync_engine_resolvers.dart 这个 part 文件:
  //   _resolveLedgerIdBySyncId / _resolveCategoryIdBySyncId
  //   _resolveAccountIdBySyncId / _resolveCategoryId / _resolveAccountId
  //   _getDeviceId

  // ==================== 全量推送/拉取 ====================

  /// 首次全量推送（将本地所有数据推送到服务端）
  Future<void> fullPush({required int ledgerId}) async {
    logger.info('SyncEngine', '开始全量推送 ledger=$ledgerId');

    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingle();
    final pathForSnapshot = ledger.syncId ?? ledger.id.toString();

    // 0. 先用专用的 writeCreateLedger API(POST /write/ledgers)显式带 currency
    //    创建 server 端账本。这是修复"app 选 JPY 创建账本,server 端却是 CNY"的
    //    关键:之前 fullPush 只走 storage.upload,server auto-create ledger 时
    //    可能不读 metadata 的 currency,fallback 到默认 CNY;后续的 ledger:upsert
    //    change 在某些 server 实现下也只更新已存在 ledger,不能改它的 currency。
    //    用 dedicated API 显式声明 ledger_id + ledger_name + currency,server
    //    能正确建账本。
    //    幂等性:如果账本已存在(例如老数据 / 重试),server 会返回 409 或类似错误,
    //    这里 try/catch 吞掉,不阻塞后续 storage.upload + _pushAllEntities。
    try {
      await provider.writeCreateLedger(
        ledgerId: pathForSnapshot,
        ledgerName: ledger.name,
        currency: ledger.currency,
      );
      logger.info('SyncEngine',
          'writeCreateLedger 成功: ledgerId=$pathForSnapshot, name=${ledger.name}, currency=${ledger.currency}');
    } catch (e, st) {
      // 已存在 / 其他错误都不阻断流程,后续 storage.upload + _pushAllEntities
      // 仍会跑,部分 server 实现会从这两条路径 auto-create / 修正 meta。
      logger.warning('SyncEngine',
          'writeCreateLedger 失败（已存在或其他原因,继续走 storage 上传）: $e', st);
    }

    // 1. 上传 JSON 快照
    //    path 用 ledger.syncId，跟 _push/_pushAllEntities 的 ledger_id 一致，
    //    避免 server 出现两条 external_id 指向同一账本的分裂。
    try {
      final jsonData = await _exportLedgerJson(ledger);
      await provider.storage.upload(
        path: pathForSnapshot,
        data: jsonData,
        metadata: {
          'ledger_name': ledger.name,
          'currency': ledger.currency,
          'type': 'full_push',
        },
      );
      logger.info('SyncEngine', 'JSON 快照上传成功');
    } catch (e, st) {
      logger.error('SyncEngine', 'JSON 快照上传失败（继续推送个体变更）', e, st);
    }

    // 2. ledger 已就绪，这时再上传附件文件、回填 cloudFileId 到本地 DB。
    //    _pushAllEntities 会把 cloudFileId 写进 transaction payload。
    try {
      await uploadAttachments(ledgerId: ledgerId);
    } catch (e, st) {
      logger.error('SyncEngine', '附件上传失败（不阻塞推送）', e, st);
    }

    // 3. 推送所有实体的个体变更（用于 Web 端和增量同步）
    await _pushAllEntities(ledger);

    // 标记本次 fullPush 已经覆盖的变更为已推送。
    //
    // 关键:**只 mark 非 delete change**。`_pushAllEntities` 是从当前 DB
    // 实体 build syncChanges,只会 upsert 当前还存在的行;对应 delete change
    // 的实体已经被本地删掉、不在当前 DB 里、不在 _pushAllEntities 的输出里,
    // 所以 server 没收到 delete 操作,canonical state 还保留旧数据。
    //
    // 之前这里是把所有 unpushed 一并 markPushed,结果 delete change 静默被吃
    // 掉,server 永远删不掉对应数据(典型症状:用户清空账本后 remote 还显示
    // 旧记录,导入新数据后 remote 数 = 旧 + 新)。
    //
    // 修复:把 delete change 留作未推送,sync() 在 fullPush 之后会再调一次
    // _push 把它们推上去 + markPushed。
    final unpushed =
        await changeTracker.getUnpushedChangesForLedger(ledgerId);
    final nonDeletes =
        unpushed.where((c) => c.action != 'delete').toList();
    if (nonDeletes.isNotEmpty) {
      await changeTracker.markPushed(nonDeletes.map((c) => c.id).toList());
    }

    logger.info('SyncEngine',
        '全量推送完成 ledger=${ledger.name},markPushed ${nonDeletes.length}/${unpushed.length}(剩余 delete change 留给 _push)');
  }
  /// 推送所有实体为个体变更（fullPush 时调用）
  Future<void> _pushAllEntities(Ledger ledger) async {
    // 跟增量 _push 保持一致：用 ledger.syncId 作为 server 认的 external_id，
    // 跨设备时同一账本永远同一个 external_id，不会分裂成多条。
    final ledgerId = ledger.syncId ?? ledger.id.toString();
    final now = DateTime.now().toUtc().toIso8601String();
    final syncChanges = <Map<String, dynamic>>[];

    // 先推一条 ledger:upsert,显式带 ledgerName + currency。否则:
    //   - storage.upload 的 metadata 虽然带了 currency,但 server 端 auto-create
    //     ledger 时不一定从 metadata 读 currency(字段名可能对不上,或默认走 CNY)
    //   - _pushAllEntities 后续推的 accounts/categories/... 都不会带账本币种
    //   - 结果:用户在 app 选 JPY 创建账本,server 端 canonical state 是 CNY
    // 推一条显式的 ledger upsert 可以兜底,server 收到后用 payload 里的 currency
    // 覆盖默认值。
    syncChanges.add({
      'ledger_id': ledgerId,
      'entity_type': 'ledger',
      'entity_sync_id': ledgerId,
      'action': 'upsert',
      'payload': EntitySerializer.serializeLedger(ledger),
      'updated_at': now,
    });

    // 先上传分类自定义图标，拿到每个分类对应的 cloudFileId/sha256。
    final categoryIconCloudRefs = await _uploadCategoryIcons();

    // 账户：虽然 Accounts 表有 ledgerId（历史遗留），账户在 UI 层是跨账本可选的，
    // 所以按全局推送，避免跨账本共享账户在只属于某一账本的 fullPush 中漏推。
    // server 端按 syncId 幂等，不会重复。
    final accounts = await db.select(db.accounts).get();
    for (final account in accounts) {
      final syncId = account.syncId ?? _uuid.v4();
      // 确保 syncId 已持久化
      if (account.syncId == null) {
        await (db.update(db.accounts)
              ..where((a) => a.id.equals(account.id)))
            .write(AccountsCompanion(syncId: d.Value(syncId)));
      }
      syncChanges.add({
        'ledger_id': ledgerId,
        'entity_type': 'account',
        'entity_sync_id': syncId,
        'action': 'upsert',
        'payload': EntitySerializer.serializeAccount(account),
        'updated_at': now,
      });
    }

    // 分类
    final categories = await db.select(db.categories).get();
    for (final category in categories) {
      final syncId = category.syncId ?? _uuid.v4();
      if (category.syncId == null) {
        await (db.update(db.categories)
              ..where((c) => c.id.equals(category.id)))
            .write(CategoriesCompanion(syncId: d.Value(syncId)));
      }
      String? parentName;
      String? parentSyncId;
      if (category.parentId != null) {
        final parent = categories
            .cast<Category?>()
            .firstWhere((p) => p?.id == category.parentId, orElse: () => null);
        parentName = parent?.name;
        parentSyncId = parent?.syncId;
      }
      final iconRef = categoryIconCloudRefs[category.id];
      syncChanges.add({
        'ledger_id': ledgerId,
        'entity_type': 'category',
        'entity_sync_id': syncId,
        'action': 'upsert',
        'payload': EntitySerializer.serializeCategory(
          category,
          parentName: parentName,
          parentSyncId: parentSyncId,
          iconCloudFileId: iconRef?.fileId,
          iconCloudSha256: iconRef?.sha256,
        ),
        'updated_at': now,
      });
    }

    // 标签
    final tags = await db.select(db.tags).get();
    for (final tag in tags) {
      final syncId = tag.syncId ?? _uuid.v4();
      if (tag.syncId == null) {
        await (db.update(db.tags)
              ..where((t) => t.id.equals(tag.id)))
            .write(TagsCompanion(syncId: d.Value(syncId)));
      }
      syncChanges.add({
        'ledger_id': ledgerId,
        'entity_type': 'tag',
        'entity_sync_id': syncId,
        'action': 'upsert',
        'payload': EntitySerializer.serializeTag(tag),
        'updated_at': now,
      });
    }

    // 预算:按账本过滤推,不跨账本。分类预算带 categorySyncId。
    final budgets = await (db.select(db.budgets)
          ..where((b) => b.ledgerId.equals(ledger.id)))
        .get();
    for (final budget in budgets) {
      final syncId = budget.syncId ?? _uuid.v4();
      if (budget.syncId == null) {
        await (db.update(db.budgets)
              ..where((b) => b.id.equals(budget.id)))
            .write(BudgetsCompanion(syncId: d.Value(syncId)));
      }
      String? catSyncId;
      if (budget.categoryId != null) {
        final cat = categories
            .cast<Category?>()
            .firstWhere((c) => c?.id == budget.categoryId,
                orElse: () => null);
        catSyncId = cat?.syncId;
      }
      syncChanges.add({
        'ledger_id': ledgerId,
        'entity_type': 'budget',
        'entity_sync_id': syncId,
        'action': 'upsert',
        'payload': EntitySerializer.serializeBudget(
          budget,
          ledgerSyncId: ledger.syncId,
          categorySyncId: catSyncId,
        ),
        'updated_at': now,
      });
    }

    // 交易
    final transactions = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledger.id)))
        .get();

    // 预加载所有附件，按 transactionId 分组
    final allAttachments = await (db.select(db.transactionAttachments)
          ..where((a) => a.transactionId
              .isIn(transactions.map((t) => t.id).toList())))
        .get();
    final attachmentsByTx = <int, List<TransactionAttachment>>{};
    for (final a in allAttachments) {
      attachmentsByTx.putIfAbsent(a.transactionId, () => []).add(a);
    }

    for (final tx in transactions) {
      final syncId = tx.syncId ?? _uuid.v4();
      if (tx.syncId == null) {
        await (db.update(db.transactions)
              ..where((t) => t.id.equals(tx.id)))
            .write(TransactionsCompanion(syncId: d.Value(syncId)));
      }

      final cat = tx.categoryId != null
          ? categories
              .cast<Category?>()
              .firstWhere((c) => c?.id == tx.categoryId, orElse: () => null)
          : null;
      final acc = tx.accountId != null
          ? accounts
              .cast<Account?>()
              .firstWhere((a) => a?.id == tx.accountId, orElse: () => null)
          : null;
      final toAcc = tx.toAccountId != null
          ? accounts
              .cast<Account?>()
              .firstWhere((a) => a?.id == tx.toAccountId, orElse: () => null)
          : null;

      final txTags = await (db.select(db.transactionTags)
            ..where((tt) => tt.transactionId.equals(tx.id)))
          .get();
      final tagNames = <String>[];
      final tagSyncIds = <String>[];
      for (final tt in txTags) {
        final tag = tags
            .cast<Tag?>()
            .firstWhere((t) => t?.id == tt.tagId, orElse: () => null);
        if (tag != null) {
          tagNames.add(tag.name);
          if (tag.syncId != null && tag.syncId!.isNotEmpty) {
            tagSyncIds.add(tag.syncId!);
          }
        }
      }

      // 构建附件数据
      final txAtts = attachmentsByTx[tx.id] ?? [];
      final attMaps = txAtts
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

      syncChanges.add({
        'ledger_id': ledgerId,
        'entity_type': 'transaction',
        'entity_sync_id': syncId,
        'action': 'upsert',
        'payload': EntitySerializer.serializeTransaction(
          tx,
          categoryName: cat?.name,
          categoryKind: cat?.kind,
          categorySyncId: cat?.syncId,
          accountName: acc?.name,
          accountSyncId: acc?.syncId,
          fromAccountName: tx.type == 'transfer' ? acc?.name : null,
          fromAccountSyncId: tx.type == 'transfer' ? acc?.syncId : null,
          toAccountName: toAcc?.name,
          toAccountSyncId: toAcc?.syncId,
          ledgerSyncId: ledger.syncId,
          tagNames: tagNames.isNotEmpty ? tagNames : null,
          tagSyncIds: tagSyncIds.isNotEmpty ? tagSyncIds : null,
          attachments: attMaps,
        ),
        'updated_at': now,
      });
    }

    // 统计实体数量
    final accountCount = accounts.length;
    final categoryCount = categories.length;
    final tagCount = tags.length;
    final txCount = transactions.length;
    logger.info('SyncEngine',
        '开始推送个体变更 共${syncChanges.length}条 '
        '(accounts=$accountCount, categories=$categoryCount, tags=$tagCount, transactions=$txCount)');

    // 分批推送:每条 change 平均 ~500 字节,500 条 ≈ 250KB,远低于网关限制,
    // 但单次请求内 server 事务处理时间 ~100ms 可接受。
    // 5 倍原先 100 的吞吐,3 万条交易上传从 300 批降到 60 批,耗时约 1/5。
    const batchSize = 500;
    for (var i = 0; i < syncChanges.length; i += batchSize) {
      final end = (i + batchSize > syncChanges.length) ? syncChanges.length : i + batchSize;
      final batch = syncChanges.sublist(i, end);
      try {
        logger.info('SyncEngine', '推送批次 ${i ~/ batchSize + 1}: ${batch.length}条 (${i+1}-$end)');
        await provider.pushChanges(changes: batch);
        logger.info('SyncEngine', '批次 ${i ~/ batchSize + 1} 推送成功');
      } catch (e, st) {
        logger.error('SyncEngine', '批次 ${i ~/ batchSize + 1} 推送失败', e, st);
        rethrow; // 让调用方知道失败
      }
    }

    logger.info('SyncEngine', '全量推送个体变更完成 ${syncChanges.length} 条');
  }
  Future<String> _exportLedgerJson(Ledger ledger) async {
    final transactions = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledger.id))
          ..orderBy([(t) => d.OrderingTerm.asc(t.happenedAt)]))
        .get();

    final accounts = await (db.select(db.accounts)
          ..where((a) => a.ledgerId.equals(ledger.id)))
        .get();
    final categories = await db.select(db.categories).get();
    final tags = await db.select(db.tags).get();

    final items = <Map<String, dynamic>>[];
    for (final tx in transactions) {
      final cat = tx.categoryId != null
          ? categories
              .cast<Category?>()
              .firstWhere((c) => c?.id == tx.categoryId, orElse: () => null)
          : null;
      final acc = tx.accountId != null
          ? accounts
              .cast<Account?>()
              .firstWhere((a) => a?.id == tx.accountId, orElse: () => null)
          : null;
      final toAcc = tx.toAccountId != null
          ? accounts
              .cast<Account?>()
              .firstWhere((a) => a?.id == tx.toAccountId, orElse: () => null)
          : null;

      final txTags = await (db.select(db.transactionTags)
            ..where((tt) => tt.transactionId.equals(tx.id)))
          .get();
      final tagNames = <String>[];
      final tagSyncIds = <String>[];
      for (final tt in txTags) {
        final tag = tags
            .cast<Tag?>()
            .firstWhere((t) => t?.id == tt.tagId, orElse: () => null);
        if (tag != null) {
          tagNames.add(tag.name);
          if (tag.syncId != null && tag.syncId!.isNotEmpty) {
            tagSyncIds.add(tag.syncId!);
          }
        }
      }

      items.add(EntitySerializer.serializeTransaction(
        tx,
        categoryName: cat?.name,
        categoryKind: cat?.kind,
        categorySyncId: cat?.syncId,
        accountName: acc?.name,
        accountSyncId: acc?.syncId,
        fromAccountName: tx.type == 'transfer' ? acc?.name : null,
        fromAccountSyncId: tx.type == 'transfer' ? acc?.syncId : null,
        toAccountName: toAcc?.name,
        toAccountSyncId: toAcc?.syncId,
        ledgerSyncId: ledger.syncId,
        tagNames: tagNames.isNotEmpty ? tagNames : null,
        tagSyncIds: tagSyncIds.isNotEmpty ? tagSyncIds : null,
      ));
    }

    return jsonEncode({
      'version': 6,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'ledgerId': ledger.id,
      'ledgerName': ledger.name,
      'currency': ledger.currency,
      'count': items.length,
      'accounts':
          accounts.map((a) => EntitySerializer.serializeAccount(a)).toList(),
      'categories': categories.map((c) {
        String? parentName;
        String? parentSyncId;
        if (c.parentId != null) {
          final parent = categories
              .cast<Category?>()
              .firstWhere((p) => p?.id == c.parentId, orElse: () => null);
          parentName = parent?.name;
          parentSyncId = parent?.syncId;
        }
        return EntitySerializer.serializeCategory(c,
            parentName: parentName, parentSyncId: parentSyncId);
      }).toList(),
      'tags': tags.map((t) => EntitySerializer.serializeTag(t)).toList(),
      'items': items,
    });
  }
}
