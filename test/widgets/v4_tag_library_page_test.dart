import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/tag/tag_manage_page.dart';
import 'package:beecount/presentation/v4/bindings/tag_library_files.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/export/config_export_service.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TagLibraryPageRepo extends LocalRepository {
  TagLibraryPageRepo(super.db);
  bool failImport = false, failWatchOnce = false;
  @override
  Future<void> batchInsertTags(List<TagsCompanion> rows) async {
    if (failImport) throw StateError('Synthetic import failure');
    await super.batchInsertTags(rows);
  }

  @override
  Stream<List<({Tag tag, int transactionCount})>> watchTagsWithStats() {
    if (failWatchOnce) {
      failWatchOnce = false;
      return Stream.error(StateError('Synthetic watch failure'));
    }
    return super.watchTagsWithStats();
  }
}

class TagLibraryTestFiles extends TagLibraryFiles {
  String? selection;
  String content =
      'tags:\n  items:\n    - name: Imported\n      color: "#219c9c"\n';
  final List<String> exports = [];
  @override
  Future<String?> pick() async => selection;
  @override
  Future<String> read(String path) async => content;
  @override
  Future<String?> share(String yaml, String subject) async {
    exports.add(yaml);
    return 'Download/BeeCount/qa-tags.yml';
  }
}

void main() {
  late BeeDatabase db;
  late TagLibraryPageRepo repo;
  late ProviderContainer container;
  late TagLibraryTestFiles files;
  late int used, unused, tx;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = TagLibraryPageRepo(db);
    files = TagLibraryTestFiles();
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'日常生活','CNY')");
    used = await repo.createTag(name: '已使用', color: '#219c9c');
    unused = await repo.createTag(name: '未使用', color: '#aa8b29');
    tx = await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 12,
        happenedAt: DateTime(2026, 10, 24));
    await repo.addTagToTransaction(transactionId: tx, tagId: used);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo)
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> open(WidgetTester t, {bool compact = false}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = compact ? const Size(320, 568) : const Size(398, 844);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(
                brightness: compact ? Brightness.dark : Brightness.light),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(compact ? 1.4 : 1)),
                child: child!),
            home: TagManagePage(files: files))));
    await t.pumpAndSettle();
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
  }

  Future<void> tool(WidgetTester t, String label) async {
    await t.tap(find.byTooltip('更多'));
    await t.pumpAndSettle();
    await t.tap(find.text(label).last);
    await t.pumpAndSettle();
  }

  testWidgets('真实计数与原标签颜色，独立删除取消/确认不丢账单', (t) async {
    await open(t);
    final library = t.widget<BeeTagLibrary>(find.byType(BeeTagLibrary));
    expect(library.items.singleWhere((x) => x.tag.id == '$used').count, '1笔');
    expect(library.items.singleWhere((x) => x.tag.id == '$unused').count, '0笔');
    await t.tap(find.byTooltip('删除 未使用'));
    await t.pumpAndSettle();
    expect(find.byType(BeeDialog), findsOneWidget);
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();
    expect(await repo.getTagById(unused), isNotNull);
    await t.tap(find.byTooltip('删除 未使用'));
    await t.pumpAndSettle();
    await t.tap(find.text('删除').last);
    await t.pumpAndSettle();
    expect(await repo.getTagById(unused), isNull);
    expect((await repo.getTagsForTransaction(tx)).single.id, used);
    expect(await repo.getTransactionsByLedger(1), hasLength(1));
    await close(t);
  });
  testWidgets('分享调用原YAML服务并仅导出标签，平台文件适配独立', (t) async {
    await open(t);
    await t.tap(find.byTooltip('分享标签'));
    await t.pumpAndSettle();
    expect(files.exports, hasLength(1));
    final info = ConfigExportService.detectContent(files.exports.single);
    expect(info.hasTags, isTrue);
    expect(info.hasLedgers, isFalse);
    expect(info.hasAi, isFalse);
    expect((await repo.getAllTags()), hasLength(2));
    await close(t);
  });
  testWidgets('导入选择取消与模式取消不写，合并确认用真实仓储', (t) async {
    await open(t);
    await tool(t, '导入标签');
    expect((await repo.getAllTags()), hasLength(2));
    files.selection = '/qa.yml';
    await tool(t, '导入标签');
    expect(find.text('选择导入模式'), findsOneWidget);
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();
    expect((await repo.getAllTags()), hasLength(2));
    await tool(t, '导入标签');
    await t.tap(find.text('合并'));
    await t.pumpAndSettle();
    expect(await repo.getTagByName('Imported'), isNotNull);
    expect((await repo.getAllTags()), hasLength(3));
    expect(await repo.getTransactionsByLedger(1), hasLength(1));
    await close(t);
  });
  testWidgets('覆盖写入失败回滚，重试只清未使用并保留已用关系', (t) async {
    files.selection = '/qa.yaml';
    repo.failImport = true;
    await open(t);
    await tool(t, '导入标签');
    await t.tap(find.text('覆盖'));
    await t.pumpAndSettle();
    expect(await repo.getTagById(unused), isNotNull);
    expect(await repo.getTagById(used), isNotNull);
    repo.failImport = false;
    await tool(t, '导入标签');
    await t.tap(find.text('覆盖'));
    await t.pumpAndSettle();
    expect(await repo.getTagById(unused), isNull);
    expect(await repo.getTagById(used), isNotNull);
    expect(await repo.getTagByName('Imported'), isNotNull);
    expect((await repo.getTagsForTransaction(tx)).single.id, used);
    await close(t);
  });
  testWidgets('长列表工具弹窗取消保持滚动位置，320深色140%可操作', (t) async {
    for (var i = 0; i < 50; i++) {
      await repo.createTag(name: '长标签$i', color: '#219c9c');
    }
    await open(t, compact: true);
    final scroll = find.descendant(
        of: find.byType(BeeTagLibrary), matching: find.byType(Scrollable));
    await t.drag(scroll, const Offset(0, -600));
    await t.pumpAndSettle();
    final before = t.state<ScrollableState>(scroll).position.pixels;
    expect(before, greaterThan(0));
    await tool(t, '生成默认标签');
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();
    expect(t.state<ScrollableState>(scroll).position.pixels, before);
    expect(t.takeException(), isNull);
    await close(t);
  });
  testWidgets('真实流读取失败可重试，空态保留默认生成入口', (t) async {
    repo.failWatchOnce = true;
    await open(t);
    expect(find.text('重试'), findsOneWidget);
    await t.tap(find.text('重试'));
    await t.pumpAndSettle();
    expect(find.byType(BeeTagLibrary), findsOneWidget);
    await close(t);
    await repo.deleteTag(used);
    await repo.deleteTag(unused);
    await open(t);
    expect(find.text('暂无标签'), findsOneWidget);
    await t.tap(find.text('生成默认标签'));
    await t.pumpAndSettle();
    await t.tap(find.text(
        AppLocalizations.of(t.element(find.byType(TagManagePage)))
            .commonConfirm));
    await t.pumpAndSettle();
    expect((await repo.getAllTags()).length, greaterThan(10));
    expect(await repo.getTransactionsByLedger(1), hasLength(1));
    await close(t);
  });
}
