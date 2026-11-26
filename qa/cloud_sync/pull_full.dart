import 'dart:math';

import 'package:beecount/data/db.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/system/logger_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';
import 'pull_support.dart';

/// Web generates dictionary, budget and transaction IDs. Retain the independent
/// business expectations and substitute only identities returned by successful writes.
Future<void> seedFromWeb(PullServer server, RichLedgerFixture fixture) async {
  final ids = <String, String>{};
  final main = fixture.id('main');
  for (final book in fixture.ledgers.values) {
    final id = await server.createLedger(book['name'],
        id: book['syncId'],
        currency: book['currency'],
        start: book['monthStartDay']);
    expect(id, book['syncId']);
  }
  Future<void> create(String book, String entity, Json row, Json fields) async {
    final result = await server.write(book, 'POST', entity, fields);
    ids[row['syncId']] = result['entity_id'] as String;
  }

  final cats = fixture.categories.values.toList()
    ..sort((a, b) => (a['level'] as int).compareTo(b['level'] as int));
  for (final c in cats) {
    await create(main, 'categories', c, {
      'name': c['name'],
      'kind': c['kind'],
      'level': c['level'],
      'sort_order': c['sortOrder'],
      if (c['parentId'] != null) 'parent_sync_id': ids[c['parentId']]
    });
  }
  for (final t in fixture.tags.values) {
    await create(main, 'tags', t, {'name': t['name'], 'color': t['color']});
  }
  for (final a in fixture.accounts.values) {
    await create(main, 'accounts', a, {
      'name': a['name'],
      'account_type': a['type'],
      'currency': a['currency'],
      'initial_balance': a['initialBalance']
    });
  }
  for (final b in fixture.budgets.values) {
    await create(b['ledgerId'], 'budgets', b, {
      'type': b['type'],
      'amount': b['amount'],
      'period': b['period'],
      'start_day': b['startDay'],
      'enabled': b['enabled'],
      if (b['categoryId'] != null) 'category_id': ids[b['categoryId']]
    });
  }
  Json webTransaction(Json r) {
    final category = fixture.categories[r['categoryId']];
    final account = fixture.accounts[r['accountId']]!;
    final dest = fixture.accounts[r['toAccountId']];
    return {
      'tx_type': r['type'],
      'amount': r['amount'],
      'native_amount': r['nativeAmount'],
      'currency_code': r['currencyCode'],
      'happened_at': r['happenedAt'],
      'note': r['note'],
      'exclude_from_stats': r['excludeFromStats'],
      'exclude_from_budget': r['excludeFromBudget'],
      if (category != null) ...{
        'category_id': ids[r['categoryId']],
        'category_name': category['name'],
        'category_kind': category['kind']
      },
      'account_id': ids[r['accountId']],
      'account_name': account['name'],
      if (dest != null) ...{
        'from_account_id': ids[r['accountId']],
        'from_account_name': account['name'],
        'to_account_id': ids[r['toAccountId']],
        'to_account_name': dest['name']
      },
      'tags': [for (final id in r['tagIds']) fixture.tags[id]!['name']],
      'tag_ids': [for (final id in r['tagIds']) ids[id]],
    };
  }

  for (final ledger in fixture.ledgers.keys) {
    final rows =
        fixture.forLedger(fixture.transactions, ledger).values.toList();
    for (var offset = 0; offset < rows.length; offset += 50) {
      final batch = rows.sublist(offset, min(offset + 50, rows.length));
      final created = await server.createTransactions(
          ledger, batch.map(webTransaction).toList());
      for (var i = 0; i < batch.length; i++) {
        ids[batch[i]['syncId']] = created[i];
      }
    }
  }
  for (final table in [
    fixture.categories,
    fixture.accounts,
    fixture.tags,
    fixture.transactions,
    fixture.budgets
  ]) {
    final old = Map.of(table);
    table.clear();
    for (final entry in old.entries) {
      final actual = ids[entry.key]!;
      final row = Map<String, dynamic>.of(entry.value)..['syncId'] = actual;
      fixture.aliases[actual] = fixture.aliases[entry.key]!;
      for (final field in [
        'parentId',
        'categoryId',
        'accountId',
        'toAccountId'
      ]) {
        if (row[field] != null) row[field] = ids[row[field]]!;
      }
      if (row['tagIds'] != null) {
        row['tagIds'] = [for (final id in row['tagIds']) ids[id]!]..sort();
      }
      table[actual] = row;
    }
  }
}

