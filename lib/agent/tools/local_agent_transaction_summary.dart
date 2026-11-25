import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as d;

import '../../data/db.dart';
import '../../utils/month_range.dart';

/// Executes bounded financial aggregates in SQLite so an Agent never has to
/// infer totals from the detail-list tool's capped result set.
final class LocalAgentTransactionSummaryDataSource {
  LocalAgentTransactionSummaryDataSource(this._database);

  static const _canonicalTypes = <String>['income', 'expense', 'transfer'];

  final BeeDatabase _database;

  Future<Map<String, Object?>> summarizeTransactions({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
    required Set<String> types,
    required String groupBy,
    required String categoryLevel,
    required List<int> categoryIds,
    required List<String> categoryNames,
    required List<int> tagIds,
    required List<String> tagNames,
    required List<int> accountIds,
    required List<String> accountNames,
    required bool includeExcludedFromStats,
    required int groupLimit,
    Map<String, Object?> filters = const {},
  }) async {
    final effectiveTypes = [
      for (final type in _canonicalTypes)
        if (types.contains(type)) type,
    ];
    final ledger = await (_database.select(_database.ledgers)
          ..where((row) => row.id.equals(ledgerId)))
        .getSingleOrNull();
    final predicate = await _predicate(
        ledgerId: ledgerId,
        start: start,
        end: end,
        types: effectiveTypes,
        categoryIds: categoryIds,
        categoryNames: categoryNames,
        accountIds: accountIds,
        accountNames: accountNames,
        tagIds: tagIds,
        tagNames: tagNames,
        includeExcludedFromStats: includeExcludedFromStats,
        filters: filters);
    final where = predicate.where;
    final variables = predicate.variables;
    final rows = await _database
        .customSelect(
          '''
      SELECT
        t.type AS type,
        COUNT(*) AS transaction_count,
        COALESCE(SUM(ABS(COALESCE(t.native_amount, t.amount))), 0) AS total_amount
      FROM transactions t
      WHERE ${where.join(' AND ')}
      GROUP BY t.type
      ''',
          variables: variables,
          readsFrom: {
            _database.transactions,
            _database.categories,
            _database.accounts,
            _database.transactionTags,
            _database.tags,
          },
        )
        .get();
    final totalsByType = <String, Map<String, Object?>>{
      for (final type in _canonicalTypes)
        type: const {'amount': 0.0, 'count': 0},
    };
    for (final row in rows) {
      final type = row.read<String>('type');
      if (!totalsByType.containsKey(type)) continue;
      totalsByType[type] = {
        'amount': _asDouble(row.data['total_amount']),
        'count': _asInt(row.data['transaction_count']),
      };
    }

    if (groupBy == 'details') {
      final count = totalsByType.values
          .fold<int>(0, (n, row) => n + (row['count'] as int));
      final sum = totalsByType.values
          .fold<double>(0, (n, row) => n + (row['amount'] as num).toDouble());
      final pageWhere = [...where];
      final pageVariables = [...variables];
      final fingerprint = sha256
          .convert(utf8.encode(jsonEncode([
            ...where,
            for (final variable in variables) variable.value?.toString(),
          ])))
          .toString()
          .substring(0, 16);
      if (filters['cursor'] case final String cursor) {
        final parts = cursor.split('/');
        final seconds = parts.length == 3 ? int.tryParse(parts[1]) : null;
        final lastId = int.tryParse(parts.last);
        if (parts.first != fingerprint || seconds == null || lastId == null) {
          return {'error': 'invalid_detail_cursor', 'retryable': true};
        }
        pageWhere
            .add('(t.happened_at < ? OR (t.happened_at = ? AND t.id < ?))');
        pageVariables.addAll([
          d.Variable.withInt(seconds),
          d.Variable.withInt(seconds),
          d.Variable.withInt(lastId)
        ]);
      }
      final page = await _database.customSelect(
          'SELECT t.id, t.happened_at FROM transactions t WHERE ${pageWhere.join(' AND ')} '
          'ORDER BY t.happened_at DESC, t.id DESC LIMIT ?',
          variables: [...pageVariables, d.Variable.withInt(groupLimit + 1)],
          readsFrom: {_database.transactions}).get();
      final visible = page.take(groupLimit).toList();
      return {
        'currency': ledger?.currency ?? 'CNY',
        'periodStart': start.toIso8601String(),
        'periodEnd': end.toIso8601String(),
        'pageIds': visible.map((r) => r.read<int>('id')).toList(),
        'totalCount': count,
        'totalLedgerAmount': sum,
        'truncated': count > visible.length,
        'nextCursor': page.length > groupLimit
            ? "$fingerprint/${visible.last.read<int>('happened_at')}/${visible.last.read<int>('id')}"
            : null,
        ...predicate.match
      };
    }
    final groups = switch (groupBy) {
      'category' => await _categoryGroups(where, variables,
          categoryLevel: categoryLevel, groupLimit: groupLimit),
      'tag' => await _tagGroups(where, variables, groupLimit: groupLimit),
      'account' =>
        await _accountGroups(where, variables, groupLimit: groupLimit),
      'day' => await _timeGroups(where, variables,
          kind: 'day',
          format: '%Y-%m-%d',
          groupLimit: groupLimit,
          start: start,
          end: end,
          monthStartDay: ledger?.monthStartDay ?? 1),
      'week' => await _timeGroups(where, variables,
          kind: 'week',
          format: '%Y-W%W',
          groupLimit: groupLimit,
          start: start,
          end: end,
          monthStartDay: ledger?.monthStartDay ?? 1),
      'month' => await _timeGroups(where, variables,
          kind: 'month',
          format: '%Y-%m',
          groupLimit: groupLimit,
          start: start,
          end: end,
          monthStartDay: ledger?.monthStartDay ?? 1),
      'year' => await _timeGroups(where, variables,
          kind: 'year',
          format: '%Y',
          groupLimit: groupLimit,
          start: start,
          end: end,
          monthStartDay: ledger?.monthStartDay ?? 1),
      _ => const <Map<String, Object?>>[],
    };
    final truncated = groups.any(
      (group) => (group['key'] as Map<String, Object?>?)?['kind'] == 'other',
    );
    return {
      'currency': _currencyOr(ledger?.currency),
      'periodStart': start.toIso8601String(),
      'periodEnd': end.toIso8601String(),
      'types': effectiveTypes,
      'totals': totalsByType,
      'groupBy': groupBy,
      'groups': groups,
      'groupsMayOverlap': groupBy == 'tag' || groupBy == 'account',
      'truncated': truncated,
      ...predicate.match,
    };
  }

