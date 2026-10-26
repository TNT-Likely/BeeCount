import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/pages/report/annual_report_page.dart';
import 'package:beecount/presentation/v4/bindings/annual_report_sections.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/export/share_poster_data_service.dart';
import 'package:beecount/utils/month_range.dart';
import 'package:beecount/utils/report_period_elapsed.dart';
import 'package:beecount/widgets/posters/annual_report_poster.dart';
import 'package:beecount_business_ui/annual_report.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

final cases =
    <({String label, int year, int sd, DateTime now, int months, int days})>[
  (
    label: 'current natural October',
    year: 2026,
    sd: 1,
    now: DateTime(2026, 10, 25, 23, 59),
    months: 10,
    days: 298
  ),
  (
    label: 'historical natural year',
    year: 2025,
    sd: 1,
    now: DateTime(2026, 10, 25),
    months: 12,
    days: 365
  ),
  (
    label: 'custom October before boundary',
    year: 2026,
    sd: 10,
    now: DateTime(2026, 10, 9),
    months: 9,
    days: 273
  ),
  (
    label: 'custom October at boundary',
    year: 2026,
    sd: 10,
    now: DateTime(2026, 10, 10),
    months: 10,
    days: 274
  ),
  (
    label: 'custom first day',
    year: 2026,
    sd: 10,
    now: DateTime(2026, 1, 10),
    months: 1,
    days: 1
  ),
  (
    label: 'previous custom year still current',
    year: 2025,
    sd: 10,
    now: DateTime(2026, 1, 5),
    months: 12,
    days: 361
  ),
  (
    label: 'ended custom year',
    year: 2025,
    sd: 10,
    now: DateTime(2026, 1, 10),
    months: 12,
    days: 365
  ),
  (
    label: 'before custom year start',
    year: 2026,
    sd: 10,
    now: DateTime(2026, 1, 9),
    months: 0,
    days: 0
  ),
  (
    label: 'future year',
    year: 2027,
    sd: 1,
    now: DateTime(2026, 10, 25),
    months: 0,
    days: 0
  ),
  (
    label: 'completed leap year',
    year: 2024,
    sd: 1,
    now: DateTime(2025, 1, 1),
    months: 12,
    days: 366
  ),
];
AnnualReportData report(int year) => AnnualReportData(
    year: year,
    totalDays: 1,
    totalRecords: 2,
    totalIncome: 2400,
    totalExpense: 1200,
    netSavings: 1200,
    topExpenseCategories: const [],
    monthlyData: const [(month: 1, income: 2400, expense: 1200)]);
Widget host(Widget child) => MaterialApp(
    locale: const Locale('en'),
    theme: beeTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child);
