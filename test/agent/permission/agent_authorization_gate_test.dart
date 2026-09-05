import 'package:agentcore/agentcore.dart';
import 'package:beecount/agent/permission/agent_authorization_gate.dart';
import 'package:beecount/agent/permission/agent_tool_permission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AgentRequest request() => AgentRequest(
        text: '午饭 35',
        scope: const AgentScope(id: 'run-1', ledgerId: 7),
      );

  AgentToolCall recordCall() => AgentToolCall(
        id: 'call-1',
        name: 'record_transaction_from_text',
        arguments: const {'sourceText': '午饭 35'},
      );

  test('hard policy denial never reads permissions or opens authorization',
      () async {
    final permissions = _MemoryPermissionStore();
    final requester = _FakeRequester();
    final policy = AgentAuthorizationPolicy(
      hardPolicy: const _DenyingPolicy('工具不能跨账本访问数据。'),
      permissions: permissions,
      requester: requester,
    );

    final result = await policy.decide(request(), recordCall());

    expect(result.isAllowed, isFalse);
    expect(result.reason, '工具不能跨账本访问数据。');
    expect(permissions.permissionQueries, 0);
    expect(requester.requests, isEmpty);
  });

  test('stored permanent permission permits a call without authorization',
      () async {
    final requester = _FakeRequester();
    final policy = AgentAuthorizationPolicy(
      hardPolicy: const _AllowingPolicy(),
      permissions: _MemoryPermissionStore(
        defaults: {
          'record_transaction_from_text': AgentToolPermission.alwaysAllow,
        },
      ),
      requester: requester,
    );

    final result = await policy.decide(request(), recordCall());

    expect(result.isAllowed, isTrue);
    expect(requester.requests, isEmpty);
  });

  test('user denial rejects the call without changing stored permission',
      () async {
    final store = _MemoryPermissionStore(
      defaults: {'record_transaction_from_text': AgentToolPermission.ask},
    );
    final policy = AgentAuthorizationPolicy(
      hardPolicy: const _AllowingPolicy(),
      permissions: store,
      requester: _FakeRequester(AgentToolAuthorizationChoice.deny),
    );

    final result = await policy.decide(request(), recordCall());

    expect(result.isAllowed, isFalse);
    expect(result.reason, '用户未授权此操作。');
    expect(
      await store.permissionFor('record_transaction_from_text'),
      AgentToolPermission.ask,
    );
  });

  test('allow once permits this call without changing stored permission',
      () async {
    final store = _MemoryPermissionStore(
      defaults: {'record_transaction_from_text': AgentToolPermission.ask},
    );
    final requester = _FakeRequester(AgentToolAuthorizationChoice.allowOnce);
    final policy = AgentAuthorizationPolicy(
      hardPolicy: const _AllowingPolicy(),
      permissions: store,
      requester: requester,
    );

    final result = await policy.decide(request(), recordCall());

    expect(result.isAllowed, isTrue);
    expect(
      await store.permissionFor('record_transaction_from_text'),
      AgentToolPermission.ask,
    );
    expect(requester.requests.single.authorizationId, 'call-1');
    expect(requester.requests.single.runId, 'run-1');
    expect(requester.requests.single.ledgerId, 7);
    expect(requester.requests.single.arguments, {'sourceText': '午饭 35'});
  });

  test('always allow persists permission for later calls', () async {
    final store = _MemoryPermissionStore(
      defaults: {'record_transaction_from_text': AgentToolPermission.ask},
    );
    final policy = AgentAuthorizationPolicy(
      hardPolicy: const _AllowingPolicy(),
      permissions: store,
      requester: _FakeRequester(AgentToolAuthorizationChoice.alwaysAllow),
    );

    final result = await policy.decide(request(), recordCall());

    expect(result.isAllowed, isTrue);
    expect(
      await store.permissionFor('record_transaction_from_text'),
      AgentToolPermission.alwaysAllow,
    );
  });

  test('persistence failure still permits current call and reports error',
      () async {
    final failures = <Object>[];
    final policy = AgentAuthorizationPolicy(
      hardPolicy: const _AllowingPolicy(),
      permissions: _FailingPermissionStore(),
      requester: _FakeRequester(AgentToolAuthorizationChoice.alwaysAllow),
      onPersistenceError: (error, stackTrace) => failures.add(error),
    );

    final result = await policy.decide(request(), recordCall());

    expect(result.isAllowed, isTrue);
    expect(failures, hasLength(1));
    expect(failures.single, isA<StateError>());
  });

  test('unknown tools are denied without authorization', () async {
    final requester = _FakeRequester(AgentToolAuthorizationChoice.allowOnce);
    final policy = AgentAuthorizationPolicy(
      hardPolicy: const _AllowingPolicy(),
      permissions: _MemoryPermissionStore(),
      requester: requester,
    );

    final result = await policy.decide(
      request(),
      AgentToolCall(id: 'unknown-1', name: 'delete_everything'),
    );

    expect(result.isAllowed, isFalse);
    expect(result.reason, '工具未获授权。');
    expect(requester.requests, isEmpty);
  });

  testWidgets(
    'broker denies an unanswered authorization after exactly two minutes',
    (tester) async {
      final broker = AgentToolAuthorizationBroker(onRequest: (_) {});
      var isComplete = false;
      final result = broker.request(_authorizationRequest())
        ..then((_) => isComplete = true);

      await tester.pump(
        const Duration(minutes: 2) - const Duration(milliseconds: 1),
      );
      expect(isComplete, isFalse);

      await tester.pump(const Duration(milliseconds: 1));
      expect(await result, AgentToolAuthorizationChoice.deny);
      expect(
        broker.resolve(
          'authorization-1',
          AgentToolAuthorizationChoice.allowOnce,
        ),
        isFalse,
      );
    },
  );

  test('broker resolves and can deny all pending authorizations', () async {
    final broker = AgentToolAuthorizationBroker(onRequest: (_) {});
    final first = broker.request(_authorizationRequest());
    final second = broker.request(
      const AgentToolAuthorizationRequest(
        authorizationId: 'authorization-2',
        runId: 'run-1',
        ledgerId: 7,
        toolName: 'save_explicit_memory',
        arguments: {'content': '咖啡用微信'},
      ),
    );

    expect(
      broker.resolve('authorization-1', AgentToolAuthorizationChoice.allowOnce),
      isTrue,
    );
    broker.denyPending();

    expect(await first, AgentToolAuthorizationChoice.allowOnce);
    expect(await second, AgentToolAuthorizationChoice.deny);
    expect(
      broker.resolve('authorization-2', AgentToolAuthorizationChoice.allowOnce),
      isFalse,
    );
  });
}

