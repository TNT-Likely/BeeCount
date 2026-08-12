part of 'sync_engine.dart';

/// Pull 路径的恢复机制:**app 侧 cursor** + **失败 change 持久化**。
///
/// 改造前(详见 `.docs/full-pull-refactor/01-current-state.md` §3.1):
/// flutter_cloud_sync 包内 `pullChanges` 解码完立刻 `_saveCursor`,早于
/// app 端 apply。apply 抛错时整页 rollback,但 cursor 已跳到下一页 → 这页
/// 的 change 再也拉不回,用户只能卸载重装。
///
/// 改造:
/// 1. cloud-sync 包 `pullChanges` 加 `persistCursor: false` 参数
/// 2. app 调 `pullChanges(persistCursor: false)`,自己读 [AppCursorStore],
///    apply 成功后才 commit
/// 3. apply 失败 → [SyncErrorStore.record] 持久化错误供 UI 展示
///
/// 这两个 store 都是数据层薄 DAO,跟主类同 library 走 part,SyncEngine 持有
/// 它们的实例 (`appCursor` / `pullErrors` 字段),pull 路径内部用。

// =====================================================================
// AppCursorStore
// =====================================================================

/// app 侧维护的 pull cursor 管理。语义见上面 part 注释。
class AppCursorStore {
  AppCursorStore(this._provider);

  final BeeCountCloudProvider _provider;

  /// 读取当前 cursor。未登录返 0(等价"从头开始")。
  Future<int> read() async {
    final key = await _key();
    if (key == null) return 0;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? 0;
  }

  /// 把 cursor 推进到指定值。**只在整页 apply 成功后调**。
  Future<void> commit(int cursor) async {
    final key = await _key();
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, cursor);
  }

  /// Phase 2 上线时一次性迁移:把 cloud-sync 包内的 provider cursor 复制到
  /// app cursor key。已迁移过(app key 已存在)则 no-op。
  Future<void> migrateFromProviderCursor() async {
    final appKey = await _key();
    if (appKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(appKey) != null) return;
    final providerKey = await _providerKey();
    if (providerKey == null) return;
    final providerCursor = prefs.getInt(providerKey);
    if (providerCursor != null && providerCursor > 0) {
      await prefs.setInt(appKey, providerCursor);
      logger.info('AppCursorStore',
          '复制 provider cursor → app cursor: $providerCursor');
    }
  }

  Future<String?> _key() async {
    final auth = _provider.auth as BeeCountCloudAuthService;
    final userId = auth.currentUserId;
    final deviceId = auth.currentDeviceId;
    if (userId == null || deviceId == null) return null;
    final baseUrl = _provider.baseUrl ?? 'unknown';
    final raw = '$baseUrl|$userId|$deviceId';
    final digest = sha1.convert(utf8.encode(raw)).toString();
    return 'app_pull_cursor_$digest';
  }

  Future<String?> _providerKey() async {
    final auth = _provider.auth as BeeCountCloudAuthService;
    final userId = auth.currentUserId ?? 'unknown';
    final deviceId = auth.currentDeviceId ?? 'unknown';
    final baseUrl = _provider.baseUrl ?? 'unknown';
    final apiPrefix = _provider.apiPrefix ?? 'unknown';
    final raw = '$baseUrl|$apiPrefix|$userId|$deviceId';
    final digest = sha1.convert(utf8.encode(raw)).toString();
    return 'beecount_cloud_pull_cursor_$digest';
  }
}

// =====================================================================
// SyncErrorStore
// =====================================================================

/// `sync_pull_errors` 表的 DAO。
///
/// pull 路径上整页 apply 抛错(不可恢复异常,例如 TypeError /
/// FormatException / FK 解析失败)时,把"造成失败的 change + 错误信息"写入
/// 这张表。UI 据此显示 banner + 详情列表,**只读不可处置** —— BeeCount Cloud
/// 的核心是全自动同步,不引入"跳过"等人工干预入口。开发者从 server log 按
/// change_id 修脏数据 + 推新版本,app 自然下发新 change 后覆盖。
class SyncErrorStore {
  SyncErrorStore(this._db);

  final BeeDatabase _db;

