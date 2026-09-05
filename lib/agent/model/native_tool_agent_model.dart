import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:agentcore/agentcore.dart';

import '../../ai/providers/ai_provider_factory.dart';
import '../../services/system/logger_service.dart';
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

sealed class AgentNativeStreamEvent {
  const AgentNativeStreamEvent();
}

final class AgentNativeTextDelta extends AgentNativeStreamEvent {
  const AgentNativeTextDelta(this.text);

  final String text;
}

typedef AgentNativeEventSink = void Function(AgentNativeStreamEvent event);

/// Carries a per-request stream sink without sharing mutable state between
/// foreground Agent runs.
extension AgentRequestNativeStreaming on AgentRequest {
  static const _streamSinkKey = '_agent_native_stream_sink';

  AgentRequest withStreamingTextDeltas(AgentNativeEventSink sink) =>
      AgentRequest(
        text: text,
        scope: scope,
        toolData: toolData,
        context: {...context, _streamSinkKey: sink},
      );

  AgentNativeEventSink? get nativeStreamSink =>
      context[_streamSinkKey] as AgentNativeEventSink?;
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
  Future<AgentNativeModelResponse> complete(
    AgentNativeToolRequest request, {
    AgentNativeEventSink? onEvent,
  });
}

typedef AgentNativeToolStream = Stream<Map<String, dynamic>> Function({
  required List<Map<String, dynamic>> messages,
  required List<Map<String, dynamic>> tools,
  String? logTag,
});

final class AgentNativeToolUnsupportedException implements Exception {
  const AgentNativeToolUnsupportedException();
}

final class AgentNativeToolTimeoutException implements Exception {
  const AgentNativeToolTimeoutException();
}

