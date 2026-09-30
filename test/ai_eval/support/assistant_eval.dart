import 'package:agentcore/agentcore.dart' as core;
import 'package:beecount/agent/policy/p0_agent_policy.dart';
import 'package:beecount/services/ai/agent_app_facade.dart';

import 'ledger_fixture.dart';

/// Exercises the same facade, selection, authorization, tools and SQLite used
/// by the assistant. Oracle calls are available only to the offline model.
final class AssistantEvalExecutor {
  const AssistantEvalExecutor({required this.live, this.createLiveModel});

  final bool live;
  final core.AgentModel Function()? createLiveModel;

  Future<core.AgentEvalObservation> execute(core.AgentEvalCase testCase) async {
    final fixture = await LedgerEvalFixture.create();
    try {
      final ledgerId = fixture.ledgers[testCase.input['ledger']]!;
      final countBefore = await fixture.transactionCount();
      final history = <Map<String, Object?>>[];
      final turns = <Map<String, Object?>>[];
      var modelTurns = 0;
      var toolCalls = 0;
      var deniedCalls = 0;
      var selectionPassed = true;
      for (final (index, rawStep)
          in (testCase.input['steps'] as List).indexed) {
        final step = rawStep as Map;
        final prompt = step['prompt'] as String;
        final model = _ObservedModel(
          live ? createLiveModel!() : _OracleModel(step['oracleCalls'] as List),
          (request) {
            modelTurns++;
            if (!live && request.allowToolCalls) {
              for (final rawCall in step['oracleCalls'] as List) {
                if (!(request.availableToolNames
                        ?.contains((rawCall as Map)['name']) ??
                    false)) {
                  selectionPassed = false;
                }
              }
            }
          },
        );
        final facade = AgentAppFacade(
          memoryRepository: fixture.memory,
          toolGateway: fixture.gateway,
          permissionStore: _ReadPermissionStore(),
          policy: const _ReadOnlyPolicy(),
          model: model,
          now: () => fixture.now,
          runIdFactory: () => '${testCase.id}-$index',
        );
        final calls = <Map<String, Object?>>[];
        final events = facade.processMessageEvents(
          message: prompt,
          ledgerId: ledgerId,
          context: {
            'ledger': {
              'id': ledgerId,
              'name': testCase.input['ledger'],
              'currency': 'CNY'
            },
            'recentMessages': history,
          },
        );
        Map<String, Object?>? completed;
        await for (final event in events) {
          if (event is AgentToolAuthorizationRequestedEvent) {
            facade.resolveToolAuthorization(event.request.authorizationId,
                core.AgentToolAuthorizationChoice.deny);
          } else if (event is AgentToolCompletedEvent) {
            toolCalls++;
            final result = event.result == null
                ? null
                : Map<String, Object?>.of(event.result!);
            if (result?['items'] is List) {
              result!['itemCount'] = (result['items'] as List).length;
            }
            calls.add({
              'name': event.toolName,
              'arguments': event.arguments,
              'succeeded': event.succeeded,
              'result': result,
            });
          } else if (event is AgentRunCompletedEvent) {
            completed = {
              'responseType': event.result.type,
              'text': event.result.text,
              'calls': calls
            };
            history.addAll([
              {'role': 'user', 'content': prompt},
              {'role': 'assistant', 'content': event.result.text},
            ]);
          }
        }
        if (completed == null) throw StateError('Missing completion event');
        turns.add(completed);
      }
      final audits =
          await fixture.database.select(fixture.database.agentToolCalls).get();
      deniedCalls = audits.where((audit) => audit.status == 'denied').length;
      return core.AgentEvalObservation(
        data: {
          'turns': turns,
          'selectionPassed': selectionPassed,
          'transactionsUnchanged':
              countBefore == await fixture.transactionCount(),
          'deniedCalls': deniedCalls,
        },
        metrics: {
          'modelTurns': modelTurns,
          'toolCalls': toolCalls,
          'deniedCalls': deniedCalls
        },
      );
    } finally {
      await fixture.close();
    }
  }

