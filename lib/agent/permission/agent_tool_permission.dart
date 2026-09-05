import 'package:agentcore/agentcore.dart' as core;

/// App-facing aliases for the generic AgentCore permission contracts.
typedef AgentToolPermission = core.AgentToolPermission;
typedef AgentToolPermissionDescriptor = core.AgentToolPermissionDescriptor;
typedef AgentToolPermissionStore = core.AgentToolPermissionStore;

final class AgentToolPermissionCatalog {
  const AgentToolPermissionCatalog._();

  static const List<AgentToolPermissionDescriptor> descriptors = [
    AgentToolPermissionDescriptor(
      toolName: 'query_transactions',
      defaultPermission: AgentToolPermission.alwaysAllow,
      mutatesLocalData: false,
    ),
    AgentToolPermissionDescriptor(
      toolName: 'get_spending_summary',
      defaultPermission: AgentToolPermission.alwaysAllow,
      mutatesLocalData: false,
    ),
    AgentToolPermissionDescriptor(
      toolName: 'get_budget_status',
      defaultPermission: AgentToolPermission.alwaysAllow,
      mutatesLocalData: false,
    ),
    AgentToolPermissionDescriptor(
      toolName: 'record_transaction_from_text',
      defaultPermission: AgentToolPermission.ask,
      mutatesLocalData: true,
    ),
    AgentToolPermissionDescriptor(
      toolName: 'save_explicit_memory',
      defaultPermission: AgentToolPermission.ask,
      mutatesLocalData: true,
    ),
    AgentToolPermissionDescriptor(
      toolName: 'forget_memory',
      defaultPermission: AgentToolPermission.ask,
      mutatesLocalData: true,
    ),
  ];

  static AgentToolPermissionDescriptor? find(String toolName) {
    for (final descriptor in descriptors) {
      if (descriptor.toolName == toolName) return descriptor;
    }
    return null;
  }

  static core.AgentToolPermissionCatalog get runtime =>
      const core.AgentToolPermissionCatalog(descriptors: descriptors);
}
