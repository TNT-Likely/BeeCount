import 'dart:async';
import 'dart:collection';

import '../contracts.dart';

/// Permission mode for a tool. The host application decides how this is
/// persisted and presented to the user.
enum AgentToolPermission { ask, alwaysAllow }

final class AgentToolPermissionDescriptor {
  const AgentToolPermissionDescriptor({
    required this.toolName,
    required this.defaultPermission,
    required this.mutatesLocalData,
  });

  final String toolName;
  final AgentToolPermission defaultPermission;
  final bool mutatesLocalData;
}

/// Host-owned permission persistence contract.
abstract interface class AgentToolPermissionStore {
  Future<AgentToolPermission?> permissionFor(String toolName);

  Future<Map<String, AgentToolPermission>> readAll();

  Future<void> setPermission(
    String toolName,
    AgentToolPermission permission,
  );

  Future<void> restoreDefaults();
}

/// A runtime catalog supplied by the host application. AgentCore does not
/// assume any tool names or business domain.
final class AgentToolPermissionCatalog {
  const AgentToolPermissionCatalog({required this.descriptors});

  final List<AgentToolPermissionDescriptor> descriptors;

  AgentToolPermissionDescriptor? find(String toolName) {
    for (final descriptor in descriptors) {
      if (descriptor.toolName == toolName) return descriptor;
    }
    return null;
  }
}

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

  static const Duration authorizationTimeout = Duration(minutes: 2);
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
          authorizationTimeout,
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

/// Composes a host hard policy with user-configured tool permissions.
final class AgentAuthorizationPolicy implements AgentPolicy {
  AgentAuthorizationPolicy({
    required this.hardPolicy,
    required this.catalog,
    required this.permissions,
    required this.requester,
    this.unknownToolReason = 'tool_not_authorized',
    this.deniedReason = 'tool_denied_by_user',
    this.onPersistenceError,
  });

  final AgentPolicy hardPolicy;
  final AgentToolPermissionCatalog catalog;
  final AgentToolPermissionStore permissions;
  final AgentToolAuthorizationRequester requester;
  final String unknownToolReason;
  final String deniedReason;
  final void Function(Object error, StackTrace stackTrace)? onPersistenceError;

  @override
  Future<AgentPolicyDecision> decide(
    AgentRequest request,
    AgentToolCall call,
  ) async {
    final hardDecision = await hardPolicy.decide(request, call);
    if (!hardDecision.isAllowed) return hardDecision;

    if (catalog.find(call.name) == null) {
      return AgentPolicyDecision.deny(unknownToolReason);
    }

    final permission = await permissions.permissionFor(call.name);
    if (permission == null) {
      return AgentPolicyDecision.deny(unknownToolReason);
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
        return AgentPolicyDecision.deny(deniedReason);
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
        toolName,
        AgentToolPermission.alwaysAllow,
      );
    } on Object catch (error, stackTrace) {
      try {
        onPersistenceError?.call(error, stackTrace);
      } on Object {
        // Observability must not change the current authorization result.
      }
    }
  }
}
