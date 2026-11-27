import 'package:beecount/cloud/cloud_version_policy.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/main/home/widgets/home_reminders.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/providers/budget_providers.dart';
import 'package:beecount/widgets/cloud_version_notice_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('zh')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CloudVersionNoticeCard renders zh, zh_TW, and en copy',
      (tester) async {
    const compat = CloudVersionCompatibility(
      status: CloudVersionMatchStatus.upgradeCloudRecommended,
      appVersion: '4.1.0',
      serverVersion: '1.10.1',
      targetVersion: '1.11.0',
    );

    for (final entry in <(Locale, String)>[
      (const Locale('zh'), '建议升级 BeeCount Cloud'),
      (const Locale('zh', 'TW'), '建議升級 BeeCount Cloud'),
      (const Locale('en'), 'Upgrade BeeCount Cloud'),
    ]) {
      await tester.pumpWidget(
        _wrap(
          CloudVersionNoticeCard(
            compatibility: compat,
            primaryLabel: 'Recheck',
            onPrimary: () {},
            secondaryLabel: 'Guide',
            onSecondary: () {},
          ),
          locale: entry.$1,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
      expect(find.text('App v4.1.0'), findsOneWidget);
      expect(find.text('Cloud v1.10.1'), findsOneWidget);
    }
  });

  testWidgets('HomeReminders shows one-time version banner and persists dismiss',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      HomeReminderPolicy.budgetKey: true,
    });
    const compat = CloudVersionCompatibility(
      status: CloudVersionMatchStatus.upgradeCloudRecommended,
      appVersion: '4.1.0',
      serverVersion: '1.10.1',
      targetVersion: '1.11.0',
    );
    var openedSync = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudVersionCompatibilityProvider.overrideWith((_) async => compat),
          budgetOverviewProvider.overrideWith((_) async => null),
        ],
        child: _wrap(
          HomeReminders(
            now: DateTime(2026, 11, 20),
            onMonthly: (_) {},
            onAnnual: (_) {},
            onBudget: () {},
            onCloudVersion: () => openedSync = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('建议升级 BeeCount Cloud'), findsOneWidget);
    await tester.tap(find.text('去查看'));
    await tester.pump();
    expect(openedSync, isTrue);

    // Dismissing hides the reminder and persists the version pair.
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.text('建议升级 BeeCount Cloud'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('cloud_version_dismissed_pairs_v1'),
      contains(compat.dismissPairKey),
    );
    // Drain LoggerService debounce timer before test teardown.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('HomeReminders shows paused sync copy when blocking',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      HomeReminderPolicy.budgetKey: true,
    });
    const compat = CloudVersionCompatibility(
      status: CloudVersionMatchStatus.upgradeCloudRequired,
      appVersion: '4.1.0',
      serverVersion: '1.9.0',
      targetVersion: '1.10.0',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudVersionCompatibilityProvider.overrideWith((_) async => compat),
          budgetOverviewProvider.overrideWith((_) async => null),
        ],
        child: _wrap(
          HomeReminders(
            now: DateTime(2026, 11, 20),
            onMonthly: (_) {},
            onAnnual: (_) {},
            onBudget: () {},
            onCloudVersion: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('云同步已暂停 · 请升级 Cloud'), findsOneWidget);
    expect(find.text('先离线记账'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
