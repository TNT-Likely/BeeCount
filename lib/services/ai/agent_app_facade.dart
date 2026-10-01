import 'dart:async';

import 'package:agentcore/agentcore.dart'
    hide
        AgentAuthorizationPolicy,
        AgentMemoryDraft,
        AgentMemoryRecord,
        AgentMemoryRepository,
        AgentToolAuthorizationBroker,
        AgentToolAuthorizationChoice,
        AgentToolAuthorizationRequest,
        AgentToolAuthorizationRequester,
        AgentToolCallAudit,
        AgentToolPermission,
        AgentToolPermissionDescriptor,
        AgentToolPermissionStore,
        AgentNativeEventSink,
        AgentNativeFinalTextResponse,
        AgentNativeModelActivity,
        AgentNativeModelPhase,
        AgentNativeModelResponse,
        AgentNativeProtocolException,
        AgentNativeStreamEvent,
        AgentNativeTextDelta,
        AgentNativeToolCall,
        AgentNativeToolCallsResponse,
        AgentNativeToolDefinition,
        AgentNativeToolRequest,
        AgentNativeToolResult,
        AgentNativeToolStream,
        AgentNativeToolTimeoutException,
        AgentNativeToolTransport,
        AgentNativeToolUnsupportedException,
        AgentRequestNativeStreaming,
        NativeToolAgentModel,
        OpenAiCompatibleNativeToolTransport;
import 'package:uuid/uuid.dart';

import '../../agent/memory/agent_memory_repository.dart';
import '../../agent/model/native_tool_agent_model.dart';
import '../../agent/permission/agent_authorization_gate.dart';
import '../../agent/permission/agent_tool_permission.dart';
import '../../agent/runtime/agent_execution_settings.dart';
import '../../agent/policy/p0_agent_policy.dart';
import '../../agent/tools/local_agent_tools.dart';
import '../../agent/tools/ledger_query_call_validator.dart';
import '../../ai/core/bill_info.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_zh.dart';
import '../../l10n/app_localizations_en.dart';
import '../system/logger_service.dart';
import 'ai_chat_service.dart';
import 'ledger_follow_up_suggestions.dart';

typedef AgentConversationHistoryLoader = Future<List<Map<String, Object?>>>
    Function(int conversationId);
typedef AgentModelCapabilityLoader = Future<AgentModelCapabilities?> Function();

/// App composition root for one foreground Agent message. It records local
/// audit state before a model call and turns the bounded tool result back into
/// the existing chat response/card contract.
final class AgentAppFacade {
  AgentAppFacade({
    required AgentMemoryRepository memoryRepository,
    required LocalAgentToolGateway toolGateway,
    required AgentToolPermissionStore permissionStore,
    AgentExecutionSettingsStore? executionSettingsStore,
    this.conversationHistoryLoader,
    this.contextCompressor = const AgentConversationContextCompressor(),
    AgentModel? model,
    AgentPolicy policy = const P0AgentPolicy(),
    String Function()? runIdFactory,
    DateTime Function()? now,
    this.modelCapabilityLoader,
  })  : _memoryRepository = memoryRepository,
        _toolGateway = toolGateway,
        _permissionStore = permissionStore,
        _executionSettingsStore =
            executionSettingsStore ?? _DefaultAgentExecutionSettingsStore(),
        _model = model ??
            NativeToolAgentModel(
              transport: OpenAiCompatibleNativeToolTransport(),
            ),
        _policy = policy,
        _now = now ?? DateTime.now,
        _runIdFactory = runIdFactory ?? const Uuid().v4;

