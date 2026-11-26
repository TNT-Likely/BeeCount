import 'dart:convert';
import 'dart:io';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/settings/appearance/skin_editor.dart';
import 'package:beecount/pages/settings/appearance_settings_page.dart';
import 'package:beecount/pages/settings/header_skin_page.dart';
import 'package:beecount/pages/settings/appearance/bindings/skin_choices.dart';
import 'package:beecount/dev/component_gallery/bindings/skin_preview.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/skins/premium_skin_canvas.dart';
import 'package:beecount/skins/premium_skins.dart';
import 'package:beecount/styles/header_skins.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _TestPremiumSkins extends PremiumSkins {
  static const id = 'test-premium', otherId = 'test-new-skin';
  static const firstPack = 'legacy-pack', secondPack = 'second-pack';
  static const accent = Colors.deepPurple;
  static PremiumSkinCollection catalog(
          String packId, String skinId, String cn, String tw) =>
      PremiumSkinCollection(
        id: packId,
        name: cn,
        traditionalName: tw,
        englishName: packId,
        skins: [
          PremiumSkin(
            id: skinId,
            name: '$cn样本',
            traditionalName: '$tw樣本',
            englishName: skinId,
            preview: (context) => ColoredBox(
              key: ValueKey('thumbnail-$skinId-${TickerMode.of(context)}'),
              color: accent,
            ),
            colors: (_) => (accent: accent, onAccent: Colors.white),
            scene: (context, _, child, __) => ColoredBox(
              key: ValueKey(
                  'test-scene-$skinId-${Theme.of(context).brightness.name}'),
              color: accent,
              child: child,
            ),
          )
        ],
      );
  @override
  final collections = [
    catalog(firstPack, id, '第一套', '第一套'),
    catalog(secondPack, otherId, '冬季测试', '冬季測試'),
  ];
  final grants = <String>{};
  final recoverable = {firstPack};
  final prices = <String, String?>{firstPack: '¥12', secondPack: '¥18'};
  String? lastPurchase;
  SkinAppearance _appearance = const SkinAppearance();

  @override
  bool ownsPack(String packId) => grants.contains(packId);
  @override
  String? priceForPack(String packId) => prices[packId];
  @override
  bool get canMakePayments => true;
  @override
  bool salesEnabledForPack(String packId) => true;
  @override
  SkinAppearance get appearance => _appearance;

  @override
  Future<SkinPurchaseResult> purchasePack(String packId) async {
    lastPurchase = packId;
    return SkinPurchaseResult.pending;
  }

  @override
  Future<bool> restore() async {
    grants
      ..clear()
      ..addAll(recoverable);
    notifyListeners();
    return true;
  }

  @override
  Future<bool> select(String id, SkinAppearance value) async {
    final pack = collectionForSkin(id);
    if (pack == null || !ownsPack(pack.id)) return false;
    _appearance = value;
    notifyListeners();
    return true;
  }

  @override
  double navigationDecorationHeight(BuildContext context) => 32;

  @override
  Widget navigationArtwork(BuildContext context) =>
      const ColoredBox(color: Colors.deepOrange);

  @override
  Future<void> clearSelection() async {
    _appearance = const SkinAppearance();
    notifyListeners();
  }
}

