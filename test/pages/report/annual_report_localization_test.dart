import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/report/annual_report_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/export/share_poster_types.dart';
import 'package:beecount/widgets/posters/annual_report_poster.dart';

const reportYear = 2025;

AnnualReportData reportData(String currency) => AnnualReportData(
      year: reportYear,
      currencyCode: currency,
      totalDays: 10,
      totalRecords: 20,
      totalIncome: 5000,
      totalExpense: 3000,
      netSavings: 2000,
      maxConsecutiveDays: 5,
      topExpenseCategories: [
        CategoryTotal(id: 1, name: 'Food', total: 3000, percentage: 1),
      ],
      monthlyData: List.generate(
        12,
        (i) => (
          month: i + 1,
          income: i == 0 ? 5000.0 : 0.0,
          expense: i == 0 ? 3000.0 : 0.0
        ),
      ),
      largestExpense: Transaction(
        id: 1,
        ledgerId: 1,
        type: 'expense',
        amount: 100,
        currencyCode: 'USD',
        nativeAmount: 3000,
        happenedAt: DateTime(reportYear, 1, 1),
        excludeFromStats: false,
        excludeFromBudget: false,
      ),
    );

Widget host(Widget child, Locale locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

Future<void> nextPage(WidgetTester tester) async {
  final pageView = tester.widget<PageView>(find.byType(PageView));
  pageView.controller!.nextPage(
    duration: const Duration(milliseconds: 100),
    curve: Curves.linear,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => initializeDateFormatting());

  test('report data uses the ledger currency rather than the primary currency',
      () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO ledgers (id, name, currency) VALUES (1, 'Taiwan', 'TWD')",
    );
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: 1,
          type: 'expense',
          amount: 3000,
          happenedAt: Value(DateTime(reportYear, 1, 1)),
        ));
    final container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(LocalRepository(db)),
    ]);
    addTearDown(container.dispose);

    final data =
        await container.read(annualReportDataProvider(reportYear).future);
    expect(data!.currencyCode, 'TWD');
    expect(data.totalExpense, 3000);
  });

  for (final locale in [const Locale('zh', 'TW'), const Locale('en')]) {
    testWidgets('report pages follow $locale and show TWD amounts',
        (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          annualReportDataProvider(reportYear)
              .overrideWith((ref) async => reportData('TWD')),
          currentMonthStartDayProvider.overrideWithValue(1),
        ],
        child: host(const AnnualReportPage(initialYear: reportYear), locale),
      ));
      await tester.pumpAndSettle();
      expect(find.text('NT\$3,000.00'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await nextPage(tester);
      final context = tester.element(find.byType(AnnualReportPage));
      final l10n = AppLocalizations.of(context);
      expect(find.text(l10n.annualReportInsightsTitle), findsOneWidget);
      expect(find.text(l10n.annualReportAveragePerRecord), findsOneWidget);
      expect(find.text(l10n.annualReportCategoryCountValue(1)), findsOneWidget);
      expect(find.text('NT\$150.00'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await nextPage(tester);
      expect(find.text(l10n.annualReportComparisonTitle), findsOneWidget);
      expect(find.text(l10n.annualReportComparisonSubtitle), findsOneWidget);
      expect(find.text('NT\$5,000'), findsOneWidget);
      expect(find.text(l10n.annualReportHighestIncome), findsOneWidget);
      expect(tester.takeException(), isNull);

      await nextPage(tester); // Categories
      expect(find.text('NT\$3,000.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await nextPage(tester); // Monthly trend
      expect(find.text('NT\$3,000'), findsWidgets);
      expect(tester.takeException(), isNull);
      await nextPage(tester); // Special moments retain the original currency.
      expect(find.text('\$100.00'), findsOneWidget);
      expect(find.textContaining('¥'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in [const Locale('zh', 'TW'), const Locale('en')]) {
    for (final currency in ['TWD', 'CNY']) {
      for (final hideIncome in [false, true]) {
        testWidgets(
            'poster follows $locale and uses $currency with hidden income = $hideIncome',
            (tester) async {
          tester.view.physicalSize = const Size(750, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(host(
            Scaffold(
              body: SingleChildScrollView(
                child: AnnualReportPoster(
                  data: reportData(currency),
                  primaryColor: Colors.orange,
                  hideIncome: hideIncome,
                ),
              ),
            ),
            locale,
          ));
          await tester.pumpAndSettle();
          final symbol = currency == 'TWD' ? 'NT\$' : '¥';
          expect(find.text('${symbol}3,000.00'), findsWidgets);
          expect(find.text('\$100.00'), findsOneWidget);
          final traditional = locale.languageCode == 'zh';
          expect(
              find.text(traditional
                  ? '從資料中發現你的消費習慣'
                  : 'Discover your spending habits through data'),
              findsOneWidget);
          expect(find.text(traditional ? '最活躍月份' : 'Most Active Month'),
              findsOneWidget);
          expect(find.text(traditional ? '1個' : '1 category'), findsOneWidget);
          if (hideIncome) {
            expect(find.text(traditional ? '記帳堅持' : 'Bookkeeping Streak'),
                findsOneWidget);
            expect(find.text(traditional ? '5天' : '5 days'), findsOneWidget);
          } else {
            expect(find.text('+${symbol}2,000.00'), findsOneWidget);
          }
          if (currency == 'TWD') {
            expect(find.textContaining('¥'), findsNothing);
            expect(find.textContaining('元'), findsNothing);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
