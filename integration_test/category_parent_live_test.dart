// Run only in the verified QA bundle on a simulator owned by this run.
import 'dart:convert';

import 'package:beecount/main.dart' show MainApp;
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/pages/category/category_edit_page.dart';
import 'package:beecount/pages/category/category_manage_page.dart';
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
    'scenario': 'category-parent',
    'cases': cases
  };
  testWidgets(
      'category parent: production App UI and actual Web UI synchronization',
      (tester) async {
    expect(appId, 'com.tntlikely.beecount.qa');
    expect((await PackageInfo.fromPlatform()).packageName, appId);
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
    final engine = runtime.syncEngine!;
    final repo = container.read(repositoryProvider) as LocalRepository;
    final db = container.read(databaseProvider);
    final ledgerId = await repo.createLedger(name: 'QA 分类关联 $runId');
    container.read(currentLedgerIdProvider.notifier).state = ledgerId;
    await prefs.setInt('current_ledger_id', ledgerId);
    final parentId = await repo.createCategory(
        name: 'QA餐饮', kind: 'expense', icon: 'restaurant');
    final breakfast = await repo.createSubCategory(
        parentId: parentId, name: 'QA早餐', kind: 'expense');
    final lunch = await repo.createSubCategory(
        parentId: parentId, name: 'QA午餐', kind: 'expense');
    await repo.createCategory(
        name: 'QA购物', kind: 'expense', icon: 'shopping_bag');
    await repo.createCategory(name: 'QA餐饮', kind: 'income', icon: 'wallet');
    await repo.createCategory(name: '转账', kind: 'transfer', icon: 'swap_horiz');
    final txId = await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 32.1,
        categoryId: breakfast,
        happenedAt: DateTime.now(),
        note: 'QA 分类同步');
    final sourceTx = (await repo.getTransactionById(txId))!;
    final parent = (await repo.getCategoryById(parentId))!;
    final breakfastSyncId = (await repo.getCategoryById(breakfast))!.syncId!;
    final lunchSyncId = (await repo.getCategoryById(lunch))!.syncId!;
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
      'device_name': '$runId-web',
    });
    final token = login['access_token'] as String;
    Future<Map<String, dynamic>> snapshot() async {
      final result = await api(
          'GET', '/api/v1/sync/full?ledger_id=${ledger.syncId}',
          token: token);
      return jsonDecode(result['snapshot']['payload']['content'] as String)
          as Map<String, dynamic>;
    }

    Map<String, dynamic> category(Map<String, dynamic> s, String sid) =>
        (s['categories'] as List)
            .cast<Map<String, dynamic>>()
            .singleWhere((c) => c['syncId'] == sid);
    void pass(String id, String detail) =>
        cases.add({'id': id, 'status': 'PASS', 'detail': detail});
    Future<void> waitUi(bool Function() ready) async {
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (ready()) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await binding.takeScreenshot('failure-category-ui');
      throw StateError(
          'Production App UI did not reach the expected category state');
    }

    Future<void> tapText(String text) async {
      await waitUi(() => find.text(text).evaluate().isNotEmpty);
      final target = find.text(text).first;
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 400));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await binding.takeScreenshot(name);
    }

    Future<void> waitWeb(
        bool Function(Map<String, dynamic>) ready, String stage) async {
      debugPrint('QA_STAGE_READY_$stage');
      for (var i = 0; i < 600; i++) {
        if (ready(await snapshot())) return;
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      throw StateError('Actual QA Web UI action did not complete: $stage');
    }

    final initial = await snapshot();
    for (final sid in [breakfastSyncId, lunchSyncId]) {
      expect(category(initial, sid)['parentSyncId'], parent.syncId);
      expect(category(initial, sid)['parentName'], 'QA餐饮');
    }
    pass('C01',
        'App fixture uploaded via the real sync engine; Cloud snapshot contains the same parent/child stable IDs');
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
    await tapText('我的');
    await tapText('数据管理');
    await tapText('分类管理');
    await waitUi(() => find.byType(CategoryManagePage).evaluate().isNotEmpty);
    await tapText('QA餐饮');
    await waitUi(() =>
        find.text('QA早餐').evaluate().isNotEmpty &&
        find.text('QA午餐').evaluate().isNotEmpty);
    await capture('01-app-original-children');
    await tapText('编辑');
    await waitUi(() => find.byType(CategoryEditPage).evaluate().isNotEmpty);
    final nameField = find
        .descendant(
            of: find.byType(CategoryEditPage), matching: find.byType(TextField))
        .first;
    await tester.enterText(nameField, 'QA App伙食');
    await tapText('保存');
    await waitUi(() => find.byType(CategoryEditPage).evaluate().isEmpty);
    await sync();
    var appRenamed = await snapshot();
    for (var i = 0; i < 60; i++) {
      if (category(appRenamed, parent.syncId!)['name'] == 'QA App伙食' &&
          [breakfastSyncId, lunchSyncId].every(
              (sid) => category(appRenamed, sid)['parentName'] == 'QA App伙食')) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(seconds: 1));
      appRenamed = await snapshot();
    }
    expect(category(appRenamed, parent.syncId!)['name'], 'QA App伙食');
    for (final sid in [breakfastSyncId, lunchSyncId]) {
      expect(category(appRenamed, sid)['parentSyncId'], parent.syncId);
      expect(category(appRenamed, sid)['parentName'], 'QA App伙食');
    }
    expect((appRenamed['categories'] as List).length,
        (initial['categories'] as List).length);
    pass('C02',
        'Actual App category-management UI renamed the parent; real Cloud snapshot kept both children and the same stable parent ID');
    await tapText('QA App伙食');
    await waitUi(() =>
        find.text('QA早餐').evaluate().isNotEmpty &&
        find.text('QA午餐').evaluate().isNotEmpty);
    await capture('02-app-renamed-children');
    Navigator.of(tester.element(find.byType(Dialog).first)).pop();
    await tester.pump(const Duration(milliseconds: 500));

    await waitWeb((s) => category(s, parent.syncId!)['name'] == 'QA Web伙食',
        'WEB_PARENT_RENAME');
    await sync();
    expect((await repo.getCategoryById(parentId))!.name, 'QA Web伙食');
    for (final id in [breakfast, lunch]) {
      expect((await repo.getCategoryById(id))!.parentId, parentId);
    }
    await tapText('QA Web伙食');
    await waitUi(() =>
        find.text('QA早餐').evaluate().isNotEmpty &&
        find.text('QA午餐').evaluate().isNotEmpty);
    await capture('03-app-after-web-rename');
    pass('C03',
        'Actual Web parent rename was pulled by the real App sync engine; both children remain visible under the renamed parent');
    Navigator.of(tester.element(find.byType(Dialog).first)).pop();
    await tester.pump(const Duration(milliseconds: 500));

    await waitWeb((s) => category(s, breakfastSyncId)['name'] == 'QA早饭',
        'WEB_CHILD_EDIT');
    await sync();
    final edited = (await repo.getCategoryById(breakfast))!;
    expect(edited.name, 'QA早饭');
    expect(edited.parentId, parentId);
    final finalSnapshot = await snapshot();
    expect(category(finalSnapshot, breakfastSyncId)['parentSyncId'],
        parent.syncId);
    expect(category(finalSnapshot, breakfastSyncId)['parentName'], 'QA Web伙食');
    pass('C04',
        'Actual Web child edit preserved its stable parent link and synchronized back to App');
    final base =
        await api('GET', '/api/v1/read/ledgers/${ledger.syncId}', token: token);
    final rejected = await request('DELETE',
        '/api/v1/write/ledgers/${ledger.syncId}/categories/${parent.syncId}',
        token: token, body: {'base_change_id': base['source_change_id']});
    expect(rejected.statusCode, 400);
    expect(rejected.body, contains('child'));
    pass('C05',
        'Direct authenticated Cloud delete is rejected after both App and Web renames; the parent and children remain stored');
    final transactions =
        (finalSnapshot['items'] as List).cast<Map<String, dynamic>>();
    expect(transactions.length, 1);
    expect(transactions.single['syncId'], sourceTx.syncId);
    expect(transactions.single['amount'], 32.1);
    expect((await repo.getTransactionById(txId))!.categoryId, breakfast);
    pass('C06',
        'Existing transaction identity, amount, count and child-category association were preserved');
    await tapText('QA Web伙食');
    await waitUi(() => find.text('QA早饭').evaluate().isNotEmpty);
    await capture('04-app-after-web-child-edit');
    Navigator.of(tester.element(find.byType(Dialog).first))
        .popUntil((route) => route.isFirst);
    await tester.pump(const Duration(milliseconds: 700));
    await tapText('明细');
    await capture('05-app-home-final');
    binding.reportData!.addAll({
      'parent_sync_id': parent.syncId,
      'parent_name': 'QA Web伙食',
      'child_sync_ids': [breakfastSyncId, lunchSyncId],
      'ledger_sync_id': ledger.syncId,
      'normal_ui_markers': ['QA 分类同步', '32.1'],
      'initial_snapshot': initial,
      'final_snapshot': finalSnapshot,
    });
    await prefs.setString('qa_run_id', runId);
    expect((await db.select(db.categories).get()).length,
        (initial['categories'] as List).length);
  }, timeout: const Timeout(Duration(minutes: 25)));
}