  final AgentMemoryRepository _memoryRepository;
  final LocalAgentToolGateway _toolGateway;
  final AgentToolPermissionStore _permissionStore;
  final AgentExecutionSettingsStore _executionSettingsStore;
  final AgentConversationHistoryLoader? conversationHistoryLoader;
  final AgentConversationContextCompressor contextCompressor;
  final AgentModelCapabilityLoader? modelCapabilityLoader;
  final AgentModel _model;
  final AgentPolicy _policy;
  final DateTime Function() _now;
  final String Function() _runIdFactory;
  final Map<String, AgentToolAuthorizationBroker> _pendingAuthorizations = {};
  final Map<String, _ActiveAgentRun> _activeRuns = {};

  bool resolveToolAuthorization(
    String authorizationId,
    AgentToolAuthorizationChoice choice,
  ) =>
      _pendingAuthorizations.remove(authorizationId)?.resolve(
            authorizationId,
            choice,
          ) ??
      false;

  void cancelPendingToolAuthorizations() {
    for (final run in _activeRuns.values) {
      run.authorization.denyPending();
    }
    _pendingAuthorizations.clear();
  }

  /// Stops foreground runs that are waiting on a model response or consent.
  ///
  /// A local mutation already being executed is deliberately not force-killed;
  /// AgentCore observes this token before every next action so transactions
  /// remain consistent while blocked model requests end immediately.
  void cancelActiveRuns() {
    for (final run in _activeRuns.values.toList()) {
      run.cancellation.cancel();
    }
    cancelPendingToolAuthorizations();
  }

  /// Cancels only the foreground Agent run identified by [runId].
  bool cancelRun(String runId) {
    final run = _activeRuns[runId];
    if (run == null) return false;
    run.cancellation.cancel();
    run.authorization.denyPending();
    return true;
  }

  Future<AgentChatResponse> processMessage({
    required String message,
    required int ledgerId,
    int? conversationId,
    bool allowsExplicitMemory = false,
    bool readOnly = false,
    Map<String, Object?> context = const {},
    AppLocalizations? l10n,
  }) =>
      _processMessage(
        message: message,
        ledgerId: ledgerId,
        allowsExplicitMemory: allowsExplicitMemory,
        readOnly: readOnly,
        context: context,
        l10n: l10n,
        conversationId: conversationId,
        authorization: _createAuthorization(),
      );

  /// Emits live model text and the lifecycle of each locally executed tool.
  /// The completed event is always last, including safe error responses.
  Stream<AgentRunEvent> processMessageEvents({
    required String message,
    required int ledgerId,
    String? runId,
    int? conversationId,
    bool allowsExplicitMemory = false,
    bool readOnly = false,
    Map<String, Object?> context = const {},
    AppLocalizations? l10n,
  }) {
    var canceled = false;
    final activeRunId = runId ?? _runIdFactory();
    final cancellation = AgentCancellationToken();
    late final StreamController<AgentRunEvent> controller;
    void emit(AgentRunEvent event) {
      if (!canceled && !controller.isClosed) controller.add(event);
    }

    final authorization = _createAuthorization(emit: emit);
    controller = StreamController<AgentRunEvent>(
      onListen: () async {
        _activeRuns[activeRunId] = _ActiveAgentRun(
          authorization: authorization,
          cancellation: cancellation,
        );
        try {
          final response = await _processMessage(
            message: message,
            ledgerId: ledgerId,
            allowsExplicitMemory: allowsExplicitMemory,
            readOnly: readOnly,
            context: context,
            l10n: l10n,
            conversationId: conversationId,
            authorization: authorization,
            emit: emit,
            cancellationToken: cancellation,
            providedRunId: activeRunId,
          );
          emit(AgentRunCompletedEvent(response));
        } catch (error, stackTrace) {
          if (!canceled) controller.addError(error, stackTrace);
        } finally {
          authorization.denyPending();
          _activeRuns.remove(activeRunId);
          unawaited(controller.close());
        }
      },
      onCancel: () {
        canceled = true;
        cancellation.cancel();
        // StreamController also invokes onCancel after normal completion.
        if (!controller.isClosed) authorization.denyPending();
      },
    );
    return controller.stream;
  }

