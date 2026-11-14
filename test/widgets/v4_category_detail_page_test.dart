import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/transaction/category_detail_page.dart';
import 'package:beecount/pages/transaction/search_page.dart';
import 'package:beecount/pages/transaction/category_detail/bindings/category_detail.dart';
import 'package:beecount/pages/transaction/category_detail/widgets/category_detail_sections.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/pages/shared/transactions/transaction_list_item.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;
  late int parent, child, foreign, direct;
  final now = DateTime.now();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'生活','CNY'),(2,'旅行','USD')");
    parent = await repo.createCategory(
        name: '餐饮', kind: 'expense', icon: 'restaurant');
    child = await repo.createSubCategory(
        parentId: parent, name: '咖啡', kind: 'expense', icon: 'local_cafe');
    direct = await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 3,
        categoryId: parent,
        happenedAt: DateTime(now.year, now.month, 2));
    foreign = await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 12,
        currencyCode: 'USD',
        nativeAmount: 85.2,
        categoryId: child,
        happenedAt: DateTime(now.year, now.month, 3),
        note: '外币咖啡',
        excludeFromStats: true,
        excludeFromBudget: true);
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 9,
        categoryId: child,
        happenedAt: DateTime(now.year, now.month, 0));
    await repo.addTransaction(
        ledgerId: 2,
        type: 'expense',
        amount: 20,
        categoryId: child,
        happenedAt: DateTime(now.year, now.month, 4));
    final tag = await repo.createTag(name: '工作日', color: '#aa8b29');
    await repo.updateTransactionTags(transactionId: foreign, tagIds: [tag]);
    await repo.createAttachment(
        transactionId: foreign, fileName: 'synthetic.png', fileSize: 12);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      currentLedgerProvider.overrideWith((ref) => repo.watchLedger(1)),
      accountFeatureEnabledProvider.overrideWith((ref) async => true),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService())
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> open(WidgetTester tester,
      {Size size = const Size(398, 844), double scale = 1}) async {
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
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => CategoryDetailPage(
                                    categoryId: parent, categoryName: '餐饮'))),
                        child: const Text('打开分类')))))));
    await tester.tap(find.text('打开分类'));
    await tester.pumpAndSettle();
  }

  CategoryDetailController model(WidgetTester tester) => tester
      .widget<CategoryDetailSections>(find.byType(CategoryDetailSections))
      .data;
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  testWidgets('真实父子分类汇总、外币、标记标签与附件保留，排序和弹窗取消不写数据', (tester) async {
    final before = await repo.getTransactionsByLedger(1);
    await open(tester);
    final l =
        AppLocalizations.of(tester.element(find.byType(CategoryDetailPage)));
    expect(model(tester).count, 3);
    expect(model(tester).amount, closeTo(97.2, .0001));
    expect(find.byType(BeeResourceHero), findsOneWidget);
    expect(find.byType(BeeResourceBreakdown), findsOneWidget);
    await tester.tap(find.text(l.categoryDetailSortAmountAsc));
    await tester.pumpAndSettle();
    expect(model(tester).rows.first.t.id, direct);
    final key = find.byKey(ValueKey('category-transaction-$foreign'));
    await tester.scrollUntilVisible(key, 300,
        scrollable: find
            .descendant(
                of: find.byType(CategoryDetailSections),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    final row = tester.widget<TransactionListItem>(
        find.descendant(of: key, matching: find.byType(TransactionListItem)));
    expect(row.nativeAmount, 85.2);
    expect(row.tags!.single.name, '工作日');
    expect(row.attachmentCount, 1);
    expect(row.excludeFromStats, isTrue);
    expect(row.excludeFromBudget, isTrue);
    await tester.tap(find.byTooltip(l.commonMore));
    await tester.pumpAndSettle();
    expect(find.text(l.categoryMigrationTooltip), findsOneWidget);
    expect(find.text(l.commonEdit), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(await repo.getTransactionsByLedger(1), before);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('分类菜单直接搜索继承分类与周期且不修改原数据', (tester) async {
    final now = DateTime.now();
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 7,
        categoryId: child,
        happenedAt: DateTime(now.year, now.month + 1));
    final before = await repo.getTransactionsByLedger(1);
    await open(tester);
    final l =
        AppLocalizations.of(tester.element(find.byType(CategoryDetailPage)));
    await tester.tap(find.text(l.v4DetailMonth));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l.commonMore));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.searchTitle));
    await tester.pumpAndSettle();
    expect(find.byType(SearchPage), findsOneWidget);
    expect(find.byType(BeeTransactionRow), findsNWidgets(2));
    expect(find.textContaining('88.20'), findsOneWidget);
    expect(await repo.getTransactionsByLedger(1), before);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('全部不重复展示时间条，月份确认铺满弹层内容宽度', (tester) async {
    await open(tester);
    expect(find.byType(BeeDateRangeBar), findsNothing);
    final l =
        AppLocalizations.of(tester.element(find.byType(CategoryDetailPage)));
    await tester.tap(find.text(l.v4DetailMonth));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BeeDateRangeBar));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(BeeButton, l.commonConfirm);
    expect(tester.getSize(button).width, greaterThan(300));
    await tester.tap(find.byType(CloseButton).last);
    await tester.pumpAndSettle();
    await close(tester);
  });
  testWidgets('日期滚轮取消保留周期，二级导航保留范围，返回保留原排序', (tester) async {
    await open(tester);
    final l =
        AppLocalizations.of(tester.element(find.byType(CategoryDetailPage)));
    await tester.tap(find.text(l.v4DetailMonth));
    await tester.pumpAndSettle();
    expect(model(tester).count, 2);
    final anchor = model(tester).anchor;
    await tester.tap(find.byType(BeeDateRangeBar));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CupertinoPicker).last, const Offset(0, -44));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton).last);
    await tester.pumpAndSettle();
    expect(model(tester).anchor, anchor);
    expect(model(tester).count, 2);
    await tester.tap(find.descendant(
        of: find.byType(BeeResourceBreakdown), matching: find.text('咖啡')));
    await tester.pumpAndSettle();
    expect(model(tester).categoryId, child);
    expect(model(tester).period, CategoryDetailPeriod.month);
    expect(model(tester).count, 1);
    await tester.tap(find.descendant(
        of: find.byType(BeePageHeader), matching: find.byType(BackButton)));
    await tester.pumpAndSettle();
    expect(model(tester).categoryId, parent);
    expect(model(tester).count, 2);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('320 短屏大字详情能滚动，隐私不泄露金额或百分比', (tester) async {
    container.read(hideAmountsProvider.notifier).state = true;
    await open(tester, size: const Size(320, 568), scale: 1.4);
    expect(model(tester).count, 3);
    expect(find.text('97.20', findRichText: true), findsNothing);
    final content = find.byType(CategoryDetailSections);
    await tester.drag(
        find.descendant(of: content, matching: find.byType(ListView)),
        const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('≈ ¥85.20'), findsNothing);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