  List<core.AgentEvalCheck> evaluate(
      core.AgentEvalCase testCase, core.AgentEvalObservation observation) {
    final checks = <core.AgentEvalCheck>[
      core.AgentEvalCheck(
          name: 'readonly',
          passed: observation.data['transactionsUnchanged'] == true),
      core.AgentEvalCheck(
          name: 'no_denied_calls',
          passed: observation.data['deniedCalls'] == 0),
      if (!live)
        core.AgentEvalCheck(
            name: 'tool_selection',
            passed: observation.data['selectionPassed'] == true),
    ];
    final actualTurns = observation.data['turns'] as List;
    final expectedTurns = testCase.expected['turns'] as List;
    checks.add(core.AgentEvalCheck(
        name: 'turn_count',
        passed: actualTurns.length == expectedTurns.length));
    for (var index = 0; index < expectedTurns.length; index++) {
      if (index >= actualTurns.length) break;
      final expected = expectedTurns[index] as Map;
      final actual = actualTurns[index] as Map;
      checks.add(core.AgentEvalCheck(
          name: 'response_type',
          passed: actual['responseType'] == expected['responseType']));
      final calls = actual['calls'] as List;
      for (final rawExpectedTool in expected['tools'] as List) {
        final expectedTool = rawExpectedTool as Map;
        final candidates = calls
            .where((raw) => (raw as Map)['name'] == expectedTool['name'])
            .toList();
        checks.add(core.AgentEvalCheck(
            name: 'required_tool',
            passed: candidates.isNotEmpty,
            detail: '${testCase.id}/turn-$index/${expectedTool['name']}'));
        final matching = candidates.where((raw) {
          final call = raw as Map;
          return call['succeeded'] == true &&
              core
                  .agentEvalMismatches(
                    expectedTool['result'],
                    call['result'],
                    numericTolerance: 1e-9,
                  )
                  .isEmpty;
        }).isNotEmpty;
        final differences = candidates.isEmpty
            ? ['tool not called']
            : core.agentEvalMismatches(
                expectedTool['result'],
                (candidates.first as Map)['result'],
                numericTolerance: 1e-9,
              );
        checks.add(core.AgentEvalCheck(
            name: 'numeric_and_scope',
            passed: matching,
            detail: matching ? null : differences.join('; ')));
      }
      checks.add(core.AgentEvalCheck(
          name: 'tool_execution',
          passed: calls.every((raw) => (raw as Map)['succeeded'] == true)));
      if (live) {
        final text =
            (actual['text'] as String).replaceAll('**', '').replaceAll('`', '');
        final patterns = (expected['answerPatterns'] as List).cast<String>();
        checks.add(core.AgentEvalCheck(
            name: 'answer_facts',
            passed:
                patterns.every((pattern) => RegExp(pattern).hasMatch(text)) &&
                    text.trim().isNotEmpty,
            detail:
                'Checks expected numeric mentions; not a full semantic assessment.'));
        checks.add(core.AgentEvalCheck(
            name: 'clean_answer',
            passed: !RegExp(
                    r'DioException|is not a subtype|<[^>]*DSML|"tool_calls"')
                .hasMatch(text)));
      }
    }
    return checks;
  }
}

final class _OracleModel implements core.AgentModel {
  _OracleModel(this.calls);
  final List calls;
  bool called = false;

  @override
  Future<core.AgentTurn> nextTurn(core.AgentRequest request) async {
    if (called) return const core.AgentTurn.finalText('离线工具回归完成。');
    called = true;
    return core.AgentTurn.toolCalls([
      for (final (index, raw) in calls.indexed)
        core.AgentToolCall(
            id: 'oracle-$index',
            name: (raw as Map)['name'] as String,
            arguments: Map<String, Object?>.from(raw['arguments'] as Map)),
    ]);
  }
}

final class _ObservedModel implements core.AgentModel, core.AgentRunFinalizer {
  const _ObservedModel(this.delegate, this.onRequest);
  final core.AgentModel delegate;
  final void Function(core.AgentRequest) onRequest;

  @override
  Future<core.AgentTurn> nextTurn(core.AgentRequest request) {
    onRequest(request);
    return delegate.nextTurn(request);
  }

  @override
  void disposeRun(String runId) {
    if (delegate case core.AgentRunFinalizer finalizer) {
      finalizer.disposeRun(runId);
    }
  }
}

final class _ReadOnlyPolicy implements core.AgentPolicy {
  const _ReadOnlyPolicy();

  @override
  core.AgentPolicyDecision decide(
      core.AgentRequest request, core.AgentToolCall call) {
    if (const {
      'record_transaction_from_text',
      'save_explicit_memory',
      'forget_memory'
    }.contains(call.name)) {
      return const core.AgentPolicyDecision.deny(
          'Eval only permits read operations');
    }
    return const P0AgentPolicy().decide(request, call);
  }
}

final class _ReadPermissionStore implements core.AgentToolPermissionStore {
  @override
  Future<core.AgentToolPermission?> permissionFor(String toolName) async =>
      core.AgentToolPermission.alwaysAllow;
  @override
  Future<Map<String, core.AgentToolPermission>> readAll() async => {};
  @override
  Future<void> restoreDefaults() async {}
  @override
  Future<void> setPermission(
      String name, core.AgentToolPermission permission) async {}
}
