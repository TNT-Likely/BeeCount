import 'dart:convert';

import 'native_tool_protocol.dart';

/// Stateful OpenAI-compatible transport. The host injects its actual HTTP/SSE
/// stream and tool schemas; this package only aggregates protocol fragments.
final class OpenAiCompatibleNativeToolTransport
    implements AgentNativeToolTransport {
  OpenAiCompatibleNativeToolTransport({
    required AgentNativeToolStream toolStream,
    required List<AgentNativeToolDefinition> toolDefinitions,
    required this.systemPrompt,
    this.logSink,
    this.isUnsupportedError,
  })  : _toolStream = toolStream,
        _toolDefinitions = List.unmodifiable(toolDefinitions);

  final AgentNativeToolStream _toolStream;
  final List<AgentNativeToolDefinition> _toolDefinitions;
  final String systemPrompt;
  final AgentNativeLogSink? logSink;
  final AgentNativeUnsupportedErrorClassifier? isUnsupportedError;
  final Map<String, List<Map<String, dynamic>>> _sessions = {};

  @override
  Future<AgentNativeModelResponse> complete(
    AgentNativeToolRequest request, {
    AgentNativeEventSink? onEvent,
  }) async {
    logSink?.call('turnStarted', {
      'runId': request.runId,
      'toolResultCount': request.toolResults.length,
      'toolDefinitions': _toolDefinitions
          .map(
            (definition) => {
              'name': definition.name,
              'description': definition.description,
              'parameters': definition.parameters,
            },
          )
          .toList(),
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
        {'role': 'system', 'content': systemPrompt},
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
        tools: _toolDefinitions.map((item) => item.toOpenAiSchema()).toList(),
        logTag: 'AgentNativeTools',
        onEvent: onEvent,
      );
      if (response is AgentNativeFinalTextResponse) {
        logSink?.call('finalText', {
          'runId': request.runId,
          'textLength': response.text.length,
          'text': response.text,
        });
        _sessions.remove(request.runId);
      } else if (response is AgentNativeToolCallsResponse) {
        logSink?.call('toolCalls', {
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
      logSink?.call('turnFinished', {
        'runId': request.runId,
        'responseType': response.runtimeType.toString(),
      });
      return response;
    } on Object catch (error) {
      _sessions.remove(request.runId);
      logSink?.call('turnFailed', {
        'runId': request.runId,
        'error': error.toString(),
      });
      if (isUnsupportedError?.call(error) ?? false) {
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
    final rawArguments = function['arguments'] as String? ?? '{}';
    final decoded = jsonDecode(rawArguments);
    if (decoded is! Map) {
      throw const AgentNativeProtocolException('tool_arguments_must_be_object');
    }
    return AgentNativeToolCall(
      id: raw['id'] as String,
      name: function['name'] as String,
      arguments: Map<String, Object?>.from(decoded),
    );
  }
}

final class _StreamToolCall {
  String? id;
  String? name;
  final StringBuffer arguments = StringBuffer();

  Map<String, dynamic> toRaw() {
    if (id == null || name == null) {
      throw const AgentNativeProtocolException('incomplete_tool_call');
    }
    return {
      'id': id,
      'type': 'function',
      'function': {'name': name, 'arguments': arguments.toString()},
    };
  }
}
