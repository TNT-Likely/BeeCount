import 'contracts.dart';

final class AgentCore {
  const AgentCore({
    required this.model,
    required this.tools,
    required this.policy,
  });

  static const _maximumToolCalls = 4;

  final AgentModel model;
  final Map<String, AgentTool> tools;
  final AgentPolicy policy;

  Future<AgentRunResult> run(AgentRequest request) async {
    var nextRequest = request;
    final executedCalls = <AgentToolCall>[];
    final deniedCalls = <AgentDeniedCall>[];

    while (executedCalls.length < _maximumToolCalls) {
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
            final decision = policy.decide(nextRequest, call);
            final tool = tools[call.name];
            if (!decision.isAllowed || tool == null) {
              deniedCalls.add(
                AgentDeniedCall(
                  call: call,
                  reason: decision.reason ?? '未知工具：${call.name}',
                ),
              );
              continue;
            }
            if (executedCalls.length == _maximumToolCalls) break;
            final result = await tool.execute(call);
            executedCalls.add(call);
            data.add({'name': call.name, 'data': result});
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
}
