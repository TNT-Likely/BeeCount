import 'dart:async';
import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/budget_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/budget/budget_edit_page.dart';
import 'package:beecount/pages/budget/budget_page.dart';
import 'package:beecount/pages/budget/overview/bindings/budget_overview.dart';
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
  Future<BudgetOverview> getBudgetOverview(int ledgerId, DateTime month) async {
    await gate?.future;
    if (fail) throw StateError('synthetic budget read failure');
    return super.getBudgetOverview(ledgerId, month);
  }
}

void main() {
  late BeeDatabase db;
  late _Repo repo;
  late ProviderContainer c;
  late int parent, child, total, category;
  setUp(() async {
    SharedPreferences.setMockInitialValues(
        {'auto_sync': false, 'home_budget_card_enabled': true});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _Repo(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency,month_start_day) VALUES(1,'预算测试','USD',8)");
    parent = await repo.createCategory(
        name: '合成餐饮', kind: 'expense', icon: 'restaurant');
    child = await repo.createSubCategory(
        name: '合成午餐', kind: 'expense', parentId: parent);
    total = await repo.createBudget(
        ledgerId: 1, type: 'total', amount: 200, startDay: 1);
    category = await repo.createBudget(
        ledgerId: 1, type: 'category', categoryId: parent, amount: 100);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.customStatement(
        "INSERT INTO transactions(ledger_id,type,amount,native_amount,category_id,happened_at,exclude_from_stats,exclude_from_budget) VALUES(1,'expense',100,NULL,$parent,$now,0,0),(1,'expense',30,NULL,$child,$now,1,0),(1,'expense',12,85.2,$child,$now,0,0),(1,'expense',500,NULL,$parent,$now,0,1),(1,'income',99,NULL,NULL,$now,0,0)");
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService())
    ]);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });
  Future<void> ready(WidgetTester t, Finder f) async {
    for (var i = 0; i < 80; i++) {
      await t.pump(const Duration(milliseconds: 30));
      if (f.evaluate().isNotEmpty) {
        await t.pump(const Duration(milliseconds: 300));
        return;
      }
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    expect(f, findsWidgets);
  }

  Future<void> open(WidgetTester t,
      {bool narrow = false, Finder? target}) async {
    t.view.physicalSize = narrow ? const Size(320, 568) : const Size(398, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await c.read(currentLedgerProvider.future);
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
            home: const BudgetPage())));
    await ready(t, target ?? find.byType(BeeBudgetOverview));
  }

  AppLocalizations l(WidgetTester t) =>
      AppLocalizations.of(t.element(find.byType(BudgetPage)));
  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 3));
  }

  Future<List<Map<String, Object?>>> tx() async =>
      (await db.customSelect('SELECT * FROM transactions ORDER BY id').get())
          .map((r) => r.data)
          .toList();
  testWidgets('原口径含子分类/历史折算/仅预算排除，原超支百分比和剩余负数完整展示', (t) async {
    final before = await tx();
    await open(t);
    final overview =
        t.widget<BeeBudgetOverview>(find.byType(BeeBudgetOverview));
    expect(overview.used, '\$215.20');
    expect(overview.remaining, '\$-15.20');
    expect(overview.progress, closeTo(1.076, 1e-9));
    expect(overview.tone, BeeBudgetTone.exceeded);
    expect(overview.negativeRemaining, true);
    final cat =
        t.widget<BeeBudgetCategoryRow>(find.byType(BeeBudgetCategoryRow));
    expect(cat.percent, '215%');
    expect(cat.amounts, '\$215 / \$100');
    expect(cat.onTap, isNotNull);
    expect(await tx(), before);
    await close(t);
  });
  testWidgets('新增、总预算编辑和分类预算编辑沿用原路由与对象', (t) async {
    await open(t);
    await t.tap(find.text(l(t).commonEdit));
    await ready(t, find.byType(BudgetEditPage));
    expect(t.widget<BudgetEditPage>(find.byType(BudgetEditPage)).budget!.id,
        total);
    await close(t);
  });
  testWidgets('分类预算点击带原预算对象，首页显示开关真实持久化', (t) async {
    await open(t);
    final strings = l(t);
    await t.ensureVisible(find.text(strings.budgetShowOnHome));
    await t.pump();
    await t.tap(find.text(strings.budgetShowOnHome));
    await t.pumpAndSettle();
    expect(
        (await SharedPreferences.getInstance())
            .getBool('home_budget_card_enabled'),
        false);
    await t.ensureVisible(find.byType(BeeBudgetCategoryRow));
    await t.pump();
    await t.tap(find.byType(BeeBudgetCategoryRow));
    await ready(t, find.byType(BudgetEditPage));
    expect(t.widget<BudgetEditPage>(find.byType(BudgetEditPage)).budget!.id,
        category);
    await close(t);
  });
  testWidgets('共享编辑者只读金额，隐藏新增和编辑且保留本人首页偏好', (t) async {
    await db.customStatement(
        "UPDATE ledgers SET is_shared=1,my_role='editor' WHERE id=1");
    await open(t);
    expect(find.byTooltip(l(t).commonAdd), findsNothing);
    expect(t.widget<BeeBudgetOverview>(find.byType(BeeBudgetOverview)).onEdit,
        isNull);
    expect(
        t.widget<BeeBudgetCategoryRow>(find.byType(BeeBudgetCategoryRow)).onTap,
        isNull);
    expect(find.byType(BeeToggleRow), findsOneWidget);
    await close(t);
  });
  testWidgets('320英文深色140%大字和长金额，剩余天数/日均/开关全部可达', (t) async {
    await open(t, narrow: true);
    await t.ensureVisible(find.byType(BeeToggleRow));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await close(t);
  });
  for (final shared in [false, true]) {
    testWidgets('原空预算 shared=$shared 保留原所有者新增权限与路由', (t) async {
      await repo.deleteBudget(total);
      if (shared) {
        await db.customStatement(
            "UPDATE ledgers SET is_shared=1,my_role='editor' WHERE id=1");
      }
      final before = await tx();
      await open(t, target: find.byType(BeeEmptyState));
      final strings = l(t);
      expect(find.text(strings.budgetEmptyHint), findsOneWidget);
      if (shared) {
        expect(find.text(strings.budgetAddTotal), findsNothing);
        expect(find.byTooltip(strings.commonAdd), findsNothing);
      } else {
        await t.tap(find.text(strings.budgetAddTotal));
        await ready(t, find.byType(BudgetEditPage));
        expect(t.widget<BudgetEditPage>(find.byType(BudgetEditPage)).budget,
            isNull);
      }
      expect(await tx(), before);
      await close(t);
    });
  }
  testWidgets('原仓库读取失败可重试，恢复后读真实原用量', (t) async {
    repo.fail = true;
    await open(t, target: find.byType(BeeEmptyState));
    expect(
        find.textContaining('synthetic budget read failure'), findsOneWidget);
    repo.fail = false;
    await t.tap(find.text(l(t).v4RecordingRetry));
    await ready(t, find.byType(BeeBudgetOverview));
    expect(t.widget<BeeBudgetOverview>(find.byType(BeeBudgetOverview)).used,
        '\$215.20');
    await close(t);
  });
  testWidgets('加载不误展示空预算，完成后显示真实数据', (t) async {
    repo.gate = Completer<void>();
    await open(t, target: find.byType(CircularProgressIndicator));
    expect(find.byType(BeeEmptyState), findsNothing);
    repo.gate!.complete();
    await ready(t, find.byType(BeeBudgetOverview));
    expect(t.widget<BeeBudgetOverview>(find.byType(BeeBudgetOverview)).used,
        '\$215.20');
    await close(t);
  });
  test('预算周期跟随账本8日起始且左闭右开，忽略历史预算startDay', () async {
    await db.customStatement('DELETE FROM transactions');
    for (final entry in [
      (DateTime(2026, 10, 7, 23, 59, 59), 100),
      (DateTime(2026, 10, 8), 2),
      (DateTime(2026, 11, 7, 23, 59, 59), 3),
      (DateTime(2026, 11, 8), 200)
    ]) {
      await db.customStatement(
          "INSERT INTO transactions(ledger_id,type,amount,category_id,happened_at) VALUES(1,'expense',?, ?, ?)",
          [entry.$2, child, entry.$1.millisecondsSinceEpoch ~/ 1000]);
    }
    expect((await repo.getBudgetUsage(total, DateTime(2026, 10, 20))).used, 5);
    expect(
        (await repo.getBudgetUsage(category, DateTime(2026, 10, 20))).used, 5);
  });
  test('原70/90/100阈值映射与超过100%语义保留', () {
    for (final (used, expected) in [
      (69, BeeBudgetTone.normal),
      (70, BeeBudgetTone.warning),
      (90, BeeBudgetTone.danger),
      (100, BeeBudgetTone.exceeded),
      (150, BeeBudgetTone.exceeded)
    ]) {
      expect(budgetTone(BudgetUsage(used: used.toDouble(), budget: 100)),
          expected);
    }
  });
}