  /// 记录一条 apply 失败。同 [change.changeId] 已存在 → attempt_count++。
  ///
  /// 旧实现 `select existing → if null insert / else update` 在并发场景下有
  /// race(两个 pull 同时跑,都 select 到 null,都 insert,第二个撞 UNIQUE)。
  /// 改成 **update-first**:先按 changeId 尝试 update,affected=0 才 insert,
  /// insert 失败再降级为 update。
  Future<void> record({
    required BeeCountCloudSyncChange change,
    required Object error,
    required StackTrace stackTrace,
  }) async {
    final now = DateTime.now().toUtc();
    final errClass = error.runtimeType.toString();
    final errMessage = _firstLine(error.toString());
    final stackStr = _truncate(stackTrace.toString(), 2048);

    // 步骤 1:update。已存在 → attempt_count + 1 由 customStatement 完成
    // (Drift `.write()` 不支持引用现有列做加法,所以走 raw SQL)。
    final affected = await _db.customUpdate(
      'UPDATE sync_pull_errors '
      'SET attempt_count = attempt_count + 1, '
      '    last_attempt_at = ?, '
      '    error_class = ?, '
      '    error_message = ?, '
      '    stack_trace = ? '
      'WHERE change_id = ?',
      variables: [
        d.Variable<DateTime>(now),
        d.Variable<String>(errClass),
        d.Variable<String>(errMessage),
        d.Variable<String>(stackStr),
        d.Variable<int>(change.changeId),
      ],
      updates: {_db.syncPullErrors},
    );
    if (affected > 0) return;

    // 步骤 2:不存在 → insert。并发场景下可能撞 UNIQUE,catch 后降级 update。
    try {
      await _db.into(_db.syncPullErrors).insert(SyncPullErrorsCompanion.insert(
            changeId: change.changeId,
            ledgerExternalId:
                d.Value(change.ledgerId.isEmpty ? null : change.ledgerId),
            entityType: change.entityType,
            entitySyncId: change.entitySyncId,
            action: change.action,
            rawChangeJson: _encodeChange(change),
            errorClass: d.Value(errClass),
            errorMessage: d.Value(errMessage),
            stackTrace: d.Value(stackStr),
            firstSeenAt: now,
            lastAttemptAt: now,
          ));
      logger.warning('SyncErrorStore',
          '新增 pull error: change_id=${change.changeId} type=${change.entityType} err=$errClass');
    } catch (e) {
      // UNIQUE constraint(并发 record 同 change_id)— 已被另一路径插入,
      // 用同样的 customUpdate 增量更新计数。
      await _db.customUpdate(
        'UPDATE sync_pull_errors '
        'SET attempt_count = attempt_count + 1, last_attempt_at = ? '
        'WHERE change_id = ?',
        variables: [
          d.Variable<DateTime>(now),
          d.Variable<int>(change.changeId),
        ],
        updates: {_db.syncPullErrors},
      );
    }
  }

  /// 后台 apply 成功(server 端修了脏数据 + 推新 change → apply 通过)→
  /// 自动 resolve 历史记录,UI 不再显示这条。
  Future<void> markResolved(int changeId) async {
    await (_db.update(_db.syncPullErrors)
          ..where((t) => t.changeId.equals(changeId))
          ..where((t) => t.resolvedAt.isNull()))
        .write(SyncPullErrorsCompanion(
      resolvedAt: d.Value(DateTime.now().toUtc()),
    ));
  }

  /// 监听未解决错误(UI StreamProvider 用)。
  Stream<List<SyncPullError>> watchUnresolved() {
    return (_db.select(_db.syncPullErrors)
          ..where((t) => t.resolvedAt.isNull())
          ..orderBy([(t) => d.OrderingTerm.asc(t.changeId)]))
        .watch();
  }

  String _firstLine(String s) {
    final idx = s.indexOf('\n');
    return idx < 0 ? s : s.substring(0, idx);
  }

  String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}\n…(truncated)';
  }

  String _encodeChange(BeeCountCloudSyncChange change) {
    return jsonEncode({
      'change_id': change.changeId,
      'ledger_id': change.ledgerId,
      'entity_type': change.entityType,
      'entity_sync_id': change.entitySyncId,
      'action': change.action,
      'updated_by_device_id': change.updatedByDeviceId,
      'updated_at': change.updatedAt,
      'payload': change.payload,
    });
  }
}

// =====================================================================
// LookupCache:syncId → 本地 int id 一次性加载缓存
// =====================================================================

