import 'package:agentcore/agentcore.dart' as core;
import 'package:beecount/agent/memory/local_agent_conversation_summary_store.dart';
import 'package:beecount/agent/memory/local_agent_memory_repository.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_ai_repository.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BeeDatabase db;
  late LocalAgentConversationSummaryStore store;
  late LocalAIRepository repo;
  late int conversation;
  late int message;
  core.AgentConversationSummary summary(String text) =>
      core.AgentConversationSummary(
          coveredMessages: 3, prefixDigest: 'a' * 64, text: text);
  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    store = LocalAgentConversationSummaryStore(db);
    repo = LocalAIRepository(db);
    conversation =
        await repo.createConversation(ConversationsCompanion.insert());
    message = await repo.createMessage(MessagesCompanion.insert(
        conversationId: conversation,
        role: 'user',
        content: 'original',
        messageType: 'text'));
  });
  tearDown(() => db.close());
  Future<void> seed() async {
    await store.save('$conversation', '1', summary('scope one'));
    await store.save('$conversation', '2', summary('scope two'));
  }

  test('缓存按会话与账本隔离，同范围更新只保留一份，原消息不变', () async {
    await seed();
    await store.save('$conversation', '1', summary('updated'));
    expect((await store.load('$conversation', '1'))?.text, 'updated');
    expect((await store.load('$conversation', '2'))?.text, 'scope two');
    expect(await store.load('${conversation + 1}', '1'), isNull);
    expect(await db.select(db.agentConversationSummaries).get(), hasLength(2));
    expect((await repo.getMessageById(message))!.content, 'original');
  });
  test('旧版或损坏的缓存忽略，不产生数据库迁移', () async {
    await db.into(db.agentConversationSummaries).insert(
        AgentConversationSummariesCompanion.insert(
            conversationId: Value(conversation),
            ledgerId: const Value(1),
            content: 'plain legacy summary'));
    expect(await store.load('$conversation', '1'), isNull);
  });
  test('删除单条历史会清除所有范围摘要', () async {
    await seed();
    await repo.deleteMessage(message);
    expect(await db.select(db.agentConversationSummaries).get(), isEmpty);
  });
  test('清空对话会清摘要，晚到的摘要不会复活已清空的聊天', () async {
    await seed();
    await repo.deleteMessagesByConversation(conversation);
    await store.save('$conversation', '1', summary('late summary'));
    expect(await db.select(db.agentConversationSummaries).get(), isEmpty);
    expect(await repo.watchMessages(conversation).first, isEmpty);
  });
  test('更新原消息后摘要失效', () async {
    await seed();
    final row = (await repo.getMessageById(message))!;
    await repo.updateMessage(row.copyWith(content: 'edited'));
    expect(await db.select(db.agentConversationSummaries).get(), isEmpty);
    expect((await repo.getMessageById(message))!.content, 'edited');
  });
  test('删除会话会清除摘要', () async {
    await seed();
    await repo.deleteConversation(conversation);
    await store.save('$conversation', '1', summary('late summary'));
    expect(await db.select(db.agentConversationSummaries).get(), isEmpty);
  });
  test('清空账本记忆仅清除对应账本的派生摘要', () async {
    await seed();
    await LocalAgentMemoryRepository(db).clearForLedger(1);
    expect(await store.load('$conversation', '1'), isNull);
    expect((await store.load('$conversation', '2'))?.text, 'scope two');
  });
}