AgentToolAuthorizationRequest _authorizationRequest() =>
    const AgentToolAuthorizationRequest(
      authorizationId: 'authorization-1',
      runId: 'run-1',
      ledgerId: 7,
      toolName: 'record_transaction_from_text',
      arguments: {'sourceText': '午饭 35'},
    );

final class _AllowingPolicy implements AgentPolicy {
  const _AllowingPolicy();

  @override
  AgentPolicyDecision decide(AgentRequest request, AgentToolCall call) =>
      const AgentPolicyDecision.allow();
}

final class _DenyingPolicy implements AgentPolicy {
  const _DenyingPolicy(this.reason);

  final String reason;

  @override
  AgentPolicyDecision decide(AgentRequest request, AgentToolCall call) =>
      AgentPolicyDecision.deny(reason);
}

final class _FakeRequester implements AgentToolAuthorizationRequester {
  _FakeRequester([this.choice = AgentToolAuthorizationChoice.deny]);

  final AgentToolAuthorizationChoice choice;
  final List<AgentToolAuthorizationRequest> requests = [];

  @override
  Future<AgentToolAuthorizationChoice> request(
    AgentToolAuthorizationRequest request,
  ) async {
    requests.add(request);
    return choice;
  }

  @override
  void denyPending() {}
}

class _MemoryPermissionStore implements AgentToolPermissionStore {
  _MemoryPermissionStore({Map<String, AgentToolPermission> defaults = const {}})
      : _permissions = Map.of(defaults);

  final Map<String, AgentToolPermission> _permissions;
  int permissionQueries = 0;

  @override
  Future<AgentToolPermission?> permissionFor(String toolName) async {
    permissionQueries++;
    return _permissions[toolName] ??
        AgentToolPermissionCatalog.find(toolName)?.defaultPermission;
  }

  @override
  Future<Map<String, AgentToolPermission>> readAll() async =>
      Map.unmodifiable(_permissions);

  @override
  Future<void> restoreDefaults() async => _permissions.clear();

  @override
  Future<void> setPermission(
    String toolName,
    AgentToolPermission permission,
  ) async {
    _permissions[toolName] = permission;
  }
}

final class _FailingPermissionStore extends _MemoryPermissionStore {
  _FailingPermissionStore()
      : super(
          defaults: {
            'record_transaction_from_text': AgentToolPermission.ask,
          },
        );

  @override
  Future<void> setPermission(
    String toolName,
    AgentToolPermission permission,
  ) =>
      Future<void>.error(StateError('磁盘不可用'));
}
