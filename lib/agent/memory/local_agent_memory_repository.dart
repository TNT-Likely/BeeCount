import 'package:drift/drift.dart' as d;

import '../../data/db.dart';
import 'agent_memory_repository.dart';

/// Drift-backed Agent memory store. All reads and writes stay in the device's
/// SQLite database and do not pass through the app's sync repositories.
final class LocalAgentMemoryRepository implements AgentMemoryRepository {
  LocalAgentMemoryRepository(this._db);

  static const _searchLimit = 6;

  final BeeDatabase _db;

  @override
  Future<AgentMemoryRecord> saveExplicit(AgentMemoryDraft draft) async {
    final now = DateTime.now();
    final id = await _db.into(_db.agentMemories).insert(
          AgentMemoriesCompanion.insert(
            ledgerId: d.Value(draft.ledgerId),
            kind: draft.kind,
            content: draft.content,
            keywords: d.Value(draft.keywords),
            sourceMessageId: d.Value(draft.sourceMessageId),
            expiresAt: d.Value(draft.expiresAt),
            createdAt: d.Value(now),
            updatedAt: d.Value(now),
          ),
        );
    await _tryFtsStatement(
      'INSERT INTO agent_memory_fts(memory_id, content) VALUES (?, ?)',
      [id, draft.content],
    );
    final row = await (_db.select(_db.agentMemories)
          ..where((memory) => memory.id.equals(id)))
        .getSingle();
    return _toRecord(row);
  }

  @override
  Future<List<AgentMemoryRecord>> search({
    required int ledgerId,
    required String query,
  }) async {
    final ids = await _searchFtsIds(query);
    if (ids.isNotEmpty) {
      final matched = await _activeMemories(ledgerId: ledgerId, ids: ids);
      if (matched.isNotEmpty) return matched;
    }
    return _activeMemories(ledgerId: ledgerId, query: query);
  }

