import 'dart:convert';

import 'package:agentcore/agentcore.dart';
import 'package:test/test.dart';

AgentEvalCase sample(String id) =>
    AgentEvalCase(id: id, tags: ['aggregate'], input: {}, expected: {});

void main() {
  test(
      'numeric assertions detect wrong totals, missing nulls and list truncation',
      () {
    expect(agentEvalMismatches({'amount': 1295}, {'amount': 1296}), isNotEmpty);
    expect(agentEvalMismatches({'share': null}, {}), isNotEmpty);
    expect(agentEvalMismatches([1, 2], [1]), isNotEmpty);
    expect(
        agentEvalMismatches({'amount': 1295}, {'amount': 1295.0, 'count': 4}),
        isEmpty);
    expect(
        agentEvalMismatches({'share': .3}, {'share': .30000000001},
            numericTolerance: 1e-9),
        isEmpty);
    expect(agentEvalMismatches(1, double.nan), isNotEmpty);
  });

  test('executor failures continue the suite without leaking exception content',
      () async {
    final report = await AgentEvalRunner(
      execute: (item) async {
        if (item.id == 'error') throw StateError('Bearer private-key');
        return const AgentEvalObservation(metrics: {'requests': 2});
      },
      evaluate: (_, __) =>
          [const AgentEvalCheck(name: 'numbers', passed: true)],
    ).run(
        cases: [sample('error'), sample('ok')], metadata: {'mode': 'offline'});

    expect(report.passed, 1);
    expect(report.allPassed, isFalse);
    final json = jsonEncode(report.toJson());
    expect(json, isNot(contains('private-key')));
    expect(report.toJson()['summary'],
        containsPair('metricTotals', {'requests': 2}));
    expect(report.toMarkdown(), contains('| error | FAIL |'));
  });

  test('empty assertions never result in a passing case', () async {
    final report = await AgentEvalRunner(
      execute: (_) async => const AgentEvalObservation(),
      evaluate: (_, __) => [],
    ).run(cases: [sample('unchecked')], metadata: {});
    expect(report.allPassed, isFalse);
  });

  test('empty selections and duplicate IDs fail before execution', () async {
    var calls = 0;
    final runner = AgentEvalRunner(
      execute: (_) async {
        calls++;
        return const AgentEvalObservation();
      },
      evaluate: (_, __) => [],
    );
    await expectLater(runner.run(cases: [], metadata: {}), throwsArgumentError);
    await expectLater(
        runner.run(cases: [sample('same'), sample('same')], metadata: {}),
        throwsArgumentError);
    expect(calls, 0);
  });

  test('case schema rejects missing expectations and invalid tags', () {
    expect(() => AgentEvalCase.fromJson({'id': 'x', 'input': {}, 'tags': []}),
        throwsFormatException);
    expect(
        () => AgentEvalCase.fromJson({
              'id': 'x',
              'input': {},
              'expected': {},
              'tags': [1]
            }),
        throwsFormatException);
  });

  test('summary counts check failures separately from case failures', () async {
    final report = await AgentEvalRunner(
      execute: (_) async => const AgentEvalObservation(),
      evaluate: (item, _) => [
        const AgentEvalCheck(name: 'tool', passed: true),
        AgentEvalCheck(name: 'numbers', passed: item.id == 'ok'),
      ],
    ).run(cases: [sample('ok'), sample('wrong')], metadata: {});
    final summary = report.toJson()['summary'] as Map;
    expect(summary['checks'], {
      'tool': {'total': 2, 'passed': 2},
      'numbers': {'total': 2, 'passed': 1}
    });
    expect(summary['tags'], {
      'aggregate': {'total': 2, 'passed': 1}
    });
  });

  test('reports use nearest-rank latency percentiles and never pass empty runs',
      () {
    final report = AgentEvalReport(metadata: {}, results: [
      for (var index = 1; index <= 20; index++)
        AgentEvalResult(
          testCase: sample('case-$index'),
          observation: const AgentEvalObservation(),
          checks: const [AgentEvalCheck(name: 'numbers', passed: true)],
          elapsedMilliseconds: index * 100,
        ),
    ]);
    final summary = report.toJson()['summary'] as Map;
    expect(summary['latencyP50Ms'], 1000);
    expect(summary['latencyP95Ms'], 1900);
    expect(report.toMarkdown(), contains('p95 1900 ms'));
    expect(const AgentEvalReport(metadata: {}, results: []).allPassed, isFalse);
  });
}
