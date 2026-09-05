import 'dart:convert';

import '../contracts.dart';
import '../protocol/native_tool_protocol.dart';

/// Stateful bridge between a provider's native tool-call protocol and the
/// pure-Dart AgentCore loop. Prompts, schemas, and tool names are injected by
/// the host application.
final class NativeToolAgentModel implements AgentModel {
  NativeToolAgentModel({
    required AgentNativeToolTransport transport,
    required this.promptBuilder,
    this.ledgerScopedToolNames = const {},
    this.toolTurnTimeout = const Duration(seconds: 45),
    this.emptyFinalText = '完成。',
  }) : _transport = transport;

  final AgentNativeToolTransport _transport;
  final String Function(AgentRequest request) promptBuilder;
  final Set<String> ledgerScopedToolNames;
  final Duration toolTurnTimeout;
  final String emptyFinalText;
  final Set<String> _startedRuns = <String>{};

  @override
  Future<AgentTurn> nextTurn(AgentRequest request) async {
    final isFirstTurn = _startedRuns.add(request.scope.id);
    final AgentNativeModelResponse response;
    try {
      response = await _transport
          .complete(
            AgentNativeToolRequest(
              runId: request.scope.id,
              userPrompt: isFirstTurn ? promptBuilder(request) : request.text,
              toolResults: _toolResults(request.toolData),
            ),
            onEvent: request.nativeStreamSink,
          )
          .timeout(
            toolTurnTimeout,
            onTimeout: () => throw const AgentNativeToolTimeoutException(),
          );
    } on AgentNativeToolUnsupportedException {
      _startedRuns.remove(request.scope.id);
      rethrow;
    } on AgentNativeToolTimeoutException {
      _startedRuns.remove(request.scope.id);
      rethrow;
    } on Object {
      _startedRuns.remove(request.scope.id);
      rethrow;
    }
    return switch (response) {
      AgentNativeFinalTextResponse(:final text) => _finish(
          request.scope.id,
          AgentTurn.finalText(text.isEmpty ? emptyFinalText : text),
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
    if (!ledgerScopedToolNames.contains(call.name) ||
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