  Future<List<Map<String, Object?>>> _categoryGroups(
      List<String> where, List<d.Variable> variables,
      {required String categoryLevel, required int groupLimit}) async {
    final rows = await _database
        .customSelect(
          '''
      SELECT
        t.category_id AS category_id,
        c.name AS category_name,
        c.icon AS category_icon,
        t.type AS type,
        COUNT(*) AS transaction_count,
        COALESCE(SUM(ABS(COALESCE(t.native_amount, t.amount))), 0) AS total_amount
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE ${where.join(' AND ')}
      GROUP BY t.category_id, c.name, c.icon, t.type
      ''',
          variables: variables,
          readsFrom: {
            _database.transactions,
            _database.categories,
            _database.accounts,
            _database.transactionTags,
            _database.tags,
          },
        )
        .get();
    final categories = {
      for (final category in await _database.select(_database.categories).get())
        category.id: category,
    };
    final groups = <String, _SummaryGroup>{};
    for (final row in rows) {
      var categoryId = row.read<int?>('category_id');
      var name = row.read<String?>('category_name') ?? '未分类';
      var icon = row.read<String?>('category_icon');
      if (categoryLevel == 'top' && categoryId != null) {
        final category = categories[categoryId];
        final parent = category?.parentId == null
            ? category
            : categories[category!.parentId];
        if (parent != null) {
          categoryId = parent.id;
          name = parent.name;
          icon = parent.icon;
        }
      }
      final key = categoryId == null ? 'uncategorized' : 'category:$categoryId';
      groups
          .putIfAbsent(
            key,
            () => _SummaryGroup(
              key: {
                'kind': 'category',
                'id': categoryId,
                'name': name,
                'icon': icon,
              },
            ),
          )
          .add(
            type: row.read<String>('type'),
            amount: _asDouble(row.data['total_amount']),
            count: _asInt(row.data['transaction_count']),
          );
    }
    return _sortedGroups(groups.values, limit: groupLimit);
  }

