import 'dart:async';
import 'dart:collection';

import 'package:agentcore/agentcore.dart';

import 'agent_tool_permission.dart';

enum AgentToolAuthorizationChoice { deny, allowOnce, alwaysAllow }

final class AgentToolAuthorizationRequest {
  AgentToolAuthorizationRequest({
    required this.authorizationId,
    required this.runId,
    required this.ledgerId,
    required this.toolName,
    required Map<String, Object?> arguments,
  }) : arguments = UnmodifiableMapView(Map.of(arguments));

  final String authorizationId;
  final String runId;
  final int? ledgerId;
  final String toolName;
  final Map<String, Object?> arguments;
}

abstract interface class AgentToolAuthorizationRequester {
  Future<AgentToolAuthorizationChoice> request({
    required String runId,
    required int? ledgerId,
    required String toolName,
    required Map<String, Object?> arguments,
  });

  void denyPending();
}

final class AgentToolAuthorizationBroker
    implements AgentToolAuthorizationRequester {
  AgentToolAuthorizationBroker({required this.onRequest});

  static const Duration _authorizationTimeout = Duration(minutes: 2);
  static int _nextAuthorizationNonce = 0;

  final void Function(AgentToolAuthorizationRequest request) onRequest;
  final Map<String, _PendingAuthorization> _pending = {};

  @override
  Future<AgentToolAuthorizationChoice> request({
    required String runId,
    required int? ledgerId,
    required String toolName,
    required Map<String, Object?> arguments,
  }) {
    final pending = _PendingAuthorization(_nextAuthorizationId());
    _pending[pending.authorizationId] = pending;
    final request = AgentToolAuthorizationRequest(
      authorizationId: pending.authorizationId,
      runId: runId,
      ledgerId: ledgerId,
      toolName: toolName,
      arguments: arguments,
    );
    try {
      onRequest(request);
    } on Object {
      _removePending(pending);
      return Future.value(AgentToolAuthorizationChoice.deny);
    }
    return pending.completer.future
        .timeout(
          _authorizationTimeout,
          onTimeout: () => AgentToolAuthorizationChoice.deny,
        )
        .whenComplete(() => _removePending(pending));
  }

  bool resolve(String authorizationId, AgentToolAuthorizationChoice choice) {
    final pending = _pending.remove(authorizationId);
    if (pending == null) return false;
    pending.completer.complete(choice);
    return true;
  }

  @override
  void denyPending() {
    final pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final authorization in pending) {
      authorization.completer.complete(AgentToolAuthorizationChoice.deny);
    }
  }

  String _nextAuthorizationId() => 'authorization-${++_nextAuthorizationNonce}';

  void _removePending(_PendingAuthorization pending) {
    if (identical(_pending[pending.authorizationId], pending)) {
      _pending.remove(pending.authorizationId);
    }
  }
}

final class _PendingAuthorization {
  _PendingAuthorization(this.authorizationId);

  final String authorizationId;
  final Completer<AgentToolAuthorizationChoice> completer = Completer();
}

final class AgentAuthorizationPolicy implements AgentPolicy {
  AgentAuthorizationPolicy({
    required this.hardPolicy,
    required this.permissions,
    required this.requester,
    this.onPersistenceError,
  });

  final AgentPolicy hardPolicy;
  final AgentToolPermissionStore permissions;
  final AgentToolAuthorizationRequester requester;
  final void Function(Object error, StackTrace stackTrace)? onPersistenceError;

  @override
  Future<AgentPolicyDecision> decide(
    AgentRequest request,
    AgentToolCall call,
  ) async {
    final hardDecision = await hardPolicy.decide(request, call);
    if (!hardDecision.isAllowed) return hardDecision;

    if (AgentToolPermissionCatalog.find(call.name) == null) {
      return const AgentPolicyDecision.deny('工具未获授权。');
    }

    final permission = await permissions.permissionFor(call.name);
    if (permission == null) {
      return const AgentPolicyDecision.deny('工具未获授权。');
    }
    if (permission == AgentToolPermission.alwaysAllow) {
      return const AgentPolicyDecision.allow();
    }

    final choice = await requester.request(
      runId: request.scope.id,
      ledgerId: request.scope.ledgerId,
      toolName: call.name,
      arguments: call.arguments,
    );
    switch (choice) {
      case AgentToolAuthorizationChoice.deny:
        return const AgentPolicyDecision.deny('用户未授权此操作。');
      case AgentToolAuthorizationChoice.allowOnce:
        return const AgentPolicyDecision.allow();
      case AgentToolAuthorizationChoice.alwaysAllow:
        await _persistAlwaysAllow(call.name);
        return const AgentPolicyDecision.allow();
    }
  }

  Future<void> _persistAlwaysAllow(String toolName) async {
    try {
      await permissions.setPermission(
          toolName, AgentToolPermission.alwaysAllow);
    } on Object catch (error, stackTrace) {
      try {
        onPersistenceError?.call(error, stackTrace);
      } on Object {
        // Observability cannot change the current authorization result.
      }
    }
  }
}
