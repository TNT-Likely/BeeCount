import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../data/db.dart';

/// Bounded across all tool calls in a response. Reserve before awaiting a
/// database read so concurrent calls cannot spend the same capacity.
class LedgerSnapshotBudget {
  LedgerSnapshotBudget({int rowLimit = 6000, int byteLimit = 1024 * 1024})
      : _rows = rowLimit,
        _bytes = byteLimit;
  static const queryRows = 2000, queryBytes = 320 * 1024;
  int _rows, _bytes;

  Future<Map<String, Object?>> capture(
      Future<Map<String, Object?>> Function(int rows, int bytes) read) async {
    final rows = math.min(_rows, queryRows),
        bytes = math.min(_bytes, queryBytes);
    _rows -= rows;
    _bytes -= bytes;
    Map<String, Object?>? saved;
    try {
      saved = await read(rows, bytes);
      return saved;
    } finally {
      _rows += rows - (saved?['capturedCount'] as int? ?? 0);
      _bytes += bytes - (saved?['storedBytes'] as int? ?? 0);
    }
  }
}

/// A typed, in-process request. Ordinary JSON from a model cannot request
/// local attachments by injecting private-looking keys into its arguments.
class LedgerSnapshotRequest {
  const LedgerSnapshotRequest(this.tool, this.budget);
  final String tool;
  final LedgerSnapshotBudget budget;
}

/// A local attachment to a query reference. The model receives only the tool's
/// bounded answer. Independently compressed pages keep old evidence scrollable
/// without decoding or hydrating a whole ledger on every chat rebuild.
abstract final class LedgerQuerySnapshot {
  static const pageSize = 20;
  static const _batchSize = 160;
  static final _nativeGzip = io.ZLibCodec(gzip: true, level: 1);
  static const _projection = '''
    SELECT t.id, t.sync_id, t.happened_at, t.type, t.amount, t.native_amount,
      COALESCE(NULLIF(t.currency_code, ''), a.currency, sa.currency, book.currency) AS currency_code,
      substr(t.note, 1, 8193) AS note, t.exclude_from_stats, t.exclude_from_budget,
      COALESCE(c.name,sc.name) AS category, COALESCE(c.icon,sc.icon) AS icon,
      c.id AS category_id, COALESCE(c.icon_type,sc.icon_type) AS icon_type,
      c.custom_icon_path AS icon_path,
      COALESCE(CAST(t.account_id AS TEXT), t.account_sync_id_override) AS account_key,
      COALESCE(a.name, sa.name) AS account, COALESCE(dest.name, sd.name) AS destination,
      (SELECT json_group_array(json_object('id', id, 'name', name, 'color', color))
       FROM (SELECT tag.id, tag.name, tag.color FROM tags tag
             JOIN transaction_tags tt ON tt.tag_id = tag.id WHERE tt.transaction_id = t.id
             UNION ALL
             SELECT -st.rowid AS id, st.name, st.color FROM transaction_tag_overrides ot
             JOIN shared_ledger_tags st ON st.sync_id = ot.tag_sync_id AND st.ledger_sync_id = book.sync_id
             WHERE ot.transaction_sync_id = t.sync_id
             ORDER BY id)) AS tags,
      (SELECT COUNT(*) FROM transaction_attachments att
       WHERE att.transaction_id = t.id) AS attachments
    FROM transactions t
    JOIN ledgers book ON book.id = t.ledger_id
    LEFT JOIN shared_ledger_categories sc
      ON sc.ledger_sync_id = book.sync_id AND sc.sync_id = t.category_sync_id_override
    LEFT JOIN shared_ledger_accounts sa
      ON sa.ledger_sync_id = book.sync_id AND sa.sync_id = t.account_sync_id_override
    LEFT JOIN shared_ledger_accounts sd
      ON sd.ledger_sync_id = book.sync_id AND sd.sync_id = t.to_account_sync_id_override
    LEFT JOIN categories c ON c.id = t.category_id
    LEFT JOIN accounts a ON a.id = t.account_id
    LEFT JOIN accounts dest ON dest.id = t.to_account_id
  ''';

