import 'dart:collection';

final class AgentScope {
  const AgentScope({required this.id});

  final String id;
}

final class AgentRequest {
  AgentRequest({
    required this.text,
    required this.scope,
    List<Map<String, Object?>> toolData = const [],
  }) : toolData = UnmodifiableListView(
          toolData.map((data) => UnmodifiableMapView(Map.of(data))),
        );

  final String text;
  final AgentScope scope;
  final List<Map<String, Object?>> toolData;

  AgentRequest withToolData(List<Map<String, Object?>> data) => AgentRequest(
        text: text,
        scope: scope,
        toolData: data,
      );
}

final class AgentToolCall {
  AgentToolCall({
    required this.name,
    Map<String, Object?> arguments = const {},
  }) : arguments = UnmodifiableMapView(Map.of(arguments));

  final String name;
  final Map<String, Object?> arguments;
}

sealed class AgentTurn {
  const AgentTurn._();

  const factory AgentTurn.finalText(String text) = AgentFinalTextTurn;
  factory AgentTurn.toolCalls(List<AgentToolCall> calls) = AgentToolCallsTurn;
}

final class AgentFinalTextTurn extends AgentTurn {
  const AgentFinalTextTurn(this.text) : super._();

  final String text;
}

final class AgentToolCallsTurn extends AgentTurn {
  AgentToolCallsTurn(List<AgentToolCall> calls)
      : calls = UnmodifiableListView(List.of(calls)),
        super._();

  final List<AgentToolCall> calls;
}

abstract interface class AgentModel {
  Future<AgentTurn> nextTurn(AgentRequest request);
}

abstract interface class AgentTool {
  String get name;

  Future<Map<String, Object?>> execute(AgentToolCall call);
}

abstract interface class AgentPolicy {
  AgentPolicyDecision decide(AgentRequest request, AgentToolCall call);
}

final class AgentPolicyDecision {
  const AgentPolicyDecision.allow() : reason = null;
  const AgentPolicyDecision.deny(this.reason);

  final String? reason;

  bool get isAllowed => reason == null;
}

final class AgentDeniedCall {
  const AgentDeniedCall({required this.call, required this.reason});

  final AgentToolCall call;
  final String reason;
}

final class AgentRunResult {
  AgentRunResult({
    required this.text,
    List<AgentToolCall> executedCalls = const [],
    List<AgentDeniedCall> deniedCalls = const [],
  })  : executedCalls = UnmodifiableListView(List.of(executedCalls)),
        deniedCalls = UnmodifiableListView(List.of(deniedCalls));

  final String text;
  final List<AgentToolCall> executedCalls;
  final List<AgentDeniedCall> deniedCalls;
}