  _RunAuthorization _createAuthorization({
    void Function(AgentRunEvent event)? emit,
  }) {
    late final _RunAuthorization authorization;
    authorization = _RunAuthorization(
      hardPolicy: _policy,
      permissions: _permissionStore,
      onRequest: emit == null
          ? null
          : (request) {
              _pendingAuthorizations[request.authorizationId] =
                  authorization.broker;
              logger.info(
                  'AgentCore', '工具等待用户授权', authorization._requestLogData);
              emit(AgentToolAuthorizationRequestedEvent(request));
            },
      onSettled: _pendingAuthorizations.remove,
    );
    return authorization;
  }

  Future<AgentChatResponse> _processMessage({
    required String message,
    required int ledgerId,
    required bool allowsExplicitMemory,
    required bool readOnly,
    required Map<String, Object?> context,
    required AppLocalizations? l10n,
    required int? conversationId,
    required _RunAuthorization authorization,
    void Function(AgentRunEvent event)? emit,
    AgentCancellationToken? cancellationToken,
    String? providedRunId,
  }) async {
    final runId = providedRunId ?? _runIdFactory();
    logger.info('AgentCore', '运行开始', {
      'runId': runId,
      'ledgerId': ledgerId,
      'userMessage': message,
    });
    await _memoryRepository.createRun(
      runId: runId,
      ledgerId: ledgerId,
      userMessage: message,
    );

    final unsupportedResponse = await _unsupportedCapabilityResponse(
      runId: runId,
      l10n: l10n,
    );
    if (unsupportedResponse != null) return unsupportedResponse;

    final scope = AgentScope(
      id: runId,
      ledgerId: ledgerId,
      isForeground: true,
      allowsMutations: !readOnly,
      // The caller can grant this explicitly, while the foreground chat also
      // derives a narrow consent signal from the user's current message.
      // Ordinary messages remain unable to authorize a model-initiated memory
      // write, so hallucinated save/forget calls are still hard-denied.
      allowsExplicitMemory: allowsExplicitMemory ||
          P0AgentPolicy.hasExplicitMemoryIntent(message),
    );
    final localTools = LocalAgentTools(
      scope: scope,
      gateway: _toolGateway,
      now: _now,
    );
    final toolRegistry = localTools.buildRegistry();
    final requestContext = Map<String, Object?>.of(context);
    requestContext['currentTime'] = _now().toIso8601String();
    await _loadConversationHistory(
      conversationId: conversationId,
      requestContext: requestContext,
      runId: runId,
      ledgerId: ledgerId,
      currentMessage: message,
      cancellation: cancellationToken,
    );
    try {
      final memories = await _loadMemories(
        ledgerId: ledgerId,
        query: message,
      );
      requestContext['memories'] =
          memories.map((item) => item.content).toList();
      logger.debug('AgentCore', '本地记忆已加载', {
        'runId': runId,
        'count': memories.length,
        'memoryIds': memories.map((memory) => memory.id).toList(),
      });
    } catch (_) {
      // Memory is optional context: a local lookup failure must never turn
      // into a write or prevent the user from receiving a safe response.
      requestContext['memories'] = const <String>[];
    }
    final toolSelection = toolRegistry.select(
      _toolSelectionQuery(message, requestContext),
      requirementQuery: message,
      maximumTools: 7,
    );
    logger.debug('AgentCore', '本次运行工具目录已选择', {
      'runId': runId,
      'tools': toolSelection.names.toList()..sort(),
    });
    var bufferQueryText = false;
    var request = AgentRequest(
      text: message,
      scope: scope,
      context: requestContext,
      availableToolNames: toolSelection.names,
    );
    if (emit != null) {
      request = request.withStreamingTextDeltas((event) {
        // Known invalid queries still need a verified final response; normal
        // tool-backed answers must not be buffered by directory keywords.
        if ((cancellationToken?.isCancelled) ?? false) {
          return;
        }
        switch (event) {
          case AgentNativeModelActivity(:final phase):
            emit(AgentModelActivityEvent(phase));
          case AgentNativeTextDelta(:final text):
            if (!bufferQueryText) emit(AgentTextDeltaEvent(text));
        }
      });
    }
    final failedToolAudits = <AgentToolCallAudit>[];
    final suggestionEvidence = <AgentSuggestionEvidence>[];

    try {
      final executionSettings = await _executionSettingsStore.read();
      logger.debug('AgentCore', '本地执行深度已加载', {
        'runId': runId,
        'maximumModelTurns': executionSettings.maximumModelTurns,
        'maximumToolCalls': executionSettings.maximumToolCalls,
      });
      final result = await AgentCore(
        model: _model,
        tools: _observedTools(
          toolSelection.tools,
          emit,
          runId,
          onEvidence: suggestionEvidence.add,
          onToolFailed: (call, error) {
            bufferQueryText = true;
            failedToolAudits.add(
              AgentToolCallAudit(
                runId: runId,
                callId: call.id,
                toolName: call.name,
                status: 'failed',
                detail: error.toString(),
              ),
            );
          },
        ),
        policy: authorization,
        maximumModelTurns: executionSettings.maximumModelTurns,
        maximumToolCalls: executionSettings.maximumToolCalls,
        singleUseToolNames: toolSelection.singleUseToolNames,
        deduplicatedToolNames: toolSelection.deduplicatedToolNames,
        singleUseToolDenialReason: (_) => '同一条消息只能记账一次。',
        cancellationToken: cancellationToken,
        validateToolCall: (request, call) {
          final issue = LedgerQueryCallValidator.validate(request, call);
          if (issue != null) bufferQueryText = true;
          return issue;
        },
      ).run(request);
      await _recordAudit(runId, result, failedToolAudits: failedToolAudits);
      if (result.wasCancelled) {
        logger.info('AgentCore', '运行已由用户停止', {
          'runId': runId,
          'executedToolCalls': result.executedCalls.length,
          'deniedToolCalls': result.deniedCalls.length,
        });
        await _memoryRepository.finishRun(runId: runId, status: 'cancelled');
        return AgentChatResponse(
          runId: runId,
          response: AIResponse.text(
            l10n?.agentRunCancelled ?? '本次操作已停止。',
          ),
        );
      }
      final requiredTools = toolSelection.requiredToolNames;
      final calledRequiredTool = result.executedCalls
              .any((call) => requiredTools.contains(call.name)) ||
          result.deniedCalls
              .any((denied) => requiredTools.contains(denied.call.name));
      // Directory keyword matches are diagnostic hints, not a contract for
      // which tool the model must use. Other queries or conversation context
      // may already provide the requested information.
      if (requiredTools.isNotEmpty && !calledRequiredTool) {
        logger.debug('AgentCore', '未调用目录匹配工具，仅记录诊断，不拦截回答', {
          'runId': runId,
          'requiredTools': requiredTools.toList()..sort(),
        });
      }
      if (LedgerQueryCallValidator.hasUnresolvedIssue(result)) {
        logger.warning('AgentCore', '查询参数校验未纠正，拒绝错误答案', {
          'runId': runId,
          'issues':
              result.rejectedCalls.map((call) => call.issue.code).toList(),
        });
        await _memoryRepository.finishRun(
          runId: runId,
          status: 'failed',
          errorMessage: 'agent_query_validation_failed',
        );
        return AgentChatResponse(
          runId: runId,
          response: AIResponse.error(
            l10n?.agentQueryValidationFailed ?? '查询参数未能纠正，暂时无法给出可靠结果。请重试。',
          ),
        );
      }
      logger.info('AgentCore', '运行结束', {
        'runId': runId,
        'executedToolCalls': result.executedCalls.length,
        'deniedToolCalls': result.deniedCalls.length,
        'terminationReason': result.terminationReason.name,
        'hasFinalText': result.text.isNotEmpty,
        'finalText': result.text,
      });

      final baseResponse = _responseFor(result, localTools, l10n);
      final canSuggest =
          (baseResponse.type == 'text' || baseResponse.type == 'bill_card') &&
              result.terminationReason == AgentRunTerminationReason.completed &&
              result.deniedCalls.isEmpty &&
              failedToolAudits.isEmpty;
      final recent = requestContext['recentMessages'];
      final suggestions = LedgerFollowUpSuggestions.generate(
        evidence: suggestionEvidence,
        l10n: l10n ??
            (requestContext['languageCode'] == 'en'
                ? AppLocalizationsEn()
                : AppLocalizationsZh()),
        currentPrompt: message,
        recentPrompts: recent is List
            ? recent
                .whereType<Map>()
                .where((row) => row['role'] == 'user')
                .map((row) => row['content'])
                .whereType<String>()
            : const [],
        enabled: canSuggest,
      );
      final response = baseResponse.withFollowUpSuggestions(suggestions,
          allowPromptSuggestions: canSuggest);
      logger.info('AgentCore', '运行结果已生成', {
        'runId': runId,
        'responseType': response.type,
        'text': response.text,
        'billCount': response.bills.length,
        'transactionIds': response.transactionIds,
      });
      await _memoryRepository.finishRun(runId: runId, status: 'completed');
      return AgentChatResponse(runId: runId, response: response);
    } on AgentNativeToolUnsupportedException {
      await _recordFailedToolAudits(failedToolAudits);
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
              '当前模型可以进行普通对话，但不支持读取或操作账本所需的原生工具调用。请前往“设置 > AI 设置 > 服务商管理”切换模型或运行文本模型测试。',
          action: AIResponseAction.openProviderSettings,
        ),
      );
    } on AgentNativeToolTimeoutException {
      await _recordFailedToolAudits(failedToolAudits);
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
      await _recordFailedToolAudits(failedToolAudits);
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

  Future<AgentChatResponse?> _unsupportedCapabilityResponse({
    required String runId,
    required AppLocalizations? l10n,
  }) async {
    final loader = modelCapabilityLoader;
    if (loader == null) return null;
    try {
      final capabilities = await loader();
      if (capabilities?.nativeToolCalls != AgentCapabilitySupport.unsupported) {
        return null;
      }
      logger.warning('AgentCore', '能力探测确认模型不支持原生工具', {
        'runId': runId,
        'detail': capabilities?.detail,
      });
      await _memoryRepository.finishRun(
        runId: runId,
        status: 'failed',
        errorMessage: 'agent_native_tools_unsupported',
      );
      return AgentChatResponse(
        runId: runId,
        response: AIResponse.error(
          l10n?.agentNativeToolsUnsupported ??
              '当前模型可以进行普通对话，但不支持读取或操作账本所需的原生工具调用。请前往“设置 > AI 设置 > 服务商管理”切换模型或运行文本模型测试。',
          action: AIResponseAction.openProviderSettings,
        ),
      );
    } on Object catch (error, stackTrace) {
      // A transient probe/cache failure must not replace the real model call.
      logger.warning('AgentCore', '模型能力预检失败，继续实际请求', {
        'runId': runId,
        'error': error.toString(),
      });
      logger.debug('AgentCore', '模型能力预检异常堆栈', {
        'runId': runId,
        'stackTrace': stackTrace.toString(),
      });
      return null;
    }
  }

  String _toolSelectionQuery(
    String message,
    Map<String, Object?> requestContext,
  ) {
    final buffer = StringBuffer(message);
    final recent = requestContext['recentMessages'];
    if (recent is List) {
      for (final item in recent.reversed.take(4)) {
        if (item is Map && item['content'] is String) {
          buffer
            ..write('\n')
            ..write(item['content']);
        }
      }
    }
    return buffer.toString();
  }

  Future<void> _loadConversationHistory({
    required int? conversationId,
    required Map<String, Object?> requestContext,
    required String runId,
    required int ledgerId,
    required String currentMessage,
    AgentCancellationToken? cancellation,
  }) async {
    final loader = conversationHistoryLoader;
    if (conversationId == null || loader == null) {
      requestContext.putIfAbsent(
        'recentMessages',
        () => const <Map<String, Object?>>[],
      );
      return;
    }

    try {
      final history = await loader(conversationId);
      final prepared = await contextCompressor.prepare(
        history: history,
        currentMessage: currentMessage,
        conversationId: conversationId.toString(),
        scopeId: ledgerId.toString(),
        cancellation: cancellation,
      );
      requestContext['recentMessages'] = prepared.recentMessages;
      requestContext['summary'] = prepared.summary;
      logger.debug('AgentCore', '会话上下文已加载', {
        'runId': runId,
        'conversationId': conversationId,
        'count': prepared.recentMessages.length,
        'hasSummary': prepared.summary != null,
      });
    } on Object catch (error, stackTrace) {
      // Conversation context is optional. A local history read failure must
      // not prevent the current request or turn history into a write source.
      requestContext['recentMessages'] = const <Map<String, Object?>>[];
      logger.warning('AgentCore', '会话上下文加载失败', {
        'runId': runId,
        'conversationId': conversationId,
        'error': error.toString(),
      });
      logger.debug('AgentCore', '会话上下文异常堆栈', {
        'runId': runId,
        'stackTrace': stackTrace.toString(),
      });
    }
  }

  /// Retrieves lexical matches first, then fills the bounded context with
  /// recent active memories. A user may ask an equivalent question (for
  /// example, “我是谁”) that shares no exact words with the saved memory
  /// (“用户的身份是笑”), so query-only retrieval would incorrectly report an
  /// empty memory context.
  Future<List<AgentMemoryRecord>> _loadMemories({
    required int ledgerId,
    required String query,
  }) async {
    const maxMemories = 6;
    final matched = await _memoryRepository.search(
      ledgerId: ledgerId,
      query: query,
    );
    if (matched.length >= maxMemories) {
      return matched.take(maxMemories).toList(growable: false);
    }

    final recent = await _memoryRepository.listActive(ledgerId: ledgerId);
    final byId = <int, AgentMemoryRecord>{
      for (final memory in matched) memory.id: memory,
    };
    for (final memory in recent) {
      byId.putIfAbsent(memory.id, () => memory);
      if (byId.length >= maxMemories) break;
    }
    return byId.values.toList(growable: false);
  }

  Map<String, AgentTool> _observedTools(
    Map<String, AgentTool> tools,
    void Function(AgentRunEvent event)? emit,
    String runId, {
    required void Function(AgentSuggestionEvidence) onEvidence,
    void Function(AgentToolCall call, Object error)? onToolFailed,
  }) {
    return {
      for (final entry in tools.entries)
        entry.key: _ObservedAgentTool(
          delegate: entry.value,
          onStarted: (call) {
            logger.info('AgentCore', '工具开始执行', {
              'runId': runId,
              'callId': call.id,
              'tool': call.name,
              'arguments': call.arguments,
            });
            emit?.call(
              AgentToolStartedEvent(
                call.name,
                callId: call.id,
                arguments: call.arguments,
              ),
            );
          },
          onFinished: (call, result, error) {
            if (error == null &&
                result != null &&
                !result.containsKey('error')) {
              onEvidence(AgentSuggestionEvidence(
                  toolName: call.name,
                  arguments: call.arguments,
                  result: result));
            }
            final data = {
              'runId': runId,
              'callId': call.id,
              'tool': call.name,
              'arguments': call.arguments,
              if (result != null) 'result': result,
              if (error != null) 'error': error.toString(),
            };
            if (error == null) {
              logger.info('AgentCore', '工具执行结束', data);
            } else {
              logger.warning('AgentCore', '工具执行失败', data);
            }
            emit?.call(
              AgentToolCompletedEvent(
                call.name,
                callId: call.id,
                arguments: call.arguments,
                result: result,
                error: error?.toString(),
                succeeded: error == null,
              ),
            );
            if (error != null) onToolFailed?.call(call, error);
          },
        ),
    };
  }

  Future<void> _recordAudit(
    String runId,
    AgentRunResult result, {
    Iterable<AgentToolCallAudit> failedToolAudits = const [],
  }) async {
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
      logger.warning('AgentCore', '工具调用已拒绝', {
        'runId': runId,
        'callId': denied.call.id,
        'tool': denied.call.name,
        'arguments': denied.call.arguments,
        'reason': denied.reason,
      });
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
    for (final rejected in result.rejectedCalls) {
      await _memoryRepository.recordToolCall(
        AgentToolCallAudit(
          runId: runId,
          callId: rejected.call.id,
          toolName: rejected.call.name,
          status: 'rejected',
          detail: rejected.issue.code,
        ),
      );
    }
    await _recordFailedToolAudits(failedToolAudits);
  }

  Future<void> _recordFailedToolAudits(
    Iterable<AgentToolCallAudit> failedToolAudits,
  ) async {
    for (final audit in failedToolAudits) {
      await _memoryRepository.recordToolCall(audit);
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
      return AIResponse.text(
        l10n?.agentRecordCreated(recorded.transactionIds.length) ??
            '已创建 ${recorded.transactionIds.length} 笔账单。',
      );
    }
    return AIResponse.text(
      result.text.isEmpty
          ? (l10n?.agentStepsExceeded ?? '这次操作步骤过多，请简化后重试。')
          : result.text,
    );
  }
}

