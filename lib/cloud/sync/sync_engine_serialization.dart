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
extension SyncEngineSerializationExt on SyncEngine {
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

        return serializeTransactionForSync(db, tx, parentLedgerSyncId);

      case 'account':
        final account = await (db.select(db.accounts)
              ..where((a) => a.id.equals(entityId)))
            .getSingleOrNull();
        if (account == null) return <String, dynamic>{};
        return EntitySerializer.serializeAccount(account);

      case 'exchange_rate_override':
        // 按 entityId 反查行,跟 account 分支同款;行已删(delete change)
        // 返回空 payload(delete 路径 server 只看 action,不读 payload)。
        // server 端 projection.upsert_exchange_rate_override 对缺字段静默 return
        // (BeeCount-Cloud Task 3 防御分支),空 payload upsert 无害。
        final override = await (db.select(db.exchangeRateOverrides)
              ..where((o) => o.id.equals(entityId)))
            .getSingleOrNull();
        if (override == null) return <String, dynamic>{};
        return EntitySerializer.serializeExchangeRateOverride(override);

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
            logger.warning('SyncEngine', '分类图标增量上传失败: ${category.name} $e', st);
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

  /// 首次全量推送(将本地所有数据推送到服务端)。
  ///
  /// **in-flight 单飞**:同 ledger 的并发调用复用第一个 future,避免 sync_changes
  /// 表 2-3x 膨胀。详见 `.docs/concurrent-fullpush-bloat.md`。
  Future<void> fullPush({required int ledgerId}) async {
    (await _fullPushResult(ledgerId)).requireSuccess();
  }

  Future<_PushTally> _fullPushResult(int ledgerId) async {
    await _recoverTransactionMoves();
    final incremental = _pushInFlight['$ledgerId'];
    if (incremental != null) await incremental.future;
    final inFlight = _fullPushInFlight[ledgerId];
    if (inFlight != null) {
      logger.info('SyncEngine', 'fullPush(ledger=$ledgerId) 已在执行,复用 in-flight');
      return inFlight.future;
    }
    final completer = Completer<_PushTally>();
    completer.future.ignore(); // 防 unhandled async error
    _fullPushInFlight[ledgerId] = completer;
    try {
      final tally = await _doFullPush(ledgerId: ledgerId);
      completer.complete(tally);
      return tally;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      if (_fullPushInFlight[ledgerId] == completer) {
        _fullPushInFlight.remove(ledgerId);
      }
    }
  }

  Future<_PushTally> _doFullPush({required int ledgerId}) async {
    logger.info('SyncEngine', '开始全量推送 ledger=$ledgerId');

    Future<Ledger> readLedger() => (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingle();
    var ledger = await readLedger();
    if (ledger.syncId == null || ledger.syncId!.length < 3) {
      await _ensureLedgerSyncId(ledger);
      ledger = await readLedger();
    }
    final pathForSnapshot = ledger.syncId!;

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
        // The create endpoint emits ledger metadata before later snapshot/upserts.
        // Preserve the period there so its default 1 cannot be replayed over us.
        monthStartDay: ledger.monthStartDay,
      );
      logger.info('SyncEngine',
          'writeCreateLedger 成功: ledgerId=$pathForSnapshot, name=${ledger.name}, currency=${ledger.currency}');
    } catch (e, st) {
      // 已存在 / 其他错误都不阻断流程,后续 storage.upload + _pushAllEntities
      // 仍会跑,部分 server 实现会从这两条路径 auto-create / 修正 meta。
      logger.warning('SyncEngine',
          'writeCreateLedger 失败（已存在或其他原因,继续走 storage 上传）: $e', st);
    }

    // A recurring ledger may already have server-only entries and later edits.
    final held = await _adoptBeforeUpload(ledger);
    // Only acknowledge changes present before this upload started.
    final unpushed = await changeTracker.getUnpushedChangesForLedger(ledgerId);
    final bulkExclusions = await _recurringBulkExclusions(ledger, held, unpushed);
    // 1. 上传 JSON 快照
    //    path 用 ledger.syncId，跟 _push/_pushAllEntities 的 ledger_id 一致，
    //    避免 server 出现两条 external_id 指向同一账本的分裂。
    if (bulkExclusions == null) {
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
    }

    // 2. ledger 已就绪，这时再上传附件文件、回填 cloudFileId 到本地 DB。
    //    _pushAllEntities 会把 cloudFileId 写进 transaction payload。
    try {
      await uploadAttachments(ledgerId: ledgerId);
    } catch (e, st) {
      logger.error('SyncEngine', '附件上传失败（不阻塞推送）', e, st);
    }

