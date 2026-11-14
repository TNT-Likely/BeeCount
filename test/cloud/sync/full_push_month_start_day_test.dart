import 'dart:convert';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes/fake_beecount_cloud_provider.dart';

class _Auth extends FakeBeeCountCloudAuthService {
  @override
  Future<String> requireAccessToken() async => 'synthetic-period-token';
}

/// Keep the real SDK request serializer. Replay the fixed Cloud create route's
/// ledger event, whose missing month_start_day becomes an explicit default 1.
class _CreateEchoProvider extends FakeBeeCountCloudProvider {
  _CreateEchoProvider() {
    client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/write/ledgers');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      createBodies.add(body);
      final day = body['month_start_day'] as int? ?? 1;
      pushFakeChange(
        entityType: 'ledger',
        entitySyncId: body['ledger_id'] as String,
        ledgerId: body['ledger_id'] as String,
        updatedByDeviceId: 'web-console',
        payload: {
          'ledgerName': body['ledger_name'],
          'currency': body['currency'],
          'monthStartDay': day,
        },
      );
      return http.Response(
          jsonEncode({
            'ledger_id': body['ledger_id'],
            'base_change_id': 0,
            'new_change_id': 1,
          }),
          200);
    });
    sdk = BeeCountCloudStorageService(
        baseUrl: 'https://qa.invalid',
        apiPrefix: '/api/v1',
        auth: _Auth(),
        httpClient: client);
  }

  late final MockClient client;
  late final BeeCountCloudStorageService sdk;
  final createBodies = <Map<String, dynamic>>[];

  @override
  Future<BeeCountCloudWriteCommitMeta> writeCreateLedger({
    String? ledgerId,
    required String ledgerName,
    String currency = 'CNY',
    int? monthStartDay,
    String? idempotencyKey,
  }) =>
      sdk.writeCreateLedger(
          ledgerId: ledgerId,
          ledgerName: ledgerName,
          currency: currency,
          monthStartDay: monthStartDay,
          idempotencyKey: idempotencyKey);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late SyncEngine engine;
  late _CreateEchoProvider provider;
  late Map<String, dynamic> originalTransaction;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    final tracker = ChangeTracker(db);
    final repo = LocalRepository(db, changeTracker: tracker);
    provider = _CreateEchoProvider();
    engine = SyncEngine(
        db: db, repo: repo, changeTracker: tracker, provider: provider);
    await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: const Value(1),
        name: 'QA control',
        syncId: const Value('qa-period-control'),
        monthStartDay: const Value(15)));
    await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: const Value(4),
        name: 'QA period eight',
        syncId: const Value('qa-period-eight'),
        monthStartDay: const Value(8)));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: 4,
        type: 'expense',
        amount: 12,
        currencyCode: const Value('USD'),
        nativeAmount: const Value(85.19999999999999),
        happenedAt: Value(DateTime.utc(2026, 10, 20)),
        syncId: const Value('qa-period-tx')));
    originalTransaction =
        (await db.select(db.transactions).getSingle()).toJson();
  });
  tearDown(() async {
    provider.sdk.dispose();
    await db.close();
  });

  test('fullPush real SDK create body carries the local period eight',
      () async {
    await engine.fullPush(ledgerId: 4);
    expect(provider.createBodies, hasLength(1));
    expect(provider.createBodies.single['month_start_day'], 8);
    expect(provider.createBodies.single['currency'], 'CNY');
    expect(provider.createBodies.single.containsKey('periodStartDay'), isFalse);
    final snapshot =
        jsonDecode((await provider.storage.download(path: 'qa-period-eight'))!);
    expect(snapshot['monthStartDay'], 8);
    final ledgerChange = provider.pushedBatches
        .expand((batch) => batch)
        .singleWhere((row) => row['entity_type'] == 'ledger');
    expect(ledgerChange['payload']['monthStartDay'], 8);
  });

  test('fullPush create event replay cannot overwrite SQLite eight with one',
      () async {
    await engine.fullPush(ledgerId: 4);
    await engine.pull('4');
    final target = await (db.select(db.ledgers)
          ..where((row) => row.id.equals(4)))
        .getSingle();
    expect(target.monthStartDay, 8);
    final control = await (db.select(db.ledgers)
          ..where((row) => row.id.equals(1)))
        .getSingle();
    expect(control.monthStartDay, 15);
    expect((await db.select(db.transactions).getSingle()).toJson(),
        originalTransaction);
  });

  for (final day in [1, 28]) {
    test('fullPush real create request and echo retain explicit day $day',
        () async {
      await (db.update(db.ledgers)..where((row) => row.id.equals(4)))
          .write(LedgersCompanion(monthStartDay: Value(day)));
      await engine.fullPush(ledgerId: 4);
      expect(provider.createBodies.single['month_start_day'], day);
      await engine.pull('4');
      final target = await (db.select(db.ledgers)
            ..where((row) => row.id.equals(4)))
          .getSingle();
      expect(target.monthStartDay, day);
    });
  }

  test(
      'SDK legacy caller omits period instead of inventing a new request value',
      () async {
    await provider.sdk.writeCreateLedger(
        ledgerId: 'qa-legacy-create', ledgerName: 'Legacy', currency: 'USD');
    expect(provider.createBodies.single, {
      'ledger_id': 'qa-legacy-create',
      'ledger_name': 'Legacy',
      'currency': 'USD',
    });
  });
}
