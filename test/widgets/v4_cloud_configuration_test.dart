import 'dart:async';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/pages/auth/login_page.dart';
import 'package:beecount/pages/cloud/cloud_service_page.dart';
import 'package:beecount/presentation/v4/bindings/cloud_configuration_controls.dart';
import 'package:beecount/presentation/v4/bindings/cloud_configuration_preview.dart';
import 'package:beecount/presentation/v4/bindings/cloud_login_controls.dart';
import 'package:beecount/presentation/v4/gallery/cloud_configuration_sample.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/cloud/sync_service.dart' as local;
import 'package:beecount_business_ui/cloud_configuration.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' hide SyncStatus;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends NoopAuthService {
  int logins = 0, signouts = 0;
  String? submittedEmail, submittedPassword;
  Object? error;
  Completer<void>? gate;
  @override
  Future<CloudUser> signInWithEmail(
      {required String email, required String password}) async {
    logins++;
    submittedEmail = email;
    submittedPassword = password;
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return const CloudUser(id: 'qa-user', email: 'qa@example.invalid');
  }

  @override
  Future<void> signOut() async {
    signouts++;
  }
}

class _Runtime extends ActiveCloudRuntimeController {
  final saves = <CloudServiceConfig>[];
  final activations = <CloudBackendType>[];
  Object? saveError;
  bool activateResult = true;
  @override
  Future<ActiveCloudRuntime?> build() async => null;
  @override
  Future<void> saveOnly(CloudServiceConfig config) async {
    if (saveError != null) throw saveError!;
    saves.add(config);
  }

  @override
  Future<bool> activate(CloudBackendType type) async {
    activations.add(type);
    return activateResult;
  }
}

class _Provider extends BeeCountCloudProvider {
  _Provider(this.service);
  final _Auth service;
  @override
  CloudAuthService get auth => service;
}

