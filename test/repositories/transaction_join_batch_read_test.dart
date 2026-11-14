import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_transaction_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Row = ({
  Transaction t,
  Category? category,
  Account? account,
  Account? toAccount
});

class _Metrics extends d.QueryInterceptor {
  int calls = 0, cells = 0, baseReads = 0, maxBindings = 0;
  int selectMicros = 0;
  Completer<void>? entered, release;
  bool blockNextBase = false, failNextBase = false;

  void reset() => calls = cells = baseReads = maxBindings = selectMicros = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
      d.QueryExecutor executor, String statement, List<Object?> args) async {
    final isBase =
        RegExp(r'FROM ["`]?transactions["`]?(?:\s|$)', caseSensitive: false)
                .hasMatch(statement) &&
            !statement.contains('JOIN');
    if (isBase && failNextBase) {
      failNextBase = false;
      throw StateError('synthetic read failure');
    }
    final watch = Stopwatch()..start();
    final result = await executor.runSelect(statement, args);
    selectMicros += watch.elapsedMicroseconds;
    calls++;
    cells += result.fold(0, (n, row) => n + row.length);
    if (args.length > maxBindings) maxBindings = args.length;
    if (isBase) {
      baseReads++;
      if (blockNextBase) {
        blockNextBase = false;
        entered!.complete();
        await release!.future;
      }
    }
    return result;
  }

  void block() {
    entered = Completer<void>();
    release = Completer<void>();
    blockNextBase = true;
  }
}

Future<void> seed(BeeDatabase db, int count) async {
  await db.customStatement(
      "INSERT INTO ledgers(id,name,currency,sync_id) VALUES(1,'QA one','CNY','book-1'),(2,'QA two','USD','book-2')");
  await db.customStatement(
      '''WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM n WHERE x<12)
INSERT INTO categories(id,name,kind,icon,sync_id) SELECT x,'QA category '||x,'expense','restaurant','category-'||x FROM n''');
  await db.customStatement(
      '''WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM n WHERE x<8)
INSERT INTO accounts(id,ledger_id,name,type,currency,hidden,note,sync_id)
SELECT x,99,'QA account '||x,'credit',CASE WHEN x%2=0 THEN 'USD' ELSE 'CNY' END,x%2,'historical account','account-'||x FROM n''');
  await db.customStatement(
      '''WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM n WHERE x<?)
INSERT INTO transactions(id,ledger_id,type,amount,category_id,account_id,to_account_id,happened_at,note,sync_id,
 currency_code,native_amount,exclude_from_stats,exclude_from_budget,recurring_id,created_by_user_id,last_edited_by_user_id)
SELECT x,1,CASE WHEN x%7=0 THEN 'transfer' WHEN x%5=0 THEN 'income' ELSE 'expense' END,x/10.0,
 CASE WHEN x%13=0 THEN NULL WHEN x%17=0 THEN -999 ELSE 1+(x%12) END,
 CASE WHEN x%11=0 THEN NULL WHEN x%19=0 THEN 99999 ELSE 1+(x%8) END,
 CASE WHEN x%7=0 THEN 1+((x+2)%8) ELSE NULL END,
 1792022400+(x%5),'QA note '||x,'tx-'||x,'USD',x*0.7,x%2,x%3=0,x%4,'qa-author','qa-editor' FROM n''',
      [count]);
  await db.customStatement(
      "INSERT INTO transactions(id,ledger_id,type,amount,happened_at,sync_id) VALUES(200001,2,'expense',1,1792022400,'other-book')");
}

Future<void> shared(BeeDatabase db) async {
  await db.customStatement(
      "INSERT INTO shared_ledger_categories(ledger_sync_id,sync_id,name,kind,icon_type,icon_cloud_sha256,updated_at) VALUES('book-1','shared-category','QA shared category','expense','custom','abcdef',1792022400),('book-2','shared-category','QA shared later','expense','material',NULL,1792022401)");
  await db.customStatement(
      "INSERT INTO shared_ledger_accounts(ledger_sync_id,sync_id,name,account_type,currency,note,credit_limit,updated_at) VALUES('book-1','shared-account','QA shared account','credit','JPY','QA shared note',500,1792022400)");
  await db.customStatement(
      "UPDATE transactions SET category_sync_id_override='shared-category',account_sync_id_override='shared-account',to_account_sync_id_override='shared-account' WHERE id%13=0 OR id%19=0");
}

