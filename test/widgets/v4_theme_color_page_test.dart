import 'dart:convert';
import 'dart:io';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/settings/personalize_page.dart';
import 'package:beecount/pages/settings/header_skin_page.dart';
import 'package:beecount/presentation/v4/bindings/theme_color_options.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/styles/header_skins.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final legacy = (jsonDecode(
          File('test/fixtures/v4-theme-colors-legacy.json').readAsStringSync())
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
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'主题验收','CNY')");
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(LocalRepository(db))
    ]);
    await container.read(primaryColorInitProvider.future);
    await container.read(headerSkinInitProvider.future);
    container.read(skinAnimationEnabledProvider.notifier).state = false;
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> mount(WidgetTester t, {bool compact = false}) async {
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
                builder: (c, child) => MediaQuery(
                    data: MediaQuery.of(c).copyWith(
                        textScaler: TextScaler.linear(compact ? 1.4 : 1)),
                    child: child!),
                home: const PersonalizePage()))));
    await t.pumpAndSettle();
  }

  AppLocalizations l(WidgetTester t) =>
      AppLocalizations.of(t.element(find.byType(PersonalizePage)));
  Future<void> custom(WidgetTester t) async {
    final target = find.text(l(t).personalizeCustomColor);
    await t.scrollUntilVisible(target, 180,
        scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pumpAndSettle();
  }

  test('HSV预览使用实际RGB字节，边界值与透明色的RGB正确', () {
    expect(BeeHsvColorPicker.hex(Colors.blue), '#2196F3');
    expect(BeeHsvColorPicker.hex(Colors.red), '#F44336');
    expect(BeeHsvColorPicker.hex(const Color(0xFFFF0000)), '#FF0000');
    expect(BeeHsvColorPicker.hex(Colors.black), '#000000');
    expect(BeeHsvColorPicker.hex(Colors.white), '#FFFFFF');
    expect(BeeHsvColorPicker.hex(const Color(0x801234AB)), '#1234AB');
  });
  testWidgets('原27主题名称/色值逐个真实选择并持久化、不改数据库', (t) async {
    await mount(t);
    final options = themeColorOptions(l(t));
    expect(options, hasLength(27));
    expect(options.map((o) => BeeHsvColorPicker.hex(o.color)).toList(),
        legacy.map((o) => o['hex']).toList());
    expect(options.map((o) => o.label).toList(),
        legacy.map((o) => o['zh']).toList());
    for (final option in options) {
      await t.ensureVisible(find.text(option.label));
      await t.pumpAndSettle();
      await t.tap(find.text(option.label));
      await t.pumpAndSettle();
      expect(container.read(primaryColorProvider), option.color);
      expect(container.read(userChosenPrimaryProvider), option.color);
      final stored = prefs.getInt('primaryColor');
      expect(BeeHsvColorPicker.hex(Color(stored!)),
          BeeHsvColorPicker.hex(option.color));
      expect(
          BeeHsvColorPicker.hex(Color(prefs.getInt('userChosenPrimaryColor')!)),
          BeeHsvColorPicker.hex(option.color));
    }
    expect(await db.customSelect('SELECT * FROM transactions').get(), isEmpty);
    expect(await db.customSelect('SELECT * FROM ledgers').get(), hasLength(1));
    expect(t.takeException(), isNull);
  });
  for (final compact in [false, true]) {
    testWidgets(
        '自定义HSV原蓝色初稿、取消不写、确认持久化、关闭位置保持 ${compact ? '320英文深色140%' : '398中文'}',
        (t) async {
      await mount(t, compact: compact);
      if (compact) {
        expect(themeColorOptions(l(t)).map((o) => o.label).toList(),
            legacy.map((o) => o['en']).toList());
      }
      final before = container.read(primaryColorProvider),
          remembered = container.read(userChosenPrimaryProvider);
      await custom(t);
      expect(find.text('#2196F3'), findsOneWidget);
      final hue = find.byType(Slider).at(0);
      await t.ensureVisible(hue);
      await t.drag(hue, const Offset(-75, 0));
      await t.pumpAndSettle();
      final draft = t
          .widget<BeeHsvColorPicker>(find.byType(BeeHsvColorPicker))
          .value
          .toColor();
      expect(draft, isNot(Colors.blue));
      expect(container.read(primaryColorProvider), before);
      await t.tap(find.byType(CloseButton));
      await t.pumpAndSettle();
      expect(container.read(primaryColorProvider), before);
      final scroll = t.widget<ListView>(find.byType(ListView)).controller!;
      final offset = scroll.offset;
      await custom(t);
      expect(find.text('#2196F3'), findsOneWidget);
      await t.tap(find.text(l(t).personalizeSelectColor));
      await t.pumpAndSettle();
      expect(BeeHsvColorPicker.hex(container.read(primaryColorProvider)),
          '#2196F3');
      expect(BeeHsvColorPicker.hex(Color(prefs.getInt('primaryColor')!)),
          '#2196F3');
      expect(container.read(userChosenPrimaryProvider), remembered,
          reason: '原自定义确认只写primary，皮肤切换仍由原服务记住当前色');
      expect(scroll.offset, closeTo(offset, .01));
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('任意HSV草稿确认后按预览RGB持久化，实际重新加载保持一致', (t) async {
    await mount(t);
    await custom(t);
    final hue = find.byType(Slider).at(0);
    await t.ensureVisible(hue);
    await t.pumpAndSettle();
    await t.drag(hue, const Offset(-83, 0));
    await t.pumpAndSettle();
    final expected = BeeHsvColorPicker.hex(t
        .widget<BeeHsvColorPicker>(find.byType(BeeHsvColorPicker))
        .value
        .toColor());
    expect(expected, isNot('#2196F3'));
    await t.tap(find.text(l(t).personalizeSelectColor));
    await t.pumpAndSettle();
    expect(
        BeeHsvColorPicker.hex(Color(prefs.getInt('primaryColor')!)), expected);
    container.invalidate(primaryColorInitProvider);
    await container.read(primaryColorInitProvider.future);
    await t.pumpAndSettle();
    expect(
        BeeHsvColorPicker.hex(container.read(primaryColorProvider)), expected);
    expect(t.takeException(), isNull);
  });
  testWidgets('固定皮肤锁住预设和自定义，原更换皮肤入口和返回保留', (t) async {
    final fixed = kVisibleHeaderSkins.firstWhere((s) => s.hasFixedPalette);
    applyHeaderSkinWith(container.read, fixed.id);
    await mount(t, compact: true);
    expect(
        t
            .widget<BeeColorPalette<String>>(
                find.byType(BeeColorPalette<String>))
            .onChanged,
        isNull);
    final before = container.read(primaryColorProvider);
    final item = themeColorOptions(l(t)).first;
    await t.ensureVisible(find.text(item.label));
    await t.pumpAndSettle();
    await t.tap(find.text(item.label));
    await t.pumpAndSettle();
    expect(container.read(primaryColorProvider), before);
    await t.scrollUntilVisible(find.text(l(t).personalizeCustomColor), 180,
        scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(find.text(l(t).personalizeCustomColor));
    await t.tap(find.text(l(t).personalizeCustomColor));
    await t.pumpAndSettle();
    expect(find.byType(BeeDialog), findsNothing);
    t.widget<ListView>(find.byType(ListView).first).controller!.jumpTo(0);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text(l(t).personalizeFixedSkinAction));
    await t.pumpAndSettle();
    await t.tap(find.text(l(t).personalizeFixedSkinAction));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(HeaderSkinPage), findsOneWidget);
    Navigator.of(t.element(find.byType(HeaderSkinPage))).pop();
    await t.pumpAndSettle();
    expect(container.read(primaryColorProvider), before);
    expect(t.takeException(), isNull);
  });
  testWidgets('自定义确认时若皮肤已锁定，不覆盖绑定配色', (t) async {
    await mount(t);
    await custom(t);
    final fixed = kVisibleHeaderSkins.firstWhere((s) => s.hasFixedPalette);
    applyHeaderSkinWith(container.read, fixed.id);
    await t.pumpAndSettle();
    final bound = container.read(primaryColorProvider);
    await t.tap(find.text(l(t).personalizeSelectColor));
    await t.pumpAndSettle();
    expect(container.read(primaryColorProvider), bound);
    expect(t.takeException(), isNull);
  });
}
