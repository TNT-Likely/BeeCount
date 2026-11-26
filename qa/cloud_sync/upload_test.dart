import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fixture.dart';
import 'fixture_client.dart';

typedef _Exercise = Future<void> Function(FixtureCloud service, FixtureDevice a,
    RichLedgerFixture fixture, Map<String, dynamic> result);

Future<void> _scenario(String name, _Exercise run) async {
  final env = Platform.environment;
  final seed = int.parse(env['CLOUD_SYNC_QA_SEED'] ?? '20261126');
  final count = int.parse(env['CLOUD_SYNC_QA_TRANSACTIONS'] ?? '1200');
  final f = RichLedgerFixture.generate(
      namespace: '$name-${DateTime.now().microsecondsSinceEpoch}',
      seed: seed,
      transactionCount: count);
  final result = <String, dynamic>{
    'case': name,
    'seed': seed,
    'transactions': count,
    'representatives': count < 48 ? count : 48,
    'generated': count > 48 ? count - 48 : 0,
    'app_sha': env['CLOUD_SYNC_QA_APP_SHA'],
    'status': 'FAIL'
  };
  final sampleIds = {
    for (final key in f.transactions.keys.take(48)) f.aliases[key]!: key
  };
  result['representative_sync_ids'] = sampleIds;
  Map<String, int> distribution(String Function(FixtureRow row) group) {
    final totals = <String, int>{};
    for (final row in f.transactions.values) {
      totals.update(group(row), (n) => n + 1, ifAbsent: () => 1);
    }
    return totals;
  }

  result['distribution'] = {
    'transaction_types': distribution((r) => r['type']),
    'currencies': distribution((r) => r['currencyCode']),
    'tag_count': distribution((r) => (r['tagIds'] as List).length.toString()),
    'excluded_from_stats': f.transactions.values
        .where((r) => r['excludeFromStats'] == true)
        .length,
    'excluded_from_budget': f.transactions.values
        .where((r) => r['excludeFromBudget'] == true)
        .length,
  };
  final watch = Stopwatch()..start();
  try {
    final service = await FixtureCloud.create(name);
    result.addAll({
      'cloud_sha': service.identity['cloud_sha'],
      'database': service.identity['database'],
      'session_timezone': service.identity['session_timezone']
    });
    final a = await service.device();
    addTearDown(a.close);
    await f.seedLocal(a.db);
    expect(await a.tracker.getUnpushedCount(), 0);
    await f.assertLocal(a.db);
    await run(service, a, f, result);
    result['current_period_budget_sentinel'] =
        await _currentBudgetSentinel(service, a, f);
    result['status'] = 'PASS';
  } catch (e) {
    final summary = e is http.ClientException
        ? 'HTTP ${e.uri?.path}: ${e.message}'
        : e.toString().replaceAll(RegExp(r'https?://[^\s,)]+'), '<QA service>');
    final brief = summary.split('\n').take(2).join(' ');
    result['first_difference'] =
        brief.length > 550 ? brief.substring(0, 550) : brief;
    rethrow;
  } finally {
    result['elapsed_ms'] = watch.elapsedMilliseconds;
    if (name == 'full-upload') {
      result['host_test_process_max_rss_bytes'] = ProcessInfo.maxRss;
    }
    final output = env['CLOUD_SYNC_QA_OUTPUT'];
    if (output != null) {
      final dir = Directory(output)..createSync(recursive: true);
      File('${dir.path}/$name.json').writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(result)}\n');
    }
  }
}

Future<Map<String, int>> _initial(FixtureDevice a, RichLedgerFixture f) async {
  expect(await a.provider.storage.list(path: ''), isEmpty);
  final receipts = <String, int>{};
  for (final ledger in f.ledgers.keys) {
    final key = await a.ledger(ledger);
    final result = await a.engine.sync(ledgerId: '$key');
    expect(result.error, isNull);
    expect(result.conflicts, 0);
    expect(result.pushed, greaterThan(0));
    receipts[f.aliases[ledger]!] = result.pushed;
  }
  expect(await a.tracker.getUnpushedCount(), 0);
  final books = await a.provider.storage.list(path: '');
  expect(books.map((book) => book.path), unorderedEquals(f.ledgers.keys));
  return receipts;
}

