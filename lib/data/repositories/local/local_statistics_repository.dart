import 'package:drift/drift.dart' as d;

import '../../db.dart';
import '../../../utils/shared_ledger_picker_filter.dart';
import '../statistics_repository.dart';

/// 本地统计Repository实现
/// 基于 Drift 数据库实现
class LocalStatisticsRepository implements StatisticsRepository {
  final BeeDatabase db;

  LocalStatisticsRepository(this.db);

  @override
  Future<List<({int? id, String name, String? icon, double total})>> totalsByCategory({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) async {
    final q = (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.type.equals(type) &
              t.happenedAt.isBiggerOrEqualValue(start) & t.happenedAt.isSmallerThanValue(end)))
        .join([
      d.leftOuterJoin(db.categories,
          db.categories.id.equalsExp(db.transactions.categoryId)),
    ]);
    final rows = await q.get();
    final shared = await _loadSharedCategoriesForLedger(ledgerId);
    final map = <int?, double>{};
    final names = <int?, String>{};
    final icons = <int?, String?>{};
    for (final r in rows) {
      final t = r.readTable(db.transactions);
      final c = r.readTableOrNull(db.categories);
      int? id = c?.id;
      String name = c?.name ?? '未分类';
      String? icon = c?.icon;
      // §7 共享账本:Editor 写的 tx categoryId 为空,但 categorySyncIdOverride
      // 指向 Owner 的分类 syncId — 查 SharedLedgerCategories 兜底。
      if (c == null && t.categorySyncIdOverride != null) {
        final s = shared[t.categorySyncIdOverride!];
        if (s != null) {
          id = syntheticIdForSyncId(s.syncId);
          name = s.name;
          icon = s.icon;
        }
      }
      names[id] = name;
      icons[id] = icon;
      map.update(id, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    final list = map.entries
        .map((e) => (id: e.key, name: names[e.key] ?? '未分类', icon: icons[e.key], total: e.value))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  /// 加载当前账本的 SharedLedger 分类索引(by syncId)。单人账本返回空 map,
  /// 共享账本返回 Owner user-global 的镜像。
  Future<Map<String, SharedLedgerCategory>> _loadSharedCategoriesForLedger(
      int ledgerId) async {
    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    final syncId = ledger?.syncId;
    if (syncId == null || syncId.isEmpty) return const {};
    final rows = await (db.select(db.sharedLedgerCategories)
          ..where((t) => t.ledgerSyncId.equals(syncId)))
        .get();
    return {for (final r in rows) r.syncId: r};
  }

  @override
  Future<Map<int, Category>> getSharedSyntheticCategoriesForLedger(
      int ledgerId) async {
    final shared = await _loadSharedCategoriesForLedger(ledgerId);
    if (shared.isEmpty) return const {};
    return {
      for (final s in shared.values)
        syntheticIdForSyncId(s.syncId): Category(
          id: syntheticIdForSyncId(s.syncId),
          name: s.name,
          kind: s.kind,
          icon: s.icon,
          sortOrder: s.sortOrder,
          // §7 二级分类 hierarchy:转 synthetic 父 id,让 analytics 的
          // L2→L1 rollup 找到 SharedLedger* 父分类(主表查不到这些 negative id)。
          parentId: (s.parentSyncId != null && s.parentSyncId!.isNotEmpty)
              ? syntheticIdForSyncId(s.parentSyncId!)
              : null,
          level: s.level,
          iconType: s.iconType,
          customIconPath: s.iconType == 'custom' && s.iconCloudSha256 != null
              ? 'custom_icons/shared_${s.iconCloudSha256}.png'
              : null,
          communityIconId: null,
          syncId: s.syncId,
        )
    };
  }

  @override
  Future<List<({int? id, String name, String? icon, int? parentId, int level, double total})>>
      totalsByCategoryWithHierarchy({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) async {
    final q = (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.type.equals(type) &
              t.happenedAt.isBiggerOrEqualValue(start) & t.happenedAt.isSmallerThanValue(end)))
        .join([
      d.leftOuterJoin(db.categories,
          db.categories.id.equalsExp(db.transactions.categoryId)),
    ]);

    final rows = await q.get();
    final shared = await _loadSharedCategoriesForLedger(ledgerId);
    final map = <int?, double>{};
    final categoryInfo = <int?, ({String name, String? icon, int? parentId, int level})>{};

    for (final r in rows) {
      final t = r.readTable(db.transactions);
      final c = r.readTableOrNull(db.categories);
      int? id = c?.id;

      if (c != null) {
        categoryInfo[id] = (
          name: c.name,
          icon: c.icon,
          parentId: c.parentId,
          level: c.level,
        );
      } else if (t.categorySyncIdOverride != null &&
          shared[t.categorySyncIdOverride!] != null) {
        // §7 共享账本:Editor 写的 tx 用 categorySyncIdOverride 指向 Owner
        // 的分类,主表 join 不到,查 SharedLedger* 兜底。用 synthetic 负 id
        // 做聚合 key,跟 picker filter 保持一致。
        // §7 二级分类 hierarchy:Phase 2 加了 parent_sync_id 后,L2 SharedLedger*
        // 行有父分类 syncId — 转 synthetic 负 id 写入 parentId,让 analytics
        // 的 L2→L1 rollup 正确累加,而不是把 L2 当 orphan 丢掉。
        final s = shared[t.categorySyncIdOverride!]!;
        id = syntheticIdForSyncId(s.syncId);
        final pSyncId = s.parentSyncId;
        final parentSyntheticId = (pSyncId != null && pSyncId.isNotEmpty)
            ? syntheticIdForSyncId(pSyncId)
            : null;
        categoryInfo[id] = (
          name: s.name,
          icon: s.icon,
          parentId: parentSyntheticId,
          level: s.level,
        );
      } else {
        categoryInfo[id] = (
          name: '未分类',
          icon: null,
          parentId: null,
          level: 1,
        );
      }

      map.update(id, (v) => v + t.amount, ifAbsent: () => t.amount);
    }

    final list = map.entries.map((e) {
      final info = categoryInfo[e.key]!;
      return (
        id: e.key,
        name: info.name,
        icon: info.icon,
        parentId: info.parentId,
        level: info.level,
        total: e.value,
      );
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return list;
  }

  @override
  Future<List<({DateTime day, double total})>> totalsByDay({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.type.equals(type) &
              t.happenedAt.isBiggerOrEqualValue(start) & t.happenedAt.isSmallerThanValue(end)))
        .get();
    final map = <DateTime, double>{};
    for (final t in rows) {
      final dt = t.happenedAt.toLocal();
      final day = DateTime(dt.year, dt.month, dt.day);
      map.update(day, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    // ensure full range continuity
    final result = <({DateTime day, double total})>[];
    for (DateTime d = DateTime(start.year, start.month, start.day);
        d.isBefore(end);
        d = d.add(const Duration(days: 1))) {
      result.add((day: d, total: map[d] ?? 0));
    }
    return result;
  }

  @override
  Future<List<({DateTime month, double total})>> totalsByMonth({
    required int ledgerId,
    required String type,
    required int year,
  }) async {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    final rows = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.type.equals(type) &
              t.happenedAt.isBiggerOrEqualValue(start) & t.happenedAt.isSmallerThanValue(end)))
        .get();
    final map = <int, double>{};
    for (final t in rows) {
      final dt = t.happenedAt.toLocal();
      map.update(dt.month, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    final result = <({DateTime month, double total})>[];
    for (int m = 1; m <= 12; m++) {
      result.add((month: DateTime(year, m, 1), total: map[m] ?? 0));
    }
    return result;
  }

  @override
  Future<List<({int year, double total})>> totalsByYearSeries({
    required int ledgerId,
    required String type,
  }) async {
    final rows = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId) & t.type.equals(type)))
        .get();
    if (rows.isEmpty) return const [];
    final map = <int, double>{};
    int minYear = 9999, maxYear = 0;
    for (final t in rows) {
      final y = t.happenedAt.toLocal().year;
      if (y < minYear) minYear = y;
      if (y > maxYear) maxYear = y;
      map.update(y, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    final out = <({int year, double total})>[];
    for (int y = minYear; y <= maxYear; y++) {
      out.add((year: y, total: map[y] ?? 0));
    }
    return out;
  }

  @override
  Future<(double income, double expense)> totalsInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) async {
    // 使用 SQL 聚合查询，比查出全部数据再累加快得多
    final result = await db.customSelect(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS expense
      FROM transactions
      WHERE ledger_id = ?1 AND happened_at >= ?2 AND happened_at < ?3
      ''',
      variables: [
        d.Variable<int>(ledgerId),
        d.Variable<DateTime>(start),
        d.Variable<DateTime>(end),
      ],
      readsFrom: {db.transactions},
    ).getSingle();

    final income = (result.data['income'] as num?)?.toDouble() ?? 0.0;
    final expense = (result.data['expense'] as num?)?.toDouble() ?? 0.0;
    return (income, expense);
  }

  @override
  Future<(double income, double expense)> monthlyTotals({
    required int ledgerId,
    required DateTime month,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    // 使用 SQL 聚合查询，比查出全部数据再累加快得多
    final result = await db.customSelect(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS expense
      FROM transactions
      WHERE ledger_id = ?1 AND happened_at >= ?2 AND happened_at < ?3
      ''',
      variables: [
        d.Variable<int>(ledgerId),
        d.Variable<DateTime>(start),
        d.Variable<DateTime>(end),
      ],
      readsFrom: {db.transactions},
    ).getSingle();

    final income = (result.data['income'] as num?)?.toDouble() ?? 0.0;
    final expense = (result.data['expense'] as num?)?.toDouble() ?? 0.0;
    return (income, expense);
  }

  @override
  Future<(double income, double expense)> yearlyTotals({
    required int ledgerId,
    required int year,
  }) async {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);

    // 使用 SQL 聚合查询，比查出全部数据再累加快得多
    final result = await db.customSelect(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS expense
      FROM transactions
      WHERE ledger_id = ?1 AND happened_at >= ?2 AND happened_at < ?3
      ''',
      variables: [
        d.Variable<int>(ledgerId),
        d.Variable<DateTime>(start),
        d.Variable<DateTime>(end),
      ],
      readsFrom: {db.transactions},
    ).getSingle();

    final income = (result.data['income'] as num?)?.toDouble() ?? 0.0;
    final expense = (result.data['expense'] as num?)?.toDouble() ?? 0.0;
    return (income, expense);
  }
}
