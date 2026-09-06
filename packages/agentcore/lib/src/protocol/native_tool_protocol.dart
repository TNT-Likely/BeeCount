import 'dart:async';
import 'dart:collection';

import '../contracts.dart';

final class AgentNativeToolDefinition {
  const AgentNativeToolDefinition({
    required this.name,
    required this.description,
    required Map<String, Object?> parameters,
  }) : parameters = parameters;

  final String name;
  final String description;
  final Map<String, Object?> parameters;

  Map<String, dynamic> toOpenAiSchema() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };
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
  }) : toolResults = UnmodifiableListView(List.of(toolResults));

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
      : calls = UnmodifiableListView(List.of(calls)),
        super._();

  final List<AgentNativeToolCall> calls;
}

abstract interface class AgentNativeToolTransport {
  Future<AgentNativeModelResponse> complete(
    AgentNativeToolRequest request, {
    AgentNativeEventSink? onEvent,
  });
}

/// Optional resource-release hook for a stateful native tool transport.
abstract interface class AgentNativeToolRunFinalizer {
  void disposeRun(String runId);
}

typedef AgentNativeToolStream = Stream<Map<String, dynamic>> Function({
  required List<Map<String, dynamic>> messages,
  required List<Map<String, dynamic>> tools,
  String? logTag,
});

typedef AgentNativeLogSink = void Function(
  String event,
  Map<String, Object?> data,
);

typedef AgentNativeUnsupportedErrorClassifier = bool Function(Object error);

final class AgentNativeToolUnsupportedException implements Exception {
  const AgentNativeToolUnsupportedException();
}

final class AgentNativeToolTimeoutException implements Exception {
  const AgentNativeToolTimeoutException();
}

/// Raised when a caller disposes a run while its native tool stream is active.
final class AgentNativeToolRunCancelledException implements Exception {
  const AgentNativeToolRunCancelledException();
}

final class AgentNativeProtocolException implements Exception {
  const AgentNativeProtocolException(this.message);

  final String message;

  @override
  String toString() => 'AgentNativeProtocolException($message)';
}
