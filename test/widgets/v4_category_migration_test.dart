import 'dart:async';
import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/category/category_migration_page.dart';
import 'package:beecount/dev/component_gallery/bindings/category_migration_preview.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/pages/shared/selectors/category_selector_dialog.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends LocalRepository {
  _Repository(super.db);
  bool failRead = false, failWrite = false;
  int readCalls = 0, writeCalls = 0;
  Completer<void>? gate;
  @override
  Future<({int transactionCount, bool canMigrate})> getCategoryMigrationInfo(
      {required int fromCategoryId, required int toCategoryId}) async {
    readCalls++;
    await gate?.future;
    if (failRead) throw StateError('synthetic read failure');
    return super.getCategoryMigrationInfo(
        fromCategoryId: fromCategoryId, toCategoryId: toCategoryId);
  }

  @override
  Future<int> migrateCategory(
      {required int fromCategoryId, required int toCategoryId}) {
    writeCalls++;
    if (failWrite) throw StateError('synthetic write failure');
    return super.migrateCategory(
        fromCategoryId: fromCategoryId, toCategoryId: toCategoryId);
  }
}

void main() {
  late BeeDatabase db;
  late _Repository repo;
  late ProviderContainer container;
  late int parent, source, target, targetChild, empty, income;
  bool? result;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _Repository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'生活','CNY'),(2,'旅行','USD')");
    parent = await repo.createCategory(name: '来源父级', kind: 'expense');
    source = await repo.createSubCategory(
        name: '合成咖啡', kind: 'expense', parentId: parent);
    target = await repo.createCategory(name: '目标父级', kind: 'expense');
    targetChild = await repo.createSubCategory(
        name: '目标子级', kind: 'expense', parentId: target);
    empty = await repo.createCategory(name: '空分类', kind: 'expense');
    income = await repo.createCategory(name: '合成收入', kind: 'income');
    for (final ledger in [1, 2]) {
      await repo.addTransaction(
          ledgerId: ledger,
          type: 'expense',
          amount: 12.34,
          happenedAt: DateTime(2026, 10, 24, 12, 34),
          categoryId: source,
          note: '保留备注$ledger');
    }
    await repo.addTransaction(
        ledgerId: 1,
        type: 'income',
        amount: 99,
        happenedAt: DateTime(2026, 10, 23),
        categoryId: income);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
    ]);
    result = null;
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> ready(WidgetTester t, Finder f) async {
    for (var i = 0; i < 100; i++) {
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
      {int? preselect, bool live = false, bool narrow = false}) async {
    t.view.physicalSize = narrow ? const Size(320, 568) : const Size(398, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final category = preselect == null
        ? null
        : await (db.select(db.categories)..where((c) => c.id.equals(preselect)))
            .getSingle();
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(
                brightness: narrow ? Brightness.dark : Brightness.light),
            locale: narrow ? const Locale('en') : const Locale('zh'),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(narrow ? 1.4 : 1)),
                child: child!),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
                builder: (context) => Scaffold(
                    body: Center(
                        child: TextButton(
                            child: const Text('进入'),
                            onPressed: () async {
                              result = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => live
                                          ? const Scaffold(
                                              body: SingleChildScrollView(
                                                  child:
                                                      LiveCategoryMigrationPreview()))
                                          : CategoryMigrationPage(
                                              preselectedFromCategory:
                                                  category)));
                            })))))));
    await t.tap(find.text('进入'));
    await ready(t, find.byType(BeeCategoryMigrationPair));
  }

  AppLocalizations l(WidgetTester t) =>
      AppLocalizations.of(t.element(find.byType(BeeCategoryMigrationPair)));
  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 3));
  }

  Future<void> targetSelect(WidgetTester t, {String name = '目标父级'}) async {
    final label = l(t).categoryMigrationToLabel;
    await t.ensureVisible(find.bySemanticsLabel(RegExp('^$label ·')));
    await t.pump();
    await t.tap(find.bySemanticsLabel(RegExp('^$label ·')));
    await ready(t, find.byType(CategorySelectorDialog));
    final dialog =
        t.widget<CategorySelectorDialog>(find.byType(CategorySelectorDialog));
    expect(dialog.includeParentCategories, true);
    expect(dialog.excludeIds, hasLength(1));
    final selectedName = t
        .widget<BeeCategoryMigrationPair>(find.byType(BeeCategoryMigrationPair))
        .fromName;
    expect(
        (await repo.getAllCategories())
            .singleWhere((c) => c.id == dialog.excludeIds!.single)
            .name,
        selectedName);
    expect(dialog.ledgerId, 1);
    await t.enterText(find.byType(TextField), name);
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(RecordingCategoryTile, name));
    await t.pumpAndSettle();
    if (find.byType(CategorySelectorDialog).evaluate().isNotEmpty) {
      await t.tap(find.widgetWithText(RecordingSubcategoryChip, name));
      await t.pumpAndSettle();
    }
    expect(find.byType(CategorySelectorDialog), findsNothing);
  }

  Future<void> start(WidgetTester t) async {
    await t
        .tap(find.widgetWithText(BeeButton, l(t).categoryMigrationStartButton));
    await ready(t, find.byType(BeeDialog));
  }

  Future<void> dialogButton(WidgetTester t, String label) async {
    await t.tap(find
        .descendant(of: find.byType(BeeDialog), matching: find.text(label))
        .last);
    await t.pump(const Duration(milliseconds: 400));
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<List<Map<String, Object?>>> tx() async =>
      (await db.customSelect('SELECT * FROM transactions ORDER BY id').get())
          .map((r) => r.data)
          .toList();

  testWidgets('来源先选、目标禁用；原分类弹窗保留类型、当前账本笔数和取消草稿', (t) async {
    await open(t);
    var pair = t.widget<BeeCategoryMigrationPair>(
        find.byType(BeeCategoryMigrationPair));
    expect(pair.onTo, isNull);
    await t.tap(
        find.bySemanticsLabel(RegExp('^${l(t).categoryMigrationFromLabel} ·')));
    await ready(t, find.byType(CategorySelectorDialog));
    final selector =
        t.widget<CategorySelectorDialog>(find.byType(CategorySelectorDialog));
    expect(selector.includeParentCategories, false);
    expect(selector.showTransactionCount, true);
    expect(selector.ledgerId, 1);
    expect(selector.type, 'expense');
    await t.tap(find.byType(CloseButton));
    await t.pumpAndSettle();
    pair = t.widget<BeeCategoryMigrationPair>(
        find.byType(BeeCategoryMigrationPair));
    expect(pair.fromName, isNull);
    expect(await tx(), hasLength(3));
    await close(t);
  });
  testWidgets('来源预选与父级目标保留，确认显示跨账本2笔；取消不写', (t) async {
    await open(t, preselect: source);
    await targetSelect(t);
    final before = await tx();
    await start(t);
    final text = l(t).categoryMigrationConfirmMessage('2', '合成咖啡', '目标父级');
    expect(find.text(text), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await dialogButton(t, l(t).commonCancel);
    expect(await tx(), before);
    expect(repo.writeCalls, 0);
    await close(t);
  });
  testWidgets('真实确认迁移两个账本，仅改categoryId；成功弹窗关闭返回true', (t) async {
    await db.customStatement(
        "INSERT INTO tags(id,name,color) VALUES(1,'保留标签','#219c9c')");
    await db.customStatement(
        'INSERT INTO transaction_tags(transaction_id,tag_id) VALUES(1,1),(2,1)');
    await db.customStatement(
        "INSERT INTO transaction_attachments(transaction_id,file_name,original_name,file_size,width,height) VALUES(1,'owned.png','保留付款凭证.png',1234,80,120)");
    final relations = await db
        .customSelect('SELECT * FROM transaction_tags ORDER BY id')
        .get();
    final attachments = await db
        .customSelect('SELECT * FROM transaction_attachments ORDER BY id')
        .get();
    await open(t, preselect: source);
    await targetSelect(t);
    final before = await tx(), categories = await repo.getAllCategories();
    await start(t);
    final strings = l(t);
    await dialogButton(t, strings.categoryMigrationConfirmOk);
    await ready(t, find.text(strings.categoryMigrationCompleteTitle));
    final after = await tx();
    expect(after, [
      for (final row in before)
        {...row, if (row['category_id'] == source) 'category_id': target}
    ]);
    expect(await repo.getAllCategories(), categories);
    expect(
        (await db
                .customSelect('SELECT * FROM transaction_tags ORDER BY id')
                .get())
            .map((r) => r.data),
        relations.map((r) => r.data));
    expect(
        (await db
                .customSelect(
                    'SELECT * FROM transaction_attachments ORDER BY id')
                .get())
            .map((r) => r.data),
        attachments.map((r) => r.data));
    expect((await repo.getSubCategories(target)).single.id, targetChild);
    expect(repo.writeCalls, 1);
    expect(result, isNull);
    await dialogButton(t, strings.commonOk);
    expect(result, true);
    expect(find.byType(CategoryMigrationPage), findsNothing);
    await close(t);
  });
  test('真实仓库拒绝相同/缺失/共享负ID目标，统计跨账本且不纳入父分类子账单', () async {
    final count = await repo.getCategoryMigrationInfo(
        fromCategoryId: source, toCategoryId: target);
    expect(count, (transactionCount: 2, canMigrate: true));
    for (final id in [source, 999999, -123]) {
      expect(
          (await repo.getCategoryMigrationInfo(
                  fromCategoryId: source, toCategoryId: id))
              .canMigrate,
          false);
    }
    expect(
        (await repo.getCategoryMigrationInfo(
                fromCategoryId: parent, toCategoryId: target))
            .transactionCount,
        0);
    expect(await tx(), hasLength(3));
  });
  testWidgets('无账单来源走原不可迁移弹窗，不产生写入', (t) async {
    await open(t, preselect: empty);
    await targetSelect(t);
    final strings = l(t);
    await start(t);
    expect(find.text(strings.categoryMigrationCannotMessage), findsOneWidget);
    expect(repo.writeCalls, 0);
    await dialogButton(t, strings.commonOk);
    expect(result, isNull);
    await close(t);
  });
  for (final write in [false, true]) {
    testWidgets('真实仓库${write ? '写入' : '查询'}失败有规范反馈，数据不变且可再次提交', (t) async {
      await open(t, preselect: source);
      await targetSelect(t);
      final before = await tx(), strings = l(t);
      repo.failRead = !write;
      repo.failWrite = write;
      await start(t);
      if (write) {
        await dialogButton(t, strings.categoryMigrationConfirmOk);
        await ready(t, find.text(strings.categoryMigrationFailedTitle));
      }
      expect(find.text(strings.categoryMigrationFailedTitle), findsOneWidget);
      await dialogButton(t, strings.commonOk);
      expect(await tx(), before);
      repo.failRead = repo.failWrite = false;
      await start(t);
      expect(find.text(strings.categoryMigrationConfirmTitle), findsWidgets);
      await dialogButton(t, strings.commonCancel);
      await close(t);
    });
  }
  testWidgets('查询等待时按钮和类型不可重复触发，取消后恢复', (t) async {
    await open(t, preselect: source);
    await targetSelect(t);
    repo.gate = Completer<void>();
    await t
        .tap(find.widgetWithText(BeeButton, l(t).categoryMigrationStartButton));
    await t.pump();
    expect(
        t
            .widget<BeeSegmented<String>>(find.byType(BeeSegmented<String>))
            .onChanged,
        isNull);
    expect(t.widget<BeeActionBar>(find.byType(BeeActionBar)).onPrimary, isNull);
    expect(repo.readCalls, 1);
    repo.gate!.complete();
    await ready(t, find.byType(BeeDialog));
    await dialogButton(t, l(t).commonCancel);
    expect(
        t.widget<BeeActionBar>(find.byType(BeeActionBar)).onPrimary, isNotNull);
    await close(t);
  });
  testWidgets('重复点当前收支类型也清空两项，收入预选保持原类型', (t) async {
    await open(t, preselect: income);
    var segmented =
        t.widget<BeeSegmented<String>>(find.byType(BeeSegmented<String>));
    expect(segmented.value, 'income');
    await t.tap(find.text(l(t).categoryIncome));
    await t.pump();
    expect(
        t
            .widget<BeeCategoryMigrationPair>(
                find.byType(BeeCategoryMigrationPair))
            .fromName,
        isNull);
    await close(t);
  });
  testWidgets('320英文深色140%字体无溢出，底部提交固定且所有字段能滚到', (t) async {
    await open(t, preselect: source, narrow: true);
    final footer = t.getRect(find.byType(BeeActionBar));
    expect(footer.bottom, 568);
    await t.ensureVisible(find.byType(BeeCategoryMigrationPair));
    await t.pumpAndSettle();
    expect(t.getRect(find.byType(BeeActionBar)), footer);
    expect(t.takeException(), isNull);
    await close(t);
  });
  testWidgets('业务验收读取真实迁移信息，不写数据；入口传递原来源分类', (t) async {
    await open(t, live: true);
    final before = await tx();
    await t.tap(
        find.bySemanticsLabel(RegExp('^${l(t).categoryMigrationFromLabel} ·')));
    await ready(t, find.byType(CategorySelectorDialog));
    await t.enterText(find.byType(TextField), '合成咖啡');
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(RecordingSubcategoryChip, '合成咖啡'));
    await t.pumpAndSettle();
    await targetSelect(t);
    await ready(t, find.text('2笔 · 可迁移'));
    expect(repo.writeCalls, 0);
    expect(await tx(), before);
    await t.ensureVisible(find.text('打开分类迁移'));
    await t.pump();
    await t.tap(find.text('打开分类迁移'));
    await ready(t, find.byType(CategoryMigrationPage));
    expect(
        t
            .widget<CategoryMigrationPage>(find.byType(CategoryMigrationPage))
            .preselectedFromCategory
            ?.id,
        source);
    await close(t);
  });
}
