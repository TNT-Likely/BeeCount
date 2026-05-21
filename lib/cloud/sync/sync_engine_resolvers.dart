part of 'sync_engine.dart';

/// pull 路径上的批量 resolver 缓存。
///
/// 老路径每条 tx apply 时 await DB 查 ~6 个不同 syncId 映射(ledger /
/// category / account / sharedLedgerCategory / sharedLedgerAccount /
/// transaction-by-syncId),一万条 tx ≈ 6 万次 SQL 串行 await,在 Drift
/// transaction 内造成持锁 → UI 卡死、SQLite WAL 写阻塞读。
///
/// 现在:
///   1. `_pull` 拿到一页 changes 后,先扫一遍 payload,**收集所有引用过的
///      syncId 集合**;
///   2. 一次性 IN 查询拉到本地 int id 映射,塞进本类的 Map;
///   3. apply 单条时 resolver 先查 Map,miss 才 fallthrough 到原 DB 查询
///      (兜底,理论上不应该 miss)。
///
/// 总 SQL 量从 O(changes × 6) 降到 O(distinct_entity_types ≈ 6),持锁时
/// 间显著缩短。
class PageResolverCache {
  /// ledger.syncId → ledger.id
  final Map<String, int> ledgerBySync = {};

  /// category.syncId → category.id(主表)
  final Map<String, int> categoryBySync = {};

  /// account.syncId → account.id(主表)
  final Map<String, int> accountBySync = {};

  /// tag.syncId → tag.id(主表)
  final Map<String, int> tagBySync = {};

  /// shared_ledger_categories.syncId 集合(Editor 视角看 Owner tx 用)
  final Set<String> sharedCategorySyncIds = {};

  /// shared_ledger_accounts.syncId 集合
  final Set<String> sharedAccountSyncIds = {};

  /// shared_ledger_tags.syncId 集合
  final Set<String> sharedTagSyncIds = {};

  /// 缓存命中次数(debug 用,日志统计)
  int hits = 0;
  int misses = 0;
}

