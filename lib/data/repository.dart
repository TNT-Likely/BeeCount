import 'package:drift/drift.dart' as d;

import 'db.dart';

class BeeRepository {
  final BeeDatabase db;
  BeeRepository(this.db);

  Stream<List<Transaction>> recentTransactions(
      {required int ledgerId, int limit = 20}) {
    final q = (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..orderBy([
            (t) => d.OrderingTerm(
                expression: t.happenedAt, mode: d.OrderingMode.desc)
          ])
          ..limit(limit))
        .watch();
    return q;
  }

  // Lightweight counts for Settings header (performance-friendly)
  Future<int> ledgerCount() async {
    final row = await db.customSelect('SELECT COUNT(*) AS c FROM ledgers',
        readsFrom: {db.ledgers}).getSingle();
    final v = row.data['c'];
    if (v is int) return v;
    if (v is BigInt) return v.toInt();
    if (v is num) return v.toInt();
    return 0;
  }

  Future<({int dayCount, int txCount})> countsForLedger(
      {required int ledgerId}) async {
    final txRow = await db.customSelect(
        'SELECT COUNT(*) AS c FROM transactions WHERE ledger_id = ?1',
        variables: [d.Variable.withInt(ledgerId)],
        readsFrom: {db.transactions}).getSingle();
    final dayRow = await db.customSelect("""
      SELECT COUNT(DISTINCT strftime('%Y-%m-%d', happened_at, 'unixepoch', 'localtime')) AS c
      FROM transactions WHERE ledger_id = ?1
      """,
        variables: [d.Variable.withInt(ledgerId)],
        readsFrom: {db.transactions}).getSingle();

    int parse(dynamic v) {
      if (v is int) return v;
      if (v is BigInt) return v.toInt();
      if (v is num) return v.toInt();
      return 0;
    }

    return (dayCount: parse(dayRow.data['c']), txCount: parse(txRow.data['c']));
  }

  /// 全部账本的聚合统计：总笔数与记账天数（不同日期求去重）
  Future<({int dayCount, int txCount})> countsAll() async {
    final txRow = await db.customSelect(
      'SELECT COUNT(*) AS c FROM transactions',
      readsFrom: {db.transactions},
    ).getSingle();
    final dayRow = await db.customSelect(
      """
      SELECT COUNT(DISTINCT strftime('%Y-%m-%d', happened_at, 'unixepoch', 'localtime')) AS c
      FROM transactions
      """,
      readsFrom: {db.transactions},
    ).getSingle();

    int parse(dynamic v) {
      if (v is int) return v;
      if (v is BigInt) return v.toInt();
      if (v is num) return v.toInt();
      return 0;
    }

    return (dayCount: parse(dayRow.data['c']), txCount: parse(txRow.data['c']));
  }

