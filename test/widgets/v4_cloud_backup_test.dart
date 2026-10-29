import 'dart:async';
import 'dart:convert';
import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/cloud/transactions_sync_manager.dart';
import 'package:beecount/cloud/transactions_json.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/pages/cloud/cloud_sync_page.dart';
import 'package:beecount/pages/auth/login_page.dart';
import 'package:beecount/pages/cloud/backup/bindings/cloud_backup_controls.dart';
import 'package:beecount/dev/component_gallery/bindings/cloud_backup_preview.dart';
import 'package:beecount/dev/component_gallery/cloud_backup_sample.dart';
import 'package:beecount/providers.dart';
import 'package:beecount_business_ui/cloud_backup.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' as cloud;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends cloud.NoopAuthService {
  final events = StreamController<cloud.CloudUser?>.broadcast();
  @override
  Stream<cloud.CloudUser?> get authStateChanges => events.stream;
  cloud.CloudUser? user =
      const cloud.CloudUser(id: 'qa-user', email: 'qa@example.invalid');
  int reads = 0, logins = 0, signouts = 0;
  Object? error;
  @override
  Future<cloud.CloudUser?> get currentUser async {
    reads++;
    return user;
  }

  @override
  Future<cloud.CloudUser> signInWithEmail(
      {required String email, required String password}) async {
    logins++;
    if (error != null) throw error!;
    return user = cloud.CloudUser(id: 'qa-user', email: email);
  }

  @override
  Future<void> signOut() async {
    signouts++;
    user = null;
  }
}

class _Sync extends LocalOnlySyncService {
  SyncStatus status = const SyncStatus(
      diff: SyncDiff.localNewer,
      localCount: 2,
      localFingerprint: 'local-qa',
      cloudCount: 1,
      cloudFingerprint: 'remote-qa');
  int statusCalls = 0, uploads = 0, downloads = 0, clears = 0;
  Object? statusError, uploadError, downloadError;
  Completer<void>? gate;
  @override
  Future<SyncStatus> getStatus({required int ledgerId}) async {
    statusCalls++;
    if (statusError != null) throw statusError!;
    return status;
  }

  @override
  void clearStatusCache({int? ledgerId}) {
    clears++;
  }

  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) async {
    uploads++;
    if (gate != null) await gate!.future;
    if (uploadError != null) throw uploadError!;
    status = const SyncStatus(
        diff: SyncDiff.inSync, localCount: 2, localFingerprint: 'qa');
  }

  @override
  Future<({int inserted, int deletedDup})> downloadAndRestoreToCurrentLedger(
      {required int ledgerId}) async {
    downloads++;
    if (downloadError != null) throw downloadError!;
    return (inserted: 2, deletedDup: 0);
  }

  @override
  Future<({String? fingerprint, int? count, DateTime? exportedAt})>
      refreshCloudFingerprint({required int ledgerId}) async =>
          (fingerprint: 'qa', count: 2, exportedAt: null);
}

class _BeeProvider extends cloud.BeeCountCloudProvider {
  _BeeProvider(this.service);
  final _Auth service;
  @override
  cloud.CloudAuthService get auth => service;
}

/// A synthetic transport backed by MockClient, with the production manager and
/// SQLite repository above it. No socket, real server or private configuration.
class _Storage extends cloud.NoopStorageService {
  _Storage() {
    client = MockClient((request) async {
      requests.add(request);
      final key = request.url.pathSegments.last;
      if (fail) return http.Response('QA transport failed', 503);
      if (request.method == 'PUT') {
        files[key] = request.body;
        return http.Response('', 200);
      }
      if (request.method == 'DELETE') {
        files.remove(key);
        return http.Response('', 204);
      }
      return files.containsKey(key)
          ? http.Response(files[key]!, 200)
          : http.Response('', 404);
    });
  }
  late final http.Client client;
  final files = <String, String>{};
  final requests = <http.Request>[];
  bool fail = false;
  @override
  Future<void> upload(
      {required String path,
      required String data,
      Map<String, String>? metadata}) async {
    final r =
        await client.put(Uri.parse('https://qa.invalid/$path'), body: data);
    if (r.statusCode != 200) throw StateError('QA upload 503');
  }

