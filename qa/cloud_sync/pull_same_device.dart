import 'dart:io';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pull_support.dart';

String _device(PullPhone phone) =>
    (phone.provider.auth as BeeCountCloudAuthService).currentDeviceId!;

/// The first transaction is created and uploaded via the local repository.
/// Additional SDK pushes fill another page without adding rows to the receiver.
Future<Json> checkSameDeviceRestore(PullServer server) async {
  final ledger = await server.createLedger('QA same-device restore');
  final source = await PullPhone.open(server);
  late String original;
  late String device;
  try {
    await source.engine.syncLedgersFromServer();
    final localLedger = await source.localLedger(ledger);
    final localId = await source.repo.addTransaction(
        ledgerId: localLedger,
        type: 'expense',
        amount: 12.34,
        happenedAt: DateTime.utc(2026, 11, 18),
        note: 'Before reinstall');
    original = (await (source.db.select(source.db.transactions)
              ..where((r) => r.id.equals(localId)))
            .getSingle())
        .syncId!;
    expect(await source.engine.push(localLedger.toString()), 1);
    expect(await source.pending(), 0);
    device = _device(source);
  } finally {
    await source.close();
  }

  final dir = await Directory.systemTemp.createTemp('beecount-device-restore-');
  final file = File('${dir.path}/restore.sqlite');
  PullPhone? openPhone;
  try {
    final phone =
        await PullPhone.open(server, database: file, resetPreferences: false);
    openPhone = phone;
    expect(_device(phone), device);
    expect(await phone.engine.appCursor.read(), 0);
    expect(await phone.db.select(phone.db.transactions).get(), isEmpty);
    await phone.engine.syncLedgersFromServer();
    await phone.engine.pull('');
    final recovered = await phone.db.select(phone.db.transactions).getSingle();
    expect([recovered.syncId, recovered.note, (recovered.amount * 100).round()],
        [original, 'Before reinstall', 1234]);
    expect(phone.provider.pages.single.restoring, isTrue);
    final initialCursor = await phone.engine.appCursor.read();
    await phone.repo.updateTransaction(
        id: recovered.id,
        type: 'expense',
        amount: 15.71,
        note: 'Unpushed edit',
        happenedAt: recovered.happenedAt);
    expect(await phone.pending(), 1);

    final expected = <String, int>{original: 1571};
    Json change(String id, int cents) => {
          'ledger_id': ledger,
          'entity_type': 'transaction',
          'entity_sync_id': id,
          'action': 'upsert',
          'updated_at': '2026-11-18T07:00:00Z',
          'payload': {
            'syncId': id,
            'type': 'expense',
            'amount': cents / 100,
            'currencyCode': 'CNY',
            'nativeAmount': cents / 100,
            'happenedAt': '2026-11-18T07:00:00Z',
            'note': 'Same-device page'
          }
        };
    const count = 503;
    String idFor(int i) => 'own-${server.namespace}-$i';
    for (var start = 0; start < count; start += 50) {
      final batch = <Json>[];
      for (var i = start; i < start + 50 && i < count; i++) {
        expected[idFor(i)] = 501 + i;
        batch.add(change(idFor(i), 501 + i));
      }
      final ack = await phone.provider.pushChanges(changes: batch);
      expect(ack.items.map((item) => item.status), everyElement('accepted'));
    }
    final web = (await server.createTransactions(ledger, [
      {
        'tx_type': 'expense',
        'amount': 8.97,
        'currency_code': 'CNY',
        'native_amount': 8.97,
        'happened_at': '2026-11-18T07:00:00Z',
        'note': 'Other client',
        'tag_ids': <String>[],
      }
    ]))
        .single;
    expected[web] = 897;

    // The temporary trigger disappears when this actual database connection
    // closes; no edits to the cursor, cached response or outbox are necessary.
    final last = idFor(count - 1);
    await phone.db.customStatement("""
      CREATE TEMP TRIGGER pause_restore BEFORE INSERT ON transactions
      WHEN NEW.sync_id = '$last'
      BEGIN SELECT RAISE(ABORT, 'QA interrupted restore'); END
    """);
    phone.provider.pages.clear();
    await phone.engine.replayAllChanges();
    final heldCursor = await phone.engine.appCursor.read();
    expect(phone.provider.pages, hasLength(2));
    expect(phone.provider.pages.first.result.changes, hasLength(500));
    expect(heldCursor, phone.provider.pages.first.result.serverCursor);
    expect(heldCursor, greaterThan(initialCursor));
    final errors = await phone.db.select(phone.db.syncPullErrors).get();
    expect(errors.single.entitySyncId, last);
    expect(errors.single.resolvedAt, isNull);
    final interruptedPages =
        phone.provider.pages.map((p) => p.summary()).toList();
    await phone.close();
    openPhone = null;

    final resumed =
        await PullPhone.open(server, database: file, resetPreferences: false);
    openPhone = resumed;
    expect(_device(resumed), device);
    expect(await resumed.engine.appCursor.read(), heldCursor);
    await resumed.engine.pull('');
    final retry = resumed.provider.pages.single;
    expect(retry.restoring, isTrue);
    expect(retry.since, heldCursor);
    final finalCursor = await resumed.engine.appCursor.read();
    expect(finalCursor, greaterThan(heldCursor));
    final rows = await resumed.db.select(resumed.db.transactions).get();
    expect(rows.length, expected.length);
    expect({for (final row in rows) row.syncId: (row.amount * 100).round()},
        expected);
    expect(rows.singleWhere((r) => r.syncId == original).note, 'Unpushed edit');
    expect(await resumed.pending(), 1);
    expect(
        (await resumed.db.select(resumed.db.syncPullErrors).getSingle())
            .resolvedAt,
        isNotNull);
    final remote = await server
        .get('/api/v1/read/ledgers/$ledger/transactions?limit=2000') as List;
    expect(
        {for (final r in remote) r['id']: ((r['amount'] as num) * 100).round()},
        {...expected, original: 1234});

    final echoId = idFor(count);
    expect(
        (await resumed.provider.pushChanges(changes: [change(echoId, 779)]))
            .items
            .single
            .status,
        'accepted');
    expect(await resumed.engine.pull(''), 0);
    final normal = resumed.provider.pages.last;
    expect(normal.restoring, isFalse);
    expect(normal.result.changes, isEmpty);
    expect(await resumed.engine.appCursor.read(), finalCursor);
    return {
      'sourceDeviceReusedAfterReinstall': true,
      'firstRecoveredAmountCents': 1234,
      'recoveredTransactions': rows.length,
      'ownAdditionalTransactions': count,
      'otherClientTransactions': 1,
      'initialCursor': initialCursor,
      'interruptedPages': interruptedPages,
      'checkpoint': heldCursor,
      'resumedAfterDatabaseReopen': retry.summary(),
      'finalCursor': finalCursor,
      'pendingEditsKept': 1,
      'pendingLocalAmountCents': 1571,
      'remoteAmountCents': 1234,
      'normalPullAfterOwnWrite': normal.summary()
    };
  } finally {
    await openPhone?.close();
    await dir.delete(recursive: true);
  }
}
