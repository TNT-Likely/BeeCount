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
