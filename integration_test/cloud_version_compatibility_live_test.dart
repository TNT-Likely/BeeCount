// Run only in the verified QA bundle on a simulator owned by this run.
import 'package:beecount/cloud/cloud_version_policy.dart';
import 'package:beecount/main.dart' show MainApp;
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/language_provider.dart';
import 'package:beecount/providers/sync_providers.dart';
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount/providers/ui_state_providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
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
    'scenario': 'cloud-version-compatibility',
    'cases': cases,
  };

  testWidgets('App & Cloud version compatibility: matched, recommend, require, 426, recover',
      (tester) async {
    void pass(String id, String summary) =>
        cases.add({'id': id, 'status': 'PASS', 'summary': summary});

    Future<void> waitFor(Finder finder,
        {Duration timeout = const Duration(seconds: 25)}) async {
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
        if (finder.evaluate().isNotEmpty) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await binding.takeScreenshot('failure-version-compat-ui');
      expect(finder, findsWidgets);
    }

    Future<void> tap(Finder finder) async {
      await waitFor(finder);
      await tester.ensureVisible(finder.first);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(finder.first);
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> setServerPolicy({
      required String version,
      required String minApp,
      required String recApp,
    }) async {
      final res = await api('POST', '/__qa__/version-policy', body: {
        'run_id': runId,
        'version': version,
        'min_app_version': minApp,
        'recommended_app_version': recApp,
      });
      expect(res['version'], version);
      expect(res['min_app_version'], minApp);
      expect(res['recommended_app_version'], recApp);
    }

    expect(appId, 'com.tntlikely.beecount.qa');
    final pkg = await PackageInfo.fromPlatform();
    expect(pkg.packageName, appId);
    expect(pkg.version, '4.1.0');
    expect(runId.startsWith('beecount-qa-'), isTrue);

    final identity = await api('GET', '/__qa__/identity');
    expect(identity['run_id'], runId);
    expect(identity['database_is_isolated'], isTrue);

    await api('POST', '/api/v1/auth/register', body: {
      'email': email,
      'password': password,
      'client_type': 'app',
      'platform': 'ios',
      'device_name': runId,
      'app_version': '4.0.1',
    });

    await HomeWidget.setAppGroupId('group.com.tntlikely.beecount.qa');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', 'zh');
    await prefs.setBool('welcome_shown', true);
    await prefs.setString('noteDisplayMode', 'note');
    await prefs.setBool('budget_setup_hint_dismissed', true);

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
    final beeAuth = cloud.auth as BeeCountCloudAuthService;
    expect(cloud.baseUrl, origin);
    await beeAuth.signInWithEmail(email: email, password: password);
    final engine = runtime.syncEngine!;
    final repo = container.read(repositoryProvider);

    final ledgerId = await repo.createLedger(name: 'QA 版本匹配');
    container.read(currentLedgerIdProvider.notifier).state = ledgerId;
    await prefs.setInt('current_ledger_id', ledgerId);
    await prefs.setString('qa_run_id', runId);
    final ledgerSyncId = (await repo.getLedgerById(ledgerId))!.syncId!;
    final catId = await repo.createCategory(name: 'QA版本餐饮', kind: 'expense');

    final tx1Id = await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 42.5,
      categoryId: catId,
      happenedAt: DateTime.now(),
      note: 'QA 版本匹配基准',
    );
    final tx1SyncId = (await repo.getTransactionById(tx1Id))!.syncId!;

    Future<Set<String>> remoteTxIds() async {
      final token = await beeAuth.requireAccessToken();
      final list = await api(
        'GET',
        '/api/v1/read/ledgers/$ledgerSyncId/transactions',
        token: token,
      ) as List;
      return list.map((e) => (e as Map)['id'] as String).toSet();
    }

    // 启动生产 UI（挂载 SyncService 的 versionGuard 与 onUpgradeRequired）
    await container.read(primaryColorInitProvider.future);
    await container.read(themeModeInitProvider.future);
    container.read(themeModeProvider.notifier).state = ThemeMode.light;
    await container
        .read(languageProvider.notifier)
        .setLanguage(const Locale('zh'));
    container.read(syncServiceProvider);
    container.read(appInitStateProvider.notifier).state = AppInitState.ready;
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MainApp()),
    );
    await waitFor(find.text('QA版本餐饮'));

    // 1. 匹配状态（App 4.1.0 + Cloud 1.11.0）
    final initialSync = await engine
        .sync(ledgerId: '$ledgerId')
        .timeout(const Duration(seconds: 60));
    expect(initialSync.error, isNull);
    expect(await remoteTxIds(), contains(tx1SyncId));

    // 验证 X-BeeCount-App-Version 请求头已刷新服务端 Device.app_version
    final token = await beeAuth.requireAccessToken();
    final devices = await api('GET', '/api/v1/devices', token: token) as List;
    final currentDevice = devices.cast<Map<String, dynamic>>().firstWhere(
          (d) => d['id'] == beeAuth.currentDeviceId,
        );
    expect((currentDevice['app_version'] as String?)?.startsWith('4.1.0'), isTrue);

    await tap(find.text('我的'));
    await waitFor(find.text('BeeCount Cloud v1.11.0'));
    await tap(find.byType(BeeSyncStatus));
    await waitFor(find.textContaining('App v4.1.0 · Cloud v1.11.0', skipOffstage: false));
    expect(find.text('建议升级 BeeCount Cloud'), findsNothing);
    expect(find.text('请先升级 BeeCount Cloud'), findsNothing);
    await binding.takeScreenshot('01-matched-sync-page');
    pass('V01', 'App 4.1.0 与 Cloud 1.11.0 匹配时无升级打扰，云同步页显示已匹配，且 X-BeeCount-App-Version 刷新了服务端设备版本。');

    // 2. Cloud 低于推荐版本（1.10.1）：温和提示 + 首页一次性提醒 + 放行同步
    await setServerPolicy(version: '1.10.1', minApp: '4.0.0', recApp: '4.0.0');
    await container.refresh(beecountCloudServerInfoProvider.future);
    await container.refresh(cloudVersionCompatibilityProvider.future);
    await waitFor(find.text('建议升级 BeeCount Cloud'));
    await binding.takeScreenshot('02-cloud-recommended-sync-page');

    final tx2Id = await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 19.8,
      categoryId: catId,
      happenedAt: DateTime.now(),
      note: 'QA 建议档放行',
    );
    final tx2SyncId = (await repo.getTransactionById(tx2Id))!.syncId!;
    final recSync = await engine
        .sync(ledgerId: '$ledgerId')
        .timeout(const Duration(seconds: 60));
    expect(recSync.error, isNull);
    expect(await remoteTxIds(), contains(tx2SyncId));

    // 返回首页验证一次性提醒卡片与关闭记忆
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.popUntil((route) => route.isFirst);
    await tap(find.text('明细'));
    await waitFor(find.text('建议升级 BeeCount Cloud'));
    await binding.takeScreenshot('03-home-one-time-banner');
    await tap(find.text('知道了'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('建议升级 BeeCount Cloud'), findsNothing);
    pass('V02', 'Cloud 1.10.1 触发建议升级提示，首页一次性卡片点击「知道了」后持久化关闭，同步保持放行（19.80 正常上云）。');

    // 3. Cloud 低于最低版本（1.9.0）：强提示 + 暂停云同步 + 本地记账正常
    await setServerPolicy(version: '1.9.0', minApp: '4.0.0', recApp: '4.0.0');
    await tap(find.text('我的'));
    await container.refresh(beecountCloudServerInfoProvider.future);
    await container.refresh(cloudVersionCompatibilityProvider.future);
    await waitFor(find.textContaining('同步已暂停'));
    await tap(find.byType(BeeSyncStatus));
    await waitFor(find.text('请先升级 BeeCount Cloud'));
    await binding.takeScreenshot('04-cloud-required-paused');

    final tx3Id = await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 31.0,
      categoryId: catId,
      happenedAt: DateTime.now(),
      note: 'QA 离线记账不受影响',
    );
    final tx3SyncId = (await repo.getTransactionById(tx3Id))!.syncId!;
    final blockedSync = await engine
        .sync(ledgerId: '$ledgerId')
        .timeout(const Duration(seconds: 30));
    expect(blockedSync.error, 'sync_paused_version_mismatch');
    expect(await remoteTxIds(), isNot(contains(tx3SyncId)));
    expect((await repo.getTransactionById(tx3Id))?.amount, 31.0);
    pass('V03', 'Cloud 1.9.0 低于最低要求时暂停云同步并展示强提示，本地新建 31.00 仍正常写入本地库且未误推云端。');

    // 4. 服务端要求更新 App（HTTP 426：Cloud 1.12.0, min_app=9.0.0）
    await setServerPolicy(version: '1.12.0', minApp: '9.0.0', recApp: '9.1.0');
    Object? caught426;
    try {
      await cloud.pushChanges(changes: [
        {
          'ledger_id': ledgerSyncId,
          'entity_type': 'transaction',
          'entity_sync_id': tx3SyncId,
          'action': 'upsert',
          'payload': <String, dynamic>{},
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }
      ]);
    } catch (e) {
      caught426 = e;
    }
    expect(caught426, isA<BeeCountCloudUpgradeRequiredException>());
    container.read(cloudVersionRuntimeBlockProvider.notifier).state =
        CloudVersionCompatibility.fromUpgradeRequired(
      caught426 as BeeCountCloudUpgradeRequiredException,
      fallbackAppVersion: '4.1.0',
    );
    await waitFor(find.text('请先更新 BeeCount App'));
    await binding.takeScreenshot('05-app-required-426');
    pass('V04', '服务端提高 min_app_version 后，真实 /sync/push 返回 HTTP 426，App 解析结构化错误并切换为「请先更新 BeeCount App」。');

    // 5. 服务端升级回 1.11.0，用户点「重新检测」即时恢复并自动补传离线交易
    await setServerPolicy(version: '1.11.0', minApp: '4.0.0', recApp: '4.1.0');
    await tap(find.text('重新检测'));
    await waitFor(find.textContaining('App v4.1.0 · Cloud v1.11.0', skipOffstage: false));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('请先更新 BeeCount App'), findsNothing);
    expect(find.text('请先升级 BeeCount Cloud'), findsNothing);

    final recovered = await engine
        .sync(ledgerId: '$ledgerId')
        .timeout(const Duration(seconds: 60));
    expect(recovered.error, isNull);
    final finalRemote = await remoteTxIds();
    expect(finalRemote, containsAll([tx1SyncId, tx2SyncId, tx3SyncId]));
    await binding.takeScreenshot('06-recovered-matched');
    pass('V05', 'Cloud 升级至 1.11.0 后点击「重新检测」立即消除阻断，恢复同步并补传离线期间记下的 31.00，两端 3 笔账单完全一致。');

    // 回到明细页准备正常入口重启验证
    nav.popUntil((route) => route.isFirst);
    await tap(find.text('明细'));
    await waitFor(find.text('QA版本餐饮'));

    binding.reportData!.addAll({
      'ledger_sync_id': ledgerSyncId,
      'expected_tx_sync_ids': [tx1SyncId, tx2SyncId, tx3SyncId],
      'normal_ui_markers': ['QA版本餐饮', '31'],
    });
  }, timeout: const Timeout(Duration(minutes: 8)));
}
