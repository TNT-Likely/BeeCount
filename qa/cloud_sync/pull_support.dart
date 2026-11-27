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

typedef Json = Map<String, dynamic>;

void resetPullHostPreferences() {
  // These host-only tests live outside test/ to keep offline discovery separate.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
}

class PullEnvironment {
  final String origin = Platform.environment['CLOUD_SYNC_QA_URL'] ??
      const String.fromEnvironment('CLOUD_SYNC_QA_URL');
  final String output = Platform.environment['CLOUD_SYNC_QA_OUTPUT'] ??
      const String.fromEnvironment('CLOUD_SYNC_QA_OUTPUT');
  final int seed = int.parse(Platform.environment['CLOUD_SYNC_QA_SEED'] ??
      const String.fromEnvironment('CLOUD_SYNC_QA_SEED',
          defaultValue: '20261126'));
  final int transactionCount = int.parse(
      Platform.environment['CLOUD_SYNC_QA_TRANSACTIONS'] ??
          const String.fromEnvironment('CLOUD_SYNC_QA_TRANSACTIONS',
              defaultValue: '1200'));

  Future<void> save(String caseName, Json data) async {
    if (output.isEmpty) {
      throw StateError('Set CLOUD_SYNC_QA_OUTPUT to an evidence directory');
    }
    final dir = await Directory(output).create(recursive: true);
    await File('${dir.path}/$caseName.json')
        .writeAsString('${const JsonEncoder.withIndent("  ").convert(data)}\n');
  }
}

class PullServer {
  PullServer._(this.env, this.identity, this._http, this._email, this._password,
      this.namespace);

  final PullEnvironment env;
  final Json identity;
  final http.Client _http;
  final String _email;
  final String _password;
  final String namespace;
  late final String _webToken;

  static Future<PullServer> start(PullEnvironment env) async {
    final uri = Uri.tryParse(env.origin);
    if (uri == null ||
        uri.scheme != 'http' ||
        !['127.0.0.1', '::1', 'localhost'].contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path.isNotEmpty) {
      throw StateError(
          'CLOUD_SYNC_QA_URL must point to an isolated loopback HTTP origin');
    }
    final client = http.Client();
    try {
      final identityResponse =
          await client.get(uri.resolve('/__qa__/identity'));
      final identity = jsonDecode(identityResponse.body) as Json;
      if (identityResponse.statusCode != 200 ||
          identity['database_is_isolated'] != true ||
          identity['cloud_sha'] is! String ||
          (identity['cloud_sha'] as String).isEmpty) {
        throw StateError('Cloud QA identity and isolation are required');
      }
      final random = Random.secure();
      final nonce =
          '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 30)}';
      final password =
          base64UrlEncode(List.generate(30, (_) => random.nextInt(256)));
      final server = PullServer._(
          env, identity, client, 'pull-$nonce@qa.example.com', password, nonce);
      final resp = await server
          .request('POST', '/api/v1/auth/register', auth: false, body: {
        'email': server._email,
        'password': password,
        'client_type': 'web',
        'device_name': 'matrix web writer'
      });
      server._webToken = resp['access_token'] as String;
      return server;
    } catch (_) {
      client.close();
      rethrow;
    }
  }

