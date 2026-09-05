import 'dart:async';

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
      singleUseToolNames: {fakeTool.name},
    );
  });

  test('returns final text without executing a tool', () async {
    model.turns = [const AgentTurn.finalText('你好，我能帮你查账或记账。')];

    final result = await core.run(_requestFor('你好'));

    expect(result.text, '你好，我能帮你查账或记账。');
    expect(fakeTool.calls, isEmpty);
  });

  test('waits for an asynchronous policy decision before executing a tool',
      () async {
    final decision = Completer<AgentPolicyDecision>();
    final delayedCore = AgentCore(
      model: model
        ..turns = [
          AgentTurn.toolCalls([AgentToolCall(name: fakeTool.name)]),
          const AgentTurn.finalText('完成'),
        ],
      tools: {fakeTool.name: fakeTool},
      policy: _DelayedPolicy(decision.future),
    );

    final pending = delayedCore.run(_requestFor('午饭 35'));
    await Future<void>.delayed(Duration.zero);
    expect(fakeTool.calls, isEmpty);

    decision.complete(const AgentPolicyDecision.allow());
    await pending;
    expect(fakeTool.calls, hasLength(1));
  });

  test('executes an allowed call and sends its data back to the model',
      () async {
    model.turns = [
      AgentTurn.toolCalls([
        AgentToolCall(name: 'write_report', arguments: {'text': '午饭 35'}),
      ]),
      AgentTurn.finalText('已记录午饭 35 元。'),
    ];

    final result = await core.run(_requestFor('午饭 35'));

    expect(fakeTool.calls.single.name, 'write_report');
    expect(result.executedCalls, hasLength(1));
    expect(model.requests[1].toolData, [
      {
        'id': '',
        'name': 'write_report',
        'data': {'recorded': true}
      },
    ]);
  });

  test('does not execute a denied tool call', () async {
    model.turns = [
      AgentTurn.toolCalls([
        AgentToolCall(name: 'delete_report', arguments: {'date': '昨天'}),
      ]),
      AgentTurn.finalText('我不能删除账目。'),
    ];

    final result = await core.run(_requestFor('删除昨天的账'));

    expect(result.deniedCalls.single.reason, 'tool_not_allowed');
    expect(fakeTool.calls, isEmpty);
    expect(model.requests[1].toolData, [
      {
        'id': '',
        'name': 'delete_report',
        'data': {'error': 'tool_not_allowed'},
      },
    ]);
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
          AgentToolCall(name: 'delete_report', arguments: {'index': index}),
        ]),
      const AgentTurn.finalText('不应再请求模型'),
    ];

    final result = await core.run(_requestFor('一直删除'));

    expect(fakeTool.calls, isEmpty);
    expect(result.deniedCalls, hasLength(4));
    expect(model.requests, hasLength(4));
  });

  test('does not repeat a single-use call within one tool-call turn', () async {
    model.turns = [
      AgentTurn.toolCalls([
        for (var index = 0; index < 5; index++)
          AgentToolCall(
            name: 'write_report',
            arguments: {'index': index},
          ),
      ]),
      const AgentTurn.finalText('不应再请求模型'),
    ];

    final result = await core.run(_requestFor('连续记五笔'));

    expect(fakeTool.calls, hasLength(1));
    expect(result.executedCalls, hasLength(1));
  });

  test('executes a configured single-use tool only once per run', () async {
    model.turns = [
      AgentTurn.toolCalls([
        AgentToolCall(
          id: 'call-1',
          name: 'write_report',
          arguments: {'sourceText': '午饭 35'},
        ),
      ]),
      AgentTurn.toolCalls([
        AgentToolCall(
          id: 'call-2',
          name: 'write_report',
          arguments: {'sourceText': '午饭 35'},
        ),
      ]),
      const AgentTurn.finalText('已完成'),
    ];

    final result = await core.run(_requestFor('午饭 35'));

    expect(fakeTool.calls, hasLength(1));
    expect(result.executedCalls, hasLength(1));
    expect(result.deniedCalls.single.call.id, 'call-2');
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

  group('AgentTurnParser', () {
    const parser = AgentTurnParser(allowedToolNames: {'query_report'});

    test('rejects an unknown tool name before any policy evaluation', () {
      expect(
        () => parser.parse(
          '{"kind":"tool_calls","calls":[{"id":"1","name":"drop_db","arguments":{}}]}',
        ),
        throwsA(isA<AgentParseFailure>()),
      );
    });

    test('parses a tool call from the injected allowlist', () {
      final turn = parser.parse(
        '{"kind":"tool_calls","calls":[{"id":"1","name":"query_report","arguments":{}}]}',
      );

      expect(turn, isA<AgentToolCallsTurn>());
    });

    test('rejects call objects with fields outside the protocol', () {
      expect(
        () => parser.parse(
          '{"kind":"tool_calls","calls":[{"id":"1","name":"query_report","arguments":{},"unsafe":true}]}',
        ),
        throwsA(isA<AgentParseFailure>()),
      );
    });

    test('parses a final response', () {
      final turn = parser.parse('{"kind":"final","text":"已完成"}');

      expect(turn, isA<AgentFinalTextTurn>());
      expect((turn as AgentFinalTextTurn).text, '已完成');
    });
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
  String get name => 'write_report';

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
    if (call.name == 'write_report') {
      return const AgentPolicyDecision.allow();
    }
    return const AgentPolicyDecision.deny('tool_not_allowed');
  }
}

final class _DelayedPolicy implements AgentPolicy {
  const _DelayedPolicy(this.decision);

  final Future<AgentPolicyDecision> decision;

  @override
  Future<AgentPolicyDecision> decide(
    AgentRequest request,
    AgentToolCall call,
  ) =>
      decision;
}
