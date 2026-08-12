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
        return _jsonResponse({'error': 'refresh token revoked'}, status: 401);
      }),
    );
    await winner.initialize();
    await stale.initialize();

    addTearDown(seed.dispose);
    addTearDown(winner.dispose);
    addTearDown(stale.dispose);

    expect(await winner.tryRefreshSession(), isTrue);
    expect(await stale.tryRefreshSession(), isTrue,
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
}
