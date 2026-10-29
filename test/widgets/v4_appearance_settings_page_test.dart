import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/models/note_history.dart';
import 'package:beecount/pages/settings/appearance_settings_page.dart';
import 'package:beecount/pages/settings/language_settings_page.dart';
import 'package:beecount/pages/settings/font_settings_page.dart';
import 'package:beecount/pages/settings/personalize_page.dart';
import 'package:beecount/pages/settings/header_skin_page.dart';
import 'package:beecount/pages/settings/widget_management_page.dart';
import 'package:beecount/pages/settings/app_lock_settings_page.dart';
import 'package:beecount/pages/currency/exchange_rate_page.dart';
import 'package:beecount/dev/component_gallery/bindings/note_history_preview.dart';
import 'package:beecount/providers.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BeeDatabase db;
  late ProviderContainer container;
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues(
        {'auto_sync': false, 'baseCurrency': 'CNY'});
    prefs = await SharedPreferences.getInstance();
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'外观验收','CNY')");
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(LocalRepository(db))
    ]);
    for (final init in [
      themeModeInitProvider,
      compactAmountInitProvider,
      showTransactionTimeInitProvider,
      noteDisplayModeInitProvider,
      noteHistoryPreferencesInitProvider,
      incomeExpenseColorSchemeInitProvider,
      skinAnimationInitProvider
    ]) {
      await container.read(init.future);
    }
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> mount(WidgetTester t,
      {bool compact = false, Widget? child}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = compact ? const Size(320, 568) : const Size(398, 844);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Consumer(
            builder: (context, ref, _) => MaterialApp(
                theme: beeTheme(),
                darkTheme: beeTheme(brightness: Brightness.dark),
                themeMode: ref.watch(themeModeProvider),
                locale: Locale(compact ? 'en' : 'zh'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                builder: (c, child) => MediaQuery(
                    data: MediaQuery.of(c).copyWith(
                        textScaler: TextScaler.linear(compact ? 1.4 : 1)),
                    child: child!),
                home: child ?? const AppearanceSettingsPage()))));
    await t.pumpAndSettle();
  }

  AppLocalizations l(WidgetTester t) =>
      AppLocalizations.of(t.element(find.byType(AppearanceSettingsPage)));
  Future<void> reveal(WidgetTester t, String label) async {
    final scroll = t.widget<ListView>(find.byType(ListView).first).controller!;
    scroll.jumpTo(0);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text(label), 160,
        scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(find.text(label));
    await t.pumpAndSettle();
  }

  Future<void> choose(WidgetTester t, String entry, String option) async {
    await reveal(t, entry);
    await t.tap(find.text(entry));
    await t.pumpAndSettle();
    expect(find.byType(BeeDialog), findsOneWidget);
    await t.tap(find.descendant(
        of: find.byType(BeeDialog), matching: find.text(option)));
    await t.pumpAndSettle();
    expect(find.byType(BeeDialog), findsNothing);
  }

  testWidgets('原15项/四组与五种弹窗、即时偏好及取消不改值', (t) async {
    await mount(t);
    expect(t.getSize(find.byType(BeeSurface).first).height, lessThan(300),
        reason: 'HTML同卡片使用紧凑分隔，防止默认24px分组间距混入五行菜单');
    final s = l(t);
    await choose(t, s.appearanceThemeMode, s.appearanceThemeModeDark);
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(prefs.getString('themeMode'), 'dark');
    expect(Theme.of(t.element(find.byType(AppearanceSettingsPage))).brightness,
        Brightness.dark);
    await choose(t, s.appearanceThemeMode, s.appearanceThemeModeLight);
    await choose(t, s.appearanceThemeMode, s.appearanceThemeModeSystem);
    await choose(t, s.appearanceAmountFormat, s.appearanceAmountFormatCompact);
    expect(container.read(compactAmountProvider), true);
    expect(prefs.getBool('compactAmount'), true);
    await choose(t, s.appearanceAmountFormat, s.appearanceAmountFormatFull);
    await choose(t, s.appearanceNoteDisplay, s.appearanceNoteDisplayNote);
    expect(prefs.getString('noteDisplayMode'), 'note');
    await choose(t, s.appearanceNoteDisplay, s.appearanceNoteDisplayCategory);
    await choose(t, s.appearanceColorScheme, s.appearanceColorSchemeOff);
    expect(container.read(incomeExpenseColorSchemeProvider), false);
    await choose(t, s.appearanceColorScheme, s.appearanceColorSchemeOn);
    await reveal(t, s.appearanceAmountFormat);
    await t.tap(find.text(s.appearanceAmountFormat));
    await t.pumpAndSettle();
    await t.tap(find.byType(CloseButton));
    await t.pumpAndSettle();
    expect(container.read(compactAmountProvider), false);
    for (final pair in [
      (s.appearanceSkinAnimation, skinAnimationEnabledProvider),
      (s.appearanceShowTransactionTime, showTransactionTimeProvider)
    ]) {
      await reveal(t, pair.$1);
      final before = container.read(pair.$2);
      await t.tap(find.text(pair.$1));
      await t.pumpAndSettle();
      expect(container.read(pair.$2), !before);
      await t.tap(find.text(pair.$1));
      await t.pumpAndSettle();
      expect(container.read(pair.$2), before);
    }
    expect(await db.customSelect('SELECT * FROM transactions').get(), isEmpty);
    expect(await db.customSelect('SELECT * FROM ledgers').get(), hasLength(1));
    expect(t.takeException(), isNull);
  });
  for (final compact in [false, true]) {
    testWidgets('历史备注即时保存/无效值保护/关闭后位置保持 ${compact ? '320深色英文140%' : '398中文'}',
        (t) async {
      if (compact) {
        container.read(themeModeProvider.notifier).state = ThemeMode.dark;
      }
      await mount(t, compact: compact);
      final s = l(t);
      await reveal(t, s.appearanceNoteHistory);
      final scroll =
          t.widget<ListView>(find.byType(ListView).first).controller!;
      final before = scroll.offset;
      await t.tap(find.text(s.appearanceNoteHistory));
      await t.pumpAndSettle();
      await t.tap(find.text(s.appearanceNoteHistoryScopeCurrentCategory));
      await t.pumpAndSettle();
      expect(prefs.getString('noteHistoryScope'), 'currentCategory');
      await t.ensureVisible(find.text(s.appearanceNoteHistorySortRecent));
      await t.pumpAndSettle();
      await t.tap(find.text(s.appearanceNoteHistorySortRecent));
      await t.pumpAndSettle();
      expect(prefs.getString('noteHistorySort'), 'recent');
      final field = find.byType(TextFormField);
      await t.ensureVisible(field);
      for (final invalid in ['0', '101', '']) {
        await t.enterText(field, invalid);
        await t.pumpAndSettle();
        expect(prefs.getInt('noteHistoryLimit'), 20);
        expect(find.text(s.appearanceNoteHistoryLimitInvalid), findsOneWidget);
      }
      for (final valid in ['1', '100', '37']) {
        await t.enterText(field, valid);
        await t.pumpAndSettle();
        expect(prefs.getInt('noteHistoryLimit'), int.parse(valid));
        expect(find.text(s.appearanceNoteHistoryLimitInvalid), findsNothing);
      }
      await t.tap(find.byType(CloseButton));
      await t.pumpAndSettle();
      expect(scroll.offset, closeTo(before, .01));
      await t.tap(find.text(s.appearanceNoteHistory));
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '37'), findsOneWidget);
      await t.tap(find.text(s.commonClose));
      await t.pumpAndSettle();
      expect(container.read(noteHistoryScopeProvider),
          NoteHistoryScope.currentCategory);
      expect(container.read(noteHistorySortProvider), NoteHistorySort.recent);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('保留七条原生产目的页与返回的Provider作用域', (t) async {
    await mount(t);
    final s = l(t);
    final routes = <String, Type>{
      s.personalizeTitle: PersonalizePage,
      s.headerSkinTitle: HeaderSkinPage,
      s.mineDisplayScale: FontSettingsPage,
      s.exchangeRatePageTitle: ExchangeRatePage,
      s.mineLanguageSettings: LanguageSettingsPage,
      s.widgetManagement: WidgetManagementPage,
      s.appLockTitle: AppLockSettingsPage
    };
    for (final route in routes.entries) {
      await reveal(t, route.key);
      await t.tap(find.text(route.key));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(route.value), findsOneWidget, reason: route.key);
      Navigator.of(t.element(find.byType(route.value))).pop();
      await t.pumpAndSettle();
      expect(find.byType(AppearanceSettingsPage), findsOneWidget);
    }
    expect(await db.customSelect('SELECT * FROM ledgers').get(), hasLength(1));
    expect(t.takeException(), isNull);
  });
  testWidgets('真实只读预览与生产配置共享偏好，关闭后更新', (t) async {
    await mount(t,
        child: const Scaffold(
            body: SingleChildScrollView(child: LiveNoteHistoryPreview())));
    expect(find.byType(TextFormField), findsOneWidget);
    expect(t.widget<TextFormField>(find.byType(TextFormField)).enabled, false);
    await t.tap(find.text('打开真实显示与外观设置'));
    await t.pumpAndSettle();
    final s = l(t);
    await reveal(t, s.appearanceNoteHistory);
    await t.tap(find.text(s.appearanceNoteHistory));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text(s.appearanceNoteHistorySortRecent));
    await t.pumpAndSettle();
    await t.tap(find.text(s.appearanceNoteHistorySortRecent));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byType(TextFormField));
    await t.enterText(find.byType(TextFormField), '37');
    await t.pumpAndSettle();
    await t.tap(find.byType(CloseButton));
    await t.pumpAndSettle();
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(container.read(noteHistorySortProvider), NoteHistorySort.recent);
    expect(find.widgetWithText(TextFormField, '37'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
