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

abstract interface class AgentToolPermissionStore {
  Future<AgentToolPermission?> permissionFor(String toolName);

  Future<Map<String, AgentToolPermission>> readAll();

  Future<void> setPermission(
    String toolName,
    AgentToolPermission permission,
  );

  Future<void> restoreDefaults();
}

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
}