  // Aggregation: totals by category for a period and type (income/expense)
  Future<List<({int? id, String name, double total})>> totalsByCategory({
    required int ledgerId,
    required String type, // 'income' or 'expense'
    required DateTime start,
    required DateTime end,
  }) async {
    final q = (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.type.equals(type) &
              t.happenedAt.isBetweenValues(start, end)))
        .join([
      d.leftOuterJoin(db.categories,
          db.categories.id.equalsExp(db.transactions.categoryId)),
    ]);
    final rows = await q.get();
    final map = <int?, double>{}; // categoryId (nullable) -> total
    final names = <int?, String>{};
    for (final r in rows) {
      final t = r.readTable(db.transactions);
      final c = r.readTableOrNull(db.categories);
      final id = c?.id;
      final name = c?.name ?? '未分类';
      names[id] = name;
      map.update(id, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    final list = map.entries
        .map((e) => (id: e.key, name: names[e.key] ?? '未分类', total: e.value))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  // Aggregation: totals by day for a period and type
  Future<List<({DateTime day, double total})>> totalsByDay({
    required int ledgerId,
    required String type, // 'income' or 'expense'
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.type.equals(type) &
              t.happenedAt.isBetweenValues(start, end)))
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

  /// 统计指定账本、类型与时间范围内是否存在交易（返回记录条数）
  Future<int> countByTypeInRange({
    required int ledgerId,
    required String type, // 'income' | 'expense'
    required DateTime start,
    required DateTime end,
  }) async {
    final row = await db.customSelect(
      'SELECT COUNT(*) AS c FROM transactions WHERE ledger_id = ?1 AND type = ?2 AND happened_at >= ?3 AND happened_at < ?4',
      variables: [
        d.Variable<int>(ledgerId),
        d.Variable<String>(type),
        d.Variable<DateTime>(start),
        d.Variable<DateTime>(end),
      ],
      readsFrom: {db.transactions},
    ).getSingle();
    final v = row.data['c'];
    if (v is int) return v;
    if (v is BigInt) return v.toInt();
    if (v is num) return v.toInt();
    return 0;
  }

  // Transactions with category filter within a range (by categoryId and type)
  Stream<List<({Transaction t, Category? category})>>
      transactionsForCategoryInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
    int? categoryId,
    required String type, // 'income' or 'expense'
  }) {
    final base = (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.type.equals(type) &
              t.happenedAt.isBetweenValues(start, end))
          ..orderBy([
            (t) => d.OrderingTerm(
                expression: t.happenedAt, mode: d.OrderingMode.desc)
          ]))
        .join([
      d.leftOuterJoin(db.categories,
          db.categories.id.equalsExp(db.transactions.categoryId)),
    ]);
    if (categoryId == null) {
      base.where(db.transactions.categoryId.isNull());
    } else {
      base.where(db.transactions.categoryId.equals(categoryId));
    }
    return base.watch().map((rows) => rows
        .map((r) => (
              t: r.readTable(db.transactions),
              category: r.readTableOrNull(db.categories)
            ))
        .toList());
  }

  // Aggregation: totals by month for a year and type
  Future<List<({DateTime month, double total})>> totalsByMonth({
    required int ledgerId,
    required String type, // 'income' or 'expense'
    required int year,
  }) async {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    final rows = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.type.equals(type) &
              t.happenedAt.isBetweenValues(start, end)))
        .get();
    final map = <int, double>{}; // month -> total
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

  // Aggregation: totals by year (all years) for a type
  Future<List<({int year, double total})>> totalsByYearSeries({
    required int ledgerId,
    required String type, // 'income' or 'expense'
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

  // Aggregation: income & expense totals for arbitrary range
  Future<(double income, double expense)> totalsInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) async {
    final list = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.happenedAt.isBetweenValues(start, end)))
        .get();
    double income = 0, expense = 0;
    for (final t in list) {
      if (t.type == 'income') income += t.amount;
      if (t.type == 'expense') expense += t.amount;
    }
    return (income, expense);
  }

  Stream<List<Transaction>> transactionsInMonth(
      {required int ledgerId, required DateTime month}) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final q = (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.happenedAt.isBetweenValues(start, end))
          ..orderBy([
            (t) => d.OrderingTerm(
                expression: t.happenedAt, mode: d.OrderingMode.desc)
          ]))
        .watch();
    return q;
  }

  /// 计算当前账本总余额：收入 - 支出
  Future<double> getCurrentBalance({required int ledgerId}) async {
    final rows = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId)))
        .get();
    double balance = 0;
    for (final t in rows) {
      if (t.type == 'income') {
        balance += t.amount;
      } else if (t.type == 'expense') {
        balance -= t.amount;
      }
      // transfer 不影响总余额
    }
    return balance;
  }

  Future<int> addTransaction({
    required int ledgerId,
    required String type, // expense / income / transfer
    required double amount,
    int? categoryId,
    int? accountId,
    int? toAccountId,
    required DateTime happenedAt,
    String? note,
  }) async {
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: type,
          amount: amount,
          categoryId: d.Value(categoryId),
          accountId: d.Value(accountId),
          toAccountId: d.Value(toAccountId),
          happenedAt: d.Value(happenedAt),
          note: d.Value(note),
        ));
  }

  /// 批量新增交易，单事务内插入，返回插入条数
  Future<int> insertTransactionsBatch(List<TransactionsCompanion> items) async {
    if (items.isEmpty) return 0;
    return db.transaction(() async {
      await db.batch((b) => b.insertAll(db.transactions, items));
      return items.length;
    });
  }

  // --- 去重与签名工具 ---

  /// 生成用于判重的签名（同一账本内）：
  /// type|amount|categoryId|null-safe|happenedAtEpochMs|note
  String txSignature({
    required String type,
    required double amount,
    required int? categoryId,
    required DateTime happenedAt,
    required String? note,
  }) {
    final ts = happenedAt.millisecondsSinceEpoch;
    final cat = categoryId?.toString() ?? '';
    final n = note ?? '';
    // 避免小数误差，amount 规范为最多 6 位小数
    final amt = amount.toStringAsFixed(6);
    return '$type|$amt|$cat|$ts|$n';
  }

  /// 获取某账本下所有交易的签名集合
  Future<Set<String>> signatureSetForLedger(int ledgerId) async {
    final rows = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId)))
        .get();
    final set = <String>{};
    for (final t in rows) {
      set.add(txSignature(
          type: t.type,
          amount: t.amount,
          categoryId: t.categoryId,
          happenedAt: t.happenedAt,
          note: t.note));
    }
    return set;
  }

  /// 对指定账本执行去重：保留每个签名的最小 id，删除其它重复项。
  /// 返回删除的条数。
  Future<int> deduplicateLedgerTransactions(int ledgerId) async {
    final rows = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..orderBy([(t) => d.OrderingTerm(expression: t.id)]))
        .get();
    final firstIdForSig = <String, int>{};
    final toDelete = <int>[];
    for (final t in rows) {
      final sig = txSignature(
          type: t.type,
          amount: t.amount,
          categoryId: t.categoryId,
          happenedAt: t.happenedAt,
          note: t.note);
      final id = t.id;
      final existed = firstIdForSig[sig];
      if (existed == null) {
        firstIdForSig[sig] = id;
      } else {
        // 此签名已存在，视为重复，删除当前 id
        toDelete.add(id);
      }
    }
    if (toDelete.isEmpty) return 0;
    await (db.delete(db.transactions)..where((t) => t.id.isIn(toDelete))).go();
    return toDelete.length;
  }

  // Ledgers
  Stream<List<Ledger>> ledgers() => db.select(db.ledgers).watch();

  Future<int> createLedger(
      {required String name, String currency = 'CNY'}) async {
    return db.into(db.ledgers).insert(
        LedgersCompanion.insert(name: name, currency: d.Value(currency)));
  }

  Future<void> updateLedgerName({required int id, required String name}) async {
    await (db.update(db.ledgers)..where((tbl) => tbl.id.equals(id))).write(
      LedgersCompanion(name: d.Value(name)),
    );
  }

  Future<void> updateLedger(
      {required int id, String? name, String? currency}) async {
    final comp = LedgersCompanion(
      name: name != null ? d.Value(name) : const d.Value.absent(),
      currency: currency != null ? d.Value(currency) : const d.Value.absent(),
    );
    await (db.update(db.ledgers)..where((tbl) => tbl.id.equals(id)))
        .write(comp);
  }

  Future<void> deleteLedger(int id) async {
    // 先删除该账本下的所有交易，再删除账本本身
    await db.transaction(() async {
      await (db.delete(db.transactions)..where((t) => t.ledgerId.equals(id)))
          .go();
      await (db.delete(db.ledgers)..where((tbl) => tbl.id.equals(id))).go();
    });
  }

  /// 获取当前最大账本ID
  Future<int> maxLedgerId() async {
    final row = await db.customSelect(
        'SELECT IFNULL(MAX(id), 0) AS m FROM ledgers',
        readsFrom: {db.ledgers}).getSingle();
    final v = row.data['m'];
    if (v is int) return v;
    if (v is BigInt) return v.toInt();
    if (v is num) return v.toInt();
    return 0;
  }

  /// 取得下一个未占用的账本ID（通常为 max+1）
  Future<int> nextFreeLedgerId() async {
    final maxId = await maxLedgerId();
    return maxId + 1;
  }

  /// 将账本ID从 fromId 迁移到 toId（同时更新关联的 accounts/transactions）
  /// 要求 toId 在迁移前未被 ledgers 使用。
  Future<void> reassignLedgerId(
      {required int fromId, required int toId}) async {
    if (fromId == toId) return;
    final existsTo = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(toId)))
        .getSingleOrNull();
    if (existsTo != null) {
      throw StateError('目标账本ID已存在: $toId');
    }
    await db.transaction(() async {
      // 先迁移子表中的外键引用
      await db.customUpdate(
        'UPDATE accounts SET ledger_id = ?1 WHERE ledger_id = ?2',
        variables: [d.Variable<int>(toId), d.Variable<int>(fromId)],
        updates: {db.accounts},
      );
      await db.customUpdate(
        'UPDATE transactions SET ledger_id = ?1 WHERE ledger_id = ?2',
        variables: [d.Variable<int>(toId), d.Variable<int>(fromId)],
        updates: {db.transactions},
      );
      // 再更新主表ID（SQLite 允许更新 INTEGER PRIMARY KEY 的值）
      await db.customUpdate(
        'UPDATE ledgers SET id = ?1 WHERE id = ?2',
        variables: [d.Variable<int>(toId), d.Variable<int>(fromId)],
        updates: {db.ledgers},
      );
    });
  }

  /// 清空指定账本的所有交易记录，返回删除的条数
  Future<int> clearLedgerTransactions(int ledgerId) async {
    final count = await (db.delete(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId)))
        .go();
    return count;
  }

  // Monthly totals
  Future<(double income, double expense)> monthlyTotals(
      {required int ledgerId, required DateTime month}) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final list = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.happenedAt.isBetweenValues(start, end)))
        .get();
    double income = 0, expense = 0;
    for (final t in list) {
      if (t.type == 'income') income += t.amount;
      if (t.type == 'expense') expense += t.amount;
    }
    return (income, expense);
  }

  Future<(double income, double expense)> yearlyTotals(
      {required int ledgerId, required int year}) async {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    final list = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.happenedAt.isBetweenValues(start, end)))
        .get();
    double income = 0, expense = 0;
    for (final t in list) {
      if (t.type == 'income') income += t.amount;
      if (t.type == 'expense') expense += t.amount;
    }
    return (income, expense);
  }

  Future<int> upsertCategory(
      {required String name, required String kind}) async {
    final existing = await (db.select(db.categories)
          ..where((c) => c.name.equals(name) & c.kind.equals(kind)))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    return db.into(db.categories).insert(CategoriesCompanion.insert(
        name: name, kind: kind, icon: const d.Value(null)));
  }

  // Join model for UI
  Stream<List<({Transaction t, Category? category})>>
      transactionsWithCategoryInMonth(
          {required int ledgerId, required DateTime month}) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final q = (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.happenedAt.isBetweenValues(start, end))
          ..orderBy([
            (t) => d.OrderingTerm(
                expression: t.happenedAt, mode: d.OrderingMode.desc)
          ]))
        .join([
      d.leftOuterJoin(db.categories,
          db.categories.id.equalsExp(db.transactions.categoryId)),
    ]);
    return q.watch().map((rows) => rows
        .map((r) => (
              t: r.readTable(db.transactions),
              category: r.readTableOrNull(db.categories)
            ))
        .toList());
  }

  Stream<List<({Transaction t, Category? category})>>
      transactionsWithCategoryInYear(
          {required int ledgerId, required int year}) {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    final q = (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.happenedAt.isBetweenValues(start, end))
          ..orderBy([
            (t) => d.OrderingTerm(
                expression: t.happenedAt, mode: d.OrderingMode.desc)
          ]))
        .join([
      d.leftOuterJoin(db.categories,
          db.categories.id.equalsExp(db.transactions.categoryId)),
    ]);
    return q.watch().map((rows) => rows
        .map((r) => (
              t: r.readTable(db.transactions),
              category: r.readTableOrNull(db.categories)
            ))
        .toList());
  }

  Future<void> updateTransaction({
    required int id,
    required String type,
    required double amount,
    int? categoryId,
    String? note,
    DateTime? happenedAt,
  }) async {
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        type: d.Value(type),
        amount: d.Value(amount),
        categoryId: d.Value(categoryId),
        note: d.Value(note),
        happenedAt:
            happenedAt != null ? d.Value(happenedAt) : const d.Value.absent(),
      ),
    );
  }

  // All transactions joined with category, ordered by date desc
  Stream<List<({Transaction t, Category? category})>>
      transactionsWithCategoryAll({required int ledgerId}) {
    final q = (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..orderBy([
            (t) => d.OrderingTerm(
                expression: t.happenedAt, mode: d.OrderingMode.desc)
          ]))
        .join([
      d.leftOuterJoin(db.categories,
          db.categories.id.equalsExp(db.transactions.categoryId)),
    ]);
    return q.watch().map((rows) => rows
        .map((r) => (
              t: r.readTable(db.transactions),
              category: r.readTableOrNull(db.categories)
            ))
        .toList());
  }
  
  // Category CRUD operations
  Future<int> createCategory({
    required String name,
    required String kind,
    String? icon,
  }) async {
    return await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        name: name,
        kind: kind,
        icon: d.Value(icon),
      ),
    );
  }
  
  Future<void> updateCategory(
    int id, {
    String? name,
    String? icon,
  }) async {
    await (db.update(db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: name != null ? d.Value(name) : const d.Value.absent(),
        icon: icon != null ? d.Value(icon) : const d.Value.absent(),
      ),
    );
  }
  
  Future<void> deleteCategory(int id) async {
    await (db.delete(db.categories)..where((c) => c.id.equals(id))).go();
  }
  
  Future<int> getTransactionCountByCategory(int categoryId) async {
    final result = await db.customSelect(
      'SELECT COUNT(*) AS count FROM transactions WHERE category_id = ?1',
      variables: [d.Variable.withInt(categoryId)],
      readsFrom: {db.transactions},
    ).getSingle();

    final count = result.data['count'];
    if (count is int) return count;
    if (count is BigInt) return count.toInt();
    if (count is num) return count.toInt();
    return 0;
  }

  /// 批量获取所有分类的交易数量（性能优化版本）
  Future<Map<int, int>> getAllCategoryTransactionCounts() async {
    final result = await db.customSelect(
      '''
      SELECT
        c.id as category_id,
        COALESCE(COUNT(t.id), 0) as transaction_count
      FROM categories c
      LEFT JOIN transactions t ON c.id = t.category_id
      GROUP BY c.id
      ''',
      readsFrom: {db.categories, db.transactions},
    ).get();

    final Map<int, int> counts = {};
    for (final row in result) {
      final categoryId = row.data['category_id'];
      final count = row.data['transaction_count'];

      if (categoryId is int) {
        int countInt = 0;
        if (count is int) {
          countInt = count;
        } else if (count is BigInt) {
          countInt = count.toInt();
        } else if (count is num) {
          countInt = count.toInt();
        }

        counts[categoryId] = countInt;
      }
    }

    return counts;
  }
  
  // 分类迁移：将fromCategoryId的所有交易迁移到toCategoryId
  Future<int> migrateCategory({
    required int fromCategoryId,
    required int toCategoryId,
  }) async {
    // 获取迁移前的数量
    final beforeCount = await getTransactionCountByCategory(fromCategoryId);
    
    // 执行迁移
    await (db.update(db.transactions)
      ..where((t) => t.categoryId.equals(fromCategoryId))).write(
      TransactionsCompanion(
        categoryId: d.Value(toCategoryId),
      ),
    );
    
    // 返回迁移的交易数量
    return beforeCount;
  }
  
  // 获取分类迁移信息（检查是否可以迁移）
  Future<({int transactionCount, bool canMigrate})> getCategoryMigrationInfo({
    required int fromCategoryId,
    required int toCategoryId,
  }) async {
    // 检查源分类的交易数量
    final transactionCount = await getTransactionCountByCategory(fromCategoryId);
    
    // 检查目标分类是否存在
    final targetCategory = await (db.select(db.categories)
      ..where((c) => c.id.equals(toCategoryId))).getSingleOrNull();
    
    final canMigrate = transactionCount > 0 && targetCategory != null && fromCategoryId != toCategoryId;
    
    return (transactionCount: transactionCount, canMigrate: canMigrate);
  }
  
  // 获取分类汇总信息
  Future<({int totalCount, double totalAmount, double averageAmount})> getCategorySummary(int categoryId) async {
    final result = await db.customSelect(
      '''
      SELECT 
        COUNT(*) as count,
        SUM(amount) as total,
        AVG(amount) as average
      FROM transactions 
      WHERE category_id = ?1
      ''',
      variables: [d.Variable.withInt(categoryId)],
      readsFrom: {db.transactions},
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
    
    final count = parseCount(result.data['count']);
    final total = parseAmount(result.data['total']);
    final average = parseAmount(result.data['average']);
    
    return (
      totalCount: count,
      totalAmount: total,
      averageAmount: average,
    );
  }
  
  // 获取分类下的所有交易记录（按时间倒序）
  Future<List<Transaction>> getTransactionsByCategory(int categoryId) async {
    return await (db.select(db.transactions)
      ..where((t) => t.categoryId.equals(categoryId))
      ..orderBy([
        (t) => d.OrderingTerm(
          expression: t.happenedAt,
          mode: d.OrderingMode.desc,
        )
      ])).get();
  }

  // 获取分类下的所有交易记录（支持自定义排序）
  Future<List<Transaction>> getTransactionsByCategoryWithSort(
    int categoryId, {
    String sortBy = 'time', // 'time' or 'amount'
    bool ascending = false,
  }) async {
    final query = db.select(db.transactions)..where((t) => t.categoryId.equals(categoryId));

    if (sortBy == 'amount') {
      query.orderBy([
        (t) => d.OrderingTerm(
          expression: t.amount,
          mode: ascending ? d.OrderingMode.asc : d.OrderingMode.desc,
        )
      ]);
    } else {
      query.orderBy([
        (t) => d.OrderingTerm(
          expression: t.happenedAt,
          mode: ascending ? d.OrderingMode.asc : d.OrderingMode.desc,
        )
      ]);
    }

    return await query.get();
  }
}
