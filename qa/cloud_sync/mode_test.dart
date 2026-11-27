import 'dart:convert';
import 'dart:io';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/sync_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test('local mode queues changes until the same Cloud is reactivated',
      () async {
    final cloud = await FixtureCloud.create('local-mode');
    // Establish a real App session. The normal runtime reopens it from preferences.
    final session = await cloud.device();
    await session.close();
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    final container =
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(() async {
      final runtime = await container.read(activeCloudRuntimeProvider.future);
      await runtime?.close();
      container.dispose();
      await db.close();
    });
    final ctl = container.read(activeCloudRuntimeProvider.notifier);
    await container.read(activeCloudRuntimeProvider.future);
    final tracker = ChangeTracker(db);
    final book = await db.into(db.ledgers).insert(LedgersCompanion.insert(
        name: '家庭',
        currency: const Value('CNY'),
        syncId: const Value('mode-family')));
    final date = DateTime.utc(2026, 2, 2, 8);
    Future<int> write(String id, double amount) =>
        container.read(repositoryProvider).addTransaction(
            ledgerId: book,
            type: 'expense',
            amount: amount,
            happenedAt: date,
            syncId: id,
            note: id);
    await write('control', 10);
    expect(await tracker.getUnpushedCount(), 0,
        reason: 'never-linked local account');
    await ctl.saveAndActivate(cloud.config);
    Future<void> sync() async {
      final runtime = await container.read(activeCloudRuntimeProvider.future);
      final result = await runtime!.syncEngine!.sync(ledgerId: '$book');
      expect(result.error, isNull);
    }

    Future<Map<String, double>> rows() async {
      final records = await cloud
          .get('/api/v1/read/ledgers/mode-family/transactions') as List;
      return {
        for (final r in records)
          r['id'] as String: (r['amount'] as num).toDouble()
      };
    }

    await sync();
    expect(await rows(), {'control': 10.0});
    final baseline = (await cloud.eventsAfter(0)).cursor;
    // Same controller method as the settings screen, with the network still available.
    await (await container.read(authServiceProvider.future)).signOut();
    expect(await ctl.activate(CloudBackendType.local), isTrue);
    expect(
        (await container.read(activeCloudRuntimeProvider.future))!.syncEngine,
        isNull);
    await write('offline', 28.5);
    expect(await rows(), {'control': 10.0});
    final pending = await tracker.getUnpushedCount();
    expect(await ctl.activate(CloudBackendType.beecountCloud), isTrue);
    await sync();
    expect(await rows(), {'control': 10.0, 'offline': 28.5},
        reason:
            'transaction written in local mode must reach the Web projection');
    expect(pending, greaterThan(0));
    expect(await tracker.getUnpushedCount(), 0);
    final changes = await cloud.eventsAfter(baseline);
    expect(
        changes.events
            .where((e) => e['entity_type'] == 'transaction')
            .map((e) => e['entity_sync_id']),
        ['offline']);
    await sync();
    expect((await cloud.eventsAfter(changes.cursor)).events, isEmpty);
    final dest = Directory(Platform.environment['CLOUD_SYNC_QA_OUTPUT']!);
    await File('${dest.path}/mode-switch.json').writeAsString(jsonEncode({
      'case': 'mode-switch',
      'status': 'PASS',
      'pending_while_local': pending,
      'cloud_while_local': 1,
      'transactions_after_return': await rows(),
      'repeated_events': 0,
    }));
  });
}
