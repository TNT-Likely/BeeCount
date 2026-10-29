import 'dart:async';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/report/annual_report_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/pages/report/annual/widgets/annual_report_sections.dart';
import 'package:beecount_business_ui/annual_report.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Widget host(Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child);
void main() {
  setUpAll(() => initializeDateFormatting());
  test(
      'provider preserves custom annual period, ledger isolation and native comparison',
      () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    final repo = LocalRepository(db);
    final a = await repo.createLedger(name: 'QA Taiwan', currency: 'TWD');
    final b = await repo.createLedger(name: 'QA Japan', currency: 'JPY');
    await repo.updateLedger(id: a, monthStartDay: 10);
    await repo.addTransaction(
        ledgerId: a,
        type: 'expense',
        amount: 999,
        happenedAt: DateTime(2025, 1, 9));
    final converted = await repo.addTransaction(
        ledgerId: a,
        type: 'expense',
        amount: 5,
        currencyCode: 'USD',
        nativeAmount: 150,
        happenedAt: DateTime(2025, 1, 10));
    await repo.addTransaction(
        ledgerId: a,
        type: 'expense',
        amount: 1000,
        currencyCode: 'JPY',
        nativeAmount: 20,
        happenedAt: DateTime(2026, 1, 9));
    await repo.addTransaction(
        ledgerId: a,
        type: 'expense',
        amount: 999,
        happenedAt: DateTime(2026, 1, 10));
    await repo.addTransaction(
        ledgerId: b,
        type: 'expense',
        amount: 5000,
        happenedAt: DateTime(2025, 1, 11));
    final c = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => a)
    ]);
    try {
      final report = (await c.read(annualReportDataProvider(2025).future))!;
      expect(report.currencyCode, 'TWD');
      expect(report.totalRecords, 2);
      expect(report.totalExpense, 170);
      expect(report.largestExpense!.id, converted);
      expect(report.largestExpense!.currencyCode, 'USD');
      expect(report.monthlyData.first.expense, 150);
      expect(report.monthlyData.last.expense, 20);
      c.read(currentLedgerIdProvider.notifier).state = b;
      final other = (await c.read(annualReportDataProvider(2025).future))!;
      expect(other.currencyCode, 'JPY');
      expect(other.totalExpense, 5000);
      expect(other.totalRecords, 1);
    } finally {
      c.dispose();
      await db.close();
    }
  });
  testWidgets(
      'old initial year, empty result and loading retain accessible controls',
      (tester) async {
    final completer = Completer<AnnualReportData?>();
    await tester.pumpWidget(ProviderScope(overrides: [
      annualReportDataProvider(2010).overrideWith((ref) => completer.future)
    ], child: host(const AnnualReportPage(initialYear: 2010))));
    await tester.pump();
    expect(find.byKey(const ValueKey('annual-close')), findsOneWidget);
    expect(find.text('2010'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('No data for 2010'), findsOneWidget);
    expect(find.byKey(const ValueKey('annual-generate-poster')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('failed report can retry without replacing page', (tester) async {
    int calls = 0;
    await tester.pumpWidget(ProviderScope(overrides: [
      annualReportDataProvider(2025).overrideWith((ref) async {
        calls++;
        if (calls == 1) throw StateError('QA synthetic failure');
        return null;
      })
    ], child: host(const AnnualReportPage(initialYear: 2025))));
    await tester.pumpAndSettle();
    expect(find.textContaining('QA synthetic failure'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('No data for 2025'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('all chapters remain readable at 320px and 1.4 text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const data = AnnualReportData(
        year: 2025,
        currencyCode: 'TWD',
        totalDays: 123,
        totalRecords: 345,
        totalIncome: 12345678.9,
        totalExpense: 999999.1,
        netSavings: 11345679.8,
        topExpenseCategories: [],
        monthlyData: [(month: 1, income: 12345678.9, expense: 999999.1)]);
    for (var i = 0; i < 7; i++) {
      await tester.pumpWidget(host(Builder(
          builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.4)),
              child: Scaffold(
                  backgroundColor: BeeCardTheme.of(context).canvas,
                  body: annualReportSections(context, data,
                      monthStartDay: 10, now: DateTime(2026, 1, 10))[i])))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'chapter $i');
    }
  });
  testWidgets(
      'twelve-month trend adapts to narrow columns at system text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final scale in [1.4, 2.0]) {
      await tester.pumpWidget(host(Builder(
          builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                    body: Padding(
                        padding: const EdgeInsets.all(32),
                        child: BeeAnnualTrend(
                            points: List.generate(
                                12,
                                (i) => BeeAnnualTrendPoint(
                                    label: '${i + 1}',
                                    amount: 'TWD 100',
                                    fraction: 1))))),
              ))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final scroll = find.byType(SingleChildScrollView);
      expect(scroll, findsOneWidget);
      await tester.drag(scroll, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('12')).right,
          lessThanOrEqualTo(tester.getRect(scroll).right));
      expect(MediaQuery.textScalerOf(tester.element(find.text('12'))).scale(11),
          11 * scale);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('cancelling generation never pops the annual report underneath',
      (tester) async {
    const data = AnnualReportData(
        year: 2025,
        totalDays: 1,
        totalRecords: 1,
        totalIncome: 20,
        totalExpense: 10,
        netSavings: 10,
        topExpenseCategories: [],
        monthlyData: [(month: 1, income: 20.0, expense: 10.0)]);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          annualReportDataProvider(2025).overrideWith((ref) async => data),
          currentMonthStartDayProvider.overrideWithValue(1),
        ],
        child: host(Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              const AnnualReportPage(initialYear: 2025))),
                  child: const Text('Open report'),
                ))))));
    await tester.tap(find.text('Open report'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('annual-generate-poster')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
      final button = tester.widget<BeeButton>(
          find.byKey(const ValueKey('annual-generate-poster')));
      if (button.onPressed != null) break;
    }
    expect(find.byType(AnnualReportPage), findsOneWidget);
    expect(find.byType(BeeAnnualPosterPreview), findsNothing);
    expect(
        tester
            .widget<BeeButton>(
                find.byKey(const ValueKey('annual-generate-poster')))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('poster privacy and native action callbacks obey busy state',
      (tester) async {
    var privacy = 0, save = 0, share = 0, close = 0;
    Widget preview(bool busy) => host(BeeAnnualPosterPreview(
        title: 'QA annual',
        closeLabel: 'Close',
        privacyLabel: 'Hide income',
        saveLabel: 'Save',
        shareLabel: 'Share',
        preview: const SizedBox(width: 120, height: 180),
        onPrivacy: () => privacy++,
        onSave: () => save++,
        onShare: () => share++,
        onClose: () => close++,
        busy: busy));
    await tester.pumpWidget(preview(false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('annual-poster-privacy')));
    await tester.tap(find.byKey(const ValueKey('annual-poster-save')));
    await tester.tap(find.byKey(const ValueKey('annual-poster-share')));
    expect([privacy, save, share], [1, 1, 1]);
    await tester.pumpWidget(preview(true));
    await tester.pump();
    for (final id in ['privacy', 'save', 'share']) {
      final finder = find.byKey(ValueKey('annual-poster-$id'));
      expect(
          id == 'privacy'
              ? tester.widget<ButtonStyleButton>(finder).onPressed
              : tester.widget<BeeButton>(finder).onPressed,
          isNull);
    }
    expect(close, 0);
    expect(tester.takeException(), isNull);
  });
}
