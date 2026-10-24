import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/data/repositories/account_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/account/account_edit_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingAdjustmentRepository extends LocalRepository {
  _FailingAdjustmentRepository(super.db);
  bool fail = true;
  @override
  Future<AccountBalanceUpdateResult> setAccountBalance({
    required int ledgerId,
    required int accountId,
    required double targetBalance,
    required bool createBalanceAdjustment,
    DateTime? happenedAt,
    String? note,
  }) async {
    final result = await super.setAccountBalance(
        ledgerId: ledgerId,
        accountId: accountId,
        targetBalance: targetBalance,
        createBalanceAdjustment: createBalanceAdjustment,
        happenedAt: happenedAt,
        note: note);
    if (fail) throw StateError('Synthetic adjustment rollback');
    return result;
  }
}

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
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> open(WidgetTester tester,
      {Account? account,
      Size size = const Size(398, 844),
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
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => AccountEditPage(
                                    ledgerId: 1, account: account))),
                        child: const Text('打开账户')))))));
    await tester.tap(find.text('打开账户'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester, {bool decision = false}) async {
    final button = find.text('保存');
    await tester.ensureVisible(button);
    await tester.tap(button);
    if (decision) {
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        final close = find.byType(CloseButton);
        if (close.evaluate().length == 1 &&
            tester.getCenter(close).dy < tester.view.physicalSize.height) {
          break;
        }
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CloseButton).hitTestable(), findsOneWidget);
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> modal(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(CloseButton).evaluate().isNotEmpty) break;
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }

  Future<Account> cashWithHistory() async {
    final id = await repo.createAccount(
        ledgerId: 1, name: '现金', type: 'cash', initialBalance: 100);
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        accountId: id,
        amount: 20,
        happenedAt: DateTime(2026, 10, 24));
    return (await repo.getAccount(id))!;
  }

  testWidgets('新建账户校验必填且保存真实币种、类型和初始金额，不生成账单', (tester) async {
    await open(tester);
    await save(tester);
    expect(await repo.getAllAccounts(), isEmpty);
    await tester.enterText(find.byKey(const ValueKey('account-name')), '合成现金');
    await tester.enterText(
        find.byKey(const ValueKey('account-balance-amount')), '100.25');
    await save(tester);
    final account = (await repo.getAllAccounts()).single;
    expect(account.name, '合成现金');
    expect(account.type, 'cash');
    expect(account.currency, 'CNY');
    expect(account.initialBalance, 100.25);
    expect(await repo.getTransactionsByLedger(1), isEmpty);
    expect(find.byType(AccountEditPage), findsNothing);
    await close(tester);
  });
  for (final overpayment in [false, true]) {
    testWidgets('信用卡欠款与溢缴款符号正确，并保存全部资料 $overpayment', (tester) async {
      await open(tester);
      final l =
          AppLocalizations.of(tester.element(find.byType(AccountEditPage)));
      await tester.tap(find.text(l.accountTypeCreditCard));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('account-name')), '信用卡测试');
      await tester.enterText(
          find.byKey(const ValueKey('account-balance-amount')), '100');
      if (overpayment) {
        await tester.ensureVisible(find.text(l.creditCardOverpayment));
        await tester.tap(find.text(l.creditCardOverpayment));
      }
      for (final item in {
        'account-credit-limit': '1000',
        'account-bank-name': '合成银行',
        'account-card-last-four': '6789',
        'account-note': '信用卡备注'
      }.entries) {
        final field = find.byKey(ValueKey(item.key));
        await tester.ensureVisible(field);
        await tester.enterText(field, item.value);
      }
      await save(tester);
      final saved = (await repo.getAllAccounts()).single;
      expect(saved.type, 'credit_card');
      expect(saved.initialBalance, overpayment ? 100 : -100);
      expect(saved.creditLimit, 1000);
      expect(saved.bankName, '合成银行');
      expect(saved.cardLastFour, '6789');
      expect(saved.note, '信用卡备注');
      expect(await repo.getTransactionsByLedger(1), isEmpty);
      expect(
          (await SharedPreferences.getInstance())
              .getBool('cc_reminder_enabled_${saved.id}'),
          false);
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  }
  testWidgets('小屏大字体信用卡保留1至28号选择和清除，并定位屏外必填错误', (tester) async {
    await open(tester,
        size: const Size(320, 568), scale: 1.4, brightness: Brightness.dark);
    final l = AppLocalizations.of(tester.element(find.byType(AccountEditPage)));
    await tester.tap(find.text(l.accountTypeCreditCard));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(l.billingDay));
    await tester.tap(find.text(l.billingDay));
    await modal(tester);
    expect(find.text('29'), findsNothing);
    final day =
        find.descendant(of: find.byType(BeeSheet), matching: find.text('28'));
    await tester.ensureVisible(day);
    await tester.tap(day);
    await tester.pumpAndSettle();
    expect(find.text(l.dayOfMonth(28)), findsOneWidget);
    await tester.ensureVisible(find.byTooltip(l.commonRemove));
    await tester.tap(find.byTooltip(l.commonRemove));
    await tester.pumpAndSettle();
    expect(find.text(l.dayOfMonth(28)), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('account-note')));
    await save(tester);
    expect(await repo.getAllAccounts(), isEmpty);
    expect(find.text(l.accountNameRequired).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('开启还款提醒而未选还款日时阻止保存', (tester) async {
    await open(tester);
    final l = AppLocalizations.of(tester.element(find.byType(AccountEditPage)));
    await tester.tap(find.text(l.accountTypeCreditCard));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('account-name')), '提醒待配置');
    final toggle = find.byType(BeeToggleRow);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await save(tester);
    expect(await repo.getAllAccounts(), isEmpty);
    expect(find.text(l.creditCardReminderDueRequired), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('无流水账户可以选择美元并实际保存币种', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const ValueKey('account-name')), '合成美元');
    final currency = find.byKey(const ValueKey('account-currency'));
    await tester.ensureVisible(currency);
    await tester.tap(currency);
    await modal(tester);
    final usd =
        find.descendant(of: find.byType(BeeSheet), matching: find.textContaining('(USD)'));
    await tester.ensureVisible(usd);
    await tester.tap(usd);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('account-balance-amount')), '12.50');
    await save(tester);
    final saved = (await repo.getAllAccounts()).single;
    expect(saved.currency, 'USD');
    expect(saved.initialBalance, 12.5);
    expect(await repo.getTransactionsByLedger(1), isEmpty);
    await close(tester);
  });
  testWidgets('仅修改元信息不覆盖打开页面后并发新增账单的余额', (tester) async {
    final account = await cashWithHistory();
    await open(tester, account: account);
    await tester.enterText(find.byKey(const ValueKey('account-name')), '更名现金');
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        accountId: account.id,
        amount: 5,
        happenedAt: DateTime(2026, 10, 24));
    await save(tester);
    expect((await repo.getAccount(account.id))!.name, '更名现金');
    expect(await repo.getAccountBalance(account.id), 75);
    expect((await repo.getTransactionsByLedger(1)).length, 2);
    await close(tester);
  });
  testWidgets('银行卡切换为现金清除卡信息，同时保留正在编辑的备注', (tester) async {
    final id = await repo.createAccount(
        ledgerId: 1,
        name: '银行卡',
        type: 'bank_card',
        initialBalance: 100,
        bankName: '合成银行',
        cardLastFour: '1234',
        note: '旧备注');
    await open(tester, account: await repo.getAccount(id));
    final l = AppLocalizations.of(tester.element(find.byType(AccountEditPage)));
    await tester.tap(find.text(l.accountTypeCash));
    await tester.pumpAndSettle();
    final note = find.byKey(const ValueKey('account-note'));
    await tester.ensureVisible(note);
    await tester.enterText(note, '现金仍保留这条备注');
    await save(tester);
    final saved = (await repo.getAccount(id))!;
    expect(saved.type, 'cash');
    expect(saved.bankName, isEmpty);
    expect(saved.cardLastFour, isEmpty);
    expect(saved.note, '现金仍保留这条备注');
    expect(await repo.getAccountBalance(id), 100);
    await close(tester);
  });
  testWidgets('备注可以实际清空，估值账户的元信息保存保留原价值', (tester) async {
    final id = await repo.createAccount(
        ledgerId: 1,
        name: '合成投资',
        type: 'investment',
        initialBalance: -100,
        note: '需要清除');
    await open(tester, account: await repo.getAccount(id));
    expect(find.byKey(const ValueKey('account-balance-amount')), findsNothing);
    final note = find.byKey(const ValueKey('account-note'));
    await tester.ensureVisible(note);
    await tester.enterText(note, '');
    await save(tester);
    final saved = (await repo.getAccount(id))!;
    expect(saved.initialBalance, -100);
    expect(saved.note, isEmpty);
    await close(tester);
  });
  testWidgets('有交易的账户保持原币种锁，并使用规范提示弹窗', (tester) async {
    final account = await cashWithHistory();
    await open(tester, account: account);
    final l = AppLocalizations.of(tester.element(find.byType(AccountEditPage)));
    final currency = find.byKey(const ValueKey('account-currency'));
    await tester.ensureVisible(currency);
    await tester.tap(currency);
    await modal(tester);
    expect(find.byType(BeeDialog), findsOneWidget);
    expect(find.text(l.accountCurrencyLocked), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect((await repo.getAccount(account.id))!.currency, 'CNY');
    expect(await repo.getAccountBalance(account.id), 80);
    await close(tester);
  });
  testWidgets('隐藏取消不改数据，确认清空目标默认账户，恢复不擅自重设默认', (tester) async {
    final account = await cashWithHistory();
    final other =
        await repo.createAccount(ledgerId: 1, name: '其他现金', type: 'cash');
    await container
        .read(defaultAccountSetterProvider)
        .setDefaultExpenseAccountId(account.id);
    await container
        .read(defaultAccountSetterProvider)
        .setDefaultIncomeAccountId(other);
    await open(tester, account: account);
    final l = AppLocalizations.of(tester.element(find.byType(AccountEditPage)));
    Future<void> ask() async {
      await tester.ensureVisible(find.text(l.accountHide));
      await tester.tap(find.text(l.accountHide));
      await modal(tester);
    }

    await ask();
    await tester.tap(find.descendant(
        of: find.byType(BeeDialog), matching: find.text(l.commonCancel)));
    await tester.pumpAndSettle();
    expect((await repo.getAccount(account.id))!.hidden, isFalse);
    expect(await container.read(defaultExpenseAccountIdProvider.future),
        account.id);
    await ask();
    await tester.tap(find.descendant(
        of: find.byType(BeeDialog), matching: find.text(l.accountHide)));
    await tester.pumpAndSettle();
    expect((await repo.getAccount(account.id))!.hidden, isTrue);
    expect(
        await container.read(defaultExpenseAccountIdProvider.future), isNull);
    expect(await container.read(defaultIncomeAccountIdProvider.future), other);
    await open(tester, account: await repo.getAccount(account.id));
    await tester.ensureVisible(find.text(l.accountUnhide));
    await tester.tap(find.text(l.accountUnhide));
    await tester.pumpAndSettle();
    expect((await repo.getAccount(account.id))!.hidden, isFalse);
    expect(await repo.getAccountBalance(account.id), 80);
    expect(
        await container.read(defaultExpenseAccountIdProvider.future), isNull);
    await close(tester);
  });
  testWidgets('删除规范确认的取消和确认均保留原有流水', (tester) async {
    final account = await cashWithHistory();
    final original = await repo.getTransactionsByLedger(1);
    await open(tester, account: account);
    final l = AppLocalizations.of(tester.element(find.byType(AccountEditPage)));
    Future<void> ask() async {
      await tester.ensureVisible(find.text(l.commonDelete));
      await tester.tap(find.text(l.commonDelete));
      await modal(tester);
      expect(find.text(l.accountDeleteWarningMessage(1)), findsOneWidget);
    }

    await ask();
    await tester.tap(find.descendant(
        of: find.byType(BeeDialog), matching: find.text(l.commonCancel)));
    await tester.pumpAndSettle();
    expect(await repo.getAccount(account.id), account);
    await ask();
    await tester.tap(find.descendant(
        of: find.byType(BeeDialog), matching: find.text(l.commonDelete)));
    await tester.pumpAndSettle();
    expect(await repo.getAccount(account.id), isNull);
    expect(await repo.getTransactionsByLedger(1), original);
    await close(tester);
  });
  testWidgets('余额写入失败回滚资料和平账记录，重试只产生一次调整', (tester) async {
    final account = await cashWithHistory();
    final before = await repo.getTransactionsByLedger(1);
    final failing = _FailingAdjustmentRepository(db);
    container.dispose();
    repo = failing;
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
    ]);
    await open(tester, account: account);
    await tester.enterText(find.byKey(const ValueKey('account-name')), '失败后重试');
    await tester.enterText(
        find.byKey(const ValueKey('account-balance-amount')), '90');
    final l = AppLocalizations.of(tester.element(find.byType(AccountEditPage)));
    Future<void> adjust() async {
      await save(tester, decision: true);
      await tester.tap(find.text(l.accountBalanceAdjustmentCreate));
      await tester.pump(const Duration(milliseconds: 300));
      final confirm = find.text(l.accountBalanceAdjustmentConfirmCreate);
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
    }

    await adjust();
    expect(await repo.getAccount(account.id), account);
    expect(await repo.getTransactionsByLedger(1), before);
    expect(await repo.getAllCategories(), isEmpty);
    failing.fail = false;
    await adjust();
    expect((await repo.getAccount(account.id))!.name, '失败后重试');
    expect(await repo.getAccountBalance(account.id), 90);
    expect((await repo.getTransactionsByLedger(1)).length, 2);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  for (final choice in <bool?>[null, false, true]) {
    testWidgets('真实账户余额修改保留取消/仅改余额/平账记录三分支 $choice', (tester) async {
      final account = await cashWithHistory();
      final before = await repo.getTransactionsByLedger(1);
      await open(tester, account: account);
      await tester.enterText(
          find.byKey(const ValueKey('account-balance-amount')), '90');
      await save(tester, decision: true);
      final l =
          AppLocalizations.of(tester.element(find.byType(AccountEditPage)));
      if (choice == null) {
        await tester.tap(find.byType(CloseButton));
      } else {
        if (choice) {
          await tester.tap(find.text(l.accountBalanceAdjustmentCreate));
          await tester.pump(const Duration(milliseconds: 300));
        }
        final confirm = find.text(choice
            ? l.accountBalanceAdjustmentConfirmCreate
            : l.accountBalanceAdjustmentConfirmOnly);
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
      }
      await tester.pumpAndSettle();
      expect(
          await repo.getAccountBalance(account.id), choice == null ? 80 : 90);
      final after = await repo.getTransactionsByLedger(1);
      expect(after.length, choice == true ? before.length + 1 : before.length);
      for (final original in before) {
        expect(after.singleWhere((item) => item.id == original.id), original);
      }
      if (choice == true) {
        final created = after
            .singleWhere((item) => !before.any((old) => old.id == item.id));
        expect(created.type, 'income');
        expect(created.amount, 10);
        expect(created.accountId, account.id);
      }
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  }
}
