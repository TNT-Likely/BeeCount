import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FixtureCloud {
  FixtureCloud._(this.origin, this.identity, this._email, this._password);
  final Uri origin;
  final Map<String, dynamic> identity;
  final String _email, _password;
  late String _webToken;

  CloudServiceConfig get config => CloudServiceConfig(
      type: CloudBackendType.beecountCloud,
      name: 'QA',
      beecountCloudBaseUrl: origin.toString(),
      beecountCloudEmail: _email,
      beecountCloudPassword: _password);

  static Future<FixtureCloud> create(String scenario) async {
    final origin = Uri.parse(Platform.environment['CLOUD_SYNC_QA_URL'] ??
        const String.fromEnvironment('CLOUD_SYNC_QA_URL'));
    if (origin.scheme != 'http' ||
        origin.host != '127.0.0.1' ||
        origin.userInfo.isNotEmpty ||
        origin.path.length > 1) {
      throw StateError('Use the isolated BeeCount QA loopback service.');
    }
    final response = await http
        .get(origin.resolve('/__qa__/identity'))
        .timeout(const Duration(seconds: 10));
    final identity =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final expected = Platform.environment['CLOUD_SYNC_QA_CLOUD_SHA'];
    if (response.statusCode != 200 ||
        identity['database_is_isolated'] != true ||
        !RegExp(r'^beecount-qa-')
            .hasMatch(identity['run_id']?.toString() ?? '') ||
        (expected != null && identity['cloud_sha'] != expected)) {
      throw StateError('QA identity or Cloud revision mismatch.');
    }
    final salt = List.generate(18, (_) => Random.secure().nextInt(256));
    final q = FixtureCloud._(
        origin,
        identity,
        '$scenario-${DateTime.now().microsecondsSinceEpoch}@qa.example.com',
        base64UrlEncode(salt));
    final registration = await q._session(true);
    await registration.dispose();
    final result = await q._http('POST', '/api/v1/auth/login', body: {
      'email': q._email,
      'password': q._password,
      'client_type': 'web',
      'device_name': 'Synthetic QA observer'
    });
    q._webToken = result['access_token'];
    return q;
  }

  Future<BeeCountCloudProvider> _session(bool fresh) async {
    // A host-side test gives each simulated device its own preference store.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final provider = BeeCountCloudProvider();
    await provider.initialize({'baseUrl': origin.toString()});
    if (fresh) {
      await provider.auth.signUpWithEmail(email: _email, password: _password);
    } else {
      await provider.auth.signInWithEmail(email: _email, password: _password);
    }
    return provider;
  }

  Future<FixtureDevice> device() async => FixtureDevice(await _session(false));

  Future<dynamic> get(String path) => _http('GET', path, token: _webToken);

  Future<dynamic> _http(String method, String path,
      {String? token, Map<String, dynamic>? body}) async {
    if (!path.startsWith('/api/v1/')) throw ArgumentError.value(path, 'path');
    final req = http.Request(method, origin.resolve(path));
    if (token != null) req.headers['authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final res = await http.Response.fromStream(await req.send())
        .timeout(const Duration(seconds: 45));
    if (res.statusCode < 200 || res.statusCode > 299) {
      throw StateError('$method ${req.url.path} returned ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<({int cursor, List<Map<String, dynamic>> events})> eventsAfter(
      int cursor) async {
    final events = <Map<String, dynamic>>[];
    var after = cursor;
    while (true) {
      final page = await get('/api/v1/sync/pull?since=$after&limit=500');
      final batch = (page['changes'] as List).cast<Map<String, dynamic>>();
      final next = page['server_cursor'] as int;
      for (final row in batch) {
        final id = row['change_id'] as int;
        if (id <= after) throw StateError('Change order $id after $after');
        after = id;
      }
      events.addAll(batch);
      if (page['has_more'] != true) return (cursor: next, events: events);
      if (batch.isEmpty || next < after) {
        throw StateError('Pagination failed to advance');
      }
      after = next;
    }
  }
}

class FixtureDevice {
  FixtureDevice(this.provider);
  final BeeCountCloudProvider provider;
  final db = BeeDatabase.forTesting(NativeDatabase.memory());
  late final tracker = ChangeTracker(db);
  late final repo = LocalRepository(db, changeTracker: tracker);
  late final engine = SyncEngine(
      db: db, repo: repo, changeTracker: tracker, provider: provider);

  Future<int> ledger(String syncId) async =>
      (await (db.select(db.ledgers)..where((l) => l.syncId.equals(syncId)))
              .getSingle())
          .id;

  Future<void> close() async {
    await engine.dispose();
    await provider.dispose();
    await db.close();
  }
}
