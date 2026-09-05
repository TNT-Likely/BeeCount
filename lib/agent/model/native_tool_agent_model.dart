import 'package:agentcore/agentcore.dart' as core;

import '../../ai/providers/ai_provider_factory.dart';
import '../../services/system/logger_service.dart';
import 'agent_prompt_builder.dart';

// Keep the protocol types public from the App adapter so existing consumers do
// not need to know whether a model is provided by BeeCount or agentcore.
export 'package:agentcore/agentcore.dart'
    show
        AgentNativeEventSink,
        AgentNativeFinalTextResponse,
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
        AgentNativeToolTransport,
        AgentNativeToolTimeoutException,
        AgentNativeToolUnsupportedException,
        AgentRequestNativeStreaming;

/// BeeCount's OpenAI-compatible adapter: provider stream, local schemas,
/// localized prompt, and App logging are injected here; SSE aggregation lives
/// in the pure-Dart agentcore package.
final class OpenAiCompatibleNativeToolTransport
    implements core.AgentNativeToolTransport {
  OpenAiCompatibleNativeToolTransport({
    core.AgentNativeToolStream? toolStream,
    List<core.AgentNativeToolDefinition>? toolDefinitions,
    String? systemPrompt,
  }) : _delegate = core.OpenAiCompatibleNativeToolTransport(
          toolStream: toolStream ?? AIProviderFactory.chatWithToolsStream,
          toolDefinitions: toolDefinitions ?? _toolDefinitions,
          systemPrompt: systemPrompt ?? AgentPromptBuilder.nativeSystemPrompt,
          logSink: _log,
          isUnsupportedError: (error) =>
              error is AIException &&
              (error.message.contains('不支持原生工具调用') ||
                  error.message.toLowerCase().contains('tool')),
        );

  final core.OpenAiCompatibleNativeToolTransport _delegate;

  @override
  Future<core.AgentNativeModelResponse> complete(
    core.AgentNativeToolRequest request, {
    core.AgentNativeEventSink? onEvent,
  }) =>
      _delegate.complete(request, onEvent: onEvent);

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

  static const _rangeParameters = <String, Object?>{
    'type': 'object',
    'properties': {
      'start': {
        'type': 'string',
        'description': '查询开始时间，ISO 8601 格式。',
      },
      'end': {
        'type': 'string',
        'description': '查询结束时间，ISO 8601 格式。',
      },
    },
    'additionalProperties': false,
  };

  static const _toolDefinitions = <core.AgentNativeToolDefinition>[
    core.AgentNativeToolDefinition(
      name: 'query_transactions',
      description: '查询当前账本交易',
      parameters: _rangeParameters,
    ),
    core.AgentNativeToolDefinition(
      name: 'get_spending_summary',
      description: '汇总当前账本支出',
      parameters: _rangeParameters,
    ),
    core.AgentNativeToolDefinition(
      name: 'get_budget_status',
      description: '读取当前账本预算',
      parameters: {'type': 'object'},
    ),
    core.AgentNativeToolDefinition(
      name: 'record_transaction_from_text',
      description: '记录当前用户明确给出的交易',
      parameters: {
        'type': 'object',
        'properties': {
          'sourceText': {'type': 'string'},
        },
        'required': ['sourceText'],
        'additionalProperties': false,
      },
    ),
    core.AgentNativeToolDefinition(
      name: 'save_explicit_memory',
      description: '保存用户明确要求记住的信息',
      parameters: {'type': 'object'},
    ),
    core.AgentNativeToolDefinition(
      name: 'forget_memory',
      description: '遗忘用户明确指定的记忆',
      parameters: {'type': 'object'},
    ),
  ];
}

/// BeeCount composition adapter for the generic stateful model.
final class NativeToolAgentModel implements core.AgentModel {
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

  static const _ledgerScopedTools = <String>{
    'query_transactions',
    'get_spending_summary',
    'get_budget_status',
  };
}
