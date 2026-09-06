import 'package:agentcore/agentcore.dart'
    hide
        AgentAuthorizationPolicy,
        AgentToolAuthorizationBroker,
        AgentToolAuthorizationChoice,
        AgentToolAuthorizationRequest,
        AgentToolAuthorizationRequester,
        AgentToolPermission,
        AgentToolPermissionDescriptor,
        AgentToolPermissionStore,
        AgentToolPermissionCatalog;
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

  test('persistence observer failure still permits the current call', () async {
    final policy = AgentAuthorizationPolicy(
      hardPolicy: const _AllowingPolicy(),
      permissions: _FailingPermissionStore(),
      requester: _FakeRequester(AgentToolAuthorizationChoice.alwaysAllow),
      onPersistenceError: (error, stackTrace) {
        throw StateError('观察者不可用');
      },
    );

    final result = await policy.decide(request(), recordCall());

    expect(result.isAllowed, isTrue);
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
      final result = broker.request(
        runId: 'run-1',
        ledgerId: 7,
        toolName: 'record_transaction_from_text',
        arguments: const {'sourceText': '午饭 35'},
      )..then((_) => isComplete = true);

      await tester.pump(
        const Duration(minutes: 2) - const Duration(milliseconds: 1),
      );
      expect(isComplete, isFalse);

      await tester.pump(const Duration(milliseconds: 1));
      expect(await result, AgentToolAuthorizationChoice.deny);
      expect(
        broker.resolve('missing', AgentToolAuthorizationChoice.allowOnce),
        isFalse,
      );
    },
  );

  test('broker resolves and can deny all pending authorizations', () async {
    final requested = <AgentToolAuthorizationRequest>[];
    final broker = AgentToolAuthorizationBroker(
      onRequest: requested.add,
    );
    final first = broker.request(
      runId: 'run-1',
      ledgerId: 7,
      toolName: 'record_transaction_from_text',
      arguments: const {'sourceText': '午饭 35'},
    );
    final second = broker.request(
      runId: 'run-1',
      ledgerId: 7,
      toolName: 'save_explicit_memory',
      arguments: const {'content': '咖啡用微信'},
    );

    expect(
      broker.resolve(
        requested[0].authorizationId,
        AgentToolAuthorizationChoice.allowOnce,
      ),
      isTrue,
    );
    broker.denyPending();

    expect(await first, AgentToolAuthorizationChoice.allowOnce);
    expect(await second, AgentToolAuthorizationChoice.deny);
    expect(
      broker.resolve(
        requested[1].authorizationId,
        AgentToolAuthorizationChoice.allowOnce,
      ),
      isFalse,
    );
  });

  test('broker gives blank repeated model call IDs independent nonces',
      () async {
    final requests = <AgentToolAuthorizationRequest>[];
    final broker = AgentToolAuthorizationBroker(onRequest: requests.add);
    final policy = AgentAuthorizationPolicy(
      hardPolicy: const _AllowingPolicy(),
      permissions: _MemoryPermissionStore(
        defaults: {'record_transaction_from_text': AgentToolPermission.ask},
      ),
      requester: broker,
    );
    final blankCall = AgentToolCall(
      id: '',
      name: 'record_transaction_from_text',
      arguments: const {'sourceText': '午饭 35'},
    );

    final first = policy.decide(request(), blankCall);
    await Future<void>.delayed(Duration.zero);
    final firstId = requests.single.authorizationId;
    expect(firstId, isNotEmpty);
    expect(
      broker.resolve(firstId, AgentToolAuthorizationChoice.allowOnce),
      isTrue,
    );
    expect((await first).isAllowed, isTrue);

    final later = policy.decide(request(), blankCall);
    await Future<void>.delayed(Duration.zero);
    final laterId = requests.last.authorizationId;
    expect(laterId, isNot(firstId));
    expect(
      broker.resolve(firstId, AgentToolAuthorizationChoice.alwaysAllow),
      isFalse,
    );
    expect(
      broker.resolve(laterId, AgentToolAuthorizationChoice.allowOnce),
      isTrue,
    );
    expect((await later).isAllowed, isTrue);
  });

  test('broker snapshots immutable authorization payload', () async {
    final requests = <AgentToolAuthorizationRequest>[];
    final broker = AgentToolAuthorizationBroker(onRequest: requests.add);
    final arguments = <String, Object?>{'sourceText': '午饭 35'};

    final decision = broker.request(
      runId: 'run-1',
      ledgerId: 7,
      toolName: 'record_transaction_from_text',
      arguments: arguments,
    );
    final authorization = requests.single;
    arguments['sourceText'] = '晚饭 48';

    expect(authorization.runId, 'run-1');
    expect(authorization.toolName, 'record_transaction_from_text');
    expect(authorization.arguments, {'sourceText': '午饭 35'});
    expect(
      () => authorization.arguments['sourceText'] = '不能修改',
      throwsUnsupportedError,
    );
    broker.resolve(
        authorization.authorizationId, AgentToolAuthorizationChoice.deny);
    expect(await decision, AgentToolAuthorizationChoice.deny);
  });

  test('old resolved cleanup cannot remove a newly pending authorization',
      () async {
    final requests = <AgentToolAuthorizationRequest>[];
    final broker = AgentToolAuthorizationBroker(onRequest: requests.add);
    final first = broker.request(
      runId: 'run-1',
      ledgerId: 7,
      toolName: 'record_transaction_from_text',
      arguments: const {'sourceText': '午饭 35'},
    );
    final firstId = requests.single.authorizationId;

    expect(
      broker.resolve(firstId, AgentToolAuthorizationChoice.allowOnce),
      isTrue,
    );
    final later = broker.request(
      runId: 'run-1',
      ledgerId: 7,
      toolName: 'save_explicit_memory',
      arguments: const {'content': '咖啡用微信'},
    );
    final laterId = requests.last.authorizationId;
    await first;
    await Future<void>.delayed(Duration.zero);

    expect(
      broker.resolve(laterId, AgentToolAuthorizationChoice.allowOnce),
      isTrue,
    );
    expect(await later, AgentToolAuthorizationChoice.allowOnce);
  });

  test('old denied cleanup cannot remove a newly pending authorization',
      () async {
    final requests = <AgentToolAuthorizationRequest>[];
    final broker = AgentToolAuthorizationBroker(onRequest: requests.add);
    final first = broker.request(
      runId: 'run-1',
      ledgerId: 7,
      toolName: 'record_transaction_from_text',
      arguments: const {'sourceText': '午饭 35'},
    );

    broker.denyPending();
    final later = broker.request(
      runId: 'run-1',
      ledgerId: 7,
      toolName: 'save_explicit_memory',
      arguments: const {'content': '咖啡用微信'},
    );
    final laterId = requests.last.authorizationId;
    await first;
    await Future<void>.delayed(Duration.zero);

    expect(
      broker.resolve(laterId, AgentToolAuthorizationChoice.allowOnce),
      isTrue,
    );
    expect(await later, AgentToolAuthorizationChoice.allowOnce);
  });

  test('broker denies a request callback failure without reserving the nonce',
      () async {
    var throwsOnRequest = true;
    final requests = <AgentToolAuthorizationRequest>[];
    final broker = AgentToolAuthorizationBroker(
      onRequest: (request) {
        if (throwsOnRequest) throw StateError('事件流关闭');
        requests.add(request);
      },
    );

    final failed = broker.request(
      runId: 'run-1',
      ledgerId: 7,
      toolName: 'record_transaction_from_text',
      arguments: const {'sourceText': '午饭 35'},
    );
    expect(await failed, AgentToolAuthorizationChoice.deny);

    throwsOnRequest = false;
    final recovered = broker.request(
      runId: 'run-1',
      ledgerId: 7,
      toolName: 'record_transaction_from_text',
      arguments: const {'sourceText': '午饭 35'},
    );
    expect(
      broker.resolve(
        requests.single.authorizationId,
        AgentToolAuthorizationChoice.allowOnce,
      ),
      isTrue,
    );
    expect(await recovered, AgentToolAuthorizationChoice.allowOnce);
  });
}

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
  final List<_AuthorizationPayload> requests = [];

  @override
  Future<AgentToolAuthorizationChoice> request({
    required String runId,
    required int? ledgerId,
    required String toolName,
    required Map<String, Object?> arguments,
  }) async {
    requests.add(
      _AuthorizationPayload(
        runId: runId,
        ledgerId: ledgerId,
        toolName: toolName,
        arguments: arguments,
      ),
    );
    return choice;
  }

  @override
  void denyPending() {}
}

final class _AuthorizationPayload {
  const _AuthorizationPayload({
    required this.runId,
    required this.ledgerId,
    required this.toolName,
    required this.arguments,
  });

  final String runId;
  final int? ledgerId;
  final String toolName;
  final Map<String, Object?> arguments;
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