/// Stateful OpenAI-compatible transport. It emits actual `tools` in the HTTP
/// payload and appends assistant tool_calls plus role:tool results verbatim.
final class OpenAiCompatibleNativeToolTransport
    implements AgentNativeToolTransport {
  OpenAiCompatibleNativeToolTransport({AgentNativeToolStream? toolStream})
      : _toolStream = toolStream ?? AIProviderFactory.chatWithToolsStream;

  final AgentNativeToolStream _toolStream;
  final Map<String, List<Map<String, dynamic>>> _sessions = {};

  @override
  Future<AgentNativeModelResponse> complete(
    AgentNativeToolRequest request, {
    AgentNativeEventSink? onEvent,
  }) async {
    logger.debug('AgentNativeTools', '模型回合开始', {
      'runId': request.runId,
      'toolResultCount': request.toolResults.length,
      if (request.toolResults.isNotEmpty)
        'toolResults': request.toolResults
            .map(
              (result) => {
                'toolCallId': result.toolCallId,
                'content': result.content,
              },
            )
            .toList(),
    });
    final messages = _sessions.putIfAbsent(
      request.runId,
      () => [
        {'role': 'system', 'content': AgentPromptBuilder.nativeSystemPrompt},
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
    try {
      final response = await _completeStream(
        messages: messages,
        tools: _toolDefinitions,
        logTag: 'AgentNativeTools',
        onEvent: onEvent,
      );
      if (response is AgentNativeFinalTextResponse) {
        logger.debug('AgentNativeTools', '模型返回最终文本', {
          'runId': request.runId,
          'textLength': response.text.length,
          'text': response.text,
        });
        _sessions.remove(request.runId);
      } else if (response is AgentNativeToolCallsResponse) {
        logger.debug('AgentNativeTools', '模型请求工具', {
          'runId': request.runId,
          'toolCount': response.calls.length,
          'toolCalls': response.calls
              .map(
                (call) => {
                  'id': call.id,
                  'name': call.name,
                  'arguments': call.arguments,
                },
              )
              .toList(),
        });
      }
      logger.debug('AgentNativeTools', '模型回合结束', {
        'runId': request.runId,
        'responseType': response.runtimeType.toString(),
      });
      return response;
    } on AIException catch (error) {
      _sessions.remove(request.runId);
      logger.warning('AgentNativeTools', '模型回合失败', {
        'runId': request.runId,
        'reason': error.message,
      });
      if (error.message.contains('不支持原生工具调用') ||
          error.message.toLowerCase().contains('tool')) {
        throw const AgentNativeToolUnsupportedException();
      }
      rethrow;
    }
  }

  Future<AgentNativeModelResponse> _completeStream({
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
    required String logTag,
    AgentNativeEventSink? onEvent,
  }) async {
    final text = StringBuffer();
    final calls = <int, _StreamToolCall>{};
    await for (final chunk in _toolStream(
      messages: messages,
      tools: tools,
      logTag: logTag,
    )) {
      final choices = chunk['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        continue;
      }
      final delta = (choices.first as Map)['delta'];
      if (delta is! Map) continue;
      final content = delta['content'];
      if (content is String && content.isNotEmpty) {
        text.write(content);
        onEvent?.call(AgentNativeTextDelta(content));
      }
      final rawCalls = delta['tool_calls'];
      if (rawCalls is! List) continue;
      for (final raw in rawCalls.whereType<Map>()) {
        final index = raw['index'] is num ? (raw['index'] as num).toInt() : 0;
        final call = calls.putIfAbsent(index, _StreamToolCall.new);
        if (raw['id'] case final String id when id.isNotEmpty) {
          call.id = id;
        }
        final function = raw['function'];
        if (function is Map) {
          if (function['name'] case final String name when name.isNotEmpty) {
            call.name = name;
          }
          if (function['arguments'] is String) {
            call.arguments.write(function['arguments'] as String);
          }
        }
      }
    }
    if (calls.isNotEmpty) {
      final toolCalls = calls.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key));
      final rawCalls = toolCalls.map((entry) => entry.value.toRaw()).toList();
      // OpenAI-compatible tool continuation requires an assistant message
      // whose `content` is explicitly null before role:tool results. Some
      // gateways otherwise lose the tool-call turn and repeat it.
      messages.add({
        'role': 'assistant',
        'content': null,
        'tool_calls': rawCalls,
      });
      return AgentNativeModelResponse.toolCalls(
        rawCalls.map(_toToolCall).toList(),
      );
    }
    return AgentNativeModelResponse.finalText(text.toString());
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
    _tool('query_transactions', '查询当前账本交易', _rangeParameters),
    _tool('get_spending_summary', '汇总当前账本支出', _rangeParameters),
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

  static const Map<String, dynamic> _rangeParameters = {
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
}

final class _StreamToolCall {
  String? id;
  String? name;
  final StringBuffer arguments = StringBuffer();

  Map<String, dynamic> toRaw() {
    if (id == null || name == null) {
      throw AIException('服务商返回了不完整的工具调用');
    }
    return {
      'id': id,
      'type': 'function',
      'function': {'name': name, 'arguments': arguments.toString()},
    };
  }
}

/// Stateful bridge between a provider's native tool-call protocol and the
/// pure-Dart AgentCore loop. State is keyed by one foreground run ID.
final class NativeToolAgentModel implements AgentModel {
  NativeToolAgentModel({
    required AgentNativeToolTransport transport,
    AgentPromptBuilder promptBuilder = const AgentPromptBuilder(),
    Duration toolTurnTimeout = const Duration(seconds: 45),
  })  : _transport = transport,
        _promptBuilder = promptBuilder,
        _toolTurnTimeout = toolTurnTimeout;

  final AgentNativeToolTransport _transport;
  final AgentPromptBuilder _promptBuilder;
  final Duration _toolTurnTimeout;
  final Set<String> _startedRuns = <String>{};

  // Ledger-scoped tools always execute against the ledger in AgentScope. A
  // provider may still echo a hallucinated ledgerId argument even though it is
  // not part of the tool schema; drop it before policy evaluation so the
  // current local scope remains authoritative.
  static const Set<String> _ledgerScopedTools = <String>{
    'query_transactions',
    'get_spending_summary',
    'get_budget_status',
  };

  @override
  Future<AgentTurn> nextTurn(AgentRequest request) async {
    final isFirstTurn = _startedRuns.add(request.scope.id);
    final AgentNativeModelResponse response;
    try {
      response = await _transport
          .complete(
            AgentNativeToolRequest(
              runId: request.scope.id,
              userPrompt: isFirstTurn
                  ? _promptBuilder.buildNative(request)
                  : request.text,
              toolResults: _toolResults(request.toolData),
            ),
            onEvent: request.nativeStreamSink,
          )
          .timeout(
            _toolTurnTimeout,
            onTimeout: () => throw const AgentNativeToolTimeoutException(),
          );
    } on AgentNativeToolUnsupportedException {
      _startedRuns.remove(request.scope.id);
      rethrow;
    } on AgentNativeToolTimeoutException {
      _startedRuns.remove(request.scope.id);
      rethrow;
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
                  arguments: _argumentsForScope(call),
                ),
              )
              .toList(),
        ),
    };
  }

  Map<String, Object?> _argumentsForScope(AgentNativeToolCall call) {
    if (!_ledgerScopedTools.contains(call.name) ||
        !call.arguments.containsKey('ledgerId')) {
      return call.arguments;
    }
    final arguments = Map<String, Object?>.of(call.arguments)
      ..remove('ledgerId');
    return arguments;
  }

  AgentTurn _finish(String runId, AgentTurn turn) {
    _startedRuns.remove(runId);
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
