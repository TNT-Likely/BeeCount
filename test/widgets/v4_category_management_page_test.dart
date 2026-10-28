import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/category/category_edit_page.dart';
import 'package:beecount/pages/category/category_manage_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CategoryPicker extends FilePicker {
  String? path;
  @override
  Future<FilePickerResult?> pickFiles(
          {String? dialogTitle,
          String? initialDirectory,
          FileType type = FileType.any,
          List<String>? allowedExtensions,
          Function(FilePickerStatus)? onFileLoading,
          bool allowCompression = true,
          int compressionQuality = 30,
          bool allowMultiple = false,
          bool withData = false,
          bool withReadStream = false,
          bool lockParentWindow = false,
          bool readSequential = false}) async =>
      path == null
          ? null
          : FilePickerResult([
              PlatformFile(
                  name: path!.split('/').last,
                  path: path,
                  size: File(path!).lengthSync())
            ]);
}

class _RetryCategories extends LocalRepository {
  _RetryCategories(super.db);
  bool fail = false;
  @override
  Future<List<Category>> getSubCategories(int parentId) async {
    if (fail) throw StateError('Synthetic child load failure');
    return super.getSubCategories(parentId);
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FilePicker.platform = _CategoryPicker();
  });
  late BeeDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;
  late FilePicker oldPicker;
  late _CategoryPicker picker;
  late Directory owned;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'生活','CNY')");
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
    ]);
    oldPicker = FilePicker.platform;
    picker = _CategoryPicker();
    FilePicker.platform = picker;
    owned =
        await Directory.systemTemp.createTemp('beecount-category-management-');
  });
  tearDown(() async {
    FilePicker.platform = oldPicker;
    container.dispose();
    await db.close();
    await owned.delete(recursive: true);
  });
  Future<void> ready(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (target.evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 300));
        return;
      }
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    expect(target, findsWidgets);
  }

  Future<void> open(WidgetTester tester,
      {int tab = 0,
      Size size = const Size(398, 844),
      Brightness brightness = Brightness.light,
      double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(brightness: brightness),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CategoryManagePage(initialTabIndex: tab))));
    await ready(tester, find.byType(BeeCategoryManagementList));
    await tester.pumpAndSettle();
  }

  AppLocalizations strings(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(CategoryManagePage)));
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }

  Future<void> tools(WidgetTester tester) async {
    await tester.tap(find.byTooltip(strings(tester).commonMore));
    await ready(tester, find.byType(BeeDialog));
  }

  Future<void> choose(WidgetTester tester, String text) async {
    await tester.tap(
        find.descendant(of: find.byType(BeeDialog), matching: find.text(text)));
    await tester.pumpAndSettle();
  }

  testWidgets('空态保留转账设置和工具，工具五项与原字段在规范弹窗内', (tester) async {
    await open(tester);
    final l = strings(tester);
    await ready(tester, find.text(l.transferIconSettings));
    expect(find.text(l.categoryEmpty), findsOneWidget);
    expect((await repo.getAllCategories()).where((c) => c.kind == 'transfer'),
        hasLength(1));
    final before = await repo.getAllCategories();
    await tools(tester);
    for (final title in [
      l.categoryShare,
      l.categoryNew,
      l.categoryImport,
      l.categoryGenerateDefault,
      l.categoryClearUnused
    ]) {
      expect(
          find.descendant(
              of: find.byType(BeeDialog), matching: find.text(title)),
          findsOneWidget);
    }
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(await repo.getAllCategories(), before);
    await tester.ensureVisible(find.text(l.transferIconSettings));
    await tester.tap(find.text(l.transferIconSettings));
    await tester.pumpAndSettle();
    expect(tester.widget<CategoryEditPage>(find.byType(CategoryEditPage)).kind,
        'transfer');
    await close(tester);
  });
  testWidgets('收入页新建保留收入类型，二级管理弹窗固定操作与真实子分类相连', (tester) async {
    final parent = await repo.createCategory(name: '合成餐饮', kind: 'expense');
    await repo.createCategory(
        name: '合成早餐', kind: 'expense', level: 2, parentId: parent);
    await open(tester, tab: 1);
    final l = strings(tester);
    await tester.tap(find.byTooltip(l.categoryNew));
    await tester.pumpAndSettle();
    expect(tester.widget<CategoryEditPage>(find.byType(CategoryEditPage)).kind,
        'income');
    await ready(tester, find.byType(BackButton));
    await tester.tap(find.byTooltip(l.commonBack));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.categoryExpense));
    await tester.pumpAndSettle();
    await tester.tap(find.text('合成餐饮'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.categoryManageChildren));
    await ready(tester, find.byType(BeeCategoryChildrenGrid));
    expect(find.text('合成早餐'), findsWidgets);
    expect(
        find.descendant(
            of: find.byType(BeeDialog), matching: find.text(l.commonAdd)),
        findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(BeeDialog), matching: find.text('合成早餐')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CategoryEditPage>(find.byType(CategoryEditPage))
            .category!
            .parentId,
        parent);
    await close(tester);
  });
  for (final hierarchical in [false, true]) {
    testWidgets('默认分类 $hierarchical 先取消不写入，再从生产界面实际生成当前收入类型', (tester) async {
      await open(tester, tab: 1);
      final l = strings(tester);
      final before = await repo.getAllCategories();
      await tools(tester);
      await choose(tester, l.categoryGenerateDefault);
      await ready(tester, find.byType(BeeRadioTile<bool>));
      await choose(tester, l.commonCancel);
      expect(await repo.getAllCategories(), before);
      await tools(tester);
      await choose(tester, l.categoryGenerateDefault);
      await ready(tester, find.byType(BeeRadioTile<bool>));
      if (hierarchical) {
        await tester.tap(find.text(l.categoryGenerateDefaultHierarchical));
        await tester.pumpAndSettle();
      }
      await choose(tester, l.commonConfirm);
      final rows = await repo.getAllCategories();
      final added =
          rows.where((row) => !before.any((old) => old.id == row.id)).toList();
      expect(added, isNotEmpty);
      expect(added.every((row) => row.kind == 'income'), true);
      expect(added.any((row) => row.parentId != null), hierarchical);
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  }
  testWidgets('拖动可见把手立即排序并持久化，收入类型和子分类关系保持不变', (tester) async {
    final first =
        await repo.createCategory(name: '排序甲', kind: 'expense', sortOrder: 0);
    final second =
        await repo.createCategory(name: '排序乙', kind: 'expense', sortOrder: 1);
    final child = await repo.createCategory(
        name: '排序子级', kind: 'expense', level: 2, parentId: first, sortOrder: 7);
    final income =
        await repo.createCategory(name: '保留收入', kind: 'income', sortOrder: 9);
    await open(tester);
    final handle = find.byType(ReorderableDragStartListener).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 20));
    for (var step = 0; step < 10; step++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    final rows = await repo.getAllCategories();
    expect(rows.singleWhere((c) => c.id == first).sortOrder, 1);
    expect(rows.singleWhere((c) => c.id == second).sortOrder, 0);
    expect(rows.singleWhere((c) => c.id == child).parentId, first);
    expect(rows.singleWhere((c) => c.id == child).sortOrder, 7);
    expect(rows.singleWhere((c) => c.id == income).sortOrder, 9);
    container.invalidate(categoriesWithCountProvider);
    await ready(tester, find.text('排序乙'));
    expect(tester.getTopLeft(find.text('排序乙')).dy,
        lessThan(tester.getTopLeft(find.text('排序甲')).dy));
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('清理未使用分类取消不写入，确认保留有账单的父子分类及原账单', (tester) async {
    final parent = await repo.createCategory(name: '有账单的父级', kind: 'expense');
    final child = await repo.createCategory(
        name: '有账单的子级', kind: 'expense', level: 2, parentId: parent);
    final unused = await repo.createCategory(name: '待清理父级', kind: 'expense');
    final unusedChild = await repo.createCategory(
        name: '待清理子级', kind: 'expense', level: 2, parentId: unused);
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 12,
        categoryId: child,
        happenedAt: DateTime(2026, 10, 24));
    final tx = await repo.getTransactionsByLedger(1);
    await open(tester);
    final l = strings(tester);
    final before = await repo.getAllCategories();
    await tools(tester);
    await choose(tester, l.categoryClearUnused);
    await ready(tester, find.text(l.categoryClearUnusedTitle));
    final content = tester
        .widgetList<Text>(find.descendant(
            of: find.byType(BeeDialog), matching: find.byType(Text)))
        .map((v) => v.data ?? '')
        .join(' ');
    expect(content, contains('待清理父级'));
    expect(content.contains('有账单的父级'), false);
    expect(content.contains('有账单的子级'), false);
    await choose(tester, l.commonCancel);
    expect(await repo.getAllCategories(), before);
    await tools(tester);
    await choose(tester, l.categoryClearUnused);
    await ready(tester, find.text(l.categoryClearUnusedTitle));
    await choose(tester, l.commonDelete);
    final remaining = (await repo.getAllCategories()).map((v) => v.id).toSet();
    expect(remaining.containsAll([parent, child]), true);
    expect(remaining.contains(unused), false);
    expect(remaining.contains(unusedChild), false);
    expect(await repo.getTransactionsByLedger(1), tx);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('320短屏深色大字体保留头部、空态、转账与工具弹窗', (tester) async {
    await open(tester,
        size: const Size(320, 568),
        brightness: Brightness.dark,
        textScale: 1.4);
    final l = strings(tester);
    await ready(tester, find.text(l.transferIconSettings));
    expect(find.byTooltip(l.categoryNew), findsOneWidget);
    await tester.ensureVisible(find.text(l.transferIconSettings));
    await tools(tester);
    await tester.ensureVisible(find.text(l.categoryClearUnused));
    expect(find.byType(BeeDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('二级分类仓库异常进入规范重试，重试实际加载并保留原数据', (tester) async {
    final parent = await repo.createCategory(name: '重试父级', kind: 'expense');
    await repo.createCategory(
        name: '重试子级', kind: 'expense', level: 2, parentId: parent);
    final retry = _RetryCategories(db);
    repo = retry;
    container.dispose();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService())
    ]);
    await open(tester);
    final l = strings(tester);
    final before = await repo.getAllCategories();
    retry.fail = true;
    await tester.tap(find.text('重试父级'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.categoryManageChildren));
    await ready(tester, find.text(l.helpCenterRetry));
    expect(find.byType(BeeDialog), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    retry.fail = false;
    await tester.tap(find.text(l.helpCenterRetry));
    await ready(tester, find.byType(BeeCategoryChildrenGrid));
    expect(
        find.descendant(
            of: find.byType(BeeDialog), matching: find.text('重试子级')),
        findsOneWidget);
    expect(await repo.getAllCategories(), before);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  for (final overwrite in [false, true]) {
    testWidgets('真实 ZIP ${overwrite ? '覆盖' : '合并'}导入保存父子关系，保护已用分类及账单',
        (tester) async {
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => owned.path);
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      final parent = await repo.createCategory(name: '保留父级', kind: 'expense');
      final child = await repo.createCategory(
          name: '保留子级', kind: 'expense', level: 2, parentId: parent);
      final unused = await repo.createCategory(name: '未用收入', kind: 'income');
      await repo.addTransaction(
          ledgerId: 1,
          type: 'expense',
          amount: 17,
          categoryId: child,
          happenedAt: DateTime(2026, 10, 24));
      final beforeTransactions = await repo.getTransactionsByLedger(1);
      final bytes = utf8.encode(jsonEncode({
        'version': 1,
        'categories': [
          {'name': '包内父级', 'kind': 'expense', 'level': 1, 'icon': 'restaurant'},
          {
            'name': '包内子级',
            'kind': 'expense',
            'level': 2,
            'parent_name': '包内父级',
            'icon': 'local_cafe'
          },
        ]
      }));
      final archive = Archive()
        ..addFile(ArchiveFile('categories.yaml', bytes.length, bytes));
      final zip = File('${owned.path}/synthetic.zip');
      await tester
          .runAsync(() => zip.writeAsBytes(ZipEncoder().encode(archive)!));
      picker.path = zip.path;
      await open(tester);
      final l = strings(tester);
      await tools(tester);
      await choose(tester, l.categoryImport);
      await ready(tester, find.text(l.categoryImportModeTitle));
      await choose(
          tester,
          overwrite
              ? l.categoryImportModeOverwrite
              : l.categoryImportModeMerge);
      await ready(tester, find.text('包内父级'));
      final rows = await repo.getAllCategories();
      expect(rows.any((c) => c.id == unused), !overwrite);
      expect(rows.singleWhere((c) => c.id == child).parentId, parent);
      final importedParent = rows.singleWhere((c) => c.name == '包内父级');
      expect(rows.singleWhere((c) => c.name == '包内子级').parentId,
          importedParent.id);
      expect(await repo.getTransactionsByLedger(1), beforeTransactions);
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  }
  testWidgets('导入选择取消、无效扩展名和模式取消均保持原分类及账单', (tester) async {
    await repo.createCategory(name: '合成已有', kind: 'expense');
    await open(tester);
    final l = strings(tester);
    final before = await repo.getAllCategories();
    await tools(tester);
    await choose(tester, l.categoryImport);
    expect(await repo.getAllCategories(), before);
    final file = File('${owned.path}/owned.txt');
    await tester.runAsync(() => file.writeAsString('owned'));
    picker.path = file.path;
    await tools(tester);
    await choose(tester, l.categoryImport);
    await ready(tester, find.text(l.categoryImportInvalidFile));
    final zip = File('${owned.path}/owned.zip');
    await tester.runAsync(() => zip.writeAsBytes([]));
    picker.path = zip.path;
    await tools(tester);
    await choose(tester, l.categoryImport);
    await ready(tester, find.text(l.categoryImportModeTitle));
    expect(find.text(l.categoryImportModeMerge), findsOneWidget);
    expect(find.text(l.categoryImportModeOverwrite), findsOneWidget);
    await choose(tester, l.commonCancel);
    expect(await repo.getAllCategories(), before);
    expect(await repo.getTransactionsByLedger(1), isEmpty);
    await close(tester);
  });
}
