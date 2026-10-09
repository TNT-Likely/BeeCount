// Run only in the verified QA bundle on a simulator owned by this run.
import 'dart:convert';

import 'package:beecount/main.dart' show MainApp;
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/pages/account/account_edit_page.dart';
import 'package:beecount/pages/account/account_detail_page.dart';
import 'package:beecount/pages/account/accounts_page.dart';
import 'package:beecount/pages/transaction/transaction_editor_page.dart';
import 'package:beecount/pages/data/import_confirm_page.dart';
import 'package:beecount/pages/data/import_page.dart';
import 'package:beecount/widgets/biz/amount_editor_sheet.dart';
import 'package:beecount/data/db.dart' as schema;
import 'package:beecount/pages/main/home_page.dart';
import 'package:beecount/providers/database_providers.dart';
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
      ..headers['Content-Type'] = 'application/json';
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
    'scenario': 'account-balance-trust',
    'cases': cases
  };
  testWidgets('production account forms, payments, import and live Cloud',
      (tester) async {
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
    final ledgerId = await repo.createLedger(name: 'QA 金额可信度 $runId');
    container.read(currentLedgerIdProvider.notifier).state = ledgerId;
    await prefs.setInt('current_ledger_id', ledgerId);
    final categoryId = await repo.createCategory(
        name: 'QA消费', kind: 'expense', icon: 'restaurant');
    await repo.createCategory(name: '转账', kind: 'transfer', icon: 'swap_horiz');
    final bankId = await repo.createAccount(
        ledgerId: ledgerId,
        name: 'QA 银行卡',
        type: 'bank_card',
        initialBalance: 10000);
    final usdId = await repo.createAccount(
        ledgerId: ledgerId,
        name: 'QA美元',
        type: 'bank_card',
        currency: 'USD',
        initialBalance: 100);
    final otherLedger =
        await repo.createLedger(name: 'QA 跨账本', currency: 'USD');
    await repo.addTransaction(
        ledgerId: otherLedger,
        type: 'expense',
        amount: 20,
        accountId: usdId,
        happenedAt: DateTime.now(),
        note: 'QA 另一账本消费',
        currencyCode: 'USD',
        nativeAmount: 20);
    await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 5,
        accountId: usdId,
        happenedAt: DateTime.now(),
        note: 'QA 外币消费',
        currencyCode: 'USD',
        nativeAmount: 35);
    Future<void> sync() async {
      final result = await engine
          .sync(ledgerId: ledgerId.toString())
          .timeout(const Duration(seconds: 60));
      expect(result.error, isNull);
    }

    await engine.sync(ledgerId: otherLedger.toString());
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

    Future<schema.Account> createCard(String name, String amount,
        {bool overpayment = false, String? limit}) async {
      await open(AccountEditPage(ledgerId: ledgerId));
      await tap('信用卡');
      await fill('account-name', name);
      if (overpayment) {
        final toggle = find.descendant(
            of: find.byType(SegmentedButton<bool>), matching: find.text('溢缴款'));
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pump();
      }
      await fill('account-balance-amount', amount);
      if (limit != null) await fill('account-credit-limit', limit);
      await capture(
          overpayment ? '02-app-overpayment-input' : '01-app-debt-input');
      await tap('保存');
      await waitUi(() => find.byType(AccountEditPage).evaluate().isEmpty);
      return (await repo.getAllAccounts()).singleWhere((a) => a.name == name);
    }

    final beforeCreate =
        (await database.select(database.transactions).get()).length;
    final card = await createCard('QA信用卡', '1000', limit: '20000');
    expect(card.initialBalance, -1000);
    expect(card.billingDay, isNull);
    expect(card.paymentDueDay, isNull);
    expect((await database.select(database.transactions).get()).length,
        beforeCreate);
    final prepaid = await createCard('QA溢缴卡', '200', overpayment: true);
    expect(prepaid.initialBalance, 200);
    expect(prepaid.creditLimit, isNull);
    pass('A01',
        'Production App form accepted positive debt/overpayment amounts and optional metadata; stored -1000/+200 without creating expenses');
    await open(AccountEditPage(account: prepaid, ledgerId: ledgerId));
    await waitUi(() => find
        .byKey(const ValueKey('account-balance-amount'))
        .evaluate()
        .isNotEmpty);
    await fill('account-name', 'QA溢缴卡改名');
    await tap('保存');
    await waitUi(() => find.byType(AccountEditPage).evaluate().isEmpty);
    expect(await repo.getAccountBalance(prepaid.id), 200);
    pass('A02',
        'Editing a positive-balance card name preserved its sign, baseline and transactions');
    Future<void> record(String type, double amount, String note,
        {int? to}) async {
      await open(TransactionEditorPage(
          initialKind: type,
          quickAdd: true,
          initialCategoryId: type == 'transfer' ? null : categoryId,
          initialAccountId: type == 'transfer' ? bankId : card.id,
          initialToAccountId: to));
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
      await tester.pump(const Duration(milliseconds: 500));
      for (final digit in amount.toInt().toString().split('')) {
        await tester.tap(find.text(digit).last);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tap('完成');
      await waitUi(() => find.byType(AmountEditorSheet).evaluate().isEmpty);
      await home();
      expect(
          (await database.select(database.transactions).get())
              .singleWhere((t) => t.note == note)
              .amount,
          amount);
    }

    await record('expense', 1000, 'QA 信用消费');
    expect(await repo.getAccountBalance(card.id), -2000);
    await record('transfer', 2200, 'QA 信用还款', to: card.id);
    expect(await repo.getAccountBalance(card.id), 200);
    expect(await repo.getAccountBalance(bankId), 7800);
    expect((await repo.getAccountStats(card.id)).expense, 1000);
    await open(AccountDetailPage(account: (await repo.getAccount(card.id))!));
    await waitUi(() => find.text('溢缴款').evaluate().isNotEmpty);
    await capture('03-app-after-overpayment');
    await home();
    await record('expense', 300, 'QA 溢缴后消费');
    expect(await repo.getAccountBalance(card.id), -100);
    expect((await repo.getAccountStats(card.id)).expense, 1300);
    final cny = (await repo.getNetWorthBreakdownByCurrency())['CNY']!;
    expect(cny.totalAssets, 8000);
    expect(cny.totalLiabilities, -100);
    expect(cny.netWorth, 7900);
    pass('A03',
        'Production consumption/payment UI recorded expenses once; paying 2200 created +200 overpayment, then spending 300 restored -100 debt; CNY assets/debt/net = 8000/100/7900');
    await open(AccountDetailPage(account: (await repo.getAccount(bankId))!));
    await waitUi(() => find.text('全部流水').evaluate().isNotEmpty);
    expect(find.text('QA 信用还款'), findsWidgets);
    await tap('收入与转入');
    await tap('全部流水');
    await waitUi(() => find.text('QA 信用还款').evaluate().isNotEmpty);
    await capture('04-app-all-flows');
    await home();
    pass('A04',
        'Ordinary account defaults to all flows, includes outgoing repayment, and switching filters returns the same transaction');
    await sync();
    var snap = await snapshot();
    expect(
        (snap['accounts'] as List)
            .cast<Map>()
            .singleWhere((a) => a['syncId'] == card.syncId)['initialBalance'],
        -1000);
    final items = (snap['items'] as List).cast<Map>();
    expect(
        items.singleWhere((t) => t['note'] == 'QA 信用还款')['type'], 'transfer');
    expect(items.singleWhere((t) => t['note'] == 'QA 信用还款')['amount'], 2200);
    pass('A05',
        'Real App sync uploaded signed balances and transfer relationships into the authenticated Cloud snapshot');
    debugPrint('QA_STAGE_READY_WEB_ACCOUNT_TRUST');
    var webDone = false;
    for (var i = 0; i < 1800; i++) {
      snap = await snapshot();
      final accts = (snap['accounts'] as List).cast<Map>();
      if (accts.any(
              (a) => a['syncId'] == card.syncId && a['name'] == 'QA Web信用卡') &&
          accts.any((a) =>
              a['name'] == 'QA Web欠款卡' && a['initialBalance'] == -5000)) {
        webDone = true;
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    expect(webDone, true,
        reason: 'Actual Web UI must rename existing card and create debt card');
    await sync();
    expect((await repo.getAccount(card.id))!.name, 'QA Web信用卡');
    expect(await repo.getAccountBalance(card.id), -100);
    final webCard =
        (await repo.getAllAccounts()).singleWhere((a) => a.name == 'QA Web欠款卡');
    expect(webCard.initialBalance, -5000);
    await open(AccountsPage());
    await waitUi(() => find.text('QA Web欠款卡').evaluate().isNotEmpty);
    await capture('05-app-after-web');
    await home();
    pass('A06',
        'Actual Web form rename and positive debt creation pulled back through the production App engine, preserving the existing card balance');
    await open(const ImportPage());
    await open(const ImportConfirmPage(
        csvText:
            '日期,类型,金额,币种,账户,备注\n2026-10-09,支出,2000,JPY,QA日元,QA 日元导入\n2026-10-09,支出,10,CNY,QA人民币,QA 人民币导入',
        hasHeader: true,
        billType: BillSourceType.generic));
    await waitUi(() => find.text('下一步').evaluate().isNotEmpty);
    await tap('下一步');
    await tap('开始导入');
    await waitUi(() => find.text('确认账户币种').evaluate().isNotEmpty);
    expect(find.text('QA日元 · JPY'), findsOneWidget);
    await capture('06-app-currency-preview');
    final beforeImportCount =
        (await database.select(database.transactions).get()).length;
    await tap('取消');
    expect((await repo.getAllAccounts()).any((a) => a.name == 'QA日元'), false);
    expect((await database.select(database.transactions).get()).length,
        beforeImportCount);
    await tap('开始导入');
    await waitUi(() => find.text('确认账户币种').evaluate().isNotEmpty);
    await tap('开始导入');
    await waitUi(() => find.byType(ImportConfirmPage).evaluate().isEmpty);
    final jpy =
        (await repo.getAllAccounts()).singleWhere((a) => a.name == 'QA日元');
    expect(jpy.currency, 'JPY');
    final imported = (await database.select(database.transactions).get())
        .singleWhere((t) => t.note == 'QA 日元导入');
    expect(imported.currencyCode, 'JPY');
    expect(imported.amount, 2000);
    expect(imported.accountId, jpy.id);
    await sync();
    snap = await snapshot();
    expect(
        (snap['accounts'] as List)
            .cast<Map>()
            .singleWhere((a) => a['syncId'] == jpy.syncId)['currency'],
        'JPY');
    pass('A07',
        'Actual CSV confirmation/import UI created a JPY account in a CNY ledger and preserved original 2000 JPY transaction and Cloud account identity');
    final txCount = (await database.select(database.transactions).get()).length;
    await sync();
    await sync();
    expect(
        (await database.select(database.transactions).get()).length, txCount);
    pass('A08', 'Repeated real synchronization did not duplicate transactions');
    await api('POST', '/__qa__/fault',
        body: {'run_id': runId, 'offline': true});
    try {
      await record('expense', 10, 'QA 故障后消费');
      final unavailable = await engine.sync(ledgerId: ledgerId.toString());
      expect(unavailable.error, isNotNull);
      expect(await repo.getAccountBalance(card.id), -110);
    } finally {
      await api('POST', '/__qa__/fault',
          body: {'run_id': runId, 'offline': false});
    }
    await sync();
    await sync();
    snap = await snapshot();
    final recovered = (snap['items'] as List)
        .cast<Map>()
        .where((t) => t['note'] == 'QA 故障后消费')
        .toList();
    expect(recovered.length, 1);
    expect(recovered.single['amount'], 10);
    expect((await database.select(database.transactions).get()).length,
        txCount + 1);
    pass('A09',
        'QA Cloud API 503 simulation: production UI saved expense locally; recovery synchronized it exactly once, retaining card balance -110');
    await home();
    await tap('明细');
    await capture('07-app-home-final');
    final finalAccounts = await repo.getAllAccounts();
    binding.reportData!.addAll({
      'ledger_sync_id': ledger.syncId,
      'normal_ui_markers': ['QA 日元导入'],
      'final_accounts': finalAccounts
          .map((a) => {
                'sync_id': a.syncId,
                'name': a.name,
                'type': a.type,
                'currency': a.currency,
                'initial_balance': a.initialBalance
              })
          .toList(),
      'final_snapshot': await snapshot(),
      'tested_ui_navigation':
          'Production pages opened under MainApp; fixture navigation does not cover every menu entry',
    });
    await prefs.setString('qa_run_id', runId);
  }, timeout: const Timeout(Duration(minutes: 60)));
}