void main() {
  final l = AppLocalizationsEn();
  for (final c in cases) {
    test('shared denominators ${c.label}', () {
      expect(elapsedReportYearMonths(c.year, monthStartDay: c.sd, now: c.now),
          c.months);
      expect(elapsedReportDays(yearRangeFor(c.year, c.sd), now: c.now), c.days);
    });
    test(
        'SQLite share projection keeps totals and uses the same denominator ${c.label}',
        () async {
      final db = BeeDatabase.forTesting(NativeDatabase.memory());
      final repo = LocalRepository(db);
      try {
        final id = await repo.createLedger(name: 'QA Q20', currency: 'CNY');
        await repo.updateLedger(id: id, monthStartDay: c.sd);
        await repo.addTransaction(
            ledgerId: id,
            type: 'expense',
            amount: 1200,
            happenedAt: DateTime(c.year, 1, c.sd));
        await repo.addTransaction(
            ledgerId: id,
            type: 'income',
            amount: 2400,
            happenedAt: DateTime(c.year, 1, c.sd));
        final data = await SharePosterDataService(repo, clock: () => c.now)
            .calculateYearSummary(ledgerId: id, year: c.year);
        expect(data.totalExpense, 1200);
        expect(data.totalIncome, 2400);
        expect(data.avgMonthlyExpense, c.months == 0 ? 0 : 1200 / c.months);
        expect(data.avgMonthlyIncome, c.months == 0 ? 0 : 2400 / c.months);
      } finally {
        await db.close();
      }
    });
    testWidgets('annual page and actual poster show agreed amounts ${c.label}',
        (t) async {
      final monthly = c.months == 0 ? 0.0 : 1200 / c.months,
          daily = c.days == 0 ? 0.0 : 1200 / c.days;
      try {
        await t.pumpWidget(host(Builder(
            builder: (context) => Scaffold(
                body: annualReportSections(context, report(c.year),
                    monthStartDay: c.sd, now: c.now)[1]))));
        await t.pumpAndSettle();
        final metrics =
            t.widgetList<BeeAnnualMetric>(find.byType(BeeAnnualMetric));
        expect(
            metrics
                .singleWhere((m) => m.label == l.annualReportMonthlyAverage)
                .value,
            '¥${NumberFormat('#,##0.00', 'en').format(monthly)}');
        expect(
            metrics
                .singleWhere((m) => m.label == l.annualReportDailyAverage)
                .value,
            '¥${NumberFormat('#,##0.00', 'en').format(daily)}');
        await t.pumpWidget(host(Scaffold(
            body: SingleChildScrollView(
                child: Center(
                    child: AnnualReportPoster(
                        data: report(c.year),
                        primaryColor: Colors.amber,
                        monthStartDay: c.sd,
                        now: c.now))))));
        await t.pumpAndSettle();
        final monthlyColumn = find
            .ancestor(
                of: find.text(l.annualReportMonthlyAverage),
                matching: find.byType(Column))
            .first;
        final dailyColumn = find
            .ancestor(
                of: find.text(l.annualReportDailyAverage),
                matching: find.byType(Column))
            .first;
        expect(
            find.descendant(
                of: monthlyColumn,
                matching:
                    find.text(NumberFormat('#,##0', 'en').format(monthly))),
            findsOneWidget);
        expect(
            find.descendant(
                of: dailyColumn,
                matching: find.text(NumberFormat('#,##0', 'en').format(daily))),
            findsOneWidget);
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
      }
    });
  }
  testWidgets(
      'generation and privacy regeneration retain captured custom start day',
      (t) async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    final startDay = StateProvider<int>((ref) => 10);
    final data = report(2026);
    final container = ProviderContainer(overrides: [
      annualReportDataProvider(2026).overrideWith((ref) async => data),
      currentMonthStartDayProvider.overrideWith((ref) => ref.watch(startDay))
    ]);
    try {
      await t.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: host(const AnnualReportPage(initialYear: 2026))));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('annual-generate-poster')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      for (var i = 0;
          i < 40 && find.byType(AnnualReportPoster).evaluate().isEmpty;
          i++) {
        await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await t.pump(const Duration(milliseconds: 10));
      }
      expect(
          t
              .widget<AnnualReportPoster>(find.byType(AnnualReportPoster))
              .monthStartDay,
          10);
      await t.pump(const Duration(milliseconds: 600));
      for (var i = 0;
          i < 80 && find.byType(BeeAnnualPosterPreview).evaluate().isEmpty;
          i++) {
        await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await t.pump(const Duration(milliseconds: 20));
      }
      expect(find.byType(BeeAnnualPosterPreview), findsOneWidget);
      container.read(startDay.notifier).state = 20;
      await t.pump();
      await t.tap(find.text(l.sharePosterHideIncome));
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      expect(
          t
              .widget<AnnualReportPoster>(find.byType(AnnualReportPoster))
              .monthStartDay,
          10);
      await t.pump(const Duration(milliseconds: 600));
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump();
      expect(t.takeException(), isNull);
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 3));
      container.dispose();
    }
  });
}
