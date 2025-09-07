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

  Future<void> deleteLedger(int id) async {
    await (db.delete(db.ledgers)..where((tbl) => tbl.id.equals(id))).go();
    // Note: For simplicity, we do not cascade delete related rows here in MVP
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
}