  Future<List<Map<String, Object?>>> _accountGroups(
      List<String> where, List<d.Variable> variables,
      {required int groupLimit}) async {
    final sourceRows = await _database
        .customSelect(
          '''
      SELECT
        a.id AS account_id,
        a.name AS account_name,
        a.currency AS account_currency,
        t.type AS type,
        COUNT(*) AS transaction_count,
        COALESCE(SUM(ABS(COALESCE(t.native_amount, t.amount))), 0) AS total_amount
      FROM transactions t
      LEFT JOIN accounts a ON a.id = t.account_id
      WHERE ${where.join(' AND ')}
      GROUP BY a.id, a.name, a.currency, t.type
      ''',
          variables: variables,
          readsFrom: {
            _database.transactions,
            _database.categories,
            _database.accounts,
            _database.transactionTags,
            _database.tags,
          },
        )
        .get();
    final destinationRows = await _database
        .customSelect(
          '''
      SELECT
        a.id AS account_id,
        a.name AS account_name,
        a.currency AS account_currency,
        t.type AS type,
        COUNT(*) AS transaction_count,
        COALESCE(SUM(ABS(COALESCE(t.native_amount, t.amount))), 0) AS total_amount
      FROM transactions t
      LEFT JOIN accounts a ON a.id = t.to_account_id
      WHERE ${where.join(' AND ')}
        AND t.type = 'transfer'
        AND t.to_account_id IS NOT NULL
      GROUP BY a.id, a.name, a.currency, t.type
      ''',
          variables: variables,
          readsFrom: {
            _database.transactions,
            _database.categories,
            _database.accounts,
            _database.transactionTags,
            _database.tags,
          },
        )
        .get();
    final groups = <String, _AccountSummaryGroup>{};
    for (final row in sourceRows) {
      final group = groups.putIfAbsent(
        _accountKey(row.data),
        () => _AccountSummaryGroup(key: _accountToolKey(row.data)),
      );
      final type = row.read<String>('type');
      final amount = _asDouble(row.data['total_amount']);
      final count = _asInt(row.data['transaction_count']);
      if (type == 'transfer') {
        group.addTransferOut(amount: amount, count: count);
      } else {
        group.add(type: type, amount: amount, count: count);
      }
    }
    for (final row in destinationRows) {
      final group = groups.putIfAbsent(
        _accountKey(row.data),
        () => _AccountSummaryGroup(key: _accountToolKey(row.data)),
      );
      group.addTransferIn(
        amount: _asDouble(row.data['total_amount']),
        count: _asInt(row.data['transaction_count']),
      );
    }
    final sorted = groups.values.toList()
      ..sort((left, right) {
        final amount = right.totalAmount.compareTo(left.totalAmount);
        if (amount != 0) return amount;
        return (left.key['name'] as String)
            .compareTo(right.key['name'] as String);
      });
    if (sorted.length <= groupLimit) {
      return sorted.map((group) => group.toToolData()).toList();
    }
    final visible = sorted.take(groupLimit).toList();
    final other = _AccountSummaryGroup(
      key: const {'kind': 'other', 'id': null, 'name': '其他'},
    );
    for (final group in sorted.skip(groupLimit)) {
      other.merge(group);
    }
    return [
      ...visible.map((group) => group.toToolData()),
      other.toToolData(),
    ];
  }