final class _DefaultAgentExecutionSettingsStore
    implements AgentExecutionSettingsStore {
  @override
  Future<AgentExecutionSettings> read() async => AgentExecutionSettings();

  @override
  Future<void> setMaximumModelTurns(int value) async {}
}

final class _ActiveAgentRun {
  const _ActiveAgentRun({
    required this.authorization,
    required this.cancellation,
  });

  final _RunAuthorization authorization;
  final AgentCancellationToken cancellation;
}

sealed class AgentRunEvent {
  const AgentRunEvent();
}

final class AgentToolAuthorizationRequestedEvent extends AgentRunEvent {
  const AgentToolAuthorizationRequestedEvent(this.request);

  final AgentToolAuthorizationRequest request;
}

final class AgentTextDeltaEvent extends AgentRunEvent {
  const AgentTextDeltaEvent(this.text);

  final String text;
}

final class AgentModelActivityEvent extends AgentRunEvent {
  const AgentModelActivityEvent(this.phase);

  final AgentNativeModelPhase phase;
}

final class AgentToolStartedEvent extends AgentRunEvent {
  AgentToolStartedEvent(
    this.toolName, {
    this.callId = '',
    Map<String, Object?> arguments = const {},
  }) : arguments = Map.unmodifiable(arguments);

  final String toolName;
  final String callId;
  final Map<String, Object?> arguments;
}

