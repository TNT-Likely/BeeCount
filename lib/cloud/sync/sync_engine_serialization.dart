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
  Future<void> fullPush(
      {required int ledgerId, bool resumePreparation = false}) async {
    (await _fullPushResult(ledgerId, remoteExists: resumePreparation))
        .requireSuccess();
  }

  Future<bool> _hasFullPreparation(Ledger ledger) async {
    final key = ledger.syncId;
    if (key == null || (ledger.isShared && ledger.myRole != 'owner')) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_fullPreparationKey(_receiptScope, key));
  }

  /// Missing metadata is authoritative only after a successful remote list.
  /// A device with no bootstrap checkpoint only sends its normal journal to
  /// an existing ledger, including a partial restore or a shared editor copy.
  Future<InitialUploadAction> initialUploadAction(Ledger ledger,
      {required bool? remoteExists}) async {
    if (remoteExists == null || (ledger.isShared && ledger.myRole != 'owner')) {
      return InitialUploadAction.incremental;
    }
    if (!remoteExists) return InitialUploadAction.create;
    return await _hasFullPreparation(ledger)
        ? InitialUploadAction.resume
        : InitialUploadAction.incremental;
  }

  String _fullPreparationKey(String scope, String ledger) {
    final digest = sha256.convert(utf8.encode(jsonEncode([scope, ledger])));
    return 'beecount_full_push_preparing_$digest';
  }

  Future<_PushTally> _fullPushResult(int ledgerId,
      {bool remoteExists = false}) async {
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
      final tally =
          await _doFullPush(ledgerId: ledgerId, remoteExists: remoteExists);
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

  Future<_PushTally> _doFullPush(
      {required int ledgerId, required bool remoteExists}) async {
    logger.info('SyncEngine', '开始全量推送 ledger=$ledgerId');

    Future<Ledger> readLedger() =>
        (db.select(db.ledgers)..where((l) => l.id.equals(ledgerId)))
            .getSingle();
    var ledger = await readLedger();
    if (ledger.syncId == null || ledger.syncId!.length < 3) {
      await _ensureLedgerSyncId(ledger);
      ledger = await readLedger();
    }
    final pathForSnapshot = ledger.syncId!;
    // The remote ledger can become visible before any historical row has a local
    // journal entry. Restart preparation at its original write time in that window.
    final scope = _receiptScope;
    final prefs = await SharedPreferences.getInstance();
    final preparation = _fullPreparationKey(scope, pathForSnapshot);
    final previousStart = prefs.getInt(preparation);
    final startedAt = previousStart ?? DateTime.now().microsecondsSinceEpoch;
    if (previousStart == null && !await prefs.setInt(preparation, startedAt)) {
      throw CloudStorageException('Could not save initial upload progress');
    }

    // 0. 先用专用的 writeCreateLedger API(POST /write/ledgers)显式带 currency
    //    创建 server 端账本。这是修复"app 选 JPY 创建账本,server 端却是 CNY"的
    //    关键:之前 fullPush 只走 storage.upload,server auto-create ledger 时
    //    可能不读 metadata 的 currency,fallback 到默认 CNY;后续的 ledger:upsert
    //    change 在某些 server 实现下也只更新已存在 ledger,不能改它的 currency。
    //    用 dedicated API 显式声明 ledger_id + ledger_name + currency,server
    //    能正确建账本。
    //    幂等性:如果账本已存在(例如老数据 / 重试),server 会返回 409 或类似错误,
    //    这里 try/catch 吞掉,不阻塞后续 storage.upload + _pushAllEntities。
    if (!remoteExists) {
      try {
        await provider.writeCreateLedger(
          ledgerId: pathForSnapshot,
          ledgerName: ledger.name,
          currency: ledger.currency,
          // The create endpoint emits ledger metadata before later snapshot/upserts.
          // Preserve the period there so its default 1 cannot be replayed over us.
          monthStartDay: ledger.monthStartDay,
          idempotencyKey:
              'initial-${sha256.convert(utf8.encode('$pathForSnapshot/$startedAt'))}',
        );
        logger.info('SyncEngine',
            'writeCreateLedger 成功: ledgerId=$pathForSnapshot, name=${ledger.name}, currency=${ledger.currency}');
      } catch (e, st) {
        // 已存在 / 其他错误都不阻断流程,后续 storage.upload + _pushAllEntities
        // 仍会跑,部分 server 实现会从这两条路径 auto-create / 修正 meta。
        logger.warning('SyncEngine',
            'writeCreateLedger 失败（已存在或其他原因,继续走 storage 上传）: $e', st);
      }
    }

    // A recurring ledger may already have server-only entries and later edits.
    final held = await _adoptBeforeUpload(ledger);
    // Only acknowledge changes present before this upload started.
    final unpushed = await changeTracker.getUnpushedChangesForLedger(ledgerId);
    final bulkExclusions =
        await _recurringBulkExclusions(ledger, held, unpushed);
    // 1. 上传 JSON 快照
    //    path 用 ledger.syncId，跟 _push/_pushAllEntities 的 ledger_id 一致，
    //    避免 server 出现两条 external_id 指向同一账本的分裂。
    if (bulkExclusions == null && !remoteExists) {
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
    _requireReceiptScope(scope);
    return _pushAllEntities(
        ledger, bulkExclusions, journalIds, startedAt, remoteExists, () async {
      if (!await prefs.remove(preparation)) {
        throw CloudStorageException(
            'Could not finish initial upload preparation');
      }
    });
  }

  /// 推送所有实体为个体变更(fullPush 时调用)。
  ///
  /// **只处理 ledger-scope 实体**(ledger / budget / transaction)。user-global
  /// 实体(account / category / tag)由调用方通过 [pushUserGlobalEntities] 统一
  /// 推送 — 本函数入口处会调它一次,跨 ledger 并发的 fullPush 共享同一份
  /// user-global push,避免重复(详见 .docs/concurrent-fullpush-bloat.md)。
  Future<_PushTally> _pushAllEntities(
    Ledger ledger,
    Set<int>? recurringExclusions,
    Map<(String, String), List<int>> journalIds,
    int startedAt,
    bool remoteExists,
    Future<void> Function() staged,
  ) async {
    const pageSize = 500;
    final scope = _receiptScope;
    var outcome = await _pushUserGlobalResult();
    final ledgerKey = ledger.syncId!;
    final now = DateTime.fromMicrosecondsSinceEpoch(startedAt, isUtc: true)
        .toIso8601String();
    final order = <(String, String)>[];
    final retries = <LocalChange>[];

    // Each local read and write batch only holds one page of transaction payloads.
    // All pages commit together before a network request can observe the outbox.
    await db.transaction(() async {
      _requireReceiptScope(scope);
      final pending =
          await changeTracker.getUnpushedChangesForLedger(ledger.id);
      final byId = {for (final row in pending) row.id: row};
      final pendingKeys = {
        for (final row in pending) (row.entityType, row.entitySyncId)
      };
      final newKeys = <(String, String)>{};

      Future<void> stage(
              List<
                      ({
                        int id,
                        String type,
                        String key,
                        Map<String, dynamic> payload
                      })>
                  page) =>
          db.batch((batch) {
            for (final entity in page) {
              final key = (entity.type, entity.key);
              final rows = (journalIds[key] ?? const <int>[])
                  .map((id) => byId[id])
                  .whereType<LocalChange>()
                  .toList();
              if (rows.any((row) => row.wireJson != null)) {
                retries.addAll(rows);
                continue;
              }
              // A later edit/delete has its own operation and receipt.
              if (rows.isEmpty && pendingKeys.contains(key)) continue;
              final operation = rows.lastOrNull?.operationId ?? _uuid.v4();
              final change = {
                'ledger_id': ledgerKey,
                'entity_type': entity.type,
                'entity_sync_id': entity.key,
                'action': 'upsert',
                'payload': entity.payload,
                // The explicit create endpoint just initialized ledger metadata.
                'updated_at': entity.type == 'ledger'
                    ? DateTime.now().toUtc().toIso8601String()
                    : now,
                'operation_id': operation,
              };
              final wire = jsonEncode({'scope': scope, 'change': change});
              order.add(key);
              if (rows.isEmpty) {
                newKeys.add(key);
                batch.insert(
                    db.localChanges,
                    LocalChangesCompanion.insert(
                        entityType: entity.type,
                        entityId: entity.id,
                        entitySyncId: entity.key,
                        ledgerId: ledger.id,
                        action: 'upsert',
                        operationId: d.Value(operation),
                        wireJson: d.Value(wire),
                        writeMicros: d.Value(startedAt)));
              } else {
                for (final row in rows) {
                  batch.update(db.localChanges,
                      LocalChangesCompanion(wireJson: d.Value(wire)),
                      where: (c) => c.id.equals(row.id));
                }
              }
            }
          });

      // A resumed remote ledger already has metadata from its create request.
      // Subsequent metadata edits have their own journal entries.
      if (!remoteExists) {
        await stage([
          (
            id: ledger.id,
            type: 'ledger',
            key: ledgerKey,
            payload: EntitySerializer.serializeLedger(ledger)
          )
        ]);
      }
      final categories = {
        for (final c in await db.select(db.categories).get()) c.id: c
      };
      final accounts = {
        for (final a in await db.select(db.accounts).get()) a.id: a
      };
      final budgets = await (db.select(db.budgets)
            ..where((b) => b.ledgerId.equals(ledger.id)))
          .get();
      for (final budget in budgets) {
        final key = budget.syncId ?? _uuid.v4();
        if (budget.syncId == null) {
          await (db.update(db.budgets)..where((b) => b.id.equals(budget.id)))
              .write(BudgetsCompanion(syncId: d.Value(key)));
        }
        await stage([
          (
            id: budget.id,
            type: 'budget',
            key: key,
            payload: EntitySerializer.serializeBudget(budget,
                ledgerSyncId: ledgerKey,
                categorySyncId: categories[budget.categoryId]?.syncId)
          )
        ]);
      }
      int? after;
      while (true) {
        final query = db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledger.id))
          ..orderBy([(t) => d.OrderingTerm.asc(t.id)])
          ..limit(pageSize);
        if (after != null) query.where((t) => t.id.isBiggerThanValue(after!));
        final transactions = await query.get();
        if (transactions.isEmpty) break;
        final ids = transactions.map((t) => t.id).toList();
        final tagLinks = await readLedgerSyncTags(db, ledger,
            firstId: ids.first, lastId: ids.last);
        final attachments = await (db.select(db.transactionAttachments)
              ..where((a) => a.transactionId.isIn(ids))
              ..orderBy([
                (a) => d.OrderingTerm.asc(a.sortOrder),
                (a) => d.OrderingTerm.asc(a.id)
              ]))
            .get();
        final byTx = <int, List<Map<String, dynamic>>>{};
        for (final att in attachments) {
          (byTx[att.transactionId] ??= []).add({
            'fileName': att.fileName,
            'originalName': att.originalName,
            'fileSize': att.fileSize,
            'width': att.width,
            'height': att.height,
            'sortOrder': att.sortOrder,
            if (att.cloudFileId != null) 'cloudFileId': att.cloudFileId,
            if (att.cloudSha256 != null) 'cloudSha256': att.cloudSha256,
          });
        }
        final page = <({
          int id,
          String type,
          String key,
          Map<String, dynamic> payload
        })>[];
        for (final tx in transactions) {
          if (recurringExclusions?.contains(tx.id) ?? false) continue;
          final key = tx.syncId ?? _uuid.v4();
          if (tx.syncId == null) {
            await (db.update(db.transactions)..where((t) => t.id.equals(tx.id)))
                .write(TransactionsCompanion(syncId: d.Value(key)));
          }
          final cat = categories[tx.categoryId];
          final acc = accounts[tx.accountId];
          final to = accounts[tx.toAccountId];
          final tags = tagLinks[tx.id];
          final payload = EntitySerializer.serializeTransaction(
            tx.syncId == null ? tx.copyWith(syncId: d.Value(key)) : tx,
            categoryName: cat?.name,
            categoryKind: cat?.kind,
            categorySyncId: cat?.syncId,
            accountName: acc?.name,
            accountSyncId: acc?.syncId,
            fromAccountName: tx.type == 'transfer' ? acc?.name : null,
            fromAccountSyncId: tx.type == 'transfer' ? acc?.syncId : null,
            toAccountName: to?.name,
            toAccountSyncId: to?.syncId,
            ledgerSyncId: ledgerKey,
            tagNames: tags?.names ?? const [],
            tagSyncIds: tags?.ids.toList() ?? const [],
            attachments: byTx[tx.id] ?? const [],
          );
          if (recurringExclusions != null) payload['restoredSnapshot'] = true;
          page.add(
              (id: tx.id, type: 'transaction', key: key, payload: payload));
        }
        await stage(page);
        after = ids.last;
        if (transactions.length < pageSize) break;
      }
      if (newKeys.isNotEmpty) {
        final t = db.localChanges;
        final inserted = await (db.selectOnly(t)
              ..addColumns([t.id, t.entityType, t.entitySyncId])
              ..where(t.ledgerId.equals(ledger.id) & t.pushedAt.isNull()))
            .get();
        for (final row in inserted) {
          final key = (row.read(t.entityType)!, row.read(t.entitySyncId)!);
          if (newKeys.contains(key)) journalIds[key] = [row.read(t.id)!];
        }
      }
      _requireReceiptScope(scope);
    });

    // From this point a normal incremental sync can finish the durable outbox,
    // even if the first request fails or its successful reply is lost.
    await staged();
    outcome += await _sendTracked(retries, ledgerKey);
    for (var at = 0; at < order.length; at += pageSize) {
      final keys = order.sublist(at, (at + pageSize).clamp(at, order.length));
      final ids = [for (final key in keys) journalIds[key]!];
      final t = db.localChanges;
      final rows = await (db.selectOnly(t)
            ..addColumns([t.id, t.wireJson])
            ..where(t.id.isIn(ids.map((r) => r.first))))
          .get();
      final wires = {
        for (final row in rows)
          row.read(t.id)!: (jsonDecode(row.read(t.wireJson)!)['change']
              as Map<String, dynamic>)
      };
      final outgoing = [for (final group in ids) wires[group.first]!];
      _requireReceiptScope(scope);
      final receipt = await provider.pushChanges(changes: outgoing);
      outcome += await _settleBatch(scope, outgoing, receipt, ids);
    }
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
    final categoriesById = {for (final cat in categories) cat.id: cat};
    final accountsById = {for (final acc in accounts) acc.id: acc};
    final tagsByTx = await readLedgerSyncTags(db, ledger);
    for (final tx in transactions) {
      final cat = categoriesById[tx.categoryId];
      final acc = accountsById[tx.accountId];
      final toAcc = accountsById[tx.toAccountId];
      final txTags = tagsByTx[tx.id];

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
        tagNames: txTags?.names ?? const [],
        tagSyncIds: txTags?.ids.toList() ?? const [],
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
