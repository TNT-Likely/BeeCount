import 'dart:async';

import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';

import '../../db.dart';
import '../exceptions.dart';
import '../tag_repository.dart';

/// 本地标签Repository实现
/// 基于 Drift 数据库实现
class LocalTagRepository implements TagRepository {
  static const _uuid = Uuid();
  final BeeDatabase db;

  LocalTagRepository(this.db);

  // ============================================
  // 基础 CRUD 操作
  // ============================================

  @override
  Future<int> createTag({
    required String name,
    String? color,
    int sortOrder = 0,
    String? syncId,
  }) async {
    // 撞同名抛 DuplicateNameException(name 全局唯一)。静默路径(import /
    // 自动记账等)请改用 [upsertTag]。
    final existing =
        await (db.select(db.tags)..where((t) => t.name.equals(name))).get();
    if (existing.isNotEmpty) {
      throw DuplicateNameException(
        entityType: 'tag',
        name: name,
        existingId: existing.first.id,
      );
    }
    return await db.into(db.tags).insert(
      TagsCompanion.insert(
        name: name,
        color: d.Value(color),
        sortOrder: d.Value(sortOrder),
        syncId: d.Value(syncId ?? _uuid.v4()),
      ),
    );
  }

  @override
  Future<int> upsertTag({
    required String name,
    String? color,
  }) async {
    final existing =
        await (db.select(db.tags)..where((t) => t.name.equals(name))).get();
    if (existing.isNotEmpty) return existing.first.id;
    return await db.into(db.tags).insert(
      TagsCompanion.insert(
        name: name,
        color: d.Value(color),
        sortOrder: const d.Value(0),
        syncId: d.Value(_uuid.v4()),
      ),
    );
  }