  @override
  Future<void> forget(int memoryId) async {
    await (_db.update(_db.agentMemories)
          ..where((memory) => memory.id.equals(memoryId)))
        .write(
      AgentMemoriesCompanion(
        status: const d.Value('forgotten'),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
    await _tryFtsStatement(
      'DELETE FROM agent_memory_fts WHERE memory_id = ?',
      [memoryId],
    );
  }

  @override
  Future<void> clearAll() async {
    await _db.transaction(() async {
      await _db.delete(_db.agentMemories).go();
      await _db.delete(_db.agentConversationSummaries).go();
      await _tryFtsStatement('DELETE FROM agent_memory_fts');
    });
  }

  @override
  Future<void> clearForLedger(int ledgerId) async {
    final rows = await (_db.select(_db.agentMemories)
          ..where((memory) => memory.ledgerId.equals(ledgerId)))
        .get();
    final ids = rows.map((memory) => memory.id).toList();
    await (_db.delete(_db.agentMemories)
          ..where((memory) => memory.ledgerId.equals(ledgerId)))
        .go();
    for (final id in ids) {
      await _tryFtsStatement(
        'DELETE FROM agent_memory_fts WHERE memory_id = ?',
        [id],
      );
    }
  }

  @override
  Future<List<AgentMemoryRecord>> listActive({required int ledgerId}) async {
    final now = DateTime.now();
    final rows = await (_db.select(_db.agentMemories)
          ..where(
            (memory) =>
                memory.status.equals('active') &
                memory.ledgerId.equals(ledgerId) &
                (memory.expiresAt.isNull() |
                    memory.expiresAt.isBiggerThanValue(now)),
          )
          ..orderBy([(memory) => d.OrderingTerm.desc(memory.updatedAt)]))
        .get();
    return rows.map(_toRecord).toList();
  }

  @override
  Future<void> saveSummary({
    required int? ledgerId,
    required int? conversationId,
    required String content,
  }) async {
    final now = DateTime.now();
    await _db.into(_db.agentConversationSummaries).insert(
          AgentConversationSummariesCompanion.insert(
            ledgerId: d.Value(ledgerId),
            conversationId: d.Value(conversationId),
            content: content,
            createdAt: d.Value(now),
            updatedAt: d.Value(now),
          ),
        );
  }

  @override
  Future<void> createRun({
    required String runId,
    required int? ledgerId,
    required String userMessage,
  }) =>
      _db.into(_db.agentRuns).insert(
            AgentRunsCompanion.insert(
              runId: runId,
              ledgerId: d.Value(ledgerId),
              status: 'running',
              userMessage: d.Value(userMessage),
            ),
            mode: d.InsertMode.insertOrIgnore,
          );

  @override
  Future<void> finishRun({
    required String runId,
    required String status,
    String? errorMessage,
  }) async {
    await (_db.update(_db.agentRuns)..where((run) => run.runId.equals(runId)))
        .write(
      AgentRunsCompanion(
        status: d.Value(status),
        errorMessage: d.Value(errorMessage),
        finishedAt: d.Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> recordToolCall(AgentToolCallAudit call) =>
      _db.into(_db.agentToolCalls).insert(
            AgentToolCallsCompanion.insert(
              runId: call.runId,
              callId: call.callId,
              toolName: call.toolName,
              status: call.status,
              detail: d.Value(call.detail),
            ),
            mode: d.InsertMode.insertOrIgnore,
          );

  @override
  Future<int> toolCallCount(String runId) async {
    final count = _db.agentToolCalls.id.count();
    final row = await (_db.selectOnly(_db.agentToolCalls)
          ..addColumns([count])
          ..where(_db.agentToolCalls.runId.equals(runId)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<List<AgentRunRecord>> listRecentRuns({required int ledgerId}) async {
    final rows = await (_db.select(_db.agentRuns)
          ..where((run) => run.ledgerId.equals(ledgerId))
          ..orderBy([(run) => d.OrderingTerm.desc(run.startedAt)])
          ..limit(30))
        .get();
    return rows
        .map(
          (run) => AgentRunRecord(
            runId: run.runId,
            ledgerId: run.ledgerId,
            status: run.status,
            userMessage: run.userMessage,
            errorMessage: run.errorMessage,
            startedAt: run.startedAt,
            finishedAt: run.finishedAt,
          ),
        )
        .toList();
  }

  @override
  Future<List<AgentToolCallRecord>> listToolCalls(String runId) async {
    final rows = await (_db.select(_db.agentToolCalls)
          ..where((call) => call.runId.equals(runId))
          ..orderBy([(call) => d.OrderingTerm.asc(call.createdAt)]))
        .get();
    return rows
        .map(
          (call) => AgentToolCallRecord(
            runId: call.runId,
            callId: call.callId,
            toolName: call.toolName,
            status: call.status,
            detail: call.detail,
            createdAt: call.createdAt,
          ),
        )
        .toList();
  }

  Future<List<int>> _searchFtsIds(String query) async {
    if (query.trim().isEmpty) return const [];
    try {
      final rows = await _db.customSelect(
        'SELECT memory_id FROM agent_memory_fts WHERE agent_memory_fts MATCH ? LIMIT ?',
        variables: [d.Variable<String>(query), d.Variable<int>(_searchLimit)],
      ).get();
      return rows
          .map((row) => int.parse(row.read<String>('memory_id')))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _tryFtsStatement(String sql,
      [List<Object?> variables = const []]) async {
    try {
      await _db.customStatement(sql, variables);
    } catch (_) {
      // FTS is an acceleration index. A partial migration must not prevent
      // local memory writes, which remain searchable through scoped LIKE.
    }
  }

  Future<List<AgentMemoryRecord>> _activeMemories({
    required int ledgerId,
    List<int>? ids,
    String? query,
  }) async {
    final now = DateTime.now();
    final rows = await (_db.select(_db.agentMemories)
          ..where(
            (memory) =>
                memory.status.equals('active') &
                (memory.ledgerId.isNull() | memory.ledgerId.equals(ledgerId)) &
                (memory.expiresAt.isNull() |
                    memory.expiresAt.isBiggerThanValue(now)) &
                (ids == null || ids.isEmpty
                    ? const d.Constant(true)
                    : memory.id.isIn(ids)) &
                (query == null || query.trim().isEmpty
                    ? const d.Constant(true)
                    : memory.content.like('%${query.trim()}%')),
          )
          ..orderBy([(memory) => d.OrderingTerm.desc(memory.updatedAt)])
          ..limit(_searchLimit))
        .get();
    return rows.map(_toRecord).toList();
  }

  AgentMemoryRecord _toRecord(AgentMemory memory) => AgentMemoryRecord(
        id: memory.id,
        ledgerId: memory.ledgerId,
        kind: memory.kind,
        content: memory.content,
        status: memory.status,
        expiresAt: memory.expiresAt,
        createdAt: memory.createdAt,
        updatedAt: memory.updatedAt,
      );
}