  Future<List<Map<String, Object?>>> _timeGroups(
      List<String> where, List<d.Variable> variables,
      {required String kind,
      required String format,
      required int groupLimit,
      required DateTime start,
      required DateTime end,
      required int monthStartDay}) async {
    if (kind == 'month') {
      return _monthGroups(
        where,
        variables,
        start: start,
        end: end,
        monthStartDay: monthStartDay,
        groupLimit: groupLimit,
      );
    }
    final offsetSeconds = DateTime.now().timeZoneOffset.inSeconds;
    final offsetModifier =
        '${offsetSeconds >= 0 ? '+' : '-'}${offsetSeconds.abs()} seconds';
    final rows = await _database
        .customSelect(
          '''
      SELECT
        strftime(
          '$format',
          CASE
            WHEN typeof(t.happened_at) = 'integer' AND abs(t.happened_at) > 100000000000
              THEN t.happened_at / 1000
            ELSE t.happened_at
          END,
          'unixepoch', '$offsetModifier'
        ) AS period,
        t.type AS type,
        COUNT(*) AS transaction_count,
        COALESCE(SUM(ABS(COALESCE(t.native_amount, t.amount))), 0) AS total_amount
      FROM transactions t
      WHERE ${where.join(' AND ')}
      GROUP BY period, t.type
      ORDER BY period ASC
      ''',
          variables: variables,
          readsFrom: {
            _database.transactions,
            _database.categories,
            _database.accounts,
            _database.transactionTags,
            _database.tags,
          },
        )
        .get();
    final groups = <String, _SummaryGroup>{};
    for (final row in rows) {
      final period = row.read<String?>('period');
      if (period == null || period.isEmpty) continue;
      groups
          .putIfAbsent(
            period,
            () => _SummaryGroup(
              key: {'kind': kind, 'value': period},
            ),
          )
          .add(
            type: row.read<String>('type'),
            amount: _asDouble(row.data['total_amount']),
            count: _asInt(row.data['transaction_count']),
          );
    }
    final sorted = groups.values.toList()
      ..sort((left, right) => (left.key['value'] as String)
          .compareTo(right.key['value'] as String));
    if (sorted.length <= groupLimit) {
      return sorted.map((group) => group.toToolData()).toList();
    }
    final other = _SummaryGroup(
      key: {'kind': 'other', 'id': null, 'name': '更早期间'},
    );
    for (final group in sorted.take(sorted.length - groupLimit)) {
      for (final type in const ['income', 'expense', 'transfer']) {
        final total = group.totals[type]!;
        other.add(
          type: type,
          amount: total['amount']! as double,
          count: total['count']! as int,
        );
      }
    }
    return [
      other.toToolData(),
      ...sorted
          .skip(sorted.length - groupLimit)
          .map((group) => group.toToolData()),
    ];
  }

  Future<List<Map<String, Object?>>> _monthGroups(
    List<String> where,
    List<d.Variable> variables, {
    required DateTime start,
    required DateTime end,
    required int monthStartDay,
    required int groupLimit,
  }) async {
    final rows = await _database
        .customSelect(
          '''
      SELECT
        t.happened_at AS happened_at,
        t.type AS type,
        ABS(COALESCE(t.native_amount, t.amount)) AS amount
      FROM transactions t
      WHERE ${where.join(' AND ')}
      ORDER BY t.happened_at ASC
      ''',
          variables: variables,
          readsFrom: {
            _database.transactions,
            _database.categories,
            _database.accounts,
            _database.transactionTags,
            _database.tags,
          },
        )
        .get();
    final groups = <String, _SummaryGroup>{};
    for (final row in rows) {
      final happenedAt = _databaseDateTime(row.data['happened_at']);
      if (happenedAt == null) continue;
      final label = labelForDate(happenedAt.toLocal(), monthStartDay);
      final key = _monthKey(label);
      groups
          .putIfAbsent(
            key,
            () => _SummaryGroup(
              key: {'kind': 'month', 'value': key},
            ),
          )
          .add(
            type: row.read<String>('type'),
            amount: _asDouble(row.data['amount']),
            count: 1,
          );
    }

    // Trend results are a time series, so represent months without matching
    // transactions explicitly instead of making the model infer missing zeroes.
    var label = labelForDate(start.toLocal(), monthStartDay);
    while (periodForLabel(label.year, label.month, monthStartDay)
        .start
        .isBefore(end)) {
      final key = _monthKey(label);
      groups.putIfAbsent(
        key,
        () => _SummaryGroup(key: {'kind': 'month', 'value': key}),
      );
      label = DateTime(label.year, label.month + 1, 1);
    }

    final sorted = groups.values.toList()
      ..sort((left, right) => (left.key['value'] as String)
          .compareTo(right.key['value'] as String));
    if (sorted.length <= groupLimit) {
      return sorted.map((group) => group.toToolData()).toList();
    }
    final other = _SummaryGroup(
      key: const {'kind': 'other', 'id': null, 'name': '更早期间'},
    );
    for (final group in sorted.take(sorted.length - groupLimit)) {
      for (final type in const ['income', 'expense', 'transfer']) {
        final total = group.totals[type]!;
        other.add(
          type: type,
          amount: total['amount']! as double,
          count: total['count']! as int,
        );
      }
    }
    return [
      other.toToolData(),
      ...sorted
          .skip(sorted.length - groupLimit)
          .map((group) => group.toToolData()),
    ];
  }

