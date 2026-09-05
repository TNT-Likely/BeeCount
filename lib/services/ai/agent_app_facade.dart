import 'dart:async';

import 'package:agentcore/agentcore.dart';
import 'package:uuid/uuid.dart';

import '../../agent/memory/agent_memory_repository.dart';
import '../../agent/model/native_tool_agent_model.dart';
import '../../agent/permission/agent_authorization_gate.dart';
import '../../agent/permission/agent_tool_permission.dart';
import '../../agent/policy/p0_agent_policy.dart';
import '../../agent/tools/local_agent_tools.dart';
import '../../ai/core/bill_info.dart';
import '../../l10n/app_localizations.dart';
import '../system/logger_service.dart';
import 'ai_chat_service.dart';

typedef AgentConversationHistoryLoader = Future<List<Map<String, Object?>>>
    Function(int conversationId);

/// App composition root for one foreground Agent message. It records local
/// audit state before a model call and turns the bounded tool result back into
/// the existing chat response/card contract.
final class AgentAppFacade {
  AgentAppFacade({
    required AgentMemoryRepository memoryRepository,
    required LocalAgentToolGateway toolGateway,
    required AgentToolPermissionStore permissionStore,
    this.conversationHistoryLoader,
    AgentModel? model,
    AgentPolicy policy = const P0AgentPolicy(),
    String Function()? runIdFactory,
  })  : _memoryRepository = memoryRepository,
        _toolGateway = toolGateway,
        _permissionStore = permissionStore,
        _model = model ??
            NativeToolAgentModel(
              transport: OpenAiCompatibleNativeToolTransport(),
            ),
        _policy = policy,
        _runIdFactory = runIdFactory ?? const Uuid().v4;

  final AgentMemoryRepository _memoryRepository;
  final LocalAgentToolGateway _toolGateway;
  final AgentToolPermissionStore _permissionStore;
  final AgentConversationHistoryLoader? conversationHistoryLoader;
  final AgentModel _model;
  final AgentPolicy _policy;
  final String Function() _runIdFactory;
  final Map<String, AgentToolAuthorizationBroker> _pendingAuthorizations = {};
  final Set<_RunAuthorization> _activeAuthorizations = {};

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
    for (final authorization in _activeAuthorizations) {
      authorization.denyPending();
    }
    _pendingAuthorizations.clear();
  }

  Future<AgentChatResponse> processMessage({
    required String message,
    required int ledgerId,
    int? conversationId,
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
        conversationId: conversationId,
        authorization: _createAuthorization(),
      );

  /// Emits live model text and the lifecycle of each locally executed tool.
  /// The completed event is always last, including safe error responses.
  Stream<AgentRunEvent> processMessageEvents({
    required String message,
    required int ledgerId,
    int? conversationId,
    bool allowsExplicitMemory = false,
    Map<String, Object?> context = const {},
    AppLocalizations? l10n,
  }) {
    var canceled = false;
    late final StreamController<AgentRunEvent> controller;
    void emit(AgentRunEvent event) {
      if (!canceled && !controller.isClosed) controller.add(event);
    }

    final authorization = _createAuthorization(emit: emit);
    controller = StreamController<AgentRunEvent>(
      onListen: () async {
        _activeAuthorizations.add(authorization);
        try {
          final response = await _processMessage(
            message: message,
            ledgerId: ledgerId,
            allowsExplicitMemory: allowsExplicitMemory,
            context: context,
            l10n: l10n,
            conversationId: conversationId,
            authorization: authorization,
            emit: emit,
          );
          emit(AgentRunCompletedEvent(response));
        } catch (error, stackTrace) {
          if (!canceled) controller.addError(error, stackTrace);
        } finally {
          authorization.denyPending();
          _activeAuthorizations.remove(authorization);
          unawaited(controller.close());
        }
      },
      onCancel: () {
        canceled = true;
        // StreamController also invokes onCancel after normal completion.
        if (!controller.isClosed) cancelPendingToolAuthorizations();
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
    required Map<String, Object?> context,
    required AppLocalizations? l10n,
    required int? conversationId,
    required _RunAuthorization authorization,
    void Function(AgentRunEvent event)? emit,
  }) async {
    final runId = _runIdFactory();
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

    final scope = AgentScope(
      id: runId,
      ledgerId: ledgerId,
      isForeground: true,
      allowsExplicitMemory: allowsExplicitMemory,
    );
    final localTools = LocalAgentTools(scope: scope, gateway: _toolGateway);
    final requestContext = Map<String, Object?>.of(context);
    requestContext['currentTime'] = DateTime.now().toIso8601String();
    await _loadConversationHistory(
      conversationId: conversationId,
      requestContext: requestContext,
      runId: runId,
    );
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
        policy: authorization,
        singleUseToolNames: const {'record_transaction_from_text'},
        singleUseToolDenialReason: (_) => '同一条消息只能记账一次。',
      ).run(request);
      await _recordAudit(runId, result);
      logger.info('AgentCore', '运行结束', {
        'runId': runId,
        'executedToolCalls': result.executedCalls.length,
        'deniedToolCalls': result.deniedCalls.length,
        'hasFinalText': result.text.isNotEmpty,
        'finalText': result.text,
      });

      final response = _responseFor(result, localTools, l10n);
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

  Future<void> _loadConversationHistory({
    required int? conversationId,
    required Map<String, Object?> requestContext,
    required String runId,
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
      const maxMessageCharacters = 2000;
      final safeHistory = <Map<String, Object?>>[];
      for (final item in history) {
        final role = item['role'];
        final content = item['content'];
        if ((role == 'user' || role == 'assistant') && content is String) {
          final trimmed = content.trim();
          if (trimmed.isNotEmpty) {
            safeHistory.add({
              'role': role as String,
              'content': trimmed.length > maxMessageCharacters
                  ? '${trimmed.substring(0, maxMessageCharacters)}…'
                  : trimmed,
            });
          }
        }
      }
      const maxRecentMessages = 12;
      final start = safeHistory.length > maxRecentMessages
          ? safeHistory.length - maxRecentMessages
          : 0;
      requestContext['recentMessages'] = List.unmodifiable(
        safeHistory.sublist(start),
      );
      logger.debug('AgentCore', '会话上下文已加载', {
        'runId': runId,
        'conversationId': conversationId,
        'count': safeHistory.length - start,
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

  Map<String, AgentTool> _observedTools(
    Map<String, AgentTool> tools,
    void Function(AgentRunEvent event)? emit,
    String runId,
  ) {
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

final class AgentToolAuthorizationRequestedEvent extends AgentRunEvent {
  const AgentToolAuthorizationRequestedEvent(this.request);

  final AgentToolAuthorizationRequest request;
}

final class AgentTextDeltaEvent extends AgentRunEvent {
  const AgentTextDeltaEvent(this.text);

  final String text;
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
