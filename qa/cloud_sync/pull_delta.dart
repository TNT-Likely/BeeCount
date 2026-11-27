import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'pull_support.dart';

/// The touched-entity list is derived from write receipts, independently of the
/// SDK's pull responses. Sequence numbers may have gaps from other QA accounts.
Future<Json> checkDeltaPull(PullServer server, int visibleCount) async {
  final ledger = await server.createLedger('QA page boundary $visibleCount');
  final phone = await PullPhone.open(server);
  try {
    final expected = <String, Json>{};
    final touched = <String, String>{};
    final eventIds = <String, int>{};
    final baselineIds = <String, int>{};
    final random = Random(server.env.seed + visibleCount);
    Future<String> write(String type, String method, String path, Json body,
        {bool baseline = false}) async {
      final reply = await server.write(ledger, method, path, body);
      final id = reply['entity_id'] as String;
      if (!baseline) {
        if (touched.containsKey(id)) {
          throw StateError('Fixture touched $id more than once');
        }
        touched[id] = method == 'DELETE' ? '$type/delete' : '$type/upsert';
        eventIds[id] = reply['new_change_id'] as int;
      }
      return id;
    }

    Json want(int cents, String? note,
            {String? category,
            String? account,
            List<String> tags = const []}) =>
        {
          'cents': cents,
          'note': note,
          'category': category,
          'account': account,
          'tags': tags.toList()..sort()
        };
    Json txPayload(Json row) => {
          'tx_type': 'expense',
          'amount': row['cents'] / 100,
          'currency_code': 'CNY',
          'native_amount': row['cents'] / 100,
          'happened_at': '2026-11-18T07:00:00Z',
          'note': row['note'],
          'category_id': row['category'],
          'account_id': row['account'],
          'tag_ids': row['tags']
        };
    Future<String> add(Json row, {bool baseline = false}) async {
      final id = await write(
          'transaction', 'POST', 'transactions', txPayload(row),
          baseline: baseline);
      expected[id] = row;
      return id;
    }

    Future<void> filler(int count, int offset) async {
      for (var i = 0; i < count; i += 50) {
        final batch = [
          for (var n = i; n < min(i + 50, count); n++)
            want(100 + random.nextInt(999999), 'page ${offset + n}')
        ];
        final ids = await server.createTransactions(
            ledger, batch.map(txPayload).toList());
        for (var j = 0; j < ids.length; j++) {
          final id = ids[j];
          if (touched.containsKey(id)) {
            throw StateError('Duplicate Web batch identity: $id');
          }
          touched[id] = 'transaction/upsert';
          expected[id] = batch[j];
        }
      }
    }

    final oldTag = await write('tag', 'POST', 'tags', {'name': 'Baseline tag'},
        baseline: true);
    final clearRow = want(1125, 'Clear both fields', tags: [oldTag]);
    final clearId = await add(clearRow, baseline: true);
    final removeId = await add(want(2375, 'Remove'), baseline: true);
    final keepId =
        await add(want(3575, 'Keep', tags: [oldTag]), baseline: true);
    await phone.engine.syncLedgersFromServer();
    await phone.engine.pull('');
    final start = await phone.engine.appCursor.read();
    expect(start, greaterThan(0));
    final ledgerId = await phone.localLedger(ledger);
    for (final tx in await phone.db.select(phone.db.transactions).get()) {
      baselineIds[tx.syncId!] = tx.id;
    }
    expect(baselineIds.keys, unorderedEquals(expected.keys));
    expect(await phone.repo.getTagsForTransaction(baselineIds[clearId]!),
        hasLength(1));
    phone.provider.pages.clear();

    await write('transaction', 'PATCH', 'transactions/$clearId', {
      'note': null,
      'tags': [],
      'tag_ids': [],
      'amount': 12.75,
      'native_amount': 12.75
    });
    expected[clearId] = want(1275, null);
    await write('transaction', 'DELETE', 'transactions/$removeId', {});
    expected.remove(removeId);

    // Events 499, 500 and 501 (when present) are the parent, child and
    // transaction referencing the child. At 1000/1001 an account and the
    // transaction referencing it straddle the second page boundary as well.
    final firstClusterEnd = min(501, visibleCount);
    await filler(firstClusterEnd - 6, 0);
    final tag = await write('tag', 'POST', 'tags', {'name': 'Boundary tag'});
    final parent = await write('category', 'POST', 'categories',
        {'name': 'Page parent', 'kind': 'expense', 'level': 1});
    final child = await write('category', 'POST', 'categories', {
      'name': 'Page child',
      'kind': 'expense',
      'level': 2,
      'parent_sync_id': parent,
      'parent_name': 'Page parent'
    });
    final relation =
        await add(want(2850, 'First boundary', category: child, tags: [tag]));
    String? lastAccount, lastRelation;
    if (visibleCount > 501) {
      await filler(visibleCount - firstClusterEnd - 2, firstClusterEnd);
      lastAccount = await write('account', 'POST', 'accounts',
          {'name': 'Across pages', 'currency': 'CNY', 'account_type': 'cash'});
      lastRelation = await add(want(5420, 'Second boundary',
          category: child, account: lastAccount, tags: [tag]));
    }
    expect(touched.length, visibleCount);
    expect((await phone.repo.getTransactionById(baselineIds[clearId]!))!.note,
        'Clear both fields');
    expect(
        await phone.repo.getTransactionById(baselineIds[removeId]!), isNotNull);
    final db = phone.db;
    var applied = 0;
    final pages = <PullPage>[];
    Json? interrupted;
    if (visibleCount == 1001) {
      // Fail the final write of page two on this private client. Confirm all
      // preceding writes in that page roll back while page one stays committed.
      await db
          .customStatement('CREATE TEMP TABLE qa_hold_account (sync_id TEXT)');
      await db.customStatement(
          'INSERT INTO qa_hold_account VALUES (?)', [lastAccount!]);
      await db.customStatement('''
        CREATE TEMP TRIGGER qa_interrupt_page BEFORE INSERT ON accounts
        WHEN NEW.sync_id IN (SELECT sync_id FROM qa_hold_account)
        BEGIN SELECT RAISE(ABORT, 'QA simulated local interruption'); END
      ''');
      try {
        applied = await phone.engine.pull('');
        expect(applied, 500);
        expect(phone.provider.pages.map((p) => p.result.changes.length),
            [500, 500]);
        final first = phone.provider.pages.first;
        final heldCursor = await phone.engine.appCursor.read();
        expect(heldCursor, first.result.serverCursor);
        expect(
            await (db.select(db.transactions)
                  ..where((t) => t.syncId.equals(relation)))
                .getSingleOrNull(),
            isNull);
        final errors = await db.select(db.syncPullErrors).get();
        expect(errors.single.changeId, eventIds[lastAccount]);
        expect(errors.single.resolvedAt, isNull);
        interrupted = {
          'firstAttemptApplied': applied,
          'committedCursor': heldCursor,
          'failedEvent': eventIds[lastAccount],
          'firstWriteOnFailedPageRolledBack': true
        };
        pages.add(first);
      } finally {
        await db.customStatement('DROP TRIGGER qa_interrupt_page');
      }
      phone.provider.pages.clear();
    }
    applied += await phone.engine.pull('');
    pages.addAll(phone.provider.pages);
    if (interrupted != null) {
      expect((await db.select(db.syncPullErrors).get()).single.resolvedAt,
          isNotNull);
      interrupted['retryFrom'] = phone.provider.pages.first.since;
      interrupted['retryApplied'] = applied - 500;
    }
    final cursor = await phone.engine.appCursor.read();
    final pageSizes = [
      for (var index = 0; index < visibleCount; index += 500)
        min(500, visibleCount - index)
    ];
    expect(applied, visibleCount);
    expect(pages.map((p) => p.result.changes.length), pageSizes);
    var previous = start;
    final eventPositions = <String, int>{};
    final observed = <String, String>{};
    final uniqueEvents = <int>{};
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      expect(page.durableBefore, previous);
      expect(page.since, previous);
      expect(page.limit, 500);
      expect(page.result.hasMore, i + 1 < pages.length);
      for (final item in page.result.changes) {
        expect(item.changeId, greaterThan(previous));
        previous = item.changeId;
        expect(uniqueEvents.add(item.changeId), true);
        final id = item.entitySyncId;
        expect(observed.containsKey(id), false, reason: 'second event for $id');
        eventPositions[id] = observed.length + 1;
        observed[id] = '${item.entityType}/${item.action}';
        if (eventIds.containsKey(id)) {
          expect(item.changeId, eventIds[id], reason: id);
        }
      }
      expect(page.result.serverCursor, previous);
    }
    expect(observed.length, touched.length);
    for (final e in touched.entries) {
      expect(observed[e.key], e.value, reason: 'event for ${e.key}');
    }
    expect(observed.containsKey(keepId), false);
    expect(cursor, previous);
    expect(eventPositions[parent], firstClusterEnd - 2);
    expect(eventPositions[child], firstClusterEnd - 1);
    expect(eventPositions[relation], firstClusterEnd);
    if (lastAccount != null) {
      expect(eventPositions[lastAccount], visibleCount - 1);
      expect(eventPositions[lastRelation], visibleCount);
    }
    final catRows = await db.select(db.categories).get();
    final catKeys = {for (final r in catRows) r.id: r.syncId};
    final actualChild = catRows.singleWhere((r) => r.syncId == child);
    expect(catKeys[actualChild.parentId], parent);
    final accKeys = {
      for (final r in await db.select(db.accounts).get()) r.id: r.syncId
    };
    final tagKeys = {
      for (final r in await db.select(db.tags).get()) r.id: r.syncId
    };
    final localTags = <int, List<String>>{};
    for (final link in await db.select(db.transactionTags).get()) {
      (localTags[link.transactionId] ??= []).add(tagKeys[link.tagId]!);
    }
    final local = (await (db.select(db.transactions)
          ..where((r) => r.ledgerId.equals(ledgerId)))
        .get());
    expect(local.length, expected.length);
    expect(local.any((r) => r.syncId == removeId), false);
    expect(
        local.singleWhere((r) => r.syncId == keepId).id, baselineIds[keepId]);
    expect(
        local.singleWhere((r) => r.syncId == clearId).id, baselineIds[clearId]);
    for (final row in local) {
      final id = row.syncId!;
      expect(
          want((row.amount * 100).round(), row.note,
              category: catKeys[row.categoryId],
              account: accKeys[row.accountId],
              tags: localTags[row.id] ?? []),
          expected[id],
          reason: 'App $id');
    }
    final web = await server
        .get('/api/v1/read/ledgers/$ledger/transactions?limit=2000') as List;
    expect(web.length, expected.length);
    for (final row in web) {
      expect(
          want(((row['amount'] as num) * 100).round(), row['note'],
              category: row['category_id'],
              account: row['account_id'],
              tags: List<String>.from(row['tag_ids'] ?? [])),
          expected[row['id']],
          reason: 'Web ${row['id']}');
    }
    expect(await phone.pending(), 0);
    phone.provider.pages.clear();
    expect(await phone.engine.pull(''), 0);
    final repeat = phone.provider.pages.single;
    expect(repeat.result.changes, isEmpty);
    expect(repeat.durableBefore, cursor);
    expect(await phone.engine.appCursor.read(), cursor);
    expect(await phone.pending(), 0);
    return {
      'visibleEvents': visibleCount,
      if (interrupted != null) 'interruptedPageRecovery': interrupted,
      'applied': applied,
      'startCursor': start,
      'finalCursor': cursor,
      'repeatApplied': 0,
      'pending': 0,
      'verifiedTransactionCount': expected.length,
      'pages': [for (final page in pages) page.summary()],
      'emptyPage': repeat.summary(),
      'relationshipPositions': {
        'parent': eventPositions[parent],
        'child': eventPositions[child],
        'transactionWithChildAndTag': eventPositions[relation],
        if (lastAccount != null) ...{
          'account': eventPositions[lastAccount],
          'transactionWithAccount': eventPositions[lastRelation]
        }
      },
      'changedAndCleared': 1,
      'deleted': 1,
      'untouchedControl': 1,
      'verifiedUniqueEventIds': uniqueEvents.length
    };
  } finally {
    await phone.close();
  }
}
