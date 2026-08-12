part of 'sync_engine.dart';

/// WebSocket 实时事件监听 + auto sync / pull 调度。
///
/// `startListeningRealtime` / `stopListeningRealtime` / `triggerAutoSync` 是
/// public,被 `sync_providers.dart` / `sync_coordinator.dart` 调用——所以
/// extension 必须 public(`_` 私有的 extension 在 library 外不可见)。
extension SyncEngineRealtime on SyncEngine {
  /// 开始监听 WebSocket 实时事件，收到变更通知时自动触发 pull
  void startListeningRealtime() {
    _realtimeSubscription?.cancel();
    // 启动 WebSocket 连接，否则 realtimeEvents 流永远为空
    provider.startRealtime().catchError((e) {
      logger.warning('SyncEngine', 'WebSocket 启动失败: $e');
    });
    _realtimeSubscription = provider.realtimeEvents.listen((event) {
      if (event.type == 'sync_change' || event.type == 'backup_restore') {
        logger.info('SyncEngine',
            '收到实时事件: type=${event.type}, ledgerId=${event.ledgerId}');
        _schedulePull(event.ledgerId);
      } else if (event.type == 'profile_change') {
        // A 设备改主题色 / 收支配色 / 外观 / 头像 → server 广播。这里拉一下
        // /profile/me,把 theme_primary_color / income_is_red / appearance
        // 写回本地 SharedPreferences,让 B 无感同步。
        logger.info('SyncEngine', '收到实时事件: profile_change');
        unawaited(syncMyProfile().then((changed) {
          if (changed) {
            final ledgerId = event.ledgerId ?? '';
            _emit(PullCompleted(ledgerId: ledgerId));
          }
        }));
      } else if (event.type == 'connected') {
        // WS 连接建立（首次或断线重连）。离线期间累积的 local_changes 这里
        // 顺带 flush 一次，否则用户要等下一次交易写入 PostProcessor.sync()
        // 才能把东西推出去。
        logger.info('SyncEngine', 'WS connected, scheduling auto sync');
        _scheduleAutoSync(reason: 'ws_connected');
      } else if (event.type == 'member_change') {
        logger.info('SyncEngine',
            '收到 member_change: ledger=${event.ledgerId} change=${event.rawData['changeType']}');
        unawaited(_handleMemberChange(event));
      } else if (event.type == 'shared_resource_change') {
        logger.info('SyncEngine',
            '收到 shared_resource_change: ledger=${event.ledgerId} '
            'resource=${event.rawData['resourceType']} action=${event.rawData['action']}');
        unawaited(_handleSharedResourceChange(event));
      }
    }, onError: (Object e) {
      logger.warning('SyncEngine', '实时事件流错误: $e');
    });
    logger.info('SyncEngine', '已开始监听实时事件');
  }

