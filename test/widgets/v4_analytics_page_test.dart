import 'dart:async';
import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/main/analytics_page.dart';
import 'package:beecount/presentation/v4/bindings/analytics_content.dart';
import 'package:beecount/presentation/v4/bindings/analytics_data.dart';
import 'package:beecount/presentation/v4/bindings/analytics_ranking.dart';
import 'package:beecount/providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repo extends LocalRepository {
  _Repo(super.db);
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<int> countByTypeInRange(
      {required int ledgerId,
      required String type,
      required DateTime start,
      required DateTime end}) async {
    await gate?.future;
    if (fail) throw StateError('synthetic analytics unavailable');
    return super.countByTypeInRange(
        ledgerId: ledgerId, type: type, start: start, end: end);
  }
}

void main() {
  late BeeDatabase db;
  late _Repo repo;
  late ProviderContainer c;
  late int parent, child;
  final now = DateTime.now(),
      month = DateTime(DateTime.now().year, DateTime.now().month);
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _Repo(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'统计合成账本','CNY')");
    parent = await repo.createCategory(
        name: '统计餐饮', kind: 'expense', icon: 'restaurant');
    child = await repo.createCategory(
        name: '统计午餐',
        kind: 'expense',
        icon: 'restaurant',
        parentId: parent,
        level: 2);
    final at =
        DateTime(now.year, now.month, 1, 12).millisecondsSinceEpoch ~/ 1000;
    await db.customStatement(
        '''INSERT INTO transactions(ledger_id,type,amount,native_amount,currency_code,category_id,happened_at,note,exclude_from_stats,exclude_from_budget) VALUES
      (1,'expense',12,85.2,'USD',$child,$at,'原币快照',0,0),
      (1,'expense',30,NULL,'CNY',$child,${at + 3600},'不计收支',1,0),
      (1,'expense',10,NULL,'CNY',$parent,${at + 7200},'仅排除预算',0,1),
      (1,'income',12000,NULL,'CNY',NULL,${at + 10800},'收入',0,0),
      (1,'transfer',500,NULL,'CNY',NULL,${at + 14400},'转账',0,0)''');
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      selectedMonthProvider.overrideWith((ref) => month),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService())
    ]);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });
  Future<AnalyticsResult> load(String scope, String type,
          {DateTime? at, int sd = 1}) =>
      loadAnalyticsData(repo,
          ledgerId: 1,
          scope: scope,
          type: type,
          selMonth: at ?? month,
          startDay: sd,
          clock: now);
  Future<void> ready(WidgetTester t, Finder f) async {
    for (var i = 0; i < 80; i++) {
      await t.pump(const Duration(milliseconds: 30));
      if (f.evaluate().isNotEmpty) {
        await t.pump(const Duration(milliseconds: 200));
        return;
      }
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    expect(f, findsWidgets);
  }

  Future<void> open(WidgetTester t, {bool narrow = false}) async {
    t.view.physicalSize = narrow ? const Size(320, 568) : const Size(398, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            theme: beeTheme(
                brightness: narrow ? Brightness.dark : Brightness.light),
            locale: narrow ? const Locale('en') : const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(narrow ? 1.4 : 1)),
                child: child!),
            home: const AnalyticsPage())));
    await ready(t, find.byType(BeeAnalyticsSummary));
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 2));
  }

  test('真实仓库本币快照/排除规则/父子聚合不变', () async {
    final d = await load('month', 'expense');
    expect(d.total, closeTo(95.2, 1e-8));
    expect(d.count, 3);
    expect(d.categories, hasLength(1));
    expect(d.categories.single.id, parent);
    expect(d.categories.single.subCategories.single.id, child);
    expect(d.categories.single.subCategories.single.total, 85.2);
    expect(d.values.fold(0.0, (a, b) => a + b), closeTo(95.2, 1e-8));
    expect((await repo.getTransactionById(1))!.nativeAmount, 85.2);
  });
  for (final scope in ['month', 'year', 'all']) {
    test('$scope 收支/结余及平均数沿用真实序列', () async {
      final e = await load(scope, 'expense'),
          i = await load(scope, 'income'),
          b = await load(scope, 'balance');
      expect(e.total, closeTo(95.2, 1e-8));
      expect(i.total, 12000);
      expect(b.total, closeTo(11904.8, 1e-8));
      expect(b.count, 4);
      expect(b.empty, false);
      expect(b.values.fold(0.0, (a, b) => a + b), closeTo(11904.8, 1e-8));
      expect(e.average, e.total / e.values.length);
    });
  }
  test('空历史周期与自定义起始日边界保持', () async {
    expect((await load('month', 'expense', at: DateTime(2020, 2))).empty, true);
    final d = await load('month', 'expense', sd: 8);
    expect(d.start, DateTime(month.year, month.month, 8));
    expect(d.end,
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1)));
  });
  testWidgets('默认月支出/三视角Tab/结余收支构成且不写账单', (t) async {
    await open(t);
    final content = t.widget<AnalyticsContent>(find.byType(AnalyticsContent));
    expect(content.type, 'expense');
    expect(content.data.total, closeTo(95.2, 1e-8));
    await t.tap(find.text('结余'));
    await ready(t, find.byType(BeeAnalyticsSummary));
    final changed = t.widget<AnalyticsContent>(find.byType(AnalyticsContent));
    expect(changed.type, 'balance');
    expect(changed.data.total, closeTo(11904.8, 1e-8));
    expect(find.byType(AnalyticsRanking), findsNothing);
    expect(find.byType(BeeAnalyticsComposition), findsOneWidget);
    final composition =
        t.widget<BeeAnalyticsComposition>(find.byType(BeeAnalyticsComposition));
    expect(composition.income, '¥12,000');
    expect(composition.expense, '¥95.2');
    expect((await db.select(db.transactions).get()).length, 5);
    await close(t);
  });
  testWidgets('月年全部切换、原年月滚轮取消与不允许未来', (t) async {
    await open(t);
    await t.tap(find.text('年'));
    await ready(t, find.byType(BeeAnalyticsSummary));
    expect(t.widget<AnalyticsContent>(find.byType(AnalyticsContent)).scope,
        'year');
    await t.tap(find.widgetWithText(TextButton, '${now.year}年'));
    await t.pumpAndSettle();
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();
    expect(c.read(selectedMonthProvider), month);
    await t.tap(find.text('全部'));
    await ready(t, find.byType(BeeAnalyticsSummary));
    expect(
        t
            .widget<BeeAnalyticsSummary>(find.byType(BeeAnalyticsSummary))
            .onPeriod,
        isNull);
    await close(t);
  });
  testWidgets('占比与排行独立卡片且二级展开保留', (t) async {
    await open(t);
    await t.scrollUntilVisible(
        find.byKey(ValueKey('analytics-category-expand-$parent')), 250,
        scrollable: find.byType(Scrollable).last);
    await t.tap(find.byKey(ValueKey('analytics-category-expand-$parent')));
    await t.pump();
    expect(find.text('统计午餐'), findsOneWidget);
    expect(
        t
            .widget<BeeAnalyticsRankingList>(
                find.byType(BeeAnalyticsRankingList))
            .items
            .single
            .children
            .single
            .description,
        '89.5%');
    expect(find.byType(BeeAnalyticsProportion), findsOneWidget);
    expect(find.byType(BeeAnalyticsRankingList), findsOneWidget);
    final chart =
        t.widget<BeeAnalyticsProportion>(find.byType(BeeAnalyticsProportion));
    expect(chart.items.single.fraction, 1);
    expect(chart.items.single.valueLabel, '100.0%');
    expect(chart.selected, 0);
    await close(t);
  });
  testWidgets('原始读取失败可重试不改金融数据', (t) async {
    repo.fail = true;
    t.view.physicalSize = const Size(398, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AnalyticsPage())));
    await ready(t, find.text('重试'));
    repo.fail = false;
    await t.tap(find.text('重试'));
    await ready(t, find.byType(BeeAnalyticsSummary));
    expect((await db.select(db.transactions).get()).length, 5);
    await close(t);
  });
  testWidgets('空周期仍保留年月与视角入口及补折算取消不写入', (t) async {
    final at =
        DateTime(now.year, now.month, 1, 17).millisecondsSinceEpoch ~/ 1000;
    await db.customStatement(
        "INSERT INTO transactions(ledger_id,type,amount,native_amount,currency_code,happened_at,note) VALUES(1,'expense',7,7,'USD',$at,'未折算合成数据')");
    await open(t);
    await ready(t, find.text('补折算'));
    final before =
        await db.customSelect('SELECT * FROM transactions ORDER BY id').get();
    await t.tap(find.text('补折算'));
    await ready(t, find.byType(BeeDialog));
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();
    expect(
        (await db.customSelect('SELECT * FROM transactions ORDER BY id').get())
            .map((e) => e.data)
            .toList(),
        before.map((e) => e.data).toList());
    c.read(selectedMonthProvider.notifier).state = DateTime(2020, 2);
    await ready(t, find.text('暂无数据'));
    expect(
        t
            .widget<BeeAnalyticsSummary>(find.byType(BeeAnalyticsSummary))
            .onPeriod,
        isNotNull);
    await t.tap(find.text('收入'));
    await t.pumpAndSettle();
    expect(t.widget<AnalyticsContent>(find.byType(AnalyticsContent)).type,
        'income');
    await t.tap(find.text('切换到结余'));
    await ready(t, find.byType(BeeAnalyticsSummary));
    expect(t.widget<AnalyticsContent>(find.byType(AnalyticsContent)).type,
        'balance');
    await close(t);
  });
  testWidgets('横滑不改变视角或周期，均线与三项Tab保护原数据', (t) async {
    final before =
        (await db.customSelect('SELECT * FROM transactions ORDER BY id').get())
            .map((e) => e.data)
            .toList();
    await open(t);
    final original = c.read(selectedMonthProvider);
    await t.drag(find.byType(BeeColumnChart), const Offset(-220, 0));
    await t.pump();
    expect(t.widget<AnalyticsContent>(find.byType(AnalyticsContent)).type,
        'expense');
    expect(c.read(selectedMonthProvider), original);
    final column = t.widget<BeeColumnChart>(find.byType(BeeColumnChart));
    final loaded =
        t.widget<AnalyticsContent>(find.byType(AnalyticsContent)).data;
    expect(column.average, loaded.average);
    expect(column.average,
        loaded.values.reduce((a, b) => a + b) / loaded.values.length);
    await t.tap(find.byKey(const ValueKey('column-average-label')));
    await ready(t, find.byType(BeeDialog));
    await t.tap(find.text('知道了'));
    await t.pumpAndSettle();
    await t.tap(find.text('收入'));
    await ready(t, find.byType(BeeAnalyticsSummary));
    expect(t.widget<AnalyticsContent>(find.byType(AnalyticsContent)).data.total,
        12000);
    await t.tap(find.text('结余'));
    await ready(t, find.byType(BeeAnalyticsComposition));
    final balance =
        t.widget<AnalyticsContent>(find.byType(AnalyticsContent)).data;
    expect(balance.incomeTotal - balance.expenseTotal, balance.total);
    expect(
        (await db.customSelect('SELECT * FROM transactions ORDER BY id').get())
            .map((e) => e.data)
            .toList(),
        before);
    await close(t);
  });
  testWidgets('隐藏金额覆盖均线、点柱与占比文本，不泄露真实金额', (t) async {
    c.read(hideAmountsProvider.notifier).state = true;
    await open(t);
    expect(
        t.widget<BeeAnalyticsSummary>(find.byType(BeeAnalyticsSummary)).total,
        '****');
    expect(t.widget<BeeColumnChart>(find.byType(BeeColumnChart)).averageLabel,
        contains('****'));
    expect(
        t
            .widget<BeeColumnChart>(find.byType(BeeColumnChart))
            .valueLabels
            .every((s) => s == '****'),
        true);
    expect(
        t
            .widget<BeeAnalyticsProportion>(find.byType(BeeAnalyticsProportion))
            .items
            .every((s) => s.valueLabel == '****'),
        true);
    await t.tap(find.byKey(const ValueKey('column-average-label')));
    await ready(t, find.byType(BeeDialog));
    expect(find.textContaining('95.2', findRichText: true), findsNothing);
    expect(find.textContaining('12,000', findRichText: true), findsNothing);
    await close(t);
  });
  testWidgets('均线提示沿用实际趋势序列，不把旧汇总查询误作同口径', (t) async {
    final future =
        DateTime(now.year, now.month, 16, 12).millisecondsSinceEpoch ~/ 1000;
    await db.customStatement(
        "INSERT INTO transactions(ledger_id,type,amount,category_id,happened_at,note) VALUES(1,'expense',50,$parent,$future,'趋势原口径边界')");
    final data = await loadAnalyticsData(repo,
        ledgerId: 1,
        scope: 'year',
        type: 'expense',
        selMonth: month,
        startDay: 1,
        clock: DateTime(now.year, now.month, 15));
    expect(data.total, closeTo(95.2, 1e-8));
    expect(data.values.reduce((a, b) => a + b), closeTo(145.2, 1e-8));
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
                body: AnalyticsContent(
                    data: data,
                    scope: 'year',
                    type: 'expense',
                    month: month,
                    onTypeChanged: (_) {},
                    onAnnual: () {},
                    onShare: () {},
                    onRecalculate: (_) {})))));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('column-average-label')));
    await ready(t, find.byType(BeeDialog));
    expect(find.textContaining('145.2 ÷'), findsOneWidget);
    expect(find.textContaining('95.2 ÷'), findsNothing);
    expect((await db.select(db.transactions).get()).length, 6);
    await close(t);
  });
  testWidgets('320英文深色140%三范围三视角均无溢出且仍为真实数据', (t) async {
    await open(t, narrow: true);
    for (final scope in ['Month', 'Year', 'All']) {
      await t.tap(find.descendant(
          of: find.byType(BeeCompactTabs<String>).first,
          matching: find.text(scope)));
      await ready(t, find.byType(BeeAnalyticsSummary));
      for (final label in ['Expense', 'Income', 'Balance']) {
        await t.tap(find.descendant(
            of: find.byType(BeeAnalyticsSummary), matching: find.text(label)));
        await ready(t, find.byType(BeeAnalyticsSummary));
        expect(t.takeException(), isNull, reason: '$scope $label');
        final actual =
            t.widget<AnalyticsContent>(find.byType(AnalyticsContent));
        expect(
            actual.data.count,
            label == 'Expense'
                ? 3
                : label == 'Income'
                    ? 1
                    : 4);
        if (label == 'Balance') {
          expect(actual.data.incomeTotal, 12000);
          expect(actual.data.expenseTotal, closeTo(95.2, 1e-8));
          expect(find.byType(BeeAnalyticsComposition), findsOneWidget);
        }
      }
    }
    await close(t);
  });
  testWidgets('320英文深色140%结构无溢出', (t) async {
    await open(t, narrow: true);
    expect(t.takeException(), isNull);
    expect(
        t.widget<BeeAnalyticsSummary>(find.byType(BeeAnalyticsSummary)).count,
        '3');
    await t.drag(
        find.byType(SingleChildScrollView).last, const Offset(0, -600));
    await t.pump();
    expect(t.takeException(), isNull);
    await close(t);
  });
}
