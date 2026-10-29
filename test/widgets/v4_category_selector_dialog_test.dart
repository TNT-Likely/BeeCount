import 'dart:ui' as ui;
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/providers/shared_ledger_providers.dart';
import 'package:beecount/utils/shared_ledger_picker_filter.dart';
import 'package:beecount/pages/shared/selectors/category_selector_dialog.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CountingCategoryRepository extends LocalRepository {
  CountingCategoryRepository(super.db);
  int reads = 0;
  bool failNext = false;
  @override
  Future<List<Category>> getAllCategories() async {
    reads++;
    if (failNext) {
      failNext = false;
      throw StateError('Synthetic category loading failure');
    }
    return super.getAllCategories();
  }
}

void main() {
  late BeeDatabase db;
  late CountingCategoryRepository repo;
  late ProviderContainer container;
  late int food, lunch, dinner, drink, coffee, salary;
  Category? chosen;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = CountingCategoryRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency,sync_id) VALUES(1,'生活','CNY','selector-ledger')");
    food =
        await repo.createCategory(name: '餐饮A', kind: 'expense', sortOrder: 0);
    lunch = await repo.createSubCategory(
        parentId: food, name: '午餐A', kind: 'expense');
    dinner = await repo.createSubCategory(
        parentId: food, name: '晚餐A', kind: 'expense');
    drink =
        await repo.createCategory(name: '饮品A', kind: 'expense', sortOrder: 1);
    coffee = await repo.createSubCategory(
        parentId: drink, name: '咖啡A', kind: 'expense');
    salary = await repo.createCategory(name: '工资A', kind: 'income');
    for (final category in [food, lunch, lunch]) {
      await repo.addTransaction(
          ledgerId: 1,
          type: 'expense',
          amount: 3,
          happenedAt: DateTime(2026, 10, 24),
          categoryId: category);
    }
    repo.reads = 0;
    chosen = null;
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> open(WidgetTester tester, CategorySelectorDialog dialog,
      {double scale = 1, Brightness brightness = Brightness.light}) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: beeTheme(brightness: brightness),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Builder(
            builder: (context) => Scaffold(
                body: Center(
                    child: TextButton(
                        onPressed: () async {
                          chosen = await showDialog<Category>(
                              context: context, builder: (_) => dialog);
                        },
                        child: const Text('选择真实分类'))))),
      ),
    ));
    await tester.tap(find.text('选择真实分类'));
    await tester.pumpAndSettle();
  }

  Finder root(String name) => find.widgetWithText(RecordingCategoryTile, name);
  Finder child(String name) =>
      find.widgetWithText(RecordingSubcategoryChip, name);

  testWidgets('真实笔数、二级选择和本地搜索不重复发起数据请求', (tester) async {
    await open(
        tester,
        const CategorySelectorDialog(
            type: 'expense', showTransactionCount: true, ledgerId: 1));
    expect(find.byType(BeeDialog), findsOneWidget);
    expect(find.text('2笔'), findsOneWidget);
    expect(repo.reads, 1);
    await tester.enterText(find.byType(TextField), '咖啡A');
    await tester.pumpAndSettle();
    expect(repo.reads, 1);
    await tester.tap(child('咖啡A'));
    await tester.pumpAndSettle();
    expect(chosen?.id, coffee);
    expect(find.byType(CategorySelectorDialog), findsNothing);
    expect((await db.select(db.transactions).get()), hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('不可选父分类仍可进入二级，第二组父分类也能切换', (tester) async {
    await open(tester, const CategorySelectorDialog(type: 'expense'));
    await tester.tap(root('饮品A'));
    await tester.pumpAndSettle();
    expect(chosen, isNull);
    expect(child('咖啡A'), findsOneWidget);
    await tester.tap(child('咖啡A'));
    await tester.pumpAndSettle();
    expect(chosen?.id, coffee);
    expect(tester.takeException(), isNull);
  });

  testWidgets('允许父分类时先展开，再从二级条选择父分类；初始子分类保持高亮', (tester) async {
    await open(
        tester,
        CategorySelectorDialog(
            type: 'expense',
            includeParentCategories: true,
            currentCategoryId: dinner));
    expect(
        tester.widget<RecordingSubcategoryChip>(child('晚餐A')).selected, isTrue);
    await tester.tap(root('餐饮A'));
    await tester.pumpAndSettle();
    expect(chosen, isNull);
    await tester.tap(child('餐饮A'));
    await tester.pumpAndSettle();
    expect(chosen?.id, food);
  });

  testWidgets('排除项与跨收支过滤保留，父分类被排除后不显示孤立子项', (tester) async {
    await open(
        tester,
        CategorySelectorDialog(
            type: 'all',
            includeParentCategories: true,
            excludeIds: [food],
            excludeNames: const ['咖啡A']));
    expect(root('餐饮A'), findsNothing);
    expect(child('午餐A'), findsNothing);
    expect(child('咖啡A'), findsNothing);
    expect(find.text('收入'), findsOneWidget);
    await tester.tap(root('工资A'));
    await tester.pumpAndSettle();
    expect(chosen?.id, salary);
  });

  testWidgets('仅一级模式保持父类可选且不暴露二级；全展开模式展示全部组', (tester) async {
    await open(tester,
        const CategorySelectorDialog(type: 'expense', onlyTopLevel: true));
    expect(child('午餐A'), findsNothing);
    await tester.tap(root('餐饮A'));
    await tester.pumpAndSettle();
    expect(chosen?.id, food);
    await open(
        tester,
        const CategorySelectorDialog(
            type: 'expense', expandChildrenByDefault: true));
    expect(child('午餐A'), findsOneWidget);
    expect(child('咖啡A'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
  });

  testWidgets('异步过滤禁用二级，禁用语义正确且不能误选', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(
        tester,
        CategorySelectorDialog(
            type: 'expense',
            categoryFilter: (category) async => category.id != coffee));
    await tester.tap(root('饮品A'));
    await tester.pumpAndSettle();
    final disabled = child('咖啡A');
    expect(tester.widget<RecordingSubcategoryChip>(disabled).onTap, isNull);
    expect(tester.getSemantics(disabled).hasFlag(ui.SemanticsFlag.isEnabled),
        isFalse);
    await tester.tap(disabled);
    await tester.pumpAndSettle();
    expect(chosen, isNull);
    expect(find.byType(BeeDialog), findsOneWidget);
    await tester.tap(root('餐饮A'));
    await tester.pumpAndSettle();
    await tester.tap(child('午餐A'));
    await tester.pumpAndSettle();
    expect(chosen?.id, lunch);
    semantics.dispose();
  });

  testWidgets('加载异常可重试，320深色大字含键盘时可关闭且无溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    repo.failNext = true;
    await open(tester, const CategorySelectorDialog(type: 'expense'),
        scale: 1.4, brightness: Brightness.dark);
    expect(find.text('分类加载失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(repo.reads, 2);
    expect(root('餐饮A'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(BeeDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('共享成员只看拥有者资源，真实笔数与刷新和负数身份保留', (tester) async {
    await db.customStatement(
        "UPDATE ledgers SET is_shared=1,my_role='editor' WHERE id=1");
    await db.customStatement(
        "INSERT INTO shared_ledger_categories(ledger_sync_id,sync_id,name,kind,icon,level,sort_order,updated_at) VALUES('selector-ledger','owner-parent','共享父类','expense','restaurant',1,0,1792713600)");
    await db.customStatement(
        "INSERT INTO shared_ledger_categories(ledger_sync_id,sync_id,name,kind,icon,level,parent_sync_id,sort_order,updated_at) VALUES('selector-ledger','owner-child','共享子类','expense','coffee',2,'owner-parent',0,1792713600)");
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 5,
        happenedAt: DateTime(2026, 10, 24),
        categorySyncIdOverride: 'owner-child');
    await open(
        tester,
        const CategorySelectorDialog(
            type: 'expense', ledgerId: 1, showTransactionCount: true));
    expect(root('餐饮A'), findsNothing);
    expect(child('共享子类'), findsOneWidget);
    expect(find.text('1笔'), findsOneWidget);
    expect(repo.reads, 1);
    await db.customStatement(
        "UPDATE shared_ledger_categories SET name='共享更新' WHERE sync_id='owner-child'");
    container.read(sharedResourceRefreshProvider.notifier).state++;
    await tester.pumpAndSettle();
    expect(child('共享子类'), findsNothing);
    expect(child('共享更新'), findsOneWidget);
    expect(repo.reads, 2);
    await tester.tap(child('共享更新'));
    await tester.pumpAndSettle();
    expect(chosen?.id, syntheticIdForSyncId('owner-child'));
    expect(chosen?.parentId, syntheticIdForSyncId('owner-parent'));
    expect(await db.select(db.categories).get(), hasLength(6));
    expect(tester.takeException(), isNull);
  });
}
