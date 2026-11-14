import 'dart:io';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/settings/config_import_export_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/export/config_export_service.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OwnedPicker extends FilePicker {
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
                  name: 'owned.yml', path: path, size: File(path!).lengthSync())
            ]);
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FilePicker.platform = _OwnedPicker();
  });
  late BeeDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;
  late Directory owned;
  late FilePicker originalPicker;
  late _OwnedPicker picker;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'验收账本','CNY')");
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 12,
        currencyCode: 'USD',
        nativeAmount: 85.2,
        happenedAt: DateTime(2026, 10, 24));
    await repo.createCategory(name: '餐饮', kind: 'expense');
    await repo.createTag(name: '已有标签', color: '#aa8b29');
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1)
    ]);
    owned = await Directory.systemTemp.createTemp('beecount-config-widget-');
    originalPicker = FilePicker.platform;
    picker = _OwnedPicker();
    FilePicker.platform = picker;
  });
  tearDown(() async {
    FilePicker.platform = originalPicker;
    container.dispose();
    await db.close();
    await owned.delete(recursive: true);
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
            home: const ConfigImportExportPage())));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

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
    final visible = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .join(' | ');
    expect(target, findsWidgets, reason: visible);
  }

  AppLocalizations strings(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(ConfigImportExportPage)));
  testWidgets('八项真实导出选择使用规范弹窗，未选分类标签不会进入 YAML，取消不写数据库', (tester) async {
    final before = await repo.getTransactionsByLedger(1);
    await open(tester);
    final l = strings(tester);
    await tester.tap(find.text(l.configExportTitle));
    await tester.pumpAndSettle();
    expect(find.byType(BeeDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    final options = tester
        .widget<BeeConfigurationOptions>(find.byType(BeeConfigurationOptions));
    expect(options.items.length, 8);
    expect(options.selected.length, 8);
    for (final label in [l.configIncludeCategories, l.configIncludeTags]) {
      final row = find.descendant(
          of: find.byType(BeeConfigurationOptions), matching: find.text(label));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(l.commonNext));
    await ready(tester, find.byType(BeeConfigurationPreview));
    final preview = tester
        .widget<BeeConfigurationPreview>(find.byType(BeeConfigurationPreview));
    final info = ConfigExportService.detectContent(preview.content);
    expect(info.hasLedgers, isTrue);
    expect(info.hasCategories, isFalse);
    expect(info.hasTags, isFalse);
    expect(preview.content, contains('验收账本'));
    await tester.tap(find.text(l.commonCancel));
    await tester.pumpAndSettle();
    expect(await repo.getTransactionsByLedger(1), before);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('小屏大字导出列表滚动，主要操作始终可见，关闭不跳动或泄漏控制器', (tester) async {
    await open(tester, size: const Size(320, 568), scale: 1.4);
    final l = strings(tester);
    await tester.tap(find.text(l.configExportTitle));
    await tester.pumpAndSettle();
    final next = find.text(l.commonNext);
    expect(tester.getBottomRight(next).dy, lessThan(568));
    await tester.drag(
        find.byType(BeeConfigurationOptions), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(BeeDialog), findsNothing);
    await close(tester);
  });
  testWidgets('文件选择取消不改变业务数据，导入预览只提供文件中存在的内容', (tester) async {
    final before = await repo.getTransactionsByLedger(1);
    await open(tester);
    final l = strings(tester);
    await tester.tap(find.text(l.configImportTitle));
    await tester.pumpAndSettle();
    expect(find.byType(BeeDialog), findsNothing);
    final file = File('${owned.path}/owned.yml');
    await tester.runAsync(() => file.writeAsString(
        "version: 1\ntags:\n  items:\n    - name: 导入标签\n      color: '#219c9c'\n"));
    picker.path = file.path;
    await tester.tap(find.text(l.configImportTitle));
    await ready(tester, find.byType(BeeConfigurationOptions));
    final options = tester
        .widget<BeeConfigurationOptions>(find.byType(BeeConfigurationOptions));
    expect(options.items.map((x) => x.id), ['tags']);
    expect(options.selected, {'tags'});
    await tester.tap(find.text(l.commonCancel));
    await tester.pumpAndSettle();
    expect((await repo.getAllTags()).map((x) => x.name), ['已有标签']);
    expect(await repo.getTransactionsByLedger(1), before);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('导入确认调用真实配置服务，只新增所选标签并保留原账单和标签', (tester) async {
    final before = await repo.getTransactionsByLedger(1);
    final file = File('${owned.path}/owned.yml');
    await tester.runAsync(() => file.writeAsString(
        "version: 1\ntags:\n  items:\n    - name: 导入标签\n      color: '#219c9c'\n"));
    picker.path = file.path;
    await open(tester);
    final l = strings(tester);
    await tester.tap(find.text(l.configImportTitle));
    await ready(tester, find.byType(BeeConfigurationOptions));
    await tester.tap(find.text(l.configImportConfirmTitle));
    await ready(tester, find.text(l.configImportRestartTitle));
    expect((await repo.getAllTags()).map((x) => x.name),
        containsAll(['已有标签', '导入标签']));
    expect(await repo.getTransactionsByLedger(1), before);
    expect(find.text(l.configImportRestartTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
