import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/db.dart';

/// Local chat navigation. Conversation and receipt IDs remain stable when
/// older global conversations are separated by their recorded ledger.
final class ChatSessionStore {
  ChatSessionStore(this.db);
  final BeeDatabase db;

  Future<int> open(int ledgerId) async {
    final prefs = await SharedPreferences.getInstance();
    final selected = prefs.getInt(_key(ledgerId));
    return db.transaction(() async {
      await _adoptLegacy(ledgerId);
      if (selected != null && await _belongsTo(selected, ledgerId)) {
        return selected;
      }
      final latest = await (db.select(db.conversations)
            ..where((c) => c.ledgerId.equals(ledgerId))
            ..orderBy([
              (c) => OrderingTerm.desc(c.updatedAt),
              (c) => OrderingTerm.desc(c.id)
            ])
            ..limit(1))
          .getSingleOrNull();
      return latest?.id ?? await _insert(ledgerId);
    });
  }

  Future<int> start(int ledgerId, int currentId) async {
    final id = await db.transaction(() async {
      if (await _belongsTo(currentId, ledgerId)) {
        final message = await (db.selectOnly(db.messages)
              ..addColumns([db.messages.id])
              ..where(db.messages.conversationId.equals(currentId))
              ..limit(1))
            .getSingleOrNull();
        if (message == null) return currentId;
      }
      // Reuse a previously opened blank conversation in this ledger.
      final blank = await db.customSelect(
        'SELECT id FROM conversations c WHERE ledger_id = ? AND NOT EXISTS '
        '(SELECT 1 FROM messages m WHERE m.conversation_id = c.id) ORDER BY id DESC LIMIT 1',
        variables: [Variable.withInt(ledgerId)],
      ).getSingleOrNull();
      return blank?.read<int>('id') ?? await _insert(ledgerId);
    });
    await select(ledgerId, id);
    return id;
  }

  Future<bool> select(int ledgerId, int id) async {
    if (!await _belongsTo(id, ledgerId)) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.setInt(_key(ledgerId), id);
  }

  Future<List<({int id, String title, DateTime updated})>> history(
      int ledgerId) async {
    final rows = await db.customSelect(
      'SELECT c.id, COALESCE((SELECT content FROM messages WHERE conversation_id = c.id '
      "AND role = 'user' ORDER BY created_at, id LIMIT 1), c.title) AS label, "
      'MAX(m.created_at) AS latest FROM conversations c JOIN messages m ON m.conversation_id = c.id '
      'WHERE c.ledger_id = ? GROUP BY c.id ORDER BY latest DESC, c.id DESC',
      variables: [Variable.withInt(ledgerId)],
    ).get();
    return [
      for (final r in rows)
        (
          id: r.read<int>('id'),
          title: r.read<String>('label'),
          updated: r.read<DateTime>('latest')
        )
    ];
  }

  /// Project only the lightweight query definitions needed for a follow-up.
  /// In particular, interaction history and model summaries cannot see frozen
  /// bill pages, attachments, or raw receipt metadata.
  Future<List<Map<String, Object?>>> modelHistory(int conversationId) async {
    final rows = await db.customSelect(r'''
      SELECT id, role, content,
        CASE WHEN json_valid(metadata) THEN coalesce(json_extract(metadata, '$.contextLedgerId'),
          json_extract(metadata, '$.followUpLedgerId')) END AS scope,
        CASE WHEN role = 'assistant' AND json_valid(metadata) THEN
          CASE WHEN json_type(metadata, '$.queryContext') = 'object' THEN
            json_remove(json_extract(metadata, '$.queryContext'), '$.snapshots')
          END END AS query_context
      FROM messages WHERE conversation_id = ? ORDER BY created_at, id
      ''', variables: [Variable.withInt(conversationId)]).get();
    return [
      for (final row in rows)
        {
          'id': row.read<int>('id'),
          'role': row.read<String>('role'),
          'content': row.read<String>('content'),
          'scopeId': row.data['scope']?.toString(),
          if (row.readNullable<String>('query_context')
              case final String encoded)
            'queryContext': jsonDecode(encoded),
        }
    ];
  }

  static String _key(int ledgerId) => 'ai_chat_active_conversation_4_$ledgerId';

  Future<int> _insert(int ledgerId) => db
      .into(db.conversations)
      .insert(ConversationsCompanion.insert(ledgerId: Value(ledgerId)));

  Future<bool> _belongsTo(int id, int ledgerId) async =>
      await (db.selectOnly(db.conversations)
            ..addColumns([db.conversations.id])
            ..where(db.conversations.id.equals(id) &
                db.conversations.ledgerId.equals(ledgerId)))
          .getSingleOrNull() !=
      null;

  Future<void> _adoptLegacy(int fallbackLedger) async {
    final global = await (db.select(db.conversations)
          ..where((c) => c.ledgerId.isNull()))
        .get();
    if (global.isEmpty) return;
    final firstLedger = await (db.selectOnly(db.ledgers)
          ..addColumns([db.ledgers.id])
          ..orderBy([OrderingTerm.asc(db.ledgers.id)])
          ..limit(1))
        .getSingleOrNull();
    final fallback = firstLedger?.read(db.ledgers.id) ?? fallbackLedger;
    for (final conversation in global) {
      final rows = await (db.select(db.messages)
            ..where((m) => m.conversationId.equals(conversation.id))
            ..orderBy([
              (m) => OrderingTerm.asc(m.createdAt),
              (m) => OrderingTerm.asc(m.id)
            ]))
          .get();
      final ledgers = rows.map((r) => _messageLedger(r.metadata)).toList();
      var current = ledgers.whereType<int>().firstOrNull ?? fallback;
      final originalLedger = current;
      final destinations = {current: conversation.id};
      await (db.update(db.conversations)
            ..where((c) => c.id.equals(conversation.id)))
          .write(ConversationsCompanion(ledgerId: Value(current)));
      for (var i = 0; i < rows.length; i++) {
        current = ledgers[i] ?? current;
        if (current == originalLedger) continue;
        final destination = destinations[current] ??= await db
            .into(db.conversations)
            .insert(ConversationsCompanion.insert(
                ledgerId: Value(current),
                title: Value(conversation.title),
                createdAt: Value(conversation.createdAt),
                updatedAt: Value(conversation.updatedAt)));
        await (db.update(db.messages)..where((m) => m.id.equals(rows[i].id)))
            .write(MessagesCompanion(conversationId: Value(destination)));
      }
      if (destinations.length > 1) {
        await (db.delete(db.agentConversationSummaries)
              ..where((s) => s.conversationId.equals(conversation.id)))
            .go();
      }
    }
  }

  static int? _messageLedger(String? raw) {
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return null;
      final bill = data['billInfo'] ??
          (data['bills'] is List ? (data['bills'] as List).firstOrNull : null);
      final value = data['contextLedgerId'] ??
          data['followUpLedgerId'] ??
          (bill is Map ? bill['ledgerId'] : null) ??
          data['ledgerId'];
      return value is int && value > 0 ? value : null;
    } on FormatException {
      return null;
    }
  }
}
