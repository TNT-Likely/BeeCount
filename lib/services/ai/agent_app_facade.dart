import 'package:agentcore/agentcore.dart';
import 'package:uuid/uuid.dart';

import '../../agent/memory/agent_memory_repository.dart';
import '../../agent/model/json_agent_model.dart';
import '../../agent/model/native_tool_agent_model.dart';
import '../../agent/policy/p0_agent_policy.dart';
import '../../agent/tools/local_agent_tools.dart';
import '../../ai/core/bill_info.dart';
import '../../l10n/app_localizations.dart';
import 'ai_chat_service.dart';

/// App composition root for one foreground Agent message. It records local
/// audit state before a model call and turns the bounded tool result back into
/// the existing chat response/card contract.
final class AgentAppFacade {
  AgentAppFacade({
    required AgentMemoryRepository memoryRepository,
    required LocalAgentToolGateway toolGateway,
    AgentModel? model,
    AgentPolicy policy = const P0AgentPolicy(),
    String Function()? runIdFactory,
  })  : _memoryRepository = memoryRepository,
        _toolGateway = toolGateway,
        _model = model ??
            NativeToolAgentModel(
              transport: OpenAiCompatibleNativeToolTransport(),
              fallback: JsonAgentModel(),
            ),
        _policy = policy,
        _runIdFactory = runIdFactory ?? const Uuid().v4;

  final AgentMemoryRepository _memoryRepository;
  final LocalAgentToolGateway _toolGateway;
  final AgentModel _model;
  final AgentPolicy _policy;
  final String Function() _runIdFactory;

  Future<AgentChatResponse> processMessage({
    required String message,
    required int ledgerId,
    bool allowsExplicitMemory = false,
    Map<String, Object?> context = const {},
    AppLocalizations? l10n,
  }) async {
    final runId = _runIdFactory();
    await _memoryRepository.createRun(
      runId: runId,
      ledgerId: ledgerId,
      userMessage: message,
    );

    final scope = AgentScope(
      id: runId,
      ledgerId: ledgerId,
      isForeground: true,
      allowsExplicitMemory: allowsExplicitMemory,
    );
    final localTools = LocalAgentTools(scope: scope, gateway: _toolGateway);
    final requestContext = Map<String, Object?>.of(context);
    try {
      final memories = await _memoryRepository.search(
        ledgerId: ledgerId,
        query: message,
      );
      requestContext['memories'] =
          memories.map((item) => item.content).toList();
    } catch (_) {
      // Memory is optional context: a local lookup failure must never turn
      // into a write or prevent the user from receiving a safe response.
      requestContext['memories'] = const <String>[];
    }
    final request = AgentRequest(
      text: message,
      scope: scope,
      context: requestContext,
    );

    try {
      final result = await AgentCore(
        model: _model,
        tools: localTools.build(),
        policy: _policy,
      ).run(request);
      await _recordAudit(runId, result);

      final response = _responseFor(result, localTools, l10n);
      await _memoryRepository.finishRun(runId: runId, status: 'completed');
      return AgentChatResponse(runId: runId, response: response);
    } catch (_) {
      await _memoryRepository.finishRun(
        runId: runId,
        status: 'failed',
        errorMessage: 'agent_run_failed',
      );
      return AgentChatResponse(
        runId: runId,
        response: AIResponse.error(l10n?.agentRunFailed ?? 'AI 服务暂时不可用，请稍后重试。'),
      );
    }
  }

  Future<void> _recordAudit(String runId, AgentRunResult result) async {
    for (final call in result.executedCalls) {
      await _memoryRepository.recordToolCall(
        AgentToolCallAudit(
          runId: runId,
          callId: call.id,
          toolName: call.name,
          status: 'completed',
        ),
      );
    }
    for (final denied in result.deniedCalls) {
      await _memoryRepository.recordToolCall(
        AgentToolCallAudit(
          runId: runId,
          callId: denied.call.id,
          toolName: denied.call.name,
          status: 'denied',
          detail: denied.reason,
        ),
      );
    }
  }

  AIResponse _responseFor(
    AgentRunResult result,
    LocalAgentTools tools,
    AppLocalizations? l10n,
  ) {
    for (final call in result.executedCalls) {
      if (call.name != 'record_transaction_from_text') continue;
      final recorded = tools.recordResultFor(call);
      if (recorded == null || !recorded.success) {
        return AIResponse.text(
          l10n?.agentRecordIncomplete ?? '未识别到完整的记账信息，请补充金额和用途后重试。',
        );
      }
      final bills = recorded.bills
          .map((bill) => BillInfo.fromJson(Map<String, dynamic>.from(bill)))
          .toList();
      if (bills.isNotEmpty && bills.length == recorded.transactionIds.length) {
        return AIResponse.billCards(bills, recorded.transactionIds);
      }
      return AIResponse.text('已创建 ${recorded.transactionIds.length} 笔账单。');
    }
    return AIResponse.text(
      result.text.isEmpty
          ? (l10n?.agentStepsExceeded ?? '这次操作步骤过多，请简化后重试。')
          : result.text,
    );
  }
}

final class AgentChatResponse {
  const AgentChatResponse({required this.runId, required this.response});

  final String runId;
  final AIResponse response;

  String get type => response.type;
  String get text => response.text;
  List<BillInfo> get bills => response.bills;
  List<int> get transactionIds => response.transactionIds;
}
