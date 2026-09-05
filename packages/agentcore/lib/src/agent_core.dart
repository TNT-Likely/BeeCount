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
    this.cancellationToken,
  });

  final AgentModel model;
  final Map<String, AgentTool> tools;
  final AgentPolicy policy;
  final int maximumToolCalls;
  final int maximumModelTurns;
  final Set<String> singleUseToolNames;
  final String Function(String toolName) singleUseToolDenialReason;
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
    var modelTurns = 0;

    while (modelTurns < maximumModelTurns) {
      if (_isCancelled) {
        return _cancelledResult(executedCalls, deniedCalls);
      }
      modelTurns += 1;
      final turn = await _awaitUnlessCancelled(model.nextTurn(nextRequest));
      if (turn == null || _isCancelled) {
        return _cancelledResult(executedCalls, deniedCalls);
      }
      switch (turn) {
        case AgentFinalTextTurn(:final text):
          return AgentRunResult(
            text: text,
            executedCalls: executedCalls,
            deniedCalls: deniedCalls,
          );
        case AgentToolCallsTurn(:final calls):
          // A tool batch can consume the final call in the budget. Still give
          // the model one more turn so it can turn those results into a user
          // response. A later tool request after that budget is exhausted is
          // bounded below instead of running another local action.
          if (executedCalls.length >= maximumToolCalls) {
            return AgentRunResult(
              text: '',
              executedCalls: executedCalls,
              deniedCalls: deniedCalls,
            );
          }
          final data = <Map<String, Object?>>[];
          for (final call in calls) {
            if (_isCancelled) {
              return _cancelledResult(executedCalls, deniedCalls);
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
            if (executedCalls.length >= maximumToolCalls) {
              // Preserve results already collected in this batch. They still
              // need to be returned to the model, which may now finish with a
              // final response; a later tool request is bounded above.
              break;
            }
            if (_isCancelled) {
              return _cancelledResult(executedCalls, deniedCalls);
            }
            final result = await tool.execute(call);
            executedCalls.add(call);
            if (singleUseToolNames.contains(call.name)) {
              executedSingleUseTools.add(call.name);
            }
            data.add({'id': call.id, 'name': call.name, 'data': result});
          }
          nextRequest = nextRequest.withToolData(data);
      }
    }

    return AgentRunResult(
      text: '',
      executedCalls: executedCalls,
      deniedCalls: deniedCalls,
    );
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

String _defaultSingleUseToolDenialReason(String toolName) =>
    'tool_can_only_run_once:$toolName';