  Future<dynamic> request(String method, String path,
      {Json? body, bool auth = true}) async {
    final uri = Uri.parse(env.origin).resolve(path);
    if (uri.origin != Uri.parse(env.origin).origin) {
      throw ArgumentError('Use a relative QA API path');
    }
    // Seeding and later assertions can be separated by a long mobile recovery.
    // Keep fixture-only reads independent of an expired idle HTTP connection.
    final req = http.Request(method, uri)..persistentConnection = false;
    if (auth) req.headers['Authorization'] = 'Bearer $_webToken';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(await _http.send(req));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('$method ${uri.path} HTTP ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<dynamic> get(String path) => request('GET', path);
  Future<Json> write(String ledger, String method, String path,
          [Json? data]) async =>
      await request(method, '/api/v1/write/ledgers/$ledger/$path',
          body: {'base_change_id': 0, ...?data}) as Json;

  Future<String> createLedger(String name,
      {String? id, String currency = 'CNY', int start = 1}) async {
    final r = await request('POST', '/api/v1/write/ledgers', body: {
      'ledger_name': name,
      'currency': currency,
      'month_start_day': start,
      if (id != null) 'ledger_id': id
    });
    return r['entity_id'] as String;
  }

  Future<List<String>> createTransactions(
      String ledger, List<Json> payloads) async {
    final result = await write(ledger, 'POST', 'transactions/batch',
        {'transactions': payloads, 'auto_ai_tag': false});
    final ids = List<String>.from(result['created_sync_ids'] as List);
    if (ids.length != payloads.length || ids.toSet().length != ids.length) {
      throw StateError('Invalid IDs returned from create batch');
    }
    return ids;
  }

  Future<void> signIn(BeeCountCloudProvider provider) =>
      provider.auth.signInWithEmail(email: _email, password: _password);
  CloudServiceConfig configuration() => CloudServiceConfig(
      type: CloudBackendType.beecountCloud,
      name: 'QA Cloud',
      beecountCloudBaseUrl: env.origin,
      beecountCloudEmail: _email,
      beecountCloudPassword: _password);
  void close() => _http.close();
}

/// Records the actual SDK response and durable cursor at the start of each real request.
class PullObserver extends BeeCountCloudProvider {
  final pages = <PullPage>[];
  Future<int> Function()? readCursor;

  @override
  Future<BeeCountCloudPullResult> pullChanges(
      {int? since, int limit = 1000, bool persistCursor = true}) async {
    final before = await readCursor?.call();
    final result = await super
        .pullChanges(since: since, limit: limit, persistCursor: persistCursor);
    pages.add(PullPage(since ?? 0, before, limit, result));
    return result;
  }

  @override
  Future<BeeCountCloudPullResult> pullRestorePage(
      {required int since, required int limit}) async {
    final before = await readCursor?.call();
    final result = await super.pullRestorePage(since: since, limit: limit);
    pages.add(PullPage(since, before, limit, result, restoring: true));
    return result;
  }
}

class PullPage {
  PullPage(this.since, this.durableBefore, this.limit, this.result,
      {this.restoring = false});
  final int since;
  final int? durableBefore;
  final int limit;
  final BeeCountCloudPullResult result;
  final bool restoring;
  Json summary() => {
        'since': since,
        'restoring': restoring,
        'persistedBeforeRequest': durableBefore,
        'limit': limit,
        'count': result.changes.length,
        'lastCursor': result.serverCursor,
        'hasMore': result.hasMore
      };
}

class PullPhone {
  PullPhone._(this.db, this.repo, this.provider, this.engine);
  final BeeDatabase db;
  final LocalRepository repo;
  final PullObserver provider;
  final SyncEngine engine;

  static Future<PullPhone> open(PullServer server,
      {File? database, bool resetPreferences = true}) async {
    if (resetPreferences) resetPullHostPreferences();
    final provider = PullObserver();
    await provider.initialize({'baseUrl': server.env.origin});
    await server.signIn(provider);
    final db = BeeDatabase.forTesting(
        database == null ? NativeDatabase.memory() : NativeDatabase(database));
    final tracker = ChangeTracker(db);
    final repo = LocalRepository(db, changeTracker: tracker);
    final engine = SyncEngine(
        db: db, provider: provider, changeTracker: tracker, repo: repo);
    provider.readCursor = engine.appCursor.read;
    return PullPhone._(db, repo, provider, engine);
  }

  Future<int> localLedger(String id) async =>
      (await (db.select(db.ledgers)..where((r) => r.syncId.equals(id)))
              .getSingle())
          .id;
  Future<int> pending() async =>
      (await engine.changeTracker.getUnpushedChanges()).length;
  Future<void> close() async {
    await engine.dispose();
    await provider.dispose();
    await db.close();
  }
}
