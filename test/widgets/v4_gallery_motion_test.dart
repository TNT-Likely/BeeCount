import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/presentation/v4/gallery/component_gallery_page.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('目录暂停动效保持平铺、局部主题与应用动效偏好互不影响', (t) async {
    SharedPreferences.setMockInitialValues(
        {'skinAnimationEnabled': true, 'primaryColor': 0xfff8c91c});
    t.view.physicalSize = const Size(398, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ProviderScope(
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ComponentGalleryPage(enableLiveData: false))));
    await t.pump(const Duration(milliseconds: 400));
    expect(
        t
            .widget<TickerMode>(
                find.byKey(const ValueKey('gallery-foundation-tickers')))
            .enabled,
        true);
    await t.tap(find.byTooltip('主题色与动效'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('暂停示例动效'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(
        t
            .widget<TickerMode>(
                find.byKey(const ValueKey('gallery-foundation-tickers')))
            .enabled,
        false);
    await t.tap(find.text('业务组件'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(
        t
            .widget<TickerMode>(
                find.byKey(const ValueKey('gallery-business-tickers')))
            .enabled,
        false);
    expect(find.text('54 组组件 · 全部平铺'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('business-case')));
    await t.pumpAndSettle();
    final lastItem = find.widgetWithText(BeeButton, '51 · 预算编辑与分类草稿');
    await t.ensureVisible(lastItem);
    await t.tap(lastItem);
    await t.pumpAndSettle();
    final lastSection = find.byKey(const ValueKey('business-section-50'));
    expect(t.getTopLeft(lastSection).dy, greaterThan(100));
    expect(t.getTopLeft(lastSection).dy, lessThan(550));

    await t.tap(find.byTooltip('主题色与动效'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('薄荷绿'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(Theme.of(t.element(find.text('业务组件验收'))).colorScheme.primary,
        const Color(0xff49a396));
    await t.tap(find.byTooltip('主题色与动效'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('播放示例动效'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(
        t
            .widget<TickerMode>(
                find.byKey(const ValueKey('gallery-business-tickers')))
            .enabled,
        true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('skinAnimationEnabled'), true);
    expect(prefs.getInt('primaryColor'), 0xfff8c91c);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 3));
  });
}
