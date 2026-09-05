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
  });

  final AgentModel model;
  final Map<String, AgentTool> tools;
  final AgentPolicy policy;
  final int maximumToolCalls;
  final int maximumModelTurns;
  final Set<String> singleUseToolNames;
  final String Function(String toolName) singleUseToolDenialReason;

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

    while (modelTurns < maximumModelTurns &&
        executedCalls.length < maximumToolCalls) {
      modelTurns += 1;
      final turn = await model.nextTurn(nextRequest);
      switch (turn) {
        case AgentFinalTextTurn(:final text):
          return AgentRunResult(
            text: text,
            executedCalls: executedCalls,
            deniedCalls: deniedCalls,
          );
        case AgentToolCallsTurn(:final calls):
          final data = <Map<String, Object?>>[];
          for (final call in calls) {
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
            final decision = await policy.decide(nextRequest, call);
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
            if (executedCalls.length >= maximumToolCalls) break;
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
