// Run only in the verified QA bundle on a simulator owned by this run.
import 'dart:convert';
import 'package:drift/drift.dart' as d;

import 'package:beecount/main.dart' show MainApp;
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/pages/account/account_edit_page.dart';
import 'package:beecount/pages/account/account_detail_page.dart';
import 'package:beecount/pages/account/accounts_page.dart';
import 'package:beecount/pages/transaction/transaction_editor_page.dart';
import 'package:beecount/widgets/biz/amount_editor_sheet.dart';
import 'package:beecount/data/db.dart' as schema;
import 'package:beecount/pages/main/home_page.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/statistics_providers.dart';
import 'package:beecount/providers/language_provider.dart';
import 'package:beecount/providers/sync_providers.dart';
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount/providers/ui_state_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const runId = String.fromEnvironment('QA_RUN_ID');
const origin = String.fromEnvironment('QA_ORIGIN');
const email = String.fromEnvironment('QA_EMAIL');
const password = String.fromEnvironment('QA_PASSWORD');
const appId = String.fromEnvironment('QA_APP_ID');

Future<http.Response> request(String method, String path,
    {Map<String, dynamic>? body, String? token}) async {
  final uri = Uri.parse(origin).resolve(path);
  if (uri.origin != origin || uri.host != '127.0.0.1' || uri.scheme != 'http') {
    throw StateError('Refusing a request outside this QA Cloud');
  }
  final client = http.Client();
  try {
    final req = http.Request(method, uri)
      ..followRedirects = false
      ..headers['Content-Type'] = 'application/json'
      ..headers['X-BeeCount-Capabilities'] = 'loan-flow-v1';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);
    return await http.Response.fromStream(await client.send(req))
        .timeout(const Duration(seconds: 30));
  } finally {
    client.close();
  }
}