Future<Map<String, dynamic>> _currentBudgetSentinel(
    FixtureCloud service, FixtureDevice a, RichLedgerFixture f) async {
  // The reference data is fixed. This separate ledger follows the current month
  // because the Web usage endpoint always queries its current reporting period.
  final now = DateTime.now().toUtc();
  final stamp = DateTime.utc(now.year, now.month, 15, 12);
  final book = await a.repo.createLedger(name: 'QA current-period budget');
  final bookKey = (await a.repo.getLedgerById(book))!.syncId!;
  final cats = {
    for (final c in await a.db.select(a.db.categories).get()) c.syncId: c.id
  };
  final accounts = {
    for (final v in await a.db.select(a.db.accounts).get()) v.syncId: v.id
  };
  final total =
      await a.repo.createBudget(ledgerId: book, type: 'total', amount: 500);
  final food = await a.repo.createBudget(
      ledgerId: book,
      type: 'category',
      categoryId: cats[f.id('food')],
      amount: 120);
  for (final (
        type,
        category,
        account,
        amount,
        currency,
        native,
        excludeBudget,
        excludeStats
      ) in [
    ('expense', 'breakfast', 'usd', 10.0, 'USD', 72.0, false, false),
    ('expense', 'books', 'cash', 3.25, 'CNY', 3.25, false, true),
    ('expense', 'dinner', 'cash', 9.0, 'CNY', 9.0, true, false),
    ('income', 'salary', 'bank', 40.0, 'CNY', 40.0, false, false),
    ('transfer', null, 'bank', 20.0, 'CNY', 20.0, false, false),
  ]) {
    await a.repo.addTransaction(
        ledgerId: book,
        type: type,
        amount: amount,
        currencyCode: currency,
        nativeAmount: native,
        accountId: accounts[f.id(account)],
        toAccountId: type == 'transfer' ? accounts[f.id('cash')] : null,
        categoryId: category == null ? null : cats[f.id(category)],
        excludeFromBudget: excludeBudget,
        excludeFromStats: excludeStats,
        happenedAt: stamp);
  }
  final result = await a.engine.sync(ledgerId: '$book');
  expect(result.error, isNull);
  final budgets = await (a.db.select(a.db.budgets)
        ..where((b) => b.ledgerId.equals(book)))
      .get();
  final expected = {
    for (final b in budgets) b.syncId: b.id == total ? 75.25 : 72.0
  };
  final response =
      await service.get('/api/v1/read/ledgers/$bookKey/budgets/usage');
  final observed = {
    for (final b in response['items']) b['budget_id']: b['used']
  };
  expect(observed, expected);
  expect((await a.repo.getBudgetUsage(total, stamp.toLocal())).used, 75.25);
  expect((await a.repo.getBudgetUsage(food, stamp.toLocal())).used, 72.0);
  return {
    'period': stamp.toIso8601String().substring(0, 7),
    'transaction_count': 5,
    'total_web_and_app': 75.25,
    'food_parent_web_and_app': 72.0
  };
}

