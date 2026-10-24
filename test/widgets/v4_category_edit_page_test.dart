import 'dart:io';
import 'dart:convert';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/category/category_edit_page.dart';
import 'package:beecount/presentation/v4/bindings/category_icon_draft.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/custom_icon_service.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _IconService extends CustomIconService {
  _IconService(this.root);
  final Directory root;
  int saves = 0;
  @override
  Future<String> resolveIconPath(String path) async => '${root.path}/$path';
  @override
  Future<String> saveCustomIcon(File sourceFile, int categoryId) async {
    await validateImage(sourceFile);
    final path = 'saved-$categoryId-${++saves}.png';
    await sourceFile.copy('${root.path}/$path');
    return path;
  }
}

class _Picker extends CategoryIconPicker {
  File? file;
  @override
  Future<File?> pick(BuildContext context, Color primary) async => file;
}

class _Repository extends LocalRepository {
  _Repository(super.db);
  bool failIcon = false;
  @override
  Future<void> updateCategoryIcon(int id,
      {required String iconType,
      String? icon,
      String? customIconPath,
      String? communityIconId}) async {
    if (failIcon) throw StateError('owned icon write failure');
    await super.updateCategoryIcon(id,
        iconType: iconType,
        icon: icon,
        customIconPath: customIconPath,
        communityIconId: communityIconId);
  }
}