/// pull 路径上的 `syncId → 本地 int id` 查找缓存。
///
/// 改造前每条 sync_change apply 会做 5-10 次 SELECT 查 ledger / category /
/// account / tag 的 syncId 映射,10k 条 ≈ 80-100k SELECT,iOS SQLite 主线程
/// 阻塞数十分钟(用户实测 1 万条 20 分钟)。
///
/// 改造后:pull 入口 [prime] 一次性加载 4 张表全表 syncId→id,apply 内查
/// cache,miss 才走 DB(insert 新实体后调 [putXxx] 写回)。10k 条 SELECT
/// 从 ~10万 降到 ~5(prime)+ 极少量 miss。
///
/// **生命周期**:SyncEngine 每次 pull 入口 new 一个实例赋值给 `activePullCache`,
/// pull 结束清空。不跨 pull 复用,避免长期持有大 map。
class LookupCache {
  final Map<String, int> _ledger = {};
  final Map<String, int> _category = {};
  final Map<String, int> _account = {};
  final Map<String, int> _tag = {};

  /// transactions 表 syncId → 已存在记录的轻量信息(id + createdByUserId)。
  /// `_applyTransactionChange` 每条都要查 existing tx 决定 INSERT/UPDATE,
  /// 这是 10k 条 = 10k 次 SELECT,后期变慢的主因。改走 cache 一次性 prime。
  final Map<String, _TxCacheEntry> _tx = {};

  Future<void> prime(BeeDatabase db) async {
    final ledgers = await db.select(db.ledgers).get();
    for (final l in ledgers) {
      final s = l.syncId;
      if (s != null && s.isNotEmpty) _ledger[s] = l.id;
    }
    final categories = await db.select(db.categories).get();
    for (final c in categories) {
      final s = c.syncId;
      if (s != null && s.isNotEmpty) _category[s] = c.id;
    }
    final accounts = await db.select(db.accounts).get();
    for (final a in accounts) {
      final s = a.syncId;
      if (s != null && s.isNotEmpty) _account[s] = a.id;
    }
    final tags = await db.select(db.tags).get();
    for (final t in tags) {
      final s = t.syncId;
      if (s != null && s.isNotEmpty) _tag[s] = t.id;
    }
    // tx 全表加载:只保留 id + syncId + createdByUserId(每行 ~100B,10k 条 ~1MB)
    final txs = await db.select(db.transactions).get();
    for (final t in txs) {
      final s = t.syncId;
      if (s != null && s.isNotEmpty) {
        _tx[s] = _TxCacheEntry(id: t.id, createdByUserId: t.createdByUserId);
      }
    }
    logger.info('LookupCache',
        'prime: ledgers=${_ledger.length} categories=${_category.length} '
        'accounts=${_account.length} tags=${_tag.length} transactions=${_tx.length}');
  }

  int? ledgerId(String? syncId) =>
      (syncId == null || syncId.isEmpty) ? null : _ledger[syncId];
  int? categoryId(String? syncId) =>
      (syncId == null || syncId.isEmpty) ? null : _category[syncId];
  int? accountId(String? syncId) =>
      (syncId == null || syncId.isEmpty) ? null : _account[syncId];
  int? tagId(String? syncId) =>
      (syncId == null || syncId.isEmpty) ? null : _tag[syncId];
  /// `_TxCacheEntry` 是 part 内私有,仅供 apply 路径用,所以 ignore lint。
  // ignore: library_private_types_in_public_api
  _TxCacheEntry? transaction(String? syncId) =>
      (syncId == null || syncId.isEmpty) ? null : _tx[syncId];

  void putLedger(String syncId, int id) => _ledger[syncId] = id;
  void putCategory(String syncId, int id) => _category[syncId] = id;
  void putAccount(String syncId, int id) => _account[syncId] = id;
  void putTag(String syncId, int id) => _tag[syncId] = id;
  void putTransaction(String syncId, int id, String? createdByUserId) =>
      _tx[syncId] = _TxCacheEntry(id: id, createdByUserId: createdByUserId);
  void removeTransaction(String syncId) => _tx.remove(syncId);
}

/// transactions 表的轻量缓存条目。只存 apply 路径会用到的 2 个字段。
class _TxCacheEntry {
  const _TxCacheEntry({required this.id, required this.createdByUserId});
  final int id;
  final String? createdByUserId;
}

// =====================================================================
// 自定义分类图标下载任务(in-memory queue)
// =====================================================================

/// 自定义分类图标的下载任务。
///
/// 旧实现把 `await provider.downloadAttachment(...)` 放在 `_applyCategoryChange`
/// 的事务内,网络抖动会让整页事务卡死。改造后只在事务内 enqueue 到
/// [SyncEngine.pendingCustomIconJobs],事务 commit 之后 [drainCustomIconQueue]
/// 并发处理。
class CustomIconDownloadJob {
  const CustomIconDownloadJob({
    required this.categoryId,
    required this.cloudFileId,
    this.expectedPath,
  });

  final int categoryId;
  final String cloudFileId;
  final String? expectedPath;
}
