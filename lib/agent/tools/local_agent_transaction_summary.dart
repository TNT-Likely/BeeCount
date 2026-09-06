import 'package:drift/drift.dart' as d;

import '../../data/db.dart';

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
    required List<int> tagIds,
    required List<int> accountIds,
    required bool includeExcludedFromStats,
    required int groupLimit,
  }) async {
    final effectiveTypes = [
      for (final type in _canonicalTypes)
        if (types.contains(type)) type,
    ];
    final ledger = await (_database.select(_database.ledgers)
          ..where((row) => row.id.equals(ledgerId)))
        .getSingleOrNull();
    final where = <String>[
      't.ledger_id = ?',
      't.happened_at >= ?',
      't.happened_at < ?',
      't.type IN (${List.filled(effectiveTypes.length, '?').join(', ')})',
      if (!includeExcludedFromStats) 't.exclude_from_stats = 0',
    ];
    final variables = <d.Variable>[
      d.Variable.withInt(ledgerId),
      d.Variable.withDateTime(start),
      d.Variable.withDateTime(end),
      for (final type in effectiveTypes) d.Variable.withString(type),
    ];
    _appendIdFilter(
      where,
      variables,
      column: 't.category_id',
      ids: categoryIds,
    );
    _appendIdFilter(
      where,
      variables,
      column: 't.account_id',
      ids: accountIds,
      additionalColumn: 't.to_account_id',
    );
    if (tagIds.isNotEmpty) {
      final placeholders = List.filled(tagIds.length, '?').join(', ');
      where.add('''EXISTS (
        SELECT 1 FROM transaction_tags filter_tt
        WHERE filter_tt.transaction_id = t.id
          AND filter_tt.tag_id IN ($placeholders)
      )''');
      variables.addAll(tagIds.map(d.Variable.withInt));
    }
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
          readsFrom: {_database.transactions},
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

    final groups = switch (groupBy) {
      'category' => await _categoryGroups(where, variables,
          categoryLevel: categoryLevel, groupLimit: groupLimit),
      'tag' => await _tagGroups(where, variables, groupLimit: groupLimit),
      'account' =>
        await _accountGroups(where, variables, groupLimit: groupLimit),
      'day' => await _timeGroups(where, variables,
          kind: 'day', format: '%Y-%m-%d', groupLimit: groupLimit),
      'week' => await _timeGroups(where, variables,
          kind: 'week', format: '%Y-W%W', groupLimit: groupLimit),
      'month' => await _timeGroups(where, variables,
          kind: 'month', format: '%Y-%m', groupLimit: groupLimit),
      'year' => await _timeGroups(where, variables,
          kind: 'year', format: '%Y', groupLimit: groupLimit),
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
          readsFrom: {_database.transactions, _database.categories},
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
          readsFrom: {_database.transactions, _database.accounts},
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
          readsFrom: {_database.transactions, _database.accounts},
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
      required int groupLimit}) async {
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
          readsFrom: {_database.transactions},
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
          readsFrom: {_database.transactions, _database.transactionTags},
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

  void _appendIdFilter(
    List<String> where,
    List<d.Variable> variables, {
    required String column,
    required List<int> ids,
    String? additionalColumn,
  }) {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(', ');
    final columns = [column, if (additionalColumn != null) additionalColumn];
    where.add(
        '(${columns.map((item) => '$item IN ($placeholders)').join(' OR ')})');
    for (final _ in columns) {
      variables.addAll(ids.map(d.Variable.withInt));
    }
  }
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
