import 'package:agentcore/agentcore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const catalog = AgentToolPermissionCatalog(
    descriptors: [
      AgentToolPermissionDescriptor(
        toolName: 'read_report',
        defaultPermission: AgentToolPermission.alwaysAllow,
        mutatesLocalData: false,
      ),
      AgentToolPermissionDescriptor(
        toolName: 'write_report',
        defaultPermission: AgentToolPermission.ask,
        mutatesLocalData: true,
      ),
    ],
  );

  test('permission catalog is supplied by the host application', () {
    expect(catalog.find('read_report')?.mutatesLocalData, isFalse);
    expect(catalog.find('write_report')?.defaultPermission,
        AgentToolPermission.ask);
    expect(catalog.find('record_transaction_from_text'), isNull);
  });

  test('generic authorization policy uses the injected catalog', () async {
    final permissions = _MemoryPermissionStore({
      'write_report': AgentToolPermission.ask,
    });
    final requests = <AgentToolAuthorizationRequest>[];
    final broker = AgentToolAuthorizationBroker(
      onRequest: requests.add,
    );
    final policy = AgentAuthorizationPolicy(
      hardPolicy: const _AllowPolicy(),
      catalog: catalog,
      permissions: permissions,
      requester: broker,
    );

    final pending = policy.decide(
      _request,
      AgentToolCall(name: 'write_report', arguments: {'value': 1}),
    );
    await Future<void>.delayed(Duration.zero);
    expect(requests, hasLength(1));
    expect(requests.single.toolName, 'write_report');
    broker.resolve(
      requests.single.authorizationId,
      AgentToolAuthorizationChoice.allowOnce,
    );
    expect((await pending).isAllowed, isTrue);
  });

  test('memory contracts stay serializable and host-independent', () {
    const draft = AgentMemoryDraft(
      ledgerId: 1,
      kind: 'preference',
      content: 'use compact reports',
    );
    const audit = AgentToolCallAudit(
      runId: 'run-1',
      callId: 'call-1',
      toolName: 'write_report',
      status: 'completed',
    );
    expect(draft.content, 'use compact reports');
    expect(audit.toolName, 'write_report');
  });
}

final class _AllowPolicy implements AgentPolicy {
  const _AllowPolicy();

  @override
  AgentPolicyDecision decide(AgentRequest request, AgentToolCall call) =>
      const AgentPolicyDecision.allow();
}

final class _MemoryPermissionStore implements AgentToolPermissionStore {
  _MemoryPermissionStore(this.values);

  final Map<String, AgentToolPermission> values;

  @override
  Future<AgentToolPermission?> permissionFor(String toolName) async =>
      values[toolName];

  @override
  Future<Map<String, AgentToolPermission>> readAll() async => Map.of(values);

  @override
  Future<void> setPermission(
    String toolName,
    AgentToolPermission permission,
  ) async {
    values[toolName] = permission;
  }

  @override
  Future<void> restoreDefaults() async {}
}

final _request = AgentRequest(
  text: 'report',
  scope: const AgentScope(id: 'run-1', ledgerId: 1),
);
