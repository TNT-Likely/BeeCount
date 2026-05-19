part of 'sync_engine.dart';

/// 跨设备 ID 解析:syncId(string,跨设备稳定) ↔ 本地 int id(autoIncrement,设
/// 备私有)。apply remote change 时大量用到——server 推下来的 entity 引用都
/// 是 syncId,本地存储用 int id,中间要靠这些函数转换。
extension _SyncEngineResolvers on SyncEngine {
  /// 按 syncId 查 ledger 的本地 int id。用于 apply remote change 时把
  /// server 的 external_id（string）映射成本地 autoIncrement id。
  Future<int?> _resolveLedgerIdBySyncId(String? syncId) async {
    if (syncId == null || syncId.isEmpty) return null;
    final led = await (db.select(db.ledgers)
          ..where((l) => l.syncId.equals(syncId)))
        .getSingleOrNull();
    return led?.id;
  }

  /// 按 syncId 查 category 的本地 int id。优先级比 name+kind 高：设备间
  /// category.syncId 是稳定的，name 可能被改过 / 有重名。
  ///
  /// §7 决策 v25:返 null 时调用方应检查 tx 是否有 categorySyncIdOverride
  /// 字段 — 共享账本场景 Editor 选 Owner cat,本地主表没有该 row,需要走
  /// SharedLedgerCategories 表显示。tx UI 应该按 override 优先。
  Future<int?> _resolveCategoryIdBySyncId(String? syncId) async {
    if (syncId == null || syncId.isEmpty) return null;
    final cat = await (db.select(db.categories)
          ..where((c) => c.syncId.equals(syncId)))
        .getSingleOrNull();
    return cat?.id;
  }

  /// 按 syncId 查 account 的本地 int id。同理，跨设备稳定。
  /// §7 决策 v25:返 null 时调用方应检查 tx 是否有 accountSyncIdOverride
  /// 字段。
  Future<int?> _resolveAccountIdBySyncId(String? syncId) async {
    if (syncId == null || syncId.isEmpty) return null;
    final acc = await (db.select(db.accounts)
          ..where((a) => a.syncId.equals(syncId)))
        .getSingleOrNull();
    return acc?.id;
  }

  /// 根据分类名和类型查找 categoryId
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
    final cat = await query.getSingleOrNull();
    return cat?.id;
  }

  /// 根据账户名查找 accountId
  ///
  /// 账户是 user-scoped（跟 category/tag 一样）—— 同一用户的所有账本共享一份
  /// 账户表。Accounts 表仍带着 ledgerId 字段只是历史遗留（schema 注释里写着
  /// "保留用于v2迁移，后续会移除"），不应该参与解析。
  ///
  /// 之前按 (name + ledgerId) 查会有两个问题：
  ///   1. 同一个账户在别的账本上（因为旧数据沿 ledger 分裂），本账本查不到 → null
  ///      → web 改的 tx 账户在 mobile 上显示空。
  ///   2. 多次同步后 accounts 表里可能出现重名（因为 ledgerId 不同被当成不同
  ///      实体），按 name 全局查会 throw；这里用 take(1) 保守一点。
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