/// 跨设备 ID 解析:syncId(string,跨设备稳定) ↔ 本地 int id(autoIncrement,设
/// 备私有)。apply remote change 时大量用到——server 推下来的 entity 引用都
/// 是 syncId,本地存储用 int id,中间要靠这些函数转换。
///
/// 所有 by-syncId 查询都会先查 `_pageCache`(若 `_pull` 已 prewarm),命中
/// 直接返本地 id,不走 DB。miss 时 fallthrough 原 DB 查询保持兼容。
extension _SyncEngineResolvers on SyncEngine {
  /// 预热 cache:扫一遍 changes payload 收集所有需要解析的 syncId,一次
  /// IN 查询批量拉本地 id 映射。整个 `_pull` 一页用同一个 cache。
  Future<PageResolverCache> _prewarmPageCache(
    List<BeeCountCloudSyncChange> changes,
  ) async {
    final cache = PageResolverCache();
    final ledgerSyncIds = <String>{};
    final categorySyncIds = <String>{};
    final accountSyncIds = <String>{};
    final tagSyncIds = <String>{};

    for (final c in changes) {
      // ledger_id 字段(change 自带 — server scope=ledger 的 external_id)
      if (c.ledgerId.isNotEmpty) ledgerSyncIds.add(c.ledgerId);
      final p = c.payload;
      if (p == null) continue;

      // entity_sync_id 自己(分类/账户/标签时):apply 时 by-syncId 查 existing
      if (c.entityType == 'category') {
        categorySyncIds.add(c.entitySyncId);
      } else if (c.entityType == 'account') {
        accountSyncIds.add(c.entitySyncId);
      } else if (c.entityType == 'tag') {
        tagSyncIds.add(c.entitySyncId);
      }
      // tx existing 检查会走 db.transactions by syncId,但 tx 之间很少有同一
      // syncId 重复在同一页(server 已 dedup,只剩 LWW 后的 latest),
      // 预查命中率低、收益小,这里不缓存 tx by syncId。

      // tx payload 引用的外键 syncId
      final cid = p['categoryId'] as String?;
      if (cid != null && cid.isNotEmpty) categorySyncIds.add(cid);
      final aid = p['accountId'] as String?;
      if (aid != null && aid.isNotEmpty) accountSyncIds.add(aid);
      final faid = p['fromAccountId'] as String?;
      if (faid != null && faid.isNotEmpty) accountSyncIds.add(faid);
      final taid = p['toAccountId'] as String?;
      if (taid != null && taid.isNotEmpty) accountSyncIds.add(taid);
      // payload tagIds
      final rawTagIds = p['tagIds'];
      if (rawTagIds is List) {
        for (final t in rawTagIds) {
          if (t is String && t.isNotEmpty) tagSyncIds.add(t);
        }
      }
      // 父分类 syncId(category 自己引用 parent 分类)
      final parentSync = p['parentSyncId'] as String?;
      if (parentSync != null && parentSync.isNotEmpty) {
        categorySyncIds.add(parentSync);
      }
    }

    // 一次 IN 查询拿到所有映射。empty 集合不查(IN [] 在 Drift 上行为不定,
    // 直接跳过更稳)。
    if (ledgerSyncIds.isNotEmpty) {
      final rows = await (db.select(db.ledgers)
            ..where((l) => l.syncId.isIn(ledgerSyncIds.toList())))
          .get();
      for (final r in rows) {
        final sid = r.syncId;
        if (sid != null) cache.ledgerBySync[sid] = r.id;
      }
    }
    if (categorySyncIds.isNotEmpty) {
      final idList = categorySyncIds.toList();
      final rows = await (db.select(db.categories)
            ..where((c) => c.syncId.isIn(idList)))
          .get();
      for (final r in rows) {
        final sid = r.syncId;
        if (sid != null) cache.categoryBySync[sid] = r.id;
      }
      final sharedRows = await (db.select(db.sharedLedgerCategories)
            ..where((c) => c.syncId.isIn(idList)))
          .get();
      for (final r in sharedRows) {
        cache.sharedCategorySyncIds.add(r.syncId);
      }
    }
    if (accountSyncIds.isNotEmpty) {
      final idList = accountSyncIds.toList();
      final rows = await (db.select(db.accounts)
            ..where((a) => a.syncId.isIn(idList)))
          .get();
      for (final r in rows) {
        final sid = r.syncId;
        if (sid != null) cache.accountBySync[sid] = r.id;
      }
      final sharedRows = await (db.select(db.sharedLedgerAccounts)
            ..where((a) => a.syncId.isIn(idList)))
          .get();
      for (final r in sharedRows) {
        cache.sharedAccountSyncIds.add(r.syncId);
      }
    }
    if (tagSyncIds.isNotEmpty) {
      final idList = tagSyncIds.toList();
      final rows = await (db.select(db.tags)
            ..where((t) => t.syncId.isIn(idList)))
          .get();
      for (final r in rows) {
        final sid = r.syncId;
        if (sid != null) cache.tagBySync[sid] = r.id;
      }
      final sharedRows = await (db.select(db.sharedLedgerTags)
            ..where((t) => t.syncId.isIn(idList)))
          .get();
      for (final r in sharedRows) {
        cache.sharedTagSyncIds.add(r.syncId);
      }
    }

    logger.debug(
      'SyncEngine',
      'pull.prewarm: ledger=${cache.ledgerBySync.length}/${ledgerSyncIds.length} '
      'category=${cache.categoryBySync.length}/${categorySyncIds.length}(+shared ${cache.sharedCategorySyncIds.length}) '
      'account=${cache.accountBySync.length}/${accountSyncIds.length}(+shared ${cache.sharedAccountSyncIds.length}) '
      'tag=${cache.tagBySync.length}/${tagSyncIds.length}(+shared ${cache.sharedTagSyncIds.length})',
    );
    return cache;
  }

  /// 按 syncId 查 ledger 的本地 int id。用于 apply remote change 时把
  /// server 的 external_id(string)映射成本地 autoIncrement id。
  Future<int?> _resolveLedgerIdBySyncId(String? syncId) async {
    if (syncId == null || syncId.isEmpty) return null;
    final cache = _pageCache;
    if (cache != null) {
      final hit = cache.ledgerBySync[syncId];
      if (hit != null) {
        cache.hits++;
        return hit;
      }
      cache.misses++;
    }
    final led = await (db.select(db.ledgers)
          ..where((l) => l.syncId.equals(syncId))
          ..limit(1))
        .get();
    return led.isEmpty ? null : led.first.id;
  }

  /// 按 syncId 查 category 的本地 int id。优先级比 name+kind 高:设备间
  /// category.syncId 是稳定的,name 可能被改过 / 有重名。
  ///
  /// §7 决策 v25:返 null 时调用方应检查 tx 是否有 categorySyncIdOverride
  /// 字段 — 共享账本场景 Editor 选 Owner cat,本地主表没有该 row,需要走
  /// SharedLedgerCategories 表显示。tx UI 应该按 override 优先。
  Future<int?> _resolveCategoryIdBySyncId(String? syncId) async {
    if (syncId == null || syncId.isEmpty) return null;
    final cache = _pageCache;
    if (cache != null) {
      final hit = cache.categoryBySync[syncId];
      if (hit != null) {
        cache.hits++;
        return hit;
      }
      cache.misses++;
    }
    final cat = await (db.select(db.categories)
          ..where((c) => c.syncId.equals(syncId))
          ..limit(1))
        .get();
    return cat.isEmpty ? null : cat.first.id;
  }

