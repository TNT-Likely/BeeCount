import 'dart:io';
import 'dart:ui' as ui;
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/pages/report/annual_report_page.dart';
import 'package:beecount/services/export/share_poster_data_service.dart';
import 'package:beecount/pages/report/annual/bindings/annual_poster_projection.dart';
import 'package:beecount/pages/shared/sharing/bindings/app_promo_poster.dart';
import 'package:beecount/pages/shared/sharing/bindings/ledger_summary_poster.dart';
import 'package:beecount/pages/shared/sharing/bindings/month_summary_poster.dart';
import 'package:beecount/pages/shared/sharing/bindings/transaction_receipt.dart';
import 'package:beecount/pages/shared/sharing/bindings/user_profile_poster.dart';
import 'package:beecount/pages/shared/sharing/bindings/year_summary_poster.dart';
import 'package:beecount_business_ui/annual_report.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_business_ui/card_refinements.dart';
import 'package:beecount_business_ui/support.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    // Optional private evidence font; CI does not depend on an OS font path.
    final font = Platform.environment['BEE_D_POSTER_FONT'];
    if (font != null) {
      final loader = FontLoader('Roboto')
        ..addFont(File(font)
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)));
      await loader.load();
    }
  });
  testWidgets(
      'D seven poster layouts use unchanged SQLite projections and original USD receipt',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory()),
        repo = LocalRepository(db);
    addTearDown(db.close);
    final ledger = await t.runAsync(
        () => repo.createLedger(name: '小满和家人的日常生活与旅行记录', currency: 'CNY'));
    final foreign = await t.runAsync(() =>
        repo.createAccount(ledgerId: ledger!, name: '美元旅行账户', currency: 'USD'));
    final account = await t
        .runAsync(() => repo.createAccount(ledgerId: ledger!, name: '现金账户'));
    final destination = await t
        .runAsync(() => repo.createAccount(ledgerId: ledger!, name: '旅行备用金'));
    final category = await t.runAsync(
        () => repo.createCategory(name: '饮品 / 与家人一起喝咖啡', kind: 'expense'));
    final salary =
        await t.runAsync(() => repo.createCategory(name: '工资', kind: 'income'));
    final tag = await t.runAsync(() => repo.createTag(name: '和家人一起'));
    final expense = await t.runAsync(() => repo.addTransaction(
        ledgerId: ledger!,
        type: 'expense',
        amount: 12,
        currencyCode: 'USD',
        nativeAmount: 85.2,
        accountId: foreign,
        categoryId: category,
        happenedAt: DateTime(2026, 10, 20, 12, 34),
        note: '一杯拿铁，记下普通的一天。'));
    await t.runAsync(() =>
        repo.updateTransactionTags(transactionId: expense!, tagIds: [tag!]));
    await t.runAsync(() => repo.addTransaction(
        ledgerId: ledger!,
        type: 'income',
        amount: 1200,
        accountId: account,
        categoryId: salary,
        happenedAt: DateTime(2026, 10, 21, 10)));
    await t.runAsync(() => repo.addTransaction(
        ledgerId: ledger!,
        type: 'transfer',
        amount: 100,
        accountId: account,
        toAccountId: destination,
        happenedAt: DateTime(2026, 10, 22, 10)));
    final service =
        SharePosterDataService(repo, clock: () => DateTime(2026, 10, 25));
    final year = (await t.runAsync(
        () => service.calculateYearSummary(ledgerId: ledger!, year: 2026)))!;
    final month = (await t.runAsync(() => service.calculateMonthSummary(
        ledgerId: ledger!, year: 2026, month: 10)))!;
    final book = (await t
        .runAsync(() => service.calculateLedgerSummary(ledgerId: ledger!)))!;
    final profile = (await t
        .runAsync(() => service.calculateUserProfile(ledgerId: ledger!)))!;
    final tx = (await t.runAsync(() => repo.getTransactionById(expense!)))!;
    final currentLedger =
        (await t.runAsync(() => repo.getLedgerById(ledger!)))!;
    final tags =
        (await t.runAsync(() => repo.getTagsForTransaction(expense!)))!;
    final before = (await t.runAsync(() => db.select(db.transactions).get()))!
        .map((x) => x.toJson())
        .toList();
    expect(year.totalExpense, closeTo(85.2, .001));
    expect(month.totalIncome, 1200);
    expect(year.recordCount, 3);
    expect(book.balance, closeTo(1114.8, .001));
    final l = AppLocalizationsZh(), key = GlobalKey();
    final annual = AnnualReportData(
        year: 2026,
        currencyCode: 'CNY',
        totalDays: year.recordDays,
        totalRecords: year.recordCount,
        totalIncome: year.totalIncome,
        totalExpense: year.totalExpense,
        netSavings: year.balance,
        topExpenseCategories: year.topExpenseCategories,
        monthlyData: List.generate(
            12,
            (i) => (
                  month: i + 1,
                  income: i == 9 ? year.totalIncome : 0.0,
                  expense: i == 9 ? year.totalExpense : 0.0
                )),
        largestExpense: tx,
        firstRecord: tx,
        maxConsecutiveDays: 3);
    final layouts = <String, Widget>{
      'profile': UserProfilePoster(
          data: profile, l10n: l, primaryColor: const Color(0xfffacb16)),
      'app': AppPromoPoster(l10n: l, primaryColor: const Color(0xfffacb16)),
      'month': MonthSummaryPoster(
          data: month, primaryColor: const Color(0xfffacb16)),
      'year': YearSummaryPoster(
          data: year, primaryColor: const Color(0xfffacb16), hideIncome: true),
      'ledger': LedgerSummaryPoster(
          data: book, primaryColor: const Color(0xfffacb16)),
      'annual': AnnualReportPoster(
          data: annual,
          primaryColor: const Color(0xfffacb16),
          now: DateTime(2026, 10, 25)),
      'receipt': TransactionReceipt(
          data: TransactionReceiptData(
              transaction: tx,
              ledger: currentLedger,
              category: await t
                  .runAsync<Category?>(() => repo.getCategoryById(category!)),
              tags: tags))
    };
    t.view.physicalSize = const Size(750, 1500);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final entry in layouts.entries) {
      await t.pumpWidget(MaterialApp(
          locale: const Locale('zh'),
          theme: beeTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Align(
                      alignment: Alignment.topCenter,
                      child: RepaintBoundary(
                          key: key,
                          child: SizedBox(
                              width: entry.key == 'receipt' ? 320 : 750,
                              child: entry.value)))))));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: entry.key);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      expect(boundary.size.width, entry.key == 'receipt' ? 320 : 750);
      if (['profile', 'app', 'month', 'year', 'ledger'].contains(entry.key)) {
        expect(boundary.size.height, 1334);
      }
      if (entry.key == 'receipt') {
        expect(find.text('−\$12.00'), findsOneWidget);
        expect(find.text('USD'), findsOneWidget);
        expect(find.text('85.20'), findsNothing);
        expect(find.text('#和家人一起'), findsOneWidget);
      }
      final folder = Platform.environment['BEE_D_POSTER_EVIDENCE'];
      if (folder != null) {
        await t.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(folder).create(recursive: true);
          await File('$folder/${entry.key}.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    final after = (await t.runAsync(() => db.select(db.transactions).get()))!
        .map((x) => x.toJson())
        .toList();
    expect(after, before);
    expect(
        (await t.runAsync(() => repo.getTagsForTransaction(expense!)))!
            .single
            .id,
        tag);
  });

  for (final dark in [false, true]) {
    testWidgets('D application card family fits 320 at 140 percent; dark=$dark',
        (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final l = AppLocalizationsZh(), key = GlobalKey();
      var recommended = false;
      await t.pumpWidget(MaterialApp(
          theme:
              beeTheme(brightness: dark ? Brightness.dark : Brightness.light),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.4)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: RepaintBoundary(
                      key: key,
                      child: ColoredBox(
                          color: BeeCardTheme.fromBrightness(
                                  dark ? Brightness.dark : Brightness.light)
                              .canvas,
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    BeeAnnualOverview(
                                        year: '2026',
                                        title: '年度总览',
                                        subtitle: '日常生活 · CNY',
                                        expenseLabel: '这一年的总支出',
                                        expense: '¥32,414.75',
                                        incomeLabel: '收入',
                                        income: '¥120,000.00',
                                        savingsLabel: '结余',
                                        savings: '¥87,585.25',
                                        facts: const [
                                          (label: '记录天数', value: '268 天'),
                                          (label: '记账笔数', value: '1,268 笔')
                                        ]),
                                    const SizedBox(height: 14),
                                    const BeeBudgetOverview(
                                        title: '10 月预算',
                                        amount: '¥5,000.00',
                                        totalLabel: '总预算',
                                        usedLabel: '已支出',
                                        used: '¥3,286.50',
                                        remainingLabel: '剩余预算',
                                        remaining: '¥1,713.50',
                                        daysLabel: '剩余 11 天',
                                        dailyLabel: '日均可用 ¥155.77',
                                        progress: .6573,
                                        progressLabel: '65.7%',
                                        tone: BeeBudgetTone.normal,
                                        editLabel: '编辑'),
                                    const SizedBox(height: 14),
                                    const BeeSurface(
                                        child: BeeSyncHealthHeader(
                                            title: '云端与同步',
                                            status: '本地数据与云端保持一致')),
                                    const SizedBox(height: 14),
                                    BeeSupportBrand(
                                        logo: const Icon(Icons.flutter_dash),
                                        title: '蜜蜂记账',
                                        version: '4.0.0-preview',
                                        onStory: () {},
                                        socials: const [],
                                        description:
                                            l.v4SharePosterOpenSourceBody,
                                        tag: '开源 · 免费',
                                        sourceLabel:
                                            l.v4SharePosterOpenSourceAction,
                                        onSource: () {},
                                        recommendLabel:
                                            l.v4SharePosterRecommend,
                                        onRecommend: () => recommended = true),
                                  ]))))))));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.text(l.v4SharePosterRecommend));
      await t.tap(find.text(l.v4SharePosterRecommend));
      expect(recommended, isTrue);
      await t.pumpAndSettle();
      final folder = Platform.environment['BEE_D_POSTER_EVIDENCE'];
      if (folder != null) {
        await t.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(folder).create(recursive: true);
          await File('$folder/cards-${dark ? 'dark' : 'light'}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
