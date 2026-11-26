import 'dart:convert';
import 'dart:io';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '_fakes/fake_beecount_cloud_provider.dart';

class _Auth extends FakeBeeCountCloudAuthService {
  @override
  Future<String> requireAccessToken() async => 'qa';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  late HttpServer server;
  late BeeCountCloudStorageService storage;
  late List<(String, Uri)> requests;
  var closedConnections = 0;
  var httpStatus = 200;

  setUp(() async {
    requests = [];
    closedConnections = 0;
    httpStatus = 200;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final auth = _Auth();
    storage = BeeCountCloudStorageService(
      baseUrl: 'http://127.0.0.1:${server.port}/self-hosted',
      apiPrefix: '/api/v1',
      auth: auth,
    );
    addTearDown(auth.dispose);
    addTearDown(storage.dispose);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      requests.add((request.method, request.uri));
      if (requests.length <= closedConnections) {
        // The request arrived but the peer closed before writing any HTTP header.
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.destroy();
        return;
      }
      request.response.statusCode = httpStatus;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'server_cursor': 18,
        'has_more': false,
        'changes': [
          {
            'change_id': 18,
            'ledger_id': 'ledger',
            'entity_type': 'transaction',
            'entity_sync_id': 'item',
            'action': 'upsert',
            'payload': {'amount': 28.50},
          }
        ],
      }));
      await request.response.close();
    });
  });

  Future<BeeCountCloudPullResult> pull() => storage.pullChanges(
      since: 17, limit: 500, restoring: true, persistCursor: false);

  test('a dropped pull connection retries the exact page once', () async {
    closedConnections = 1;
    final result = await pull();
    expect(result.serverCursor, 18);
    expect(result.changes.map((c) => c.entitySyncId), ['item']);
    expect(requests, hasLength(2));
    expect(requests.first, requests.last);
    expect(requests.first.$1, 'GET');
    expect(requests.first.$2.path, '/self-hosted/api/v1/sync/pull');
    expect(requests.first.$2.queryParameters, {
      'since': '17',
      'limit': '500',
      'restore_device_id': 'test-device-id',
    });
  });

  test('a second dropped connection reaches the caller', () async {
    closedConnections = 10;
    await expectLater(pull(), throwsA(isA<http.ClientException>()));
    expect(requests, hasLength(2));
  });

  test('an HTTP error is returned without replaying the pull', () async {
    httpStatus = 503;
    await expectLater(pull(), throwsA(isA<CloudStorageException>()));
    expect(requests, hasLength(1));
  });

  test('a disconnected POST push is sent only once', () async {
    closedConnections = 1;
    await expectLater(
        storage.pushEntityChanges(changes: [
          {
            'ledger_id': 'ledger',
            'entity_type': 'transaction',
            'entity_sync_id': 'item',
            'action': 'upsert',
            'payload': {'amount': 28.50}
          }
        ]),
        throwsA(isA<http.ClientException>()));
    expect(requests.map((v) => v.$1), ['POST']);
  });
}
