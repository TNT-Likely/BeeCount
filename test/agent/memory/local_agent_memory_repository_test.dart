import 'package:beecount/agent/memory/agent_memory_repository.dart';
import 'package:beecount/agent/memory/local_agent_memory_repository.dart';
import 'package:beecount/data/db.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BeeDatabase db;
  late LocalAgentMemoryRepository repository;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repository = LocalAgentMemoryRepository(db);
  });

  tearDown(() => db.close());

  AgentMemoryDraft memory({
    int? ledgerId = 1,
    String content = '咖啡用微信支付',
    DateTime? expiresAt,
  }) =>
      AgentMemoryDraft(
        ledgerId: ledgerId,
        kind: 'preference',
        content: content,
        expiresAt: expiresAt,
      );

  test('search never returns a memory from another ledger scope', () async {
    await repository.saveExplicit(memory(ledgerId: 2));
    await repository.saveExplicit(memory(ledgerId: null, content: '全局的咖啡偏好'));

    final results = await repository.search(ledgerId: 1, query: '咖啡');

    expect(results.map((item) => item.content), ['全局的咖啡偏好']);
  });

  test('search excludes expired memories', () async {
    await repository.saveExplicit(
      memory(expiresAt: DateTime.now().subtract(const Duration(minutes: 1))),
    );

    expect(await repository.search(ledgerId: 1, query: '咖啡'), isEmpty);
  });

  test('falls back to scoped LIKE search when the FTS table is unavailable',
      () async {
    await db.customStatement('DROP TABLE agent_memory_fts');

    await repository.saveExplicit(memory());

    expect(
      (await repository.search(ledgerId: 1, query: '咖啡')).single.content,
      '咖啡用微信支付',
    );
  });

  test('forget marks only the selected memory as forgotten', () async {
    final first = await repository.saveExplicit(memory(content: '咖啡用微信'));
    await repository.saveExplicit(memory(content: '午饭用现金'));

    await repository.forget(first.id);

    expect(await repository.search(ledgerId: 1, query: '咖啡'), isEmpty);
    expect(
      (await repository.search(ledgerId: 1, query: '午饭')).single.content,
      '午饭用现金',
    );
  });

  test('lists only active memories that belong to the selected ledger',
      () async {
    await repository.saveExplicit(memory(content: '账本一的偏好'));
    await repository.saveExplicit(memory(ledgerId: 2, content: '账本二的偏好'));
    final forgotten = await repository.saveExplicit(
      memory(content: '已忘记的偏好'),
    );
    await repository.forget(forgotten.id);

    final memories = await repository.listActive(ledgerId: 1);

    expect(memories.map((item) => item.content), ['账本一的偏好']);
  });

  test('clearAll deletes only local memories and keeps conversation messages',
      () async {
    await repository.saveExplicit(memory());
    await db.into(db.conversations).insert(
          ConversationsCompanion.insert(title: const Value('保留的对话')),
        );

    await repository.clearAll();

    expect(await repository.search(ledgerId: 1, query: '咖啡'), isEmpty);
    expect(await db.select(db.conversations).get(), hasLength(1));
  });

  test('clears only memories in the selected ledger', () async {
    await repository.saveExplicit(memory(ledgerId: 1, content: '账本一'));
    await repository.saveExplicit(memory(ledgerId: 2, content: '账本二'));

    await repository.clearForLedger(1);

    expect(await repository.listActive(ledgerId: 1), isEmpty);
    expect(
      (await repository.listActive(ledgerId: 2)).single.content,
      '账本二',
    );
  });

  test('recordToolCall ignores a repeated run and call id', () async {
    const call = AgentToolCallAudit(
      runId: 'run-1',
      callId: 'call-1',
      toolName: 'query_transactions',
      status: 'completed',
    );

    await repository.recordToolCall(call);
    await repository.recordToolCall(call);

    expect(await repository.toolCallCount('run-1'), 1);
  });

  test('lists recent local runs together with their local tool audit',
      () async {
    await repository.createRun(
      runId: 'run-activity',
      ledgerId: 1,
      userMessage: '本月花了多少',
    );
    await repository.finishRun(runId: 'run-activity', status: 'completed');
    await repository.recordToolCall(
      const AgentToolCallAudit(
        runId: 'run-activity',
        callId: 'call-summary',
        toolName: 'get_spending_summary',
        status: 'completed',
      ),
    );
    await repository.createRun(
      runId: 'other-ledger-run',
      ledgerId: 2,
      userMessage: '不应展示',
    );

    final runs = await repository.listRecentRuns(ledgerId: 1);
    final toolCalls = await repository.listToolCalls('run-activity');

    expect(runs.single.runId, 'run-activity');
    expect(runs.single.status, 'completed');
    expect(runs.single.userMessage, '本月花了多少');
    expect(toolCalls.single.toolName, 'get_spending_summary');
    expect(toolCalls.single.status, 'completed');
  });
}