  /// 按 syncId 查 account 的本地 int id。同理,跨设备稳定。
  /// §7 决策 v25:返 null 时调用方应检查 tx 是否有 accountSyncIdOverride
  /// 字段。
  Future<int?> _resolveAccountIdBySyncId(String? syncId) async {
    if (syncId == null || syncId.isEmpty) return null;
    final cache = _pageCache;
    if (cache != null) {
      final hit = cache.accountBySync[syncId];
      if (hit != null) {
        cache.hits++;
        return hit;
      }
      cache.misses++;
    }
    final acc = await (db.select(db.accounts)
          ..where((a) => a.syncId.equals(syncId))
          ..limit(1))
        .get();
    return acc.isEmpty ? null : acc.first.id;
  }

  /// 检查 syncId 是否在 sharedLedgerCategories 表里。批量 prewarm 时塞进
  /// `_pageCache.sharedCategorySyncIds`,apply 时 O(1) 查 Set,不走 DB。
  Future<bool> _hasSharedCategorySyncId(String syncId) async {
    if (syncId.isEmpty) return false;
    final cache = _pageCache;
    if (cache != null) {
      // 注意:这里不能用 "key 不存在 = false" 的语义,因为只有"预热时收集到
      // 但 DB 没命中"才会留在 sharedCategorySyncIds 外。这里直接查 cache 即可。
      return cache.sharedCategorySyncIds.contains(syncId);
    }
    final row = await (db.select(db.sharedLedgerCategories)
          ..where((c) => c.syncId.equals(syncId))
          ..limit(1))
        .get();
    return row.isNotEmpty;
  }

  /// 检查 syncId 是否在 sharedLedgerAccounts 表里。
  Future<bool> _hasSharedAccountSyncId(String syncId) async {
    if (syncId.isEmpty) return false;
    final cache = _pageCache;
    if (cache != null) {
      return cache.sharedAccountSyncIds.contains(syncId);
    }
    final row = await (db.select(db.sharedLedgerAccounts)
          ..where((a) => a.syncId.equals(syncId))
          ..limit(1))
        .get();
    return row.isNotEmpty;
  }

  /// 根据分类名和类型查找 categoryId(name fallback,by-syncId 未命中时的兜底)。
  ///
  /// 用 limit(1).get() 而非 getSingleOrNull —— 历史 bug / 跨设备 seed race
  /// 可能让本地 categories 表里出现同 name 多行,getSingleOrNull 撞多行会
  /// 抛 "Too many elements",在 pull transaction 里抛 → 整批回滚。这里只挑
  /// 第一行,行为退化为"任意命中"。
  Future<int?> _resolveCategoryId({
    String? categoryName,
    String? categoryKind,
  }) async {
    if (categoryName == null || categoryName.isEmpty) return null;
    final query = db.select(db.categories)
      ..where((c) => c.name.equals(categoryName));
    if (categoryKind != null) {
      query.where((c) => c.kind.equals(categoryKind));
    }
    query.limit(1);
    final rows = await query.get();
    return rows.isEmpty ? null : rows.first.id;
  }

  /// 根据账户名查找 accountId
  ///
  /// 账户是 user-scoped(跟 category/tag 一样)—— 同一用户的所有账本共享一份
  /// 账户表。Accounts 表仍带着 ledgerId 字段只是历史遗留(schema 注释里写着
  /// "保留用于v2迁移,后续会移除"),不应该参与解析。
  ///
  /// 之前按 (name + ledgerId) 查会有两个问题:
  ///   1. 同一个账户在别的账本上(因为旧数据沿 ledger 分裂),本账本查不到 → null
  ///      → web 改的 tx 账户在 mobile 上显示空。
  ///   2. 多次同步后 accounts 表里可能出现重名(因为 ledgerId 不同被当成不同
  ///      实体),按 name 全局查会 throw;这里用 take(1) 保守一点。
  Future<int?> _resolveAccountId({
    String? accountName,
    required int ledgerId, // 参数保留兼容上游调用
  }) async {
    if (accountName == null || accountName.isEmpty) return null;
    final rows = await (db.select(db.accounts)
          ..where((a) => a.name.equals(accountName))
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first.id;
  }

  Future<String> _getDeviceId() async {
    final user = await provider.auth.currentUser;
    return user?.metadata?['deviceId'] as String? ?? 'unknown';
  }
}