  Future<
      ({
        List<String> where,
        List<d.Variable> variables,
        Map<String, Object?> match
      })> _predicate({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
    required List<String> types,
    required List<int> categoryIds,
    required List<String> categoryNames,
    required List<int> accountIds,
    required List<String> accountNames,
    required List<int> tagIds,
    required List<String> tagNames,
    required bool includeExcludedFromStats,
    required Map<String, Object?> filters,
  }) async {
    final categoryFilter = await _expandedCategoryFilter(
      types: types,
      ids: categoryIds,
      names: categoryNames,
    );
    final where = <String>[
      't.ledger_id = ?',
      't.happened_at >= ?',
      't.happened_at < ?',
      't.type IN (${List.filled(types.length, '?').join(', ')})',
      if (!includeExcludedFromStats) 't.exclude_from_stats = 0',
    ];
    final variables = <d.Variable>[
      d.Variable.withInt(ledgerId),
      d.Variable.withDateTime(start),
      d.Variable.withDateTime(end),
      for (final type in types) d.Variable.withString(type),
    ];
    _appendReferenceFilter(
      where,
      variables,
      column: 't.category_id',
      ids: categoryFilter.ids,
      names: const [],
      table: 'categories',
      tableAlias: 'filter_category',
    );
    _appendReferenceFilter(
      where,
      variables,
      column: 't.account_id',
      ids: accountIds,
      names: accountNames,
      table: 'accounts',
      tableAlias: 'filter_account',
      additionalColumn: 't.to_account_id',
    );
    _appendTagFilter(where, variables, ids: tagIds, names: tagNames);

    var match = categoryFilter.match;
    for (final entity in [
      (table: 'accounts', ids: accountIds, names: accountNames),
      (table: 'tags', ids: tagIds, names: tagNames)
    ]) {
      if (entity.ids.isEmpty && entity.names.isEmpty) continue;
      final status = await _entityMatch(entity.table, entity.ids, entity.names);
      if (status != null) {
        match = status;
        break;
      }
    }
    if (match.isNotEmpty && match['matchStatus'] != 'matched') where.add('0');
    final original = filters['amountBasis'] == 'original';
    final amount =
        original ? 'ABS(t.amount)' : 'ABS(COALESCE(t.native_amount,t.amount))';
    for (final (key, op) in [('minAmount', '>='), ('maxAmount', '<=')]) {
      if (filters[key] case final num limit) {
        where.add('$amount $op ?');
        variables.add(d.Variable.withReal(limit.toDouble()));
      }
    }
    if (filters['currency'] case final String currency) {
      where.add(
          "upper(COALESCE(t.currency_code, (SELECT currency FROM ledgers WHERE id=t.ledger_id))) = ?");
      variables.add(d.Variable.withString(currency.toUpperCase()));
    }
    if (filters['exclude'] case final Map excluded) {
      final x = Map<String, Object?>.from(excluded);
      final clause = await _predicate(
          ledgerId: ledgerId,
          start: DateTime.parse(x['start'] as String),
          end: DateTime.parse(x['end'] as String),
          types: x['flowType'] is String
              ? [x['flowType'] as String]
              : _canonicalTypes,
          categoryIds: _ids(x, 'categoryIds'),
          categoryNames: _names(x, 'categoryNames'),
          accountIds: _ids(x, 'accountIds'),
          accountNames: _names(x, 'accountNames'),
          tagIds: _ids(x, 'tagIds'),
          tagNames: _names(x, 'tagNames'),
          includeExcludedFromStats: x['includeExcludedFromStats'] == true,
          filters: x);
      where.add(
          "t.id NOT IN (SELECT t.id FROM transactions t WHERE ${clause.where.join(' AND ')})");
      variables.addAll(clause.variables);
      if (clause.match['matchStatus'] == 'unmatched' ||
          clause.match['matchStatus'] == 'ambiguous') {
        match = clause.match;
        where.add('0');
      }
    }
    return (where: where, variables: variables, match: match);
  }

  // Accounts and tags are user-level dictionaries. Transactions remain scoped to the ledger.
  Future<Map<String, Object?>?> _entityMatch(
      String table, List<int> ids, List<String> names) async {
    final rows =
        await _database.customSelect('SELECT id, name FROM $table').get();
    for (final id in ids) {
      if (!rows.any((row) => row.read<int>('id') == id)) {
        return {'matchStatus': 'unmatched', 'requestedName': id.toString()};
      }
    }
    for (final name in names) {
      final options = rows
          .where((row) =>
              row.read<String>('name').toLowerCase() ==
              name.trim().toLowerCase())
          .toList();
      if (options.length != 1) {
        return {
          'matchStatus': options.isEmpty ? 'unmatched' : 'ambiguous',
          'requestedName': name,
          'candidates': options.take(12).map((row) => row.data).toList()
        };
      }
    }
    return null;
  }

