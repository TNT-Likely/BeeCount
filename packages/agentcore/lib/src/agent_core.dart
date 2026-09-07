import 'dart:convert';

import 'contracts.dart';

final class AgentCore {
  const AgentCore({
    required this.model,
    required this.tools,
    required this.policy,
    this.maximumToolCalls = 4,
    this.maximumModelTurns = 4,
    this.singleUseToolNames = const {},
    this.singleUseToolDenialReason = _defaultSingleUseToolDenialReason,
    this.deduplicatedToolNames = const {},
    this.cancellationToken,
  });

  final AgentModel model;
  final Map<String, AgentTool> tools;
  final AgentPolicy policy;
  final int maximumToolCalls;
  final int maximumModelTurns;
  final Set<String> singleUseToolNames;
  final String Function(String toolName) singleUseToolDenialReason;

  /// Read-only tools that should not be executed twice with identical input
  /// during one run. The cached result is sent back to the model instead.
  ///
  /// This is opt-in because some tools intentionally poll changing state.
  final Set<String> deduplicatedToolNames;
  final AgentCancellationToken? cancellationToken;

  Future<AgentRunResult> run(AgentRequest request) async {
    _validateToolRegistry();
    if (maximumToolCalls <= 0 || maximumModelTurns <= 0) {
      throw ArgumentError('AgentCore 执行上限必须大于 0。');
    }

    var nextRequest = request;
    final executedCalls = <AgentToolCall>[];
    final deniedCalls = <AgentDeniedCall>[];
    final executedSingleUseTools = <String>{};
    final cachedToolResults = <String, Map<String, Object?>>{};
    var modelTurns = 0;
    var finalizationPending = false;
    var toolCallLimitReached = false;

    try {
      while (modelTurns < maximumModelTurns || finalizationPending) {
        if (_isCancelled) {
          return _cancelledResult(executedCalls, deniedCalls);
        }
        final isFinalizationTurn = finalizationPending;
        finalizationPending = false;
        if (!isFinalizationTurn) modelTurns += 1;
        final turn = await _awaitUnlessCancelled(
          model.nextTurn(
            isFinalizationTurn ? nextRequest.withoutToolCalls() : nextRequest,
          ),
        );
        if (turn == null || _isCancelled) {
          return _cancelledResult(executedCalls, deniedCalls);
        }
        switch (turn) {
          case AgentFinalTextTurn(:final text):
            return AgentRunResult(
              text: text,
              executedCalls: executedCalls,
              deniedCalls: deniedCalls,
              terminationReason: AgentRunTerminationReason.completed,
            );
          case AgentToolCallsTurn(:final calls):
            if (isFinalizationTurn) {
              // Defensive guard for custom AgentModel implementations. Native
              // transports receive an empty tool list during finalization.
              return AgentRunResult(
                text: '',
                executedCalls: executedCalls,
                deniedCalls: deniedCalls,
                terminationReason: toolCallLimitReached
                    ? AgentRunTerminationReason.toolCallLimitReached
                    : AgentRunTerminationReason.modelTurnLimitReached,
              );
            }
            final data = <Map<String, Object?>>[];
            var executedNewTool = false;
            var reusedCachedTool = false;
            for (final call in calls) {
              if (_isCancelled) {
                return _cancelledResult(executedCalls, deniedCalls);
              }
              if (executedCalls.length >= maximumToolCalls) {
                // Native providers require one tool result for every call in an
                // assistant tool-call batch. Report the budget denial instead
                // of omitting the call and leaving the session invalid.
                const reason = 'tool_call_limit_reached';
                toolCallLimitReached = true;
                deniedCalls.add(AgentDeniedCall(call: call, reason: reason));
                data.add({
                  'id': call.id,
                  'name': call.name,
                  'data': {'error': reason},
                });
                continue;
              }
              if (singleUseToolNames.contains(call.name) &&
                  executedSingleUseTools.contains(call.name)) {
                final reason = singleUseToolDenialReason(call.name);
                deniedCalls.add(AgentDeniedCall(call: call, reason: reason));
                data.add({
                  'id': call.id,
                  'name': call.name,
                  'data': {'error': reason},
                });
                continue;
              }
              final duplicateKey = deduplicatedToolNames.contains(call.name)
                  ? _toolCallKey(call)
                  : null;
              final cachedResult =
                  duplicateKey == null ? null : cachedToolResults[duplicateKey];
              if (cachedResult != null) {
                // Preserve the call/result pairing expected by native
                // providers, but do not spend another local action on an
                // identical read. A duplicate-only turn is finalized below.
                data.add({
                  'id': call.id,
                  'name': call.name,
                  'data': cachedResult,
                });
                reusedCachedTool = true;
                continue;
              }
              final decision = await _awaitUnlessCancelled(
                Future<AgentPolicyDecision>.value(
                    policy.decide(nextRequest, call)),
              );
              if (decision == null || _isCancelled) {
                return _cancelledResult(executedCalls, deniedCalls);
              }
              final tool = tools[call.name];
              if (!decision.isAllowed || tool == null) {
                final reason = decision.reason ?? '未知工具：${call.name}';
                deniedCalls.add(
                  AgentDeniedCall(call: call, reason: reason),
                );
                data.add({
                  'id': call.id,
                  'name': call.name,
                  'data': {'error': reason},
                });
                continue;
              }
              if (_isCancelled) {
                return _cancelledResult(executedCalls, deniedCalls);
              }
              final result = await tool.execute(call);
              executedCalls.add(call);
              executedNewTool = true;
              if (singleUseToolNames.contains(call.name)) {
                executedSingleUseTools.add(call.name);
              }
              if (duplicateKey != null) {
                cachedToolResults[duplicateKey] = Map.of(result);
              }
              data.add({'id': call.id, 'name': call.name, 'data': result});
            }
            nextRequest = nextRequest.withToolData(data);
            if (executedCalls.length >= maximumToolCalls) {
              toolCallLimitReached = true;
            }
            if (toolCallLimitReached || modelTurns >= maximumModelTurns) {
              // Always reserve one model turn to turn the completed tool data
              // into a user-facing response. Tool calls are disabled for that
              // turn so a provider cannot consume another local action.
              finalizationPending = true;
            }
            if (!executedNewTool && reusedCachedTool) {
              // A model that only repeats already answered reads is stuck;
              // give it one bounded text-only turn instead of another loop.
              finalizationPending = true;
            }
        }
      }

      return AgentRunResult(
        text: '',
        executedCalls: executedCalls,
        deniedCalls: deniedCalls,
        terminationReason: toolCallLimitReached
            ? AgentRunTerminationReason.toolCallLimitReached
            : AgentRunTerminationReason.modelTurnLimitReached,
      );
    } finally {
      if (model case AgentRunFinalizer finalizer) {
        finalizer.disposeRun(request.scope.id);
      }
    }
  }