    // 3. 推送所有实体的个体变更（用于 Web 端和增量同步）
    // Only non-delete operations captured at the start can be covered by a
    // snapshot upsert. Match them by entity and settle each batch's receipts.
    final journalIds = <(String, String), List<int>>{};
    for (final row in unpushed) {
      if (row.action != 'delete' && !_holdRecurringChange(row, held)) {
        (journalIds[(row.entityType, row.entitySyncId)] ??= []).add(row.id);
      }
    }
    return _pushAllEntities(ledger, bulkExclusions, journalIds);
  }

  /// 推送所有实体为个体变更(fullPush 时调用)。
  ///
  /// **只处理 ledger-scope 实体**(ledger / budget / transaction)。user-global
  /// 实体(account / category / tag)由调用方通过 [pushUserGlobalEntities] 统一
  /// 推送 — 本函数入口处会调它一次,跨 ledger 并发的 fullPush 共享同一份
  /// user-global push,避免重复(详见 .docs/concurrent-fullpush-bloat.md)。
  Future<_PushTally> _pushAllEntities(Ledger ledger, Set<int>? recurringExclusions,
      Map<(String, String), List<int>> journalIds) async {
    // 1) 先推 user-global(单飞,多账本并行 fullPush 时共享同一次推送)
    final scope = _receiptScope;
    var outcome = await _pushUserGlobalResult();

    // 2) 再处理本 ledger 的 ledger-scope 推送
    // 跟增量 _push 保持一致:用 ledger.syncId 作为 server 认的 external_id,
    // 跨设备时同一账本永远同一个 external_id,不会分裂成多条。
    final ledgerId = ledger.syncId ?? ledger.id.toString();
    final now = DateTime.now().toUtc().toIso8601String();
    final syncChanges = <Map<String, dynamic>>[];
    final localIds = <(String, String), int>{('ledger', ledgerId): ledger.id};

    // 推一条 ledger:upsert,显式带 ledgerName + currency。否则:
    //   - storage.upload 的 metadata 虽然带了 currency,但 server 端 auto-create
    //     ledger 时不一定从 metadata 读 currency(字段名可能对不上,或默认走 CNY)
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

    // tx push 需要查类目/账户/标签的 syncId 做 denormalize 用,这里仍要预拉。
    // 分类自定义图标已经在 [pushUserGlobalEntities] 走 [_serializeEntityForPush]
    // 时上传到 server(payload 里带 iconCloudFileId/sha256),这里不需要再批量传。
    final categories = await db.select(db.categories).get();
    final accounts = await db.select(db.accounts).get();
    final tags = await db.select(db.tags).get();

    // 预算:按账本过滤推,不跨账本。分类预算带 categorySyncId。
    final budgets = await (db.select(db.budgets)
          ..where((b) => b.ledgerId.equals(ledger.id)))
        .get();
    for (final budget in budgets) {
      final syncId = budget.syncId ?? _uuid.v4();
      if (budget.syncId == null) {
        await (db.update(db.budgets)..where((b) => b.id.equals(budget.id)))
            .write(BudgetsCompanion(syncId: d.Value(syncId)));
      }
      String? catSyncId;
      if (budget.categoryId != null) {
        final cat = categories
            .cast<Category?>()
            .firstWhere((c) => c?.id == budget.categoryId, orElse: () => null);
        catSyncId = cat?.syncId;
      }
      localIds[('budget', syncId)] = budget.id;
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
          ..where((a) =>
              a.transactionId.isIn(transactions.map((t) => t.id).toList())))
        .get();
    final attachmentsByTx = <int, List<TransactionAttachment>>{};
    for (final a in allAttachments) {
      attachmentsByTx.putIfAbsent(a.transactionId, () => []).add(a);
    }

    for (final tx in transactions) {
      if (recurringExclusions?.contains(tx.id) ?? false) continue;
      final syncId = tx.syncId ?? _uuid.v4();
      if (tx.syncId == null) {
        await (db.update(db.transactions)..where((t) => t.id.equals(tx.id)))
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

      final txTags = await readTransactionSyncTags(db, tx, ledger.syncId);

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

      localIds[('transaction', syncId)] = tx.id;
      syncChanges.add({
        'ledger_id': ledgerId,
        'entity_type': 'transaction',
        'entity_sync_id': syncId,
        'action': 'upsert',
        'payload': {
          ...EntitySerializer.serializeTransaction(
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
            tagNames: txTags.names,
            tagSyncIds: txTags.ids,
            attachments: attMaps,
          ),
          if (recurringExclusions != null) 'restoredSnapshot': true,
        },
        'updated_at': now,
      });
    }

    // A snapshot can contain pre-journal entities. Stage them durably so an
    // interruption after creating the remote ledger can resume incrementally.
    // Keep an already-sent operation frozen across explicit full-upload retries.
    final snapshots = <Map<String, dynamic>>[];
    final retries = <LocalChange>[];
    await db.transaction(() async {
      _requireReceiptScope(scope);
      final pending = await changeTracker.getUnpushedChangesForLedger(ledger.id);
      final byId = {for (final row in pending) row.id: row};
      final pendingKeys = {for (final row in pending) (row.entityType, row.entitySyncId)};
      for (final change in syncChanges) {
        final key = (change['entity_type'] as String, change['entity_sync_id'] as String);
        final rows = (journalIds[key] ?? const <int>[]).map((id) => byId[id]).whereType<LocalChange>().toList();
        if (rows.any((row) => row.wireJson != null)) {
          retries.addAll(rows);
          continue;
        }
        final operation = rows.lastOrNull?.operationId ?? _uuid.v4();
        change['operation_id'] = operation;
        snapshots.add(change);
        final wire = jsonEncode({'scope': scope, 'change': change});
        if (rows.isNotEmpty) {
          await (db.update(db.localChanges)..where((c) => c.id.isIn(rows.map((r) => r.id))))
              .write(LocalChangesCompanion(wireJson: d.Value(wire)));
        } else if (!pendingKeys.contains(key)) {
          final id = await db.into(db.localChanges).insert(LocalChangesCompanion.insert(
              entityType: key.$1, entityId: localIds[key]!, entitySyncId: key.$2,
              ledgerId: ledger.id, action: 'upsert', operationId: d.Value(operation),
              wireJson: d.Value(wire), writeMicros: d.Value(DateTime.parse(now).microsecondsSinceEpoch)));
          journalIds[key] = [id];
        }
      }
    });
    outcome += await _sendTracked(retries, ledgerId);

    // 统计实体数量
    final accountCount = accounts.length;
    final categoryCount = categories.length;
    final tagCount = tags.length;
    final txCount = transactions.length;
    logger.info(
        'SyncEngine',
        '开始推送个体变更 共${syncChanges.length}条 '
            '(accounts=$accountCount, categories=$categoryCount, tags=$tagCount, transactions=$txCount)');

    // 分批推送:每条 change 平均 ~500 字节,500 条 ≈ 250KB,远低于网关限制,
    // 但单次请求内 server 事务处理时间 ~100ms 可接受。
    // 5 倍原先 100 的吞吐,3 万条交易上传从 300 批降到 60 批,耗时约 1/5。
    const batchSize = 500;
    for (var i = 0; i < snapshots.length; i += batchSize) {
      final end = (i + batchSize > snapshots.length)
          ? snapshots.length
          : i + batchSize;
      final batch = snapshots.sublist(i, end);
      try {
        logger.info('SyncEngine',
            '推送批次 ${i ~/ batchSize + 1}: ${batch.length}条 (${i + 1}-$end)');
        _requireReceiptScope(scope);
        final receipt = await provider.pushChanges(changes: batch);
        outcome += await _settleBatch(scope, batch, receipt, [
          for (final change in batch)
            journalIds[(change['entity_type'] as String, change['entity_sync_id'] as String)] ?? const <int>[],
        ]);
        logger.info('SyncEngine', '批次 ${i ~/ batchSize + 1} 推送成功');
      } catch (e, st) {
        logger.error('SyncEngine', '批次 ${i ~/ batchSize + 1} 推送失败', e, st);
        rethrow; // 让调用方知道失败
      }
    }

    logger.info('SyncEngine', '全量推送个体变更完成 ${snapshots.length} 条');
    return outcome;
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

      final txTags = await readTransactionSyncTags(db, tx, ledger.syncId);

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
        tagNames: txTags.names,
        tagSyncIds: txTags.ids,
      ));
    }

    return jsonEncode({
      'version': 6,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'ledgerId': ledger.id,
      'ledgerName': ledger.name,
      'currency': ledger.currency,
      'monthStartDay': ledger.monthStartDay,
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