  static List<int> _ids(Map args, String key) =>
      (args[key] as List?)?.whereType<int>().toList() ?? [];
  static List<String> _names(Map args, String key) =>
      (args[key] as List?)?.whereType<String>().toList() ?? [];

  Future<({List<int> ids, Map<String, Object?> match})>
      _expandedCategoryFilter({
    required List<String> types,
    required List<int> ids,
    required List<String> names,
  }) async {
    if (ids.isEmpty && names.isEmpty) {
      return (ids: <int>[], match: <String, Object?>{});
    }
    final categories = await _database.select(_database.categories).get();
    final byId = {for (final c in categories) c.id: c};
    final resolved = <Category>[];
    const synonyms = {
      '伙食': ['餐饮', '餐飲', '饮食', '飲食'],
      '伙食费': ['餐饮', '餐飲', '饮食', '飲食'],
      '吃饭': ['餐饮', '餐飲', '饮食', '飲食'],
      '飯錢': ['餐饮', '餐飲', '饮食', '飲食'],
      '饭钱': ['餐饮', '餐飲', '饮食', '飲食'],
      '午饭': ['午餐'],
      '午飯': ['午餐'],
      '早饭': ['早餐'],
      '早飯': ['早餐'],
      '晚饭': ['晚餐'],
      '晚飯': ['晚餐'],
    };
    for (final input in names) {
      final name = input.trim().toLowerCase();
      final allowed = categories.where((c) => types.contains(c.kind));
      var options =
          allowed.where((c) => c.name.trim().toLowerCase() == name).toList();
      if (options.isEmpty) {
        options = allowed
            .where((c) => synonyms[name]?.contains(c.name) == true)
            .toList();
      }
      if (options.length != 1) {
        return (
          ids: <int>[],
          match: {
            'matchStatus': options.isEmpty ? 'unmatched' : 'ambiguous',
            'requestedName': input,
            'candidates': [
              for (final c in options.take(12))
                {'id': c.id, 'name': c.name, 'parent': byId[c.parentId]?.name}
            ]
          }
        );
      }
      resolved.add(options.single);
    }
    final matched = <int>{
      ...ids.where((id) => types.contains(byId[id]?.kind)),
      ...resolved.map((c) => c.id)
    };
    if (matched.isEmpty || ids.any((id) => !matched.contains(id))) {
      return (ids: <int>[], match: {'matchStatus': 'unmatched'});
    }
    final direct = [...matched];
    var changed = true;
    while (changed) {
      changed = false;
      for (final category in categories) {
        if (category.parentId != null &&
            matched.contains(category.parentId) &&
            matched.add(category.id)) {
          changed = true;
        }
      }
    }
    final result = matched.toList()..sort();
    return (
      ids: result,
      match: {
        'matchStatus': 'matched',
        'matchedCategories': [
          for (final id in direct) {'id': id, 'name': byId[id]?.name}
        ]
      }
    );
  }

  String _accountKey(Map<String, Object?> row) =>
      'account:${row['account_id'] ?? 'unknown'}';

  Map<String, Object?> _accountToolKey(Map<String, Object?> row) => {
        'kind': 'account',
        'id': row['account_id'],
        'name': row['account_name'] ?? '未知账户',
        'currency': row['account_currency'],
      };