class _Sync extends local.LocalOnlySyncService {
  int uploads = 0;
  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) async {
    uploads++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = AppLocalizationsEn();
  late _Auth auth;
  late _Runtime runtime;
  late _Sync sync;
  late CloudServiceConfig active;
  final configs = <CloudBackendType, CloudServiceConfig?>{};
  bool ios = false;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = _Auth();
    runtime = _Runtime();
    sync = _Sync();
    active = CloudServiceConfig.localStorage();
    configs.clear();
    ios = false;
  });
  Widget host(Widget page,
          {Brightness brightness = Brightness.light, double scale = 1}) =>
      ProviderScope(
          overrides: [
            activeCloudConfigProvider.overrideWith((ref) async => active),
            beecountCloudConfigProvider.overrideWith(
                (ref) async => configs[CloudBackendType.beecountCloud]),
            supabaseConfigProvider.overrideWith(
                (ref) async => configs[CloudBackendType.supabase]),
            webdavConfigProvider
                .overrideWith((ref) async => configs[CloudBackendType.webdav]),
            s3ConfigProvider
                .overrideWith((ref) async => configs[CloudBackendType.s3]),
            authServiceProvider.overrideWith((ref) async => auth),
            activeCloudRuntimeProvider.overrideWith(() => runtime),
            beecountCloudProviderInstance
                .overrideWith((ref) async => _Provider(auth)),
            syncServiceProvider.overrideWithValue(sync),
            cloudConfigurationShowICloudProvider.overrideWith((ref) => ios),
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
  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (t) async {
      try {
        await body(t);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
        await t.pump(const Duration(seconds: 4));
      }
    });
  }

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pumpAndSettle();
  }

  Future<void> fields(WidgetTester t, String key, String value) async {
    final field = find.descendant(
        of: find.byKey(ValueKey(key)), matching: find.byType(TextFormField));
    await t.ensureVisible(field);
    await t.enterText(field, value);
  }

  Future<void> openPage(WidgetTester t, Widget page, {double scale = 1}) async {
    await t.pumpWidget(host(
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    child: const Text('Open QA route'),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute<void>(builder: (_) => page))))),
        scale: scale));
    await t.tap(find.text('Open QA route'));
    await settle(t);
  }

  Future<void> openConfig(WidgetTester t, CloudBackendType type,
      {double scale = 1}) async {
    await t.pumpWidget(host(const CloudServicePage(), scale: scale));
    await settle(t);
    await t.tap(find.text(type == CloudBackendType.beecountCloud
        ? l.cloudTabCloudSync
        : l.cloudTabBackup));
    await settle(t);
    final title = switch (type) {
      CloudBackendType.beecountCloud => l.cloudBeeCountCloudTitle,
      CloudBackendType.supabase => l.cloudCustomSupabaseTitle,
      CloudBackendType.webdav => l.cloudCustomWebdavTitle,
      _ => l.cloudCustomS3Title,
    };
    await t.ensureVisible(find.text(title));
    await t.tap(find.text(title));
    await settle(t);
  }

  CloudServiceConfig config(CloudBackendType type) => switch (type) {
        CloudBackendType.beecountCloud => const CloudServiceConfig(
            type: CloudBackendType.beecountCloud,
            name: 'QA BeeCount',
            beecountCloudBaseUrl: 'https://cloud.example.invalid'),
        CloudBackendType.webdav => const CloudServiceConfig(
            type: CloudBackendType.webdav,
            name: 'QA DAV',
            webdavUrl: 'https://dav.example.invalid/base',
            webdavUsername: 'qa',
            webdavPassword: 'qa-synthetic'),
        CloudBackendType.supabase => const CloudServiceConfig(
            type: CloudBackendType.supabase,
            name: 'QA Supabase',
            supabaseUrl: 'https://sb.example.invalid',
            supabaseAnonKey: 'qa-anon'),
        CloudBackendType.s3 => const CloudServiceConfig(
            type: CloudBackendType.s3,
            name: 'QA S3',
            s3Endpoint: 's3.example.invalid',
            s3AccessKey: 'qa-access',
            s3SecretKey: 'qa-secret',
            s3Bucket: 'qa-bucket'),
        CloudBackendType.icloud => const CloudServiceConfig(
            type: CloudBackendType.icloud, name: 'iCloud'),
        _ => CloudServiceConfig.localStorage(),
      };

  for (final brightness in Brightness.values) {
    scenario('320与1.4字号云服务卡长文本，配置和教程点击不触发选择 $brightness', (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var selection = 0, configuration = 0, guide = 0;
      await t.pumpWidget(host(
          Scaffold(
              body: SingleChildScrollView(
                  padding: const EdgeInsets.all(17),
                  child: BeeCloudServiceCard(
                      title: 'A long self hosted cloud configuration',
                      subtitle:
                          'long-server-with-a-custom-path.example.invalid',
                      icon: const BeeLineIcon('Cloud'),
                      selected: true,
                      configureLabel: 'Configure connection',
                      guideLabel: 'Read the tutorial',
                      onTap: () => selection++,
                      onConfigure: () => configuration++,
                      onGuide: () => guide++))),
          brightness: brightness,
          scale: 1.4));
      await t.tap(find.text('Configure connection'));
      await settle(t);
      await t.tap(find.text('Read the tutorial'));
      await settle(t);
      expect(selection, 0);
      expect(configuration, 1);
      expect(guide, 1);
      expect(t.takeException(), isNull);
    });
  }
  scenario('画廊本地编辑和登录回调均不初始化认证服务', (t) async {
    await t.pumpWidget(host(const Scaffold(
        body: SingleChildScrollView(child: CloudConfigurationSample()))));
    await settle(t);
    await t.tap(find.text(l.commonConfigure));
    await settle(t);
    expect(find.byType(BeeCloudConfigurationDialog), findsOneWidget);
    await t.tap(find.text(l.commonCancel));
    await settle(t);
    await t.ensureVisible(find.text(l.authLogin));
    await t.tap(find.text(l.authLogin));
    await settle(t);
    expect(auth.logins, 0);
    expect(runtime.saves, isEmpty);
  });
  scenario('真实只读画廊绑定仅展示脱敏端点，不调用认证', (t) async {
    active = config(CloudBackendType.webdav);
    await t.pumpWidget(
        host(const Scaffold(body: LiveCloudConfigurationPreview())));
    await settle(t);
    expect(find.text('dav.example.invalid'), findsOneWidget);
    expect(auth.logins, 0);
  });
  for (final type in CloudBackendType.values) {
    scenario('六类服务保留原初始栏目 $type', (t) async {
      active = config(type);
      configs[type] = active;
      await t.pumpWidget(host(const CloudServicePage()));
      await settle(t);
      final selected = t
          .widget<BeeSegmented<String>>(find.byType(BeeSegmented<String>))
          .value;
      expect(
          selected,
          type == CloudBackendType.local
              ? 'offline'
              : type == CloudBackendType.beecountCloud
                  ? 'cloud'
                  : 'backup');
      expect(auth.logins, 0);
    });
  }
  scenario('备份栏目保留WebDAV/S3/Supabase及iOS专属iCloud', (t) async {
    ios = true;
    await t.pumpWidget(host(const CloudServicePage()));
    await settle(t);
    await t.tap(find.text(l.cloudTabBackup));
    await settle(t);
    expect(find.text('iCloud'), findsOneWidget);
    expect(find.byType(BeeCloudServiceCard), findsNWidgets(4));
    expect(find.text(l.cloudCustomWebdavTitle), findsOneWidget);
    expect(find.text(l.cloudCustomS3Title), findsOneWidget);
    expect(find.text(l.cloudCustomSupabaseTitle), findsOneWidget);
  });
  for (final type in [
    CloudBackendType.beecountCloud,
    CloudBackendType.supabase,
    CloudBackendType.webdav,
    CloudBackendType.s3
  ]) {
    scenario('四种配置保持弹窗与字段、取消不保存 $type', (t) async {
      await openConfig(t, type);
      expect(find.byType(BeeCloudConfigurationDialog), findsOneWidget);
      expect(
          find.byType(BeeField),
          findsNWidgets(type == CloudBackendType.s3
              ? 6
              : type == CloudBackendType.webdav
                  ? 4
                  : 3));
      expect(find.byType(CloudServicePage), findsOneWidget);
      await t.tap(find.text(l.commonCancel));
      await settle(t);
      expect(runtime.saves, isEmpty);
      expect(find.byType(BeeCloudConfigurationDialog), findsNothing);
    });
  }
  scenario('BeeCount地址独立保存，隐藏API前缀和空账号原语义保留', (t) async {
    await openConfig(t, CloudBackendType.beecountCloud);
    await fields(t, 'cc91-beecount-url', ' https://qa.example.invalid/ ');
    await t.tap(find.text(l.commonSave));
    await settle(t);
    final saved = runtime.saves.single;
    expect(saved.beecountCloudBaseUrl, 'https://qa.example.invalid/');
    expect(saved.beecountCloudApiPrefix, '/api/v1');
    expect(saved.beecountCloudEmail, isNull);
    expect(saved.beecountCloudPassword, isNull);
    expect(runtime.activations, isEmpty);
    expect(auth.logins, 0);
  });
  scenario('BeeCount凭证保存使用原唯一provider登录并调度首次同步', (t) async {
    await openConfig(t, CloudBackendType.beecountCloud);
    await fields(t, 'cc91-beecount-url', 'https://qa.example.invalid');
    await fields(t, 'cc91-beecount-email', ' qa@example.invalid ');
    await fields(t, 'cc91-beecount-password', ' qa-password ');
    await t.tap(find.text(l.commonSave));
    await settle(t);
    expect(auth.logins, 1);
    expect(auth.submittedEmail, 'qa@example.invalid');
    expect(auth.submittedPassword, 'qa-password');
    expect(runtime.saves.single.beecountCloudPassword, 'qa-password');
    expect(sync.uploads, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('auto_sync'), isTrue);
  });
  scenario('Supabase保存保留多行AnonKey和默认bucket', (t) async {
    await openConfig(t, CloudBackendType.supabase);
    await fields(t, 'cc91-supabase-url', ' https://sb.example.invalid ');
    await fields(t, 'cc91-supabase-key', ' qa-key ');
    await t.tap(find.text(l.commonSave));
    await settle(t);
    expect(runtime.saves.single.supabaseBucket, 'beecount-backups');
    expect(runtime.saves.single.supabaseAnonKey, 'qa-key');
  });
  scenario('WebDAV保存保留用户名密码及默认路径', (t) async {
    await openConfig(t, CloudBackendType.webdav);
    await fields(t, 'cc91-webdav-url', 'https://dav.example.invalid');
    await fields(t, 'cc91-webdav-username', ' qa ');
    await fields(t, 'cc91-webdav-password', ' qa-synthetic ');
    await fields(t, 'cc91-webdav-path', '');
    await t.tap(find.text(l.commonSave));
    await settle(t);
    expect(runtime.saves.single.webdavRemotePath, '/');
    expect(runtime.saves.single.webdavUsername, 'qa');
    expect(runtime.saves.single.webdavPassword, 'qa-synthetic');
    expect(auth.logins, 0);
  });
  scenario('S3保存剥离协议，保留SSL、端口与默认region', (t) async {
    await openConfig(t, CloudBackendType.s3);
    for (final entry in {
      'endpoint': 'https://s3.example.invalid',
      'region': '',
      'access-key': 'qa-access',
      'secret-key': 'qa-secret',
      'bucket': 'qa-bucket',
      'port': '9000'
    }.entries) {
      await fields(t, 'cc91-s3-${entry.key}', entry.value);
    }
    await t.ensureVisible(find.byType(SwitchListTile));
    await t.tap(find.byType(SwitchListTile));
    await t.tap(find.text(l.commonSave));
    await settle(t);
    final saved = runtime.saves.single;
    expect(saved.s3Endpoint, 's3.example.invalid');
    expect(saved.s3Region, 'us-east-1');
    expect(saved.s3UseSSL, isFalse);
    expect(saved.s3Port, 9000);
  });
  scenario('320与1.4字号S3完整弹窗可滚动并始终保留保存取消', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await openConfig(t, CloudBackendType.s3, scale: 1.4);
    await fields(t, 'cc91-s3-port', '9000');
    expect(find.text(l.commonSave), findsOneWidget);
    await t.tap(find.text(l.commonCancel));
    await settle(t);
    expect(runtime.saves, isEmpty);
    expect(t.takeException(), isNull);
  });

  scenario('已配置卡点击走切换确认，独立配置保留旧隐藏前缀与草稿', (t) async {
    configs[CloudBackendType.beecountCloud] = const CloudServiceConfig(
        type: CloudBackendType.beecountCloud,
        name: 'QA',
        beecountCloudBaseUrl: 'https://qa.example.invalid',
        beecountCloudApiPrefix: '/qa/v2');
    await t.pumpWidget(host(const CloudServicePage()));
    await settle(t);
    await t.tap(find.text(l.cloudTabCloudSync));
    await settle(t);
    await t.tap(find.text(l.cloudBeeCountCloudTitle));
    await settle(t);
    expect(find.text(l.cloudSwitchConfirmTitle), findsOneWidget);
    await t.tap(find.text(l.commonCancel));
    await settle(t);
    await t.tap(find.text(l.commonConfigure));
    await settle(t);
    expect(
        t
            .widgetList<TextFormField>(find.byType(TextFormField))
            .first
            .controller!
            .text,
        'https://qa.example.invalid');
    await t.tap(find.text(l.commonSave));
    await settle(t);
    expect(runtime.saves.single.beecountCloudApiPrefix, '/qa/v2');
    expect(auth.logins, 0);
  });

  scenario('无效配置显示原错误弹窗，配置不落存储', (t) async {
    await openConfig(t, CloudBackendType.supabase);
    await t.tap(find.text(l.commonSave));
    await settle(t);
    expect(find.text(l.cloudConfigInvalidTitle), findsOneWidget);
    expect(runtime.saves, isEmpty);
  });
  scenario('保存失败保留原错误流程', (t) async {
    runtime.saveError = StateError('QA save failure');
    await openConfig(t, CloudBackendType.beecountCloud);
    await fields(t, 'cc91-beecount-url', 'https://qa.example.invalid');
    await t.tap(find.text(l.commonSave));
    await settle(t);
    expect(find.text(l.cloudSaveFailed), findsOneWidget);
    expect(find.textContaining('QA save failure'), findsOneWidget);
  });
  scenario('切换取消不退出，确认后先退出旧服务再activate', (t) async {
    active = config(CloudBackendType.webdav);
    await t.pumpWidget(host(const CloudServicePage()));
    await settle(t);
    await t.tap(find.text(l.cloudTabOffline));
    await settle(t);
    await t.tap(find.text(l.cloudLocalStorageTitle));
    await settle(t);
    expect(find.text(l.cloudSwitchConfirmTitle), findsOneWidget);
    await t.tap(find.text(l.commonCancel));
    await settle(t);
    expect(auth.signouts, 0);
    expect(runtime.activations, isEmpty);
    await t.tap(find.text(l.cloudLocalStorageTitle));
    await settle(t);
    await t.tap(find.text(l.commonConfirm));
    await settle(t);
    expect(auth.signouts, 1);
    expect(runtime.activations, [CloudBackendType.local]);
  });
  scenario('五类完整教程与备份多设备说明均保留弹窗', (t) async {
    ios = true;
    active = config(CloudBackendType.webdav);
    await t.pumpWidget(host(const CloudServicePage()));
    await settle(t);
    await t.tap(find.text(l.cloudMultiDeviceWarningTitle));
    await settle(t);
    expect(find.text(l.cloudSyncGuideLimitItem4), findsOneWidget);
    await t.tap(find.text(l.cloudSyncGuideGotIt));
    await settle(t);
    for (final title in [
      'iCloud',
      l.cloudCustomWebdavTitle,
      l.cloudCustomS3Title,
      l.cloudCustomSupabaseTitle
    ]) {
      final card = find.ancestor(
          of: find.text(title), matching: find.byType(BeeCloudServiceCard));
      final guide =
          find.descendant(of: card, matching: find.text(l.commonTutorial));
      await t.ensureVisible(guide);
      await t.tap(guide);
      await settle(t);
      expect(find.byType(BeeDialog), findsOneWidget);
      await t.tap(find.text(l.commonConfirm));
      await settle(t);
    }
    await t.tap(find.text(l.cloudTabCloudSync));
    await settle(t);
    await t.tap(find.text(l.commonTutorial));
    await settle(t);
    expect(find.text(l.cloudTutorialFeature4), findsOneWidget);
    await t.tap(find.text(l.cloudTutorialGotIt));
    await settle(t);
    expect(auth.logins, 0);
  });
  scenario('BeeCount公开version测试通过MockClient且无认证请求', (t) async {
    active = config(CloudBackendType.beecountCloud);
    configs[active.type] = active;
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await t.pumpWidget(host(const CloudServicePage()));
      await settle(t);
      await t.tap(find.byTooltip(l.cloudTestConnection));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(l.cloudTestSuccessTitle), findsOneWidget);
      await t.tap(find.text(l.commonOk));
      await settle(t);
    },
        () => MockClient((request) async {
              requests.add(request);
              return http.Response('{}', 200);
            }));
    expect(requests.single.url.toString(),
        'https://cloud.example.invalid/api/v1/version');
    expect(requests.single.headers.containsKey('Authorization'), isFalse);
    expect(auth.logins, 0);
  });
  scenario('连接失败显示原错误详情，关闭后状态为失败', (t) async {
    active = config(CloudBackendType.supabase);
    configs[active.type] = active;
    await http.runWithClient(() async {
      await t.pumpWidget(host(const CloudServicePage()));
      await settle(t);
      await t.tap(find.byTooltip(l.cloudTestConnection));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(l.cloudTestFailedTitle), findsOneWidget);
      expect(find.text(l.cloudErrorAuthFailed), findsOneWidget);
      await t.tap(find.text(l.commonOk));
      await settle(t);
      expect(find.text(l.cloudStatusFailed), findsOneWidget);
    }, () => MockClient((_) async => http.Response('', 401)));
  });
  scenario('多设备偏好启用时沿用静默自动探针且只请求一次', (t) async {
    SharedPreferences.setMockInitialValues({'multi_device_sync': true});
    active = config(CloudBackendType.beecountCloud);
    var requests = 0;
    await http.runWithClient(() async {
      await t.pumpWidget(host(const CloudServicePage()));
      await settle(t);
      expect(find.text(l.cloudStatusNormal), findsOneWidget);
      expect(find.text(l.cloudTestSuccessTitle), findsNothing);
    },
        () => MockClient((_) async {
              requests++;
              return http.Response('{}', 200);
            }));
    expect(requests, 1);
    expect(auth.logins, 0);
  });

  scenario('登录忙碌阻止重复请求，离开后失败不再更新已销毁页面', (t) async {
    active = config(CloudBackendType.beecountCloud);
    auth.gate = Completer<void>();
    auth.error = Exception('QA failed after leaving');
    await openPage(t, const LoginPage());
    await fields(t, 'cloud-login-email', 'qa@example.invalid');
    await t.tap(find.text(l.authLogin).last);
    await t.pump();
    await t.tap(find.text(l.authLogin).last);
    await t.pump();
    expect(auth.logins, 1);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(find.byType(CloudLoginControls), findsNothing);
    auth.gate!.complete();
    await settle(t);
    expect(find.text('Open QA route'), findsOneWidget);
    expect(runtime.saves, isEmpty);
    expect(t.takeException(), isNull);
  });

  scenario('WebDAV登录特殊页无需账号，保留返回', (t) async {
    active = config(CloudBackendType.webdav);
    await openPage(t, const LoginPage());
    expect(find.byType(BeeCloudConfiguredNotice), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await t.tap(find.text(l.commonBack));
    await settle(t);
    expect(find.text('Open QA route'), findsOneWidget);
    expect(auth.logins, 0);
  });
  scenario('登录邮箱校验不请求服务，密码可见和记住账号受控', (t) async {
    active = config(CloudBackendType.beecountCloud);
    await openPage(t, const LoginPage());
    await fields(t, 'cloud-login-email', 'invalid');
    await t.tap(find.text(l.authLogin).last);
    await settle(t);
    expect(find.text(l.authInvalidEmail), findsOneWidget);
    expect(auth.logins, 0);
    expect(t.widgetList<TextField>(find.byType(TextField)).last.obscureText,
        isTrue);
    await t.tap(find.byTooltip(l.authPassword));
    await settle(t);
    expect(t.widgetList<TextField>(find.byType(TextField)).last.obscureText,
        isFalse);
    await t.tap(find.byType(CheckboxListTile));
    await settle(t);
    expect(t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue);
  });
  for (final type in [
    CloudBackendType.beecountCloud,
    CloudBackendType.supabase
  ]) {
    scenario('原记住账号加载并保存相同后端配置 $type', (t) async {
      active = type == CloudBackendType.beecountCloud
          ? CloudServiceConfig(
              type: type,
              name: 'QA',
              beecountCloudBaseUrl: 'https://qa.example.invalid',
              beecountCloudApiPrefix: '/qa/v2',
              beecountCloudEmail: 'qa@example.invalid',
              beecountCloudPassword: 'qa-password')
          : CloudServiceConfig(
              type: type,
              name: 'QA',
              supabaseUrl: 'https://sb.example.invalid',
              supabaseAnonKey: 'qa-anon',
              supabaseEmail: 'qa@example.invalid',
              supabasePassword: 'qa-password');
      await openPage(t, const LoginPage());
      final inputs =
          t.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      expect(inputs.first.controller!.text, 'qa@example.invalid');
      expect(inputs.last.controller!.text, 'qa-password');
      await t.tap(find.text(l.authLogin).last);
      await settle(t);
      expect(auth.logins, 1);
      expect(runtime.saves.single.type, type);
      expect(find.text('Open QA route'), findsOneWidget);
    });
  }
  scenario('登录不本地校验密码强度，未记住时清除缓存且切回我的页', (t) async {
    active = config(CloudBackendType.beecountCloud);
    await openPage(t, const LoginPage());
    final container =
        ProviderScope.containerOf(t.element(find.byType(CloudLoginControls)));
    await fields(t, 'cloud-login-email', ' qa@example.invalid ');
    await fields(t, 'cloud-login-password', '');
    await t.tap(find.text(l.authLogin).last);
    await settle(t);
    expect(auth.submittedPassword, '');
    expect(auth.submittedEmail, 'qa@example.invalid');
    expect(runtime.saves.single.beecountCloudEmail, isNull);
    expect(container.read(bottomTabIndexProvider), 3);
    expect(container.read(syncStatusRefreshProvider), 1);
  });
  for (final error in [
    'invalid credentials',
    'email not confirmed',
    'rate limit',
    'network timeout',
    'other failure'
  ]) {
    scenario('登录错误保留原友好分类与调试信息 $error', (t) async {
      active = config(CloudBackendType.beecountCloud);
      auth.error = Exception(error);
      await openPage(t, const LoginPage());
      await fields(t, 'cloud-login-email', 'qa@example.invalid');
      await fields(t, 'cloud-login-password', 'qa-password');
      await t.tap(find.text(l.authLogin).last);
      await settle(t);
      final message = error == 'invalid credentials'
          ? l.authErrorInvalidCredentials
          : error == 'email not confirmed'
              ? l.authErrorEmailNotConfirmed
              : error == 'rate limit'
                  ? l.authErrorRateLimit
                  : error == 'network timeout'
                      ? l.authErrorNetworkIssue
                      : l.authErrorLoginFailed;
      expect(find.textContaining(message), findsOneWidget);
      expect(find.textContaining('调试信息:'), findsOneWidget);
      expect(runtime.saves, isEmpty);
    });
  }
  test('注册指引仍按Supabase/BeeCount/其它选择原文档主题', () {
    expect(cloudLoginRegisterDocTopic(CloudBackendType.supabase), 'supabase');
    expect(cloudLoginRegisterDocTopic(CloudBackendType.beecountCloud),
        'beecount-cloud');
    expect(cloudLoginRegisterDocTopic(null), 'overview');
    expect(cloudLoginRegisterDocTopic(CloudBackendType.local), 'overview');
  });
}
