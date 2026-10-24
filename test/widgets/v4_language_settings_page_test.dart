import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/settings/language_settings_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/utils/app_localizations_resolver.dart';
import 'package:beecount/widget/widget_manager.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Only the OS widget renderer is captured; the page, language notifier,
// preference writes, localization resolution and updateAppWidget mapping are real.
class _WidgetRenderer implements WidgetManager {
  final List<Invocation> updates = [];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #updateAllWidgets) {
      updates.add(invocation);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;
  late _WidgetRenderer renderer;
  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        widgetManagerProvider.overrideWithValue(renderer),
      ]);
  setUp(() async {
    SharedPreferences.setMockInitialValues(
        {'selected_language': 'zh', 'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    renderer = _WidgetRenderer();
    container = makeContainer();
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'语言验收','CNY')");
  });
  tearDown(() async {
    container.dispose();
    setAppLocaleOverride(null);
    await db.close();
  });
  Future<void> open(WidgetTester t, {bool compact = false}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = compact ? const Size(320, 568) : const Size(398, 844);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Consumer(
            builder: (context, ref, _) => MaterialApp(
                  theme: beeTheme(
                      brightness: compact ? Brightness.dark : Brightness.light),
                  locale: ref.watch(languageProvider) ?? const Locale('zh'),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(compact ? 1.4 : 1)),
                      child: child!),
                  home: const LanguageSettingsPage(),
                ))));
    await t.pumpAndSettle();
  }

  Future<void> choose(WidgetTester t, int index) async {
    final choice = find.byType(BeeOnboardingChoice).at(index);
    await t.ensureVisible(choice);
    await t.tap(choice);
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpAndSettle();
  }

  testWidgets('原五项语言、实际偏好和地区清理，刷新使用新语言文案', (t) async {
    await open(t);
    expect(find.byType(BeeOnboardingChoice), findsNWidgets(5));
    for (final row in [
      (3, const Locale('en')),
      (2, const Locale('zh', 'TW')),
      (4, const Locale('ko')),
      (1, const Locale('zh'))
    ]) {
      await choose(t, row.$1);
      expect(container.read(languageProvider), row.$2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('selected_language'), row.$2.languageCode);
      expect(prefs.getString('selected_language_country'), row.$2.countryCode);
      final translated = lookupAppLocalizations(row.$2);
      expect(resolveAppLocalizations(null).localeName, translated.localeName);
      expect(renderer.updates.last.namedArguments[#glanceTitleLabel],
          translated.widgetGalleryGlanceTitle);
      expect(
          t
              .widget<BeeOnboardingChoice>(
                  find.byType(BeeOnboardingChoice).at(row.$1))
              .selected,
          isTrue);
    }
    await choose(t, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(container.read(languageProvider), isNull);
    expect(prefs.containsKey('selected_language'), isFalse);
    expect(prefs.containsKey('selected_language_country'), isFalse);
    expect(await db.customSelect('SELECT * FROM ledgers').get(), hasLength(1));
    expect(await db.customSelect('SELECT * FROM transactions').get(), isEmpty);
    expect(renderer.updates, hasLength(5));
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('重新创建Provider从真实偏好恢复英语选中态', (t) async {
    await open(t);
    await choose(t, 3);
    await t.pumpWidget(const SizedBox.shrink());
    container.dispose();
    container = makeContainer();
    await open(t);
    expect(container.read(languageProvider), const Locale('en'));
    expect(find.text(lookupAppLocalizations(const Locale('en')).languageTitle),
        findsOneWidget);
    expect(
        t
            .widget<BeeOnboardingChoice>(find.byType(BeeOnboardingChoice).at(3))
            .selected,
        isTrue);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('320深色140%可滚动选择全部选项，退页后不访问失效Ref', (t) async {
    await open(t, compact: true);
    await choose(t, 4);
    expect(container.read(languageProvider), const Locale('ko'));
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.byType(BeeOnboardingChoice).at(3));
    await t.tap(find.byType(BeeOnboardingChoice).at(3));
    await t.pump();
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
  });
}
