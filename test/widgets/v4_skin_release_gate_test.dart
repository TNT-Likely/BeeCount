import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount/pages/settings/appearance_settings_page.dart';
import 'package:beecount/pages/settings/header_skin_page.dart';
import 'package:beecount/pages/settings/personalize_page.dart';
import 'package:beecount/pages/shared/scaffold/widgets/page_scaffold.dart';
import 'package:beecount/styles/header_skins.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        'auto_sync': false,
        'headerSkin': 'anniv_cake',
        'userChosenPrimaryColor': 0xff123456,
      }));

  test('紧急关闭时已保存皮肤仍保留，重新启用不需要迁移偏好', () async {
    final c = ProviderContainer(overrides: [
      headerSkinsEnabledProvider.overrideWith((_) => false),
    ]);
    addTearDown(c.dispose);
    expect(c.read(headerSkinsEnabledProvider), isFalse);
    c.read(primaryColorProvider.notifier).state = const Color(0xff123456);
    await c.read(headerSkinInitProvider.future);
    expect(c.read(headerSkinProvider), 'anniv_cake');
    expect(c.read(effectiveHeaderSkinProvider), 'none');
    expect(c.read(primaryColorProvider), const Color(0xff123456));
    applyHeaderSkinWith(c.read, 'anniversary');
    expect(c.read(headerSkinProvider), 'anniv_cake');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('headerSkin'), 'anniv_cake');
    final reopened = ProviderContainer(overrides: [
      headerSkinsEnabledProvider.overrideWith((_) => true),
    ]);
    addTearDown(reopened.dispose);
    await reopened.read(headerSkinInitProvider.future);
    expect(reopened.read(effectiveHeaderSkinProvider), 'anniv_cake');
    expect(reopened.read(primaryColorProvider), boundPrimaryOf('anniv_cake'));
  });

  Future<void> open(WidgetTester t, ProviderContainer c, Widget child) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(398, 844);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: child)));
    await t.pumpAndSettle();
  }

  testWidgets('外观页隐藏皮肤及动画入口，主题色仍能选择且不被旧皮肤锁定', (t) async {
    final c = ProviderContainer(overrides: [
      headerSkinsEnabledProvider.overrideWith((_) => false),
      headerSkinProvider.overrideWith((_) => 'anniv_cake'),
    ]);
    addTearDown(c.dispose);
    await open(t, c, const AppearanceSettingsPage());
    final l =
        AppLocalizations.of(t.element(find.byType(AppearanceSettingsPage)));
    expect(find.text(l.headerSkinTitle), findsNothing);
    expect(find.text(l.appearanceSkinAnimation), findsNothing);
    await t.tap(find.text(l.personalizeTitle));
    await t.pumpAndSettle();
    expect(find.byType(PersonalizePage), findsOneWidget);
    final palette =
        t.widget<BeeColorPalette<String>>(find.byType(BeeColorPalette<String>));
    expect(palette.onChanged, isNotNull);
    final choice = palette.items
        .firstWhere((x) => x.color != c.read(primaryColorProvider));
    await t.ensureVisible(find.text(choice.label));
    await t.tap(find.text(choice.label));
    await t.pumpAndSettle();
    expect(c.read(primaryColorProvider), choice.color);
    expect(c.read(headerSkinProvider), 'anniv_cake');
    expect(t.takeException(), isNull);
  });

  testWidgets('直接访问旧皮肤路由也无法选择；已有皮肤不产生页面背景或卡片遮罩', (t) async {
    final c = ProviderContainer(overrides: [
      headerSkinsEnabledProvider.overrideWith((_) => false),
      headerSkinProvider.overrideWith((_) => 'anniversary'),
    ]);
    addTearDown(c.dispose);
    await open(t, c, const HeaderSkinPage());
    expect(find.byType(BeeSkinCard), findsNothing);
    expect(find.byType(HeaderSkinPageArtwork), findsNothing);
    await open(
        t,
        c,
        V4PageScaffold(
            body: Consumer(
                builder: (context, ref, _) =>
                    Center(child: BeeSurface(child: const Text('账单内容'))))));
    expect(find.byType(HeaderSkinPageArtwork), findsNothing);
    expect(t.widget<BeeSurface>(find.byType(BeeSurface)).background, isNull);
    final before = t.getRect(find.text('账单内容'));
    c.read(headerSkinProvider.notifier).state = 'anniv_cake';
    await t.pumpAndSettle();
    expect(find.byType(HeaderSkinPageArtwork), findsNothing);
    expect(t.getRect(find.text('账单内容')), before);
    expect(t.takeException(), isNull);
  });
}