  /// 停止监听 WebSocket 实时事件
  void stopListeningRealtime() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _pullDebounce?.cancel();
    _pullDebounce = null;
    _autoSyncDebounce?.cancel();
    _autoSyncDebounce = null;
    logger.info('SyncEngine', '已停止监听实时事件');
  }

  /// 防抖调度一次完整 sync（push + pull）。WS 重连 / 网络恢复 都会打到这里。
  /// 2 秒防抖：WiFi ↔ 移动网络切换、或 WS reconnect 接着 connectivity 事件
  /// 这种"连续上线信号"只触发 1 次 sync。
  void _scheduleAutoSync({required String reason}) {
    _autoSyncDebounce?.cancel();
    _autoSyncDebounce = Timer(const Duration(seconds: 2), () async {
      if (_autoSyncing) {
        logger.debug('SyncEngine',
            'auto sync 跳过 (reason=$reason, 已在执行中)');
        return;
      }
      final resolver = ledgerIdResolver;
      if (resolver == null) {
        logger.debug('SyncEngine', 'auto sync 跳过 (reason=$reason, 无 resolver)');
        return;
      }
      final ledgerId = resolver();
      if (ledgerId.isEmpty || ledgerId == '0') {
        logger.debug('SyncEngine',
            'auto sync 跳过 (reason=$reason, ledgerId 为空)');
        return;
      }
      _autoSyncing = true;
      try {
        logger.info('SyncEngine',
            'auto sync 触发 (reason=$reason, ledger=$ledgerId)');
        // §7 共享账本:WS 重连 / 网络恢复时,顺手对账 ledger 列表 + 共享账本
        // 状态。如果 WS 期间错过了 member_change.removed(被踢),GC 1 会自动
        // 清掉本地残留共享账本;还有 dup ledger 检测兜底。
        //
        // reason 字符串包括:
        //   - `ws_connected`:WS 首连 / 重连
        //   - `network_restored` / `connectivity_restored`:网络恢复
        //     (sync_providers.dart 内 connectivity_plus listener 传的是
        //     `connectivity_restored`)
        // 这里同时匹配三种以兼容历史 caller。
        if (reason == 'ws_connected' ||
            reason == 'network_restored' ||
            reason == 'connectivity_restored') {
          try {
            await syncLedgersFromServer();
          } catch (e, st) {
            logger.warning('SyncEngine',
                'auto sync 内的 syncLedgersFromServer 失败,继续 sync', st);
            logger.warning('SyncEngine', 'error: $e');
          }
          // Sprint 5.1 边界:WS server 不持久化离线事件 — 用户在 Editor 视角
          // 离线期间 Owner 改了分类 / 账户 / 标签,shared_resource_change 直接
          // 被丢弃。重连时不主动对账,SharedLedger* 镜像表会一直 stale 到下一
          // 次 owner 再次改动才触发更新。reconciliation 走这里,对每个本人为
          // Editor 角色的本地共享账本拉一次 /shared-resources 覆盖镜像表。
          try {
            await _refreshAllSharedResourcesAfterReconnect();
          } catch (e, st) {
            logger.error('SyncEngine',
                '重连共享资源对账失败,继续 sync', e, st);
          }
        }
        final result = await sync(ledgerId: ledgerId);
        if (result.hasError) {
          logger.warning('SyncEngine',
              'auto sync 失败 (reason=$reason): ${result.error}');
        } else {
          logger.info('SyncEngine',
              'auto sync 完成 (reason=$reason): pushed=${result.pushed} pulled=${result.pulled}');
        }
      } catch (e, st) {
        logger.error('SyncEngine', 'auto sync 异常 (reason=$reason)', e, st);
      } finally {
        _autoSyncing = false;
      }
    });
  }

  /// 外部触发（例如 connectivity_plus 监听到网络恢复）。内部防抖、单飞。
  void triggerAutoSync({required String reason}) {
    _scheduleAutoSync(reason: reason);
  }

  /// 处理 server 推过来的 `member_change` 事件:成员加入 / 角色变更 / 被移除。
  /// 被踢的当事人 → 清本地 ledger + SharedLedger* 行;其他场景触发拉成员列表
  /// 刷新 + 触发账本元数据重拉(memberCount 等可能变了)。
  Future<void> _handleMemberChange(BeeCountCloudRealtimeEvent event) async {
    final ledgerExternalId = event.ledgerId;
    if (ledgerExternalId == null || ledgerExternalId.isEmpty) return;
    final changeType = event.rawData['changeType'] as String?;
    final affectedUserId = event.rawData['userId'] as String?;
    // provider.auth.currentUser 是 Future<CloudUser?>;CloudUser.id 是 user uuid
    final me = await provider.auth.currentUser;
    final myUserId = me?.id;

    try {
      if (changeType == 'removed' && affectedUserId != null && affectedUserId == myUserId) {
        // 自己被踢:清本地该 ledger 数据
        await _purgeLocalLedgerByExternalId(ledgerExternalId);
        _emit(PullCompleted(ledgerId: ledgerExternalId));
        logger.info('SyncEngine', '自己被踢出 ledger=$ledgerExternalId,已清本地数据');
        return;
      }

      // §7 共享账本:自己在 web 端 accept invite → server 广播 member_change.
      // joined 给所有 member 包括自己。mobile 端不是 caller,onInviteAccepted
      // 不会跑,但需要跟 mobile-side accept 等价的完整初始化流程:
      //   1. syncLedgersFromServer 拉新 ledger 行(内部自动调
      //      fetchAndStoreSharedResources 拉 SharedLedger* 资源)
      //   2. replayAllChanges 把 sync_changes 表所有历史 tx 重新 apply 到本地
      //      (单跑 _pull 拉不回历史 — 设备 cursor 已经在最新位置)
      if (changeType == 'joined' && affectedUserId != null && affectedUserId == myUserId) {
        logger.info('SyncEngine',
            '自己加入 ledger=$ledgerExternalId(可能 web 端 accept),触发完整初始化');
        await syncLedgersFromServer();
        await replayAllChanges();
        _emit(PullCompleted(ledgerId: ledgerExternalId));
        return;
      }

      // 其他场景(别人 joined / 角色变 / 被踢 / 别人退出):重拉 ledgers
      // list(memberCount / isShared 可能变),不阻塞
      await syncLedgersFromServer();
      _emit(PullCompleted(ledgerId: ledgerExternalId));
    } catch (e, st) {
      logger.warning('SyncEngine', 'handleMemberChange 失败', st);
      logger.warning('SyncEngine', 'error: $e');
    }
  }

  /// 处理 Owner user-global category/account/tag 变更的 fan-out。
  /// 直接增量更新本地 SharedLedger{Categories,Accounts,Tags} 行(写主表是
  /// Owner 操作,Editor 端只镜像)。
  Future<void> _handleSharedResourceChange(BeeCountCloudRealtimeEvent event) async {
    final ledgerExternalId = event.ledgerId;
    if (ledgerExternalId == null || ledgerExternalId.isEmpty) return;
    final resourceType = event.rawData['resourceType'] as String?;
    final action = event.rawData['action'] as String?;
    final payload = event.rawData['payload'];
    if (resourceType == null || action == null || payload is! Map) return;
    // Mobile serialize tag/category/account 时 key 是 camelCase('syncId'),
    // 但 server fan-out 时 ev["sync_id"] 也填了 entity_sync_id 兜底。
    // 优先读 camelCase(mobile push 实际值),snake_case 兜底。
    final syncId = (payload['syncId'] as String?) ??
        (payload['sync_id'] as String?);
    if (syncId == null || syncId.isEmpty) return;
    final now = DateTime.now().toUtc();

    try {
      switch (resourceType) {
        case 'category':
          if (action == 'delete') {
            await (db.delete(db.sharedLedgerCategories)
                  ..where((t) =>
                      t.ledgerSyncId.equals(ledgerExternalId) &
                      t.syncId.equals(syncId)))
                .go();
            // v25 不 mirror 主表 → 无需删主表
          } else {
            await db.into(db.sharedLedgerCategories).insertOnConflictUpdate(
                  SharedLedgerCategoriesCompanion.insert(
                    ledgerSyncId: ledgerExternalId,
                    syncId: syncId,
                    name: (payload['name'] as String?) ?? '',
                    kind: (payload['kind'] as String?) ?? 'expense',
                    icon: d.Value(payload['icon'] as String?),
                    iconType: d.Value(
                        (payload['iconType'] as String?) ?? 'material'),
                    iconCloudFileId:
                        d.Value(payload['iconCloudFileId'] as String?),
                    iconCloudSha256:
                        d.Value(payload['iconCloudSha256'] as String?),
                    color: d.Value(payload['color'] as String?),
                    sortOrder: d.Value(
                        (payload['sortOrder'] as num?)?.toInt() ?? 0),
                    level:
                        d.Value((payload['level'] as num?)?.toInt() ?? 1),
                    parentName: d.Value(payload['parentName'] as String?),
                    parentSyncId: d.Value(payload['parentSyncId'] as String?),
                    updatedAt: now,
                  ),
                );
            // §7 决策 v25 — 不再 mirror 主表。自定义图标走 sha256 cache
            // 异步下载,不阻塞 WS handler。
            await _downloadOneCustomIconIfNeeded(payload);
          }
          break;
        case 'account':
          if (action == 'delete') {
            await (db.delete(db.sharedLedgerAccounts)
                  ..where((t) =>
                      t.ledgerSyncId.equals(ledgerExternalId) &
                      t.syncId.equals(syncId)))
                .go();
            // v25 不 mirror 主表 → 无需删主表
          } else {
            // mobile EntitySerializer.serializeAccount 用 'type' 字段
            // (跟主表 Accounts.type 一致),WS handler 也按 'type' 读
            final accountType =
                (payload['type'] as String?) ?? 'cash';
            await db.into(db.sharedLedgerAccounts).insertOnConflictUpdate(
                  SharedLedgerAccountsCompanion.insert(
                    ledgerSyncId: ledgerExternalId,
                    syncId: syncId,
                    name: (payload['name'] as String?) ?? '',
                    accountType: d.Value(accountType),
                    currency: d.Value(
                        (payload['currency'] as String?) ?? 'CNY'),
                    note: d.Value(payload['note'] as String?),
                    initialBalance: d.Value(
                        (payload['initialBalance'] as num?)?.toDouble()),
                    creditLimit: d.Value(
                        (payload['creditLimit'] as num?)?.toDouble()),
                    billingDay: d.Value(
                        (payload['billingDay'] as num?)?.toInt()),
                    paymentDueDay: d.Value(
                        (payload['paymentDueDay'] as num?)?.toInt()),
                    bankName: d.Value(payload['bankName'] as String?),
                    cardLastFour:
                        d.Value(payload['cardLastFour'] as String?),
                    updatedAt: now,
                  ),
                );
            // v25:不 mirror 主表
          }
          break;
        case 'tag':
          if (action == 'delete') {
            await (db.delete(db.sharedLedgerTags)
                  ..where((t) =>
                      t.ledgerSyncId.equals(ledgerExternalId) &
                      t.syncId.equals(syncId)))
                .go();
            // v25 不 mirror 主表 → 无需删主表
          } else {
            await db.into(db.sharedLedgerTags).insertOnConflictUpdate(
                  SharedLedgerTagsCompanion.insert(
                    ledgerSyncId: ledgerExternalId,
                    syncId: syncId,
                    name: (payload['name'] as String?) ?? '',
                    color: d.Value(payload['color'] as String?),
                    updatedAt: now,
                  ),
                );
            // v25:不 mirror 主表
          }
          break;
      }
      // 共享资源变化的精确信号(sharedResourceRefreshProvider 在此 bump),
      // 跟 PullCompleted 分开避免 home 全局刷新 — Owner 改分类/账户/标签时
      // tx 数据本身没变,home 不该清缓存重建。SharedResourceChanged listener
      // 走 `forceStreamModeImmediate`,让 Drift table-watch 自然推 stream
      // 更新(category JOIN 会带新 name/icon)。
      _emit(SharedResourceChanged(ledgerId: ledgerExternalId));
    } catch (e, st) {
      logger.warning('SyncEngine',
          'handleSharedResourceChange 失败 type=$resourceType action=$action', st);
      logger.warning('SyncEngine', 'error: $e');
    }
  }

  /// Sprint 5.1 边界:WS 重连后对账所有 Editor 角色的共享账本。WS server
  /// 不持久化离线事件(websocket_manager.broadcast_to_user 找不到 socket 就
  /// 丢弃),Editor 离线期间 Owner 改的分类 / 账户 / 标签全部丢失 →
  /// SharedLedger* 镜像表 stale。
  ///
  /// 本方法在 _scheduleAutoSync(reason='ws_connected'/'network_restored')
  /// 里调,对每个本地 ledger 行 isShared=true && myRole='editor' 的共享账本
  /// 单独 await 拉 /shared-resources。Owner 角色不需要 — 他自己的资源在主表
  /// (categories/accounts/tags),走正常 sync_change 路径。
  ///
  /// 每个账本独立 try/catch,单个失败不影响其它账本。结束后 bump tick 让
  /// picker / 反查 widget reactive 刷新。
  Future<void> _refreshAllSharedResourcesAfterReconnect() async {
    final rows = await (db.select(db.ledgers)
          ..where((l) => l.isShared.equals(true) & l.myRole.equals('editor')))
        .get();
    if (rows.isEmpty) return;
    logger.info('SyncEngine',
        '重连共享资源对账:Editor 角色账本 ${rows.length} 个');
    // 并发拉(每账本独立 HTTP),原串行 await 在多账本场景下会 N×RTT 阻塞
    // 整条 auto sync 链。Future.wait + 在 inner future 内吞错保证一个失败
    // 不影响其它账本。
    final futures = <Future<bool>>[];
    for (final l in rows) {
      final sid = l.syncId;
      if (sid == null || sid.isEmpty) continue;
      futures.add(() async {
        try {
          await fetchAndStoreSharedResources(sid);
          return true;
        } catch (e, st) {
          logger.error('SyncEngine',
              '重连共享资源对账失败 ledger=$sid', e, st);
          return false;
        }
      }());
    }
    final results = await Future.wait(futures);
    final ok = results.where((v) => v).length;
    final fail = results.length - ok;
    logger.info('SyncEngine',
        '重连共享资源对账完成 ok=$ok fail=$fail');
    if (ok > 0) {
      // 只 emit SharedResourceChanged — 重连补拉的只是 SharedLedger* 镜像表,
      // tx 没变,不该让 home 整页刷新。Editor 的 TransactionList 监听
      // sharedResourceRefreshProvider 走 forceStreamModeImmediate 即可。
      _emit(const SharedResourceChanged(ledgerId: ''));
    }
  }

  /// Editor 接受邀请成功后调用:
  /// 1. 触发一次 syncLedgersFromServer 把新 ledger 拉到本地
  /// 2. 拉 Owner user-global 资源快照 → 写本地 SharedLedger* 镜像表
  /// 3. 触发 pull 把现有 tx 历史灌进本地
  ///
  /// 失败会写 warning log,不抛(UI 已经显示"加入成功",数据慢慢补)。
  /// 拉 server `/shared-resources` snapshot + 全量写入 SharedLedger{Categories,
  /// Accounts,Tags} 表(先清旧后插)。自定义图标走 sha256 cache 异步下载。
  ///
  /// 复用场景:
  /// - 邀请接受后(onInviteAccepted)
  /// - 新设备登录,Editor 已有 LedgerMember 记录,首次拉 ledgers 时检测到
  ///   isShared && myRole != 'owner' → 触发这个 helper 把资源落库
  /// - 用户手动刷新共享账本(将来 UI 加按钮)
  Future<void> fetchAndStoreSharedResources(String ledgerExternalId) async {
    final snapshot = await provider.fetchSharedResources(ledgerId: ledgerExternalId);
    final now = DateTime.now().toUtc();

    await db.transaction(() async {
      await (db.delete(db.sharedLedgerCategories)
            ..where((t) => t.ledgerSyncId.equals(ledgerExternalId)))
          .go();
      for (final c in snapshot.categories) {
        await db.into(db.sharedLedgerCategories).insert(
              SharedLedgerCategoriesCompanion.insert(
                ledgerSyncId: ledgerExternalId,
                syncId: c.syncId,
                name: c.name,
                kind: c.kind,
                icon: d.Value(c.icon),
                iconType: d.Value(c.iconType ?? 'material'),
                iconCloudFileId: d.Value(c.iconCloudFileId),
                iconCloudSha256: d.Value(c.iconCloudSha256),
                sortOrder: d.Value(c.sortOrder ?? 0),
                level: d.Value(c.level ?? 1),
                parentName: d.Value(c.parentName),
                parentSyncId: d.Value(c.parentSyncId),
                updatedAt: now,
              ),
            );
      }
      await (db.delete(db.sharedLedgerAccounts)
            ..where((t) => t.ledgerSyncId.equals(ledgerExternalId)))
          .go();
      for (final a in snapshot.accounts) {
        await db.into(db.sharedLedgerAccounts).insert(
              SharedLedgerAccountsCompanion.insert(
                ledgerSyncId: ledgerExternalId,
                syncId: a.syncId,
                name: a.name,
                accountType: d.Value(a.accountType ?? 'cash'),
                currency: d.Value(a.currency ?? 'CNY'),
                note: d.Value(a.note),
                initialBalance: d.Value(a.initialBalance),
                creditLimit: d.Value(a.creditLimit),
                billingDay: d.Value(a.billingDay),
                paymentDueDay: d.Value(a.paymentDueDay),
                bankName: d.Value(a.bankName),
                cardLastFour: d.Value(a.cardLastFour),
                updatedAt: now,
              ),
            );
      }
      await (db.delete(db.sharedLedgerTags)
            ..where((t) => t.ledgerSyncId.equals(ledgerExternalId)))
          .go();
      for (final t in snapshot.tags) {
        await db.into(db.sharedLedgerTags).insert(
              SharedLedgerTagsCompanion.insert(
                ledgerSyncId: ledgerExternalId,
                syncId: t.syncId,
                name: t.name,
                color: d.Value(t.color),
                updatedAt: now,
              ),
            );
      }
    });
    logger.info('SyncEngine',
        'fetchAndStoreSharedResources ledger=$ledgerExternalId categories=${snapshot.categories.length} accounts=${snapshot.accounts.length} tags=${snapshot.tags.length}');

    // §7 决策(v25):自定义图标走 sha256 cache 异步下载,SharedLedger* 行
    // 已落地,UI 渲染按 'custom_icons/shared_<sha256>.png' 路径查找。
    await _downloadCustomIconsForSharedSnapshot(snapshot);

    // 共享资源整批刷过,通知 UI 重渲(HomePage StreamBuilder 重订阅 +
    // picker / 反查 widget rebuild)。不在 _refreshAllSharedResourcesAfterReconnect
    // 里调,因为那个方法会逐账本调本函数,每个账本独立 fire。
    _emit(SharedResourceChanged(ledgerId: ledgerExternalId));
  }

  Future<void> onInviteAccepted(String ledgerExternalId) async {
    try {
      await syncLedgersFromServer();
      // GC:清掉所有 ledger_sync_id 在 ledgers 表里找不到的孤儿 SharedLedger*
      // 行。测试 / 退出账本 / Owner 删账本 留下的残留(数据库迁移 v25 之前
      // 没保证这点)。
      await _gcOrphanSharedLedgerRows();

      await fetchAndStoreSharedResources(ledgerExternalId);

      // 拉历史 tx — 让 Editor 看到 Owner 之前记的账。
      // 关键:不能走 pull(默认用 SharedPreferences cursor,B 设备如果之前
      // sync 过自己单人账本,cursor 已经在最新位置,A 之前的 sync_changes
      // change_id 已小于 cursor → 拉不回历史 tx / budget。
      // 强制 sinceOverride=0 走 replayAllChanges,server pull 路径会按
      // accessible_ledger_ids 过滤,Editor 自然只拿到自己能看的(含新加入
      // 的共享账本)。pullChanges apply 是 idempotent,重复 apply 已存在
      // 的不会出错。
      await replayAllChanges();
      _emit(PullCompleted(ledgerId: ledgerExternalId));
    } catch (e, st) {
      logger.warning('SyncEngine', 'onInviteAccepted 失败 ledger=$ledgerExternalId', st);
      logger.warning('SyncEngine', 'error: $e');
    }
  }

  /// §7 决策:把 Owner user-global 资源 mirror 到本地 Categories/Accounts/Tags
  /// 主表(以 syncId 唯一)。已有同 syncId 行则 update,无则 insert。
  /// Editor 在共享账本下记账走主表 picker 自然 work,sync push 时主表的 syncId
  /// 会带过去,server 端按 (user_id, sync_id) 维度 LWW,Owner 跟 Editor 各管各。
  /// §7 决策 v25:撤回 mirror。Editor 接受邀请只把图标二进制下到 sha256
  /// cache(给 SharedLedgerCategories 行渲染用),不再写主 Categories 表。
  Future<void> _downloadCustomIconsForSharedSnapshot(
      BeeCountCloudSharedResources snapshot) async {
    final iconSvc = CustomIconService();
    for (final c in snapshot.categories) {
      if (c.iconType != 'custom') continue;
      final fileId = c.iconCloudFileId;
      final sha = c.iconCloudSha256;
      if (fileId == null || fileId.isEmpty || sha == null || sha.isEmpty) {
        continue;
      }
      try {
        final cachedPath = await iconSvc.resolveCachedSharedIconPath(sha);
        if (await File(cachedPath).exists()) continue;
        final bytes = await provider.downloadAttachment(fileId: fileId);
        await iconSvc.writeCachedSharedIcon(
          expectedSha256: sha,
          bytes: bytes,
        );
      } catch (e, st) {
        logger.warning('SyncEngine',
            '自定义图标下载失败 syncId=${c.syncId}', st);
        logger.warning('SyncEngine', 'error: $e');
        // 下载失败不阻塞,后续渲染 fallback 通用图标
      }
    }
  }

  /// §7 决策 v25:WS handler 收到 category 上 iconType='custom' 时,把
  /// attachment 二进制下到 sha256 cache 给 SharedLedgerCategories 渲染。
  /// 不写主表。
  Future<void> _downloadOneCustomIconIfNeeded(Map payload) async {
    final iconType = (payload['iconType'] as String?) ?? 'material';
    final fileId = payload['iconCloudFileId'] as String?;
    final sha = payload['iconCloudSha256'] as String?;
    if (iconType != 'custom' ||
        fileId == null ||
        fileId.isEmpty ||
        sha == null ||
        sha.isEmpty) {
      return;
    }
    try {
      final iconSvc = CustomIconService();
      final cachedPath = await iconSvc.resolveCachedSharedIconPath(sha);
      if (await File(cachedPath).exists()) return;
      final bytes = await provider.downloadAttachment(fileId: fileId);
      await iconSvc.writeCachedSharedIcon(
        expectedSha256: sha,
        bytes: bytes,
      );
    } catch (e, st) {
      logger.warning('SyncEngine', 'WS 自定义图标下载失败', st);
      logger.warning('SyncEngine', 'error: $e');
    }
  }

  /// GC:清掉 SharedLedger* 表里 ledger_sync_id 在 ledgers 表找不到的孤儿行。
  /// 退出账本 / Owner 删账本 / 旧版迁移残留(73aa9e36 那种 user_测试残留)
  /// 都靠这条兜底。
  Future<void> _gcOrphanSharedLedgerRows() async {
    final aliveSyncIds = await (db.select(db.ledgers)
          ..where((l) => l.syncId.isNotNull()))
        .map((l) => l.syncId!)
        .get();
    final aliveSet = aliveSyncIds.toSet();
    Future<int> gc(Future<int> Function(Set<String>) doDelete) =>
        doDelete(aliveSet);
    final c = await gc((alive) async {
      // SQLite NOT IN 不支持空集合,空时直接 truncate 全表
      if (alive.isEmpty) {
        return (db.delete(db.sharedLedgerCategories)..where((_) =>
            d.Constant(true))).go();
      }
      return (db.delete(db.sharedLedgerCategories)
            ..where((t) => t.ledgerSyncId.isNotIn(alive.toList())))
          .go();
    });
    final a = await gc((alive) async {
      if (alive.isEmpty) {
        return (db.delete(db.sharedLedgerAccounts)..where((_) =>
            d.Constant(true))).go();
      }
      return (db.delete(db.sharedLedgerAccounts)
            ..where((t) => t.ledgerSyncId.isNotIn(alive.toList())))
          .go();
    });
    final t = await gc((alive) async {
      if (alive.isEmpty) {
        return (db.delete(db.sharedLedgerTags)..where((_) =>
            d.Constant(true))).go();
      }
      return (db.delete(db.sharedLedgerTags)
            ..where((t) => t.ledgerSyncId.isNotIn(alive.toList())))
          .go();
    });
    if (c + a + t > 0) {
      logger.info('SyncEngine',
          'GC SharedLedger* orphans: categories=$c accounts=$a tags=$t');
    }
  }

  /// 清本地某共享账本所有数据(被踢 / Owner 删账本 / 自己退出)。
  Future<void> _purgeLocalLedgerByExternalId(String ledgerExternalId) async {
    final localId = await _resolveLedgerIdBySyncId(ledgerExternalId);
    if (localId == null) return;
    // tx + tags + attachments 走级联;ledgers 行本身删
    await (db.delete(db.transactions)..where((t) => t.ledgerId.equals(localId))).go();
    await (db.delete(db.ledgers)..where((l) => l.id.equals(localId))).go();
    // SharedLedger* 镜像
    await (db.delete(db.ledgerMembers)
          ..where((t) => t.ledgerSyncId.equals(ledgerExternalId)))
        .go();
    await (db.delete(db.sharedLedgerCategories)
          ..where((t) => t.ledgerSyncId.equals(ledgerExternalId)))
        .go();
    await (db.delete(db.sharedLedgerAccounts)
          ..where((t) => t.ledgerSyncId.equals(ledgerExternalId)))
        .go();
    await (db.delete(db.sharedLedgerTags)
          ..where((t) => t.ledgerSyncId.equals(ledgerExternalId)))
        .go();
  }

  /// 防抖调度 pull（1 秒内多次触发只执行一次）
  void _schedulePull(String? ledgerId) {
    _pullDebounce?.cancel();
    _pullDebounce = Timer(const Duration(seconds: 1), () async {
      if (_autoPulling) return;
      _autoPulling = true;
      try {
        final targetLedgerId = ledgerId ?? '';
        if (targetLedgerId.isEmpty) {
          logger.debug('SyncEngine', '自动 pull: 无 ledgerId，跳过');
          return;
        }
        logger.info('SyncEngine', '自动 pull 开始: ledger=$targetLedgerId');
        final pulled = await pull(targetLedgerId);
        logger.info('SyncEngine', '自动 pull 完成: $pulled 条变更');

        // pull 完成后顺手对账一次 ledger 列表 — catch "web 端新建账本"
        // 的场景:server 推 ledger entity change 进 sync_changes,但有些
        // server 实现可能不带完整 payload(只有 syncId)→ _applyLedgerChange
        // 无法直接 insert。这里主动调一次 syncLedgersFromServer 拉完整
        // /sync/ledgers 列表兜底。
        //
        // syncLedgersFromServer 内部有 static 单飞锁,_pull 多次触发不会
        // 真重复跑;且只在远端 list 有差异时 insert 新账本,无差异是 nop。
        try {
          final inserted = await syncLedgersFromServer();
          if (inserted > 0) {
            logger.info('SyncEngine',
                '自动 pull 后 syncLedgersFromServer 新增 $inserted 个账本');
          }
        } catch (e, st) {
          logger.warning(
              'SyncEngine', '自动 pull 后 syncLedgersFromServer 失败', st);
          logger.warning('SyncEngine', 'error: $e');
        }
        // 附件二进制：metadata 已经在 _pull 里写到 Drift 了，文件本身需要额
        // 外调 downloadAttachments 才会下。之前只有 full `sync()` 调用它，
        // WS 触发的 pull 不调 → A 设备上传附件后 B 设备要重启才能看到图。
        // 这里 fire-and-forget 触发一下；失败只打日志，不阻塞 UI 刷新。
        final localLedgerIdInt =
            await _resolveLedgerIdBySyncId(targetLedgerId) ??
                int.tryParse(targetLedgerId);
        if (localLedgerIdInt != null && localLedgerIdInt > 0) {
          unawaited(() async {
            try {
              final downloaded = await downloadAttachments(
                  ledgerId: localLedgerIdInt);
              if (downloaded > 0) {
                logger.info('SyncEngine',
                    '自动 pull 后下载了 $downloaded 个附件');
                // 重新通知 UI 刷新(附件 UI 的 state 可能已经 stale)。
                _emit(PullCompleted(ledgerId: targetLedgerId));
              }
            } catch (e, st) {
              logger.warning('SyncEngine', 'auto pull 后下载附件失败: $e', st);
            }
          }());
        }
        // 不管实际拉了几条，都通知 UI 刷新。pulled==0 可能是自我回声被过滤，
        // 但等于此刻 WS 事件产生的时候 snapshot 已经由 materialize 更新过,
        // UI 刷一下总没错；派生 Provider 重算也很便宜。
        _statusCache.remove(int.tryParse(targetLedgerId));
        _emit(PullCompleted(ledgerId: targetLedgerId, applied: pulled));
      } catch (e, st) {
        logger.error('SyncEngine', '自动 pull 失败', e, st);
      } finally {
        _autoPulling = false;
      }
    });
  }
}
