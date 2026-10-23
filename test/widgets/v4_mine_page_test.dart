import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/main/mine_page.dart';
import 'package:beecount/presentation/v4/bindings/mine_cloud.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/providers/github_star_provider.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' hide SyncStatus;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'生活','CNY')");
    await repo.addTransaction(
        ledgerId: 1,
        type: 'income',
        amount: 100,
        happenedAt: DateTime(2026, 10, 23));
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 12,
        currencyCode: 'USD',
        nativeAmount: 85.2,
        happenedAt: DateTime(2026, 10, 24));
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      currentLedgerProvider.overrideWith((ref) => repo.watchLedger(1)),
      accountFeatureEnabledProvider.overrideWith((ref) async => false),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
      activeCloudConfigProvider
          .overrideWith((ref) async => CloudServiceConfig.localStorage()),
      mineCloudUserProvider.overrideWith((ref) async => null),
      beecountCloudServerVersionProvider.overrideWith((ref) async => null),
      githubStarCountProvider.overrideWith((ref) async => 2500),
    ]);
    container.read(displayNameProvider.notifier).state = '验收昵称';
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> open(WidgetTester tester,
      {Size size = const Size(398, 844),
      double scale = 1,
      Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(brightness: brightness),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: const MinePage())));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  testWidgets('我的展示真实账本历史折算余额和笔数，离线同步不可点击且保留状态', (tester) async {
    final before = await repo.getTransactionsByLedger(1);
    await open(tester);
    final balance =
        tester.widget<BeeLedgerBalance>(find.byType(BeeLedgerBalance));
    expect(balance.amount, '14.8');
    expect(balance.count, '2');
    expect(balance.days, '2');
    expect(find.text('验收昵称'), findsOneWidget);
    final sync = tester.widget<BeeSyncStatus>(find.byType(BeeSyncStatus));
    expect(sync.state, BeeSyncState.unconfigured);
    expect(sync.onTap, isNull);
    expect(await repo.getTransactionsByLedger(1), before);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('昵称规范弹窗取消不修改，确认去首尾空格且不改交易', (tester) async {
    final before = await repo.getTransactionsByLedger(1);
    await open(tester);
    final l = AppLocalizations.of(tester.element(find.byType(MinePage)));
    await tester.tap(find.text('验收昵称'));
    await tester.pumpAndSettle();
    expect(find.byType(BeeDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(find.byType(TextFormField), '临时昵称');
    await tester.tap(find.text(l.commonCancel));
    await tester.pumpAndSettle();
    expect(container.read(displayNameProvider), '验收昵称');
    await tester.tap(find.text('验收昵称'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  新昵称  ');
    await tester.tap(find.text(l.commonSave));
    await tester.pumpAndSettle();
    expect(container.read(displayNameProvider), '新昵称');
    expect(await repo.getTransactionsByLedger(1), before);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('320 大字深色保留 Android 全部菜单，Star 弹窗关闭后不跳动', (tester) async {
    await open(tester,
        size: const Size(320, 568), scale: 1.4, brightness: Brightness.dark);
    final l = AppLocalizations.of(tester.element(find.byType(MinePage)));
    for (final label in [
      l.smartBilling,
      l.dataManagement,
      l.automation,
      l.appearanceSettings,
      l.about,
      l.mineHelp,
      l.mineSupportAuthor,
      l.annualReportTitle,
      l.mineShareApp,
      l.mineCopyPromoText
    ]) {
      await tester.scrollUntilVisible(find.text(label), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(label), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.ensureVisible(find.text(l.mineSupportAuthor));
    await tester.pumpAndSettle();
    final pos =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    final before = pos.pixels;
    await tester.tap(find.text(l.mineSupportAuthor));
    await tester.pumpAndSettle();
    expect(find.byType(BeeDialog), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(pos.pixels, before);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('同步展示覆盖原有全部差异状态，错误和冲突不会伪装为成功', (tester) async {
    await open(tester);
    final l = AppLocalizations.of(tester.element(find.byType(MinePage)));
    final expected = [
      BeeSyncState.signedOut,
      BeeSyncState.unconfigured,
      BeeSyncState.noCloudData,
      BeeSyncState.synced,
      BeeSyncState.localNewer,
      BeeSyncState.cloudNewer,
      BeeSyncState.conflict,
      BeeSyncState.error
    ];
    final diffs = [
      SyncDiff.notLoggedIn,
      SyncDiff.notConfigured,
      SyncDiff.noRemote,
      SyncDiff.inSync,
      SyncDiff.localNewer,
      SyncDiff.cloudNewer,
      SyncDiff.different,
      SyncDiff.error
    ];
    for (var i = 0; i < diffs.length; i++) {
      final v = mineSyncPresentation(diffs[i], l);
      expect(v.state, expected[i]);
      expect(v.label, isNotEmpty);
    }
    expect(mineSyncPresentation(null, l).state, BeeSyncState.checking);
    await close(tester);
  });
}
