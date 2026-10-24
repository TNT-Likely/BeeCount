import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/account/accounts_page.dart';
import 'package:beecount/pages/account/account_edit_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/presentation/v4/bindings/account_sections.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'生活','CNY')");
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
    ]);
    // Fresh local rates exercise the original throttle: no network fake/provider.
    await repo.upsertAutoRates(
        base: 'CNY',
        rateDate: '2026-10-24',
        rates: {'USD': '7.1'},
        source: 'synthetic-local',
        fetchedAt: DateTime.now().toUtc());
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> ready(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (target.evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 300));
        return;
      }
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    expect(target, findsWidgets);
  }

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
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AccountsPage())));
    await ready(tester, find.byType(ListView).first);
  }

  AppLocalizations strings(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(AccountsPage)));
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('无账户保留设置和新建，进入真实编辑页不生成账户', (tester) async {
    await open(tester);
    final l = strings(tester);
    expect(find.text(l.accountsEmptyMessage), findsOneWidget);
    await tester.tap(find.text(l.accountAddButton));
    await ready(tester, find.byType(AccountEditPage));
    expect(await repo.getAllAccounts(), isEmpty);
    await close(tester);
  });

  testWidgets('真实单币种净资产包含隐藏账户，隐私和趋势选择保持原偏好', (tester) async {
    await repo.createAccount(
        ledgerId: 1,
        name: '现金',
        currency: 'CNY',
        type: 'cash',
        initialBalance: 100);
    await repo.createAccount(
        ledgerId: 1,
        name: '银行卡',
        currency: 'CNY',
        type: 'bank_card',
        initialBalance: 200);
    await repo.createAccount(
        ledgerId: 1,
        name: '信用卡',
        currency: 'CNY',
        type: 'credit_card',
        initialBalance: -50);
    final hidden = await repo.createAccount(
        ledgerId: 1,
        name: '隐藏现金',
        currency: 'CNY',
        type: 'cash',
        initialBalance: 10);
    await repo.setAccountHidden(hidden, true);
    final before = await repo.getAllAccounts();
    await open(tester);
    await ready(tester, find.byType(BeeAssetSummary));
    final summary =
        tester.widget<BeeAssetSummary>(find.byType(BeeAssetSummary));
    expect(summary.balances.single.text, '260');
    expect(summary.assets, ['310']);
    expect(summary.liabilities, ['50']);
    await tester.tap(find.byTooltip(strings(tester).v4AmountsHide));
    await tester.pumpAndSettle();
    expect(container.read(hideAmountsProvider), true);
    expect(find.textContaining('260', findRichText: true), findsNothing);
    final tabs = find.byType(BeeSegmented<AssetTrendView>);
    final composition = find.descendant(
        of: tabs, matching: find.text(strings(tester).assetComposition));
    await tester.ensureVisible(composition);
    await tester.tap(composition);
    await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getString('assetTrendView'),
        'composition');
    expect(await repo.getAllAccounts(), before);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('真实多币种缺失汇率不按1折算，详情保留负数符号且小屏大字可查看', (tester) async {
    await repo.createAccount(
        ledgerId: 1,
        name: '现金',
        currency: 'CNY',
        type: 'cash',
        initialBalance: 100);
    await repo.createAccount(
        ledgerId: 1,
        name: '美元贷款',
        currency: 'USD',
        type: 'loan',
        initialBalance: -10);
    await repo.createAccount(
        ledgerId: 1,
        name: '欧元现金',
        currency: 'EUR',
        type: 'cash',
        initialBalance: 50);
    final before = await repo.getAllAccounts();
    await open(tester,
        size: const Size(320, 568), scale: 1.4, brightness: Brightness.dark);
    await ready(tester, find.byType(BeeAssetSummary));
    for (var i = 0; i < 50; i++) {
      if (tester
              .widget<BeeAssetSummary>(find.byType(BeeAssetSummary))
              .onDetails !=
          null) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 40));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    final summary =
        tester.widget<BeeAssetSummary>(find.byType(BeeAssetSummary));
    expect(summary.balances.single.text, '¥29');
    await tester.tap(find.byTooltip(strings(tester).conversionDetailTitle));
    await ready(tester, find.byType(BeeAccountConversionRow));
    final rows = tester.widgetList<BeeAccountConversionRow>(
        find.byType(BeeAccountConversionRow));
    expect(rows.singleWhere((r) => r.code == 'USD').converted, '≈ ¥-71.00');
    expect(rows.singleWhere((r) => r.code == 'EUR').missingLabel,
        strings(tester).unconvertedBadge);
    expect(rows.singleWhere((r) => r.code == 'EUR').converted, isNull);
    expect(tester.takeException(), isNull);
    expect(await repo.getAllAccounts(), before);
    await close(tester);
  });
  testWidgets('设置读写真实默认账户，排除隐藏账户，功能开关保存且不改账单', (tester) async {
    final cash = await repo.createAccount(
        ledgerId: 1,
        name: '主现金',
        currency: 'CNY',
        type: 'cash',
        initialBalance: 100);
    final bank = await repo.createAccount(
        ledgerId: 1,
        name: '主卡',
        currency: 'CNY',
        type: 'bank_card',
        initialBalance: 200);
    final hidden = await repo.createAccount(
        ledgerId: 1,
        name: '隐藏卡',
        currency: 'CNY',
        type: 'bank_card',
        initialBalance: 50);
    await repo.setAccountHidden(hidden, true);
    final before = await repo.getAllAccounts();
    await open(tester);
    await ready(tester, find.byType(BeeAssetSummary));
    final l = strings(tester);
    await tester.tap(find.byTooltip(l.commonSettings));
    await ready(tester, find.byType(BeeAccountPreferences));
    await tester.tap(find.text(l.accountDefaultExpenseTitle));
    await ready(tester, find.byType(BeeAccountPicker));
    expect(find.text('隐藏卡'), findsNothing);
    await tester.enterText(find.byType(TextField), '主卡');
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(BeeAccountPicker),
        matching: find.byWidgetPredicate((w) => w is Text && w.data == '主卡')));
    await tester.pumpAndSettle();
    expect(
        (await SharedPreferences.getInstance())
            .getInt('default_expense_account_id'),
        bank);
    await tester.tap(find.text(l.accountDefaultIncomeTitle));
    await ready(tester, find.byType(BeeAccountPicker));
    await tester.tap(find.descendant(
        of: find.byType(BeeAccountPicker),
        matching: find.byWidgetPredicate((w) => w is Text && w.data == '主现金')));
    await tester.pumpAndSettle();
    expect(
        (await SharedPreferences.getInstance())
            .getInt('default_income_account_id'),
        cash);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
        (await SharedPreferences.getInstance())
            .getBool('account_feature_enabled'),
        false);
    expect(find.text(l.accountDefaultExpenseTitle), findsNothing);
    expect(await repo.getAllAccounts(), before);
    expect(await repo.getTransactionsByLedger(1), isEmpty);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('资产页实际新增账户返回刷新统计，保持同一真实列表', (tester) async {
    await open(tester);
    final l = strings(tester);
    await tester.tap(find.byTooltip(l.accountAddTooltip));
    await ready(tester, find.byKey(const ValueKey('account-name')));
    await tester.enterText(
        find.byKey(const ValueKey('account-name')), '从资产页新增');
    await tester.enterText(
        find.byKey(const ValueKey('account-balance-amount')), '123.5');
    await tester.tap(find.text(l.commonSave));
    await ready(tester, find.byType(BeeAssetSummary));
    final accounts = await repo.getAllAccounts();
    expect(accounts.single.name, '从资产页新增');
    expect(
        tester
            .widget<BeeAssetSummary>(find.byType(BeeAssetSummary))
            .balances
            .single
            .text,
        '123.5');
    expect(container.read(statsRefreshProvider), greaterThan(0));
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('隐藏分区默认折叠，恢复保留余额且不重新分配默认账户', (tester) async {
    final active = await repo.createAccount(
        ledgerId: 1,
        name: '在用现金',
        currency: 'CNY',
        type: 'cash',
        initialBalance: 100);
    final hidden = await repo.createAccount(
        ledgerId: 1,
        name: '待恢复卡',
        currency: 'CNY',
        type: 'bank_card',
        initialBalance: 50);
    await repo.setAccountHidden(hidden, true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('default_expense_account_id', active);
    await open(tester);
    await ready(tester, find.byType(BeeAssetSummary));
    final l = strings(tester);
    expect(find.text('待恢复卡'), findsNothing);
    final section = find.byType(HiddenAccountsSectionBinding);
    await tester.ensureVisible(section);
    await tester.tap(
        find.descendant(of: section, matching: find.byType(BeeMenuRow)).first);
    await tester.pumpAndSettle();
    final card =
        find.byWidgetPredicate((w) => w is BeeAccountCard && w.name == '待恢复卡');
    await tester.ensureVisible(card);
    final more =
        find.descendant(of: card, matching: find.byTooltip(l.commonMore));
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.accountRestore));
    await tester.pumpAndSettle();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(
        (await repo.getAllAccounts()).singleWhere((a) => a.id == hidden).hidden,
        false);
    expect(prefs.getInt('default_expense_account_id'), active);
    expect(
        tester
            .widget<BeeAssetSummary>(find.byType(BeeAssetSummary))
            .balances
            .single
            .text,
        '150');
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
