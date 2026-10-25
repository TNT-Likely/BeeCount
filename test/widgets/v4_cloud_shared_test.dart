import 'dart:async';
import 'dart:convert';
import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/pages/cloud/beecount_cloud_sync_page.dart';
import 'package:beecount/pages/cloud/invite_page.dart';
import 'package:beecount/pages/cloud/join_shared_ledger_page.dart';
import 'package:beecount/pages/cloud/member_list_page.dart';
import 'package:beecount/pages/cloud/member_stats_page.dart';
import 'package:beecount/presentation/v4/gallery/cloud_shared_sample.dart';
import 'package:beecount/presentation/v4/bindings/cloud_shared_preview.dart';
import 'package:beecount/providers.dart';
import 'package:beecount_business_ui/cloud_shared.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cloud/sync/_fakes/fake_beecount_cloud_provider.dart';

class _Auth extends BeeCountCloudAuthService {
  _Auth(http.Client client)
      : super(
            baseUrl: 'https://qa.invalid',
            apiPrefix: '/api/v1',
            httpClient: client);
  CloudUser? user = const CloudUser(id: 'owner', email: 'qa@example.invalid');
  final events = StreamController<CloudUser?>.broadcast();
  int reads = 0, logins = 0;
  Object? loginError, readError;
  @override
  Future<String> requireAccessToken() async => 'synthetic-token';
  @override
  Future<CloudUser?> get currentUser async {
    reads++;
    if (readError != null) throw readError!;
    return user;
  }

  @override
  Stream<CloudUser?> get authStateChanges => events.stream;
  @override
  String? get currentUserId => user?.id;
  @override
  String? get currentDeviceId => 'synthetic-device';
  @override
  Future<CloudUser> signInWithEmail(
      {required String email, required String password}) async {
    logins++;
    if (loginError != null) throw loginError!;
    user = CloudUser(id: 'owner', email: email);
    events.add(user);
    return user!;
  }
}

/// Real HTTP serializers/response parsing; the transport never opens sockets.
class _Cloud extends FakeBeeCountCloudProvider {
  _Cloud(this.httpStorage, this.testAuth);
  final BeeCountCloudStorageService httpStorage;
  final _Auth testAuth;
  @override
  CloudAuthService get auth => testAuth;
  @override
  String? get baseUrl => 'https://qa.invalid';
  @override
  Future<BeeCountCloudInvite> createInvite(
          {required String ledgerId,
          String role = 'editor',
          int expiresInHours = 24}) =>
      httpStorage.createInvite(
          ledgerId: ledgerId, role: role, expiresInHours: expiresInHours);
  @override
  Future<BeeCountCloudInvitePreview> previewInvite({required String code}) =>
      httpStorage.previewInvite(code: code);
  @override
  Future<BeeCountCloudInviteAcceptResult> acceptInvite(
          {required String code}) =>
      httpStorage.acceptInvite(code: code);
  @override
  Future<List<BeeCountCloudLedgerMember>> listMembers(
          {required String ledgerId}) =>
      httpStorage.listMembers(ledgerId: ledgerId);
  @override
  Future<void> removeMember(
          {required String ledgerId, required String userId}) =>
      httpStorage.removeMember(ledgerId: ledgerId, userId: userId);
  @override
  Future<BeeCountCloudMemberStats> fetchMemberStats(
          {required String ledgerId,
          String scope = 'month',
          String? period,
          int? tzOffsetMinutes}) =>
      httpStorage.fetchMemberStats(
          ledgerId: ledgerId,
          scope: scope,
          period: period,
          tzOffsetMinutes: tzOffsetMinutes);
  @override
  Future<BeeCountCloudSharedResources> fetchSharedResources(
          {required String ledgerId}) =>
      httpStorage.fetchSharedResources(ledgerId: ledgerId);
  @override
  Future<BeeCountCloudLedgerStats> readLedgerStats(
          {required String ledgerId}) =>
      httpStorage.readLedgerStats(ledgerId: ledgerId);
  @override
  Future<TwoFactorStatus> getTwoFactorStatus() => testAuth.getTwoFactorStatus();
  @override
  Future<BeeCountCloudProfile> getMyProfile() async =>
      const BeeCountCloudProfile(
          userId: 'owner',
          displayName: 'QA',
          incomeIsRed: true,
          themePrimaryColor: '#FACB16',
          appearance: {'header_skin': 'none'},
          aiConfig: {'providers': []});
}

