import 'dart:collection';
import 'dart:convert';

import 'package:agentcore/agentcore.dart';

import '../../ai/providers/ai_provider_factory.dart';
import 'agent_prompt_builder.dart';

final class AgentNativeToolDefinition {
  const AgentNativeToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, Object?> parameters;
}

final class AgentNativeToolCall {
  AgentNativeToolCall({
    required this.id,
    required this.name,
    Map<String, Object?> arguments = const {},
  }) : arguments = UnmodifiableMapView(Map.of(arguments));

  final String id;
  final String name;
  final Map<String, Object?> arguments;
}

final class AgentNativeToolResult {
  const AgentNativeToolResult({
    required this.toolCallId,
    required this.content,
  });

  final String toolCallId;
  final String content;
}

final class AgentNativeToolRequest {
  AgentNativeToolRequest({
    required this.runId,
    required List<AgentNativeToolResult> toolResults,
    required this.userPrompt,
  }) : toolResults = UnmodifiableListView(toolResults);

  final String runId;
  final String userPrompt;
  final List<AgentNativeToolResult> toolResults;
}

sealed class AgentNativeModelResponse {
  const AgentNativeModelResponse._();

  const factory AgentNativeModelResponse.finalText(String text) =
      AgentNativeFinalTextResponse;
  factory AgentNativeModelResponse.toolCalls(List<AgentNativeToolCall> calls) =
      AgentNativeToolCallsResponse;
}

final class AgentNativeFinalTextResponse extends AgentNativeModelResponse {
  const AgentNativeFinalTextResponse(this.text) : super._();

  final String text;
}

final class AgentNativeToolCallsResponse extends AgentNativeModelResponse {
  AgentNativeToolCallsResponse(List<AgentNativeToolCall> calls)
      : calls = UnmodifiableListView(calls),
        super._();

  final List<AgentNativeToolCall> calls;
}

abstract interface class AgentNativeToolTransport {
  Future<AgentNativeModelResponse> complete(AgentNativeToolRequest request);
}

final class AgentNativeToolUnsupportedException implements Exception {
  const AgentNativeToolUnsupportedException();
}

/// Stateful OpenAI-compatible transport. It emits actual `tools` in the HTTP
/// payload and appends assistant tool_calls plus role:tool results verbatim.
final class OpenAiCompatibleNativeToolTransport
    implements AgentNativeToolTransport {
  final Map<String, List<Map<String, dynamic>>> _sessions = {};

  @override
  Future<AgentNativeModelResponse> complete(
      AgentNativeToolRequest request) async {
    final messages = _sessions.putIfAbsent(
      request.runId,
      () => [
        {'role': 'system', 'content': AgentPromptBuilder.systemPrompt},
        {'role': 'user', 'content': request.userPrompt},
      ],
    );
    for (final result in request.toolResults) {
      messages.add({
        'role': 'tool',
        'tool_call_id': result.toolCallId,
        'content': result.content,
      });
    }
    final Map<String, dynamic> message;
    try {
      message = await AIProviderFactory.chatWithTools(
        messages: messages,
        tools: _toolDefinitions,
        logTag: 'AgentNativeTools',
      );
    } on AIException catch (error) {
      if (error.message.contains('不支持原生工具调用') ||
          error.message.toLowerCase().contains('tool')) {
        _sessions.remove(request.runId);
        throw const AgentNativeToolUnsupportedException();
      }
      rethrow;
    }
    final rawCalls = message['tool_calls'];
    if (rawCalls is List && rawCalls.isNotEmpty) {
      messages.add(message);
      return AgentNativeModelResponse.toolCalls(
        rawCalls.whereType<Map>().map(_toToolCall).toList(),
      );
    }
    _sessions.remove(request.runId);
    return AgentNativeModelResponse.finalText(
        message['content'] as String? ?? '');
  }

  AgentNativeToolCall _toToolCall(Map raw) {
    final function = Map<String, dynamic>.from(raw['function'] as Map);
    final decoded = jsonDecode(function['arguments'] as String? ?? '{}');
    return AgentNativeToolCall(
      id: raw['id'] as String,
      name: function['name'] as String,
      arguments: decoded is Map ? Map<String, Object?>.from(decoded) : const {},
    );
  }

  static final List<Map<String, dynamic>> _toolDefinitions = [
    _tool('query_transactions', '查询当前账本交易', {'type': 'object'}),
    _tool('get_spending_summary', '汇总当前账本支出', {'type': 'object'}),
    _tool('get_budget_status', '读取当前账本预算', {'type': 'object'}),
    _tool('record_transaction_from_text', '记录当前用户明确给出的交易', {
      'type': 'object',
      'properties': {
        'sourceText': {'type': 'string'},
      },
      'required': ['sourceText'],
      'additionalProperties': false,
    }),
    _tool('save_explicit_memory', '保存用户明确要求记住的信息', {'type': 'object'}),
    _tool('forget_memory', '遗忘用户明确指定的记忆', {'type': 'object'}),
  ];

  static Map<String, dynamic> _tool(
    String name,
    String description,
    Map<String, dynamic> parameters,
  ) =>
      {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };
}

/// Stateful bridge between a provider's native tool-call protocol and the
/// pure-Dart AgentCore loop. State is keyed by one foreground run ID.
final class NativeToolAgentModel implements AgentModel {
  NativeToolAgentModel({
    required AgentNativeToolTransport transport,
    AgentPromptBuilder promptBuilder = const AgentPromptBuilder(),
    AgentModel? fallback,
  })  : _transport = transport,
        _promptBuilder = promptBuilder,
        _fallback = fallback;

  final AgentNativeToolTransport _transport;
  final AgentPromptBuilder _promptBuilder;
  final AgentModel? _fallback;
  final Set<String> _startedRuns = <String>{};
  final Set<String> _fallbackRuns = <String>{};

  @override
  Future<AgentTurn> nextTurn(AgentRequest request) async {
    if (_fallbackRuns.contains(request.scope.id)) {
      return _fallback!.nextTurn(request);
    }
    final isFirstTurn = _startedRuns.add(request.scope.id);
    final AgentNativeModelResponse response;
    try {
      response = await _transport.complete(
        AgentNativeToolRequest(
          runId: request.scope.id,
          userPrompt:
              isFirstTurn ? _promptBuilder.build(request) : request.text,
          toolResults: _toolResults(request.toolData),
        ),
      );
    } on AgentNativeToolUnsupportedException {
      if (_fallback == null) rethrow;
      _startedRuns.remove(request.scope.id);
      _fallbackRuns.add(request.scope.id);
      return _fallback.nextTurn(request);
    }
    return switch (response) {
      AgentNativeFinalTextResponse(:final text) => _finish(
          request.scope.id,
          AgentTurn.finalText(text.isEmpty ? '已完成。' : text),
        ),
      AgentNativeToolCallsResponse(:final calls) => AgentTurn.toolCalls(
          calls
              .map(
                (call) => AgentToolCall(
                  id: call.id,
                  name: call.name,
                  arguments: call.arguments,
                ),
              )
              .toList(),
        ),
    };
  }

  AgentTurn _finish(String runId, AgentTurn turn) {
    _startedRuns.remove(runId);
    _fallbackRuns.remove(runId);
    return turn;
  }

  List<AgentNativeToolResult> _toolResults(
    List<Map<String, Object?>> toolData,
  ) =>
      toolData
          .map(
            (item) => AgentNativeToolResult(
              toolCallId: item['id'] as String? ?? '',
              content: jsonEncode(item['data']),
            ),
          )
          .where((result) => result.toolCallId.isNotEmpty)
          .toList();
}
