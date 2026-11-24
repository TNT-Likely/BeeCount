import 'package:beecount/data/repositories/local/local_repository.dart';
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
  testWidgets(
      'Cloud rules are edited on both clients and executed once by Cloud',
      (tester) async {
    final package = await PackageInfo.fromPlatform();
    expect(package.packageName, 'com.tntlikely.beecount.qa');
    await registerQa(email);
    await HomeWidget.setAppGroupId('group.com.tntlikely.beecount.qa');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', 'zh');
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
    final result = await recurringCloudRoundTrip(
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

    await waitFor(find.byType(HomePage));
    final navigator = Navigator.of(tester.element(find.byType(HomePage)),
        rootNavigator: true);
    navigator.push(MaterialPageRoute<void>(
        builder: (_) => const RecurringTransactionPage()));
    await waitFor(find.byType(CloudRecurringPage));
    await waitFor(find.text('QA 云端合账'));
    await binding.takeScreenshot('01-app-cloud-rules');
    navigator.pop();
    await waitFor(find.byType(HomePage));
    await binding.takeScreenshot('02-app-cloud-transaction');
    binding.reportData = {
      ...result,
      'run_id': runId,
      'scenario': 'recurring-cloud'
    };
    await prefs.setString('qa_run_id', runId);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
