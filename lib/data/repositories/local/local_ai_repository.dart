import 'package:drift/drift.dart' as d;

import '../../db.dart';
import '../ai_repository.dart';

/// 本地AI Repository实现
/// 基于 Drift 数据库实现
class LocalAIRepository implements AIRepository {
  final BeeDatabase db;

  LocalAIRepository(this.db);

  @override
  Future<Conversation?> getActiveConversation() async {
    return await (db.select(db.conversations)
          ..orderBy([(c) => d.OrderingTerm.desc(c.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  @override
  Future<Conversation?> getConversationById(int id) async {
    return await (db.select(db.conversations)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<int> createConversation(ConversationsCompanion conversation) async {
    return await db.into(db.conversations).insert(conversation);
  }

  @override
  Future<void> updateConversation(Conversation conversation) async {
    await db.update(db.conversations).replace(conversation);
  }

  @override
  Future<void> deleteConversation(int id) async {
    await db.transaction(() async {
      await _clearSummaries(id);
      await (db.delete(db.conversations)..where((c) => c.id.equals(id))).go();
    });
  }

  @override
  Stream<List<Message>> watchMessages(int conversationId) {
    return (db.select(db.messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => d.OrderingTerm.asc(m.createdAt)]))
        .watch();
  }

  @override
  Future<Message?> getMessageById(int id) async {
    return await (db.select(db.messages)..where((m) => m.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<int> createMessage(MessagesCompanion message) async {
    return await db.into(db.messages).insert(message);
  }

  @override
  Future<void> updateMessage(Message message) async {
    await db.transaction(() async {
      await _clearSummaries(message.conversationId);
      await db.update(db.messages).replace(message);
    });
  }

  @override
  Future<void> deleteMessagesByConversation(int conversationId) async {
    await db.transaction(() async {
      await _clearSummaries(conversationId);
      await (db.delete(db.messages)
            ..where((m) => m.conversationId.equals(conversationId)))
          .go();
    });
  }

  @override
  Future<void> deleteMessage(int id) async {
    await db.transaction(() async {
      final message = await getMessageById(id);
      if (message != null) await _clearSummaries(message.conversationId);
      await (db.delete(db.messages)..where((m) => m.id.equals(id))).go();
    });
  }

  Future<void> _clearSummaries(int conversationId) =>
      (db.delete(db.agentConversationSummaries)
            ..where((s) => s.conversationId.equals(conversationId)))
          .go();

  @override
  Future<Message?> getMessageByTransactionId(int transactionId) async {
    return await (db.select(db.messages)
          ..where((m) => m.transactionId.equals(transactionId)))
        .getSingleOrNull();
  }
}