Future<void> _incremental(FixtureCloud service, FixtureDevice a,
    RichLedgerFixture f, Map<String, dynamic> r) async {
  await _initial(a, f);
  await f.assertRemote(service.get);
  final baseline = await service.eventsAfter(0);
  final b = await service.device();
  addTearDown(b.close);
  await b.engine.syncLedgersFromServer();
  for (final key in f.ledgers.keys) {
    await b.engine
        .downloadAndRestoreToCurrentLedger(ledgerId: await b.ledger(key));
  }
  await f.assertLocal(b.db);
  final categoryRows = await a.db.select(a.db.categories).get();
  final cats = {for (final c in categoryRows) c.syncId: c.id};
  final localTags = await a.db.select(a.db.tags).get();
  final tags = {for (final t in localTags) t.syncId: t.id};
  final transactionRows = await a.db.select(a.db.transactions).get();
  final txIds = {for (final t in transactionRows) t.syncId: t.id};
  final accountRows = await a.db.select(a.db.accounts).get();
  final accounts = {for (final t in accountRows) t.syncId: t.id};
  final ledgerKeys = {
    for (final b in await a.db.select(a.db.ledgers).get()) b.syncId: b.id
  };
  final expected = <String, String>{};
  void will(String type, String alias, [String action = 'upsert']) {
    expected['$type/${f.id(alias)}'] = action;
  }

  for (final (alias, name) in [('food', '餐饮（已改名）'), ('metro', '城市地铁')]) {
    final key = f.id(alias);
    await a.repo.updateCategory(cats[key]!, name: name);
    f.categories[key]!['name'] = name;
    will('category', alias);
  }
  final sorted = f.id('dinner');
  await a.repo.updateCategorySortOrders([(id: cats[sorted]!, sortOrder: 31)]);
  f.categories[sorted]!['sortOrder'] = 31;
  will('category', 'dinner');
  final unused = f.id('unused');
  expect(f.transactions.values.any((v) => v['categoryId'] == unused), false);
  await a.repo.deleteCategory(cats[unused]!);
  f.categories.remove(unused);
  will('category', 'unused', 'delete');
  final property = f.id('property');
  await a.repo.updateAccountValuation(accounts[property]!, 832123.45);
  f.accounts[property]!['initialBalance'] = 832123.45;
  will('account', 'property');
  final budget = f.id('main-budget-food');
  final budgetRow = await (a.db.select(a.db.budgets)
        ..where((b) => b.syncId.equals(budget)))
      .getSingle();
  await a.repo.updateBudget(budgetRow.id, amount: 1732.25);
  f.budgets[budget]!['amount'] = 1732.25;
  will('budget', 'main-budget-food');
  final removed = f.id('pharmacy');
  await a.repo.deleteTransaction(txIds[removed]!);
  f.transactions.remove(removed);
  will('transaction', 'pharmacy', 'delete');
  final edited = f.transactions[f.id('rent-month-end')]!;
  await a.repo.updateTransaction(
      id: txIds[edited['syncId']]!,
      type: 'expense',
      amount: 1380.52,
      note: 'QA 账租金修订',
      categoryId: cats[edited['categoryId']],
      accountId: accounts[edited['accountId']],
      currencyCode: 'CNY',
      nativeAmount: 1380.52);
  edited
      .addAll({'amount': 1380.52, 'nativeAmount': 1380.52, 'note': 'QA 账租金修订'});
  will('transaction', 'rent-month-end');
  final added = f.id('added-locally'),
      main = f.id('main'),
      cash = f.id('cash'),
      meal = f.id('dinner');
  final when = DateTime.utc(2026, 11, 3, 12, 55);
  await a.repo.addTransaction(
      ledgerId: ledgerKeys[main]!,
      type: 'expense',
      categoryId: cats[meal],
      accountId: accounts[cash],
      amount: 53.60,
      nativeAmount: 53.60,
      currencyCode: 'CNY',
      note: 'QA 新增',
      happenedAt: when,
      syncId: added);
  f.transactions[added] = {
    'syncId': added,
    'ledgerId': main,
    'type': 'expense',
    'amount': 53.60,
    'nativeAmount': 53.60,
    'currencyCode': 'CNY',
    'categoryId': meal,
    'accountId': cash,
    'toAccountId': null,
    'note': 'QA 新增',
    'happenedAt': when.toIso8601String(),
    'excludeFromStats': false,
    'excludeFromBudget': false,
    'tagIds': <String>[]
  };
  will('transaction', 'added-locally');
  for (final (alias, values) in [
    ('breakfast-01', ['tag-trip']), // Remove one of two.
    ('single-tag', <String>[]), // Clear the last one.
    ('dinner-no-note', ['tag-family']), // Add to previously untagged.
    (
      'train-travel',
      ['tag-personal', 'tag-online']
    ), // Replace all existing tags.
  ]) {
    final key = f.id(alias);
    final ids = values.map(f.id).toList()..sort();
    await a.repo.updateTransactionTags(
        transactionId: txIds[key]!,
        tagIds: ids.map((id) => tags[id]!).toList());
    f.transactions[key]!['tagIds'] = ids;
    will('transaction', alias);
  }
  final pending = await a.tracker.getUnpushedCount();
  expect(pending, expected.length);
  for (final book in f.ledgers.keys) {
    await a.engine.uploadCurrentLedger(ledgerId: ledgerKeys[book]!);
  }
  final phase = await service.eventsAfter(baseline.cursor);
  f.assertEvents('Cloud incremental journal', expected, phase.events);
  await f.assertRemote(service.get);
  await f.assertLocal(a.db);
  r.addAll({
    'initial_pending': pending,
    'incremental_events': phase.events.length,
    'changed_ids': expected.length,
    'unchanged_transaction_ids': f.transactions.length - 6,
    'phase_before_deleting_tag': 'PASS'
  });

  // Removing a tag entity also removes its real transaction relationships on both books.
  final retired = f.id('tag-personal');
  final affected = f.transactions.values
      .where((v) => (v['tagIds'] as List).contains(retired))
      .toList();
  expect(affected, isNotEmpty);
  await a.repo.deleteTag(tags[retired]!);
  f.tags.remove(retired);
  for (final tx in affected) {
    (tx['tagIds'] as List).remove(retired);
  }
  for (final book in f.ledgers.keys) {
    await a.engine.uploadCurrentLedger(ledgerId: ledgerKeys[book]!);
  }
  final cascade = await service.eventsAfter(phase.cursor);
  final affectedIds = affected.map((t) => t['syncId']).toSet();
  final cascadeActions = {'tag/$retired': 'delete'};
  for (final event in cascade.events) {
    final id = event['entity_sync_id'];
    if (affectedIds.contains(id)) {
      cascadeActions['transaction/$id'] = 'upsert';
    }
  }
  f.assertEvents('Cloud tag removal', cascadeActions, cascade.events);
  await f.assertLocal(a.db);
  await f.assertRemote(service.get);
  await b.engine.pull('');
  await f.assertLocal(b.db);
  for (final book in f.ledgers.keys) {
    await a.engine.uploadCurrentLedger(ledgerId: ledgerKeys[book]!);
  }
  final noOp = await service.eventsAfter(cascade.cursor);
  expect(noOp.events, isEmpty);
  expect(await a.tracker.getUnpushedCount(), 0);
  r.addAll({
    'removed_tag_references': affected.length,
    'tag_delete_events': cascade.events.length,
    'repeat_events': noOp.events.length,
    'pending_after': await a.tracker.getUnpushedCount(),
    'transaction_ids_checked': f.transactions.length,
    'ledger_count': f.ledgers.length
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  test(
      'full-upload',
      () => _scenario('full-upload', (service, a, f, r) async {
            r['initial_pending'] = 0;
            final uploadClock = Stopwatch()..start();
            r['entity_receipts'] = await _initial(a, f);
            r['full_upload_ms'] = uploadClock.elapsedMilliseconds;
            await f.assertRemote(service.get);
            final before = await service.eventsAfter(0);
            f.assertEvents(
                'Full upload transactions',
                {
                  for (final id in f.transactions.keys)
                    'transaction/$id': 'upsert'
                },
                before.events.where((e) => e['entity_type'] == 'transaction'));
            final eventCounts = <String, int>{};
            for (final event in before.events) {
              eventCounts.update(event['entity_type'] as String, (n) => n + 1,
                  ifAbsent: () => 1);
            }
            r['remote_events_by_type'] = eventCounts;
            final b = await service.device();
            addTearDown(b.close);
            expect(await b.db.select(b.db.transactions).get(), isEmpty);
            final recoveryClock = Stopwatch()..start();
            await b.engine.syncLedgersFromServer();
            final inserted = <String, int>{};
            for (final ledger in f.ledgers.keys) {
              final result = await b.engine.downloadAndRestoreToCurrentLedger(
                  ledgerId: await b.ledger(ledger));
              inserted[f.aliases[ledger]!] = result.inserted;
            }
            r['cold_restore_ms'] = recoveryClock.elapsedMilliseconds;
            await f.assertLocal(b.db);
            await f.assertLocal(a.db);
            for (final ledger in f.ledgers.keys) {
              final result =
                  await a.engine.sync(ledgerId: '${await a.ledger(ledger)}');
              expect(result.error, isNull);
              expect(result.pushed, 0);
            }
            final after = await service.eventsAfter(before.cursor);
            expect(after.events, isEmpty);
            expect(await a.tracker.getUnpushedCount(), 0);
            expect(await b.tracker.getUnpushedCount(), 0);
            r.addAll({
              'remote_events': before.events.length,
              'cold_device_inserted': inserted,
              'account_count': f.accounts.length,
              'category_count': f.categories.length,
              'tag_count': f.tags.length,
              'budgets': f.budgets.length,
              'ledger_count': f.ledgers.length,
              'transaction_ids_checked': f.transactions.length,
              'repeat_events': after.events.length,
              'pending_after': await a.tracker.getUnpushedCount()
            });
          }),
      timeout: Timeout(Duration(
          minutes: int.parse(
                      Platform.environment['CLOUD_SYNC_QA_TRANSACTIONS'] ??
                          '1200') >
                  5000
              ? 90
              : 12)));
  test(
      'incremental-upload', () => _scenario('incremental-upload', _incremental),
      timeout: const Timeout(Duration(minutes: 12)));
}
