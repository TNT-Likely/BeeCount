import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/settings/automation_page.dart';
import 'package:beecount/pages/settings/reminder_settings_page.dart';
import 'package:beecount/pages/transaction/recurring_transaction_page.dart';
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
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'自动化验收','CNY')");
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(LocalRepository(db))
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  for (final compact in [false, true]) {
    testWidgets('自动化原两项真实页面往返、保留作用域和数据 ${compact ? '320英文深色140%' : '398中文'}',
        (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize =
          compact ? const Size(320, 568) : const Size(398, 844);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              theme: beeTheme(
                  brightness: compact ? Brightness.dark : Brightness.light),
              locale: Locale(compact ? 'en' : 'zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (c, child) => MediaQuery(
                  data: MediaQuery.of(c).copyWith(
                      textScaler: TextScaler.linear(compact ? 1.4 : 1)),
                  child: child!),
              home: Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          child: const Text('进入'),
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const AutomationPage()))))))));
      await t.tap(find.text('进入'));
      await t.pumpAndSettle();
      expect(find.byType(BeeMenuRow), findsNWidgets(2));
      final l = AppLocalizations.of(t.element(find.byType(AutomationPage)));
      expect(find.text(l.automationPageSubtitle), findsOneWidget);
      await t.tap(find.text(l.mineRecurringTransactions));
      await t.pumpAndSettle();
      expect(find.byType(RecurringTransactionPage), findsOneWidget);
      expect(find.text(l.recurringTransactionEmpty), findsOneWidget);
      Navigator.of(t.element(find.byType(RecurringTransactionPage))).pop();
      await t.pumpAndSettle();
      await t.tap(find.text(l.mineReminderSettings));
      await t.pumpAndSettle();
      expect(find.byType(ReminderSettingsPage), findsOneWidget);
      expect(find.text(l.reminderDailyTitle), findsOneWidget);
      Navigator.of(t.element(find.byType(ReminderSettingsPage))).pop();
      await t.pumpAndSettle();
      expect(find.byType(AutomationPage), findsOneWidget);
      expect(
          await db.customSelect('SELECT * FROM transactions').get(), isEmpty);
      expect(
          await db.customSelect('SELECT * FROM recurring_transactions').get(),
          isEmpty);
      expect(
          await db.customSelect('SELECT * FROM ledgers').get(), hasLength(1));
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(find.text('进入'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
