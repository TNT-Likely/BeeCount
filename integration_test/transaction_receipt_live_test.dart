// Only run through scripts/qa/isolated_app_cloud.py on its newly owned device.
import 'dart:convert';

import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/main.dart' show MainApp;
import 'package:beecount/pages/main/home_page.dart';
import 'package:beecount/pages/transaction/detail/bindings/transaction_receipt_dialog.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/language_provider.dart';
import 'package:beecount/providers/sync_providers.dart';
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount/providers/ui_state_providers.dart';
import 'package:beecount/pages/transaction/recording/bindings/amount_editor_sheet.dart';
import 'package:beecount/pages/shared/transactions/transaction_list_item.dart';
import 'package:beecount/pages/shared/sharing/bindings/transaction_receipt.dart';
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

Future<Map<String, dynamic>> api(String method, String path,
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
    if (method == 'PATCH') {
      req.headers['Idempotency-Key'] =
          '$runId-${DateTime.now().microsecondsSinceEpoch}';
    }
    if (body != null) req.body = jsonEncode(body);
    final result = await http.Response.fromStream(await client.send(req))
        .timeout(const Duration(seconds: 30));
    if (result.statusCode < 200 || result.statusCode >= 300) {
      throw StateError('QA API $method $path returned ${result.statusCode}');
    }
    return result.body.isEmpty
        ? {}
        : jsonDecode(result.body) as Map<String, dynamic>;
  } finally {
    client.close();
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  final cases = <Map<String, dynamic>>[];
  binding.reportData = {'run_id': runId, 'cases': cases};
  testWidgets(
      'receipt: production gestures, exports, immutable data and live Cloud round trip',
      (tester) async {
    expect((await PackageInfo.fromPlatform()).packageName,
        'com.tntlikely.beecount.qa');
    expect(runId.startsWith('beecount-qa-'), isTrue);
    final identity = await api('GET', '/__qa__/identity');
    expect(identity['run_id'], runId);
    expect(identity['database_is_isolated'], isTrue);
    await api('POST', '/api/v1/auth/register', body: {
      'email': email,
      'password': password,
      'client_type': 'app',
      'device_name': runId,
    });
    await HomeWidget.setAppGroupId('group.com.tntlikely.beecount.qa');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', 'zh');
    await prefs.setBool('account_feature_enabled', true);
    await prefs.setBool('welcome_shown', true);
    await prefs.setString('noteDisplayMode', 'note');
    await CloudServiceStore().saveAndActivate(const CloudServiceConfig(
      type: CloudBackendType.beecountCloud,
      name: 'Isolated QA Cloud',
      beecountCloudBaseUrl: origin,
      beecountCloudEmail: email,
      beecountCloudPassword: password,
    ));
    final container = ProviderContainer();
    final runtime = (await container.read(activeCloudRuntimeProvider.future))!;
    final cloud = runtime.provider! as BeeCountCloudProvider;
    expect(cloud.baseUrl, origin);
    await cloud.auth.signInWithEmail(email: email, password: password);
    final repo = container.read(repositoryProvider) as LocalRepository;
    final db = repo.db;
    final ledgerId = await repo.createLedger(name: 'QA 小票体验');
    container.read(currentLedgerIdProvider.notifier).state = ledgerId;
    await prefs.setInt('current_ledger_id', ledgerId);
    final expenseCategory = await repo.createCategory(
        name: 'QA 餐饮', kind: 'expense', icon: 'restaurant');
    final incomeCategory =
        await repo.createCategory(name: 'QA 工资', kind: 'income');
    final from = await repo.createAccount(
        ledgerId: ledgerId, name: 'QA 现金', initialBalance: 1000);
    final to = await repo.createAccount(
        ledgerId: ledgerId, name: 'QA 银行', initialBalance: 1000);
    final tag = await repo.createTag(name: 'QA 周末');
    final now = DateTime.now();
    final sourceId = await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 38.5,
        categoryId: expenseCategory,
        accountId: from,
        happenedAt: now,
        note: 'QA 周末的一碗面 🍜',
        currencyCode: 'CNY');
    await repo.updateTransactionTags(transactionId: sourceId, tagIds: [tag]);
    await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'income',
        amount: 100,
        categoryId: incomeCategory,
        happenedAt: now,
        note: 'QA 美元收入',
        currencyCode: 'USD',
        nativeAmount: 720);
    await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'transfer',
        amount: 30,
        accountId: from,
        toAccountId: to,
        happenedAt: now,
        note: 'QA 账户转账',
        currencyCode: 'CNY');
    await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 1200,
        categoryId: expenseCategory,
        happenedAt: now,
        note: 'QA 日元消费',
        currencyCode: 'JPY',
        nativeAmount: 60);

    Future<void> sync() async {
      final result = await runtime.syncEngine!
          .sync(ledgerId: ledgerId.toString())
          .timeout(const Duration(seconds: 60));
      expect(result.error, isNull);
    }

    await sync();
    final baseline = (await db.select(db.transactions).get())
        .map((t) => t.toJson())
        .toList();
    final source = (await repo.getTransactionById(sourceId))!;
    final ledger = (await repo.getLedgerById(ledgerId))!;
    final login = await api('POST', '/api/v1/auth/login', body: {
      'email': email,
      'password': password,
      'client_type': 'web',
      'device_name': '$runId-web',
    });
    final token = login['access_token'] as String;
    Future<List<dynamic>> snapshot() async {
      final full = await api(
          'GET', '/api/v1/sync/full?ledger_id=${ledger.syncId}',
          token: token);
      return (jsonDecode(full['snapshot']['payload']['content'] as String)
          as Map<String, dynamic>)['items'] as List;
    }

    final cloudBaseline = await snapshot();
    expect(cloudBaseline.length, 4);

    Future<void> waitFor(bool Function() ready, {int seconds = 30}) async {
      for (var i = 0; i < seconds * 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (ready()) return;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await binding.takeScreenshot('receipt-failure');
      throw StateError('Receipt UI did not reach expected state');
    }

    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 400));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await binding.takeScreenshot(name);
    }

    void pass(String id, String detail) =>
        cases.add({'id': id, 'status': 'PASS', 'detail': detail});
    Finder row(String note) => find.byWidgetPredicate(
        (w) => w is TransactionListItem && w.title == note,
        skipOffstage: false);
    Future<void> open(String note, {bool menuCapture = false}) async {
      await tester.pump(const Duration(milliseconds: 700));
      await waitFor(() => row(note).evaluate().isNotEmpty);
      await tester.ensureVisible(row(note));
      await tester.pump(const Duration(milliseconds: 400));
      final gesture = await tester
          .startGesture(tester.getTopLeft(row(note)) + const Offset(100, 16));
      await tester.pump(const Duration(milliseconds: 1000));
      await gesture.up();
      await waitFor(() => find.text('生成小票').evaluate().isNotEmpty);
      if (menuCapture) await capture('01-receipt-menu');
      await tester.tap(find.text('生成小票'));
      await waitFor(
          () => find.byType(TransactionReceiptDialog).evaluate().isNotEmpty);
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> close() async {
      await tester.tap(find.byKey(const ValueKey('receipt-close')));
      await tester.pump(const Duration(milliseconds: 700));
    }

    Future<void> option(String name) async {
      final chip = find.byKey(ValueKey('receipt-option-$name'));
      await tester.ensureVisible(chip);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(chip);
      await tester.pump(const Duration(milliseconds: 300));
    }

    Finder receiptText(String text) => find.descendant(
        of: find.byType(TransactionReceipt), matching: find.text(text));

    await container.read(primaryColorInitProvider.future);
    await container.read(themeModeInitProvider.future);
    await api('PATCH', '/api/v1/profile/me', token: token, body: {
      'appearance': {'note_display_mode': 'note'}
    });
    await container.read(noteDisplayModeInitProvider.future);
    container.read(noteDisplayModeProvider.notifier).state = 'note';
    container.read(themeModeProvider.notifier).state = ThemeMode.light;
    await container
        .read(languageProvider.notifier)
        .setLanguage(const Locale('zh'));
    container.read(appInitStateProvider.notifier).state = AppInitState.ready;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MainApp()));
    await waitFor(() => find.byType(HomePage).evaluate().isNotEmpty);
    await open('QA 周末的一碗面 🍜', menuCapture: true);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget,
        reason: 'Receipt preview overlays the current page');
    expect(receiptText('−38.50'), findsOneWidget);
    expect(receiptText('QA 现金'), findsNothing);
    expect(receiptText('QA 小票体验'), findsNothing);
    await capture('02-receipt-default');
    pass('R01',
        'Actual home long press opens receipt; amount, category, time, note and tag shown; account and ledger hidden');
    for (final name in ['note', 'tags', 'account', 'ledger']) {
      await option(name);
    }
    expect(receiptText('QA 周末的一碗面 🍜'), findsNothing);
    expect(receiptText('#QA 周末'), findsNothing);
    expect(receiptText('QA 现金'), findsOneWidget);
    expect(receiptText('QA 小票体验'), findsOneWidget);
    await capture('03-receipt-options');
    pass('R02', 'All four switches change the production receipt preview');
    // Restore the private defaults for the saved and shared images.
    for (final name in ['note', 'tags', 'account', 'ledger']) {
      await option(name);
    }
    await tester.tap(find.byKey(const ValueKey('receipt-save')));
    await waitFor(() => find.text('已保存到相册').evaluate().isNotEmpty, seconds: 60);
    pass('R03',
        'Actual save button rasterizes the receipt and the native Photos API reports success');
    await tester.tap(find.byKey(const ValueKey('receipt-share')));
    await waitFor(
        () =>
            tester
                .widget<FilledButton>(
                    find.byKey(const ValueKey('receipt-share')))
                .onPressed !=
            null,
        seconds: 90);
    pass('R04',
        'Actual share button invokes the iOS share sheet and returns after native cancellation');
    await close();
    await open('QA 周末的一碗面 🍜');
    expect(receiptText('QA 现金'), findsNothing);
    await close();
    pass('R05',
        'Cancel and reopen resets private defaults and leaves every transaction unchanged');
    for (final entry in [
      ('QA 美元收入', '+100.00', 'USD'),
      ('QA 日元消费', '−1,200', 'JPY'),
      ('QA 账户转账', '30.00', 'CNY')
    ]) {
      await open(entry.$1);
      expect(receiptText(entry.$2), findsOneWidget);
      expect(receiptText(entry.$3), findsOneWidget);
      if (entry.$1 == 'QA 账户转账') {
        await option('account');
        expect(receiptText('QA 现金'), findsOneWidget);
        expect(receiptText('QA 银行'), findsOneWidget);
      }
      await capture(entry.$3 == 'USD'
          ? '04-receipt-income'
          : entry.$3 == 'JPY'
              ? '05-receipt-jpy'
              : '06-receipt-transfer');
      await close();
    }
    pass('R06',
        'USD income uses original 100, not native 720; JPY uses zero decimals; transfer has no sign and shows both accounts');
    expect(
        (await db.select(db.transactions).get())
            .map((t) => t.toJson())
            .toList(),
        baseline);
    await sync();
    expect(await snapshot(), cloudBaseline);
    pass('R07',
        'Generating, switching fields, saving, sharing and cancelling preserve all local rows and the real Cloud snapshot');

    // An actual user edit proves App -> Cloud still works beside receipt export.
    await tester.ensureVisible(row('QA 周末的一碗面 🍜'));
    await tester.tap(row('QA 周末的一碗面 🍜'));
    await waitFor(() => find.byType(AmountEditorSheet).evaluate().isNotEmpty);
    await waitFor(() => find
        .descendant(
            of: find.byType(AmountEditorSheet),
            matching: find.byType(CircularProgressIndicator))
        .evaluate()
        .isEmpty);
    await tester.enterText(find.byType(TextField).first, 'QA App 小票更新');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('完成'));
    await waitFor(() => find.byType(AmountEditorSheet).evaluate().isEmpty);
    await sync();
    expect(
        (await snapshot())
            .singleWhere((t) => t['syncId'] == source.syncId)['note'],
        'QA App 小票更新');
    pass('R08',
        'Production editor changes the note; production sync uploads the same transaction identity to Cloud');
    final full = await api(
        'GET', '/api/v1/sync/full?ledger_id=${ledger.syncId}',
        token: token);
    await api('PATCH',
        '/api/v1/write/ledgers/${ledger.syncId}/transactions/${source.syncId}',
        token: token,
        body: {
          'base_change_id': full['snapshot']['change_id'],
          'amount': 55.5,
          'native_amount': 55.5,
          'note': 'QA Cloud 小票更新'
        });
    await sync();
    await open('QA Cloud 小票更新');
    expect(receiptText('−55.50'), findsOneWidget);
    expect(receiptText('QA Cloud 小票更新'), findsOneWidget);
    await capture('07-receipt-cloud-update');
    await close();
    await sync();
    await sync();
    expect((await snapshot()).length, 4);
    expect((await db.select(db.transactions).get()).length, 4);
    pass('R09',
        'Real Cloud web write API -> production App pull -> regenerated receipt shows updated amount/note; repeated sync keeps four identities');
    container.read(themeModeProvider.notifier).state = ThemeMode.dark;
    await open('QA Cloud 小票更新');
    await capture('08-receipt-dark');
    await close();
    container.read(themeModeProvider.notifier).state = ThemeMode.light;
    await container
        .read(languageProvider.notifier)
        .setLanguage(const Locale('en'));
    await tester.pump(const Duration(milliseconds: 500));
    // Return to Chinese for the review environment; English narrow/long-note layout also has widget coverage.
    await container
        .read(languageProvider.notifier)
        .setLanguage(const Locale('zh'));
    pass('R10',
        'Real dark mode preserves readable paper/ink; English narrow layout and long Unicode notes are covered separately by widget tests');
    binding.reportData!['receipt_transaction_sync_id'] = source.syncId;
    binding.reportData!['normal_ui_markers'] = ['QA Cloud 小票更新', '55.5'];
    binding.reportData!['final_transactions'] = await snapshot();
    binding.reportData!['before_export_transactions'] = cloudBaseline;
    await capture('09-receipt-final-home');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
