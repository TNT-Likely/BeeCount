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
    Iterable<String>? availableToolNames,
    this.allowToolCalls = true,
  })  : toolData = UnmodifiableListView(
          toolData.map((data) => UnmodifiableMapView(Map.of(data))),
        ),
        context = UnmodifiableMapView(Map.of(context)),
        availableToolNames = availableToolNames == null
            ? null
            : UnmodifiableSetView(Set.of(availableToolNames));

  final String text;
  final AgentScope scope;
  final List<Map<String, Object?>> toolData;
  final Map<String, Object?> context;

  /// The native tool schemas visible during this run. `null` means every
  /// definition configured on the transport; an empty set means no tools.
  final Set<String>? availableToolNames;

  /// Whether the next model request may return native tool calls.
  ///
  /// AgentCore sets this to false for its finalization-only turn after a
  /// planning or tool budget is exhausted.
  final bool allowToolCalls;

  AgentRequest withToolData(List<Map<String, Object?>> data) => AgentRequest(
        text: text,
        scope: scope,
        toolData: data,
        context: context,
        availableToolNames: availableToolNames,
        allowToolCalls: allowToolCalls,
      );

  AgentRequest withoutToolCalls() => AgentRequest(
        text: text,
        scope: scope,
        toolData: toolData,
        context: context,
        availableToolNames: availableToolNames,
        allowToolCalls: false,
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

/// Optional lifecycle hook for a model that keeps resources per Agent run.
///
/// AgentCore calls this once whenever a run reaches any terminal path,
/// including cancellation and budget exhaustion. Stateless models do not need
/// to implement it.
abstract interface class AgentRunFinalizer {
  void disposeRun(String runId);
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

/// Host-owned semantic checks, separate from permission policy. Invalid calls
/// are never executed; their error is paired with the original native call so
/// the model can make a bounded correction without weakening authorization.
typedef AgentToolCallValidator = FutureOr<AgentToolValidationIssue?> Function(
  AgentRequest request,
  AgentToolCall call,
);

final class AgentToolValidationIssue {
  const AgentToolValidationIssue({required this.code, required this.message});

  final String code;
  final String message;
}

final class AgentRejectedCall {
  const AgentRejectedCall({required this.call, required this.issue});

  final AgentToolCall call;
  final AgentToolValidationIssue issue;
}

/// Explains why an [AgentCore.run] finished without hiding a usable final text.
enum AgentRunTerminationReason {
  /// The model returned a final text response.
  completed,

  /// The local tool-call budget was exhausted before a final text response.
  toolCallLimitReached,

  /// The planning-turn budget was exhausted before a final text response.
  modelTurnLimitReached,

  /// The caller cancelled the run.
  cancelled,
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
    List<AgentRejectedCall> rejectedCalls = const [],
    this.terminationReason = AgentRunTerminationReason.completed,
    this.wasCancelled = false,
  })  : executedCalls = UnmodifiableListView(List.of(executedCalls)),
        deniedCalls = UnmodifiableListView(List.of(deniedCalls)),
        rejectedCalls = UnmodifiableListView(List.of(rejectedCalls));

  final String text;
  final List<AgentToolCall> executedCalls;
  final List<AgentDeniedCall> deniedCalls;
  final List<AgentRejectedCall> rejectedCalls;
  final AgentRunTerminationReason terminationReason;
  final bool wasCancelled;
}
