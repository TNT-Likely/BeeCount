import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/settings/appearance/bindings/skin_material_sheet.dart';
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount/services/export/config_export_service.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('材质偏好限制非法值，导出导入兼容旧配置', () {
    final old = AppSettingsConfig.fromMap({});
    expect(old.skinCardOpacity, isNull);
    expect(old.toMap().containsKey('skin_card_blur'), isFalse);
    final map =
        const AppSettingsConfig(skinCardOpacity: .65, skinCardBlur: 8).toMap();
    final restored = AppSettingsConfig.fromMap(map);
    expect(restored.skinCardOpacity, .65);
    expect(restored.skinCardBlur, 8);
    final bounds = AppSettingsConfig.fromMap(
        {'skin_card_opacity': 9, 'skin_card_blur': -1});
    expect(bounds.skinCardOpacity, 1);
    expect(bounds.skinCardBlur, 0);
    for (final bad in ['8', double.nan, double.infinity]) {
      expect(() => AppSettingsConfig.fromMap({'skin_card_blur': bad}),
          throwsFormatException);
    }
    expect(BeePageMaterial.normalizeOpacity(double.nan), .4);
    expect(BeePageMaterial.normalizeBlur(double.infinity), 0);
  });

  test('调整后持久化，重新创建容器恢复两项设置', () async {
    SharedPreferences.setMockInitialValues(
        {'skinCardOpacity': .55, 'skinCardBlur': 4});
    final c = ProviderContainer();
    await c.read(skinCardMaterialInitProvider.future);
    expect(c.read(skinCardOpacityProvider), .55);
    expect(c.read(skinCardBlurProvider), 4);
    c.read(skinCardOpacityProvider.notifier).state = .75;
    c.read(skinCardBlurProvider.notifier).state = 12;
    await Future<void>.delayed(const Duration(milliseconds: 210));
    c.dispose();
    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    await restored.read(skinCardMaterialInitProvider.future);
    expect(restored.read(skinCardOpacityProvider), .75);
    expect(restored.read(skinCardBlurProvider), 12);
  });

  for (final dark in [false, true]) {
    testWidgets('320大字体设置实际拖动、即时预览、保存和重置 dark=$dark', (t) async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(skinCardMaterialInitProvider.future);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 900);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
              theme: beeTheme(
                  brightness: dark ? Brightness.dark : Brightness.light),
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!),
              home: Scaffold(
                  body: Builder(
                      builder: (context) => Center(
                          child: TextButton(
                              onPressed: () => showSkinMaterialSheet(context),
                              child: const Text('打开材质'))))))));
      await t.tap(find.text('打开材质'));
      await t.pumpAndSettle();
      final opacity = find.byKey(const ValueKey('material-transparency'));
      final blur = find.byKey(const ValueKey('material-blur'));
      final rect = t.getRect(opacity);
      await t.tapAt(Offset(rect.left + rect.width * .25, rect.center.dy));
      await t.pumpAndSettle();
      final blurRect = t.getRect(blur);
      await t.tapAt(Offset(blurRect.right - 30, blurRect.center.dy));
      await t.pumpAndSettle();
      expect(c.read(skinCardOpacityProvider), greaterThan(.6));
      expect(c.read(skinCardBlurProvider), greaterThan(8));
      final preview = find.byType(BeeMaterialPreview);
      final card =
          find.descendant(of: preview, matching: find.byType(BeeSurface));
      expect(BeeCardTheme.of(t.element(card)).surface.a,
          closeTo(c.read(skinCardOpacityProvider), .001));
      // A popup stays opaque, but its explicitly bounded sample really blurs.
      expect(t.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor!.a,
          1);
      expect(
          t
              .widgetList<BackdropFilter>(find.descendant(
                  of: preview, matching: find.byType(BackdropFilter)))
              .any((f) => f.enabled),
          isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('skinCardBlur'), c.read(skinCardBlurProvider));
      final reset = find.byType(BeeMaterialControls);
      await t.tap(find.descendant(of: reset, matching: find.byType(BeeButton)));
      await t.pumpAndSettle();
      expect(c.read(skinCardOpacityProvider), .4);
      expect(c.read(skinCardBlurProvider), 0);
      expect(prefs.getDouble('skinCardOpacity'), .4);
      expect(prefs.getDouble('skinCardBlur'), 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 200));
    });

    testWidgets('模糊仅在外层半透明卡生效，默认或不透明卡不创建滤镜 dark=$dark', (t) async {
      Widget host(double alpha, double sigma) => MaterialApp(
          theme:
              beeTheme(brightness: dark ? Brightness.dark : Brightness.light),
          home: Scaffold(
              body: BeePageMaterial(
                  enabled: true,
                  opacity: alpha,
                  blur: sigma,
                  child: const BeeSurface(
                      child: BeeSurface(child: Text('Nested'))))));
      await t.pumpWidget(host(.4, 0));
      expect(find.byType(BackdropFilter), findsNothing);
      await t.pumpWidget(host(1, 8));
      expect(find.byType(BackdropFilter), findsNothing);
      await t.pumpWidget(host(.4, 8));
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