final class AgentToolCompletedEvent extends AgentRunEvent {
  AgentToolCompletedEvent(
    this.toolName, {
    required this.succeeded,
    this.callId = '',
    Map<String, Object?> arguments = const {},
    Map<String, Object?>? result,
    this.error,
  })  : arguments = Map.unmodifiable(arguments),
        result = result == null ? null : Map.unmodifiable(result);

  final String toolName;
  final bool succeeded;
  final String callId;
  final Map<String, Object?> arguments;
  final Map<String, Object?>? result;
  final String? error;
}

final class AgentRunCompletedEvent extends AgentRunEvent {
  const AgentRunCompletedEvent(this.result);

  final AgentChatResponse result;
}

/// Observes the shared authorization policy without duplicating its hard rules.
/// One instance belongs to one sequential AgentCore run.
final class _RunAuthorization
    implements AgentPolicy, AgentToolAuthorizationRequester {
  _RunAuthorization({
    required AgentPolicy hardPolicy,
    required AgentToolPermissionStore permissions,
    required void Function(AgentToolAuthorizationRequest)? onRequest,
    required this.onSettled,
  }) {
    broker = AgentToolAuthorizationBroker(onRequest: (request) {
      _currentRequest = request;
      if (_canceled || onRequest == null) {
        logger.info('AgentCore', '工具等待用户授权', _requestLogData);
        broker.resolve(
            request.authorizationId, AgentToolAuthorizationChoice.deny);
      } else {
        onRequest(request);
      }
    });
    _policy = AgentAuthorizationPolicy(
      hardPolicy: hardPolicy,
      permissions: permissions,
      requester: this,
      onPersistenceError: (error, stackTrace) {
        _persistenceFailed = true;
        logger.warning('AgentCore', '工具授权偏好保存失败', {
          ..._requestLogData,
          'choice': _choice?.name,
          'persisted': false,
          'error': error.toString(),
        });
      },
    );
  }

  late final AgentToolAuthorizationBroker broker;
  late final AgentAuthorizationPolicy _policy;
  final void Function(String authorizationId) onSettled;
  AgentToolAuthorizationRequest? _currentRequest;
  AgentToolAuthorizationChoice? _choice;
  bool _persistenceFailed = false;
  bool _canceled = false;

  Map<String, Object?> get _requestLogData => {
        'runId': _currentRequest?.runId,
        'authorizationId': _currentRequest?.authorizationId,
        'tool': _currentRequest?.toolName,
        'arguments': _currentRequest?.arguments,
        'ledgerId': _currentRequest?.ledgerId,
      };

  @override
  Future<AgentPolicyDecision> decide(
    AgentRequest request,
    AgentToolCall call,
  ) async {
    _currentRequest = null;
    _choice = null;
    _persistenceFailed = false;
    if (_canceled) {
      return const AgentPolicyDecision.deny('用户未授权此操作。');
    }
    final decision = await _policy.decide(request, call);
    if (_currentRequest != null) {
      logger.info('AgentCore', '工具授权决定已完成', {
        ..._requestLogData,
        'choice': _choice?.name,
        'persisted': _choice == AgentToolAuthorizationChoice.alwaysAllow &&
            !_persistenceFailed,
      });
    }
    // Cancellation can arrive while permission lookup or persistence is pending,
    // including paths which never ask the broker (stored alwaysAllow).
    return _canceled ? const AgentPolicyDecision.deny('用户未授权此操作。') : decision;
  }

  @override
  Future<AgentToolAuthorizationChoice> request({
    required String runId,
    required int? ledgerId,
    required String toolName,
    required Map<String, Object?> arguments,
  }) async {
    try {
      return _choice = await broker.request(
        runId: runId,
        ledgerId: ledgerId,
        toolName: toolName,
        arguments: arguments,
      );
    } finally {
      final request = _currentRequest;
      if (request != null) onSettled(request.authorizationId);
    }
  }

  @override
  void denyPending() {
    _canceled = true;
    broker.denyPending();
  }
}

final class _ObservedAgentTool implements AgentTool {
  const _ObservedAgentTool({
    required this.delegate,
    required this.onStarted,
    required this.onFinished,
  });

  final AgentTool delegate;
  final void Function(AgentToolCall call) onStarted;
  final void Function(
    AgentToolCall call,
    Map<String, Object?>? result,
    Object? error,
  ) onFinished;

  @override
  String get name => delegate.name;

  @override
  Future<Map<String, Object?>> execute(AgentToolCall call) async {
    onStarted(call);
    try {
      final result = await delegate.execute(call);
      onFinished(call, result, null);
      return result;
    } catch (error) {
      onFinished(call, null, error);
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
