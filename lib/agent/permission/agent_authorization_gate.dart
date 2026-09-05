import 'package:agentcore/agentcore.dart'
    show AgentPolicy, AgentPolicyDecision, AgentRequest, AgentToolCall;
import 'package:agentcore/agentcore.dart' as core;

import 'agent_tool_permission.dart';

typedef AgentToolAuthorizationChoice = core.AgentToolAuthorizationChoice;
typedef AgentToolAuthorizationRequest = core.AgentToolAuthorizationRequest;
typedef AgentToolAuthorizationRequester = core.AgentToolAuthorizationRequester;
typedef AgentToolAuthorizationBroker = core.AgentToolAuthorizationBroker;

/// BeeCount composition of the generic permission policy with its own tool
/// catalog and localized denial messages.
final class AgentAuthorizationPolicy implements AgentPolicy {
  AgentAuthorizationPolicy({
    required AgentPolicy hardPolicy,
    required AgentToolPermissionStore permissions,
    required AgentToolAuthorizationRequester requester,
    void Function(Object error, StackTrace stackTrace)? onPersistenceError,
  }) : _delegate = core.AgentAuthorizationPolicy(
          hardPolicy: hardPolicy,
          catalog: AgentToolPermissionCatalog.runtime,
          permissions: permissions,
          requester: requester,
          unknownToolReason: '工具未获授权。',
          deniedReason: '用户未授权此操作。',
          onPersistenceError: onPersistenceError,
        );

  final core.AgentAuthorizationPolicy _delegate;

  @override
  Future<AgentPolicyDecision> decide(
    AgentRequest request,
    AgentToolCall call,
  ) =>
      _delegate.decide(request, call);
}
