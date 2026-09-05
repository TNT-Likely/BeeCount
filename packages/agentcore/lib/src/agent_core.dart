import 'contracts.dart';

final class AgentCore {
  const AgentCore({
    required this.model,
    required this.tools,
    required this.policy,
  });

  static const _maximumToolCalls = 4;
  static const _maximumModelTurns = 4;

  final AgentModel model;
  final Map<String, AgentTool> tools;
  final AgentPolicy policy;

  Future<AgentRunResult> run(AgentRequest request) async {
    _validateToolRegistry();

    var nextRequest = request;
    final executedCalls = <AgentToolCall>[];
    final deniedCalls = <AgentDeniedCall>[];
    var hasRecordedTransaction = false;
    var modelTurns = 0;

    while (modelTurns < _maximumModelTurns &&
        executedCalls.length < _maximumToolCalls) {
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
            if (call.name == 'record_transaction_from_text' &&
                hasRecordedTransaction) {
              const reason = '同一条消息只能记账一次。';
              deniedCalls.add(AgentDeniedCall(call: call, reason: reason));
              data.add({
                'id': call.id,
                'name': call.name,
                'data': {'error': reason},
              });
              continue;
            }
            final decision = policy.decide(nextRequest, call);
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
            if (executedCalls.length == _maximumToolCalls) break;
            final result = await tool.execute(call);
            executedCalls.add(call);
            if (call.name == 'record_transaction_from_text') {
              hasRecordedTransaction = true;
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
