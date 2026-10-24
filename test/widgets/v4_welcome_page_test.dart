import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/auth/welcome_page.dart';
import 'package:beecount/providers.dart';
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
                  name: File(path!).uri.pathSegments.last,
                  path: path,
                  size: File(path!).lengthSync())
            ]);
}

class _SeedDatabase extends BeeDatabase {
  _SeedDatabase() : super.forTesting(NativeDatabase.memory());
  bool failAfterSeed = false;
  @override
  Future<void> ensureSeed(
      {AppLocalizations? l10n,
      String currency = 'CNY',
      bool useHierarchicalCategories = false,
      bool skipCategories = false,
      bool createDefaultLedger = true}) async {
    await super.ensureSeed(
        l10n: l10n,
        currency: currency,
        useHierarchicalCategories: useHierarchicalCategories,
        skipCategories: skipCategories,
        createDefaultLedger: createDefaultLedger);
    if (failAfterSeed) {
      throw StateError('synthetic seed failure after real writes');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => FilePicker.platform = _OwnedPicker());
  late _SeedDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;
  late Directory owned;
  late FilePicker previousPicker;
  late _OwnedPicker picker;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = _SeedDatabase();
    repo = LocalRepository(db);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo)
    ]);
    container.read(shouldShowWelcomeProvider.notifier).state = true;
    owned = await Directory.systemTemp.createTemp('beecount-welcome-widget-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => owned.path);
    previousPicker = FilePicker.platform;
    picker = _OwnedPicker();
    FilePicker.platform = picker;
  });
  tearDown(() async {
    FilePicker.platform = previousPicker;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    container.dispose();
    await db.close();
    await owned.delete(recursive: true);
  });
  Future<void> open(WidgetTester t,
      {Size size = const Size(398, 844),
      double scale = 1,
      Brightness brightness = Brightness.light}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Consumer(
            builder: (context, ref, _) => MaterialApp(
                  theme: beeTheme(brightness: brightness),
                  locale: ref.watch(languageProvider) ?? const Locale('zh'),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!),
                  home: const WelcomePage(),
                ))));
    await t.pumpAndSettle();
  }

  AppLocalizations l(WidgetTester t) =>
      AppLocalizations.of(t.element(find.byType(WelcomePage)));
  Future<void> tap(WidgetTester t, String value) async {
    final target = find.text(value).hitTestable().first;
    await t.tap(target);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  Future<void> step(WidgetTester t, int target) async {
    final controller = t.widget<PageView>(find.byType(PageView)).controller!;
    while (controller.page!.round() < target) {
      await tap(t, l(t).commonNext);
    }
    while (controller.page!.round() > target) {
      await tap(t, l(t).commonPrevious);
    }
  }

  Future<void> settled(WidgetTester t, bool Function() ready) async {
    for (var i = 0; i < 100; i++) {
      await t.pump(const Duration(milliseconds: 20));
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      if (ready()) {
        await t.pumpAndSettle();
        return;
      }
    }
    expect(ready(), true);
  }

  Future<void> finish(WidgetTester t) async {
    await step(t, 4);
    await tap(t, l(t).commonFinish);
    await settled(t, () => !container.read(shouldShowWelcomeProvider));
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 4));
  }

  testWidgets('五步导航保留货币和分类草稿，完成前不写数据库', (t) async {
    await open(t);
    expect(find.byType(BeeOnboardingChoice), findsNWidgets(5));
    await step(t, 1);
    await tap(t, '美元');
    await step(t, 2);
    await tap(t, l(t).welcomeCategoryModeNoneTitle);
    await step(t, 0);
    await step(t, 1);
    final selected = t
        .widgetList<BeeOnboardingChoice>(find.byType(BeeOnboardingChoice))
        .where((w) => w.selected);
    expect(selected.single.subtitle, 'USD');
    expect(await repo.getAllLedgers(), isEmpty);
    expect(await repo.getAllCategories(), isEmpty);
    expect((await SharedPreferences.getInstance()).getBool('welcome_shown'),
        isNull);
    await close(t);
  });
  testWidgets('美元且不创建账本和分类时保留原虚拟转账分类，不擅自生成账本', (t) async {
    await open(t);
    await step(t, 1);
    await tap(t, '美元');
    await t.tap(find.byType(CheckboxListTile));
    await t.pumpAndSettle();
    await step(t, 2);
    await tap(t, l(t).welcomeCategoryModeNoneTitle);
    await finish(t);
    expect(await repo.getAllLedgers(), isEmpty);
    expect((await repo.getAllCategories()).where((c) => c.kind != 'transfer'),
        isEmpty);
    final p = await SharedPreferences.getInstance();
    expect(p.getString('category_mode'), 'none');
    expect(p.getString('selected_currency'), 'USD');
    expect(p.getString('baseCurrency'), 'USD');
    expect(p.getBool('welcome_shown'), true);
    expect(container.read(baseCurrencyProvider), 'USD');
    await close(t);
  });
  testWidgets('默认一级分类和人民币账本通过原SeedService创建，重复完成不重复新增', (t) async {
    await open(t);
    await finish(t);
    final ledgers = await repo.getAllLedgers(),
        categories = await repo.getAllCategories();
    expect(ledgers.single.currency, 'CNY');
    expect(categories.where((c) => c.kind == 'expense'), isNotEmpty);
    expect(categories.every((c) => c.parentId == null), true);
    final button = find.widgetWithText(BeeButton, l(t).commonFinish);
    expect(t.widget<BeeButton>(button).onPressed, isNull);
    await t.tap(button, warnIfMissed: false);
    await t.pump();
    expect(await repo.getAllLedgers(), ledgers);
    expect(await repo.getAllCategories(), categories);
    await close(t);
  });
  testWidgets('初始化数据库失败整批回滚，完成标记不提前写入且可原位重试', (t) async {
    db.failAfterSeed = true;
    await open(t);
    await step(t, 4);
    await tap(t, l(t).commonFinish);
    await settled(
        t,
        () =>
            t
                .widget<BeeButton>(
                    find.widgetWithText(BeeButton, l(t).commonFinish))
                .onPressed !=
            null);
    expect(await repo.getAllLedgers(), isEmpty);
    expect(await repo.getAllCategories(), isEmpty);
    expect((await SharedPreferences.getInstance()).getBool('welcome_shown'),
        isNull);
    expect(container.read(shouldShowWelcomeProvider), true);
    db.failAfterSeed = false;
    await finish(t);
    expect((await repo.getAllLedgers()).length, 1);
    expect(
        (await SharedPreferences.getInstance()).getBool('welcome_shown'), true);
    await close(t);
  });
  testWidgets('更多币种保留全部151种、搜索取消不改草稿，泰铢进入常用网格', (t) async {
    await open(t);
    await step(t, 1);
    final text = l(t);
    await tap(t, text.ledgersSelectCurrency);
    expect(
        t
            .widget<BeeCurrencyPicker>(find.byType(BeeCurrencyPicker))
            .currencies
            .length,
        151);
    await t.enterText(find.byType(TextField), 'THB');
    await t.pumpAndSettle();
    await t.tap(find.byTooltip(text.commonClose));
    await t.pumpAndSettle();
    expect(
        t
            .widgetList<BeeOnboardingChoice>(find.byType(BeeOnboardingChoice))
            .where((w) => w.selected)
            .single
            .subtitle,
        'CNY');
    await tap(t, text.ledgersSelectCurrency);
    await t.enterText(find.byType(TextField), 'THB');
    await t.pumpAndSettle();
    final thai = t
        .widget<BeeCurrencyPicker>(find.byType(BeeCurrencyPicker))
        .currencies
        .singleWhere((c) => c.code == 'THB');
    await tap(t, '${thai.name} (THB)');
    await t.pumpAndSettle();
    expect(
        t
            .widgetList<BeeOnboardingChoice>(find.byType(BeeOnboardingChoice))
            .where((w) => w.selected)
            .single
            .subtitle,
        'THB');
    expect((await SharedPreferences.getInstance()).getString('baseCurrency'),
        isNull);
    expect(await repo.getAllLedgers(), isEmpty);
    await close(t);
  });
  testWidgets('二级分类真实建立父子身份，默认币种选择保留', (t) async {
    await open(t);
    await step(t, 1);
    await tap(t, '欧元');
    await step(t, 2);
    await tap(t, l(t).welcomeCategoryModeHierarchicalTitle);
    await finish(t);
    final cats = await repo.getAllCategories();
    expect(cats.any((c) => c.parentId != null), true);
    expect((await repo.getAllLedgers()).single.currency, 'EUR');
    expect((await SharedPreferences.getInstance()).getString('category_mode'),
        'hierarchical');
    await close(t);
  });
  testWidgets('切换语言使用真实持久偏好，无初始化副作用', (t) async {
    await open(t);
    await tap(t, 'English');
    expect(container.read(languageProvider), const Locale('en'));
    expect(
        (await SharedPreferences.getInstance()).getString('selected_language'),
        'en');
    expect(find.text('Next'), findsOneWidget);
    await tap(t, l(t).languageChinese);
    expect(container.read(languageProvider), const Locale('zh'));
    expect(await repo.getAllLedgers(), isEmpty);
    await close(t);
  });
  testWidgets('恢复页文件取消不导入，实际标签导入后可跳过附件且不自动建账本', (t) async {
    await open(t);
    final text = l(t);
    await tap(t,
        '${text.welcomeExistingUserTitle} ${text.welcomeExistingUserButton}');
    expect(find.text(text.welcomeRestoreTitle), findsOneWidget);
    await tap(t, text.welcomeSelectBackup);
    expect(await repo.getAllTags(), isEmpty);
    expect(
        t
            .widget<BeeButton>(
                find.widgetWithText(BeeButton, text.welcomeRestoreContinue))
            .onPressed,
        isNull);
    final file = File('${owned.path}/owned.yml');
    await t.runAsync(() => file.writeAsString(
        "version: 1\ntags:\n  items:\n    - name: 初始化导入标签\n      color: '#219c9c'\n"));
    picker.path = file.path;
    await tap(t, text.welcomeSelectBackup);
    expect(await repo.getAllTags(), isEmpty);
    await tap(t, text.welcomeRestoreContinue);
    await settled(
        t,
        () =>
            find.text(text.welcomeImportAttachmentTitle).evaluate().isNotEmpty);
    expect((await repo.getAllTags()).single.name, '初始化导入标签');
    expect(await repo.getAllLedgers(), isEmpty);
    await tap(t, text.welcomeImportAttachmentSkip);
    expect(container.read(shouldShowWelcomeProvider), false);
    await close(t);
  });
  testWidgets('附件选择是草稿，无效归档可重试，原TAR.GZ格式实际导入后完成', (t) async {
    await open(t);
    final text = l(t);
    await tap(t,
        '${text.welcomeExistingUserTitle} ${text.welcomeExistingUserButton}');
    final config = File('${owned.path}/owned.yml');
    await t.runAsync(() => config.writeAsString('version: 1\n'));
    picker.path = config.path;
    await tap(t, text.welcomeSelectBackup);
    await tap(t, text.welcomeRestoreContinue);
    await settled(
        t,
        () =>
            find.text(text.welcomeImportAttachmentTitle).evaluate().isNotEmpty);
    final action =
        find.widgetWithText(BeeButton, text.welcomeImportAttachmentButton);
    expect(t.widget<BeeButton>(action).onPressed, isNull);
    final invalid = File('${owned.path}/invalid.tar.gz');
    await t.runAsync(() => invalid.writeAsString('invalid archive'));
    picker.path = invalid.path;
    await tap(t, text.welcomeSelectBackup);
    expect(container.read(shouldShowWelcomeProvider), true);
    await tap(t, text.welcomeImportAttachmentButton);
    await settled(t, () => t.widget<BeeButton>(action).onPressed != null);
    expect(container.read(shouldShowWelcomeProvider), true);
    final metadata =
        utf8.encode(jsonEncode({'version': 3, 'attachments': [], 'count': 0}));
    final archive = Archive()
      ..addFile(ArchiveFile('metadata.json', metadata.length, metadata));
    final valid = File('${owned.path}/owned.tar.gz');
    await t.runAsync(() => valid
        .writeAsBytes(GZipEncoder().encode(TarEncoder().encode(archive))!));
    picker.path = valid.path;
    await tap(t, text.welcomeSelectBackup);
    await tap(t, text.welcomeImportAttachmentButton);
    await settled(t, () => !container.read(shouldShowWelcomeProvider));
    expect(await repo.getAllLedgers(), isEmpty);
    expect(await repo.getAllTags(), isEmpty);
    await close(t);
  });
  testWidgets('无效配置拒绝后停留恢复页并允许重试，不写数据', (t) async {
    await open(t);
    final text = l(t);
    await tap(t,
        '${text.welcomeExistingUserTitle} ${text.welcomeExistingUserButton}');
    final f = File('${owned.path}/owned.yml');
    await t.runAsync(() => f.writeAsString('invalid: [\n'));
    picker.path = f.path;
    await tap(t, text.welcomeSelectBackup);
    await tap(t, text.welcomeRestoreContinue);
    await settled(
        t,
        () =>
            t
                .widget<BeeButton>(
                    find.widgetWithText(BeeButton, text.welcomeRestoreContinue))
                .onPressed !=
            null);
    expect(find.text(text.welcomeRestoreTitle), findsOneWidget);
    expect(await repo.getAllTags(), isEmpty);
    expect(await repo.getAllLedgers(), isEmpty);
    expect((await SharedPreferences.getInstance()).getBool('welcome_shown'),
        isNull);
    await close(t);
  });
  testWidgets('320深色140%五步均可滚动，主要动作固定可见且无横向溢出', (t) async {
    await open(t,
        size: const Size(320, 568), scale: 1.4, brightness: Brightness.dark);
    for (var i = 0; i < 5; i++) {
      await step(t, i);
      final label = i == 4 ? l(t).commonFinish : l(t).commonNext;
      final rect =
          t.getRect(find.widgetWithText(BeeButton, label).hitTestable());
      expect(rect.bottom, lessThanOrEqualTo(568));
      expect(t.takeException(), isNull);
    }
    await close(t);
  });
}
