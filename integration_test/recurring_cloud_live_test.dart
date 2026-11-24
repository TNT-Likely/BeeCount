import 'dart:convert';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/pages/transaction/recurring/cloud_rule_editor.dart';
import 'package:beecount_business_ui/recurring_editor.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart'
    show BeeRecurringBillCard;
import 'package:beecount_ui/beecount_ui.dart' show BeeDialog;
import 'package:beecount/main.dart' show MainApp;
import 'package:beecount/pages/main/home_page.dart';
import 'package:beecount/pages/transaction/recurring/cloud_recurring_page.dart';
import 'package:beecount/pages/transaction/recurring_transaction_page.dart';
import 'package:beecount/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/recurring_cloud_case.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  binding.reportData = {};
  testWidgets(
      'Cloud rules are edited on both clients and executed once by Cloud',
      (tester) async {
    final package = await PackageInfo.fromPlatform();
    expect(package.packageName, 'com.tntlikely.beecount.qa');
    const resume = String.fromEnvironment('QA_RECURRING_RESULT');
    if (resume.isEmpty) {
      await registerQa(email);
    } else {
      expect((await qaRequest('GET', '/__qa__/identity'))['run_id'], runId);
    }

    await HomeWidget.setAppGroupId('group.com.tntlikely.beecount.qa');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', 'zh');
    await prefs.setString('noteDisplayMode', 'note');
    await prefs.setBool('welcome_shown', true);
    await CloudServiceStore().saveAndActivate(const CloudServiceConfig(
        type: CloudBackendType.beecountCloud,
        name: 'QA Cloud',
        beecountCloudBaseUrl: origin,
        beecountCloudEmail: email,
        beecountCloudPassword: password));
    final container = ProviderContainer();
    final runtime = (await container.read(activeCloudRuntimeProvider.future))!;
    final cloud = runtime.provider as BeeCountCloudProvider;
    await cloud.auth.signInWithEmail(email: email, password: password);
    final result = resume.isNotEmpty
        ? jsonDecode(resume) as Map<String, dynamic>
        : await recurringCloudRoundTrip(
            cloud: cloud,
            engine: runtime.syncEngine!,
            repo: container.read(repositoryProvider) as LocalRepository,
            db: container.read(databaseProvider),
            address: email);
    await prefs.setInt('current_ledger_id', result['ledger_id'] as int);
    container.read(currentLedgerIdProvider.notifier).state =
        result['ledger_id'] as int;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MainApp()));
    Future<void> waitFor(Finder item) async {
      for (var n = 0; n < 120; n++) {
        await tester.pump(const Duration(milliseconds: 150));
        if (item.evaluate().isNotEmpty) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      fail('Production UI did not show $item');
    }

    Future<void> capture(String label) async {
      await tester.pump(const Duration(milliseconds: 350));
      await Future<void>.delayed(const Duration(milliseconds: 450));
      await tester.pump();
      await binding.takeScreenshot(label);
    }

    await waitFor(find.byType(HomePage));
    final navigator = Navigator.of(tester.element(find.byType(HomePage)),
        rootNavigator: true);
    navigator.push(MaterialPageRoute<void>(
        builder: (_) => const RecurringTransactionPage()));
    await waitFor(find.byType(CloudRecurringPage));
    final billName = find.descendant(
        of: find.byType(BeeRecurringBillCard), matching: find.text('QA 云端合账'));
    await waitFor(billName);
    await capture('01-app-cloud-rules');
    final l = AppLocalizationsZh();
    await tester.tap(billName);
    await waitFor(find.byType(CloudRuleEditor));
    final form = tester
        .widget<BeeRecurringEditorForm>(find.byType(BeeRecurringEditorForm));
    final amount = find.byWidgetPredicate(
        (w) => w is TextField && w.controller == form.amountController);
    await tester.enterText(amount, '47');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 250));
    await capture('02-app-rule-editor');
    await tester.tap(find.text(l.commonSave).last);
    final dialog = find.byType(BeeDialog);
    await waitFor(dialog);
    await tester.pump(const Duration(milliseconds: 300));
    await tester
        .tap(find.descendant(of: dialog, matching: find.text(l.commonSave)));
    for (var i = 0;
        i < 100 && find.byType(CloudRuleEditor).evaluate().isNotEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    expect(find.byType(CloudRuleEditor), findsNothing);
    await waitFor(billName);
    final login = await qaRequest('POST', '/api/v1/auth/login', data: {
      'email': email,
      'password': password,
      'client_type': 'web',
      'device_name': 'QA Web readback'
    });
    final web = await qaRequest(
        'GET', '/api/v1/ledgers/${result['ledger_sync_id']}/recurring-rules',
        token: login['access_token'] as String);
    final edited =
        (web['items'] as List).singleWhere((r) => r['id'] == result['rule_id']);
    expect(edited['data']['rule']['transaction']['amount'], 47);
    expect(edited['status'], 'paused');
    final local = await container
        .read(databaseProvider)
        .select(container.read(databaseProvider).transactions)
        .get();
    expect(local.where((tx) => tx.syncId == result['tx_sync_id']).single.amount,
        43);
    (result['cases'] as List).removeWhere((c) => c['id'] == 'native-edit');
    (result['cases'] as List).add({
      'id': 'native-edit',
      'status': 'PASS',
      'detail': 'App 表单将未来金额保存为 47，Web 登录读到 47，已入账流水仍为 43。'
    });

    navigator.pop();
    await waitFor(find.byType(HomePage));
    await capture('03-app-cloud-transaction');
    binding.reportData!
        .addAll({...result, 'run_id': runId, 'scenario': 'recurring-cloud'});
    await prefs.setString('qa_run_id', runId);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
