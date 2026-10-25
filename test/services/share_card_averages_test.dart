import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/export/share_poster_data_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency,month_start_day) VALUES(1,'QA CNY','CNY',1)");
    await db.customStatement(
        "INSERT INTO categories(id,name,kind) VALUES(1,'QA Food','expense'),(2,'QA Salary','income')");
  });
  tearDown(() => db.close());
  Future<void> tx(DateTime date, double amount,
      {String type = 'expense', double? native, bool excluded = false}) async {
    await db.customStatement(
        'INSERT INTO transactions(ledger_id,type,amount,native_amount,category_id,happened_at,exclude_from_stats) VALUES(?,?,?,?,?,?,?)',
        [
          1,
          type,
          amount,
          native,
          type == 'income' ? 2 : 1,
          date.millisecondsSinceEpoch ~/ 1000,
          excluded ? 1 : 0
        ]);
  }

  for (final c
      in <({String name, DateTime now, int year, int month, int sd, int days})>[
    (
      name: 'current month includes today',
      now: DateTime(2026, 10, 25, 23, 59),
      year: 2026,
      month: 10,
      sd: 1,
      days: 25
    ),
    (
      name: 'finished month full days',
      now: DateTime(2026, 10, 25),
      year: 2026,
      month: 9,
      sd: 1,
      days: 30
    ),
    (
      name: 'period first day',
      now: DateTime(2026, 10, 10),
      year: 2026,
      month: 10,
      sd: 10,
      days: 1
    ),
    (
      name: 'custom current period',
      now: DateTime(2026, 11, 5),
      year: 2026,
      month: 10,
      sd: 10,
      days: 27
    ),
    (
      name: 'custom ended period',
      now: DateTime(2026, 11, 10),
      year: 2026,
      month: 10,
      sd: 10,
      days: 31
    ),
    (
      name: 'natural month end',
      now: DateTime(2026, 10, 31),
      year: 2026,
      month: 10,
      sd: 1,
      days: 31
    ),
    (
      name: 'leap February',
      now: DateTime(2024, 3, 1),
      year: 2024,
      month: 2,
      sd: 1,
      days: 29
    ),
    (
      name: 'future period finite zero',
      now: DateTime(2026, 10, 25),
      year: 2026,
      month: 11,
      sd: 10,
      days: 0
    ),
  ]) {
    test(c.name, () async {
      await db.customStatement(
          'UPDATE ledgers SET month_start_day=? WHERE id=1', [c.sd]);
      final start = DateTime(c.year, c.month, c.sd);
      await tx(start, 10, native: 310);
      await tx(start, 10, type: 'income', native: 620);
      await tx(start, 1000, excluded: true);
      await tx(DateTime(c.year, c.month + 1, c.sd), 999);
      final data = await SharePosterDataService(repo, clock: () => c.now)
          .calculateMonthSummary(ledgerId: 1, year: c.year, month: c.month);
      expect(data.totalExpense, 310);
      expect(data.totalIncome, 620);
      expect(data.balance, 310);
      expect(
          data.avgDailyExpense, c.days == 0 ? 0 : closeTo(310 / c.days, 1e-8));
      expect(data.avgDailyExpense.isFinite, isTrue);
      expect(data.topExpenseCategories.single.total, 310);
    });
  }
  for (final c in <({String name, DateTime now, int year, int sd, int months})>[
    (
      name: 'current natural year October',
      now: DateTime(2026, 10, 25),
      year: 2026,
      sd: 1,
      months: 10
    ),
    (
      name: 'ended year',
      now: DateTime(2026, 1, 1),
      year: 2025,
      sd: 1,
      months: 12
    ),
    (
      name: 'custom current year before boundary',
      now: DateTime(2026, 10, 9),
      year: 2026,
      sd: 10,
      months: 9
    ),
    (
      name: 'custom current year at boundary',
      now: DateTime(2026, 10, 10),
      year: 2026,
      sd: 10,
      months: 10
    ),
    (
      name: 'custom prior year still current',
      now: DateTime(2026, 1, 5),
      year: 2025,
      sd: 10,
      months: 12
    ),
    (
      name: 'custom year first day',
      now: DateTime(2026, 1, 10),
      year: 2026,
      sd: 10,
      months: 1
    ),
    (
      name: 'year before first custom period',
      now: DateTime(2026, 1, 9),
      year: 2026,
      sd: 10,
      months: 0
    ),
    (
      name: 'future year',
      now: DateTime(2026, 10, 25),
      year: 2027,
      sd: 1,
      months: 0
    ),
  ]) {
    test(c.name, () async {
      await db.customStatement(
          'UPDATE ledgers SET month_start_day=? WHERE id=1', [c.sd]);
      await tx(DateTime(c.year, 1, c.sd), 10, native: 1200);
      await tx(DateTime(c.year, 1, c.sd), 20, type: 'income', native: 2400);
      await tx(DateTime(c.year, 1, c.sd), 999, excluded: true);
      await tx(DateTime(c.year + 1, 1, c.sd), 999);
      final data = await SharePosterDataService(repo, clock: () => c.now)
          .calculateYearSummary(ledgerId: 1, year: c.year);
      expect(data.totalExpense, 1200);
      expect(data.totalIncome, 2400);
      expect(data.avgMonthlyExpense, c.months == 0 ? 0 : 1200 / c.months);
      expect(data.avgMonthlyIncome, c.months == 0 ? 0 : 2400 / c.months);
      expect(data.avgMonthlyExpense.isFinite, isTrue);
    });
  }
}
