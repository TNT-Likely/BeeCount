import 'dart:async';
import 'dart:collection';

final class AgentScope {
  const AgentScope({
    required this.id,
    this.ledgerId,
    this.isForeground = true,
    this.allowsExplicitMemory = false,
  });

  final String id;
  final int? ledgerId;
  final bool isForeground;
  final bool allowsExplicitMemory;
}

final class AgentRequest {
  AgentRequest({
    required this.text,
    required this.scope,
    List<Map<String, Object?>> toolData = const [],
    Map<String, Object?> context = const {},
  })  : toolData = UnmodifiableListView(
          toolData.map((data) => UnmodifiableMapView(Map.of(data))),
        ),
        context = UnmodifiableMapView(Map.of(context));

  final String text;
  final AgentScope scope;
  final List<Map<String, Object?>> toolData;
  final Map<String, Object?> context;

  AgentRequest withToolData(List<Map<String, Object?>> data) => AgentRequest(
        text: text,
        scope: scope,
        toolData: data,
        context: context,
      );
}

final class AgentToolCall {
  AgentToolCall({
    required this.name,
    this.id = '',
    Map<String, Object?> arguments = const {},
  }) : arguments = UnmodifiableMapView(Map.of(arguments));

  final String id;
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
  FutureOr<AgentPolicyDecision> decide(
    AgentRequest request,
    AgentToolCall call,
  );
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

/// Cooperatively cancels an in-flight foreground Agent run.
///
/// It deliberately does not try to interrupt a tool midway through a local
/// mutation. Instead, AgentCore observes it before every next action and races
/// it against a waiting model or policy decision, where cancellation is safe.
final class AgentCancellationToken {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

final class AgentRunResult {
  AgentRunResult({
    required this.text,
    List<AgentToolCall> executedCalls = const [],
    List<AgentDeniedCall> deniedCalls = const [],
    this.wasCancelled = false,
  })  : executedCalls = UnmodifiableListView(List.of(executedCalls)),
        deniedCalls = UnmodifiableListView(List.of(deniedCalls));

  final String text;
  final List<AgentToolCall> executedCalls;
  final List<AgentDeniedCall> deniedCalls;
  final bool wasCancelled;
}
