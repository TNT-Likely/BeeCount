import 'dart:convert';
import 'dart:io';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/settings/header_skin_page.dart';
import 'package:beecount/pages/settings/appearance/bindings/skin_choices.dart';
import 'package:beecount/dev/component_gallery/bindings/skin_preview.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/styles/header_skins.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final legacy =
      (jsonDecode(File('test/fixtures/v4-skins-legacy.json').readAsStringSync())
          as Map)['options'] as List;
  late BeeDatabase db;
  late ProviderContainer container;
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'auto_sync': false,
      'primaryColor': 0xff123456,
      'userChosenPrimaryColor': 0xff123456
    });
    prefs = await SharedPreferences.getInstance();
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'皮肤验收','CNY')");
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(LocalRepository(db))
    ]);
    await container.read(primaryColorInitProvider.future);
    await container.read(headerSkinInitProvider.future);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> mount(WidgetTester t,
      {bool compact = false, Widget child = const HeaderSkinPage()}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = compact ? const Size(320, 568) : const Size(398, 844);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Consumer(
            builder: (c, ref, _) => MaterialApp(
                theme: beeTheme(
                    accent: ref.watch(primaryColorProvider),
                    brightness: compact ? Brightness.dark : Brightness.light),
                locale: Locale(compact ? 'en' : 'zh'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                builder: (c, w) => MediaQuery(
                    data: MediaQuery.of(c).copyWith(
                        textScaler: TextScaler.linear(compact ? 1.4 : 1),
                        disableAnimations: true,
                        padding: const EdgeInsets.only(top: 24)),
                    child: w!),
                home: Scaffold(body: child)))));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
  }

  AppLocalizations l(WidgetTester t) =>
      AppLocalizations.of(t.element(find.byType(HeaderSkinPage)));
  testWidgets('冻结原23项调试/22项正式注册、名称、系列与固定色', (t) async {
    await mount(t);
    final loc = l(t);
    final handle = t.ensureSemantics();
    final card = find.byType(BeeSkinCard).first;
    final semantics = t.getSemantics(card);
    expect(semantics.label, loc.headerSkinNone);
    expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(semantics.rect.width, t.getSize(card).width);
    handle.dispose();
    final ids = ['none', ...kVisibleHeaderSkins.map((s) => s.id)];
    expect(ids, legacy.map((o) => o['id']).toList());
    expect(legacy.where((o) => o['debugOnly'] != true), hasLength(22));
    for (final row in legacy) {
      final item = skinChoice(t.element(find.byType(HeaderSkinPage)),
          id: row['id'], primary: const Color(0xff123456));
      expect(item.name, row['name']);
      expect(item.animated, row['animated']);
      expect(item.fixedPalette, row['fixed']);
      expect(item.cornerBadge, row['badge']);
    }
    expect(loc.headerSkinTitle, isNotEmpty);
    expect(t.takeException(), isNull);
  });
  for (final compact in [false, true]) {
    testWidgets('原三筛选只筛显示、固定皮肤色恢复、只读与真实入口 ${compact ? '320英文深色140%' : '398中文'}',
        (t) async {
      await mount(t, compact: compact);
      final loc = l(t);
      final original = container.read(primaryColorProvider);
      await t.tap(find.text(loc.headerSkinTabAnimated));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(BeeSkinCard), findsNWidgets(2));
      expect(container.read(headerSkinProvider), 'none');
      final animatedCards =
          t.widgetList<BeeSkinCard>(find.byType(BeeSkinCard)).toList();
      for (final card in animatedCards) {
        await t.ensureVisible(find.text(card.item.name));
        await t.pump();
        await t.tap(find.text(card.item.name));
        await t.pump(const Duration(milliseconds: 500));
        expect(container.read(headerSkinProvider), card.item.id);
        expect(container.read(primaryColorProvider),
            headerSkinById(card.item.id)!.boundPrimary);
        expect(prefs.getString('headerSkin'), card.item.id);
        expect(t.takeException(), isNull);
      }
      await t.ensureVisible(find.text(loc.headerSkinTabStatic));
      await t.pump();
      await t.tap(find.text(loc.headerSkinTabStatic));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text(loc.headerSkinNone), findsOneWidget);
      expect(container.read(headerSkinProvider), 'anniv_cake');
      await t.tap(find.text(loc.headerSkinNone));
      await t.pump(const Duration(milliseconds: 500));
      expect(container.read(headerSkinProvider), 'none');
      expect(container.read(primaryColorProvider), original);
      await t.scrollUntilVisible(
          find.text(kVisibleHeaderSkins.last.nameOf(loc)), 350,
          scrollable: find.byType(Scrollable).last);
      await t.ensureVisible(find.text(kVisibleHeaderSkins.last.nameOf(loc)));
      await t.pump();
      expect(find.text(kVisibleHeaderSkins.last.nameOf(loc)), findsOneWidget);
      expect(t.takeException(), isNull);
      await mount(t, compact: compact, child: const LiveSkinPreview());
      expect(t.widget<BeeSkinCard>(find.byType(BeeSkinCard)).onTap, isNull);
      expect(container.read(headerSkinProvider), 'none');
      await t.ensureVisible(find.text('打开真实皮肤设置'));
      await t.tap(find.text('打开真实皮肤设置'));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(HeaderSkinPage), findsOneWidget);
      expect(container.read(headerSkinProvider), 'none');
      expect(
          await db.customSelect('SELECT * FROM transactions').get(), isEmpty);
      expect(
          await db.customSelect('SELECT * FROM ledgers').get(), hasLength(1));
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('原预览实际绑定色、暗底、移除状态栏留白，纯组件回调不写真实偏好', (t) async {
    await mount(t);
    final context = t.element(find.byType(HeaderSkinPage));
    final choice =
        skinChoice(context, id: 'anniv_cake', primary: const Color(0xff123456));
    final media = choice.preview as MediaQuery;
    expect(media.data.padding.top, 0);
    expect((media.child as ColoredBox).color, const Color(0xffff7a45));
    await mount(t, compact: true);
    final dark = skinChoice(t.element(find.byType(HeaderSkinPage)),
        id: 'anniv_cake', primary: const Color(0xff123456));
    expect(
        ((dark.preview as MediaQuery).child as ColoredBox).color, Colors.black);
    expect(t.takeException(), isNull);
  });
}
