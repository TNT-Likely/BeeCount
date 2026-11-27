part of 'fixture.dart';

Future<void> _checkRemote(RichLedgerFixture f,
    Future<dynamic> Function(String) get, Set<String> requested) async {
  for (final key in requested) {
    final ledger = f.ledgers[key]!, path = '/api/v1/read/ledgers/$key';
    final full = await get('/api/v1/sync/full?ledger_id=$key');
    if (full['snapshot'] == null) {
      throw StateError('Cloud full is missing ${f.aliases[key]} ($key)');
    }
    final snap =
        jsonDecode(full['snapshot']['payload']['content'] as String) as Map;
    f.compare('Cloud ledger snapshot', {
      key: ledger
    }, [
      {
        'syncId': snap['ledgerSyncId'],
        'name': snap['ledgerName'],
        'currency': snap['currency'],
        'monthStartDay': snap['monthStartDay']
      }
    ]);
    final expectedTx = f.forLedger(f.transactions, key),
        expectedBudgets = f.forLedger(f.budgets, key);
    Map<String, dynamic> tx(Map r, bool web) {
      dynamic field(String snapName, String webName) =>
          r[web ? webName : snapName];
      String? ref(dynamic value) =>
          value == null || value == '' ? null : value as String;
      final kind = field('type', 'tx_type'),
          account = ref(field('accountId', 'account_id'));
      final from = ref(field('fromAccountId', 'from_account_id'));
      final key = field('syncId', 'id') as String;
      final tx = expectedTx[key];
      if (tx != null) {
        final expectedNames = (tx['tagIds'] as List)
            .map((id) => f.tags[id]!['name'] as String)
            .toList()
          ..sort();
        final actualNames = web
            ? List<String>.from(r['tags_list'] ?? const [])
            : (r['tags'] as String? ?? '')
                .split(',')
                .map((name) => name.trim())
                .where((name) => name.isNotEmpty)
                .toList();
        actualNames.sort();
        if (!listEquals(actualNames, expectedNames)) {
          throw StateError(
              'Cloud ${web ? "Web" : "snapshot"} ${f.aliases[key] ?? key}.tags: expected $expectedNames, observed $actualNames');
        }
      }
      if (kind == 'transfer' &&
          account != null &&
          from != null &&
          account != from) {
        throw StateError(
            'Cloud transfer ${r['syncId'] ?? r['id']} sources disagree: $from and $account');
      }
      return {
        'syncId': field('syncId', 'id'),
        'ledgerId': web ? r['ledger_id'] : snap['ledgerSyncId'],
        'type': kind,
        'amount': r['amount'],
        'nativeAmount': field('nativeAmount', 'native_amount'),
        'currencyCode': field('currencyCode', 'currency_code'),
        'note': r['note'],
        'happenedAt': DateTime.parse(field('happenedAt', 'happened_at'))
            .toUtc()
            .toIso8601String(),
        'categoryId': ref(field('categoryId', 'category_id')),
        'accountId': kind == 'transfer' ? (from ?? account) : account,
        'toAccountId': ref(field('toAccountId', 'to_account_id')),
        'excludeFromStats': field('excludeFromStats', 'exclude_from_stats'),
        'excludeFromBudget': field('excludeFromBudget', 'exclude_from_budget'),
        'tagIds': List<String>.from(field('tagIds', 'tag_ids') ?? [])..sort()
      };
    }

    f.compare('Cloud snapshot transactions', expectedTx,
        (snap['items'] as List).map((r) => tx(r, false)));
    final webRows = <FixtureRow>[];
    const pageSize = 500;
    for (var offset = 0;; offset += pageSize) {
      final batch =
          await get('$path/transactions?limit=$pageSize&offset=$offset')
              as List;
      webRows.addAll(batch.map((r) => tx(r, true)));
      if (batch.length < pageSize) break;
      if (webRows.length > expectedTx.length) {
        throw StateError(
            'Cloud Web transactions exceeds ${expectedTx.length}; last offset $offset');
      }
    }
    f.compare('Cloud Web transactions', expectedTx, webRows);

    for (final web in [false, true]) {
      Future<List> rows(String name) async =>
          web ? await get('$path/$name') as List : snap[name] as List;
      final source = web ? 'Cloud Web' : 'Cloud snapshot';
      String k(String a, String b) => web ? b : a;
      f.compare(
          '$source categories',
          f.categories,
          (await rows('categories')).map((r) => {
                'syncId': r[k('syncId', 'id')],
                'name': r['name'],
                'kind': r['kind'],
                'level': r['level'],
                'parentId': r[k('parentSyncId', 'parent_sync_id')],
                'sortOrder': r[k('sortOrder', 'sort_order')]
              }));
      f.compare(
          '$source accounts',
          f.accounts,
          (await rows('accounts')).map((r) => {
                'syncId': r[k('syncId', 'id')],
                'name': r['name'],
                'type': r[k('type', 'account_type')],
                'currency': r['currency'],
                'initialBalance': r[k('initialBalance', 'initial_balance')]
              }));
      final expectedTags = {
        for (final e in f.tags.entries)
          e.key: Map<String, dynamic>.of(e.value)..remove('sortOrder')
      };
      f.compare(
          '$source tags',
          expectedTags,
          (await rows('tags')).map((r) => {
                'syncId': r[k('syncId', 'id')],
                'name': r['name'],
                'color': r['color']
              }));
      f.compare(
          '$source budgets',
          expectedBudgets,
          (await rows('budgets')).map((r) => {
                'syncId': r[k('syncId', 'id')],
                'ledgerId': r[k('ledgerSyncId', 'ledger_id')],
                'type': r['type'],
                'categoryId': r[k('categoryId', 'category_id')],
                'amount': r['amount'],
                'period': r['period'],
                'startDay': r[k('startDay', 'start_day')],
                'enabled': r['enabled']
              }));
    }

    final usage = await get('$path/budgets/usage');
    final date = DateTime.now().toUtc(), day = ledger['monthStartDay'] as int;
    final start =
        DateTime.utc(date.year, date.month - (date.day < day ? 1 : 0), day);
    final end = DateTime.utc(start.year, start.month + 1, day);
    final expectedUsage = {
      for (final b in expectedBudgets.values)
        b['syncId'] as String: {
          'syncId': b['syncId'],
          'used': _expenseInPeriod(f, expectedTx, b['categoryId'], start, end)
        }
    };
    f.compare(
        'Cloud Web budget usage',
        expectedUsage,
        (usage['items'] as List)
            .map((r) => {'syncId': r['budget_id'], 'used': r['used']}));
  }
}
