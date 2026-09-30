import 'dart:convert';
import 'dart:io';

import 'package:agentcore/agentcore.dart' as core;
import 'package:beecount/agent/model/native_tool_agent_model.dart' as app;
import 'package:beecount/ai/providers/ai_provider_config.dart';
import 'package:beecount/ai/providers/ai_provider_factory.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/assistant_eval.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final environment = Platform.environment;
  final live = environment['AI_EVAL_MODE'] == 'live';
  final filter = environment['AI_EVAL_FILTER'] ?? '';
  final output = environment['AI_EVAL_OUTPUT'] ??
      'build/ai-eval/${live ? 'live' : 'offline'}';

  test(
      'versioned assistant evaluation (${live ? 'live model' : 'offline tool regression'})',
      () async {
    final suite = jsonDecode(
        await File('test/ai_eval/fixtures/readonly_cases_v1.json')
            .readAsString()) as Map;
    expect(suite['schemaVersion'], 1);
    expect(suite['fixtureVersion'], 'ledger-v1');
    final allCases = (suite['cases'] as List)
        .map((raw) =>
            core.AgentEvalCase.fromJson(Map<String, Object?>.from(raw as Map)))
        .toList();
    expect(allCases.length, greaterThanOrEqualTo(50));
    expect(allCases.map((item) => item.id).toSet().length, allCases.length);
    for (final testCase in allCases) {
      final steps = testCase.input['steps'] as List;
      final turns = testCase.expected['turns'] as List;
      expect(steps, isNotEmpty, reason: testCase.id);
      expect(turns.length, steps.length, reason: testCase.id);
      for (final step in steps) {
        expect((step as Map)['prompt'], isNotEmpty, reason: testCase.id);
        expect(step['oracleCalls'], isNotEmpty, reason: testCase.id);
      }
      for (final turn in turns) {
        expect((turn as Map)['tools'], isNotEmpty, reason: testCase.id);
        expect(turn['answerPatterns'], isA<List>(), reason: testCase.id);
      }
    }
    final cases = allCases
        .where((item) =>
            filter.isEmpty ||
            item.id.contains(filter) ||
            item.tags.contains(filter))
        .toList();
    final baseUrl = environment['AI_EVAL_BASE_URL'];
    final apiKey = environment['AI_EVAL_API_KEY'];
    final model = environment['AI_EVAL_MODEL'];
    if (live &&
        [baseUrl, apiKey, model]
            .any((value) => value == null || value.trim().isEmpty)) {
      fail(
          'Live evaluation requires AI_EVAL_BASE_URL, AI_EVAL_API_KEY and AI_EVAL_MODEL');
    }
    final config = live
        ? AIServiceProviderConfig(
            id: 'eval',
            name: 'Eval provider',
            apiKey: apiKey!,
            baseUrl: baseUrl!,
            textModel: model!,
            createdAt: DateTime(2026, 9, 30),
          )
        : null;
    var httpRequests = 0;
    final client = !live
        ? null
        : Dio(BaseOptions(
            baseUrl: baseUrl!,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 45),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json'
            },
          ));
    client?.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      httpRequests++;
      handler.next(options);
    }));
    final executor = AssistantEvalExecutor(
      live: live,
      createLiveModel: !live
          ? null
          : () => app.NativeToolAgentModel(
                transport: app.OpenAiCompatibleNativeToolTransport(
                  toolStream: ({required messages, required tools, logTag}) {
                    return AIProviderFactory.chatWithToolsStreamForConfig(
                      config: config!,
                      messages: messages,
                      tools: tools,
                      logTag: logTag,
                      client: client,
                    );
                  },
                ),
              ),
    );
    // Logs contain only synthetic data, but can be voluminous. Errors are
    // reported through checks; the live credential is never put in a report.
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    late core.AgentEvalReport report;
    try {
      Future<core.AgentEvalReport> run() => core.AgentEvalRunner(
                  execute: executor.execute, evaluate: executor.evaluate)
              .run(
            cases: cases,
            metadata: {
              'suite': suite['id'],
              'fixtureVersion': suite['fixtureVersion'],
              'mode': live ? 'live' : 'offline',
              'clock': '2026-09-30T12:00:00',
              'timezone': Platform.environment['TZ'] ?? 'host-local',
              'model': live ? model : 'oracle-tools-no-language-evaluation',
              'sourceRevision': environment['AI_EVAL_REVISION'] ?? 'unknown',
              'sourceDirty': environment['AI_EVAL_DIRTY'] == 'true',
              'assertionVersion': 1,
            },
            onResult: (result) => stdout.writeln(
                '${result.passed ? 'PASS' : 'FAIL'} ${result.testCase.id} (${result.elapsedMilliseconds}ms)'),
          );
      // Widget-test binding blocks HTTP by default. Opt in only for explicit
      // live mode; ordinary test runs remain fully offline.
      report = live
          ? await HttpOverrides.runZoned(run,
              createHttpClient: _LiveHttpOverrides().createHttpClient)
          : await run();
    } finally {
      debugPrint = previousDebugPrint;
      client?.close(force: true);
    }
    final reportJson = report.toJson();
    reportJson['httpRequests'] = httpRequests;
    await File('$output.json').parent.create(recursive: true);
    await File('$output.json').writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(reportJson)}\n');
    await File('$output.md').writeAsString(report.toMarkdown());
    stdout.writeln(
        'Report: $output.json / $output.md; passed ${report.passed}/${report.results.length}');
    final failures = report.results
        .where((result) => !result.passed)
        .map((result) =>
            '${result.testCase.id}: ${result.checks.where((check) => !check.passed).map((check) => '${check.name}: ${check.detail ?? ''}').join('; ')}')
        .join('\n');
    expect(report.allPassed, isTrue, reason: failures);
  }, timeout: const Timeout(Duration(hours: 2)));
}

final class _LiveHttpOverrides extends HttpOverrides {}
