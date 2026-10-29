import 'package:beecount/app.dart';
import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/account/accounts_page.dart';
import 'package:beecount/pages/account/overview/widgets/account_sections.dart';
import 'package:beecount/providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;
  late List<Account> before;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      selectedMonthProvider.overrideWith((ref) => DateTime(2026, 10)),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
      beecountCloudProviderInstance.overrideWith((ref) async => null),
    ]);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'QA cold lifecycle','CNY')");
    for (var id = 1; id <= 24; id++) {
      await db.customStatement(
          'INSERT INTO accounts(id,ledger_id,name,currency,type,initial_balance) '
          'VALUES(?,1,?,?,?,?)',
          [
            id,
            'QA cold account $id',
            id.isEven ? 'USD' : 'CNY',
            id % 4 == 0 ? 'bank_card' : 'cash',
            100.0,
          ]);
    }
    await db.customStatement('''
WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM n WHERE x<15000)
INSERT INTO transactions(id,ledger_id,type,amount,account_id,happened_at,currency_code,native_amount)
SELECT x,1,CASE WHEN x%5=0 THEN 'income' ELSE 'expense' END,
       0.01,1+(x%24),1792022400,
       CASE WHEN (1+(x%24))%2=0 THEN 'USD' ELSE 'CNY' END,
       CASE WHEN (1+(x%24))%2=0 THEN 0.071 ELSE 0.01 END FROM n
''');
    await repo.upsertAutoRates(
        base: 'CNY',
        rateDate: '2026-10-26',
        rates: {'USD': '7.1'},
        source: 'synthetic-cold-lifecycle',
        fetchedAt: DateTime.now().toUtc());
    before = await repo.getAllAccounts();
  });
  tearDown(() async {
    expect(await repo.getAllAccounts(), before);
    expect((await repo.getCountsForLedger(ledgerId: 1)).txCount, 15000);
    container.dispose();
    await db.close();
  });
  testWidgets('15000笔与24账户冷挂主入口，未点击资产也不在子行构建时通知祖先', (tester) async {
    final oldInterval = VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    const quickActions = MethodChannel('plugins.flutter.io/quick_actions');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(quickActions, (_) async => null);
    tester.view.physicalSize = const Size(398, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    try {
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              theme: beeTheme(),
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const BeeApp())));
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)));
      }
      expect(container.read(bottomTabIndexProvider), 0);
      expect(find.byType(AccountsPage, skipOffstage: false), findsOneWidget);
      expect(
          find.byType(AccountCardBinding, skipOffstage: false), findsWidgets);
      expect(tester.takeException(), isNull);

      // A real refresh/requery must remain reactive after the cold mount.
      container.read(hideAmountsProvider.notifier).state = true;
      container.read(statsRefreshProvider.notifier).state++;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)));
      }
      final rows = tester.widgetList<BeeCompactAccountRow>(
          find.byType(BeeCompactAccountRow, skipOffstage: false));
      expect(rows, isNotEmpty);
      expect(rows.every((row) => row.hidden), isTrue);
      expect(container.read(multiCurrencyActiveProvider), isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      VisibilityDetectorController.instance.updateInterval = oldInterval;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(quickActions, null);
    }
  });
}