Future<dynamic> api(String method, String path,
    {Map<String, dynamic>? body, String? token}) async {
  final response = await request(method, path, body: body, token: token);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('QA API $method $path returned ${response.statusCode}');
  }
  return jsonDecode(response.body);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  final cases = <Map<String, dynamic>>[];
  binding.reportData = {
    'run_id': runId,
    'scenario': 'loan-account',
    'cases': cases
  };
  testWidgets('production loan principal forms and live Cloud', (tester) async {
    expect(appId, 'com.tntlikely.beecount.qa');
    expect((await PackageInfo.fromPlatform()).packageName, appId);
    final identity = await api('GET', '/__qa__/identity');
    expect(identity['run_id'], runId);
    expect(identity['database_is_isolated'], true);
    await api('POST', '/api/v1/auth/register', body: {
      'email': email,
      'password': password,
      'client_type': 'app',
      'device_name': runId
    });
    await HomeWidget.setAppGroupId('group.com.tntlikely.beecount.qa');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', 'zh');
    await prefs.setBool('welcome_shown', true);
    await prefs.setString('noteDisplayMode', 'note');
    await CloudServiceStore().saveAndActivate(const CloudServiceConfig(
        type: CloudBackendType.beecountCloud,
        name: 'Isolated QA Cloud',
        beecountCloudBaseUrl: origin,
        beecountCloudEmail: email,
        beecountCloudPassword: password));
    final container = ProviderContainer();
    final runtime = (await container.read(activeCloudRuntimeProvider.future))!;
    final cloud = runtime.provider! as BeeCountCloudProvider;
    expect(cloud.baseUrl, origin);
    await cloud.auth.signInWithEmail(email: email, password: password);
    final engine = runtime.syncEngine!;
    final repo = container.read(repositoryProvider) as LocalRepository;
    final database = container.read(databaseProvider);
    final ledgerId = await repo.createLedger(name: 'QA 贷款本金 $runId');
    container.read(currentLedgerIdProvider.notifier).state = ledgerId;
    await prefs.setInt('current_ledger_id', ledgerId);
    final categoryId = await repo.createCategory(
        name: 'QA利息', kind: 'expense', icon: 'restaurant');
    await repo.createCategory(name: '转账', kind: 'transfer', icon: 'swap_horiz');
    final bankId = await repo.createAccount(
        ledgerId: ledgerId,
        name: 'QA 银行卡',
        type: 'bank_card',
        initialBalance: 20000);
    final legacyBank = await repo.createAccount(
        ledgerId: ledgerId,
        name: 'QA 历史银行卡',
        type: 'bank_card',
        initialBalance: 5000);
    final cardId = await repo.createAccount(
        ledgerId: ledgerId,
        name: 'QA 信用卡',
        type: 'credit_card',
        initialBalance: -1000);
    final houseId = await repo.createAccount(
        ledgerId: ledgerId,
        name: 'QA 房产',
        type: 'real_estate',
        initialBalance: 800000);
    final legacyId = await database.into(database.accounts).insert(
        schema.AccountsCompanion.insert(
            ledgerId: ledgerId,
            name: 'QA 旧贷款',
            type: const d.Value('loan'),
            initialBalance: const d.Value(-30000),
            syncId: d.Value('legacy-$runId')));
    await database.into(database.transactions).insert(
        schema.TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'transfer',
            amount: 1000,
            accountId: d.Value(legacyBank),
            toAccountId: d.Value(legacyId),
            happenedAt:
                d.Value(DateTime.now().subtract(const Duration(days: 7))),
            note: const d.Value('QA 历史本金记录'),
            syncId: d.Value('legacy-tx-$runId')));
    Future<void> sync() async {
      final result = await engine
          .sync(ledgerId: ledgerId.toString())
          .timeout(const Duration(seconds: 60));
      expect(result.error, isNull);
    }

    await sync();
    final ledger = (await repo.getLedgerById(ledgerId))!;
    final login = await api('POST', '/api/v1/auth/login', body: {
      'email': email,
      'password': password,
      'client_type': 'web',
      'device_name': '$runId-web'
    });
    final token = login['access_token'] as String;
    Future<Map<String, dynamic>> snapshot() async {
      final result = await api(
          'GET', '/api/v1/sync/full?ledger_id=${ledger.syncId}',
          token: token);
      return jsonDecode(result['snapshot']['payload']['content'] as String)
          as Map<String, dynamic>;
    }

    void pass(String id, String detail) =>
        cases.add({'id': id, 'status': 'PASS', 'detail': detail});
    Future<void> waitUi(bool Function() ready) async {
      for (var i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (ready()) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await binding.takeScreenshot('failure-account-ui');
      throw StateError('Production account UI did not reach expected state');
    }

    Future<void> tap(String text) async {
      await waitUi(() => find.text(text).evaluate().isNotEmpty);
      final target = find.text(text).last;
      await tester.ensureVisible(target);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 400));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await binding.takeScreenshot(name);
    }

    await container.read(primaryColorInitProvider.future);
    await container.read(themeModeInitProvider.future);
    container.read(themeModeProvider.notifier).state = ThemeMode.light;
    await container
        .read(languageProvider.notifier)
        .setLanguage(const Locale('zh'));
    container.read(appInitStateProvider.notifier).state = AppInitState.ready;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MainApp()));
    await waitUi(() => find.byType(HomePage).evaluate().isNotEmpty);
    final navigator = Navigator.of(tester.element(find.byType(HomePage).first));
    // Navigation preparation only; all account and transaction writes below use production controls.
    Future<void> open(Widget page) async {
      navigator.push(MaterialPageRoute(builder: (_) => page));
      await tester.pump(const Duration(milliseconds: 700));
    }

    Future<void> home() async {
      navigator.popUntil((route) => route.isFirst);
      await tester.pump(const Duration(milliseconds: 700));
    }

    Future<void> fill(String key, String text) async {
      final finder = find.byKey(ValueKey(key));
      await waitUi(() => finder.evaluate().isNotEmpty);
      await tester.ensureVisible(finder);
      await tester.enterText(finder, text);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 300));
    }

    final beforeCreation = await repo.getTransactionCountByAccount(bankId);
    await open(AccountEditPage(ledgerId: ledgerId));
    await tap('负债账户');
    await tap('贷款');
    await fill('account-name', 'QA 贷款');
    await fill('account-balance-amount', '50000');
    expect(find.text('信用额度'), findsNothing);
    await capture('01-loan-positive-principal-input');
    await tap('保存');
    await waitUi(() => find.byType(AccountEditPage).evaluate().isEmpty);
    final loan =
        (await repo.getAllAccounts()).singleWhere((a) => a.name == 'QA 贷款');
    expect(loan.loanBalanceVersion, 1);
    expect(loan.initialBalance, -50000);
    expect(await repo.getTransactionCountByAccount(bankId), beforeCreation);
    pass('L01',
        'Production loan form stores positive 50000 principal as signed -50000 without creating income/expense');

    await open(AccountEditPage(ledgerId: ledgerId));
    await tap('负债账户');
    await tap('贷款');
    await fill('account-name', 'QA 取消贷款');
    await home();
    expect(
        (await repo.getAllAccounts()).any((a) => a.name == 'QA 取消贷款'), false);
    pass('L02', 'Canceling account creation leaves no account or transaction');

    Future<void> finishAmount(double amount, String note) async {
      await waitUi(() => find.byType(AmountEditorSheet).evaluate().isNotEmpty);
      await waitUi(() => find
          .descendant(
              of: find.byType(AmountEditorSheet),
              matching: find.byType(CircularProgressIndicator))
          .evaluate()
          .isEmpty);
      await tester.enterText(
          find
              .descendant(
                  of: find.byType(AmountEditorSheet),
                  matching: find.byType(TextField))
              .first,
          note);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 400));
      for (final digit in amount.toInt().toString().split('')) {
        await tester.tap(find.text(digit).last);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await capture('amount-${note.hashCode.abs()}');
      await tap('完成');
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<void> record(String kind, double amount, String note,
        {required int from, int? to, bool valid = true}) async {
      final count = (await database.select(database.transactions).get()).length;
      await open(TransactionEditorPage(
          initialKind: kind,
          quickAdd: true,
          initialCategoryId: kind == 'transfer' ? null : categoryId,
          initialAccountId: from,
          initialToAccountId: to));
      await finishAmount(amount, note);
      if (valid) {
        await waitUi(() => find.byType(AmountEditorSheet).evaluate().isEmpty);
        expect(
            (await database.select(database.transactions).get())
                .singleWhere((t) => t.note == note)
                .amount,
            amount);
      } else {
        expect(
            (await database.select(database.transactions).get()).length, count);
      }
      await home();
    }

    await open(AccountDetailPage(account: loan));
    await waitUi(() => find.text('归还本金').evaluate().isNotEmpty);
    expect(find.text('信用额度'), findsNothing);
    await capture('02-loan-detail-actions');
    await home();
    await open(AccountsPage());
    final repayAction = find.byKey(ValueKey('loan-repay-${loan.id}'));
    expect((await container.read(netWorthBreakdownByCurrencyProvider.future))['CNY']!.totalLiabilities, -81000);
    await capture('02b-account-totals-after-creation');
    await tester.scrollUntilVisible(repayAction, 350,
        scrollable: find.descendant(of: find.byType(AccountsPage), matching: find.byType(Scrollable)).first,
        maxScrolls: 20);
    await tester.ensureVisible(repayAction);
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 12 && repayAction.hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(find.descendant(of: find.byType(AccountsPage), matching: find.byType(Scrollable)).first, const Offset(0, -220));
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(repayAction.hitTestable(), findsOneWidget);
    await capture('02c-loan-card-repay-entry');
    await tester.tap(repayAction.hitTestable());
    await tester.pump(const Duration(milliseconds: 600));
    await waitUi(() => find.byType(TransactionEditorPage).evaluate().isNotEmpty);
    await tester.ensureVisible(find.text('QA 银行卡').first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('QA 银行卡').first);
    await tester.pump(const Duration(milliseconds: 600));
    await finishAmount(1000, 'QA 归还本金');
    await waitUi(() => find.byType(AmountEditorSheet).evaluate().isEmpty);
    await home();
    expect(await repo.getAccountBalance(loan.id), -49000);
    expect(await repo.getAccountBalance(bankId), 19000);
    expect(
        (await repo.monthlyTotals(ledgerId: ledgerId, month: DateTime.now()))
            .$2,
        0);
    pass('L03',
        'Actual loan repayment action transfers 1000 bank→loan: cash 19000, outstanding 49000, ordinary expense 0');

    await record('transfer', 10000, 'QA 借入本金', from: loan.id, to: bankId);
    expect(await repo.getAccountBalance(loan.id), -59000);
    expect(await repo.getAccountBalance(bankId), 29000);
    expect(
        (await repo.monthlyTotals(ledgerId: ledgerId, month: DateTime.now()))
            .$1,
        0);
    await record('expense', 50, 'QA 单记利息', from: bankId);
    expect(
        (await repo.monthlyTotals(ledgerId: ledgerId, month: DateTime.now()))
            .$2,
        50);
    pass('L04',
        'Production borrowing adds 10000 cash/debt without income; separate interest records exactly 50 ordinary expense');

    await record('expense', 100, 'QA 信用消费回归', from: cardId);
    await record('transfer', 1200, 'QA 信用还款回归', from: bankId, to: cardId);
    expect(await repo.getAccountBalance(cardId), 100);
    expect(await repo.getAccountBalance(houseId), 800000);
    pass('L05',
        'Credit consumption/overpayment and valuation property remain intact');

    final countBeforeReview =
        (await database.select(database.transactions).get()).length;
    await open(AccountDetailPage(account: (await repo.getAccount(legacyId))!));
    await tap('核对贷款欠款');
    await waitUi(() => find.byType(AlertDialog).evaluate().isNotEmpty);
    await tester.enterText(
        find
            .descendant(
                of: find.byType(AlertDialog), matching: find.byType(TextField))
            .first,
        '30000');
    FocusManager.instance.primaryFocus?.unfocus();
    await tap('确定');
    await waitUi(() => find.byType(AlertDialog).evaluate().isEmpty);
    await capture('03-legacy-loan-reconciled');
    await home();
    final legacy = (await repo.getAccount(legacyId))!;
    expect(legacy.syncId, 'legacy-$runId');
    expect(legacy.loanBalanceVersion, 1);
    expect(legacy.initialBalance, -30000);
    expect(await repo.getAccountBalance(legacyId), -30000);
    expect((await database.select(database.transactions).get()).length,
        countBeforeReview);
    pass('L06',
        'Legacy review preserves identity/current 30000 debt; original 1000 movement stays historical and is not applied to the new principal baseline without fabricated cash');

    await open(AccountEditPage(
        account: (await repo.getAccount(loan.id))!, ledgerId: ledgerId));
    await fill('account-name', 'QA 贷款改名');
    await tap('保存');
    await waitUi(() => find.byType(AccountEditPage).evaluate().isEmpty);
    expect(await repo.getAccountBalance(loan.id), -59000);
    pass('L07',
        'Metadata rename after transactions preserves current principal');

    await record('transfer', 60000, 'QA 超额还本金',
        from: bankId, to: loan.id, valid: false);
    expect(await repo.getAccountBalance(loan.id), -59000);
    pass('L08',
        'Production form rejects overrepayment with no partial bank/loan write');
    await open(AccountDetailPage(account: (await repo.getAccount(loan.id))!));
    await waitUi(() => find
        .textContaining('QA 归还本金', findRichText: true)
        .evaluate()
        .isNotEmpty);
    await waitUi(() => find.textContaining('本金减少', findRichText: true).evaluate().isNotEmpty && find.textContaining('本金增加', findRichText: true).evaluate().isNotEmpty);
    expect(find.textContaining('本金减少', findRichText: true), findsWidgets);
    expect(find.textContaining('本金增加', findRichText: true), findsWidgets);
    await capture('04-loan-principal-history');
    await home();
    await sync();
    var snap = await snapshot();
    expect(
        (snap['accounts'] as List).cast<Map>().singleWhere(
            (a) => a['syncId'] == loan.syncId)['loanBalanceVersion'],
        1);
    expect(
        (snap['items'] as List)
            .cast<Map>()
            .singleWhere((t) => t['note'] == 'QA 归还本金')['toAccountId'],
        loan.syncId);
    pass('L09',
        'Authenticated production SyncEngine uploads principal contract and exact transfer relationship');

    debugPrint('QA_STAGE_READY_WEB_LOAN');
    var webDone = false;
    for (var i = 0; i < 1800; i++) {
      snap = await snapshot();
      final accounts = (snap['accounts'] as List).cast<Map>();
      if (accounts.any(
              (a) => a['syncId'] == loan.syncId && a['name'] == 'QA Web贷款') &&
          accounts.any((a) =>
              a['name'] == 'QA Web新增贷款' && a['initialBalance'] == -7000) &&
          (snap['items'] as List)
              .cast<Map>()
              .any((t) => t['note'] == 'QA Web归还本金' && t['amount'] == 2000)) {
        webDone = true;
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    expect(webDone, true,
        reason:
            'Actual Web UI must rename loan, create new principal loan and repay 2000');
    await sync();
    expect((await repo.getAccount(loan.id))!.name, 'QA Web贷款');
    expect(await repo.getAccountBalance(loan.id), -57000);
    expect(await repo.getAccountBalance(bankId), 25750);
    final webLoan = (await repo.getAllAccounts())
        .singleWhere((a) => a.name == 'QA Web新增贷款');
    expect(webLoan.loanBalanceVersion, 1);
    expect(await repo.getAccountBalance(webLoan.id), -7000);
    await open(AccountDetailPage(account: (await repo.getAccount(loan.id))!));
    await waitUi(() => find
        .textContaining('QA Web归还本金', findRichText: true)
        .evaluate()
        .isNotEmpty);
    await capture('05-web-repayment-pulled-back');
    await home();
    pass('L10',
        'Actual Web create/rename/repay UI pulls back to the same App loan identity, outstanding 57000 and cash 25750');

    final countBeforeFault =
        (await database.select(database.transactions).get()).length;
    await api('POST', '/__qa__/fault',
        body: {'run_id': runId, 'offline': true});
    try {
      await record('transfer', 500, 'QA 故障后还本', from: bankId, to: loan.id);
      final failed = await engine.sync(ledgerId: ledgerId.toString());
      expect(failed.error, isNotNull);
      expect(await repo.getAccountBalance(loan.id), -56500);
    } finally {
      await api('POST', '/__qa__/fault',
          body: {'run_id': runId, 'offline': false});
    }
    await sync();
    await sync();
    snap = await snapshot();
    expect(
        (snap['items'] as List)
            .cast<Map>()
            .where((t) => t['note'] == 'QA 故障后还本')
            .length,
        1);
    expect((await database.select(database.transactions).get()).length,
        countBeforeFault + 1);
    expect(await repo.getAccountBalance(bankId), 25250);
    pass('L11',
        'QA 503 service outage preserves local repayment; recovery and repeated sync upload exactly one 500 transfer');
    await home();
    await tap('明细');
    await capture('06-final-home');
    final finalAccounts = await repo.getAllAccounts();
    binding.reportData!.addAll({
      'ledger_sync_id': ledger.syncId,
      'normal_ui_markers': ['QA 故障后还本'],
      'final_accounts': [
        for (final a in finalAccounts)
          {
            'sync_id': a.syncId,
            'name': a.name,
            'type': a.type,
            'currency': a.currency,
            'initial_balance': a.initialBalance,
            'loan_balance_version': a.loanBalanceVersion,
            'balance': await repo.getAccountBalance(a.id),
          }
      ],
      'final_snapshot': snap,
      'tested_ui_navigation':
          'Production pages under MainApp; fixture navigation opens pages, all tested writes use actual controls',
    });
    await prefs.setString('qa_run_id', runId);
  }, timeout: const Timeout(Duration(minutes: 60)));
}
