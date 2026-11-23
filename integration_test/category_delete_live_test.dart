// Run only in the verified QA bundle on a simulator owned by this run.
import 'dart:convert';

import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/main.dart' show MainApp;
import 'package:beecount/pages/category/category_edit_page.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/language_provider.dart';
import 'package:beecount/providers/sync_providers.dart';
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount/providers/ui_state_providers.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'category_parent_live_test.dart'
    show api, appId, email, origin, password, runId;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  final cases = <Map<String, dynamic>>[];
  binding.reportData = {
    'run_id': runId,
    'scenario': 'category-delete',
    'cases': cases
  };

  testWidgets('category deletion: App UI, legacy orphan and Cloud cleanup',
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
    final repo = container.read(repositoryProvider);
    final ledgerId = await repo.createLedger(name: 'QA 分类删除');
    container.read(currentLedgerIdProvider.notifier).state = ledgerId;
    await prefs.setInt('current_ledger_id', ledgerId);
    await prefs.setString('qa_run_id', runId);
    final ledgerSyncId = (await repo.getLedgerById(ledgerId))!.syncId!;
    final keepId = await repo.createCategory(name: 'QA保留分类', kind: 'expense');
    await repo.createCategory(name: '转账', kind: 'transfer', icon: 'swap_horiz');
    final txId = await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 32.1,
        categoryId: keepId,
        happenedAt: DateTime.now(),
        note: 'QA 分类删除保留交易');
    for (var i = (await repo.getAllCategories()).length; i < 53; i++) {
      await repo.createCategory(
          name: 'QA基准$i', kind: 'expense', sortOrder: i + 10);
    }

    Future<({int id, String parent, String child})> categories(
        String parent, String child) async {
      final parentId = await repo.createCategory(
          name: parent, kind: 'expense', sortOrder: -1);
      final childId = await repo.createSubCategory(
          parentId: parentId, name: child, kind: 'expense');
      return (
        id: parentId,
        parent: (await repo.getCategoryById(parentId))!.syncId!,
        child: (await repo.getCategoryById(childId))!.syncId!
      );
    }

    Future<void> sync() async {
      final result = await engine
          .sync(ledgerId: '$ledgerId')
          .timeout(const Duration(seconds: 60));
      expect(result.error, isNull);
    }

    final fixed = await categories('QA待删父分类', 'QA待删子分类');
    await sync();
    final secondDevice = await api('POST', '/api/v1/auth/login', body: {
      'email': email,
      'password': password,
      'client_type': 'app',
      'device_name': '$runId-legacy',
    });
    final token = secondDevice['access_token'] as String;
    final deviceId = secondDevice['device_id'] as String;
    Future<List<dynamic>> changesSince(int cursor,
        {bool filterDevice = false}) async {
      final suffix = filterDevice ? '&device_id=$deviceId' : '';
      final result = await api('GET', '/api/v1/sync/pull?since=$cursor$suffix',
          token: token);
      return result['changes'] as List<dynamic>;
    }

    Future<Set<String>> remoteCategories() async {
      final response = await api(
          'GET', '/api/v1/sync/full?ledger_id=$ledgerSyncId',
          token: token);
      final snapshot =
          jsonDecode(response['snapshot']['payload']['content'] as String);
      return (snapshot['categories'] as List)
          .map((c) => c['syncId'] as String)
          .toSet();
    }

    Future<void> count(int local, int remote) async {
      final health = await engine.checkSyncHealth(ledgerId: ledgerId);
      expect(health.categories.local, local);
      expect(health.categories.remote, remote);
    }

    Future<void> waitFor(Finder finder) async {
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (finder.evaluate().isNotEmpty) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await binding.takeScreenshot('failure-category-delete-ui');
      fail('Production UI did not show $finder');
    }

    Future<void> tap(Finder finder) async {
      await waitFor(finder);
      await tester.ensureVisible(finder.first);
      await tester.tap(finder.first);
      await tester.pump(const Duration(milliseconds: 500));
    }

    void pass(String id, String detail) =>
        cases.add({'id': id, 'status': 'PASS', 'detail': detail});

    await count(55, 55);
    final beforeDelete = (await changesSince(0)).last['change_id'] as int;
    await container.read(primaryColorInitProvider.future);
    await container.read(themeModeInitProvider.future);
    container.read(themeModeProvider.notifier).state = ThemeMode.light;
    await container
        .read(languageProvider.notifier)
        .setLanguage(const Locale('zh'));
    container.read(appInitStateProvider.notifier).state = AppInitState.ready;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MainApp()));
    for (final text in ['我的', '数据管理', '分类管理', 'QA待删父分类']) {
      await tap(find.text(text));
    }
    await waitFor(find.text('QA待删子分类'));
    await tap(find.descendant(
        of: find.byKey(ValueKey('${fixed.id}')),
        matching: find.byType(IconButton)));
    await tap(find.text('删除分类'));
    await waitFor(find.widgetWithText(BeeButton, '删除'));
    await binding.takeScreenshot('01-app-confirm-parent-delete');
    await tap(find.widgetWithText(BeeButton, '删除'));
    expect(find.byType(CategoryEditPage), findsNothing);
    await sync();
    await count(53, 53);
    expect((await remoteCategories()).intersection({fixed.parent, fixed.child}),
        isEmpty);
    final deleted = (await changesSince(beforeDelete, filterDevice: true))
        .where((c) => c['entity_type'] == 'category' && c['action'] == 'delete')
        .map((c) => c['entity_sync_id']);
    expect(deleted, unorderedEquals([fixed.parent, fixed.child]));
    pass('D01', '生产 App 编辑页确认删除父分类后，Cloud 收到父、子两个删除事件，计数由 55/55 降为 53/53。');

    final legacy = await categories('QA旧版父分类', 'QA旧版孤儿子分类');
    await sync();
    await count(55, 55);
    final oldPush = await api('POST', '/api/v1/sync/push', token: token, body: {
      'device_id': deviceId,
      'changes': [
        {
          'scope': 'user',
          'action': 'delete',
          'entity_type': 'category',
          'entity_sync_id': legacy.parent,
          'payload': <String, dynamic>{},
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }
      ],
    });
    expect(oldPush['accepted'], 1);
    await sync();
    await count(53, 54);
    expect(await remoteCategories(), contains(legacy.child));
    pass('D02', '旧版协议只推父分类删除事件后，真实 App 与 Cloud 复现 53/54，云端多出 QA旧版孤儿子分类。');

    debugPrint('QA_STAGE_READY_CLOUD_CATEGORY_CLEANUP');
    for (var i = 0; i < 120; i++) {
      if (!(await remoteCategories()).contains(legacy.child)) break;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    final cleanupChanges =
        await changesSince(oldPush['server_cursor'] as int, filterDevice: true);
    expect(
        cleanupChanges.where((c) =>
            c['entity_type'] == 'category' &&
            c['entity_sync_id'] == legacy.child &&
            c['action'] == 'delete'),
        hasLength(1));
    await sync();
    await count(53, 53);
    expect((await repo.getTransactionById(txId))!.categoryId, keepId);
    pass('D03', '管理员通过真实 Cloud 清理接口移除残留子分类，生成可拉取删除事件，计数恢复 53/53，保留交易不变。');

    final NavigatorState navigator = tester.state(find.byType(Navigator).first);
    navigator.popUntil((route) => route.isFirst);
    await tester.pump(const Duration(milliseconds: 700));
    await tap(find.text('明细'));
    await binding.takeScreenshot('02-app-after-category-cleanup');
    binding.reportData!.addAll({
      'ledger_sync_id': ledgerSyncId,
      'deleted_category_sync_ids': [
        fixed.parent,
        fixed.child,
        legacy.parent,
        legacy.child
      ],
      'normal_ui_markers': ['QA保留分类', '32.1'],
    });
  }, timeout: const Timeout(Duration(minutes: 8)));
}
