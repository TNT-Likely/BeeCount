import 'dart:async';

import 'package:agentcore/agentcore.dart';

import 'agent_tool_permission.dart';

enum AgentToolAuthorizationChoice { deny, allowOnce, alwaysAllow }

final class AgentToolAuthorizationRequest {
  const AgentToolAuthorizationRequest({
    required this.authorizationId,
    required this.runId,
    required this.ledgerId,
    required this.toolName,
    required this.arguments,
  });

  final String authorizationId;
  final String runId;
  final int? ledgerId;
  final String toolName;
  final Map<String, Object?> arguments;
}

abstract interface class AgentToolAuthorizationRequester {
  Future<AgentToolAuthorizationChoice> request(
    AgentToolAuthorizationRequest request,
  );

  void denyPending();
}

final class AgentToolAuthorizationBroker
    implements AgentToolAuthorizationRequester {
  AgentToolAuthorizationBroker({required this.onRequest});

  static const Duration _authorizationTimeout = Duration(minutes: 2);

  final void Function(AgentToolAuthorizationRequest request) onRequest;
  final Map<String, Completer<AgentToolAuthorizationChoice>> _pending = {};

  @override
  Future<AgentToolAuthorizationChoice> request(
    AgentToolAuthorizationRequest request,
  ) {
    if (_pending.containsKey(request.authorizationId)) {
      throw StateError('Authorization is already pending.');
    }

    final completer = Completer<AgentToolAuthorizationChoice>();
    _pending[request.authorizationId] = completer;
    onRequest(request);
    return completer.future
        .timeout(
          _authorizationTimeout,
          onTimeout: () => AgentToolAuthorizationChoice.deny,
        )
        .whenComplete(() => _pending.remove(request.authorizationId));
  }

  bool resolve(String authorizationId, AgentToolAuthorizationChoice choice) {
    final completer = _pending.remove(authorizationId);
    if (completer == null) return false;
    completer.complete(choice);
    return true;
  }

  @override
  void denyPending() {
    final pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final completer in pending) {
      completer.complete(AgentToolAuthorizationChoice.deny);
    }
  }
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
      AgentToolAuthorizationRequest(
        authorizationId: call.id,
        runId: request.scope.id,
        ledgerId: request.scope.ledgerId,
        toolName: call.name,
        arguments: call.arguments,
      ),
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
      onPersistenceError?.call(error, stackTrace);
    }
  }
}
