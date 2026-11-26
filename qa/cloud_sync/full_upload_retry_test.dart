import 'dart:convert';
import 'dart:io';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pull_support.dart';

enum _Fault {
  dictionary('upload-resume-dictionary'),
  beforeSecondBatch('upload-resume-uncommitted'),
  afterSecondBatch('upload-resume-lost-receipt');

  const _Fault(this.caseName);
  final String caseName;
}

class _Writer extends BeeCountCloudProvider {
  _Writer([this.fault]);
  final _Fault? fault;
  bool injected = false;
  final batches = <int>[];
  final transactionBatches = <List<Json>>[];
  List<int?>? lostChangeIds;
  final receipts = <String, int?>{};

  @override
  Future<BeeCountCloudPushResult> pushChanges(
      {required List<Json> changes}) async {
    batches.add(changes.length);
    final transactions =
        changes.where((c) => c['entity_type'] == 'transaction').toList();
    if (transactions.isNotEmpty) transactionBatches.add(transactions);
    final target = !injected &&
        ((fault == _Fault.dictionary &&
                changes.any((c) => c['entity_type'] == 'tag')) ||
            (transactions.isNotEmpty &&
                transactionBatches.length == 2 &&
                fault != null));
    if (target && fault != _Fault.afterSecondBatch) {
      injected = true;
      throw const SocketException('QA disconnected before request');
    }
    final result = await super.pushChanges(changes: changes);
    for (var i = 0; i < changes.length; i++) {
      receipts[changes[i]['operation_id'] as String] = result.items[i].changeId;
    }
    if (target) {
      injected = true;
      lostChangeIds = result.items.map((r) => r.changeId).toList();
      throw const SocketException('QA disconnected after real Cloud commit');
    }
    return result;
  }
}

Future<({BeeDatabase db, ChangeTracker tracker, SyncEngine engine})> _open(
    File file, PullServer server, _Writer provider,
    {required bool first}) async {
  await provider.initialize({'baseUrl': server.env.origin});
  if (first) await server.signIn(provider);
  final db = BeeDatabase.forTesting(NativeDatabase(file));
  final tracker = ChangeTracker(db);
  return (
    db: db,
    tracker: tracker,
    engine: SyncEngine(
        db: db,
        provider: provider,
        changeTracker: tracker,
        repo: LocalRepository(db, changeTracker: tracker))
  );
}

Future<Map<String, int>> _remoteRows(PullServer server, String ledger) async {
  final raw = await server.get('/api/v1/sync/full?ledger_id=$ledger');
  final snapshot =
      jsonDecode(raw['snapshot']['payload']['content'] as String) as Json;
  return {
    for (final row in snapshot['items'] as List)
      row['syncId'] as String: ((row['amount'] as num) * 100).round()
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final fault in _Fault.values) {
    test('reopen and ordinary sync after ${fault.name}', () async {
      HttpOverrides.global = null;
      resetPullHostPreferences();
      final env = PullEnvironment();
      final server = await PullServer.start(env);
      addTearDown(server.close);
      final dir = await Directory.systemTemp.createTemp('bee-full-retry-');
      addTearDown(() => dir.delete(recursive: true));
      final path = File('${dir.path}/local.sqlite');
      final first = _Writer(fault);
      var app = await _open(path, server, first, first: true);
      const ledgerKey = 'full-upload-ledger';
      final ledger = await app.db.into(app.db.ledgers).insert(
          LedgersCompanion.insert(
              name: 'First upload', syncId: const Value(ledgerKey)));
      final expected = <String, int>{};
      final count = fault == _Fault.dictionary ? 1 : 503;
      await app.db.batch((batch) {
        batch.insert(
            app.db.tags,
            TagsCompanion.insert(
                name: 'First tag', syncId: const Value('initial-upload-tag')));
        for (var i = 0; i < count; i++) {
          final id = 'upload-row-$i';
          expected[id] = i + 1;
          batch.insert(
              app.db.transactions,
              TransactionsCompanion.insert(
                  ledgerId: ledger,
                  syncId: Value(id),
                  amount: (i + 1) / 100,
                  type: 'expense',
                  happenedAt: Value(DateTime.utc(2025))));
        }
      });
      expect(await app.tracker.getUnpushedCount(), 0);
      final failure = await app.engine.sync(ledgerId: '$ledger');
      expect(first.injected, isTrue);
      expect(failure.hasError, isTrue);
      final before = await _remoteRows(server, ledgerKey);
      expect(
          before.length,
          switch (fault) {
            _Fault.dictionary => 0,
            _Fault.beforeSecondBatch => 499,
            _Fault.afterSecondBatch => count
          });
      final queueAfterFailure = await app.tracker.getUnpushedCount();
      await app.engine.dispose();
      await first.dispose();
      await app.db.close();

      if (fault == _Fault.dictionary) {
        await server.write(
            ledgerKey, 'PATCH', 'meta', {'ledger_name': 'Renamed on web'});
      }
      final resumed = _Writer();
      app = await _open(path, server, resumed, first: false);
      addTearDown(() async {
        await app.engine.dispose();
        await resumed.dispose();
        await app.db.close();
      });
      final recovery = await app.engine.sync(ledgerId: '$ledger');
      expect(recovery.hasError, isFalse, reason: recovery.error);
      expect(await _remoteRows(server, ledgerKey), expected);
      if (fault == _Fault.dictionary) {
        final metadata = await (app.db.select(app.db.ledgers)
              ..where((l) => l.id.equals(ledger)))
            .getSingle();
        expect(metadata.name, 'Renamed on web');
      }
      expect(await app.tracker.getUnpushedCount(), 0);
      if (fault != _Fault.dictionary) {
        expect(resumed.transactionBatches.single, first.transactionBatches[1]);
        if (first.lostChangeIds != null) {
          expect([
            for (final row in resumed.transactionBatches.single)
              resumed.receipts[row['operation_id']]
          ], first.lostChangeIds);
        }
      }

      final beforeThird = resumed.batches.length;
      expect((await app.engine.sync(ledgerId: '$ledger')).hasError, isFalse);
      expect(resumed.batches.length, beforeThird);
      final eventIds = <String>[];
      int cursor = 0;
      while (true) {
        final page =
            await server.get('/api/v1/sync/pull?since=$cursor&limit=500');
        final changes = (page['changes'] as List).cast<Json>();
        eventIds.addAll(changes
            .where((r) => r['entity_type'] == 'transaction')
            .map((r) => r['entity_sync_id'] as String));
        if (page['has_more'] != true) break;
        cursor = changes.last['change_id'] as int;
      }
      expect(eventIds.length, expected.length);
      expect(eventIds.toSet(), expected.keys.toSet());
      await env.save(fault.caseName, {
        'status': 'PASS',
        'database': server.identity['database'],
        'cloud_sha': server.identity['cloud_sha'],
        'historical_rows': count,
        'remote_rows_at_interruption': before.length,
        'pending_at_interruption': queueAfterFailure,
        'remote_rows_after_restart': expected.length,
        'pending_after_restart': 0,
        'transaction_events': eventIds.length,
        'before_transaction_batches':
            first.transactionBatches.map((b) => b.length).toList(),
        'restart_transaction_batches':
            resumed.transactionBatches.map((b) => b.length).toList(),
        'third_sync_posts': resumed.batches.length - beforeThird,
        if (fault == _Fault.dictionary) 'concurrent_web_rename_preserved': true,
        if (fault == _Fault.afterSecondBatch)
          'identical_receipt_change_ids': true,
      });
    }, timeout: const Timeout(Duration(minutes: 4)));
  }
}
