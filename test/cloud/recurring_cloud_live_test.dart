import 'dart:convert';
import 'dart:io';
import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../integration_test/support/recurring_cloud_case.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const existingLedger = String.fromEnvironment('QA_EXISTING_LEDGER');
  test('Flutter reads the saved browser edit and the original posted amount',
      () async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    const owner = String.fromEnvironment('QA_EXISTING_EMAIL');
    await qaRequest('GET', '/__qa__/identity')
        .then((v) => expect(v['run_id'], runId));
    final cloud = BeeCountCloudProvider();
    await cloud.initialize({'baseUrl': origin});
    await cloud.auth.signInWithEmail(email: owner, password: password);
    final row =
        ((await cloud.recurringRules(existingLedger))['items'] as List).single;
    expect(row['id'], const String.fromEnvironment('QA_EXPECTED_RULE'));
    expect(row['status'], 'paused');
    expect(row['data']['rule']['name'], 'QA Web 已复核');
    expect(row['data']['rule']['transaction']['amount'], 46);
    final token = (await qaRequest('POST', '/api/v1/auth/login', data: {
      'email': owner,
      'password': password,
      'client_type': 'web',
      'device_name': 'QA verification'
    }))['access_token'] as String;
    final full = await qaRequest(
        'GET', '/api/v1/sync/full?ledger_id=$existingLedger',
        token: token);
    final posted =
        (jsonDecode(full['snapshot']['payload']['content'])['items'] as List)
            .single;
    expect(posted['syncId'], const String.fromEnvironment('QA_EXPECTED_TX'));
    expect(posted['amount'], 43);
  }, skip: existingLedger.isEmpty);
  test('live Flutter client and Drift round trip against owned Cloud',
      () async {
    HttpOverrides.global = null;
    final address = email.replaceFirst(
        '@', '+host-${DateTime.now().millisecondsSinceEpoch}@');
    await registerQa(address);
    SharedPreferences.setMockInitialValues({});
    final store = CloudServiceStore();
    await store.saveAndActivate(CloudServiceConfig(
        type: CloudBackendType.beecountCloud,
        name: 'QA',
        beecountCloudBaseUrl: origin,
        beecountCloudEmail: address,
        beecountCloudPassword: password));
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tracker = ChangeTracker(db);
    final repo = LocalRepository(db,
        changeTracker: tracker,
        cloudExecutesRecurring: store.usesBeeCountCloud);
    final cloud = BeeCountCloudProvider();
    await cloud.initialize(
        {'baseUrl': origin, 'email': address, 'password': password});
    await cloud.auth.signInWithEmail(email: address, password: password);
    final engine =
        SyncEngine(db: db, provider: cloud, changeTracker: tracker, repo: repo);
    addTearDown(engine.dispose);
    final result = await recurringCloudRoundTrip(
        cloud: cloud, engine: engine, repo: repo, db: db, address: address);
    stdout.writeln('QA_RECURRING_RESULT ${jsonEncode(result)}');
  },
      skip: runId.isEmpty || existingLedger.isNotEmpty,
      timeout: const Timeout(Duration(minutes: 3)));
}
