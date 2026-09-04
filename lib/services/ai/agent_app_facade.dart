import 'dart:async';

import 'package:agentcore/agentcore.dart';
import 'package:uuid/uuid.dart';

import '../../agent/memory/agent_memory_repository.dart';
import '../../agent/model/native_tool_agent_model.dart';
import '../../agent/policy/p0_agent_policy.dart';
import '../../agent/tools/local_agent_tools.dart';
import '../../ai/core/bill_info.dart';
import '../../l10n/app_localizations.dart';
import '../system/logger_service.dart';
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
  }) =>
      _processMessage(
        message: message,
        ledgerId: ledgerId,
        allowsExplicitMemory: allowsExplicitMemory,
        context: context,
        l10n: l10n,
      );

  /// Emits live model text and the lifecycle of each locally executed tool.
  /// The completed event is always last, including safe error responses.
  Stream<AgentRunEvent> processMessageEvents({
    required String message,
    required int ledgerId,
    bool allowsExplicitMemory = false,
    Map<String, Object?> context = const {},
    AppLocalizations? l10n,
  }) {
    final controller = StreamController<AgentRunEvent>();
    () async {
      final response = await _processMessage(
        message: message,
        ledgerId: ledgerId,
        allowsExplicitMemory: allowsExplicitMemory,
        context: context,
        l10n: l10n,
        emit: controller.add,
      );
      controller.add(AgentRunCompletedEvent(response));
      await controller.close();
    }();
    return controller.stream;
  }

  Future<AgentChatResponse> _processMessage({
    required String message,
    required int ledgerId,
    required bool allowsExplicitMemory,
    required Map<String, Object?> context,
    required AppLocalizations? l10n,
    void Function(AgentRunEvent event)? emit,
  }) async {
    final runId = _runIdFactory();
    logger.info('AgentCore', '运行开始', {'runId': runId, 'ledgerId': ledgerId});
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
    requestContext['currentTime'] = DateTime.now().toIso8601String();
    try {
      final memories = await _memoryRepository.search(
        ledgerId: ledgerId,
        query: message,
      );
      requestContext['memories'] =
          memories.map((item) => item.content).toList();
      logger.debug('AgentCore', '本地记忆已加载', {
        'runId': runId,
        'count': memories.length,
      });
    } catch (_) {
      // Memory is optional context: a local lookup failure must never turn
      // into a write or prevent the user from receiving a safe response.
      requestContext['memories'] = const <String>[];
    }
    var request = AgentRequest(
      text: message,
      scope: scope,
      context: requestContext,
    );
    if (emit != null) {
      request = request.withStreamingTextDeltas((event) {
        if (event case AgentNativeTextDelta(:final text)) {
          emit(AgentTextDeltaEvent(text));
        }
      });
    }

    try {
      final result = await AgentCore(
        model: _model,
        tools: _observedTools(localTools.build(), emit, runId),
        policy: _policy,
      ).run(request);
      await _recordAudit(runId, result);
      logger.info('AgentCore', '运行结束', {
        'runId': runId,
        'executedToolCalls': result.executedCalls.length,
        'deniedToolCalls': result.deniedCalls.length,
        'hasFinalText': result.text.isNotEmpty,
      });

      final response = _responseFor(result, localTools, l10n);
      await _memoryRepository.finishRun(runId: runId, status: 'completed');
      return AgentChatResponse(runId: runId, response: response);
    } on AgentNativeToolUnsupportedException {
      logger.warning('AgentCore', '模型不支持原生 Agent 能力', {'runId': runId});
      await _memoryRepository.finishRun(
        runId: runId,
        status: 'failed',
        errorMessage: 'agent_native_tools_unsupported',
      );
      return AgentChatResponse(
        runId: runId,
        response: AIResponse.error(
          l10n?.agentNativeToolsUnsupported ??
              '当前模型不支持 Agent 原生工具调用或流式输出，请在 AI 设置中切换模型。',
        ),
      );
    } on AgentNativeToolTimeoutException {
      logger.warning('AgentCore', '模型回合超时', {'runId': runId});
      await _memoryRepository.finishRun(
        runId: runId,
        status: 'failed',
        errorMessage: 'agent_turn_timeout',
      );
      return AgentChatResponse(
        runId: runId,
        response: AIResponse.error(
          l10n?.agentTurnTimedOut ?? 'AI 响应超时，请稍后重试。',
        ),
      );
    } catch (error, stackTrace) {
      logger.error('AgentCore', '运行失败', error, stackTrace);
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

  Map<String, AgentTool> _observedTools(
    Map<String, AgentTool> tools,
    void Function(AgentRunEvent event)? emit,
    String runId,
  ) {
    if (emit == null) return tools;
    return {
      for (final entry in tools.entries)
        entry.key: _ObservedAgentTool(
          delegate: entry.value,
          onStarted: (call) {
            logger.info('AgentCore', '工具开始执行', {
              'runId': runId,
              'tool': call.name,
            });
            emit(AgentToolStartedEvent(call.name));
          },
          onCompleted: (call, succeeded) {
            logger.info('AgentCore', '工具执行结束', {
              'runId': runId,
              'tool': call.name,
              'succeeded': succeeded,
            });
            emit(AgentToolCompletedEvent(call.name, succeeded: succeeded));
          },
        ),
    };
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

sealed class AgentRunEvent {
  const AgentRunEvent();
}

final class AgentTextDeltaEvent extends AgentRunEvent {
  const AgentTextDeltaEvent(this.text);

  final String text;
}

final class AgentToolStartedEvent extends AgentRunEvent {
  const AgentToolStartedEvent(this.toolName);

  final String toolName;
}

final class AgentToolCompletedEvent extends AgentRunEvent {
  const AgentToolCompletedEvent(this.toolName, {required this.succeeded});

  final String toolName;
  final bool succeeded;
}

final class AgentRunCompletedEvent extends AgentRunEvent {
  const AgentRunCompletedEvent(this.result);

  final AgentChatResponse result;
}

final class _ObservedAgentTool implements AgentTool {
  const _ObservedAgentTool({
    required this.delegate,
    required this.onStarted,
    required this.onCompleted,
  });

  final AgentTool delegate;
  final void Function(AgentToolCall call) onStarted;
  final void Function(AgentToolCall call, bool succeeded) onCompleted;

  @override
  String get name => delegate.name;

  @override
  Future<Map<String, Object?>> execute(AgentToolCall call) async {
    onStarted(call);
    try {
      final result = await delegate.execute(call);
      onCompleted(call, true);
      return result;
    } catch (_) {
      onCompleted(call, false);
      rethrow;
    }
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
