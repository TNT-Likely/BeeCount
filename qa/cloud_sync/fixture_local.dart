part of 'fixture.dart';

Future<void> _seedFixture(RichLedgerFixture f, BeeDatabase db) async {
  final repo = LocalRepository(
      db); // Local-only historical writes have no change tracker.
  final books = <String, int>{},
      cats = <String, int>{},
      tags = <String, int>{},
      accounts = <String, int>{};
  await db.transaction(() async {
    for (final r in f.ledgers.values) {
      final pk = await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: r['name'],
          currency: Value(r['currency']),
          syncId: Value(r['syncId']),
          monthStartDay: Value(r['monthStartDay'])));
      books[r['syncId']] = pk;
    }
    for (final r in f.categories.values) {
      cats[r['syncId']] = await repo.createCategory(
          name: r['name'],
          kind: r['kind'],
          level: r['level'],
          parentId: cats[r['parentId']],
          sortOrder: r['sortOrder'],
          syncId: r['syncId']);
    }
    for (final r in f.tags.values) {
      tags[r['syncId']] = await repo.createTag(
          name: r['name'],
          color: r['color'],
          sortOrder: r['sortOrder'],
          syncId: r['syncId']);
    }
    for (final r in f.accounts.values) {
      accounts[r['syncId']] = await repo.createAccount(
          ledgerId: books.values.first,
          name: r['name'],
          type: r['type'],
          currency: r['currency'],
          initialBalance: r['initialBalance'],
          syncId: r['syncId']);
    }
    for (final r in f.budgets.values) {
      await db.into(db.budgets).insert(BudgetsCompanion.insert(
          syncId: Value(r['syncId']),
          ledgerId: books[r['ledgerId']]!,
          type: Value(r['type']),
          categoryId: Value(cats[r['categoryId']]),
          amount: r['amount'],
          period: Value(r['period']),
          startDay: Value(r['startDay']),
          enabled: Value(r['enabled'])));
    }
    for (final r in f.transactions.values) {
      final pk = await repo.addTransaction(
          ledgerId: books[r['ledgerId']]!,
          type: r['type'],
          amount: r['amount'],
          accountId: accounts[r['accountId']],
          toAccountId: accounts[r['toAccountId']],
          categoryId: cats[r['categoryId']],
          happenedAt: DateTime.parse(r['happenedAt']),
          note: r['note'],
          syncId: r['syncId'],
          excludeFromStats: r['excludeFromStats'],
          excludeFromBudget: r['excludeFromBudget'],
          currencyCode: r['currencyCode'],
          nativeAmount: r['nativeAmount']);
      final links = (r['tagIds'] as List).map((id) => tags[id]!).toList();
      if (links.isNotEmpty) {
        await repo.updateTransactionTags(transactionId: pk, tagIds: links);
      }
    }
  });
}