  static Future<Map<String, Object?>> capture(
    BeeDatabase database, {
    required int ledgerId,
    required String currency,
    required DateTime start,
    required DateTime end,
    required List<String> where,
    required List<drift.Variable> variables,
    required Map<String, Map<String, Object?>> totals,
    required bool omitTransfers,
    required int maxRows,
    required int maxBytes,
  }) async {
    final clauses = [...where, if (omitTransfers) "t.type != 'transfer'"];
    final pages = <String>[];
    final flowCounts = {for (final type in totals.keys) type: <int>[]};
    final accounts = <String?, Map<String, Object?>>{};
    int? beforeSecond, beforeId;
    final totalCount = totals.entries
        .where((e) => !omitTransfers || e.key != 'transfer')
        .fold<int>(0, (sum, e) => sum + (e.value['count'] as int));
    var count = 0, bytes = 0;
    var accountsResolved = true;
    captureRows:
    while (count < math.min(totalCount, maxRows) && bytes < maxBytes) {
      final limit = math.min(_batchSize, math.min(totalCount, maxRows) - count);
      final rows = await database.customSelect(
        '$_projection WHERE ${clauses.join(' AND ')} '
        '${beforeId == null ? '' : 'AND (t.happened_at, t.id) < (?, ?)'} '
        'ORDER BY t.happened_at DESC, t.id DESC LIMIT ?',
        variables: [
          ...variables,
          if (beforeId != null) ...[
            drift.Variable.withInt(beforeSecond!),
            drift.Variable.withInt(beforeId),
          ],
          drift.Variable.withInt(limit),
        ],
      ).get();
      for (var offset = 0; offset < rows.length; offset += pageSize) {
        final page = <Map<String, Object?>>[];
        for (final row in rows.skip(offset).take(pageSize)) {
          final bill = _bill(row);
          // Keep the newest complete pages. Never silently clip the note of
          // a bill that we present as historical evidence.
          if ((bill['note'] as String?)?.length case final length?
              when length > 8192) {
            break captureRows;
          }
          page.add(bill);
        }
        final raw = utf8.encode(jsonEncode(page));
        if (raw.length > 192 * 1024) break captureRows;
        final encoded = base64Encode(
            kIsWeb ? GZipEncoder().encode(raw)! : _nativeGzip.encode(raw));
        if (bytes + encoded.length + 24 > maxBytes) break captureRows;
        pages.add(encoded);
        bytes += encoded.length + 24; // also bounds this page's index
        count += page.length;
        for (final bill in page) {
          if (bill['type'] == 'expense') {
            if (bill['account_key'] != null && bill['account'] == null) {
              accountsResolved = false;
            }
            final group = accounts.putIfAbsent(bill['account_key'] as String?,
                () => {'name': bill['account'], 'amount': 0.0, 'count': 0});
            final amount = bill['native_amount'] ?? bill['amount'];
            group['amount'] = (group['amount'] as num) + (amount as num).abs();
            group['count'] = (group['count'] as int) + 1;
          }
        }
        for (final entry in flowCounts.entries) {
          entry.value.add(page.where((row) => row['type'] == entry.key).length);
        }
      }
      if (rows.length < limit || rows.isEmpty) break;
      beforeSecond = rows.last.read<int>('happened_at');
      beforeId = rows.last.read<int>('id');
    }
    final groups = count == totalCount && accountsResolved
        ? accounts.values.toList()
        : <Map<String, Object?>>[];
    groups.sort((a, b) => (b['amount'] as num).compareTo(a['amount'] as num));
    if (groups.isNotEmpty) {
      final groupBytes = utf8.encode(jsonEncode(groups)).length;
      if (bytes + groupBytes <= maxBytes) {
        bytes += groupBytes;
      } else {
        groups.clear();
      }
    }
    return {
      'version': 1,
      'ledgerId': ledgerId,
      'currency': currency,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'totals': totals,
      'accounts': groups,
      'count': totalCount,
      'capturedCount': count,
      'storedBytes': bytes,
      'pages': pages,
      'flowCounts': flowCounts,
    };
  }

  static Map<String, Object?> _bill(drift.QueryRow row) => {
        for (final entry in row.data.entries)
          if (entry.value != null && entry.key != 'tags')
            entry.key: entry.value,
        if (row.data['tags'] != '[]')
          'tags': jsonDecode(row.read<String>('tags')),
      };

  static bool valid(Object? snapshot, int ledgerId) {
    if (snapshot is! Map ||
        snapshot['version'] != 1 ||
        snapshot['ledgerId'] != ledgerId ||
        snapshot['currency'] is! String ||
        snapshot['totals'] is! Map ||
        snapshot['accounts'] is! List ||
        snapshot['count'] is! int ||
        snapshot['capturedCount'] is! int ||
        snapshot['pages'] is! List ||
        snapshot['flowCounts'] is! Map) {
      return false;
    }
    final stored = snapshot['capturedCount'] as int,
        pages = snapshot['pages'] as List;
    if (stored < 0 ||
        stored > snapshot['count'] ||
        stored > LedgerSnapshotBudget.queryRows ||
        pages.length != (stored / pageSize).ceil()) {
      return false;
    }
    for (final flow in ['income', 'expense', 'transfer']) {
      final total = snapshot['totals'][flow],
          counts = snapshot['flowCounts'][flow];
      if (total is! Map ||
          total['amount'] is! num ||
          total['count'] is! int ||
          counts is! List ||
          counts.length != pages.length ||
          counts.any((n) => n is! int || n < 0 || n > pageSize)) {
        return false;
      }
    }
    return true;
  }

  static List<Map<String, Object?>> page(Map snapshot, int index,
      {String? flow}) {
    if (snapshot['capturedCount'] == 0) return const [];
    final pages = snapshot['pages'] as List;
    List<Map<String, Object?>> decode(int i) {
      final compressed = base64Decode(pages[i] as String);
      final json = utf8.decode(kIsWeb
          ? GZipDecoder().decodeBytes(compressed)
          : _nativeGzip.decode(compressed));
      return (jsonDecode(json) as List)
          .map((row) => Map<String, Object?>.from(row as Map))
          .toList();
    }

    if (flow == null) return decode(index);
    final result = <Map<String, Object?>>[];
    final sizes = (snapshot['flowCounts'] as Map?)?[flow] as List?;
    var skip = index * pageSize;
    for (var i = 0; i < pages.length && result.length < pageSize; i++) {
      if (sizes != null && skip >= (sizes[i] as int)) {
        skip -= sizes[i] as int;
        continue;
      }
      for (final bill in decode(i)) {
        if (bill['type'] != flow) continue;
        if (skip > 0) {
          skip--;
        } else {
          result.add(bill);
          if (result.length == pageSize) break;
        }
      }
    }
    return result;
  }

  /// Scope the comparison to the original ledger, even when a bill was moved.
  static Future<Map<String, Object?>?> current(
      BeeDatabase database, int ledgerId, Map<String, Object?> original) async {
    final row = await database.customSelect(
      '$_projection WHERE t.ledger_id = ? AND t.id = ?',
      variables: [
        drift.Variable.withInt(ledgerId),
        drift.Variable.withInt(original['id'] as int)
      ],
    ).getSingleOrNull();
    if (row == null ||
        (original['sync_id'] != null &&
            row.data['sync_id'] != original['sync_id'])) {
      return null;
    }
    return _bill(row);
  }
}
