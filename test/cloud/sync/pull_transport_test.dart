import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/native.dart';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes/fake_beecount_cloud_provider.dart';

class _Auth extends FakeBeeCountCloudAuthService {
  @override
  Future<String> requireAccessToken() async => 'qa';
}

class _PullProvider extends FakeBeeCountCloudProvider {
  _PullProvider(this.transport);
  final BeeCountCloudStorageService transport;
  @override
  Future<BeeCountCloudPullResult> pullChanges(
          {int? since, int limit = 1000, bool persistCursor = true}) =>
      transport.pullChanges(
          since: since, limit: limit, persistCursor: persistCursor);

  @override
  Future<BeeCountCloudPullResult> pullRestorePage(
          {required int since, required int limit}) =>
      transport.pullChanges(
          since: since, limit: limit, restoring: true, persistCursor: false);
}

Future<void> _disconnect(HttpRequest request,
    {required bool reset, int? partialStatus}) async {
  final socket = await request.response.detachSocket(writeHeaders: false);
  if (partialStatus != null) {
    socket.write(
        'HTTP/1.1 $partialStatus Partial\r\nContent-Length: 512\r\nContent-Type: application/json\r\n\r\n{"server_cursor":999');
    await socket.flush();
    // Give the reader the status and a partial body before the socket closes.
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
  if (reset) {
    // A zero SO_LINGER forces a TCP RST instead of a normal FIN on close.
    final linger = ByteData(Platform.isWindows ? 4 : 8);
    if (Platform.isWindows) {
      linger.setUint16(0, 1, Endian.host);
    } else {
      linger.setInt32(0, 1, Endian.host);
    }
    final soLinger = Platform.isLinux || Platform.isAndroid ? 13 : 0x80;
    socket.setRawOption(RawSocketOption(
        RawSocketOption.levelSocket, soLinger, linger.buffer.asUint8List()));
  }
  socket.destroy();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  late HttpServer server;
  late BeeCountCloudStorageService storage;
  late List<(String, Uri)> requests;
  var closedConnections = 0;
  var httpStatus = 200;
  var reset = false;
  int? partialStatus;
  var twoPages = false;
  int? emptyCursor;
  late List<int> ports;
  Future<void> Function()? observeSecondPage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    requests = [];
    ports = [];
    reset = false;
    twoPages = false;
    emptyCursor = null;
    partialStatus = null;
    observeSecondPage = null;
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
      ports.add(request.connectionInfo!.remotePort);
      final secondPage = request.uri.queryParameters['since'] == '17';
      if (secondPage && observeSecondPage != null) await observeSecondPage!();
      if ((!twoPages || secondPage) && closedConnections > 0) {
        closedConnections--;
        await _disconnect(request, reset: reset, partialStatus: partialStatus);
        return;
      }
      request.response.statusCode = httpStatus;
      request.response.headers.contentType = ContentType.json;
      if (emptyCursor != null) {
        request.response.write(jsonEncode(
            {'changes': [], 'server_cursor': emptyCursor, 'has_more': false}));
        await request.response.close();
        return;
      }
      request.response.write(jsonEncode({
        'server_cursor': twoPages && !secondPage ? 17 : 18,
        'has_more': twoPages && !secondPage,
        'changes': [
          {
            'change_id': twoPages && !secondPage ? 17 : 18,
            'ledger_id': twoPages ? '__user_global__' : 'ledger',
            'entity_type': twoPages ? 'tag' : 'transaction',
            'entity_sync_id': twoPages && !secondPage ? 'first-tag' : 'item',
            'action': 'upsert',
            'payload': twoPages
                ? {'name': secondPage ? 'second' : 'first'}
                : {'amount': 28.50},
          }
        ],
      }));
      await request.response.close();
    });
  });

  Future<BeeCountCloudPullResult> pull() => storage.pullChanges(
      since: 17, limit: 500, restoring: true, persistCursor: false);

  (BeeDatabase, SyncEngine) openEngine() {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tracker = ChangeTracker(db);
    final engine = SyncEngine(
        db: db,
        changeTracker: tracker,
        repo: LocalRepository(db, changeTracker: tracker),
        provider: _PullProvider(storage));
    addTearDown(engine.dispose);
    return (db, engine);
  }

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

  test('a TCP reset retries the identical restore GET on a fresh socket',
      () async {
    reset = true;
    closedConnections = 1;
    final result = await pull();
    expect(result.changes.single.changeId, 18);
    expect(requests, hasLength(2));
    expect(requests[1], requests[0]);
    expect(ports[1], isNot(ports[0]));
  });

  test('a partial HTTP 200 body is discarded before re-reading the same page',
      () async {
    partialStatus = 200;
    reset = true;
    closedConnections = 1;
    final result = await pull();
    expect(result.serverCursor, 18);
    expect(result.changes.map((c) => c.changeId), [18]);
    expect(requests, hasLength(2));
    expect(requests[1], requests[0]);
  });

  test('two resets keep the applied restore page until a normal pull resumes',
      () async {
    final (db, engine) = openEngine();
    final observed = <int>[];
    twoPages = true;
    reset = true;
    closedConnections = 2;
    observeSecondPage = () async => observed.add(await engine.appCursor.read());
    await expectLater(engine.pull(''), throwsA(isA<http.ClientException>()));
    expect(await engine.appCursor.read(), 17);
    expect((await db.select(db.tags).get()).map((t) => t.name), ['first']);
    expect(
        requests.map((r) => r.$2.queryParameters['since']), ['0', '17', '17']);
    expect(await engine.pull(''), 1);
    expect(await engine.appCursor.read(), 18);
    expect((await db.select(db.tags).get()).map((t) => t.name),
        ['first', 'second']);
    expect(observed, [17, 17, 17]);
    expect(requests.last, requests[1]);
    expect(requests.last.$2.queryParameters['restore_device_id'],
        'test-device-id');
  });

  test('an empty final probe at cursor 50054 survives a TCP reset', () async {
    final (_, engine) = openEngine();
    const finalCursor = 50054;
    await engine.appCursor.commit(finalCursor);
    emptyCursor = finalCursor;
    reset = true;
    closedConnections = 1;
    expect(await engine.pull(''), 0);
    expect(requests, hasLength(2));
    expect(requests.first, requests.last);
    expect(requests.first.$2.queryParameters, {
      'since': '$finalCursor',
      'limit': '500',
      'device_id': 'test-device-id',
    });
    expect(await engine.appCursor.read(), finalCursor);
  });

  test('a partial HTTP error body does not trigger a page retry', () async {
    partialStatus = 503;
    reset = true;
    closedConnections = 1;
    await expectLater(pull(), throwsA(isA<Exception>()));
    expect(requests, hasLength(1));
  });

  test('an HTTP 422 is reported with one request', () async {
    httpStatus = 422;
    await expectLater(pull(), throwsA(isA<CloudStorageException>()));
    expect(requests, hasLength(1));
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
