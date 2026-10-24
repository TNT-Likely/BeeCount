import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/settings/font_settings_page.dart';
import 'package:beecount/providers/font_scale_provider.dart';
import 'package:beecount/presentation/v4/sections/font_settings_sections.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    await container.read(fontScaleInitProvider.future);
  });
  tearDown(() => container.dispose());
  Future<void> open(WidgetTester t, {bool compact = false}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = compact ? const Size(320, 568) : const Size(398, 844);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Consumer(builder: (context, ref, _) {
          ref.watch(fontScaleInitProvider);
          return MaterialApp(
            locale: const Locale('zh'),
            theme: beeTheme(
                brightness: compact ? Brightness.dark : Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear((compact ? 1.4 : 1) *
                        ref.watch(effectiveFontScaleProvider))),
                child: child!),
            home: const FontSettingsPage(),
          );
        })));
    await t.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester t, Finder target) async {
    final scrollable = find.byType(Scrollable).first;
    t.state<ScrollableState>(scrollable).position.jumpTo(0);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(target, 240,
        scrollable: scrollable, maxScrolls: 40);
    await t.ensureVisible(target);
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder target) async {
    await reveal(t, target);
    await t.tap(target);
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 100));
  }

  testWidgets('八档真实写入、完整预览与设备信息保留', (t) async {
    await open(t);
    expect(find.byType(FontPreviewSection), findsOneWidget);
    final labels = fontLevelLabels(lookupAppLocalizations(const Locale('zh')));
    for (final entry in labels.entries) {
      await tap(t, find.widgetWithText(BeeChoiceChip, entry.value));
      expect(container.read(fontScaleLevelProvider), entry.key);
      expect(container.read(customFontScaleProvider), 1);
      expect((await SharedPreferences.getInstance()).getInt('fontScaleLevel'),
          entry.key);
      expect(t.takeException(), isNull);
    }
    await tap(t, find.text('屏幕适配信息'));
    for (final label in [
      '屏幕密度',
      '屏幕宽度',
      '设备缩放',
      '用户缩放',
      '最终缩放',
      '基准设备',
      '推荐缩放'
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await reveal(t, find.text('1234.56'));
    expect(find.text('1234.56'), findsOneWidget);
    expect(find.text('列表项标题'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('从快捷档拖动真实滑杆，自定义、标准重选和重置都正确', (t) async {
    await open(t);
    await tap(t, find.widgetWithText(BeeChoiceChip, '大'));
    final slider = find.byType(Slider);
    await reveal(t, slider);
    final box = t.getRect(slider);
    await t.dragFrom(
        Offset(box.left + 24, box.center.dy), Offset((box.width - 48) * .7, 0));
    await t.pumpAndSettle();
    expect(container.read(customFontScaleProvider), isNot(1));
    expect(container.read(fontScaleLevelProvider), 0);
    expect(
        t
            .widgetList<BeeChoiceChip>(find.byType(BeeChoiceChip))
            .where((c) => c.selected),
        isEmpty);
    await tap(t, find.widgetWithText(BeeChoiceChip, '标准'));
    expect(container.read(effectiveFontScaleProvider), 1);
    await tap(t, find.widgetWithText(BeeChoiceChip, '极大'));
    await tap(t, find.widgetWithText(BeeButton, '重置到1.0x'));
    expect(container.read(effectiveFontScaleProvider), 1);
    await tap(t, find.widgetWithText(BeeChoiceChip, '大'));
    await tap(t, find.widgetWithText(BeeButton, '适配基准'));
    expect(container.read(effectiveFontScaleProvider), 1);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('320深色大字可操作全部控件，实时放大不横向溢出', (t) async {
    await open(t, compact: true);
    await tap(t, find.widgetWithText(BeeChoiceChip, '极大'));
    expect(t.takeException(), isNull);
    await tap(t, find.widgetWithText(BeeButton, '重置到1.0x'));
    await tap(t, find.text('屏幕适配信息'));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
