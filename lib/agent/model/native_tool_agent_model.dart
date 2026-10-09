import 'package:agentcore/agentcore.dart' as core;

import '../../ai/providers/ai_provider_factory.dart';
import '../../ai/providers/ai_provider_config.dart';
import '../../ai/providers/ai_provider_manager.dart';
import '../../services/system/logger_service.dart';
import 'agent_prompt_builder.dart';
import '../tools/local_agent_tool_catalog.dart';

// Keep the protocol types public from the App adapter so existing consumers do
// not need to know whether a model is provided by BeeCount or agentcore.
export 'package:agentcore/agentcore.dart'
    show
        AgentNativeEventSink,
        AgentNativeFinalTextResponse,
        AgentNativeModelActivity,
        AgentNativeModelPhase,
        AgentNativeModelResponse,
        AgentNativeProtocolException,
        AgentNativeStreamEvent,
        AgentNativeTextDelta,
        AgentNativeReasoningDelta,
        AgentNativeToolCall,
        AgentNativeToolCallsResponse,
        AgentNativeToolDefinition,
        AgentNativeToolRequest,
        AgentNativeToolResult,
        AgentNativeToolStream,
        AgentNativeToolTransport,
        AgentNativeToolTimeoutException,
        AgentNativeToolUnsupportedException,
        AgentRequestNativeStreaming;

/// BeeCount's OpenAI-compatible adapter: provider stream, local schemas,
/// localized prompt, and App logging are injected here; SSE aggregation lives
/// in the pure-Dart agentcore package.
final class OpenAiCompatibleNativeToolTransport
    implements core.AgentNativeToolTransport, core.AgentNativeToolRunFinalizer {
  OpenAiCompatibleNativeToolTransport({
    core.AgentNativeToolStream? toolStream,
    List<core.AgentNativeToolDefinition>? toolDefinitions,
    String? systemPrompt,
    Future<AIServiceProviderConfig?> Function()? loadConfig,
    core.AgentNativeToolStream Function(AIServiceProviderConfig)? createStream,
  })  : _toolStream = toolStream,
        _toolDefinitions = toolDefinitions ?? LocalAgentToolCatalog.definitions,
        _systemPrompt = systemPrompt ?? AgentPromptBuilder.nativeSystemPrompt,
        _createStream = createStream,
        _loadConfig = loadConfig ??
            (() => AIProviderManager.getProviderForCapability(
                AICapabilityType.text));

  final core.AgentNativeToolStream? _toolStream;
  final core.AgentNativeToolStream Function(AIServiceProviderConfig)?
      _createStream;
  final List<core.AgentNativeToolDefinition> _toolDefinitions;
  final String _systemPrompt;
  final Future<AIServiceProviderConfig?> Function() _loadConfig;
  final _delegates =
      <String, Future<core.OpenAiCompatibleNativeToolTransport>>{};

  Future<core.OpenAiCompatibleNativeToolTransport> _createDelegate() async {
    var stream = _toolStream;
    if (stream == null) {
      // Capture provider and Assistant Thinking once for all rounds in this run.
      final config = await _loadConfig();
      if (config == null || !config.isValid || !config.supportsText) {
        throw AIException('未配置可用的文本对话服务商');
      }
      stream = _createStream?.call(config) ??
          (({required messages, required tools, logTag}) =>
              AIProviderFactory.chatWithToolsStreamForConfig(
                  config: config,
                  messages: messages,
                  tools: tools,
                  logTag: logTag));
    }
    return core.OpenAiCompatibleNativeToolTransport(
        toolStream: stream,
        toolDefinitions: _toolDefinitions,
        systemPrompt: _systemPrompt,
        logSink: _log,
        isUnsupportedError: (error) =>
            error is AIException &&
            error.code == AIExceptionCode.nativeToolsUnsupported);
  }

  @override
  Future<core.AgentNativeModelResponse> complete(
      core.AgentNativeToolRequest request,
      {core.AgentNativeEventSink? onEvent}) async {
    final delegate =
        await _delegates.putIfAbsent(request.runId, _createDelegate);
    return delegate.complete(request, onEvent: onEvent);
  }

  @override
  void disposeRun(String runId) {
    final pending = _delegates.remove(runId);
    pending?.then((delegate) => delegate.disposeRun(runId),
        onError: (Object _) {});
  }

  static void _log(String event, Map<String, Object?> data) {
    switch (event) {
      case 'turnStarted':
        logger.debug('AgentNativeTools', '模型回合开始', data);
      case 'finalText':
        logger.debug('AgentNativeTools', '模型返回最终文本', data);
      case 'toolCalls':
        logger.debug('AgentNativeTools', '模型请求工具', data);
      case 'turnFinished':
        logger.debug('AgentNativeTools', '模型回合结束', data);
      case 'turnFailed':
        logger.warning('AgentNativeTools', '模型回合失败', data);
    }
  }
}

/// BeeCount composition adapter for the generic stateful model.
final class NativeToolAgentModel
    implements core.AgentModel, core.AgentRunFinalizer {
  NativeToolAgentModel({
    required core.AgentNativeToolTransport transport,
    AgentPromptBuilder promptBuilder = const AgentPromptBuilder(),
    Duration toolTurnTimeout = const Duration(seconds: 45),
  }) : _delegate = core.NativeToolAgentModel(
          transport: transport,
          promptBuilder: promptBuilder.buildNative,
          ledgerScopedToolNames: _ledgerScopedTools,
          toolTurnTimeout: toolTurnTimeout,
          emptyFinalText: '已完成。',
        );

  final core.NativeToolAgentModel _delegate;

  @override
  Future<core.AgentTurn> nextTurn(core.AgentRequest request) =>
      _delegate.nextTurn(request);

  @override
  void disposeRun(String runId) => _delegate.disposeRun(runId);

  static const _ledgerScopedTools = <String>{
    'query_transactions',
    'get_period_overview',
    'get_spending_trend',
    'get_category_breakdown',
    'get_budget_status',
    'get_recurring_transactions',
  };
}