/// The unmodified production range query uses the original full JOIN and exact
/// existing shared hydration. For unscoped ordering, run that same original JOIN
/// across ledgers and use production range results as each record's oracle.
Future<List<Row>> oldJoin(
    BeeDatabase db, LocalTransactionRepository repo, int? ledger) async {
  Future<List<Row>> range(int id) => repo.getTransactionsWithCategoryInRange(
      ledgerId: id, start: DateTime.utc(1970), end: DateTime.utc(2100));
  if (ledger != null) return range(ledger);
  final from = db.alias(db.accounts, 'from_account');
  final to = db.alias(db.accounts, 'to_account');
  final base = db.select(db.transactions)
    ..orderBy([
      (t) => d.OrderingTerm(expression: t.happenedAt, mode: d.OrderingMode.desc)
    ]);
  final original = await base.join([
    d.leftOuterJoin(
        db.categories, db.categories.id.equalsExp(db.transactions.categoryId)),
    d.leftOuterJoin(from, from.id.equalsExp(db.transactions.accountId)),
    d.leftOuterJoin(to, to.id.equalsExp(db.transactions.toAccountId)),
  ]).get();
  final records = <int, Row>{};
  for (final id
      in original.map((r) => r.readTable(db.transactions).ledgerId).toSet()) {
    for (final row in await range(id)) {
      records[row.t.id] = row;
    }
  }
  return [
    for (final row in original) records[row.readTable(db.transactions).id]!
  ];
}

String hashRows(List<Row> rows) => sha256
    .convert(utf8.encode(jsonEncode([
      for (final row in rows)
        {
          'transaction': row.t.toJson(),
          'category': row.category?.toJson(),
          'account': row.account?.toJson(),
          'toAccount': row.toAccount?.toJson()
        }
    ])))
    .toString();

Future<String> allTables(BeeDatabase db) async {
  final tables = await db
      .customSelect(
          "SELECT name,sql FROM sqlite_master WHERE type='table' ORDER BY name")
      .get();
  final result = <String, Object?>{};
  for (final table in tables) {
    final name = table.read<String>('name');
    final escaped = name.replaceAll('"', '""');
    result[name] = (await db.customSelect('SELECT * FROM "$escaped"').get())
        .map((r) => r.data)
        .toList();
  }
  return sha256.convert(utf8.encode(jsonEncode(result))).toString();
}