Future<void> _checkLocal(RichLedgerFixture f, BeeDatabase db,
    Set<String> selected, bool checkResources) async {
  final repo = LocalRepository(db);
  final books = await db.select(db.ledgers).get();
  final bookKeys = {for (final b in books) b.id: b.syncId};
  final cats = await db.select(db.categories).get();
  final catKeys = {for (final c in cats) c.id: c.syncId};
  final accounts = await db.select(db.accounts).get();
  final accKeys = {for (final a in accounts) a.id: a.syncId};
  final tags = await db.select(db.tags).get();
  final tagKeys = {for (final t in tags) t.id: t.syncId};
  final tagsByTx = <int, List<String>>{};
  for (final edge in await db.select(db.transactionTags).get()) {
    (tagsByTx[edge.transactionId] ??= [])
        .add(tagKeys[edge.tagId] ?? '<missing tag>');
  }
  if (checkResources) {
    f.compare(
        'App categories',
        f.categories,
        cats.map((c) => {
              'syncId': c.syncId,
              'name': c.name,
              'kind': c.kind,
              'level': c.level,
              'sortOrder': c.sortOrder,
              'parentId': catKeys[c.parentId]
            }));
    f.compare(
        'App accounts',
        f.accounts,
        accounts.map((a) => {
              'syncId': a.syncId,
              'name': a.name,
              'type': a.type,
              'currency': a.currency,
              'initialBalance': a.initialBalance
            }));
    f.compare(
        'App tags',
        f.tags,
        tags.map((t) => {
              'syncId': t.syncId,
              'name': t.name,
              'color': t.color,
              'sortOrder': t.sortOrder
            }));
  }
  f.compare(
      'App ledgers',
      {for (final k in selected) k: f.ledgers[k]!},
      books.where((b) => selected.contains(b.syncId)).map((b) => {
            'syncId': b.syncId,
            'name': b.name,
            'currency': b.currency,
            'monthStartDay': b.monthStartDay
          }));
  final allTx = await db.select(db.transactions).get(),
      budgets = await db.select(db.budgets).get();
  for (final book in books.where((b) => selected.contains(b.syncId))) {
    final key = book.syncId!;
    final expected = f.forLedger(f.transactions, key);
    f.compare(
        'App transactions on ${f.aliases[key]}',
        expected,
        allTx.where((t) => t.ledgerId == book.id).map((t) => {
              'syncId': t.syncId,
              'ledgerId': key,
              'type': t.type,
              'amount': t.amount,
              'nativeAmount': t.nativeAmount,
              'currencyCode': t.currencyCode,
              'note': t.note,
              'happenedAt': t.happenedAt.toUtc().toIso8601String(),
              'categoryId': catKeys[t.categoryId],
              'accountId': accKeys[t.accountId],
              'toAccountId': accKeys[t.toAccountId],
              'excludeFromStats': t.excludeFromStats,
              'excludeFromBudget': t.excludeFromBudget,
              'tagIds': (tagsByTx[t.id] ?? <String>[])..sort(),
            }));
    final localBudgets = budgets.where((b) => b.ledgerId == book.id);
    f.compare(
        'App budgets',
        f.forLedger(f.budgets, key),
        localBudgets.map((b) => {
              'syncId': b.syncId,
              'ledgerId': key,
              'amount': b.amount,
              'type': b.type,
              'period': b.period,
              'startDay': b.startDay,
              'enabled': b.enabled,
              'categoryId': catKeys[b.categoryId]
            }));
    final ledgerStats = await repo.getLedgerStats(ledgerId: book.id);
    final net = expected.values.fold<double>(
        0,
        (sum, r) =>
            sum +
            (r['type'] == 'income'
                    ? 1
                    : r['type'] == 'expense'
                        ? -1
                        : 0) *
                (r['nativeAmount'] as num));
    _amount('App ledger balance ${f.aliases[key]}', net, ledgerStats.balance);
    if (ledgerStats.transactionCount != expected.length) {
      throw StateError(
          'App ledger count ${f.aliases[key]}: ${ledgerStats.transactionCount} != ${expected.length}');
    }
    // Use a fixed date in the sample and the ledger-specific reporting period.
    final monthly = DateTime(2026, 11, 23);
    final daily =
        await repo.getDailyTotalsByMonth(ledgerId: book.id, month: monthly);
    final expectedDaily = <String, (double, double)>{};
    for (final t in expected.values) {
      final date = DateTime.parse(t['happenedAt']).toLocal();
      if (date.year != monthly.year || date.month != monthly.month) {
        continue;
      }
      final day = date.toIso8601String().substring(0, 10);
      final (income, expense) = expectedDaily[day] ?? (0.0, 0.0);
      final value = t['excludeFromStats'] == true
          ? 0.0
          : (t['nativeAmount'] as num).toDouble();
      expectedDaily[day] = (
        income + (t['type'] == 'income' ? value : 0.0),
        expense + (t['type'] == 'expense' ? value : 0.0),
      );
    }
    f.compare(
        'App calendar totals ${f.aliases[key]}',
        {
          for (final e in expectedDaily.entries)
            e.key: {
              'syncId': e.key,
              'income': e.value.$1,
              'expense': e.value.$2
            }
        },
        daily.entries.map((e) => {
              'syncId': e.key,
              'income': e.value.$1,
              'expense': e.value.$2,
            }));
    final start = DateTime(monthly.year, monthly.month, book.monthStartDay);
    final end = DateTime(monthly.year, monthly.month + 1, book.monthStartDay);
    for (final budget in localBudgets) {
      final used = await repo.getBudgetUsage(budget.id, monthly);
      final planned =
          _expenseInPeriod(f, expected, catKeys[budget.categoryId], start, end);
      _amount(
          'App budget usage ${f.aliases[budget.syncId]}', planned, used.used);
    }
  }
  // Account balances span both personal ledgers. A device can intentionally hold only one.
  if (checkResources &&
      selected.containsAll(f.ledgers.keys) &&
      allTx.every((t) => selected.contains(bookKeys[t.ledgerId]))) {
    for (final a in accounts) {
      final expected = _accountBalance(f, a.syncId!);
      _amount('App balance ${f.aliases[a.syncId]}', expected,
          await repo.getAccountBalance(a.id));
    }
  }
}

double _accountBalance(RichLedgerFixture f, String account) {
  var balance = (f.accounts[account]!['initialBalance'] as num).toDouble();
  for (final r in f.transactions.values) {
    final value = (r['amount'] as num).toDouble();
    if (r['accountId'] == account) {
      balance += r['type'] == 'income' ? value : -value;
    }
    if (r['type'] == 'transfer' && r['toAccountId'] == account) {
      balance += value;
    }
  }
  return balance;
}

double _expenseInPeriod(RichLedgerFixture f, FixtureRows txs, String? category,
    DateTime start, DateTime end) {
  var total = 0.0;
  for (final tx in txs.values) {
    final timestamp = DateTime.parse(tx['happenedAt']);
    if (tx['type'] != 'expense' ||
        tx['excludeFromBudget'] == true ||
        timestamp.isBefore(start) ||
        !timestamp.isBefore(end)) {
      continue;
    }
    if (category == null ||
        tx['categoryId'] == category ||
        f.categories[tx['categoryId']]?['parentId'] == category) {
      total += tx['nativeAmount'] as num;
    }
  }
  return total;
}

void _amount(String field, double expected, double actual) {
  if ((expected - actual).abs() > 0.00001) {
    throw StateError('$field: expected $expected, observed $actual');
  }
}
