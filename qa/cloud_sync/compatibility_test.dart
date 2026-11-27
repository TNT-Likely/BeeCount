import 'dart:convert';
import 'dart:io';

import 'package:beecount/data/db.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'fixture_client.dart';

/// Deliberately uses the release's public engine API so the exact same probe
/// can be copied into the exported release checkout and compiled against it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  test('two App devices round-trip transactions across versions', () async {
    final cloud = await FixtureCloud.create('compatibility');
    final a = await cloud.device();
    addTearDown(a.close);
    const key = 'compatibility-qa-book';
    final localId = await a.db.into(a.db.ledgers).insert(
        LedgersCompanion.insert(
            name: '兼容账本',
            currency: const Value('CNY'),
            syncId: const Value(key)));
    final date = DateTime.utc(2026, 10, 28, 8);
    await a.db.into(a.db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: localId,
        type: 'expense',
        amount: 12.5,
        happenedAt: Value(date),
        note: const Value('首次'),
        syncId: const Value('first')));
    final upload = await a.engine.sync(ledgerId: '$localId');
    expect(upload.error, isNull);
    Future<Map<String, double>> web() async {
      final data =
          await cloud.get('/api/v1/read/ledgers/$key/transactions') as List;
      return {
        for (final r in data) r['id'] as String: (r['amount'] as num).toDouble()
      };
    }

    expect(await web(), {'first': 12.5});
    final b = await cloud.device();
    addTearDown(b.close);
    await b.engine.syncLedgersFromServer();
    final otherId = await b.ledger(key);
    await b.engine.downloadAndRestoreToCurrentLedger(ledgerId: otherId);
    expect((await b.db.select(b.db.transactions).get()).single.amount, 12.5);
    await b.repo.addTransaction(
        ledgerId: otherId,
        type: 'income',
        amount: 22.25,
        happenedAt: date,
        syncId: 'second',
        note: '增量');
    final delta = await b.engine.sync(ledgerId: '$otherId');
    expect(delta.error, isNull);
    await a.engine.pull('');
    final rows = await a.db.select(a.db.transactions).get();
    final expected = {'first': 12.5, 'second': 22.25};
    expect({for (final tx in rows) tx.syncId: tx.amount}, expected);
    expect(await web(), expected);
    expect(await a.tracker.getUnpushedCount(), 0);
    expect(await b.tracker.getUnpushedCount(), 0);
    final dest = Directory(Platform.environment['CLOUD_SYNC_QA_OUTPUT']!);
    await File('${dest.path}/compatibility.json').writeAsString(jsonEncode({
      'case': 'compatibility',
      'status': 'PASS',
      'app_sha': Platform.environment['CLOUD_SYNC_QA_APP_SHA'],
      'cloud_sha': cloud.identity['cloud_sha'],
      'cloud_database': cloud.identity['database'],
      'web_and_device_a': expected,
      'cold_device_b_amount': 12.5,
      'pending': [0, 0],
    }));
  });
}
