import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/main/home/widgets/home_reminders.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/providers/budget_providers.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('沿用月初七天、年末年度窗口与原偏好键，关闭范围互不影响', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(HomeReminderPolicy(DateTime(2026, 10, 7), prefs).monthly, isTrue);
    expect(HomeReminderPolicy(DateTime(2026, 10, 8), prefs).monthly, isFalse);
    expect(HomeReminderPolicy(DateTime(2026, 12, 14), prefs).annual, isFalse);
    final december = HomeReminderPolicy(DateTime(2026, 12, 15), prefs);
    expect(december.annual, isTrue);
    expect(december.reportYear, 2026);
    await december.dismissAnnual();
    final january = HomeReminderPolicy(DateTime(2027, 1, 7), prefs);
    expect(january.reportYear, 2026);
    expect(january.annual, isFalse);
    expect(january.monthly, isTrue);
    await january.dismissMonthly();
    expect(HomeReminderPolicy(DateTime(2027, 1, 7), prefs).monthly, isFalse);
    expect(HomeReminderPolicy(DateTime(2027, 2, 1), prefs).monthly, isTrue);
    expect(HomeReminderPolicy(DateTime(2027, 12, 15), prefs).annual, isTrue);
    expect(january.budget, isTrue);
    await january.dismissBudget();
    expect(HomeReminderPolicy(DateTime(2028, 1), prefs).budget, isFalse);
    expect(prefs.getInt('annual_report_reminder_dismissed'), 2026);
    expect(prefs.getString('last_month_reminder_dismissed'), '2027-1');
    expect(prefs.getBool('budget_setup_hint_dismissed'), isTrue);
  });

  for (final scale in [1.0, 1.4]) {
    testWidgets('小屏提醒保留查看临时关闭与主动关闭的不同语义 $scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final months = <DateTime>[];
      final years = <int>[];
      var budgetVisits = 0;
      final container = ProviderContainer(overrides: [
        currentMonthStartDayProvider.overrideWith((ref) => 10),
        budgetOverviewProvider.overrideWith((ref) async => null),
      ]);
      addTearDown(container.dispose);
      Future<void> open(int instance) async {
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
                theme: beeTheme(),
                locale: const Locale('zh'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: Scaffold(
                    body: HomeReminders(
                        key: ValueKey(instance),
                        now: DateTime(2027, 1, 5),
                        onMonthly: months.add,
                        onAnnual: years.add,
                        onBudget: () => budgetVisits++)))));
        await tester.pumpAndSettle();
      }

      await open(0);
      expect(find.byType(BeeStatus), findsNWidgets(3));
      final l10n =
          AppLocalizations.of(tester.element(find.byType(HomeReminders)));
      await tester.tap(find.text(l10n.homeLastMonthReportView).first);
      await tester.pumpAndSettle();
      // 自定义每月10日起算：1月5日属于12月，查看其前一个月11月。
      expect(months, [DateTime(2026, 11)]);
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(HomeReminderPolicy.monthlyKey), isFalse);
      await tester.tap(find.text(l10n.homeAnnualReportView));
      await tester.pumpAndSettle();
      expect(years, [2026]);
      expect(prefs.containsKey(HomeReminderPolicy.annualKey), isFalse);
      await tester.tap(find.text(l10n.budgetSetupAction));
      await tester.pumpAndSettle();
      expect(budgetVisits, 1);
      expect(find.byType(BeeStatus), findsOneWidget);
      await open(1);
      expect(find.byType(BeeStatus), findsNWidgets(3));
      final close =
          MaterialLocalizations.of(tester.element(find.byType(HomeReminders)))
              .closeButtonTooltip;
      await tester.tap(find.byTooltip(close).first);
      await tester.pumpAndSettle();
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(HomeReminderPolicy.monthlyKey), '2027-1');
      await open(2);
      expect(find.byType(BeeStatus), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
