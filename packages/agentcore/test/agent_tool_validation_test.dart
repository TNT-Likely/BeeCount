import 'dart:async';

import 'package:agentcore/agentcore.dart';
import 'package:test/test.dart';

void main() {
  final request = AgentRequest(
    text: 'query',
    scope: const AgentScope(id: 'validation'),
  );
  AgentToolValidationIssue? validate(AgentRequest _, AgentToolCall call) =>
      call.arguments['valid'] == true
          ? null
          : const AgentToolValidationIssue(
              code: 'invalid', message: 'Fix input');
  AgentToolCall call(String id, {bool valid = false}) =>
      AgentToolCall(id: id, name: 'read', arguments: {'valid': valid});

  test('pairs invalid call feedback and executes only the corrected input',
      () async {
    final tool = _Tool();
    final model = _Model([
      AgentTurn.toolCalls([call('bad')]),
      AgentTurn.toolCalls([call('good', valid: true)]),
      const AgentTurn.finalText('done'),
    ]);
    final result = await AgentCore(
      model: model,
      tools: {'read': tool},
      policy: const _Policy(),
      validateToolCall: validate,
      deduplicatedToolNames: {'read'},
    ).run(request);

    expect(tool.calls.map((call) => call.id), ['good']);
    expect(result.executedCalls, hasLength(1));
    expect(result.deniedCalls, isEmpty);
    expect(result.rejectedCalls.single.call.id, 'bad');
    expect(model.requests[1].toolData.single, {
      'id': 'bad',
      'name': 'read',
      'data': {'error': 'invalid', 'message': 'Fix input', 'retryable': true},
    });
    expect(model.requests[2].toolData.single['data'], {'value': 42});
    expect(model.disposed, ['validation']);
  });

  test(
      'repeated invalid batches get one correction then text-only finalization',
      () async {
    final tool = _Tool();
    final model = _Model([
      AgentTurn.toolCalls([call('bad-1')]),
      AgentTurn.toolCalls([call('bad-2')]),
      const AgentTurn.finalText('unavailable'),
    ]);
    final result = await AgentCore(
      model: model,
      tools: {'read': tool},
      policy: const _Policy(),
      validateToolCall: validate,
    ).run(request);
    expect(tool.calls, isEmpty);
    expect(result.rejectedCalls, hasLength(2));
    expect(result.deniedCalls, isEmpty);
    expect(model.requests.last.allowToolCalls, isFalse);
    expect(model.requests.last.toolData.single['data'],
        containsPair('retryable', false));
  });

  test('mixed native batch keeps every call paired and executes valid calls',
      () async {
    final tool = _Tool();
    final model = _Model([
      AgentTurn.toolCalls([call('bad'), call('good', valid: true)]),
      const AgentTurn.finalText('done'),
    ]);
    await AgentCore(
      model: model,
      tools: {'read': tool},
      policy: const _Policy(),
      validateToolCall: validate,
    ).run(request);
    expect(model.requests.last.toolData.map((data) => data['id']),
        ['bad', 'good']);
    expect(tool.calls.single.id, 'good');
  });

  test('permission denial is never treated as a correctable validation issue',
      () async {
    var validations = 0;
    final tool = _Tool();
    final result = await AgentCore(
      model: _Model([
        AgentTurn.toolCalls([call('denied')]),
        const AgentTurn.finalText('denied')
      ]),
      tools: {'read': tool},
      policy: const _Policy(allow: false),
      validateToolCall: (_, __) {
        validations++;
        return null;
      },
    ).run(request);
    expect(validations, 0);
    expect(tool.calls, isEmpty);
    expect(result.deniedCalls, hasLength(1));
    expect(result.rejectedCalls, isEmpty);
  });

  test('validation cannot add planning turns beyond the configured budget',
      () async {
    final model = _Model([
      AgentTurn.toolCalls([call('bad')]),
      const AgentTurn.finalText('unavailable')
    ]);
    await AgentCore(
      model: model,
      tools: {'read': _Tool()},
      policy: const _Policy(),
      validateToolCall: validate,
      maximumModelTurns: 1,
    ).run(request);
    expect(model.requests, hasLength(2));
    expect(model.requests.last.allowToolCalls, isFalse);
    expect(model.requests.last.toolData.single['data'],
        containsPair('retryable', false));
  });

  test('cached results cannot bypass the current semantic validation',
      () async {
    var validations = 0;
    final tool = _Tool();
    final model = _Model([
      AgentTurn.toolCalls([call('first', valid: true)]),
      AgentTurn.toolCalls([call('cached', valid: true)]),
      const AgentTurn.finalText('unavailable'),
    ]);
    final result = await AgentCore(
      model: model,
      tools: {'read': tool},
      policy: const _Policy(),
      deduplicatedToolNames: {'read'},
      validateToolCall: (_, __) => ++validations == 1
          ? null
          : const AgentToolValidationIssue(
              code: 'stale', message: 'Refresh input'),
    ).run(request);
    expect(tool.calls, hasLength(1));
    expect(validations, 2);
    expect(result.rejectedCalls.single.call.id, 'cached');
    expect(model.requests.last.toolData.single['data'],
        containsPair('error', 'stale'));
  });

  test('cancellation while validating does not execute a tool', () async {
    final pending = Completer<AgentToolValidationIssue?>();
    final started = Completer<void>();
    final token = AgentCancellationToken();
    final tool = _Tool();
    final model = _Model([
      AgentTurn.toolCalls([call('pending')])
    ]);
    final run = AgentCore(
      model: model,
      tools: {'read': tool},
      policy: const _Policy(),
      cancellationToken: token,
      validateToolCall: (_, __) {
        started.complete();
        return pending.future;
      },
    ).run(request);
    await started.future;
    token.cancel();
    final result = await run;
    expect(result.wasCancelled, isTrue);
    expect(tool.calls, isEmpty);
    expect(model.disposed, ['validation']);
    pending.complete(null);
  });
}

final class _Model implements AgentModel, AgentRunFinalizer {
  _Model(this.turns);
  final List<AgentTurn> turns;
  final List<AgentRequest> requests = [];
  final List<String> disposed = [];
  @override
  Future<AgentTurn> nextTurn(AgentRequest request) async {
    requests.add(request);
    return turns.removeAt(0);
  }

  @override
  void disposeRun(String runId) => disposed.add(runId);
}

final class _Tool implements AgentTool {
  final List<AgentToolCall> calls = [];
  @override
  String get name => 'read';
  @override
  Future<Map<String, Object?>> execute(AgentToolCall call) async {
    calls.add(call);
    return {'value': 42};
  }
}

final class _Policy implements AgentPolicy {
  const _Policy({this.allow = true});
  final bool allow;
  @override
  AgentPolicyDecision decide(AgentRequest request, AgentToolCall call) => allow
      ? const AgentPolicyDecision.allow()
      : const AgentPolicyDecision.deny('permission_denied');
}