  @override
  Future<String?> download({required String path}) async {
    final r = await client.get(Uri.parse('https://qa.invalid/$path'));
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) throw StateError('QA download 503');
    return r.body;
  }

  @override
  Future<void> delete({required String path}) async {
    await client.delete(Uri.parse('https://qa.invalid/$path'));
  }

  @override
  Future<bool> exists({required String path}) async => files.containsKey(path);
  @override
  Future<cloud.CloudFile?> getMetadata({required String path}) async =>
      files.containsKey(path) ? cloud.CloudFile(name: path, path: path) : null;
}

class _Provider implements cloud.CloudProvider {
  _Provider(this.auth, this.storage);
  @override
  final _Auth auth;
  @override
  final _Storage storage;
  @override
  String get providerId => 'qa-transport';
  @override
  String get providerName => 'QA transport';
  @override
  Future<void> initialize(Map<String, dynamic> config) async {}
  @override
  bool validateConfig(Map<String, dynamic> config) => true;
  @override
  Future<void> dispose() async => storage.client.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = AppLocalizationsEn();
  late BeeDatabase db;
  late LocalRepository repo;
  late _Auth auth;
  late _Sync sync;
  late _Storage storage;
  late cloud.CloudServiceConfig config;
  int ledger = 1;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    auth = _Auth();
    sync = _Sync();
    storage = _Storage();
    ledger = 1;
    config = const cloud.CloudServiceConfig(
        type: cloud.CloudBackendType.webdav,
        name: 'QA DAV',
        webdavUrl: 'https://qa.invalid',
        webdavUsername: 'qa',
        webdavPassword: 'synthetic');
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'QA backup','CNY')");
    await db.customStatement(
        "INSERT INTO transactions(id,ledger_id,type,amount,happened_at,note,sync_id) VALUES(1,1,'expense',10,1792454400,'QA original','qa-one'),(2,1,'income',100,1792454400,'QA keep','qa-two')");
  });
  tearDown(() async {
    await auth.events.close();
    storage.client.close();
    await db.close();
  });
  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (t) async {
      try {
        await body(t);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
        await t.pumpAndSettle();
        await t.pump(const Duration(seconds: 6));
      }
    });
  }

  Widget host(Widget page,
          {SyncService? service,
          SyncStatus? presentation,
          Brightness brightness = Brightness.light,
          double scale = 1}) =>
      ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            databaseProvider.overrideWithValue(db),
            currentLedgerIdProvider.overrideWith((ref) => ledger),
            activeCloudConfigProvider.overrideWith((ref) async => config),
            authServiceProvider.overrideWith((ref) async => auth),
            syncServiceProvider.overrideWithValue(service ?? sync),
            beecountCloudProviderInstance
                .overrideWith((ref) async => _BeeProvider(auth)),
            if (presentation != null)
              syncStatusProvider.overrideWith((ref, id) async => presentation),
          ],
          child: MaterialApp(
              theme: beeTheme(brightness: brightness),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: page));
  Future<void> flush(WidgetTester t, {int cycles = 8}) async {
    for (var i = 0; i < cycles; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> show(WidgetTester t,
      {SyncService? service, SyncStatus? presentation}) async {
    await t.pumpWidget(host(const CloudSyncPage(),
        service: service, presentation: presentation));
    await flush(t);
  }

  Future<void> tapAction(WidgetTester t, String key) async {
    final f = find.byKey(ValueKey(key));
    await t.ensureVisible(f);
    await t.tap(f);
    await flush(t);
  }

  Future<void> close(WidgetTester t) async {
    await t.tap(find.text(l.commonOk));
    await flush(t);
  }

  BeeCloudBackupAction action(WidgetTester t, String key) =>
      t.widget<BeeCloudBackupAction>(find.byKey(ValueKey(key)));
  TransactionsSyncManager realManager() => TransactionsSyncManager(
      config: config, db: db, repo: repo, provider: _Provider(auth, storage));
  Future<Map<String, dynamic>> remote({int version = 6}) async {
    final data =
        jsonDecode(await exportTransactionsJson(db, 1)) as Map<String, dynamic>;
    data['version'] = version;
    return data;
  }

  for (final brightness in Brightness.values) {
    scenario('320与1.4字号长状态及本地远端信息无溢出 $brightness', (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(host(
          Scaffold(
              body: SingleChildScrollView(
                  padding: const EdgeInsets.all(17),
                  child: BeeCloudBackupSummary(
                      title: 'A long ledger backup synchronization status',
                      status:
                          'Cloud content is different from the current local book',
                      icon: const BeeLineIcon('Cloud'),
                      localSummary: 'Local: 123456 records',
                      remoteSummary: 'Remote: 123455 records',
                      backupTime: 'Latest backup: 2026-10-20 12:30:00',
                      onDetails: () {}))),
          brightness: brightness,
          scale: 1.4));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
  for (final diff in SyncDiff.values) {
    scenario('八种原状态与操作约束 $diff', (t) async {
      sync.status = SyncStatus(
          diff: diff, localCount: 2, cloudCount: 1, localFingerprint: 'qa');
      await show(t);
      expect(action(t, 'cb95-upload').enabled,
          diff != SyncDiff.inSync && diff != SyncDiff.notLoggedIn);
      expect(action(t, 'cb95-download').enabled,
          diff != SyncDiff.inSync && diff != SyncDiff.notLoggedIn);
      expect(find.text(cloudBackupPresentation(sync.status, l).label),
          findsOneWidget);
    });
  }
  for (final entry in {
    '__SYNC_NOT_CONFIGURED__': 'configuration',
    '__SYNC_NOT_LOGGED_IN__': 'login',
    '__SYNC_CLOUD_BACKUP_CORRUPTED__': 'corrupted',
    '__SYNC_NO_CLOUD_BACKUP__': 'missing',
    '__SYNC_ACCESS_DENIED__': 'denied'
  }.entries) {
    scenario('原符号错误本地化且详情保留 ${entry.value}', (t) async {
      sync.status = SyncStatus(
          diff: SyncDiff.error,
          localCount: 2,
          localFingerprint: 'local-qa',
          cloudCount: 1,
          cloudFingerprint: 'remote-qa',
          cloudExportedAt: DateTime.utc(2026, 10, 20),
          message: entry.key);
      await show(t);
      await t.tap(find.byType(BeeCloudBackupSummary));
      await flush(t);
      expect(find.textContaining(l.mineSyncLocalFingerprint('local-qa')),
          findsOneWidget);
      expect(
          find.textContaining(cloudBackupMessage(entry.key, l)!), findsWidgets);
      await close(t);
    });
  }
  scenario('无账本不初始化认证或查询远端', (t) async {
    ledger = 0;
    await show(t);
    expect(find.text(l.aiOcrNoLedger), findsOneWidget);
    expect(auth.reads, 0);
    expect(sync.statusCalls, 0);
  });
  scenario('本地模式显示原禁用提示与操作，隐藏账号自动同步', (t) async {
    config = cloud.CloudServiceConfig.localStorage();
    await show(t);
    expect(action(t, 'cb95-upload').enabled, isFalse);
    expect(action(t, 'cb95-download').enabled, isFalse);
    expect(find.byType(BeeCloudBackupPreference), findsNothing);
  });
  scenario('首次状态异常显示错误重试，恢复后不再重复currentUser查询', (t) async {
    sync.statusError = StateError('QA status failed');
    await show(t);
    expect(find.textContaining('QA status failed'), findsOneWidget);
    expect(action(t, 'cb95-upload').busy, isFalse);
    expect(auth.reads, 1);
    sync.statusError = null;
    await t.tap(find.text(l.v4RecordingRetry));
    await flush(t);
    expect(action(t, 'cb95-upload').enabled, isTrue);
    expect(sync.clears, 1);
    expect(auth.reads, 1);
  });
  scenario('备份自动同步开关沿用原偏好，不发上传', (t) async {
    await show(t);
    await t.ensureVisible(find.byType(SwitchListTile));
    await t.tap(find.byType(SwitchListTile));
    await flush(t);
    expect(
        (await SharedPreferences.getInstance()).getBool('auto_sync'), isTrue);
    expect(sync.uploads, 0);
  });
  scenario('多设备启用沿用原一次状态清缓存', (t) async {
    SharedPreferences.setMockInitialValues({'multi_device_sync': true});
    await show(t);
    expect(sync.clears, 1);
  });
  scenario('Supabase未登录显示登录，上传下载和自动同步禁用', (t) async {
    config = const cloud.CloudServiceConfig(
        type: cloud.CloudBackendType.supabase,
        name: 'QA',
        supabaseUrl: 'https://qa.invalid',
        supabaseAnonKey: 'synthetic');
    auth.user = null;
    await show(t);
    expect(action(t, 'cb95-upload').enabled, isFalse);
    expect(find.text(l.mineLoginTitle), findsOneWidget);
    expect(t.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull);
  });
  scenario('Supabase退出取消无副作用，确认走原auth并刷新', (t) async {
    config = const cloud.CloudServiceConfig(
        type: cloud.CloudBackendType.supabase,
        name: 'QA',
        supabaseUrl: 'https://qa.invalid',
        supabaseAnonKey: 'synthetic');
    await show(t);
    await t.tap(find.text('qa@example.invalid'));
    await flush(t);
    await t.tap(find.text(l.commonCancel));
    await flush(t);
    expect(auth.signouts, 0);
    await t.tap(find.text('qa@example.invalid'));
    await flush(t);
    await t.tap(find.widgetWithText(FilledButton, l.mineLogoutButton));
    await flush(t);
    expect(auth.signouts, 1);
    expect(find.text(l.mineLoginTitle), findsOneWidget);
  });
  scenario('BeeCount分支保留只读账号且不显示手动快照/自动同步', (t) async {
    config = const cloud.CloudServiceConfig(
        type: cloud.CloudBackendType.beecountCloud,
        name: 'QA',
        beecountCloudBaseUrl: 'https://qa.invalid');
    await show(t);
    expect(find.text('qa@example.invalid'), findsOneWidget);
    expect(find.byKey(const ValueKey('cb95-upload')), findsNothing);
    expect(find.byType(BeeCloudBackupPreference), findsNothing);
  });
  scenario('认证状态在页面外变化时失效缓存并恢复原登录入口', (t) async {
    config = const cloud.CloudServiceConfig(
        type: cloud.CloudBackendType.beecountCloud,
        name: 'QA',
        beecountCloudBaseUrl: 'https://qa.invalid');
    await show(t);
    expect(find.text('qa@example.invalid'), findsOneWidget);
    auth.user = null;
    auth.events.add(null);
    await flush(t);
    expect(find.text(l.mineLoginTitle), findsOneWidget);
    expect(find.text('qa@example.invalid'), findsNothing);
  });
  scenario('BeeCount冷provider缓存凭证首次重登等待唯一实例', (t) async {
    config = const cloud.CloudServiceConfig(
        type: cloud.CloudBackendType.beecountCloud,
        name: 'QA',
        beecountCloudBaseUrl: 'https://qa.invalid',
        beecountCloudEmail: 'qa@example.invalid',
        beecountCloudPassword: 'qa-synthetic');
    auth.user = null;
    await show(t);
    await t.tap(find.text(l.cloudReloginTitle));
    await flush(t);
    expect(auth.logins, 1);
    expect(find.text('qa@example.invalid'), findsOneWidget);
  });
  scenario('BeeCount无凭证保持原登录路由', (t) async {
    config = const cloud.CloudServiceConfig(
        type: cloud.CloudBackendType.beecountCloud,
        name: 'QA',
        beecountCloudBaseUrl: 'https://qa.invalid');
    auth.user = null;
    await show(t);
    await t.tap(find.text(l.mineLoginTitle));
    await flush(t);
    expect(find.byType(LoginPage), findsOneWidget);
  });
  scenario('上传忙碌阻止重复操作，成功保留详情与状态刷新', (t) async {
    sync.gate = Completer<void>();
    await show(t);
    await tapAction(t, 'cb95-upload');
    expect(sync.uploads, 1);
    expect(action(t, 'cb95-upload').busy, isTrue);
    expect(action(t, 'cb95-download').enabled, isFalse);
    sync.gate!.complete();
    await flush(t);
    expect(find.text(l.mineUploadSuccess), findsOneWidget);
    await close(t);
    expect(action(t, 'cb95-upload').enabled, isFalse);
    expect(sync.uploads, 1);
  });
  scenario('上传失败清理忙碌与全局上传标记，可再次重试', (t) async {
    sync.uploadError = StateError('QA upload failed');
    await show(t);
    final c =
        ProviderScope.containerOf(t.element(find.byType(CloudBackupControls)));
    await tapAction(t, 'cb95-upload');
    expect(find.textContaining('QA upload failed'), findsOneWidget);
    await close(t);
    expect(c.read(uploadingLedgerIdsProvider), isEmpty);
    expect(action(t, 'cb95-upload').enabled, isTrue);
  });
  scenario('非TransactionsSyncManager保留直接恢复与成功刷新', (t) async {
    await show(t);
    final c =
        ProviderScope.containerOf(t.element(find.byType(CloudBackupControls)));
    await tapAction(t, 'cb95-download');
    expect(sync.downloads, 1);
    expect(find.text(l.mineDownloadResult(2)), findsOneWidget);
    await close(t);
    expect(c.read(statsRefreshProvider), 1);
  });
  scenario('恢复失败显示原错误弹窗且解除忙碌', (t) async {
    sync.downloadError = StateError('QA download failed');
    await show(t);
    await tapAction(t, 'cb95-download');
    expect(find.textContaining('QA download failed'), findsOneWidget);
    await close(t);
    expect(action(t, 'cb95-download').enabled, isTrue);
  });
  scenario('真实SQLite快照上传经MockClient保存完整JSON且不改本地', (t) async {
    final manager = realManager();
    await show(t, service: manager, presentation: sync.status);
    await tapAction(t, 'cb95-upload');
    expect(find.text(l.mineUploadSuccess), findsOneWidget);
    final data =
        jsonDecode(storage.files['ledger_1.json']!) as Map<String, dynamic>;
    expect(data['version'], 6);
    expect(data['count'], 2);
    expect((data['items'] as List).map((e) => e['syncId']),
        containsAll(['qa-one', 'qa-two']));
    expect((await db.select(db.transactions).get()).length, 2);
    await close(t);
    expect(
        storage.requests
            .any((r) => r.method == 'PUT' && r.url.path == '/ledger_1.json'),
        isTrue);
  });
  scenario('真实v6差异预览取消不写SQLite，选择应用保留新增修改删除', (t) async {
    final data = await remote();
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    data['items'] = [
      {...items.first, 'amount': 20.0},
      {...items.first, 'syncId': 'qa-three', 'amount': 30.0, 'note': 'QA added'}
    ];
    data['count'] = 2;
    storage.files['ledger_1.json'] = jsonEncode(data);
    await show(t, service: realManager(), presentation: sync.status);
    await tapAction(t, 'cb95-download');
    expect(find.text(l.syncPreviewTitle), findsOneWidget);
    expect(find.text(l.syncPreviewApply(3)), findsOneWidget);
    await t.tap(find.text(l.commonCancel));
    await flush(t);
    expect((await db.select(db.transactions).get()).first.amount, 10);
    await tapAction(t, 'cb95-download');
    await t.tap(find.text(l.syncPreviewApply(3)));
    await flush(t);
    expect(find.text(l.syncPreviewApplied(3)), findsOneWidget);
    await close(t);
    final txs = await db.select(db.transactions).get();
    expect(txs.length, 2);
    expect(txs.map((e) => e.syncId), containsAll(['qa-one', 'qa-three']));
    expect(txs.firstWhere((e) => e.syncId == 'qa-one').amount, 20);
    expect(txs.firstWhere((e) => e.syncId == 'qa-three').note, 'QA added');
  });
  scenario('真实旧格式快照先确认，取消不写入再确认恢复', (t) async {
    final data = await remote(version: 5);
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    data['items'] = [
      {...items.first, 'amount': 88.0}
    ];
    data['count'] = 1;
    storage.files['ledger_1.json'] = jsonEncode(data);
    await show(t, service: realManager(), presentation: sync.status);
    await tapAction(t, 'cb95-download');
    expect(find.text(l.syncPreviewOldFormat), findsOneWidget);
    await t.tap(find.text(l.commonCancel));
    await flush(t);
    expect((await db.select(db.transactions).get()).length, 2);
    await tapAction(t, 'cb95-download');
    await t.tap(find.text(l.commonConfirm));
    await flush(t);
    expect(find.text(l.mineDownloadComplete), findsOneWidget);
    await close(t);
    expect((await db.select(db.transactions).get()).length, 1);
  });
  scenario('真实无备份与相同备份分别返回原无数据/无变更结果', (t) async {
    await show(t, service: realManager(), presentation: sync.status);
    await tapAction(t, 'cb95-download');
    expect(find.text(l.mineDownloadResult(0)), findsOneWidget);
    await close(t);
    storage.files['ledger_1.json'] = jsonEncode(await remote());
    await tapAction(t, 'cb95-download');
    expect(find.text(l.syncPreviewEmpty), findsOneWidget);
    await close(t);
    expect((await db.select(db.transactions).get()).length, 2);
  });
  scenario('真实传输异常保持SQLite原数据', (t) async {
    storage.fail = true;
    await show(t, service: realManager(), presentation: sync.status);
    await tapAction(t, 'cb95-download');
    expect(find.textContaining('QA download 503'), findsOneWidget);
    await close(t);
    expect((await db.select(db.transactions).get()).length, 2);
  });
  scenario('原服务删除备份能力仅移除远端，页面不新增删除入口', (t) async {
    storage.files['ledger_1.json'] = '{}';
    await realManager().deleteRemoteBackup(ledgerId: 1);
    expect(storage.files, isEmpty);
    expect((await db.select(db.transactions).get()).length, 2);
    await show(t);
    expect(storage.requests.single.method, 'DELETE');
    expect(find.textContaining('Delete backup'), findsNothing);
  });
  scenario('画廊示例和真实缓存预览不查询认证或远端', (t) async {
    await t.pumpWidget(host(const Scaffold(
        body: SingleChildScrollView(
            child: CloudBackupSample(liveData: LiveCloudBackupPreview())))));
    await flush(t);
    expect(auth.reads, 0);
    expect(sync.statusCalls, 0);
    await t.ensureVisible(find.text(l.mineAutoSyncTitle));
    await t.tap(find.byType(SwitchListTile));
    await flush(t);
    expect(sync.uploads, 0);
    expect(
        (await SharedPreferences.getInstance()).getBool('auto_sync'), isNull);
  });
}