class _Runtime extends ActiveCloudRuntimeController {
  _Runtime(this.runtime);
  final ActiveCloudRuntime runtime;
  @override
  Future<ActiveCloudRuntime?> build() async => runtime;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = AppLocalizationsEn();
  late BeeDatabase db;
  late LocalRepository repo;
  late _Auth auth;
  late _Cloud cloud;
  late SyncEngine engine;
  late MockClient client;
  late int ledger;
  final requests = <http.Request>[];
  int failure = 0;
  String failurePath = '';
  String detail = 'QA failure';
  String selfRole = 'owner';
  bool emptyStats = false, noSelf = false, twofa = true;
  Completer<void>? gate;
  String gatePath = '';
  Map<String, Object> healthStats = {};
  late CloudServiceConfig config;
  Map<String, dynamic> invite() => {
        'code': 'ABC234',
        'formatted_code': 'ABC 234',
        'target_role': 'editor',
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(days: 3))
            .toIso8601String(),
        'created_at': '2026-10-20T00:00:00Z',
        'share_url': 'https://qa.invalid/i/ABC234'
      };
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    failure = 0;
    failurePath = '';
    detail = 'QA failure';
    selfRole = 'owner';
    emptyStats = false;
    noSelf = false;
    twofa = true;
    gate = null;
    gatePath = '';
    healthStats = {};
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    final tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
    ledger = await db.into(db.ledgers).insert(LedgersCompanion.insert(
        name: 'Own book', syncId: const Value('book-own')));
    await db.into(db.ledgers).insert(LedgersCompanion.insert(
        name: 'Other book',
        currency: const Value('USD'),
        syncId: const Value('book-other')));
    client = MockClient((request) async {
      requests.add(request);
      expect(request.url.host, 'qa.invalid');
      expect(request.headers['Authorization'], 'Bearer synthetic-token');
      final path = request.url.path;
      if (gate != null && path.contains(gatePath)) await gate!.future;
      if (failure > 0 && path.contains(failurePath)) {
        return http.Response(jsonEncode({'detail': detail}), failure);
      }
      Object payload;
      if (path.endsWith('/preview')) {
        payload = {
          ...invite(),
          'ledger_external_id': 'book-shared',
          'ledger_name': 'Shared book',
          'ledger_currency': 'EUR',
          'invited_by_display': 'Owner QA'
        };
      } else if (path.endsWith('/accept')) {
        cloud.pushFakeLedger(
            ledgerId: 'book-shared',
            ledgerName: 'Shared book',
            currency: 'EUR',
            role: 'editor',
            isShared: true,
            memberCount: 2);
        payload = {
          'ledger_external_id': 'book-shared',
          'ledger_name': 'Shared book',
          'ledger_currency': 'EUR',
          'role': 'editor',
          'member_count': 2
        };
      } else if (path.endsWith('/invites')) {
        payload = invite();
      } else if (path.endsWith('/members')) {
        payload = [
          if (!noSelf)
            {
              'user_id': 'owner',
              'email': 'qa@example.invalid',
              'display_name': 'Self QA',
              'role': selfRole,
              'is_self': true,
              'joined_at': '2026-01-01T00:00:00Z'
            },
          {
            'user_id': 'editor-id',
            'email': 'editor@example.invalid',
            'display_name': 'Editor QA',
            'role': 'editor',
            'is_self': false,
            'joined_at': '2026-01-01T00:00:00Z'
          },
          {
            'user_id': 'another-owner',
            'email': 'owner2@example.invalid',
            'role': 'owner',
            'is_self': false,
            'joined_at': '2026-01-01T00:00:00Z'
          }
        ];
      } else if (request.method == 'DELETE') {
        return http.Response('', 204);
      } else if (path.endsWith('/member-stats')) {
        payload = {
          'ledger_id': 'book-shared',
          'ledger_currency': 'EUR',
          'scope': request.url.queryParameters['scope'],
          'items': emptyStats
              ? []
              : [
                  {
                    'user_id': 'x',
                    'email': '',
                    'income_total': 123.5,
                    'expense_total': 20,
                    'tx_count': 2
                  },
                  {
                    'user_id': 'editor-id',
                    'email': 'editor@example.invalid',
                    'display_name': 'Editor QA',
                    'income_total': 10,
                    'expense_total': 30,
                    'tx_count': 3
                  }
                ]
        };
      } else if (path.endsWith('/shared-resources')) {
        payload = {
          'owner_user_id': 'remote-owner',
          'categories': [
            {
              'sync_id': 'shared-cat',
              'name': 'Shared category',
              'kind': 'expense'
            }
          ],
          'accounts': [
            {
              'sync_id': 'shared-account',
              'name': 'Shared account',
              'currency': 'EUR'
            }
          ],
          'tags': [
            {'sync_id': 'shared-tag', 'name': 'Shared tag', 'color': '#FACB16'}
          ]
        };
      } else if (path.endsWith('/stats')) {
        payload = healthStats;
      } else if (path.endsWith('/2fa/status')) {
        payload = {
          'enabled': twofa,
          'enabled_at': twofa ? '2026-10-01T00:00:00Z' : null
        };
      } else {
        throw StateError(
            'Unexpected synthetic request: ${request.method} $path');
      }
      return http.Response(jsonEncode(payload), 200,
          headers: {'content-type': 'application/json'});
    });
    auth = _Auth(client);
    cloud = _Cloud(
        BeeCountCloudStorageService(
            baseUrl: 'https://qa.invalid',
            apiPrefix: '/api/v1',
            auth: auth,
            httpClient: client),
        auth);
    engine =
        SyncEngine(db: db, provider: cloud, changeTracker: tracker, repo: repo);
    config = const CloudServiceConfig(
        type: CloudBackendType.beecountCloud,
        name: 'QA',
        beecountCloudBaseUrl: 'https://qa.invalid');
  });
  tearDown(() async {
    await auth.events.close();
    auth.dispose();
    client.close();
    await db.close();
  });
  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (t) async {
      try {
        await body(t);
      } finally {
        if (gate != null && !gate!.isCompleted) gate!.complete();
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
        await t.pumpAndSettle();
        await t.pump(const Duration(seconds: 6));
      }
    });
  }

  Widget host(Widget page,
          {Brightness brightness = Brightness.light,
          double scale = 1,
          double width = 400}) =>
      ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            databaseProvider.overrideWithValue(db),
            currentLedgerIdProvider.overrideWith((ref) => ledger),
            activeCloudConfigProvider.overrideWith((ref) async => config),
            authServiceProvider.overrideWith((ref) async => auth),
            syncServiceProvider.overrideWithValue(engine),
            beecountCloudProviderInstance.overrideWith((ref) async => cloud),
            beecountCloudServerVersionProvider
                .overrideWith((ref) async => 'qa-1.0'),
            activeCloudRuntimeProvider.overrideWith(() => _Runtime(
                ActiveCloudRuntime(
                    config: config,
                    provider: cloud,
                    auth: auth,
                    syncService: engine,
                    syncEngine: engine,
                    identity: 'synthetic'))),
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
  Future<void> flush(WidgetTester t, {int n = 10}) async {
    for (var i = 0; i < n; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 40));
    }
  }

  Future<void> show(WidgetTester t, Widget page) async {
    await t.pumpWidget(host(page));
    await flush(t);
  }

  Future<void> tap(WidgetTester t, String text) async {
    final f = find.text(text).last;
    await t.ensureVisible(f);
    await t.tap(f);
    await flush(t);
  }

  int calls(String path, [String? method]) => requests
      .where((r) =>
          r.url.path.contains(path) && (method == null || r.method == method))
      .length;
  const invitePage =
      InvitePage(ledgerExternalId: 'book-shared', ledgerName: 'Shared book');
  const membersPage = MemberListPage(
      ledgerExternalId: 'book-shared', ledgerName: 'Shared book');
  const statsPage = MemberStatsPage(
      ledgerExternalId: 'book-shared', ledgerName: 'Shared book');

  for (final hours in [24, 72, 168]) {
    scenario('邀请保留编辑者角色与$hours小时有效期HTTP契约', (t) async {
      await show(t, invitePage);
      if (hours != 24) await tap(t, l.sharedInviteExpiryDays(hours ~/ 24));
      await tap(t, l.sharedInviteGenerate);
      expect(find.text('ABC 234'), findsOneWidget);
      final request =
          requests.singleWhere((r) => r.url.path.endsWith('/invites'));
      expect(jsonDecode(request.body),
          {'role': 'editor', 'expires_in_hours': hours});
      expect(await db.select(db.ledgers).get(), hasLength(2));
      expect(find.text(l.sharedInviteWarning), findsNothing);
      await tap(t, l.sharedInviteGenerateAnother);
      expect(find.text(l.sharedInviteWarning), findsOneWidget);
    });
  }
  scenario('邀请复制原始代码与完整链接', (t) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await show(t, invitePage);
    await tap(t, l.sharedInviteGenerate);
    await tap(t, l.sharedInviteCopyCode);
    expect(copied, 'ABC234');
    await tap(t, l.sharedInviteCopyLink);
    expect(copied, 'https://qa.invalid/i/ABC234');
  });
  scenario('生成403后保留错误并可重试', (t) async {
    failure = 403;
    failurePath = '/invites';
    await show(t, invitePage);
    await tap(t, l.sharedInviteGenerate);
    expect(find.textContaining('QA failure'), findsOneWidget);
    failure = 0;
    await tap(t, l.sharedInviteGenerate);
    expect(find.text('ABC 234'), findsOneWidget);
    expect(calls('/invites'), 2);
  });
  scenario('生成忙碌防重与退出不回滚已发请求', (t) async {
    gate = Completer();
    gatePath = '/invites';
    await show(t, invitePage);
    await tap(t, l.sharedInviteGenerate);
    await tap(t, l.sharedInviteGenerate);
    expect(calls('/invites'), 1);
    await t.pumpWidget(const SizedBox.shrink());
    gate!.complete();
    await flush(t);
    expect(t.takeException(), isNull);
    expect(calls('/invites'), 1);
  });
  scenario('无效代码不发送请求', (t) async {
    await show(t, const JoinSharedLedgerPage());
    await t.enterText(find.byType(TextField), 'ABC');
    await tap(t, l.sharedJoinPreviewButton);
    expect(find.text(l.sharedJoinCodeFormatError), findsOneWidget);
    expect(requests, isEmpty);
  });
  scenario('预填代码去空格横线且预览保留账本身份和取消', (t) async {
    await show(t, const JoinSharedLedgerPage(prefilledCode: 'abc-234'));
    expect(calls('/invites/ABC234/preview'), 1);
    expect(find.text('Shared book'), findsOneWidget);
    expect(find.text(l.sharedJoinRoleLine(l.sharedRoleEditor)), findsOneWidget);
    await tap(t, l.commonCancel);
    expect(find.byType(TextField), findsOneWidget);
    expect(calls('/accept'), 0);
  });
  scenario('预览Busy禁用输入及IME防重', (t) async {
    gate = Completer();
    gatePath = '/preview';
    await show(t, const JoinSharedLedgerPage(prefilledCode: 'ABC234'));
    expect(t.widget<TextField>(find.byType(TextField)).enabled, false);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await flush(t);
    expect(calls('/preview'), 1);
    gate!.complete();
    await flush(t);
    expect(find.text('Shared book'), findsOneWidget);
  });
  for (final row in [
    ('Already a member', 'already'),
    ('Invalid or expired', 'expired'),
    ('member limit reached', 'limit'),
    ('Server 503', 'raw')
  ]) {
    scenario('加入预览错误映射${row.$2}', (t) async {
      failure = 400;
      failurePath = '/preview';
      detail = row.$1;
      await show(t, const JoinSharedLedgerPage(prefilledCode: 'ABC234'));
      final expected = switch (row.$2) {
        'already' => l.sharedJoinAlreadyMember,
        'expired' => l.sharedJoinInvalidOrExpired,
        'limit' => l.sharedJoinMemberLimit,
        _ => 'Server 503'
      };
      expect(find.textContaining(expected), findsOneWidget);
    });
  }
  scenario('真实SQLite加入水合原共享镜像且保留另两本账', (t) async {
    await show(t, const JoinSharedLedgerPage(prefilledCode: 'ABC234'));
    await tap(t, l.sharedJoinAcceptButton);
    expect(calls('/accept'), 1);
    final ledgers = await db.select(db.ledgers).get();
    expect(ledgers, hasLength(3));
    final shared = ledgers.singleWhere((x) => x.syncId == 'book-shared');
    expect(shared.currency, 'EUR');
    expect(shared.myRole, 'editor');
    expect(shared.isShared, true);
    expect((await db.select(db.sharedLedgerCategories).get()).single.syncId,
        'shared-cat');
    expect((await db.select(db.sharedLedgerAccounts).get()).single.syncId,
        'shared-account');
    expect((await db.select(db.sharedLedgerTags).get()).single.syncId,
        'shared-tag');
    expect(await db.select(db.categories).get(), isEmpty);
    expect(await db.select(db.accounts).get(), isEmpty);
    expect(await db.select(db.tags).get(), isEmpty);
  });
  scenario('加入403不落地新账本且保留预览重试', (t) async {
    failure = 403;
    failurePath = '/accept';
    await show(t, const JoinSharedLedgerPage(prefilledCode: 'ABC234'));
    await tap(t, l.sharedJoinAcceptButton);
    expect(find.textContaining('QA failure'), findsOneWidget);
    expect(await db.select(db.ledgers).get(), hasLength(2));
    failure = 0;
    await tap(t, l.sharedJoinAcceptButton);
    expect(calls('/accept'), 2);
    expect(await db.select(db.ledgers).get(), hasLength(3));
  });
  scenario('加入忙碌重复点击只发送一次', (t) async {
    gate = Completer();
    gatePath = '/accept';
    await show(t, const JoinSharedLedgerPage(prefilledCode: 'ABC234'));
    await tap(t, l.sharedJoinAcceptButton);
    await tap(t, l.sharedJoinAcceptButton);
    expect(calls('/accept'), 1);
    await t.pumpWidget(const SizedBox.shrink());
    gate!.complete();
    await flush(t);
    expect(t.takeException(), isNull);
  });
  scenario('所有者只可移除其他编辑者且保留邀请入口', (t) async {
    await show(t, membersPage);
    expect(find.byTooltip(l.sharedMembersRemoveCta), findsOneWidget);
    expect(find.text(l.sharedMembersInviteCta), findsOneWidget);
    expect(find.text(l.sharedMembersLeaveCta), findsNothing);
    expect(find.text(l.sharedMembersTransferConfirmCta), findsNothing);
  });
  scenario('普通成员可退出不能邀请或移除', (t) async {
    selfRole = 'editor';
    await show(t, membersPage);
    expect(find.byTooltip(l.sharedMembersRemoveCta), findsNothing);
    expect(find.text(l.sharedMembersInviteCta), findsNothing);
    expect(find.text(l.sharedMembersLeaveCta), findsOneWidget);
  });
  scenario('缺失自身身份不推断所有者权限', (t) async {
    noSelf = true;
    await show(t, membersPage);
    expect(find.byTooltip(l.sharedMembersRemoveCta), findsNothing);
    expect(find.text(l.sharedMembersInviteCta), findsNothing);
    expect(find.text(l.sharedMembersLeaveCta), findsNothing);
  });
  scenario('取消移除不发送DELETE', (t) async {
    await show(t, membersPage);
    await t.tap(find.byTooltip(l.sharedMembersRemoveCta));
    await flush(t);
    expect(find.byType(BeeDialog), findsOneWidget);
    await tap(t, l.commonCancel);
    expect(calls('/members/', 'DELETE'), 0);
    expect(await db.select(db.ledgers).get(), hasLength(2));
  });
  scenario('确认移除使用远端userId并刷新名单', (t) async {
    await show(t, membersPage);
    await t.tap(find.byTooltip(l.sharedMembersRemoveCta));
    await flush(t);
    await tap(t, l.commonRemove);
    expect(calls('/members/editor-id', 'DELETE'), 1);
    expect(calls('/members', 'GET'), 2);
    expect(await db.select(db.ledgers).get(), hasLength(2));
  });
  scenario('移除失败显示原错误且可再次确认', (t) async {
    failure = 403;
    failurePath = '/members/editor-id';
    await show(t, membersPage);
    await t.tap(find.byTooltip(l.sharedMembersRemoveCta));
    await flush(t);
    await tap(t, l.commonRemove);
    expect(find.textContaining('QA failure'), findsOneWidget);
    failure = 0;
    await t.tap(find.byTooltip(l.sharedMembersRemoveCta));
    await flush(t);
    await tap(t, l.commonRemove);
    expect(calls('/members/editor-id', 'DELETE'), 2);
  });
  scenario('退出取消不发送请求', (t) async {
    selfRole = 'editor';
    await show(t, membersPage);
    await tap(t, l.sharedMembersLeaveCta);
    await tap(t, l.commonCancel);
    expect(calls('/members/', 'DELETE'), 0);
  });
  scenario('退出只删除自身远端身份', (t) async {
    selfRole = 'editor';
    await show(t, membersPage);
    await tap(t, l.sharedMembersLeaveCta);
    await tap(t, l.sharedMembersLeaveCta);
    expect(calls('/members/owner', 'DELETE'), 1);
    expect(await db.select(db.ledgers).get(), hasLength(2),
        reason: '本地移除仍由原服务端member_change事件触发，本Mock未模拟WS');
  });
  scenario('成员列表503显示重试并恢复', (t) async {
    failure = 503;
    failurePath = '/members';
    await show(t, membersPage);
    expect(find.textContaining('QA failure'), findsOneWidget);
    failure = 0;
    await tap(t, l.v4RecordingRetry);
    expect(find.text('Editor QA'), findsOneWidget);
  });
  scenario('成员邀请保留原路由参数', (t) async {
    await show(t, membersPage);
    await tap(t, l.sharedMembersInviteCta);
    expect(find.byType(InvitePage), findsOneWidget);
    final page = t.widget<InvitePage>(find.byType(InvitePage));
    expect(page.ledgerExternalId, 'book-shared');
    expect(page.ledgerName, 'Shared book');
  });
  scenario('统计保留月年全部与时区接口参数', (t) async {
    await show(t, statsPage);
    expect(find.text('x'), findsOneWidget);
    expect(find.text('+€133.5'), findsOneWidget);
    expect(find.text('-€50'), findsOneWidget);
    expect(find.text('-€20  (40%)'), findsOneWidget);
    for (final item in [
      ('year', l.analyticsYear),
      ('all', l.analyticsAll),
      ('month', l.analyticsMonth)
    ]) {
      await tap(t, item.$2);
      expect(requests.last.url.queryParameters['scope'], item.$1);
      expect(requests.last.url.queryParameters['tz_offset_minutes'],
          DateTime.now().timeZoneOffset.inMinutes.toString());
    }
    expect(find.textContaining('€'), findsWidgets);
  });
  scenario('统计空和503不显示伪零汇总', (t) async {
    emptyStats = true;
    await show(t, statsPage);
    expect(find.text(l.sharedMembersStatsEmpty), findsOneWidget);
    failure = 503;
    failurePath = '/member-stats';
    await tap(t, l.analyticsYear);
    expect(find.textContaining('QA failure'), findsOneWidget);
    failure = 0;
    emptyStats = false;
    await tap(t, l.v4RecordingRetry);
    expect(find.text('Editor QA'), findsOneWidget);
  });
  scenario('同步真实SQLite健康计数与2FA及版本', (t) async {
    await show(t, const BeeCountCloudSyncPage());
    expect(find.text(l.syncHealthInSync), findsOneWidget);
    expect(find.textContaining(l.twofaStatusEnabled), findsOneWidget);
    await t.drag(find.byType(ListView), const Offset(0, -600));
    await flush(t);
    expect(find.text('BeeCount Cloud vqa-1.0'), findsOneWidget);
    expect(calls('/read/ledgers/book-own/stats'), 1);
  });
  scenario('同步检查503保持错误可重试', (t) async {
    failure = 503;
    failurePath = '/stats';
    await show(t, const BeeCountCloudSyncPage());
    expect(find.textContaining('QA failure'), findsOneWidget);
    expect(find.text(l.syncHealthInSync), findsNothing);
    failure = 0;
    await tap(t, l.v4RecordingRetry);
    expect(find.text(l.syncHealthInSync), findsOneWidget);
  });
  scenario('2FA读取失败按原契约隐藏', (t) async {
    failure = 403;
    failurePath = '/2fa/status';
    await show(t, const BeeCountCloudSyncPage());
    expect(find.textContaining(l.twofaStatusTitle), findsNothing);
    expect(find.text(l.syncHealthInSync), findsOneWidget);
  });
  scenario('未登录不请求2FA并展示原登录入口', (t) async {
    auth.user = null;
    await show(t, const BeeCountCloudSyncPage());
    expect(calls('/2fa/status'), 0);
    expect(find.text(l.mineLoginTitle), findsOneWidget);
  });
  scenario('保存账户入口重登录并更新2FA', (t) async {
    auth.user = null;
    config = const CloudServiceConfig(
        type: CloudBackendType.beecountCloud,
        name: 'QA',
        beecountCloudBaseUrl: 'https://qa.invalid',
        beecountCloudEmail: 'synthetic@example.invalid',
        beecountCloudPassword: 'synthetic-only');
    await show(t, const BeeCountCloudSyncPage());
    await tap(t, l.cloudReloginTitle);
    expect(auth.logins, 1);
    expect(find.text('synthetic@example.invalid'), findsOneWidget);
  });
  scenario('同步刷新忙碌防重且退出不报ref失效', (t) async {
    gate = Completer();
    gatePath = '/stats';
    await show(t, const BeeCountCloudSyncPage());
    expect(calls('/stats'), 1);
    final retry = t.widget<BeeIconButton>(find.byType(BeeIconButton).first);
    expect(retry.onPressed, isNull);
    await t.pumpWidget(const SizedBox.shrink());
    gate!.complete();
    await flush(t);
    expect(t.takeException(), isNull);
  });
  scenario('无当前账本无同步或2FA请求', (t) async {
    ledger = 0;
    await show(t, const BeeCountCloudSyncPage());
    expect(find.text(l.aiOcrNoLedger), findsOneWidget);
    expect(requests, isEmpty);
  });
  scenario('加入前两本账的交易附件及用户资源保持原值', (t) async {
    final cat = await db.into(db.categories).insert(CategoriesCompanion.insert(
        name: 'Private category',
        kind: 'expense',
        syncId: const Value('own-cat')));
    final tag = await db.into(db.tags).insert(TagsCompanion.insert(
        name: 'Private tag', syncId: const Value('own-tag')));
    final account = await db.into(db.accounts).insert(AccountsCompanion.insert(
        ledgerId: ledger,
        name: 'Private account',
        currency: const Value('USD'),
        syncId: const Value('own-account')));
    final tx = await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
            ledgerId: ledger,
            type: 'expense',
            amount: 12.5,
            happenedAt: Value(DateTime.utc(2026, 10, 20)),
            categoryId: Value(cat),
            accountId: Value(account),
            note: const Value('private'),
            syncId: const Value('own-tx'),
            currencyCode: const Value('USD'),
            nativeAmount: const Value(88.0),
            excludeFromStats: const Value(true)));
    await db
        .into(db.transactionTags)
        .insert(TransactionTagsCompanion.insert(transactionId: tx, tagId: tag));
    await db.into(db.transactionAttachments).insert(
        TransactionAttachmentsCompanion.insert(
            transactionId: tx,
            fileName: 'synthetic.png',
            cloudSha256: const Value('synthetic-sha')));
    final before = (await db.select(db.transactions).get()).single;
    await show(t, const JoinSharedLedgerPage(prefilledCode: 'ABC234'));
    await tap(t, l.sharedJoinAcceptButton);
    expect((await db.select(db.transactions).get()).single, before);
    expect(
        (await db.select(db.transactionAttachments).get()).single.transactionId,
        tx);
    expect((await db.select(db.transactionTags).get()).single.tagId, tag);
    expect((await db.select(db.categories).get()).single.syncId, 'own-cat');
    expect((await db.select(db.accounts).get()).single.syncId, 'own-account');
    expect((await db.select(db.tags).get()).single.syncId, 'own-tag');
  });
  scenario('接受成功后共享资源503不伪装回滚仍保留加入成功契约', (t) async {
    failure = 503;
    failurePath = '/shared-resources';
    await show(t, const JoinSharedLedgerPage(prefilledCode: 'ABC234'));
    await tap(t, l.sharedJoinAcceptButton);
    expect(calls('/accept'), 1);
    expect(await db.select(db.ledgers).get(), hasLength(3));
    expect(await db.select(db.sharedLedgerCategories).get(), isEmpty);
    expect(cloud.pullCalls, isEmpty,
        reason: '原onInviteAccepted水合失败停止本次后续拉取，下一次同步恢复');
  });
  scenario('移除执行中关闭页面不访问已销毁ref且不重复DELETE', (t) async {
    gate = Completer();
    gatePath = '/members/editor-id';
    await show(t, membersPage);
    await t.tap(find.byTooltip(l.sharedMembersRemoveCta));
    await flush(t);
    await tap(t, l.commonRemove);
    await t.tap(find.byTooltip(l.sharedMembersRemoveCta));
    await flush(t);
    expect(calls('/members/editor-id', 'DELETE'), 1);
    await t.pumpWidget(const SizedBox.shrink());
    gate!.complete();
    await flush(t);
    expect(t.takeException(), isNull);
  });
  scenario('退出403保留页面及错误', (t) async {
    selfRole = 'editor';
    failure = 403;
    failurePath = '/members/owner';
    await show(t, membersPage);
    await tap(t, l.sharedMembersLeaveCta);
    await tap(t, l.sharedMembersLeaveCta);
    expect(find.textContaining('QA failure'), findsOneWidget);
    expect(find.byType(MemberListPage), findsOneWidget);
    expect(await db.select(db.ledgers).get(), hasLength(2));
  });
  scenario('同步当前与全部账本真实SQLite计数不混淆', (t) async {
    final other =
        (await db.select(db.ledgers).get()).singleWhere((x) => x.id != ledger);
    for (final id in [ledger, other.id]) {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: id,
          type: 'expense',
          amount: 8,
          happenedAt: Value(DateTime.utc(2026, 10, 20)),
          syncId: Value('count-$id')));
    }
    healthStats = {'transaction_count': 1, 'transaction_total': 2};
    await show(t, const BeeCountCloudSyncPage());
    expect(find.text(l.syncHealthValue(1, 1)), findsOneWidget);
    expect(find.text(l.syncHealthValue(2, 2)), findsOneWidget);
    expect(find.text(l.syncHealthInSync), findsOneWidget);
    expect(await db.select(db.transactions).get(), hasLength(2));
  });
  scenario('同步返回错误结果也显示失败并可重试', (t) async {
    healthStats = {'transaction_count': 1, 'transaction_total': 1};
    cloud.pushFakeLedgerSnapshot(ledgerId: 'book-own');
    cloud.pullErrorInjector = (_) => Exception('QA pull failed');
    await show(t, const BeeCountCloudSyncPage());
    expect(find.textContaining('QA pull failed'), findsWidgets);
    expect(find.text(l.syncHealthInSync), findsNothing);
    healthStats = {};
    cloud.pullErrorInjector = null;
    await tap(t, l.v4RecordingRetry);
    expect(find.text(l.syncHealthInSync), findsOneWidget);
  });
  scenario('重新登录失败保留重试入口', (t) async {
    auth.user = null;
    auth.loginError = StateError('QA login failed');
    config = const CloudServiceConfig(
        type: CloudBackendType.beecountCloud,
        name: 'QA',
        beecountCloudEmail: 'qa@example.invalid',
        beecountCloudPassword: 'synthetic');
    await show(t, const BeeCountCloudSyncPage());
    await tap(t, l.cloudReloginTitle);
    expect(find.textContaining('QA login failed'), findsOneWidget);
    expect(auth.logins, 1);
    auth.loginError = null;
    await tap(t, l.cloudReloginTitle);
    expect(auth.logins, 2);
  });
  scenario('页面重绘不重复查询账户，保留完整同步说明', (t) async {
    await show(t, const BeeCountCloudSyncPage());
    final count = auth.reads;
    await t.drag(find.byType(ListView), const Offset(0, -500));
    await flush(t);
    await tap(t, l.cloudSyncHelpTitle);
    expect(auth.reads, count);
    expect(find.text(l.cloudSyncHelpModesBody), findsOneWidget);
    expect(find.text(l.cloudSyncHelpWhenFullBody), findsOneWidget);
    expect(find.text(l.cloudSyncHelpStuckBody), findsOneWidget);
    expect(find.text(l.cloudSyncHelpTroubleshootBody), findsOneWidget);
  });
  scenario('加入重放历史保留共享引用归属币种且重复同步幂等', (t) async {
    cloud.pushFakeChange(
        entitySyncId: 'history-tx',
        ledgerId: 'book-shared',
        entityType: 'transaction',
        payload: {
          'type': 'expense',
          'amount': 12.5,
          'nativeAmount': 10.0,
          'currencyCode': 'USD',
          'happenedAt': '2026-09-20T10:00:00Z',
          'note': 'historic',
          'categoryId': 'shared-cat',
          'accountId': 'shared-account',
          'tagIds': ['shared-tag'],
          'createdByUserId': 'remote-owner',
          'excludeFromStats': true,
          'excludeFromBudget': true
        });
    await show(t, const JoinSharedLedgerPage(prefilledCode: 'ABC234'));
    await tap(t, l.sharedJoinAcceptButton);
    final row = (await db.select(db.transactions).get()).single;
    expect(row.syncId, 'history-tx');
    expect(row.amount, 12.5);
    expect(row.nativeAmount, 10.0);
    expect(row.currencyCode, 'USD');
    expect(row.createdByUserId, 'remote-owner');
    expect(row.excludeFromStats, true);
    expect(row.excludeFromBudget, true);
    expect(row.categoryId, isNull);
    expect(row.accountId, isNull);
    expect(row.categorySyncIdOverride, 'shared-cat');
    expect(row.accountSyncIdOverride, 'shared-account');
    expect(row.tagSyncIdsOverride, isNull);
    final tags = await db.select(db.transactionTagOverrides).get();
    expect(tags.single.transactionSyncId, 'history-tx');
    expect(tags.single.tagSyncId, 'shared-tag');
    await t.runAsync(() => engine.onInviteAccepted('book-shared'));
    await flush(t);
    expect(await db.select(db.transactions).get(), hasLength(1));
    expect(await db.select(db.sharedLedgerTags).get(), hasLength(1));
    expect(await db.select(db.transactionTagOverrides).get(), hasLength(1));
    expect(await db.select(db.tags).get(), isEmpty);
  });
  scenario('账户查询异常显式显示重试且不伪装已登录', (t) async {
    auth.readError = StateError('QA auth unavailable');
    await show(t, const BeeCountCloudSyncPage());
    expect(find.textContaining('QA auth unavailable'), findsOneWidget);
    auth.readError = null;
    await tap(t, l.v4RecordingRetry);
    expect(find.text('qa@example.invalid'), findsOneWidget);
  });
  scenario('画廊实际本地镜像预览读取真实SQLite且零HTTP请求', (t) async {
    await db.customStatement(
        "INSERT INTO shared_ledger_tags(ledger_sync_id,sync_id,name,updated_at) VALUES('book-own','preview-tag','Preview',1792454400)");
    await show(t, const Scaffold(body: CloudSharedPreview()));
    expect(find.text('Own book'), findsOneWidget);
    expect(find.text(l.syncHealthValueRemoteMissing(1)), findsOneWidget);
    expect(requests, isEmpty);
  });
  for (final page in [
    invitePage,
    const JoinSharedLedgerPage(),
    const JoinSharedLedgerPage(prefilledCode: 'ABC234'),
    membersPage,
    statsPage,
    const BeeCountCloudSyncPage()
  ]) {
    scenario('窄屏大字体${page.runtimeType}保留完整内容无溢出', (t) async {
      t.view.physicalSize = const Size(360, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(host(page, scale: 1.5));
      await flush(t);
      FocusManager.instance.primaryFocus?.unfocus();
      await flush(t);
      await t.drag(find.byType(ListView).first, const Offset(0, -500));
      await flush(t);
      expect(t.takeException(), isNull);
    });
  }
  for (final brightness in Brightness.values) {
    scenario('纯共享组件与局部样例${brightness.name}大字体无网络', (t) async {
      await t.pumpWidget(MaterialApp(
          theme: beeTheme(brightness: brightness),
          home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
              child: const Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: EdgeInsets.all(17),
                          child: CloudSharedSample()))))));
      await t.pumpAndSettle();
      expect(requests, isEmpty);
      expect(find.byType(BeeCloudSharedInviteForm), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
