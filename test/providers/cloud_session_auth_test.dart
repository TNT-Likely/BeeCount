import 'dart:convert';

import 'package:beecount/cloud/cloud_session_manager.dart';
import 'package:beecount/providers/sync_providers.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../cloud/sync/_fakes/fake_beecount_cloud_provider.dart';

class AuthProvider extends FakeBeeCountCloudProvider {
  AuthProvider(this.sessionAuth);
  final BeeCountCloudAuthService sessionAuth;
  @override
  CloudAuthService get auth => sessionAuth;
  @override
  Future<void> dispose() async => sessionAuth.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'test',
        packageName: 'test',
        version: '1',
        buildNumber: '1',
        buildSignature: 'test');
  });

  Map<String, dynamic> tokens(String user) => {
        'user': {'id': user, 'email': '$user@example.com'},
        'access_token': 'test-access',
        'refresh_token': 'test-refresh',
        'expires_in': 3600,
        'device_id': 'test-device',
      };

  test('UI initialized before 2FA sees login immediately without invalidation',
      () async {
    final requests = <String>[];
    final auth = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        requests.add(request.url.path);
        return http.Response(
            jsonEncode(request.url.path.endsWith('/login')
                ? {'requires_2fa': true, 'challenge_token': 'test-challenge'}
                : tokens('owner')),
            200);
      }),
      twoFactorHandler: (challenge) async =>
          await challenge.verify('totp', '123456') == null,
    );
    final provider = AuthProvider(auth);
    final manager = CloudSessionManager(
        factory: (_) async => (provider: provider, auth: auth));
    final container = ProviderContainer(overrides: [
      cloudSessionManagerProvider.overrideWithValue(manager),
      activeCloudConfigProvider.overrideWith((ref) async =>
          const CloudServiceConfig(
              type: CloudBackendType.beecountCloud,
              name: 'test',
              beecountCloudBaseUrl: 'https://cloud.example')),
    ]);
    addTearDown(() async {
      container.dispose();
      await manager.dispose();
    });
    final uiAuth = await container.read(authServiceProvider.future);
    expect(await uiAuth.currentUser, isNull);
    final cloud = await container.read(beecountCloudProviderInstance.future);
    await cloud!.auth
        .signInWithEmail(email: 'owner@example.com', password: 'test');
    expect((await uiAuth.currentUser)?.id, 'owner');
    container.invalidate(authServiceProvider);
    container.invalidate(beecountCloudProviderInstance);
    final rebuilt = await container.read(authServiceProvider.future);
    expect((await rebuilt.currentUser)?.id, 'owner');
    expect(requests, ['/api/v1/auth/login', '/api/v1/auth/2fa/verify']);
  });

  test('temporary BeeCount auth neither reads nor overwrites persisted session',
      () async {
    BeeCountCloudAuthService makeAuth(bool persist, String user) =>
        BeeCountCloudAuthService(
          baseUrl: 'https://cloud.example',
          apiPrefix: '/api/v1',
          persistSession: persist,
          httpClient: MockClient(
              (_) async => http.Response(jsonEncode(tokens(user)), 200)),
        );
    final active = makeAuth(true, 'owner');
    final draft = makeAuth(false, 'draft');
    addTearDown(active.dispose);
    addTearDown(draft.dispose);
    await active.signInWithEmail(email: 'owner@example.com', password: 'test');
    final prefs = await SharedPreferences.getInstance();
    final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
    await draft.initialize();
    expect(await draft.currentUser, isNull);
    await draft.signInWithEmail(email: 'draft@example.com', password: 'test');
    expect((await draft.currentUser)?.id, 'draft');
    expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
    expect((await active.currentUser)?.id, 'owner');
    final otherAccount = makeAuth(true, 'draft');
    final sameAccount = makeAuth(true, 'owner');
    addTearDown(otherAccount.dispose);
    addTearDown(sameAccount.dispose);
    await otherAccount.initialize(expectedEmail: 'draft@example.com');
    expect(await otherAccount.currentUser, isNull);
    await sameAccount.initialize(expectedEmail: ' OWNER@example.com ');
    expect((await sameAccount.currentUser)?.id, 'owner');
    expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
  });
}
