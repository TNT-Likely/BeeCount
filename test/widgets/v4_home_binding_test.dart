import 'dart:convert';
import 'dart:io';
import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/budget_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/presentation/v4/bindings/home_journal.dart';
import 'package:beecount/presentation/v4/bindings/home_overview.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/providers/budget_providers.dart';
import 'package:beecount/widgets/biz/bee_icon.dart';
import 'package:beecount/widgets/ui/primary_header.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;
  final events = <String>[];
  final contract = jsonDecode(
          File('test/fixtures/v4-home-design-geometry.json').readAsStringSync())
      as Map<String, dynamic>;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    events.clear();
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'日常生活','CNY')");
    await repo.addTransaction(
        ledgerId: 1,
        type: 'income',
        amount: 12000,
        happenedAt: DateTime(2026, 10, 20));
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 3286.5,
        happenedAt: DateTime(2026, 10, 20));
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      currentLedgerProvider.overrideWith((ref) => repo.watchLedger(1)),
      selectedMonthProvider.overrideWith((ref) => DateTime(2026, 10)),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
      budgetOverviewProvider.overrideWith((ref) async => BudgetOverview(
          totalBudget: BudgetUsage(used: 3286.5, budget: 5000),
          categoryBudgets: const [],
          daysRemaining: 10,
          dailyAvailable: 171.35)),
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> open(WidgetTester tester,
      {Size size = const Size(398, 844),
      double scale = 1,
      bool brandControl = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 37, bottom: 24),
                    textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                body: Container(
                    decoration: BoxDecoration(border: Border.all()),
                    child: Column(children: [
                      PrimaryHeader(
                          title: '',
                          showTitleSection: false,
                          padding: const EdgeInsets.fromLTRB(17, 6, 17, 8),
                          content: HomeOverview(
                              onLedgerTap: () => events.add('ledger'),
                              onMonthTap: () => events.add('month'),
                              actions: [
                                if (brandControl)
                                  Consumer(
                                      builder: (context, ref, _) => TextButton(
                                          onPressed: () => setHomeBrandVisible(
                                              ref,
                                              !ref.read(
                                                  homeBrandVisibleProvider)),
                                          child: const Text('切换品牌')))
                              ])),
                      Expanded(
                          child: HomeJournalFrame(
                              onCalendar: () => events.add('calendar'),
                              onFilter: () => events.add('filter'),
                              onBatch: () => events.add('batch'),
                              child: const SizedBox.expand())),
                    ]))))));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  testWidgets('首页真实汇总与 HTML 区域对齐，默认无品牌且入口独立', (tester) async {
    await open(tester);
    final identity = tester.getRect(find.byType(BeeHomeIdentity));
    final summary = tester.getRect(find.byType(BeeSummaryCard));
    final header = tester.getRect(find.byType(BeeTransactionStreamHeader));
    final expected = contract['boxes'] as Map<String, dynamic>;
    expect(identity.top, closeTo(expected['topbar']['y'] as num, 1));
    expect(identity.height, 64);
    expect(summary.left, expected['summary']['x']);
    expect(summary.top, closeTo(expected['summary']['y'] as num, 1));
    expect(summary.width, expected['summary']['width']);
    expect(summary.height, closeTo(expected['summary']['height'] as num, 1.5));
    expect(header.top, closeTo(expected['streamHeader']['y'] as num, 1.5));
    expect(find.byType(BeeIcon), findsNothing);
    expect(find.text('明细'), findsOneWidget);
    expect(find.text('2笔'), findsOneWidget);
    await tester.tap(find.text('日常生活'));
    await tester.tap(find.text('2026年 10月'));
    await tester.tap(find.bySemanticsLabel('日历'));
    await tester.tap(find.bySemanticsLabel('筛选'));
    await tester.tap(find.text('批量'));
    expect(events, ['ledger', 'month', 'calendar', 'filter', 'batch']);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('首页隐私同时隐藏月汇总与预算金额，保留笔数', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('隐藏金额'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3,286.5', findRichText: true), findsNothing);
    expect(find.textContaining('1,713.5'), findsNothing);
    expect(find.textContaining('5,000'), findsNothing);
    expect(find.text('2笔'), findsOneWidget);
    expect(container.read(hideAmountsProvider), isTrue);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  for (final scale in [1.0, 1.4]) {
    testWidgets('首页小屏与大字体布局无溢出 $scale', (tester) async {
      await open(tester, size: const Size(320, 568), scale: scale);
      expect(find.byType(BeeTransactionStreamHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  }

  testWidgets('首页品牌选择写入偏好，重新读取后仍可切换', (tester) async {
    await open(tester, brandControl: true);
    expect(find.byType(BeeIcon), findsNothing);
    await tester.tap(find.text('切换品牌'));
    await tester.pumpAndSettle();
    expect(find.byType(BeeIcon), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('v4_home_show_brand'), isTrue);
    container.read(homeBrandVisibleProvider.notifier).state = false;
    container.invalidate(homeBrandPreferenceInitProvider);
    await tester.pumpAndSettle();
    expect(find.byType(BeeIcon), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
