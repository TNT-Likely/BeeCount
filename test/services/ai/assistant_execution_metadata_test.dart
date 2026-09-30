import 'dart:convert';

import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/models/assistant_execution_metadata.dart';
import 'package:beecount/widgets/ai/agent_execution_timeline.dart';
import 'package:flutter_agent_ui/flutter_agent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('zh'));
  test('safe projection persists actual scope and totals without raw payloads',
      () {
    final projected = AgentExecutionTimeline.projectSteps(
        AppLocalizationsZh(),
        const [
          AgentExecutionStep(
              toolName: 'get_period_overview',
              arguments: {'period': 'current_month', 'apiKey': 'secret'},
              result: {
                'periodStart': '2026-09-01',
                'periodEnd': '2026-10-01',
                'income': 100,
                'expense': 25,
                'transactionCount': 2,
                'currency': 'CNY',
                'privateResult': 'secret'
              },
              status: AgentExecutionStepStatus.completed),
          AgentExecutionStep(
              toolName: 'record_transaction_from_text',
              arguments: {'sourceText': 'private source'},
              result: {
                'transactions': [
                  {'note': 'private note'}
                ]
              },
              status: AgentExecutionStepStatus.completed),
          AgentExecutionStep(
              toolName: 'secret_unknown_tool',
              arguments: {'content': 'private memory'},
              error: 'raw private stack',
              status: AgentExecutionStepStatus.failed),
        ],
        finished: true);
    final json = jsonEncode(AssistantExecutionMetadata.encode(projected));
    for (final private in [
      'secret',
      'private',
      'apiKey',
      'sourceText',
      'transactions',
      'periodStart',
      'get_period_overview'
    ]) {
      expect(json, isNot(contains(private)));
    }
    expect(json, contains('已返回 2 笔交易'));
    expect(json, contains('不含结束时间'));
    final restored = AssistantExecutionMetadata.decode(json);
    expect(restored, hasLength(3));
    expect(restored.first.title, '收支概览');
    expect(restored.last.status, AgentActivityStatus.failed);
  });

  test(
      'legacy or malformed snapshots are safe; one bad step does not drop all valid steps',
      () {
    for (final raw in [
      null,
      '',
      '{',
      '[]',
      '{}',
      '{"executionDisplayVersion":2,"executionDisplaySteps":[]}'
    ]) {
      expect(AssistantExecutionMetadata.decode(raw), isEmpty);
    }
    final json = jsonEncode({
      'executionDisplayVersion': 1,
      'executionDisplaySteps': [
        {},
        const AgentActivityStep(
                title: 'Read data', status: AgentActivityStatus.completed)
            .toJson(),
        {
          'title': 'invalid',
          'status': 'completed',
          'details': [3]
        },
      ]
    });
    expect(AssistantExecutionMetadata.decode(json), hasLength(1));
  });

  test(
      'finished authorization or running placeholders are not saved as active spinners',
      () {
    final projected = AgentExecutionTimeline.projectSteps(
        AppLocalizationsZh(),
        const [
          AgentExecutionStep(
              toolName: 'record_transaction_from_text',
              arguments: {},
              status: AgentExecutionStepStatus.waiting),
          AgentExecutionStep(
              toolName: 'query_transactions',
              arguments: {},
              status: AgentExecutionStepStatus.running),
        ],
        finished: true);
    expect(projected.every((step) => step.status == AgentActivityStatus.failed),
        isTrue);
  });

  test('snapshot counts and sizes stay bounded', () {
    final steps = List.filled(
        30,
        const AgentActivityStep(
            title: 'Read', status: AgentActivityStatus.completed));
    expect(
        AssistantExecutionMetadata.decode(
            jsonEncode(AssistantExecutionMetadata.encode(steps))),
        hasLength(24));
  });
}