  bool get _isCancelled => cancellationToken?.isCancelled ?? false;

  Future<T?> _awaitUnlessCancelled<T>(Future<T> future) {
    final token = cancellationToken;
    if (token == null) return future;
    return Future.any<T?>([
      future,
      token.whenCancelled.then<T?>((_) => null),
    ]);
  }

  AgentRunResult _cancelledResult(
    List<AgentToolCall> executedCalls,
    List<AgentDeniedCall> deniedCalls,
  ) =>
      AgentRunResult(
        text: '',
        executedCalls: executedCalls,
        deniedCalls: deniedCalls,
        terminationReason: AgentRunTerminationReason.cancelled,
        wasCancelled: true,
      );

  void _validateToolRegistry() {
    for (final entry in tools.entries) {
      if (entry.key != entry.value.name) {
        throw ArgumentError.value(
          entry.key,
          'tools',
          '工具注册键必须与 AgentTool.name 一致。',
        );
      }
    }
  }
}

String _toolCallKey(AgentToolCall call) =>
    '${call.name}:${jsonEncode(_canonicalJson(call.arguments))}';

Object? _canonicalJson(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort(
          (left, right) => left.key.toString().compareTo(right.key.toString()));
    return <String, Object?>{
      for (final entry in entries)
        entry.key.toString(): _canonicalJson(entry.value),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalJson).toList();
  }
  return value;
}

String _defaultSingleUseToolDenialReason(String toolName) =>
    'tool_can_only_run_once:$toolName';