  Future<List<Map<String, Object?>>> _tagGroups(
      List<String> where, List<d.Variable> variables,
      {required int groupLimit}) async {
    final taggedRows = await _database
        .customSelect(
          '''
      SELECT
        tag.id AS tag_id,
        tag.name AS tag_name,
        t.type AS type,
        COUNT(*) AS transaction_count,
        COALESCE(SUM(ABS(COALESCE(t.native_amount, t.amount))), 0) AS total_amount
      FROM transactions t
      INNER JOIN transaction_tags tt ON tt.transaction_id = t.id
      INNER JOIN tags tag ON tag.id = tt.tag_id
      WHERE ${where.join(' AND ')}
      GROUP BY tag.id, tag.name, t.type
      ''',
          variables: variables,
          readsFrom: {
            _database.transactions,
            _database.categories,
            _database.accounts,
            _database.transactionTags,
            _database.tags
          },
        )
        .get();
    final untaggedRows = await _database
        .customSelect(
          '''
      SELECT
        t.type AS type,
        COUNT(*) AS transaction_count,
        COALESCE(SUM(ABS(COALESCE(t.native_amount, t.amount))), 0) AS total_amount
      FROM transactions t
      WHERE ${where.join(' AND ')}
        AND NOT EXISTS (
          SELECT 1 FROM transaction_tags tt WHERE tt.transaction_id = t.id
        )
      GROUP BY t.type
      ''',
          variables: variables,
          readsFrom: {
            _database.transactions,
            _database.categories,
            _database.accounts,
            _database.transactionTags,
            _database.tags,
          },
        )
        .get();
    final groups = <String, _SummaryGroup>{};
    for (final row in taggedRows) {
      final tagId = row.read<int>('tag_id');
      groups
          .putIfAbsent(
            'tag:$tagId',
            () => _SummaryGroup(
              key: {
                'kind': 'tag',
                'id': tagId,
                'name': row.read<String>('tag_name'),
              },
            ),
          )
          .add(
            type: row.read<String>('type'),
            amount: _asDouble(row.data['total_amount']),
            count: _asInt(row.data['transaction_count']),
          );
    }
    for (final row in untaggedRows) {
      groups
          .putIfAbsent(
            'untagged',
            () => _SummaryGroup(
              key: const {'kind': 'tag', 'id': null, 'name': '未标记'},
            ),
          )
          .add(
            type: row.read<String>('type'),
            amount: _asDouble(row.data['total_amount']),
            count: _asInt(row.data['transaction_count']),
          );
    }
    return _sortedGroups(groups.values, limit: groupLimit);
  }

  void _appendReferenceFilter(
    List<String> where,
    List<d.Variable> variables, {
    required String column,
    required List<int> ids,
    required List<String> names,
    required String table,
    required String tableAlias,
    String? additionalColumn,
  }) {
    final columns = [column, if (additionalColumn != null) additionalColumn];
    if (ids.isEmpty && names.isEmpty) return;
    final predicates = <String>[];
    if (ids.isNotEmpty) {
      final placeholders = List.filled(ids.length, '?').join(', ');
      predicates.addAll(
        columns.map((item) => '$item IN ($placeholders)'),
      );
      for (final _ in columns) {
        variables.addAll(ids.map(d.Variable.withInt));
      }
    }
    if (names.isNotEmpty) {
      final placeholders = List.filled(names.length, '?').join(', ');
      for (final item in columns) {
        predicates.add('''EXISTS (
          SELECT 1 FROM $table $tableAlias
          WHERE $tableAlias.id = $item
            AND lower(trim($tableAlias.name)) IN ($placeholders)
        )''');
        variables.addAll(names.map(d.Variable.withString));
      }
    }
    where.add('(${predicates.join(' OR ')})');
  }

  void _appendTagFilter(
    List<String> where,
    List<d.Variable> variables, {
    required List<int> ids,
    required List<String> names,
  }) {
    if (ids.isEmpty && names.isEmpty) return;
    final predicates = <String>[];
    if (ids.isNotEmpty) {
      final placeholders = List.filled(ids.length, '?').join(', ');
      predicates.add('filter_tt.tag_id IN ($placeholders)');
      variables.addAll(ids.map(d.Variable.withInt));
    }
    if (names.isNotEmpty) {
      final placeholders = List.filled(names.length, '?').join(', ');
      predicates.add(
        'lower(trim(filter_tag.name)) IN ($placeholders)',
      );
      variables.addAll(names.map(d.Variable.withString));
    }
    where.add('''EXISTS (
      SELECT 1
      FROM transaction_tags filter_tt
      INNER JOIN tags filter_tag ON filter_tag.id = filter_tt.tag_id
      WHERE filter_tt.transaction_id = t.id
        AND (${predicates.join(' OR ')})
    )''');
  }
}

String _monthKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}';

DateTime? _databaseDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is! num) return null;
  final raw = value.toInt();
  final milliseconds = raw.abs() > 100000000000 ? raw : raw * 1000;
  return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}