  @override
  Future<void> updateTag(
    int id, {
    String? name,
    String? color,
    int? sortOrder,
  }) async {
    await (db.update(db.tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(
        name: name != null ? d.Value(name) : const d.Value.absent(),
        color: color != null ? d.Value(color) : const d.Value.absent(),
        sortOrder: sortOrder != null ? d.Value(sortOrder) : const d.Value.absent(),
      ),
    );
  }

  @override
  Future<void> deleteTag(int id) async {
    await db.transaction(() async {
      // 先删除关联关系
      await (db.delete(db.transactionTags)
        ..where((t) => t.tagId.equals(id))).go();
      // 再删除标签
      await (db.delete(db.tags)..where((t) => t.id.equals(id))).go();
    });
  }

  @override
  Future<Tag?> getTagById(int id) async {
    return await (db.select(db.tags)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<Tag?> getTagByName(String name) async {
    return await (db.select(db.tags)
      ..where((t) => t.name.equals(name))).getSingleOrNull();
  }

  @override
  Future<List<Tag>> getAllTags() async {
    return await (db.select(db.tags)
      ..orderBy([(t) => d.OrderingTerm(expression: t.sortOrder)])).get();
  }

  @override
  Future<void> batchInsertTags(List<TagsCompanion> tags) async {
    await db.batch((batch) {
      batch.insertAll(db.tags, tags);
    });
  }

  // ============================================
  // 交易-标签关联操作
  // ============================================

  @override
  Future<void> addTagToTransaction({
    required int transactionId,
    required int tagId,
  }) async {
    // 检查是否已存在
    final existing = await (db.select(db.transactionTags)
      ..where((t) => t.transactionId.equals(transactionId) & t.tagId.equals(tagId)))
        .getSingleOrNull();

    if (existing == null) {
      await db.into(db.transactionTags).insert(
        TransactionTagsCompanion.insert(
          transactionId: transactionId,
          tagId: tagId,
        ),
      );
    }
  }

  @override
  Future<void> addTagsToTransaction({
    required int transactionId,
    required List<int> tagIds,
  }) async {
    await db.transaction(() async {
      for (final tagId in tagIds) {
        await addTagToTransaction(transactionId: transactionId, tagId: tagId);
      }
    });
  }

  @override
  Future<void> removeTagFromTransaction({
    required int transactionId,
    required int tagId,
  }) async {
    await (db.delete(db.transactionTags)
      ..where((t) => t.transactionId.equals(transactionId) & t.tagId.equals(tagId)))
        .go();
  }

  @override
  Future<void> removeAllTagsFromTransaction(int transactionId) async {
    await (db.delete(db.transactionTags)
      ..where((t) => t.transactionId.equals(transactionId))).go();
  }

  @override
  Future<void> updateTransactionTags({
    required int transactionId,
    required List<int> tagIds,
  }) async {
    await db.transaction(() async {
      // 先删除所有关联
      await removeAllTagsFromTransaction(transactionId);
      // 再添加新的关联
      if (tagIds.isNotEmpty) {
        await addTagsToTransaction(transactionId: transactionId, tagIds: tagIds);
      }
    });
  }

  @override
  Future<List<Tag>> getTagsForTransaction(int transactionId) async {
    final query = db.select(db.tags).join([
      d.innerJoin(
        db.transactionTags,
        db.transactionTags.tagId.equalsExp(db.tags.id),
      ),
    ])..where(db.transactionTags.transactionId.equals(transactionId));

    final rows = await query.get();
    final out = rows.map((row) => row.readTable(db.tags)).toList();

    // §7 共享账本:加 TransactionTagOverrides
    final tx = await (db.select(db.transactions)
          ..where((t) => t.id.equals(transactionId)))
        .getSingleOrNull();
    if (tx?.syncId != null) {
      final overrides = await (db.select(db.transactionTagOverrides)
            ..where((t) => t.transactionSyncId.equals(tx!.syncId!)))
          .get();
      if (overrides.isNotEmpty) {
        final tagSyncIds = overrides.map((o) => o.tagSyncId).toList();
        final shared = await (db.select(db.sharedLedgerTags)
              ..where((t) => t.syncId.isIn(tagSyncIds)))
            .get();
        for (final s in shared) {
          out.add(Tag(
            id: _syntheticIdForSyncId(s.syncId),
            name: s.name,
            color: s.color,
            sortOrder: 0,
            createdAt: DateTime.now(),
            syncId: s.syncId,
          ));
        }
      }
    }
    return out;
  }

  @override
  Future<Map<int, List<Tag>>> getTagsForTransactions(List<int> transactionIds) async {
    if (transactionIds.isEmpty) return {};

    final query = db.select(db.transactionTags).join([
      d.innerJoin(
        db.tags,
        db.tags.id.equalsExp(db.transactionTags.tagId),
      ),
    ])..where(db.transactionTags.transactionId.isIn(transactionIds));

    final rows = await query.get();

    final result = <int, List<Tag>>{};
    for (final row in rows) {
      final transactionTag = row.readTable(db.transactionTags);
      final tag = row.readTable(db.tags);
      result.putIfAbsent(transactionTag.transactionId, () => []).add(tag);
    }

    // §7 共享账本:union TransactionTagOverrides — Editor 选 Owner tag 的
    // 关系存 override 表(by tx.syncId,not tx.id)。反查映射成 synthetic Tag
    // (id<0)同 picker 一致;tx 列表 chip / 编辑回显都能 join。
    final txs = await (db.select(db.transactions)
          ..where((t) => t.id.isIn(transactionIds)))
        .get();
    final syncIdToTxId = <String, int>{};
    for (final t in txs) {
      if (t.syncId != null) syncIdToTxId[t.syncId!] = t.id;
    }
    if (syncIdToTxId.isNotEmpty) {
      final overrides = await (db.select(db.transactionTagOverrides)
            ..where(
                (t) => t.transactionSyncId.isIn(syncIdToTxId.keys.toList())))
          .get();
      if (overrides.isNotEmpty) {
        final tagSyncIds = overrides.map((o) => o.tagSyncId).toSet().toList();
        final sharedTags = await (db.select(db.sharedLedgerTags)
              ..where((t) => t.syncId.isIn(tagSyncIds)))
            .get();
        final bySyncId = <String, SharedLedgerTag>{
          for (final s in sharedTags) s.syncId: s,
        };
        for (final ov in overrides) {
          final txId = syncIdToTxId[ov.transactionSyncId];
          if (txId == null) continue;
          final shared = bySyncId[ov.tagSyncId];
          if (shared == null) continue;
          result.putIfAbsent(txId, () => []).add(Tag(
                id: _syntheticIdForSyncId(shared.syncId),
                name: shared.name,
                color: shared.color,
                sortOrder: 0,
                createdAt: DateTime.now(),
                syncId: shared.syncId,
              ));
        }
      }
    }

    return result;
  }

  /// 派生 synthetic int id(跟 shared_ledger_picker_filter.syntheticIdForSyncId 同算法)
  int _syntheticIdForSyncId(String syncId) {
    final h = syncId.hashCode;
    if (h == 0) return -1;
    return h > 0 ? -h : h;
  }

  @override
  Future<List<int>> getTransactionIdsByTag(int tagId) async {
    final rows = await (db.select(db.transactionTags)
      ..where((t) => t.tagId.equals(tagId))).get();
    return rows.map((r) => r.transactionId).toList();
  }

  // ============================================
  // 统计查询
  // ============================================

  @override
  Future<int> getTransactionCountByTag(int tagId) async {
    final result = await db.customSelect(
      'SELECT COUNT(*) AS count FROM transaction_tags WHERE tag_id = ?',
      variables: [d.Variable.withInt(tagId)],
      readsFrom: {db.transactionTags},
    ).getSingle();

    final count = result.data['count'];
    if (count is int) return count;
    if (count is BigInt) return count.toInt();
    if (count is num) return count.toInt();
    return 0;
  }

  @override
  Future<Map<int, int>> getAllTagTransactionCounts() async {
    final result = await db.customSelect(
      '''
      SELECT
        t.id as tag_id,
        COALESCE(COUNT(tt.id), 0) as transaction_count
      FROM tags t
      LEFT JOIN transaction_tags tt ON t.id = tt.tag_id
      GROUP BY t.id
      ''',
      readsFrom: {db.tags, db.transactionTags},
    ).get();

    final Map<int, int> counts = {};
    for (final row in result) {
      final tagId = row.data['tag_id'];
      final count = row.data['transaction_count'];

      if (tagId is int) {
        int countInt = 0;
        if (count is int) {
          countInt = count;
        } else if (count is BigInt) {
          countInt = count.toInt();
        } else if (count is num) {
          countInt = count.toInt();
        }
        counts[tagId] = countInt;
      }
    }

    return counts;
  }

  @override
  Future<({int count, double expense, double income})> getTagStats(int tagId, {int? ledgerId}) async {
    // §7 共享账本:负 id 是 synthetic tag，经 TransactionTagOverrides 反查统计
    if (tagId < 0) return _sharedTagStatsBySyntheticId(tagId, ledgerId);
    final ledgerFilter = ledgerId != null ? 'AND tx.ledger_id = ?' : '';
    final vars = <d.Variable>[d.Variable.withInt(tagId)];
    if (ledgerId != null) vars.add(d.Variable.withInt(ledgerId));
    final result = await db.customSelect(
      '''
      SELECT
        COUNT(*) as count,
        COALESCE(SUM(CASE WHEN tx.type = 'expense' THEN tx.amount ELSE 0 END), 0) as expense,
        COALESCE(SUM(CASE WHEN tx.type = 'income' THEN tx.amount ELSE 0 END), 0) as income
      FROM transaction_tags tt
      INNER JOIN transactions tx ON tt.transaction_id = tx.id
      WHERE tt.tag_id = ? $ledgerFilter
      ''',
      variables: vars,
      readsFrom: {db.transactionTags, db.transactions},
    ).getSingle();

    int parseCount(dynamic v) {
      if (v is int) return v;
      if (v is BigInt) return v.toInt();
      if (v is num) return v.toInt();
      return 0;
    }

    double parseAmount(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is BigInt) return v.toDouble();
      if (v is num) return v.toDouble();
      return 0.0;
    }

    return (
      count: parseCount(result.data['count']),
      expense: parseAmount(result.data['expense']),
      income: parseAmount(result.data['income']),
    );
  }

  @override
  Future<List<Transaction>> getTransactionsByTag(int tagId) async {
    final query = db.select(db.transactions).join([
      d.innerJoin(
        db.transactionTags,
        db.transactionTags.transactionId.equalsExp(db.transactions.id),
      ),
    ])
      ..where(db.transactionTags.tagId.equals(tagId))
      ..orderBy([d.OrderingTerm(expression: db.transactions.happenedAt, mode: d.OrderingMode.desc)]);

    final rows = await query.get();
    return rows.map((row) => row.readTable(db.transactions)).toList();
  }

  @override
  Future<List<Transaction>> getTransactionsByTagInRange({
    required int tagId,
    required DateTime start,
    required DateTime end,
  }) async {
    final query = db.select(db.transactions).join([
      d.innerJoin(
        db.transactionTags,
        db.transactionTags.transactionId.equalsExp(db.transactions.id),
      ),
    ])
      ..where(
        db.transactionTags.tagId.equals(tagId) &
        db.transactions.happenedAt.isBiggerOrEqualValue(start) &
        db.transactions.happenedAt.isSmallerThanValue(end),
      )
      ..orderBy([d.OrderingTerm(expression: db.transactions.happenedAt, mode: d.OrderingMode.desc)]);

    final rows = await query.get();
    return rows.map((row) => row.readTable(db.transactions)).toList();
  }

  // ============================================
  // 响应式监听
  // ============================================

  @override
  Stream<List<Tag>> watchAllTags() {
    return (db.select(db.tags)
      ..orderBy([(t) => d.OrderingTerm(expression: t.sortOrder)])).watch();
  }

  @override
  Stream<List<({Tag tag, int transactionCount})>> watchTagsWithStats() async* {
    await for (final rows in db.customSelect(
      '''
      SELECT
        t.id as tag_id,
        t.name as tag_name,
        t.color as tag_color,
        t.sort_order as tag_sort_order,
        t.created_at as tag_created_at,
        COALESCE(COUNT(tt.id), 0) as transaction_count
      FROM tags t
      LEFT JOIN transaction_tags tt ON t.id = tt.tag_id
      GROUP BY t.id, t.name, t.color, t.sort_order, t.created_at
      ORDER BY t.sort_order
      ''',
      readsFrom: {db.tags, db.transactionTags},
    ).watch()) {
      final results = <({Tag tag, int transactionCount})>[];

      for (final row in rows) {
        final tag = Tag(
          id: row.read<int>('tag_id'),
          name: row.read<String>('tag_name'),
          color: row.read<String?>('tag_color'),
          sortOrder: row.read<int>('tag_sort_order'),
          createdAt: row.read<DateTime>('tag_created_at'),
        );
        final count = row.read<int>('transaction_count');

        results.add((tag: tag, transactionCount: count));
      }

      yield results;
    }
  }

  @override
  Stream<Tag?> watchTag(int tagId) {
    // §7 共享账本:负 id 是 SharedLedgerTags 的 synthetic id（_syntheticIdForSyncId
    // 派生）。标签详情页传过来时去 shared 表反查转 synthetic Tag，跟
    // getTagsForTransaction 路径一致。
    if (tagId < 0) return _watchSharedTagBySyntheticId(tagId);
    return (db.select(db.tags)
      ..where((t) => t.id.equals(tagId))).watchSingleOrNull();
  }

  /// SharedLedgerTags 表变化时 re-emit。synthetic id 是派生，反查只能扫表。
  Stream<Tag?> _watchSharedTagBySyntheticId(int syntheticId) {
    final ctrl = StreamController<Tag?>();
    StreamSubscription? sub;

    Future<void> emit() async {
      final rows = await db.select(db.sharedLedgerTags).get();
      for (final s in rows) {
        if (_syntheticIdForSyncId(s.syncId) == syntheticId) {
          if (!ctrl.isClosed) {
            ctrl.add(Tag(
              id: syntheticId,
              name: s.name,
              color: s.color,
              sortOrder: 0,
              createdAt: DateTime.now(),
              syncId: s.syncId,
            ));
          }
          return;
        }
      }
      if (!ctrl.isClosed) ctrl.add(null);
    }

    ctrl.onListen = () {
      emit();
      sub = db
          .tableUpdates(d.TableUpdateQuery.onTable(db.sharedLedgerTags))
          .listen((_) => emit());
    };
    ctrl.onCancel = () async {
      await sub?.cancel();
    };
    return ctrl.stream;
  }

  /// 共享账本:synthetic tag 下的交易 — 经 TransactionTagOverrides(tagSyncId)反查。
  Stream<List<Transaction>> _watchSharedTxByTagSyntheticId(
      int syntheticId, int? ledgerId) {
    final ctrl = StreamController<List<Transaction>>();
    StreamSubscription? sub;
    String? matchedSyncId;

    Future<void> resolveSyncId() async {
      if (matchedSyncId != null) return;
      final rows = await db.select(db.sharedLedgerTags).get();
      for (final s in rows) {
        if (_syntheticIdForSyncId(s.syncId) == syntheticId) {
          matchedSyncId = s.syncId;
          return;
        }
      }
    }

    Future<void> emit() async {
      await resolveSyncId();
      if (matchedSyncId == null) {
        if (!ctrl.isClosed) ctrl.add(const []);
        return;
      }
      final overrides = await (db.select(db.transactionTagOverrides)
            ..where((o) => o.tagSyncId.equals(matchedSyncId!)))
          .get();
      final txSyncIds = overrides.map((o) => o.transactionSyncId).toList();
      if (txSyncIds.isEmpty) {
        if (!ctrl.isClosed) ctrl.add(const []);
        return;
      }
      final q = db.select(db.transactions)
        ..where((t) => t.syncId.isIn(txSyncIds))
        ..orderBy([
          (t) => d.OrderingTerm(
              expression: t.happenedAt, mode: d.OrderingMode.desc),
        ]);
      if (ledgerId != null) {
        q.where((t) => t.ledgerId.equals(ledgerId));
      }
      final list = await q.get();
      if (!ctrl.isClosed) ctrl.add(list);
    }

    ctrl.onListen = () {
      emit();
      sub = db.tableUpdates(d.TableUpdateQuery.onAllTables([
        db.transactions,
        db.transactionTagOverrides,
        db.sharedLedgerTags,
      ])).listen((_) => emit());
    };
    ctrl.onCancel = () async {
      await sub?.cancel();
    };
    return ctrl.stream;
  }

  /// 共享账本:synthetic tag 的统计 — 基于 override 关联的交易聚合。
  Future<({int count, double expense, double income})>
      _sharedTagStatsBySyntheticId(int syntheticId, int? ledgerId) async {
    String? matchedSyncId;
    final rows = await db.select(db.sharedLedgerTags).get();
    for (final s in rows) {
      if (_syntheticIdForSyncId(s.syncId) == syntheticId) {
        matchedSyncId = s.syncId;
        break;
      }
    }
    if (matchedSyncId == null) return (count: 0, expense: 0.0, income: 0.0);
    final overrides = await (db.select(db.transactionTagOverrides)
          ..where((o) => o.tagSyncId.equals(matchedSyncId!)))
        .get();
    final txSyncIds = overrides.map((o) => o.transactionSyncId).toList();
    if (txSyncIds.isEmpty) return (count: 0, expense: 0.0, income: 0.0);
    final q = db.select(db.transactions)
      ..where((t) => t.syncId.isIn(txSyncIds));
    if (ledgerId != null) {
      q.where((t) => t.ledgerId.equals(ledgerId));
    }
    final txs = await q.get();
    var count = 0;
    var expense = 0.0;
    var income = 0.0;
    for (final t in txs) {
      count++;
      if (t.type == 'expense') {
        expense += t.amount;
      } else if (t.type == 'income') {
        income += t.amount;
      }
    }
    return (count: count, expense: expense, income: income);
  }

  @override
  Stream<List<Tag>> watchTagsForTransaction(int transactionId) {
    return db.customSelect(
      '''
      SELECT t.*
      FROM tags t
      INNER JOIN transaction_tags tt ON t.id = tt.tag_id
      WHERE tt.transaction_id = ?
      ORDER BY t.sort_order
      ''',
      variables: [d.Variable.withInt(transactionId)],
      readsFrom: {db.tags, db.transactionTags},
    ).watch().map((rows) {
      return rows.map((row) {
        return Tag(
          id: row.read<int>('id'),
          name: row.read<String>('name'),
          color: row.read<String?>('color'),
          sortOrder: row.read<int>('sort_order'),
          createdAt: row.read<DateTime>('created_at'),
        );
      }).toList();
    });
  }

  @override
  Stream<List<Transaction>> watchTransactionsByTag(int tagId, {int? ledgerId}) {
    // §7 共享账本:负 id 是 synthetic tag，经 TransactionTagOverrides 反查交易
    if (tagId < 0) return _watchSharedTxByTagSyntheticId(tagId, ledgerId);
    final ledgerFilter = ledgerId != null ? 'AND tx.ledger_id = ?' : '';
    final vars = <d.Variable>[d.Variable.withInt(tagId)];
    if (ledgerId != null) vars.add(d.Variable.withInt(ledgerId));
    return db.customSelect(
      '''
      SELECT tx.*
      FROM transactions tx
      INNER JOIN transaction_tags tt ON tx.id = tt.transaction_id
      WHERE tt.tag_id = ? $ledgerFilter
      ORDER BY tx.happened_at DESC
      ''',
      variables: vars,
      readsFrom: {db.transactions, db.transactionTags},
    ).watch().map((rows) {
      return rows.map((row) {
        return Transaction(
          id: row.read<int>('id'),
          ledgerId: row.read<int>('ledger_id'),
          type: row.read<String>('type'),
          amount: row.read<double>('amount'),
          categoryId: row.read<int?>('category_id'),
          accountId: row.read<int?>('account_id'),
          toAccountId: row.read<int?>('to_account_id'),
          happenedAt: row.read<DateTime>('happened_at'),
          note: row.read<String?>('note'),
          recurringId: row.read<int?>('recurring_id'),
        );
      }).toList();
    });
  }

  // ============================================
  // 辅助方法
  // ============================================

  @override
  Future<bool> isTagNameDuplicate({
    required String name,
    int? excludeId,
  }) async {
    var expression = db.tags.name.equals(name);

    if (excludeId != null) {
      expression = expression & db.tags.id.equals(excludeId).not();
    }

    final query = db.select(db.tags)..where((t) => expression);
    final results = await query.get();
    return results.isNotEmpty;
  }

  @override
  Future<void> updateTagSortOrders(List<({int id, int sortOrder})> updates) async {
    await db.transaction(() async {
      for (final update in updates) {
        await (db.update(db.tags)..where((t) => t.id.equals(update.id)))
            .write(TagsCompanion(sortOrder: d.Value(update.sortOrder)));
      }
    });
  }

  @override
  Future<List<Tag>> getRecentlyUsedTags({int limit = 10}) async {
    // 获取最近使用的标签（按最后使用时间排序）
    final result = await db.customSelect(
      '''
      SELECT t.*, MAX(tx.happened_at) as last_used
      FROM tags t
      INNER JOIN transaction_tags tt ON t.id = tt.tag_id
      INNER JOIN transactions tx ON tt.transaction_id = tx.id
      GROUP BY t.id
      ORDER BY last_used DESC
      LIMIT ?
      ''',
      variables: [d.Variable.withInt(limit)],
      readsFrom: {db.tags, db.transactionTags, db.transactions},
    ).get();

    return result.map((row) {
      return Tag(
        id: row.read<int>('id'),
        name: row.read<String>('name'),
        color: row.read<String?>('color'),
        sortOrder: row.read<int>('sort_order'),
        createdAt: row.read<DateTime>('created_at'),
      );
    }).toList();
  }
}
