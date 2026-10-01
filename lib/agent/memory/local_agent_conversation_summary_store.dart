import 'dart:convert';

import 'package:agentcore/agentcore.dart';
import 'package:drift/drift.dart' as d;

import '../../data/db.dart' hide AgentConversationSummary;

/// Derived, local-only context cache; reuses the existing summary table.
final class LocalAgentConversationSummaryStore
    implements AgentConversationSummaryStore {
  LocalAgentConversationSummaryStore(this.db);
  final BeeDatabase db;

  @override
  Future<AgentConversationSummary?> load(
      String conversationId, String scopeId) async {
    final row = await (db.select(db.agentConversationSummaries)
          ..where((s) =>
              s.conversationId.equals(int.parse(conversationId)) &
              s.ledgerId.equals(int.parse(scopeId)))
          ..orderBy([(s) => d.OrderingTerm.desc(s.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      return AgentConversationSummary.fromJson(jsonDecode(row.content));
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(String conversationId, String scopeId,
      AgentConversationSummary summary) async {
    final conversation = int.parse(conversationId);
    final ledger = int.parse(scopeId);
    await db.transaction(() async {
      final existing = await (db.select(db.conversations)
            ..where((c) => c.id.equals(conversation)))
          .getSingleOrNull();
      if (existing == null) return;
      // Do not resurrect a cache after the user clears/deletes the chat.
      final messages = await (db.select(db.messages)
            ..where((m) => m.conversationId.equals(conversation))
            ..limit(1))
          .get();
      if (messages.isEmpty) return;
      await (db.delete(db.agentConversationSummaries)
            ..where((s) =>
                s.conversationId.equals(conversation) &
                s.ledgerId.equals(ledger)))
          .go();
      await db.into(db.agentConversationSummaries).insert(
          AgentConversationSummariesCompanion.insert(
              conversationId: d.Value(conversation),
              ledgerId: d.Value(ledger),
              content: jsonEncode(summary.toJson())));
    });
  }
}