Future<void> drain() => pumpEventQueue(times: 20);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late LocalTransactionRepository repo;
  late _Metrics metrics;
  var explicitlyClosed = false;
  group('live all-list snapshots', () {
    setUp(() {
      explicitlyClosed = false;
      metrics = _Metrics();
      db = BeeDatabase.forTesting(
          NativeDatabase.memory().interceptWith(metrics));
      repo = LocalTransactionRepository(db);
    });
    tearDown(() async {
      if (!explicitlyClosed) await db.close();
    });

    test(
        'exact original JOIN values/order: NULL, missing/negative ID, hidden, currency, transfer and shared overrides',
        () async {
      await seed(db, 120);
      await shared(db);
      final before = await allTables(db);
      for (final scope in <int?>[1, 2, null, 999]) {
        final old = await oldJoin(db, repo, scope);
        final current =
            await repo.watchTransactionsWithCategoryAll(ledgerId: scope).first;
        expect(current, old);
        expect(hashRows(current), hashRows(old));
        expect(current.map((r) => r.t.id), old.map((r) => r.t.id));
      }
      expect(await allTables(db), before,
          reason: 'every stored table must be read-only');
    });

    test(
        'all five tables invalidate, including filling missing references and shared mirrors',
        () async {
      await seed(db, 26);
      await shared(db);
      final events = <List<Row>>[];
      final subscription =
          repo.watchTransactionsWithCategoryAll(ledgerId: 1).listen(events.add);
      addTearDown(subscription.cancel);
      Future<List<Row>> nextAfter(Future<void> Function() mutate) async {
        final oldCount = events.length;
        await mutate();
        for (var i = 0; i < 100 && events.length == oldCount; i++) {
          await drain();
        }
        expect(events.length, greaterThan(oldCount));
        expect(events.last, await oldJoin(db, repo, 1));
        return events.last;
      }

      await drain();
      expect(events, isNotEmpty);
      await nextAfter(() async => db.update(db.categories).write(
          const CategoriesCompanion(name: d.Value('QA renamed category'))));
      await nextAfter(() async => db.update(db.accounts).write(
          const AccountsCompanion(
              name: d.Value('QA renamed account'), hidden: d.Value(true))));
      await nextAfter(() async => db.update(db.sharedLedgerCategories).write(
          const SharedLedgerCategoriesCompanion(
              name: d.Value('QA shared renamed'))));
      await nextAfter(() async => db.update(db.sharedLedgerAccounts).write(
          const SharedLedgerAccountsCompanion(
              name: d.Value('QA shared account renamed'))));
      await nextAfter(() async => db.update(db.transactions).write(
          const TransactionsCompanion(note: d.Value('QA changed note'))));
      await nextAfter(() async => db.into(db.categories).insert(
          CategoriesCompanion.insert(
              id: const d.Value(-999),
              name: 'QA formerly missing',
              kind: 'expense')));
      await nextAfter(() async => db.into(db.accounts).insert(
          AccountsCompanion.insert(
              id: const d.Value(99999),
              ledgerId: 99,
              name: 'QA formerly missing account')));
      await nextAfter(() async => db.delete(db.sharedLedgerCategories).go());
    });

    test(
        'simultaneous and late first/last subscribers replay independently, then evict when unused',
        () async {
      await seed(db, 50);
      metrics.reset();
      final stream = repo.watchTransactionsWithCategoryAll(ledgerId: 1);
      final events = <List<Row>>[];
      final subscription = stream.listen(events.add);
      addTearDown(subscription.cancel);
      final first =
          await repo.watchTransactionsWithCategoryAll(ledgerId: 1).first;
      await drain();
      expect(metrics.baseReads, 1);
      first.clear();
      expect(events.single, hasLength(50));
      final late = await stream.first;
      expect(late, hasLength(50));
      expect(metrics.baseReads, 1);
      final lastOfTwo = stream.take(2).last;
      await drain();
      await db
          .update(db.transactions)
          .write(const TransactionsCompanion(note: d.Value('QA next')));
      expect((await lastOfTwo).every((r) => r.t.note == 'QA next'), isTrue);
      await subscription.cancel();
      await drain();
      final prior = metrics.baseReads;
      expect(await stream.first, hasLength(50));
      expect(metrics.baseReads, prior + 1);
    });

    test(
        'in-flight cancellation stops remaining batches; rapid invalidations coalesce without stale publish',
        () async {
      await seed(db, 60);
      metrics.reset();
      metrics.block();
      final events = <List<Row>>[];
      final subscription =
          repo.watchTransactionsWithCategoryAll(ledgerId: 1).listen(events.add);
      await metrics.entered!.future;
      await subscription.cancel();
      metrics.release!.complete();
      await db.customSelect('SELECT 1').get();
      await drain();
      expect(events, isEmpty);
      metrics.reset();
      metrics.block();
      final result = repo.watchTransactionsWithCategoryAll(ledgerId: 1).first;
      await metrics.entered!.future;
      for (var i = 0; i < 30; i++) {
        db.markTablesUpdated({db.categories, db.accounts});
      }
      await drain();
      metrics.release!.complete();
      expect(await result, await oldJoin(db, repo, 1));
      expect(metrics.baseReads, 2,
          reason:
              'one stale read, then one final read, never 30 concurrent loads');
    });

    test(
        'read transaction never assembles a mixture while an atomic multi-table write is pending',
        () async {
      await seed(db, 26);
      await shared(db);
      await db
          .update(db.transactions)
          .write(const TransactionsCompanion(note: d.Value('before')));
      await db
          .update(db.categories)
          .write(const CategoriesCompanion(name: d.Value('before')));
      await db
          .update(db.accounts)
          .write(const AccountsCompanion(name: d.Value('before')));
      await db.update(db.sharedLedgerCategories).write(
          const SharedLedgerCategoriesCompanion(name: d.Value('before')));
      await db
          .update(db.sharedLedgerAccounts)
          .write(const SharedLedgerAccountsCompanion(name: d.Value('before')));
      metrics.block();
      final events = <List<Row>>[];
      final sub =
          repo.watchTransactionsWithCategoryAll(ledgerId: 1).listen(events.add);
      addTearDown(sub.cancel);
      await metrics.entered!.future;
      final writer = db.transaction(() async {
        await db
            .update(db.transactions)
            .write(const TransactionsCompanion(note: d.Value('after')));
        await db
            .update(db.categories)
            .write(const CategoriesCompanion(name: d.Value('after')));
        await db
            .update(db.accounts)
            .write(const AccountsCompanion(name: d.Value('after')));
        await db.update(db.sharedLedgerCategories).write(
            const SharedLedgerCategoriesCompanion(name: d.Value('after')));
        await db
            .update(db.sharedLedgerAccounts)
            .write(const SharedLedgerAccountsCompanion(name: d.Value('after')));
      });
      metrics.release!.complete();
      await writer;
      for (var i = 0;
          i < 100 && (events.isEmpty || events.last.first.t.note != 'after');
          i++) {
        await drain();
      }
      expect(events, isNotEmpty);
      expect(events.last.first.t.note, 'after');
      for (final rows in events) {
        for (final row in rows) {
          expect(row.category?.name == null || row.category!.name == row.t.note,
              isTrue);
          expect(row.account?.name == null || row.account!.name == row.t.note,
              isTrue);
          expect(
              row.toAccount?.name == null || row.toAccount!.name == row.t.note,
              isTrue);
        }
      }
    });

    test(
        'load errors are forwarded; later update and a new subscriber can recover',
        () async {
      await seed(db, 4);
      metrics.failNextBase = true;
      final failures = <Object>[];
      final events = <List<Row>>[];
      final sub = repo
          .watchTransactionsWithCategoryAll(ledgerId: 1)
          .listen(events.add, onError: failures.add);
      addTearDown(sub.cancel);
      await drain();
      expect(failures, hasLength(1));
      db.markTablesUpdated({db.transactions});
      for (var i = 0; i < 100 && events.isEmpty; i++) {
        await drain();
      }
      expect(events.single, hasLength(4));
      expect(await repo.watchTransactionsWithCategoryAll(ledgerId: 1).first,
          events.single);
    });

    test('more than 400 unique references are bounded without dropping rows',
        () async {
      await seed(db, 1301);
      await db.customStatement(
          '''WITH RECURSIVE n(x) AS (SELECT 13 UNION ALL SELECT x+1 FROM n WHERE x<1301)
INSERT INTO categories(id,name,kind,sync_id) SELECT x,'QA unique category '||x,'expense','unique-category-'||x FROM n''');
      await db.customStatement(
          '''WITH RECURSIVE n(x) AS (SELECT 9 UNION ALL SELECT x+1 FROM n WHERE x<1301)
INSERT INTO accounts(id,ledger_id,name,sync_id) SELECT x,99,'QA unique account '||x,'unique-account-'||x FROM n''');
      await db.customStatement(
          'UPDATE transactions SET category_id=id,account_id=id,to_account_id=1302-id WHERE ledger_id=1');
      final oracle = await oldJoin(db, repo, 1);
      metrics.reset();
      final candidate =
          await repo.watchTransactionsWithCategoryAll(ledgerId: 1).first;
      expect(candidate, oracle);
      expect(metrics.maxBindings, 400);
      expect(candidate, hasLength(1301));
    });

    test('late first cannot replay a cache invalidated in the same event turn',
        () async {
      await seed(db, 4);
      final hold =
          repo.watchTransactionsWithCategoryAll(ledgerId: 1).listen((_) {});
      addTearDown(hold.cancel);
      await repo.watchTransactionsWithCategoryAll(ledgerId: 1).first;
      metrics.block();
      db.markTablesUpdated({db.categories});
      var completed = false;
      final late =
          repo.watchTransactionsWithCategoryAll(ledgerId: 1).first.then((rows) {
        completed = true;
        return rows;
      });
      await metrics.entered!.future;
      await drain();
      expect(completed, isFalse,
          reason:
              'wait for the invalidated read; never publish the old cached rows');
      metrics.release!.complete();
      expect(await late, hasLength(4));
    });

    test(
        'cancel A then concurrently subscribe B and fresh A keeps each scope isolated',
        () async {
      await seed(db, 60);
      metrics.block();
      final oldEvents = <List<Row>>[];
      final old = repo
          .watchTransactionsWithCategoryAll(ledgerId: 1)
          .listen(oldEvents.add);
      await metrics.entered!.future;
      await old.cancel();
      final b = repo.watchTransactionsWithCategoryAll(ledgerId: 2).first;
      final a = repo.watchTransactionsWithCategoryAll(ledgerId: 1).first;
      metrics.release!.complete();
      expect((await b).map((r) => r.t.id), [200001]);
      expect(await a, hasLength(60));
      expect(oldEvents, isEmpty);
    });

    test('database close completes an active last subscriber', () async {
      await seed(db, 4);
      final stream = repo.watchTransactionsWithCategoryAll(ledgerId: 1);
      final last = stream.last;
      expect(await stream.first, hasLength(4));
      await db.close();
      explicitlyClosed = true;
      expect(await last, hasLength(4));
    });
  });

  for (final background in [false, true]) {
    test(
        '15000 strict old-JOIN hash/order and bounded result cells (${background ? 'background SQLite' : 'memory SQLite'})',
        () async {
      final directory =
          await Directory.systemTemp.createTemp('beecount-join-benchmark-');
      final monitor = _Metrics();
      final executor = background
          ? NativeDatabase.createInBackground(
              File('${directory.path}/synthetic.sqlite'))
          : NativeDatabase.memory();
      final database = BeeDatabase.forTesting(executor.interceptWith(monitor));
      try {
        await seed(database, 15000);
        await shared(database);
        final repository = LocalTransactionRepository(database);
        final guard = await allTables(database);
        monitor.reset();
        final oldWatch = Stopwatch()..start();
        final oracle = await oldJoin(database, repository, 1);
        oldWatch.stop();
        final oldMetrics = {
          'elapsedMicros': oldWatch.elapsedMicroseconds,
          'sqlAndTransferMicros': monitor.selectMicros,
          'cells': monitor.cells,
          'queries': monitor.calls
        };
        monitor.reset();
        final newWatch = Stopwatch()..start();
        final candidate = await repository
            .watchTransactionsWithCategoryAll(ledgerId: 1)
            .first;
        newWatch.stop();
        final newMetrics = {
          'elapsedMicros': newWatch.elapsedMicroseconds,
          'sqlAndTransferMicros': monitor.selectMicros,
          'cells': monitor.cells,
          'queries': monitor.calls,
          'maxBindings': monitor.maxBindings
        };
        expect(candidate, oracle);
        expect(hashRows(candidate), hashRows(oracle));
        expect(candidate.map((r) => r.t.id), oracle.map((r) => r.t.id));
        expect(monitor.maxBindings, lessThanOrEqualTo(400));
        expect(monitor.cells, lessThan(330000));
        expect(
            identical(candidate.firstWhere((r) => r.t.id == 1).account,
                candidate.firstWhere((r) => r.t.id == 9).account),
            isTrue);
        // Reverse the second pair to expose warm-cache/JIT order effects.
        monitor.reset();
        final reverseNewWatch = Stopwatch()..start();
        final reverseCandidate = await repository
            .watchTransactionsWithCategoryAll(ledgerId: 1)
            .first;
        reverseNewWatch.stop();
        final reverseNew = {
          'elapsedMicros': reverseNewWatch.elapsedMicroseconds,
          'sqlAndTransferMicros': monitor.selectMicros,
          'cells': monitor.cells,
          'queries': monitor.calls
        };
        monitor.reset();
        final reverseOldWatch = Stopwatch()..start();
        final reverseOracle = await oldJoin(database, repository, 1);
        reverseOldWatch.stop();
        final reverseOld = {
          'elapsedMicros': reverseOldWatch.elapsedMicroseconds,
          'sqlAndTransferMicros': monitor.selectMicros,
          'cells': monitor.cells,
          'queries': monitor.calls
        };
        expect(reverseCandidate, reverseOracle);
        expect(hashRows(reverseCandidate), hashRows(oracle));
        expect(await allTables(database), guard);
        final result = {
          'kind': background ? 'background' : 'memory',
          'rows': candidate.length,
          'oracleHash': hashRows(oracle),
          'candidateHash': hashRows(candidate),
          'old': oldMetrics,
          'candidate': newMetrics,
          'reversePair': {'candidate': reverseNew, 'old': reverseOld},
          'actualDeviceAot': 'not executed'
        };
        // Synthetic repository-only measurements are retained by the QA runner.
        // ignore: avoid_print
        print('JOIN_BATCH_BENCHMARK ${jsonEncode(result)}');
        final report = Platform.environment['BEECOUNT_JOIN_BENCHMARK_REPORT'];
        if (report != null) {
          await File(report)
              .writeAsString('${jsonEncode(result)}\n', mode: FileMode.append);
        }
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
