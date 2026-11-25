import 'dart:async';
import 'dart:convert';

import '../contracts.dart';
import '../protocol/native_tool_protocol.dart';

/// Stateful bridge between a provider's native tool-call protocol and the
/// pure-Dart AgentCore loop. Prompts, schemas, and tool names are injected by
/// the host application.
final class NativeToolAgentModel implements AgentModel, AgentRunFinalizer {
  NativeToolAgentModel({
    required AgentNativeToolTransport transport,
    required this.promptBuilder,
    this.ledgerScopedToolNames = const {},
    this.toolTurnTimeout = const Duration(seconds: 45),
    this.maximumToolTurnDuration = const Duration(minutes: 2),
    this.emptyFinalText = '完成。',
  }) : _transport = transport;

  final AgentNativeToolTransport _transport;
  final String Function(AgentRequest request) promptBuilder;
  final Set<String> ledgerScopedToolNames;

  /// Maximum time until the first substantive delta, or between such deltas.
  final Duration toolTurnTimeout;
  final Duration maximumToolTurnDuration;
  final String emptyFinalText;
  final Set<String> _startedRuns = <String>{};
  final Map<String, void Function()> _cancelPendingTurn = {};

  @override
  void disposeRun(String runId) {
    _startedRuns.remove(runId);
    _cancelPendingTurn.remove(runId)?.call();
    if (_transport case AgentNativeToolRunFinalizer finalizer) {
      finalizer.disposeRun(runId);
    }
  }

  @override
  Future<AgentTurn> nextTurn(AgentRequest request) async {
    final runId = request.scope.id;
    final isFirstTurn = _startedRuns.add(runId);
    final AgentNativeModelResponse response;
    final interrupted = Completer<AgentNativeModelResponse>();
    void interrupt(Exception error) {
      if (!interrupted.isCompleted) {
        interrupted.completeError(error);
      }
    }

    final cancel =
        () => interrupt(const AgentNativeToolRunCancelledException());
    _cancelPendingTurn[runId] = cancel;
    void timedOut() => interrupt(const AgentNativeToolTimeoutException());
    var idleTimer = Timer(toolTurnTimeout, timedOut);
    final deadline = Timer(maximumToolTurnDuration, timedOut);
    void progress() {
      if (interrupted.isCompleted ||
          !identical(_cancelPendingTurn[runId], cancel)) {
        return;
      }
      idleTimer.cancel();
      idleTimer = Timer(toolTurnTimeout, timedOut);
    }

    try {
      final completion = Future.sync(() => _transport.complete(
            AgentNativeToolRequest(
              runId: runId,
              userPrompt: isFirstTurn ? promptBuilder(request) : request.text,
              toolResults: _toolResults(request.toolData),
              availableToolNames: request.availableToolNames,
              allowToolCalls: request.allowToolCalls,
              onProgress: progress,
            ),
            onEvent: request.nativeStreamSink,
          ));
      response = await Future.any([completion, interrupted.future]);
    } on Object {
      if (identical(_cancelPendingTurn[runId], cancel)) {
        disposeRun(runId);
      }
      rethrow;
    } finally {
      idleTimer.cancel();
      deadline.cancel();
      if (identical(_cancelPendingTurn[runId], cancel)) {
        _cancelPendingTurn.remove(runId);
      }
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