void main() {
  final legacy =
      (jsonDecode(File('test/fixtures/v4-skins-legacy.json').readAsStringSync())
          as Map)['options'] as List;
  late BeeDatabase db;
  late ProviderContainer container;
  late SharedPreferences prefs;
  Future<ProviderContainer> makeContainer({PremiumSkins? premium}) async {
    final instance = ProviderContainer(overrides: [
      headerSkinsEnabledProvider.overrideWith((_) => true),
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(LocalRepository(db)),
      if (premium != null) premiumSkinsProvider.overrideWith((_) => premium),
    ]);
    await instance.read(primaryColorInitProvider.future);
    await instance.read(headerSkinInitProvider.future);
    await instance.read(skinAnimationInitProvider.future);
    return instance;
  }

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
    container = await makeContainer();
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> mount(WidgetTester t,
      {bool compact = false,
      bool reduceMotion = true,
      Locale? locale,
      Widget child = const HeaderSkinPage()}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = compact ? const Size(320, 568) : const Size(398, 844);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Consumer(
            builder: (c, ref, _) => MaterialApp(
                theme: beeTheme(
                    accent: ref.watch(displaySkinPrimaryColorProvider),
                    brightness: compact ? Brightness.dark : Brightness.light),
                locale: locale ?? Locale(compact ? 'en' : 'zh'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                builder: (c, w) => MediaQuery(
                    data: MediaQuery.of(c).copyWith(
                        textScaler: TextScaler.linear(compact ? 1.4 : 1),
                        disableAnimations: reduceMotion,
                        padding: const EdgeInsets.only(top: 24)),
                    child: PremiumSkinCanvas(child: w!)),
                home: Scaffold(body: child)))));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
  }

  AppLocalizations l(WidgetTester t) =>
      AppLocalizations.of(t.element(find.byType(HeaderSkinPage)));
  Finder tile(String id) => find.byKey(ValueKey('skin-card-$id'));

  Future<void> tapVisible(WidgetTester t, Finder target) async {
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget);
    await t.tap(target);
    await t.pumpAndSettle();
  }

  Future<void> applyPreview(WidgetTester t, String id) async {
    final preview = find.byType(SkinEditor);
    expect(preview, findsOneWidget);
    expect(t.widget<SkinEditor>(preview).skinId, id);
    expect(t.widget<SkinEditor>(preview).editingActive, isFalse);
    await tapVisible(t, find.byKey(const ValueKey('official-apply')));
    expect(preview, findsNothing);
    expect(container.read(headerSkinProvider), id);
    expect(prefs.getString('headerSkin'), id);
  }

  testWidgets('保留两款静态和两款周年动态，名称、系列与固定色沿用原版', (t) async {
    await mount(t);
    final loc = l(t);
    final semantics = t.ensureSemantics();
    final none = tile('none');
    final node = t.getSemantics(none);
    expect(node.label, contains(loc.headerSkinNone));
    expect(node.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.rect.width, t.getSize(none).width);
    semantics.dispose();
    final ids = ['none', ...kVisibleHeaderSkins.map((s) => s.id)];
    expect(ids, ['none', 'anniversary', 'anniv_cake', 'aurora', 'mountains']);
    for (final row in legacy.where((o) => ids.contains(o['id']))) {
      final id = row['id'] as String;
      final item = skinChoice(t.element(find.byType(HeaderSkinPage)),
          id: id, primary: const Color(0xff123456));
      expect(item.name, row['name']);
      expect(item.animated, row['animated']);
      expect(item.fixedPalette, row['fixed']);
      expect(item.cornerBadge, row['badge']);
      expect(find.descendant(of: tile(id), matching: find.text(item.name)),
          findsOneWidget);
    }
    expect(loc.headerSkinTitle, isNotEmpty);
    expect(t.takeException(), isNull);
  });

  for (final compact in [false, true]) {
    testWidgets('统一筛选与试穿保留绑定色恢复、只读与真实入口 ${compact ? '320英文深色140%' : '398中文'}',
        (t) async {
      await mount(t, compact: compact);
      final loc = l(t);
      final original = container.read(primaryColorProvider);
      await tapVisible(t, find.text(loc.headerSkinTabAnimated));
      for (final id in ['none', 'aurora', 'mountains']) {
        expect(tile(id), findsNothing);
      }
      for (final id in ['anniversary', 'anniv_cake']) {
        final current = container.read(headerSkinProvider);
        final stored = prefs.getString('headerSkin');
        final color = container.read(primaryColorProvider);
        await tapVisible(t, tile(id));
        expect(container.read(headerSkinProvider), current);
        expect(container.read(primaryColorProvider), color);
        expect(prefs.getString('headerSkin'), stored);
        await applyPreview(t, id);
        expect(container.read(primaryColorProvider),
            headerSkinById(id)!.boundPrimary);
        expect(t.takeException(), isNull);
      }
      await tapVisible(t, find.text(loc.headerSkinTabStatic));
      for (final id in ['anniversary', 'anniv_cake']) {
        expect(tile(id), findsNothing);
      }
      expect(tile('none'), findsOneWidget);
      expect(tile('aurora'), findsOneWidget);
      expect(tile('mountains'), findsOneWidget);
      expect(container.read(headerSkinProvider), 'anniv_cake');
      await tapVisible(t, tile('none'));
      await applyPreview(t, 'none');
      expect(container.read(primaryColorProvider), original);
      await t.ensureVisible(tile('mountains'));
      await t.pumpAndSettle();
      expect(tile('mountains').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);

      await mount(t, compact: compact, child: const LiveSkinPreview());
      expect(t.widget<BeeSkinCard>(find.byType(BeeSkinCard)).onTap, isNull);
      await tapVisible(t, find.text('打开真实皮肤设置'));
      expect(find.byType(HeaderSkinPage), findsOneWidget);
      expect(container.read(headerSkinProvider), 'none');
      expect(
          await db.customSelect('SELECT * FROM transactions').get(), isEmpty);
      expect(
          await db.customSelect('SELECT * FROM ledgers').get(), hasLength(1));
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('缩略图和文字均可打开试穿，取消时保留原皮肤', (t) async {
    await mount(t);
    final loc = l(t);
    await tapVisible(t, find.text(loc.headerSkinTabAnimated));
    final thumbnail = find.descendant(
        of: tile('anniversary'), matching: find.byType(AspectRatio));
    await tapVisible(t, thumbnail);
    expect(find.byType(SkinEditor), findsOneWidget);
    expect(t.widget<SkinEditor>(find.byType(SkinEditor)).skinId, 'anniversary');
    expect(container.read(headerSkinProvider), 'none');
    await tapVisible(t, find.byType(CloseButton));
    expect(find.byType(SkinEditor), findsNothing);
    expect(container.read(headerSkinProvider), 'none');
    await tapVisible(t, find.text(headerSkinById('anniv_cake')!.nameOf(loc)));
    expect(container.read(headerSkinProvider), 'none');
    await applyPreview(t, 'anniv_cake');
    expect(t.takeException(), isNull);
  });

  testWidgets('外观设置的动效开关随当前动态皮肤调节页保存', (t) async {
    container.read(headerSkinProvider.notifier).state = 'anniversary';
    await mount(t, child: const AppearanceSettingsPage());
    final page = find.byType(AppearanceSettingsPage);
    final context = t.element(page);
    final loc = AppLocalizations.of(context);
    final adjustment = find.text(skinAdjustmentTitle(context));
    final before = container.read(skinAnimationEnabledProvider);
    for (final value in [!before, before]) {
      await tapVisible(t, adjustment);
      expect(
          t.widget<SkinEditor>(find.byType(SkinEditor)).skinId, 'anniversary');
      await tapVisible(t, find.text('动效'));
      await tapVisible(t, find.text(loc.appearanceSkinAnimation));
      expect(container.read(skinAnimationEnabledProvider), !value);
      await tapVisible(t, find.byKey(const ValueKey('official-apply')));
      expect(container.read(skinAnimationEnabledProvider), value);
      expect(prefs.getBool('skinAnimationEnabled'), value);
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('付费皮肤使用同一试穿流程，恢复后才可应用并可切回免费皮肤', (t) async {
    final runtime = _TestPremiumSkins();
    container.dispose();
    container = await makeContainer(premium: runtime);
    await mount(t);
    final freeColor = container.read(primaryColorProvider);
    final loc = l(t);
    await tapVisible(t, find.text(loc.headerSkinTabStatic));
    expect(tile(_TestPremiumSkins.id), findsNothing);
    await tapVisible(t, find.text(loc.headerSkinTabAll));
    expect(
        find.byKey(
            const ValueKey('skin-collection-${_TestPremiumSkins.firstPack}')),
        findsOneWidget);
    await tapVisible(t, tile(_TestPremiumSkins.id));

    expect(find.byKey(const ValueKey('official-apply')), findsNothing);
    await tapVisible(t, find.byKey(const ValueKey('official-buy-pack')));
    expect(runtime.ownsPack(_TestPremiumSkins.firstPack), isFalse);
    expect(find.text('等待付款完成，稍后会自动更新'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('official-redeem-preview')), findsOneWidget);
    await tapVisible(t, find.byKey(const ValueKey('official-restore-preview')));
    expect(runtime.ownsPack(_TestPremiumSkins.firstPack), isTrue);
    final restoreMessage = find.byKey(const ValueKey('official-store-message'));
    expect(t.widget<Text>(restoreMessage).data, contains('已恢复购买'));
    final ok =
        MaterialLocalizations.of(t.element(restoreMessage)).okButtonLabel;
    await tapVisible(t, find.text(ok));
    await tapVisible(t, find.byKey(const ValueKey('official-apply')));

    expect(find.byType(SkinEditor), findsNothing);
    expect(find.byType(HeaderSkinPage), findsOneWidget);
    expect(runtime.appearance.skinId, _TestPremiumSkins.id);
    expect(container.read(displaySkinPrimaryColorProvider),
        _TestPremiumSkins.accent);
    expect(container.read(primaryColorProvider), freeColor);

    await tapVisible(t, tile('aurora'));
    await applyPreview(t, 'aurora');
    expect(runtime.active, isFalse);
    expect(runtime.ownsPack(_TestPremiumSkins.firstPack), isTrue);
    expect(container.read(displaySkinPrimaryColorProvider), freeColor);
    expect(t.takeException(), isNull);
  });

  testWidgets('两个合集分别显示价格与权益，只恢复秋日时冬日仍可试穿', (t) async {
    final runtime = _TestPremiumSkins();
    await runtime.restore();
    container.dispose();
    container = await makeContainer(premium: runtime);
    await mount(t);
    expect(find.text('已购 · 1 款'), findsOneWidget);
    expect(find.text('1 款合集 · ¥18'), findsOneWidget);
    await tapVisible(t, tile(_TestPremiumSkins.otherId));
    expect(find.text('解锁 1 款 · ¥18'), findsOneWidget);
    await tapVisible(t, find.byKey(const ValueKey('skin-preview-expand')));
    final full = find.byKey(const ValueKey('skin-preview-full'));
    expect(full, findsOneWidget);
    await tapVisible(t, find.byKey(const ValueKey('skin-preview-dark')));
    expect(
        find.descendant(
            of: full,
            matching: find.byKey(const ValueKey(
                'test-scene-${_TestPremiumSkins.otherId}-dark'))),
        findsOneWidget);
    final dock = find.byKey(const ValueKey('skin-preview-dock'));
    final band = find.byKey(const ValueKey('skin-preview-decoration'));
    expect(t.getSize(band).height, 32);
    for (final name in ['明细', '洞察', '记账', '资产', '我的']) {
      final label = find.descendant(of: dock, matching: find.text(name));
      expect(
          t.getBottomLeft(label).dy, lessThanOrEqualTo(t.getTopLeft(band).dy));
    }
    await tapVisible(t, find.byKey(const ValueKey('skin-preview-close')));
    await t.pumpAndSettle();
    await tapVisible(t, find.byKey(const ValueKey('official-buy-pack')));
    expect(runtime.lastPurchase, _TestPremiumSkins.secondPack);
    expect(runtime.appearance.skinId, isNull);
    await tapVisible(t, find.byKey(const ValueKey('official-restore-preview')));
    final message = find.byKey(const ValueKey('official-store-message'));
    expect(t.widget<Text>(message).data, contains('可用合集为「第一套」'));
    expect(t.widget<Text>(message).data, contains('未找到「冬季测试」'));
    await tapVisible(t,
        find.text(MaterialLocalizations.of(t.element(message)).okButtonLabel));
    expect(find.byKey(const ValueKey('official-apply')), findsNothing);
    runtime.recoverable.add(_TestPremiumSkins.secondPack);
    await tapVisible(t, find.byKey(const ValueKey('official-restore-preview')));
    await tapVisible(t,
        find.text(MaterialLocalizations.of(t.element(message)).okButtonLabel));
    await tapVisible(t, find.byKey(const ValueKey('official-apply')));
    expect(runtime.selectedSkin?.id, _TestPremiumSkins.otherId);
    runtime.recoverable.remove(_TestPremiumSkins.secondPack);
    await runtime.restore();
    await t.pumpAndSettle();
    expect(runtime.selectedSkin, isNull);
    expect(runtime.ownsPack(_TestPremiumSkins.firstPack), isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('滚入屏幕才开预览时钟，打开试穿和系统减弱动态都暂停', (t) async {
    final originalInterval =
        VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(() => VisibilityDetectorController.instance.updateInterval =
        originalInterval);
    final runtime = _TestPremiumSkins();
    container.dispose();
    container = await makeContainer(premium: runtime);
    await mount(t, compact: true, reduceMotion: false);
    final id = _TestPremiumSkins.otherId;
    Future<void> settleVisible() async {
      await t.pump(const Duration(milliseconds: 350));
      await t.pump(const Duration(milliseconds: 50));
    }

    await t.ensureVisible(tile(id));
    await settleVisible();
    expect(find.byKey(ValueKey('thumbnail-$id-true')), findsOneWidget);
    await t.ensureVisible(tile('none'));
    await settleVisible();
    expect(find.byKey(ValueKey('thumbnail-$id-false')), findsOneWidget);
    await t.ensureVisible(tile(id));
    await settleVisible();
    await t.tap(tile(id));
    await settleVisible();
    expect(find.byKey(ValueKey('thumbnail-$id-false')), findsOneWidget);
    await t.tap(find.byType(CloseButton));
    await settleVisible();
    await mount(t, locale: const Locale('zh', 'TW'));
    await t.ensureVisible(tile(id));
    await t.pumpAndSettle();
    expect(find.text('冬季測試樣本'), findsOneWidget);
    expect(find.byKey(ValueKey('thumbnail-$id-false')), findsOneWidget);
  });

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
