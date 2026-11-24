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
  }, skip: runId.isEmpty, timeout: const Timeout(Duration(minutes: 3)));
}