List<Map<String, Object?>> _sortedGroups(
  Iterable<_SummaryGroup> groups, {
  required int limit,
}) {
  final sorted = groups.toList()
    ..sort((left, right) {
      final amount = right.totalAmount.compareTo(left.totalAmount);
      if (amount != 0) return amount;
      return (left.key['name'] as String)
          .compareTo(right.key['name'] as String);
    });
  if (sorted.length <= limit) {
    return sorted.map((group) => group.toToolData()).toList();
  }
  final visible = sorted.take(limit).toList();
  final other = _SummaryGroup(
    key: const {'kind': 'other', 'id': null, 'name': '其他'},
  );
  for (final group in sorted.skip(limit)) {
    for (final type in const ['income', 'expense', 'transfer']) {
      final total = group.totals[type]!;
      other.add(
        type: type,
        amount: total['amount']! as double,
        count: total['count']! as int,
      );
    }
  }
  return [
    ...visible.map((group) => group.toToolData()),
    other.toToolData(),
  ];
}

final class _SummaryGroup {
  _SummaryGroup({required this.key});

  final Map<String, Object?> key;
  final Map<String, Map<String, Object?>> _totals = _emptyTotals();
  Map<String, Map<String, Object?>> get totals => _totals;

  double get totalAmount => _totals.values.fold(
        0,
        (sum, total) => sum + (total['amount']! as double),
      );

  void add({
    required String type,
    required double amount,
    required int count,
  }) {
    final total = _totals[type];
    if (total == null) return;
    total['amount'] = (total['amount']! as double) + amount;
    total['count'] = (total['count']! as int) + count;
  }

  Map<String, Object?> toToolData() => {'key': key, 'totals': _totals};
}

final class _AccountSummaryGroup {
  _AccountSummaryGroup({required this.key});

  final Map<String, Object?> key;
  final Map<String, Map<String, Object?>> _totals = _emptyTotals();
  final Map<String, Map<String, Object?>> _transferOut = _emptySummary();
  final Map<String, Map<String, Object?>> _transferIn = _emptySummary();

  double get totalAmount =>
      _totals.values.fold(
        0.0,
        (sum, total) => sum + (total['amount']! as double),
      ) +
      (_transferOut['transfer']!['amount']! as double) +
      (_transferIn['transfer']!['amount']! as double);

  void add({
    required String type,
    required double amount,
    required int count,
  }) {
    final total = _totals[type];
    if (total == null) return;
    total['amount'] = (total['amount']! as double) + amount;
    total['count'] = (total['count']! as int) + count;
  }

  void addTransferOut({required double amount, required int count}) {
    final total = _transferOut['transfer']!;
    total['amount'] = (total['amount']! as double) + amount;
    total['count'] = (total['count']! as int) + count;
  }

  void addTransferIn({required double amount, required int count}) {
    final total = _transferIn['transfer']!;
    total['amount'] = (total['amount']! as double) + amount;
    total['count'] = (total['count']! as int) + count;
  }

  void merge(_AccountSummaryGroup other) {
    for (final type in const ['income', 'expense', 'transfer']) {
      final total = other._totals[type]!;
      add(
        type: type,
        amount: total['amount']! as double,
        count: total['count']! as int,
      );
    }
    final out = other._transferOut['transfer']!;
    addTransferOut(
      amount: out['amount']! as double,
      count: out['count']! as int,
    );
    final input = other._transferIn['transfer']!;
    addTransferIn(
      amount: input['amount']! as double,
      count: input['count']! as int,
    );
  }

  Map<String, Object?> toToolData() => {
        'key': key,
        'totals': _totals,
        'transferOut': _transferOut['transfer'],
        'transferIn': _transferIn['transfer'],
      };
}

Map<String, Map<String, Object?>> _emptySummary() => {
      'transfer': {'amount': 0.0, 'count': 0},
    };

Map<String, Map<String, Object?>> _emptyTotals() => {
      for (final type in const ['income', 'expense', 'transfer'])
        type: {'amount': 0.0, 'count': 0},
    };

String _currencyOr(String? value) {
  final normalized = value?.trim().toUpperCase();
  return normalized == null || normalized.isEmpty ? 'CNY' : normalized;
}

double _asDouble(Object? value) => switch (value) {
      num value => value.toDouble(),
      _ => 0.0,
    };

int _asInt(Object? value) => switch (value) {
      int value => value,
      BigInt value => value.toInt(),
      num value => value.toInt(),
      _ => 0,
    };
