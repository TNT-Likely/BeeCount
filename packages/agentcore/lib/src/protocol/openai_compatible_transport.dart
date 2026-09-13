import 'dart:async';
import 'dart:convert';

import 'native_tool_protocol.dart';

/// Stateful OpenAI-compatible transport. The host injects its actual HTTP/SSE
/// stream and tool schemas; this package only aggregates protocol fragments.
final class OpenAiCompatibleNativeToolTransport
    implements AgentNativeToolTransport, AgentNativeToolRunFinalizer {
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
  final Map<String, _ActiveNativeToolStream> _activeStreams = {};

  @override
  void disposeRun(String runId) {
    _sessions.remove(runId);
    final activeStream = _activeStreams.remove(runId);
    activeStream?.cancel();
  }

  @override
  Future<AgentNativeModelResponse> complete(
    AgentNativeToolRequest request, {
    AgentNativeEventSink? onEvent,
  }) async {
    logSink?.call('turnStarted', {
      'runId': request.runId,
      'toolResultCount': request.toolResults.length,
      'allowToolCalls': request.allowToolCalls,
      'toolDefinitions': _toolDefinitions
          .where((_) => request.allowToolCalls)
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
    if (!request.allowToolCalls) {
      // Some providers (notably DeepSeek-compatible gateways) may emit their
      // proprietary textual tool markup when the catalog is absent. Make the
      // finalization contract explicit in the message stream so that the
      // provider returns a user-facing answer instead of raw DSML/XML tags.
      messages.add({
        'role': 'user',
        'content':
            '请基于以上工具结果直接给出当前用户的最终答复。此回合不允许调用工具，不得输出任何工具调用标记（包括 <｜DSML｜...> 等内部格式）。只输出自然语言答复，不要复述工具参数。',
      });
    }
    try {
      var response = await _completeStream(
        runId: request.runId,
        messages: messages,
        tools: request.allowToolCalls
            ? _toolDefinitions.map((item) => item.toOpenAiSchema()).toList()
            : const [],
        emitTextDeltas: request.allowToolCalls,
        logTag: 'AgentNativeTools',
        onEvent: onEvent,
      );
      if (!request.allowToolCalls &&
          response is AgentNativeFinalTextResponse &&
          _containsToolMarkup(response.text)) {
        logSink?.call('invalidFinalText', {
          'runId': request.runId,
          'reason': 'tool_markup_in_final_text',
          'textLength': response.text.length,
        });
        // A few gateways ignore tool_choice=none after a tool turn and emit
        // their internal DSML syntax as ordinary content. Retry once with a
        // stronger instruction; never stream the malformed text to the UI.
        messages.add({
          'role': 'user',
          'content':
              '上一条输出违反协议。请不要调用工具，也不要输出任何 XML、DSML 或工具标记；只根据已有工具结果返回简短的自然语言答复。',
        });
        response = await _completeStream(
          runId: request.runId,
          messages: messages,
          tools: const [],
          emitTextDeltas: false,
          logTag: 'AgentNativeTools',
          onEvent: onEvent,
        );
        if (response is AgentNativeFinalTextResponse &&
            _containsToolMarkup(response.text)) {
          logSink?.call('invalidFinalText', {
            'runId': request.runId,
            'reason': 'tool_markup_in_final_text_after_retry',
            'textLength': response.text.length,
          });
          response = const AgentNativeFinalTextResponse('');
        }
      }
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
    required String runId,
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
    required bool emitTextDeltas,
    required String logTag,
    AgentNativeEventSink? onEvent,
  }) {
    final text = StringBuffer();
    final calls = <int, _StreamToolCall>{};
    final response = Completer<AgentNativeModelResponse>();
    StreamSubscription<Map<String, dynamic>>? subscription;

    AgentNativeModelResponse buildResponse() {
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

    void finish() {
      if (response.isCompleted) return;
      _activeStreams.remove(runId);
      final activeSubscription = subscription;
      if (activeSubscription != null) {
        unawaited(activeSubscription.cancel());
      }
      response.complete(buildResponse());
    }

    void fail(Object error, StackTrace stackTrace) {
      if (response.isCompleted) return;
      _activeStreams.remove(runId);
      response.completeError(error, stackTrace);
    }

    void consume(Map<String, dynamic> chunk) {
      final choices = chunk['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        return;
      }
      final choice = choices.first as Map;
      final delta = choice['delta'];
      if (delta is Map) {
        final content = delta['content'];
        if (content is String && content.isNotEmpty) {
          text.write(content);
          if (emitTextDeltas) onEvent?.call(AgentNativeTextDelta(content));
        }
        final rawCalls = delta['tool_calls'];
        if (rawCalls is List) {
          for (final raw in rawCalls.whereType<Map>()) {
            final index =
                raw['index'] is num ? (raw['index'] as num).toInt() : 0;
            final call = calls.putIfAbsent(index, _StreamToolCall.new);
            if (raw['id'] case final String id when id.isNotEmpty) {
              call.id = id;
            }
            final function = raw['function'];
            if (function is Map) {
              if (function['name'] case final String name
                  when name.isNotEmpty) {
                call.name = name;
              }
              if (function['arguments'] is String) {
                call.arguments.write(function['arguments'] as String);
              }
            }
          }
        }
      }
      // Some OpenAI-compatible providers send a terminal choice but keep the
      // HTTP stream open (or omit [DONE]). The response is complete once the
      // non-null finish_reason arrives, so do not turn an already-rendered
      // response into a false timeout while waiting for connection teardown.
      final finishReason = choice['finish_reason'];
      if (finishReason is String && finishReason.isNotEmpty) finish();
    }

    subscription = _toolStream(
      messages: messages,
      tools: tools,
      logTag: logTag,
    ).listen(
      (chunk) {
        try {
          consume(chunk);
        } on Object catch (error, stackTrace) {
          fail(error, stackTrace);
        }
      },
      onError: (Object error, StackTrace stackTrace) => fail(error, stackTrace),
      onDone: finish,
      cancelOnError: true,
    );
    if (response.isCompleted) {
      unawaited(subscription.cancel());
    } else {
      _activeStreams[runId] = _ActiveNativeToolStream(
        subscription: subscription,
        response: response,
      );
    }
    return response.future;
  }

  bool _containsToolMarkup(String text) =>
      text.contains('<｜DSML｜tool_calls>') ||
      text.contains('<｜DSML｜invoke') ||
      text.contains('<|DSML|tool_calls>') ||
      text.contains('<|DSML|invoke');

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

final class _ActiveNativeToolStream {
  const _ActiveNativeToolStream({
    required this.subscription,
    required this.response,
  });

  final StreamSubscription<Map<String, dynamic>> subscription;
  final Completer<AgentNativeModelResponse> response;

  void cancel() {
    unawaited(subscription.cancel());
    if (!response.isCompleted) {
      response.completeError(const AgentNativeToolRunCancelledException());
    }
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