void main() {
  late BeeDatabase db;
  late _Repository repo;
  late ProviderContainer container;
  late Directory owned;
  late _IconService icons;
  late _Picker picker;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _Repository(db);
    owned = await Directory.systemTemp.createTemp('beecount-category-widget-');
    icons = _IconService(owned);
    picker = _Picker();
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'验收账本','CNY')");
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 0),
      categoryIconServiceProvider.overrideWithValue(icons),
      categoryIconPickerProvider.overrideWithValue(picker)
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    await owned.delete(recursive: true);
  });
  Future<void> idle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 12)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> open(WidgetTester tester, CategoryEditPage page,
      {Size size = const Size(398, 844),
      double scale = 1,
      Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
                    body: TextButton(
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute<void>(builder: (_) => page)),
                        child: const Text('打开')))))));
    await tester.tap(find.text('打开'));
    await tester.pump(const Duration(milliseconds: 400));
    await idle(tester);
  }

  AppLocalizations l(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(CategoryEditPage)));
  Future<void> touch(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await idle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  }

  testWidgets('必填、同类型全局重名和连续保存，真实仓储只创建一条', (tester) async {
    await repo.createCategory(name: '已存在', kind: 'expense');
    await open(tester, const CategoryEditPage(kind: 'expense'));
    await tester.tap(find.text(l(tester).commonSave));
    await tester.pumpAndSettle();
    expect(find.text(l(tester).categoryNameRequired), findsWidgets);
    await tester.enterText(find.byType(TextFormField), '已存在');
    await idle(tester);
    expect(find.text(l(tester).categoryNameDuplicate), findsWidgets);
    expect((await repo.getAllCategories()).length, 1);
    await tester.enterText(find.byType(TextFormField), '新增分类');
    await tester.pump();
    final save = find.text(l(tester).commonSave);
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await idle(tester);
    final result =
        (await repo.getAllCategories()).where((c) => c.name == '新增分类').toList();
    expect(result.length, 1);
    expect(result.single.kind, 'expense');
    expect(result.single.level, 1);
    expect(find.byType(CategoryEditPage), findsNothing);
    await close(tester);
  });
  testWidgets('二级创建锁定层级与父分类，编辑保留身份排序和历史账单', (tester) async {
    final parentId = await repo.createCategory(
        name: '父分类', kind: 'expense', icon: 'restaurant');
    final parent = (await repo.getCategoryById(parentId))!;
    await open(
        tester, CategoryEditPage(kind: 'expense', parentCategory: parent));
    expect(tester.widget<BeeToggleRow>(find.byType(BeeToggleRow)).onChanged,
        isNull);
    await tester.enterText(find.byType(TextFormField), '子分类');
    await touch(tester, find.text(l(tester).commonSave));
    final child = (await repo.getSubCategories(parentId)).single;
    expect(child.level, 2);
    expect(child.parentId, parentId);
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 3.5,
        categoryId: child.id,
        happenedAt: DateTime(2026, 10, 24),
        note: '历史记录');
    final before = (await repo.getTransactionsByLedger(1)).single;
    await open(tester, CategoryEditPage(kind: 'expense', category: child));
    expect(tester.widget<BeeToggleRow>(find.byType(BeeToggleRow)).onChanged,
        isNull);
    await tester.enterText(find.byType(TextFormField), '子分类修改');
    await touch(tester, find.text(l(tester).commonSave));
    final after = (await repo.getCategoryById(child.id))!;
    expect(after.syncId, child.syncId);
    expect(after.parentId, parentId);
    expect(after.sortOrder, child.sortOrder);
    expect((await repo.getTransactionsByLedger(1)).single.toJson(),
        before.toJson());
    await close(tester);
  });
  testWidgets('自定义图片仅保存时提交，返回取消不改数据库或原图，保存保留原文件', (tester) async {
    final id =
        await repo.createCategory(name: '原图片', kind: 'expense', icon: 'coffee');
    final original = File('${owned.path}/original.png')
      ..writeAsBytesSync(File('assets/logo2.png').readAsBytesSync());
    final cropped = File('${owned.path}/crop.png')
      ..writeAsBytesSync(
          File('assets/v4_gallery/attachment-payment.png').readAsBytesSync());
    await repo.updateCategoryIcon(id,
        iconType: 'custom', icon: 'coffee', customIconPath: 'original.png');
    final initial = (await repo.getCategoryById(id))!;
    final originalBytes = original.readAsBytesSync();
    picker.file = cropped;
    await open(tester, CategoryEditPage(kind: 'expense', category: initial));
    await idle(tester);
    await touch(tester, find.text(l(tester).categoryCustomIconTapToChange));
    expect((await repo.getCategoryById(id))!.toJson(), initial.toJson());
    expect(icons.saves, 0);
    await tester.tap(find.byType(BackButton));
    await idle(tester);
    expect(original.readAsBytesSync(), originalBytes);
    expect(icons.saves, 0);
    await open(tester, CategoryEditPage(kind: 'expense', category: initial));
    await idle(tester);
    await touch(tester, find.text(l(tester).categoryCustomIconTapToChange));
    await touch(tester, find.text(l(tester).commonSave));
    final saved = (await repo.getCategoryById(id))!;
    expect(saved.id, initial.id);
    expect(saved.syncId, initial.syncId);
    expect(saved.icon, 'coffee');
    expect(saved.customIconPath, startsWith('saved-'));
    expect(icons.saves, 1);
    expect(File('${owned.path}/${saved.customIconPath}').readAsBytesSync(),
        cropped.readAsBytesSync());
    expect(original.readAsBytesSync(), originalBytes);
    await close(tester);
  });
  testWidgets('图标提交失败时分类名称与新增记录原子回滚，规范错误弹窗可关闭', (tester) async {
    final id = await repo.createCategory(
        name: '保持原名', kind: 'expense', icon: 'restaurant');
    final before = (await repo.getCategoryById(id))!;
    repo.failIcon = true;
    await open(tester, CategoryEditPage(kind: 'expense', category: before));
    await tester.enterText(find.byType(TextFormField), '失败后回滚');
    await touch(tester, find.text(l(tester).commonSave));
    expect(find.byType(BeeDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect((await repo.getCategoryById(id))!.toJson(), before.toJson());
    await tester.tap(find.byType(CloseButton));
    await idle(tester);
    await tester.tap(find.byType(BackButton));
    await idle(tester);
    await open(tester, const CategoryEditPage(kind: 'income'));
    await tester.enterText(find.byType(TextFormField), '创建回滚');
    await touch(tester, find.text(l(tester).commonSave));
    expect((await repo.getAllCategories()).length, 1);
    await tester.tap(find.byType(CloseButton));
    await idle(tester);
    await close(tester);
  });
  testWidgets('父分类子项有账单时禁止删除，空分类取消与确认保留原语义', (tester) async {
    final parentId = await repo.createCategory(name: '有记录父分类', kind: 'expense');
    final childId = await repo.createSubCategory(
        parentId: parentId, name: '有记录子分类', kind: 'expense');
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 5,
        categoryId: childId,
        happenedAt: DateTime(2026, 10, 24));
    await open(
        tester,
        CategoryEditPage(
            kind: 'expense', category: await repo.getCategoryById(parentId)));
    final strings = l(tester);
    await touch(tester, find.text(strings.categoryDeleteTitle));
    expect(find.text(strings.categoryCannotDelete), findsOneWidget);
    expect(await repo.getCategoryById(parentId), isNotNull);
    await tester.tap(find.byType(CloseButton));
    await idle(tester);
    await tester.tap(find.byType(BackButton));
    await idle(tester);
    final emptyId = await repo.createCategory(name: '空分类', kind: 'expense');
    await open(
        tester,
        CategoryEditPage(
            kind: 'expense', category: await repo.getCategoryById(emptyId)));
    await touch(tester, find.text(strings.categoryDeleteTitle));
    await tester.tap(find.text(strings.commonCancel));
    await idle(tester);
    expect(await repo.getCategoryById(emptyId), isNotNull);
    await touch(tester, find.text(strings.categoryDeleteTitle));
    await tester.tap(find.widgetWithText(BeeButton, strings.commonDelete));
    await idle(tester);
    expect(await repo.getCategoryById(emptyId), isNull);
    expect((await repo.getTransactionsByLedger(1)).length, 1);
    await close(tester);
  });
  testWidgets('父分类选择保留有子分类或无直接账单的规则，排除一级直属账单分类', (tester) async {
    final usedId = await repo.createCategory(name: '直接记账父分类', kind: 'expense');
    final emptyId = await repo.createCategory(name: '可选空分类', kind: 'expense');
    final parentId =
        await repo.createCategory(name: '已有二级父分类', kind: 'expense');
    await repo.createSubCategory(
        parentId: parentId, name: '已有子分类', kind: 'expense');
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 5,
        categoryId: usedId,
        happenedAt: DateTime(2026, 10, 24));
    await open(tester, const CategoryEditPage(kind: 'expense'));
    await touch(tester, find.text(l(tester).categorySubCategoryTitle));
    await touch(tester, find.text(l(tester).categoryParentCategoryHint));
    expect(find.text('直接记账父分类'), findsOneWidget);
    await tester.tap(find.text('直接记账父分类'));
    await idle(tester);
    expect(find.byType(BeeCategoryPicker), findsOneWidget);
    expect(
        tester
            .widget<BeeCategoryPicker>(find.byType(BeeCategoryPicker))
            .items
            .singleWhere((c) => c.label == '直接记账父分类')
            .enabled,
        isFalse);
    expect(find.text('可选空分类'), findsWidgets);
    expect(find.text('已有二级父分类'), findsWidgets);
    expect((await repo.getCategoryById(emptyId))!.parentId, isNull);
    await tester.tap(find.text('可选空分类').first);
    await idle(tester);
    await tester.enterText(find.byType(TextFormField), '筛选后的子分类');
    await touch(tester, find.text(l(tester).commonSave));
    expect((await repo.getSubCategories(emptyId)).single.name, '筛选后的子分类');
    await close(tester);
  });
  final frozenGeometry = jsonDecode(
      File('test/fixtures/v4-category-editor-geometry.json')
          .readAsStringSync()) as Map;
  for (final expected in frozenGeometry['geometry'] as List) {
    testWidgets('分类图标格对齐冻结 HTML ${expected['viewport']}', (tester) async {
      final size = (expected['viewport'] as String)
          .split('x')
          .map(double.parse)
          .toList();
      await open(tester, const CategoryEditPage(kind: 'expense'),
          size: Size(size[0], size[1]));
      await tester.ensureVisible(find.byType(BeeCategoryIconEditor));
      await tester.pump(const Duration(milliseconds: 300));
      final grid = find.byType(BeeIconChoiceGrid<String>);
      final first =
          find.descendant(of: grid, matching: find.byType(InkWell)).first;
      // HTML phone has a one-pixel border on each side; native safe area does not.
      expect(tester.getSize(grid).width,
          closeTo((expected['width'] as num).toDouble(), 2.1));
      expect(tester.getSize(first).width,
          closeTo((expected['cellWidth'] as num).toDouble(), 1));
      expect(tester.getSize(first).height,
          closeTo((expected['cellHeight'] as num).toDouble(), 1));
      expect(tester.widget<BeeIconChoiceGrid<String>>(grid).columns,
          expected['columns']);
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  }
  testWidgets('转账分类类型正确且小屏深色大字体保留保存及可滚动完整图标', (tester) async {
    final id = await repo.createCategory(
        name: '转账', kind: 'transfer', icon: 'swap_horiz');
    await open(
        tester,
        CategoryEditPage(
            kind: 'transfer', category: await repo.getCategoryById(id)),
        size: const Size(320, 568),
        scale: 1.4,
        brightness: Brightness.dark);
    expect(find.text(l(tester).transferTitle), findsWidgets);
    expect(find.text(l(tester).categoryIncomeType), findsNothing);
    expect(
        tester
            .getBottomRight(
                find.widgetWithText(BeeButton, l(tester).commonSave))
            .dy,
        lessThanOrEqualTo(568));
    await tester.ensureVisible(find.byType(BeeCategoryIconEditor));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
