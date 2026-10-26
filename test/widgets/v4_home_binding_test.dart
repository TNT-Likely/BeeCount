import 'dart:ui' show SemanticsFlag;
import 'package:beecount/widgets/biz/transaction_list.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:beecount/pages/main/home_page.dart';
import 'package:beecount/widgets/biz/transaction_list_item.dart';
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
      currentLedgerProvider.overrideWith(
          (ref) => repo.watchLedger(ref.watch(currentLedgerIdProvider))),
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

  for (final width in [320.0, 398.0]) {
    testWidgets('首页分类图标与星期表头共用左边界 $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final interval = VisibilityDetectorController.instance.updateInterval;
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      addTearDown(() =>
          VisibilityDetectorController.instance.updateInterval = interval);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              theme: beeTheme(),
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const HomePage())));
      await tester.pumpAndSettle();
      for (var i = 0;
          i < 40 &&
              find
                  .byType(BeeTransactionRow, skipOffstage: false)
                  .evaluate()
                  .isEmpty;
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final header =
          find.byType(BeeTransactionDayHeader, skipOffstage: false).first;
      final title = tester.widget<BeeTransactionDayHeader>(header).title;
      final titleBox = tester.getRect(find.descendant(
          of: header, matching: find.text(title, skipOffstage: false)));
      final row = tester.widget<BeeTransactionRow>(
          find.byType(BeeTransactionRow, skipOffstage: false).first);
      final icon = tester.getRect(find.byWidget(row.icon, skipOffstage: false));
      // A 34px icon is centered in its unchanged 36px category tap target.
      expect(icon.left, closeTo(titleBox.left + 1, .1));
      expect(icon.width, 34);
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  }

  testWidgets('首页真实汇总与 HTML 区域对齐，默认显示品牌且入口独立', (tester) async {
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
    expect(find.byType(BeeIcon), findsOneWidget);
    expect(find.text('蜜蜂记账'), findsOneWidget);
    expect(find.text('2笔'), findsOneWidget);
    expect(find.text('12,000.00'), findsOneWidget);
    expect(find.textContaining('5,000.00'), findsOneWidget);
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
    expect(find.byType(BeeIcon), findsOneWidget);
    await tester.tap(find.text('切换品牌'));
    await tester.pumpAndSettle();
    expect(find.byType(BeeIcon), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('v4_home_show_brand'), isFalse);
    container.read(homeBrandVisibleProvider.notifier).state = true;
    container.invalidate(homeBrandPreferenceInitProvider);
    await tester.pumpAndSettle();
    expect(find.byType(BeeIcon), findsNothing);
    await tester.tap(find.text('切换品牌'));
    await tester.pumpAndSettle();
    expect(prefs.getBool('v4_home_show_brand'), isTrue);
    expect(find.byType(BeeIcon), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('首页真实列表收到空流时不回退到旧启动缓存', (tester) async {
    tester.view.physicalSize = const Size(398, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final interval = VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(
        () => VisibilityDetectorController.instance.updateInterval = interval);
    final recent =
        await repo.getRecentTransactionsWithCategory(ledgerId: 1, limit: 20);
    expect(recent, hasLength(2));
    container.read(cachedTransactionsProvider.notifier).state = recent
        .map((row) => (
              t: row.t,
              category: row.category,
              account: row.account,
              toAccount: row.toAccount,
              tags: <Tag>[],
              attachmentCount: 0,
              accountName: row.account?.name,
              toAccountName: row.toAccount?.name,
            ))
        .toList();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomePage())));
    await tester.pumpAndSettle();
    for (var i = 0;
        i < 20 &&
            find
                    .byType(TransactionListItem, skipOffstage: false)
                    .evaluate()
                    .length !=
                2;
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    // 该自定义 sliver 未实现 debugVisitOnstageChildren，显式遍历并核对绘制位置。
    expect(find.byType(TransactionListItem, skipOffstage: false),
        findsNWidgets(2));
    final viewport = tester.getRect(find.byType(TransactionList));
    for (final row
        in find.byType(TransactionListItem, skipOffstage: false).evaluate()) {
      expect(
          tester
              .getRect(find.byWidget(row.widget, skipOffstage: false))
              .overlaps(viewport),
          isTrue);
    }
    for (final row in recent) {
      await repo.deleteTransaction(row.t.id);
    }
    await tester.pumpAndSettle();
    for (var i = 0;
        i < 20 &&
            find
                .byType(TransactionListItem, skipOffstage: false)
                .evaluate()
                .isNotEmpty;
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byType(TransactionListItem, skipOffstage: false), findsNothing);
    final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
    expect(find.text(l10n.homeNoRecords), findsOneWidget);
    // 启动缓存有意保留为旧值，验证真实空流的优先级而非清缓存掩盖问题。
    expect(container.read(cachedTransactionsProvider), hasLength(2));
    expect((await repo.getCountsForLedger(ledgerId: 1)).txCount, 0);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('首页键盘压缩后恢复仍复用列表订阅并显示新账单', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(398, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final interval = VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(
        () => VisibilityDetectorController.instance.updateInterval = interval);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomePage())));
    await tester.pumpAndSettle();
    final listState = tester.state<TransactionListState>(
        find.byType(TransactionList, skipOffstage: false));
    // A note keyboard can reduce the covered Home route below the compact
    // layout boundary. Returning from the editor restores the full height.
    for (final height in [568.0, 900.0, 568.0, 900.0]) {
      tester.view.physicalSize = Size(398, height);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
          tester.state<TransactionListState>(
              find.byType(TransactionList, skipOffstage: false)),
          same(listState));
    }
    final id = await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 32.5,
        happenedAt: DateTime(2026, 10, 25),
        note: '键盘返回后真实新增');
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 20));
      final list = tester.widget<TransactionList>(
          find.byType(TransactionList, skipOffstage: false));
      if (list.transactions!.any((row) => row.t.id == id)) break;
    }
    final list = tester.widget<TransactionList>(
        find.byType(TransactionList, skipOffstage: false));
    expect(list.transactions!.map((row) => row.t.id), contains(id));
    expect(list.transactions, hasLength(3));
    expect((await repo.getTransactionById(id))!.amount, 32.5);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  for (final small in [false, true]) {
    testWidgets('首页更多菜单与品牌偏好完整可达，${small ? '320深色大字' : '标准屏'}', (tester) async {
      tester.view.physicalSize =
          small ? const Size(320, 568) : const Size(398, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final interval = VisibilityDetectorController.instance.updateInterval;
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
                theme: beeTheme(
                    brightness: small ? Brightness.dark : Brightness.light),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(small ? 1.4 : 1)),
                    child: child!),
                locale: const Locale('zh'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const Scaffold(
                    body: HomePage(),
                    bottomNavigationBar: SizedBox(height: 76)))));
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(tester.element(find.byType(HomePage)));
        final menu = find.byType(BeeMenuButton<String>);
        expect(menu, findsOneWidget);
        expect(
            tester.getSemantics(menu).hasFlag(SemanticsFlag.isButton), isTrue);
        expect(
            tester.getSemantics(menu).hasFlag(SemanticsFlag.isImage), isFalse);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        for (final title in [
          l.calendarTitle,
          l.v4HomeMonthShare,
          l.annualReportTitle,
          l.homeManageLedgers,
          l.v4HomeBrandHide
        ]) {
          expect(find.text(title), findsOneWidget);
        }
        await tester.tap(find.text(l.v4HomeBrandHide));
        await tester.pumpAndSettle();
        expect(
            (await SharedPreferences.getInstance())
                .getBool('v4_home_show_brand'),
            isFalse);
        expect(
            tester
                .widget<BeeHomeIdentity>(find.byType(BeeHomeIdentity))
                .showBrand,
            isFalse);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.v4HomeBrandShow));
        await tester.pumpAndSettle();
        expect(
            (await SharedPreferences.getInstance())
                .getBool('v4_home_show_brand'),
            isTrue);
        if (small) {
          final layout =
              tester.widget<BeeHomeLayout>(find.byType(BeeHomeLayout));
          expect(layout.controller!.hasClients, isTrue);
          await tester.drag(find.byType(BeeHomeLayout), const Offset(0, -350));
          await tester.pumpAndSettle();
          expect(layout.controller!.offset, greaterThan(0));
          container.read(homeScrollToTopProvider.notifier).state++;
          await tester.pumpAndSettle();
          expect(layout.controller!.offset, 0);
        }
        expect((await repo.getCountsForLedger(ledgerId: 1)).txCount, 2);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        await close(tester);
        VisibilityDetectorController.instance.updateInterval = interval;
      }
    });
  }
  for (final small in [false, true]) {
    testWidgets('首页账本弹窗真实列表、当前状态、搜索与选择保持原数据 ${small ? '小屏键盘大字' : '标准屏'}',
        (tester) async {
      tester.view.physicalSize =
          small ? const Size(320, 568) : const Size(398, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await db.customStatement(
          "INSERT INTO ledgers(id,name,currency) VALUES(2,'旅行','USD')");
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(small ? 1.4 : 1),
                      viewInsets: EdgeInsets.only(bottom: small ? 180 : 0)),
                  child: child!),
              theme: beeTheme(),
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const HomePage())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('日常生活').first);
      await tester.pumpAndSettle();
      final picker =
          tester.widget<BeeLedgerPicker>(find.byType(BeeLedgerPicker));
      expect(picker.currentId, '1');
      expect(picker.ledgers.map((l) => l.name), ['日常生活', '旅行']);
      expect(picker.ledgers.first.detail, '2笔');
      await tester.enterText(
          find.descendant(
              of: find.byType(BeeSearchField),
              matching: find.byType(TextField)),
          '旅行');
      await tester.pumpAndSettle();
      expect(find.text('日常生活'), findsOneWidget); // underlying home identity
      await tester.ensureVisible(find.widgetWithText(BeeMenuRow, '旅行'));
      await tester.tap(find.widgetWithText(BeeMenuRow, '旅行'));
      await tester.pumpAndSettle();
      expect(find.byType(BeeLedgerPicker), findsNothing);
      expect(container.read(currentLedgerIdProvider), 2);
      expect((await repo.getCountsForLedger(ledgerId: 1)).txCount, 2);
      expect((await repo.getCountsForLedger(ledgerId: 2)).txCount, 0);
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  }
}