Future<Json> _bootstrap(PullServer server, RichLedgerFixture fixture,
    {required bool noCurrent}) async {
  resetPullHostPreferences();
  final db = BeeDatabase.forTesting(NativeDatabase.memory());
  final container = ProviderContainer(overrides: [
    databaseProvider.overrideWithValue(db),
    if (noCurrent) currentLedgerIdProvider.overrideWith((ref) => 0),
  ]);
  ActiveCloudRuntime? runtime;
  try {
    await container
        .read(activeCloudRuntimeProvider.notifier)
        .saveAndActivate(server.configuration());
    runtime = (await container.read(activeCloudRuntimeProvider.future))!;
    final engine = runtime.syncEngine!;
    await server.signIn(engine.provider);
    expect(await engine.appCursor.read(), 0);
    expect(await db.select(db.transactions).get(), isEmpty);
    final start = DateTime.now();
    final applied = <String>{};
    final deadline = start.add(const Duration(minutes: 4));
    expect(container.read(syncServiceProvider), same(engine));
    // An advanced cursor alone does not mean the last snapshot download has finished.
    while (applied.length != fixture.ledgers.length ||
        (!noCurrent && container.read(syncGenerationProvider) == 0)) {
      for (final log in logger.logs.where((row) =>
          row.tag == 'SyncProvider' && !row.timestamp.isBefore(start))) {
        for (final id in fixture.ledgers.keys) {
          if (log.message.startsWith('新账本 $id 水合失败')) {
            throw StateError(
                'Snapshot hydration ${fixture.aliases[id]} failed: ${log.message.split('| Data:').first}');
          }
          if (log.message.startsWith('新账本 $id 水合 ')) applied.add(id);
        }
      }
      if (DateTime.now().isAfter(deadline)) {
        throw StateError(
            'Bootstrap timeout; hydrated ${applied.length}/${fixture.ledgers.length} ledgers');
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    await fixture.assertLocal(db);
    final cursor = await engine.appCursor.read();
    expect(cursor, greaterThan(0));
    expect(await engine.pull(''), 0);
    expect(await engine.appCursor.read(), cursor);
    expect(await engine.changeTracker.getUnpushedChanges(), isEmpty);
    return {
      'initialTransactions': 0,
      'hydratedLedgers': applied.length,
      'transactions': fixture.transactions.length,
      'verifiedResources': [
        'categories',
        'category parents',
        'accounts',
        'tags',
        'budgets',
        'transaction fields'
      ],
      'cursor': cursor,
      'repeatPull': 0,
      'pending': 0
    };
  } finally {
    container.dispose();
    await runtime?.close();
    await db.close();
  }
}

Future<Json> checkFullPull(PullServer server) async {
  final fixture = RichLedgerFixture.generate(
      namespace: server.namespace,
      seed: server.env.seed,
      transactionCount: server.env.transactionCount);
  await seedFromWeb(server, fixture);
  await fixture.assertRemote(server.get);
  final defaultStartup = await _bootstrap(server, fixture, noCurrent: false);
  final unselectedStartup = await _bootstrap(server, fixture, noCurrent: true);

  final phone = await PullPhone.open(server);
  try {
    final sentinel = await phone.repo.createLedger(name: 'QA unsent ledger');
    final localTx = await phone.repo.addTransaction(
        ledgerId: sentinel,
        type: 'expense',
        amount: 7.25,
        happenedAt: DateTime.utc(2026, 11, 8),
        note: 'Local-only control');
    final originalPending =
        (await phone.engine.changeTracker.getUnpushedChanges())
            .map((c) => c.id)
            .toSet();
    expect(originalPending, isNotEmpty);
    await phone.engine.syncLedgersFromServer();
    final target = fixture.id('main');
    final count = fixture.forLedger(fixture.transactions, target).length;
    final ledgerId = await phone.localLedger(target);
    final first = await phone.engine
        .downloadAndRestoreToCurrentLedger(ledgerId: ledgerId);
    expect(first.inserted, count);
    await fixture.assertLocal(phone.db);
    final repeated = await phone.engine
        .downloadAndRestoreToCurrentLedger(ledgerId: ledgerId);
    expect(repeated.inserted, 0);
    await fixture.assertLocal(phone.db);
    expect((await phone.repo.getTransactionById(localTx))?.note,
        'Local-only control');
    expect(
        (await phone.engine.changeTracker.getUnpushedChanges())
            .map((c) => c.id)
            .toSet(),
        originalPending);

    final bill = await (phone.db.select(phone.db.transactions)
          ..where((r) => r.ledgerId.equals(ledgerId))
          ..limit(1))
        .getSingle();
    await phone.repo.updateTransaction(
        id: bill.id,
        type: bill.type,
        amount: bill.amount + 1,
        note: 'Pending local edit',
        currencyCode: bill.currencyCode,
        nativeAmount: bill.nativeAmount);
    await expectLater(
        phone.engine.downloadAndRestoreToCurrentLedger(ledgerId: ledgerId),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'reason', contains('unpushed'))));
    expect((await phone.repo.getTransactionById(bill.id))!.note,
        'Pending local edit');
    await fixture.assertRemote(server.get);
    return {
      'seedMethod':
          'Web writes for ledgers, dictionaries, budgets and transaction batches',
      'transactions': fixture.transactions.length,
      'categories': fixture.categories.length,
      'accounts': fixture.accounts.length,
      'tags': fixture.tags.length,
      'budgets': fixture.budgets.length,
      'ledgers': fixture.ledgers.length,
      'defaultStartup': defaultStartup,
      'withoutCurrentLedger': unselectedStartup,
      'manualWithOtherLocalLedger': {
        'addedToTarget': first.inserted,
        'addedOnRepeat': repeated.inserted,
        'untouchedLocalQueueEntries': originalPending.length,
        'pendingTargetEditPreserved': true
      }
    };
  } finally {
    await phone.close();
  }
}

void configurePullHostChannels(bool enabled) {
  for (final channel in [
    'dev.fluttercommunity.plus/connectivity',
    'dev.fluttercommunity.plus/connectivity_status'
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            MethodChannel(channel), enabled ? (call) async => null : null);
  }
}
