import 'package:agentcore/agentcore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeTool fakeTool;
  late _FakeModel model;
  late AgentCore core;

  setUp(() {
    fakeTool = _FakeTool();
    model = _FakeModel();
    core = AgentCore(
      model: model,
      tools: {fakeTool.name: fakeTool},
      policy: const _FakePolicy(),
    );
  });

  test('returns final text without executing a tool', () async {
    model.turns = [const AgentTurn.finalText('你好，我能帮你查账或记账。')];

    final result = await core.run(_requestFor('你好'));

    expect(result.text, '你好，我能帮你查账或记账。');
    expect(fakeTool.calls, isEmpty);
  });

  test('executes an allowed call once and sends its data back to the model',
      () async {
    model.turns = [
      AgentTurn.toolCalls([
        AgentToolCall(
            name: 'record_transaction_from_text', arguments: {'text': '午饭 35'}),
      ]),
      AgentTurn.finalText('已记录午饭 35 元。'),
    ];

    final result = await core.run(_requestFor('午饭 35'));

    expect(fakeTool.calls.single.name, 'record_transaction_from_text');
    expect(result.executedCalls, hasLength(1));
    expect(model.requests[1].toolData, [
      {
        'name': 'record_transaction_from_text',
        'data': {'recorded': true}
      },
    ]);
  });

  test('does not execute a denied write call', () async {
    model.turns = [
      AgentTurn.toolCalls([
        AgentToolCall(name: 'delete_transaction', arguments: {'date': '昨天'}),
      ]),
      AgentTurn.finalText('我不能删除账目。'),
    ];

    final result = await core.run(_requestFor('删除昨天的账'));

    expect(result.deniedCalls.single.reason, 'P0 不允许此操作');
    expect(fakeTool.calls, isEmpty);
  });

  test('returns after unknown calls without executing a tool', () async {
    model.turns = [
      for (var index = 0; index < 4; index++)
        AgentTurn.toolCalls([
          AgentToolCall(name: 'unknown_$index'),
        ]),
      const AgentTurn.finalText('不应再请求模型'),
    ];

    final result = await core.run(_requestFor('未知操作'));

    expect(fakeTool.calls, isEmpty);
    expect(result.deniedCalls, hasLength(4));
    expect(model.requests, hasLength(4));
  });

  test('bounds repeated denied calls independently of executed calls',
      () async {
    model.turns = [
      for (var index = 0; index < 4; index++)
        AgentTurn.toolCalls([
          AgentToolCall(
              name: 'delete_transaction', arguments: {'index': index}),
        ]),
      const AgentTurn.finalText('不应再请求模型'),
    ];

    final result = await core.run(_requestFor('一直删除'));

    expect(fakeTool.calls, isEmpty);
    expect(result.deniedCalls, hasLength(4));
    expect(model.requests, hasLength(4));
  });

  test('does not execute a fifth otherwise allowed call', () async {
    model.turns = [
      AgentTurn.toolCalls([
        for (var index = 0; index < 5; index++)
          AgentToolCall(
            name: 'record_transaction_from_text',
            arguments: {'index': index},
          ),
      ]),
      const AgentTurn.finalText('不应再请求模型'),
    ];

    final result = await core.run(_requestFor('连续记五笔'));

    expect(fakeTool.calls, hasLength(4));
    expect(result.executedCalls, hasLength(4));
  });

  test('fails fast when a tool map key does not match the tool name', () async {
    final invalidCore = AgentCore(
      model: model,
      tools: {'wrong_key': fakeTool},
      policy: const _FakePolicy(),
    );

    await expectLater(
      invalidCore.run(_requestFor('午饭 35')),
      throwsA(isA<ArgumentError>()),
    );
  });
}

AgentRequest _requestFor(String text) => AgentRequest(
      text: text,
      scope: const AgentScope(id: 'test-user'),
    );

final class _FakeModel implements AgentModel {
  List<AgentTurn> turns = [];
  final List<AgentRequest> requests = [];

  @override
  Future<AgentTurn> nextTurn(AgentRequest request) async {
    requests.add(request);
    return turns.removeAt(0);
  }
}

final class _FakeTool implements AgentTool {
  final List<AgentToolCall> calls = [];

  @override
  String get name => 'record_transaction_from_text';

  @override
  Future<Map<String, Object?>> execute(AgentToolCall call) async {
    calls.add(call);
    return {'recorded': true};
  }
}

final class _FakePolicy implements AgentPolicy {
  const _FakePolicy();

  @override
  AgentPolicyDecision decide(AgentRequest request, AgentToolCall call) {
    if (call.name == 'record_transaction_from_text') {
      return const AgentPolicyDecision.allow();
    }
    return const AgentPolicyDecision.deny('P0 不允许此操作');
  }
}
