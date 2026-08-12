import 'dart:async';
import 'dart:convert';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _sessionPayload({
  required String accessToken,
  required String refreshToken,
}) {
  return {
    'user': {'id': 'user-1', 'email': 'user@example.com'},
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_in': 3600,
    'device_id': 'device-1',
  };
}

http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('reloads a 2FA session persisted by another auth instance', () async {
    var silentLoginRequests = 0;
    final stale = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          silentLoginRequests++;
          return _jsonResponse({
            'requires_2fa': true,
            'challenge_token': 'challenge-stale',
            'available_methods': ['totp'],
          });
        }
        return _jsonResponse({'error': 'unexpected request'}, status: 500);
      }),
    );
    await stale.initialize();
    stale.setRecoveryCredentials(
      email: 'user@example.com',
      password: 'secret',
    );

    final interactive = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return _jsonResponse({
            'requires_2fa': true,
            'challenge_token': 'challenge-1',
            'available_methods': ['totp'],
          });
        }
        if (request.url.path.endsWith('/auth/2fa/verify')) {
          return _jsonResponse(_sessionPayload(
            accessToken: 'access-1',
            refreshToken: 'refresh-1',
          ));
        }
        return _jsonResponse({'error': 'unexpected request'}, status: 500);
      }),
      twoFactorHandler: (challenge) async {
        final error = await challenge.verify('totp', '123456');
        expect(error, isNull);
        return true;
      },
    );
    await interactive.initialize();

    addTearDown(stale.dispose);
    addTearDown(interactive.dispose);

    await interactive.signInWithEmail(
      email: 'user@example.com',
      password: 'secret',
    );

    expect(await stale.requireAccessToken(), 'access-1');
    expect(silentLoginRequests, 0,
        reason: 'persisted 2FA session should win over silent password login');
  });

  test('stale refresh failure cannot delete a newer rotated session', () async {
    final seed = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        return _jsonResponse(_sessionPayload(
          accessToken: 'access-0',
          refreshToken: 'refresh-0',
        ));
      }),
    );
    await seed.initialize();
    await seed.signInWithEmail(
      email: 'user@example.com',
      password: 'secret',
    );

    final staleRequestStarted = Completer<void>();
    final releaseStaleRequest = Completer<void>();
    final winner = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('/auth/refresh'));
        return _jsonResponse(_sessionPayload(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
        ));
      }),
    );
    final stale = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('/auth/refresh'));
        staleRequestStarted.complete();
        await releaseStaleRequest.future;
        return _jsonResponse({'error': 'refresh token revoked'}, status: 401);
      }),
    );
    await winner.initialize();
    await stale.initialize();

    addTearDown(seed.dispose);
    addTearDown(winner.dispose);
    addTearDown(stale.dispose);

    final staleRefresh = stale.tryRefreshSession();
    await staleRequestStarted.future;
    expect(await winner.tryRefreshSession(), isTrue);
    releaseStaleRequest.complete();
    expect(await staleRefresh, isTrue,
        reason: 'stale instance should adopt the newer persisted session');
    expect(await stale.requireAccessToken(), 'access-1');

    final restored = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        fail('restoring a valid session must not call the server');
      }),
    );
    await restored.initialize();
    addTearDown(restored.dispose);

    expect(await restored.requireAccessToken(), 'access-1');
  });

  test('empty stale instance adopts persisted session before refresh', () async {
    final stale = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('/auth/refresh'));
        return _jsonResponse(_sessionPayload(
          accessToken: 'access-2',
          refreshToken: 'refresh-2',
        ));
      }),
    );
    await stale.initialize();

    final interactive = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        return _jsonResponse(_sessionPayload(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
        ));
      }),
    );
    await interactive.initialize();
    await interactive.signInWithEmail(
      email: 'user@example.com',
      password: 'secret',
    );

    addTearDown(stale.dispose);
    addTearDown(interactive.dispose);

    expect(await stale.tryRefreshSession(), isTrue);
    expect(await stale.requireAccessToken(), 'access-2');
  });

  test('stale instance adopts a different account', () async {
    final stale = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        return _jsonResponse({
          'user': {'id': 'user-1', 'email': 'a@example.com'},
          'access_token': 'access-a',
          'refresh_token': 'refresh-a',
          'expires_in': 3600,
          'device_id': 'device-1',
        });
      }),
    );
    await stale.initialize();
    stale.setRecoveryCredentials(email: 'a@example.com', password: 'secret-a');
    await stale.signInWithEmail(email: 'a@example.com', password: 'secret-a');

    final accountB = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        return _jsonResponse({
          'user': {'id': 'user-2', 'email': 'b@example.com'},
          'access_token': 'access-b',
          'refresh_token': 'refresh-b',
          'expires_in': 3600,
          'device_id': 'device-2',
        });
      }),
    );
    await accountB.initialize();
    await accountB.signInWithEmail(email: 'b@example.com', password: 'secret-b');

    addTearDown(stale.dispose);
    addTearDown(accountB.dispose);

    expect(await stale.requireAccessToken(), 'access-b');
    expect((await stale.currentUser)?.email, 'b@example.com');
  });

  test('successful stale refresh cannot overwrite a newer account', () async {
    final requestStarted = Completer<void>();
    final releaseRequest = Completer<void>();
    final stale = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return _jsonResponse({
            'user': {'id': 'user-1', 'email': 'a@example.com'},
            'access_token': 'access-a',
            'refresh_token': 'refresh-a',
            'expires_in': 3600,
            'device_id': 'device-1',
          });
        }
        requestStarted.complete();
        await releaseRequest.future;
        return _jsonResponse({
          'user': {'id': 'user-1', 'email': 'a@example.com'},
          'access_token': 'access-a2',
          'refresh_token': 'refresh-a2',
          'expires_in': 3600,
          'device_id': 'device-1',
        });
      }),
    );
    await stale.initialize();
    await stale.signInWithEmail(email: 'a@example.com', password: 'secret-a');

    final refresh = stale.tryRefreshSession();
    await requestStarted.future;

    final accountB = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        return _jsonResponse({
          'user': {'id': 'user-2', 'email': 'b@example.com'},
          'access_token': 'access-b',
          'refresh_token': 'refresh-b',
          'expires_in': 3600,
          'device_id': 'device-2',
        });
      }),
    );
    await accountB.initialize();
    await accountB.signInWithEmail(email: 'b@example.com', password: 'secret-b');
    releaseRequest.complete();

    addTearDown(stale.dispose);
    addTearDown(accountB.dispose);

    expect(await refresh, isTrue);
    expect(await stale.requireAccessToken(), 'access-b');
  });

  test('logout clears a stale instance session', () async {
    final owner = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return _jsonResponse(_sessionPayload(
            accessToken: 'access-1',
            refreshToken: 'refresh-1',
          ));
        }
        expect(request.url.path, endsWith('/auth/logout'));
        return _jsonResponse({});
      }),
    );
    await owner.initialize();
    await owner.signInWithEmail(email: 'user@example.com', password: 'secret');

    final stale = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        fail('stale instance must not call the server after logout');
      }),
    );
    await stale.initialize();
    await owner.signOut();

    addTearDown(owner.dispose);
    addTearDown(stale.dispose);

    await expectLater(
      stale.requireAccessToken(),
      throwsA(isA<CloudNotAuthenticatedException>()),
    );
  });

  test('stale instance signs out the newest rotated session', () async {
    final seed = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        return _jsonResponse(_sessionPayload(
          accessToken: 'access-0',
          refreshToken: 'refresh-0',
        ));
      }),
    );
    await seed.initialize();
    await seed.signInWithEmail(email: 'user@example.com', password: 'secret');

    String? loggedOutRefreshToken;
    final stale = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        loggedOutRefreshToken = body['refresh_token'] as String?;
        return _jsonResponse({});
      }),
    );
    final winner = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        return _jsonResponse(_sessionPayload(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
        ));
      }),
    );
    await stale.initialize();
    await winner.initialize();
    await winner.tryRefreshSession();

    addTearDown(seed.dispose);
    addTearDown(stale.dispose);
    addTearDown(winner.dispose);

    await stale.signOut();
    expect(loggedOutRefreshToken, 'refresh-1');
    await expectLater(
      winner.requireAccessToken(),
      throwsA(isA<CloudNotAuthenticatedException>()),
    );
  });

  test('logout tombstone survives provider rebuild and blocks silent recovery',
      () async {
    final owner = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return _jsonResponse(_sessionPayload(
            accessToken: 'access-1',
            refreshToken: 'refresh-1',
          ));
        }
        return _jsonResponse({});
      }),
    );
    await owner.initialize();
    await owner.signInWithEmail(email: 'user@example.com', password: 'secret');
    await owner.signOut();

    var silentLoginRequests = 0;
    final rebuilt = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        silentLoginRequests++;
        return _jsonResponse(_sessionPayload(
          accessToken: 'unexpected',
          refreshToken: 'unexpected',
        ));
      }),
    );
    await rebuilt.initialize();
    rebuilt.setRecoveryCredentials(
      email: 'user@example.com',
      password: 'secret',
    );

    addTearDown(owner.dispose);
    addTearDown(rebuilt.dispose);

    expect(await rebuilt.currentUser, isNull);
    expect(silentLoginRequests, 0);

    await rebuilt.signInWithEmail(email: 'user@example.com', password: 'secret');
    expect(await rebuilt.requireAccessToken(), 'unexpected');
    expect(silentLoginRequests, 1);
  });

  test('refresh completing during logout cannot resurrect the session',
      () async {
    final seed = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        return _jsonResponse(_sessionPayload(
          accessToken: 'access-0',
          refreshToken: 'refresh-0',
        ));
      }),
    );
    await seed.initialize();
    await seed.signInWithEmail(email: 'user@example.com', password: 'secret');

    final refreshStarted = Completer<void>();
    final releaseRefresh = Completer<void>();
    final refresher = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        refreshStarted.complete();
        await releaseRefresh.future;
        return _jsonResponse(_sessionPayload(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
        ));
      }),
    );
    await refresher.initialize();

    final logoutStarted = Completer<void>();
    final releaseLogout = Completer<void>();
    final logout = BeeCountCloudAuthService(
      baseUrl: 'https://cloud.example.com',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        logoutStarted.complete();
        await releaseLogout.future;
        return _jsonResponse({});
      }),
    );
    await logout.initialize();

    addTearDown(seed.dispose);
    addTearDown(refresher.dispose);
    addTearDown(logout.dispose);

    final refresh = refresher.tryRefreshSession();
    await refreshStarted.future;
    final signOut = logout.signOut();
    await logoutStarted.future;
    releaseRefresh.complete();
    expect(await refresh, isFalse);
    releaseLogout.complete();
    await signOut;

    await expectLater(
      refresher.requireAccessToken(),
      throwsA(isA<CloudNotAuthenticatedException>()),
    );
  });
}
