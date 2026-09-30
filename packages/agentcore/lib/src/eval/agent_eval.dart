import 'dart:async';
import 'dart:convert';

/// Business-neutral fixture: the host owns input and expected-result schemas.
final class AgentEvalCase {
  AgentEvalCase({
    required this.id,
    required this.input,
    required this.expected,
    this.tags = const [],
  });

  final String id;
  final Map<String, Object?> input;
  final Map<String, Object?> expected;
  final List<String> tags;

  factory AgentEvalCase.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final input = json['input'];
    final expected = json['expected'];
    final tags = json['tags'];
    if (id is! String ||
        id.trim().isEmpty ||
        input is! Map ||
        expected is! Map ||
        tags is! List ||
        tags.any((tag) => tag is! String)) {
      throw const FormatException('Invalid evaluation case');
    }
    return AgentEvalCase(
      id: id,
      input: Map<String, Object?>.from(input),
      expected: Map<String, Object?>.from(expected),
      tags: tags.cast<String>(),
    );
  }
}

final class AgentEvalCheck {
  const AgentEvalCheck({required this.name, required this.passed, this.detail});

  final String name;
  final bool passed;
  final String? detail;

  Map<String, Object?> toJson() => {
        'name': name,
        'passed': passed,
        if (detail != null) 'detail': detail,
      };
}

final class AgentEvalObservation {
  const AgentEvalObservation({this.data = const {}, this.metrics = const {}});

  final Map<String, Object?> data;
  final Map<String, num> metrics;
}

typedef AgentEvalExecutor = Future<AgentEvalObservation> Function(
    AgentEvalCase);
typedef AgentEvalEvaluator = FutureOr<List<AgentEvalCheck>> Function(
  AgentEvalCase testCase,
  AgentEvalObservation observation,
);

final class AgentEvalResult {
  const AgentEvalResult({
    required this.testCase,
    required this.observation,
    required this.checks,
    required this.elapsedMilliseconds,
  });

  final AgentEvalCase testCase;
  final AgentEvalObservation observation;
  final List<AgentEvalCheck> checks;
  final int elapsedMilliseconds;
  bool get passed => checks.isNotEmpty && checks.every((check) => check.passed);

  Map<String, Object?> toJson() => {
        'id': testCase.id,
        'tags': testCase.tags,
        'passed': passed,
        'elapsedMilliseconds': elapsedMilliseconds,
        'checks': checks.map((check) => check.toJson()).toList(),
        'metrics': observation.metrics,
        'observation': observation.data,
      };
}

/// Runs cases sequentially; database isolation, network cancellation and secret
/// redaction belong to the host executor. An empty selection fails fast.
final class AgentEvalRunner {
  const AgentEvalRunner({required this.execute, required this.evaluate});

  final AgentEvalExecutor execute;
  final AgentEvalEvaluator evaluate;

  Future<AgentEvalReport> run({
    required Iterable<AgentEvalCase> cases,
    required Map<String, Object?> metadata,
    void Function(AgentEvalResult)? onResult,
  }) async {
    final selected = cases.toList();
    if (selected.isEmpty) throw ArgumentError('No evaluation cases selected');
    if (selected.map((item) => item.id).toSet().length != selected.length) {
      throw ArgumentError('Duplicate evaluation case IDs');
    }
    final results = <AgentEvalResult>[];
    for (final testCase in selected) {
      final stopwatch = Stopwatch()..start();
      AgentEvalObservation observation;
      List<AgentEvalCheck> checks;
      try {
        observation = await execute(testCase);
        checks = await evaluate(testCase, observation);
        if (checks.isEmpty) {
          checks = [
            const AgentEvalCheck(name: 'nonempty_checks', passed: false)
          ];
        }
      } catch (error) {
        // Do not serialize arbitrary exceptions: transports may embed headers.
        observation =
            AgentEvalObservation(data: {'errorType': '${error.runtimeType}'});
        checks = [const AgentEvalCheck(name: 'execution', passed: false)];
      }
      stopwatch.stop();
      final result = AgentEvalResult(
        testCase: testCase,
        observation: observation,
        checks: checks,
        elapsedMilliseconds: stopwatch.elapsedMilliseconds,
      );
      results.add(result);
      onResult?.call(result);
    }
    return AgentEvalReport(metadata: metadata, results: results);
  }
}

final class AgentEvalReport {
  const AgentEvalReport({required this.metadata, required this.results});

  final Map<String, Object?> metadata;
  final List<AgentEvalResult> results;
  int get passed => results.where((result) => result.passed).length;
  bool get allPassed => results.isNotEmpty && passed == results.length;

