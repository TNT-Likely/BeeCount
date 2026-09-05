/// Local-only data contracts for Agent memory and auditable tool execution.
/// Implementations belong to the host application.
final class AgentMemoryDraft {
  const AgentMemoryDraft({
    required this.ledgerId,
    required this.kind,
    required this.content,
    this.keywords,
    this.sourceMessageId,
    this.expiresAt,
  });

  final int? ledgerId;
  final String kind;
  final String content;
  final String? keywords;
  final int? sourceMessageId;
  final DateTime? expiresAt;
}

final class AgentMemoryRecord {
  const AgentMemoryRecord({
    required this.id,
    required this.ledgerId,
    required this.kind,
    required this.content,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int? ledgerId;
  final String kind;
  final String content;
  final String status;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class AgentToolCallAudit {
  const AgentToolCallAudit({
    required this.runId,
    required this.callId,
    required this.toolName,
    required this.status,
    this.detail,
  });

  final String runId;
  final String callId;
  final String toolName;
  final String status;
  final String? detail;
}

/// A locally persisted Agent run, suitable for a host UI's activity history.
final class AgentRunRecord {
  const AgentRunRecord({
    required this.runId,
    required this.ledgerId,
    required this.status,
    required this.userMessage,
    required this.errorMessage,
    required this.startedAt,
    required this.finishedAt,
  });

  final String runId;
  final int? ledgerId;
  final String status;
  final String? userMessage;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? finishedAt;
}

/// A locally persisted tool event belonging to an [AgentRunRecord].
final class AgentToolCallRecord {
  const AgentToolCallRecord({
    required this.runId,
    required this.callId,
    required this.toolName,
    required this.status,
    required this.detail,
    required this.createdAt,
  });

  final String runId;
  final String callId;
  final String toolName;
  final String status;
  final String? detail;
  final DateTime createdAt;
}

abstract interface class AgentMemoryRepository {
  Future<AgentMemoryRecord> saveExplicit(AgentMemoryDraft draft);

  Future<List<AgentMemoryRecord>> search({
    required int ledgerId,
    required String query,
  });

  Future<void> forget(int memoryId);
  Future<void> clearAll();
  Future<void> clearForLedger(int ledgerId);

  Future<List<AgentMemoryRecord>> listActive({required int ledgerId});

  Future<void> saveSummary({
    required int? ledgerId,
    required int? conversationId,
    required String content,
  });

  Future<void> createRun({
    required String runId,
    required int? ledgerId,
    required String userMessage,
  });

  Future<void> finishRun({
    required String runId,
    required String status,
    String? errorMessage,
  });

  Future<void> recordToolCall(AgentToolCallAudit call);
  Future<int> toolCallCount(String runId);
  Future<List<AgentRunRecord>> listRecentRuns({required int ledgerId});
  Future<List<AgentToolCallRecord>> listToolCalls(String runId);
}
