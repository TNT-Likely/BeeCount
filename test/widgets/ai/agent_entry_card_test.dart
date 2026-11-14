import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/budget_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/main/home/widgets/home_header.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/providers/budget_providers.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The retired 22px wordmark/32px legacy button is replaced by the actual v4
// Sparkles + AI action. Exercise its production binding, availability and callback.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Finder aiButton() => find.ancestor(
      of: find.text('AI'),
      matching: find.byWidgetPredicate((widget) => widget is TextButton));
  Future<void> open(WidgetTester tester,
      {required VoidCallback onTap,
      bool enabled = true,
      Brightness brightness = Brightness.light}) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentLedgerIdProvider.overrideWith((ref) => 1),
          currentLedgerProvider.overrideWith((ref) => Stream.value(Ledger(
              id: 1,
              name: '日常生活',
              currency: 'CNY',
              type: 'personal',
              createdAt: DateTime(2026),
              myRole: 'owner',
              memberCount: 1,
              isShared: false,
              monthStartDay: 1))),
          selectedMonthProvider.overrideWith((ref) => DateTime(2026, 10)),
          monthlyTotalsProvider.overrideWith((ref, params) async => (0.0, 0.0)),
          budgetOverviewProvider.overrideWith((ref) async => BudgetOverview(
              totalBudget: null,
              categoryBudgets: const [],
              daysRemaining: 0,
              dailyAvailable: 0)),
          aiAssistantEnabledProvider.overrideWith((ref) async => enabled),
        ],
        child: MaterialApp(
            theme: ThemeData(
                brightness: brightness,
                colorSchemeSeed: const Color(0xfff8c91c)),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
                body: IconTheme(
                    data: const IconThemeData(color: Colors.black),
                    child: HomeHeaderBinding(
                        jumping: false,
                        onMonth: () {},
                        onLedger: () {},
                        onAI: onTap,
                        onSearch: () {},
                        onTool: (_) {}))))));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  testWidgets('当前首页AI入口保留助手语义并调用真实绑定回调', (tester) async {
    var taps = 0;
    await open(tester, onTap: () => taps++);
    final button = aiButton();
    expect(find.byTooltip('AI助手'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('AI')), findsWidgets);
    expect(
        find.descendant(
            of: button,
            matching: find.byWidgetPredicate((widget) =>
                widget is BeeLineIcon && widget.name == 'Sparkles')),
        findsOneWidget);
    await tester.tap(button);
    await tester.pump();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('当前首页AI动作保留44px触控和紧凑图文规格', (tester) async {
    await open(tester, onTap: () {});
    final button = aiButton();
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    final mark = tester.widget<BeeLineIcon>(
        find.descendant(of: button, matching: find.byType(BeeLineIcon)));
    expect(mark.size, 18);
    final aiText = tester.widget<Text>(find.text('AI'));
    expect(aiText.style?.fontSize, 13);
    expect(aiText.style?.fontWeight, FontWeight.w600);
    await close(tester);
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('首页AI颜色使用当前主题，覆盖外层旧IconTheme $brightness', (tester) async {
      await open(tester, onTap: () {}, brightness: brightness);
      final finder = aiButton();
      final button = tester.widget<TextButton>(finder);
      final scheme = Theme.of(tester.element(finder)).colorScheme;
      final color = button.style!.foregroundColor!.resolve({});
      expect(color, Color.lerp(scheme.primary, scheme.onSurface, .4));
      expect(color, isNot(scheme.surface));
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  }

  testWidgets('关闭AI助手时当前首页不显示入口', (tester) async {
    await open(tester, onTap: () {}, enabled: false);
    expect(aiButton(), findsNothing);
    expect(find.byTooltip('AI助手'), findsNothing);
    await close(tester);
  });
}
