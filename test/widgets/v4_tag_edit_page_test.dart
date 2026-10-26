import 'dart:async';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/tag/tag_edit_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TagEditorTestRepository extends LocalRepository {
  TagEditorTestRepository(super.db);
  bool failCreate = false;
  int creates = 0;
  Completer<bool>? duplicateGate;
  @override
  Future<bool> isTagNameDuplicate({required String name, int? excludeId}) =>
      duplicateGate?.future ??
      super.isTagNameDuplicate(name: name, excludeId: excludeId);
  @override
  Future<int> createTag(
      {required String name,
      String? color,
      int sortOrder = 0,
      String? syncId}) {
    creates++;
    if (failCreate) {
      failCreate = false;
      throw StateError('Synthetic write failure');
    }
    return super.createTag(
        name: name, color: color, sortOrder: sortOrder, syncId: syncId);
  }
}

void main() {
  late BeeDatabase db;
  late TagEditorTestRepository repo;
  late ProviderContainer container;
  Tag? result;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = TagEditorTestRepository(db);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 0)
    ]);
    result = null;
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> open(WidgetTester t, {Tag? tag, bool compact = false}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = compact ? const Size(320, 568) : const Size(398, 844);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
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
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () async {
                          result = await Navigator.push<Tag>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => TagEditPage(tag: tag)));
                        },
                        child: const Text('打开')))))));
    await t.tap(find.text('打开'));
    await t.pumpAndSettle();
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
  }

  testWidgets('新建保留20色与已保存Tag返回值，颜色从真实选择回调写入', (t) async {
    await open(t);
    expect(
        t
            .widget<BeeColorPalette<String>>(
                find.byType(BeeColorPalette<String>))
            .items,
        hasLength(20));
    await t.enterText(find.byType(TextFormField), '  出行  ');
    await t.tap(find.byTooltip('标签颜色 #FF5722'));
    await t.tap(find.text('保存'));
    await t.pumpAndSettle();
    expect(result!.name, '出行');
    expect(result!.color, '#FF5722');
    expect((await repo.getAllTags()).single.id, result!.id);
    await close(t);
  });
  testWidgets('编辑保留原自定义颜色，取消不写，保存保持身份', (t) async {
    final id = await repo.createTag(name: '旅行', color: '#219c9c'),
        original = (await repo.getAllTags()).single;
    await open(t, tag: original);
    expect(t.widget<BeeTag>(find.byType(BeeTag)).tag.color,
        const Color(0xff219c9c));
    await t.enterText(find.byType(TextFormField), '取消草稿');
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect((await repo.getAllTags()).single, original);
    await close(t);
    await open(t, tag: original);
    await t.enterText(find.byType(TextFormField), '新的旅行');
    await t.tap(find.text('保存'));
    await t.pumpAndSettle();
    expect(result!.id, id);
    expect(result!.color, '#219c9c');
    expect((await repo.getAllTags()).single.name, '新的旅行');
    await close(t);
  });
  testWidgets('必填和重复名称守卫不写入，重复保存保留草稿', (t) async {
    await repo.createTag(name: '重复');
    repo.creates = 0;
    await open(t);
    await t.tap(find.text('保存'));
    await t.pumpAndSettle();
    expect(repo.creates, 0);
    await t.enterText(find.byType(TextFormField), '重复');
    await t.tap(find.text('保存'));
    await t.pumpAndSettle();
    expect(repo.creates, 0);
    expect(find.byType(TagEditPage), findsOneWidget);
    expect((await repo.getAllTags()), hasLength(1));
    await close(t);
  });
  testWidgets('重复检查期间防止双击提交，成功只创建一次', (t) async {
    repo.duplicateGate = Completer<bool>();
    await open(t);
    await t.enterText(find.byType(TextFormField), '唯一');
    await t.tap(find.text('保存'));
    await t.pump();
    await t.tap(find.text('保存'));
    await t.pump();
    expect(repo.creates, 0);
    repo.duplicateGate!.complete(false);
    await t.pumpAndSettle();
    expect(repo.creates, 1);
    expect((await repo.getAllTags()), hasLength(1));
    await close(t);
  });
  testWidgets('写入失败保留名称与颜色，重试只保存一个实际标签', (t) async {
    repo.failCreate = true;
    await open(t);
    await t.enterText(find.byType(TextFormField), '重试草稿');
    await t.tap(find.byTooltip('标签颜色 #009688'));
    await t.tap(find.text('保存'));
    await t.pumpAndSettle();
    expect(await repo.getAllTags(), isEmpty);
    expect(find.byType(TagEditPage), findsOneWidget);
    await t.tap(find.text('保存'));
    await t.pumpAndSettle();
    expect(result!.name, '重试草稿');
    expect(result!.color, '#009688');
    expect((await repo.getAllTags()), hasLength(1));
    await close(t);
  });
  testWidgets('320深色140%与完整20个字素名称保留', (t) async {
    await open(t, compact: true);
    final name = List.filled(20, '🐝').join();
    await t.enterText(find.byType(TextFormField), name);
    await t.ensureVisible(find.byTooltip('标签颜色 #536DFE'));
    await t.tap(find.byTooltip('标签颜色 #536DFE'));
    expect(t.takeException(), isNull);
    await t.tap(find.text('保存'));
    await t.pumpAndSettle();
    expect(result!.name, name);
    expect(result!.color, '#536DFE');
    await close(t);
  });
}