  Map<String, Object?> toJson() {
    final checks = <String, Map<String, int>>{};
    final tags = <String, Map<String, int>>{};
    final metrics = <String, num>{};
    for (final result in results) {
      for (final check in result.checks) {
        final counts =
            checks.putIfAbsent(check.name, () => {'total': 0, 'passed': 0});
        counts['total'] = counts['total']! + 1;
        if (check.passed) counts['passed'] = counts['passed']! + 1;
      }
      for (final tag in result.testCase.tags.toSet()) {
        final counts = tags.putIfAbsent(tag, () => {'total': 0, 'passed': 0});
        counts['total'] = counts['total']! + 1;
        if (result.passed) counts['passed'] = counts['passed']! + 1;
      }
      for (final metric in result.observation.metrics.entries) {
        metrics.update(metric.key, (value) => value + metric.value,
            ifAbsent: () => metric.value);
      }
    }
    final latencies =
        results.map((result) => result.elapsedMilliseconds).toList()..sort();
    int percentile(double quantile) => latencies.isEmpty
        ? 0
        : latencies[
            (latencies.length * quantile).ceil().clamp(1, latencies.length) -
                1];
    return {
      'schemaVersion': 1,
      'metadata': metadata,
      'summary': {
        'total': results.length,
        'passed': passed,
        'failed': results.length - passed,
        'passRate': results.isEmpty ? 0 : passed / results.length,
        'latencyP50Ms': percentile(.5),
        'latencyP95Ms': percentile(.95),
        'checks': checks,
        'tags': tags,
        'metricTotals': metrics,
      },
      'results': results.map((result) => result.toJson()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer('# Agent Eval\n\n');
    buffer.writeln('Metadata: `${jsonEncode(metadata)}`\n');
    buffer.writeln('Passed: $passed/${results.length}\n');
    final summary = toJson()['summary'] as Map;
    buffer.writeln('Case latency: p50 ${summary['latencyP50Ms']} ms, '
        'p95 ${summary['latencyP95Ms']} ms\n');
    buffer.writeln('Metric totals: `${jsonEncode(summary['metricTotals'])}`\n');
    buffer.writeln('| Check | Passed | Total |');
    buffer.writeln('| --- | ---: | ---: |');
    for (final entry in (summary['checks'] as Map).entries) {
      final counts = entry.value as Map;
      buffer.writeln('| ${_escape(entry.key as String)} | '
          '${counts['passed']} | ${counts['total']} |');
    }
    buffer.writeln();
    buffer.writeln('| Case | Result | Duration (ms) | Failed checks |');
    buffer.writeln('| --- | --- | ---: | --- |');
    for (final result in results) {
      final failed = result.checks
          .where((check) => !check.passed)
          .map((check) => check.name)
          .join(', ');
      buffer.writeln(
          '| ${_escape(result.testCase.id)} | ${result.passed ? 'PASS' : 'FAIL'} | '
          '${result.elapsedMilliseconds} | ${_escape(failed)} |');
    }
    return buffer.toString();
  }

  static String _escape(String value) =>
      value.replaceAll('|', r'\|').replaceAll('\n', ' ');
}

/// Subset matching for objects, exact length/order for lists, and explicit
/// absolute tolerance for numbers. Missing keys never match expected null.
List<String> agentEvalMismatches(
  Object? expected,
  Object? actual, {
  double numericTolerance = 0,
  String path = r'$',
}) {
  if (!numericTolerance.isFinite || numericTolerance < 0) {
    throw ArgumentError.value(numericTolerance, 'numericTolerance');
  }
  final failures = <String>[];
  if (expected is Map) {
    if (actual is! Map) return ['$path: expected object'];
    for (final entry in expected.entries) {
      final nextPath = '$path.${entry.key}';
      if (!actual.containsKey(entry.key)) {
        failures.add('$nextPath: missing');
      } else {
        failures.addAll(agentEvalMismatches(entry.value, actual[entry.key],
            numericTolerance: numericTolerance, path: nextPath));
      }
    }
  } else if (expected is List) {
    if (actual is! List || expected.length != actual.length)
      return ['$path: list length differs'];
    for (var index = 0; index < expected.length; index++) {
      failures.addAll(agentEvalMismatches(expected[index], actual[index],
          numericTolerance: numericTolerance, path: '$path[$index]'));
    }
  } else if (expected is num && actual is num) {
    if (!expected.isFinite ||
        !actual.isFinite ||
        (expected - actual).abs() > numericTolerance) {
      failures.add('$path: expected $expected, received $actual');
    }
  } else if (expected != actual) {
    failures.add(
        '$path: expected ${jsonEncode(expected)}, received ${jsonEncode(actual)}');
  }
  return failures;
}
