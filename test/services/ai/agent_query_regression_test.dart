import 'dart:convert';
import 'dart:io';

import 'package:agentcore/agentcore.dart' as core;
import 'package:beecount/agent/permission/shared_preferences_agent_tool_permission_store.dart';
import 'package:beecount/services/ai/agent_app_facade.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ai_eval/support/ledger_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final suite = jsonDecode(File('test/ai_eval/fixtures/readonly_cases_v1.json')
      .readAsStringSync()) as Map;
  const failedIds = {
    'overview-refund-2',
    'breakdown-leaf-1',
    'breakdown-leaf-2',
    'breakdown-leaf-3',
    'followup-breakdown'
  };

  for (final testCase in (suite['cases'] as List)
      .cast<Map>()
      .where((item) => failedIds.contains(item['id']))) {
    test('回放原错误工具调用并纠正：${testCase['id']}', () async {
      final fixture = await LedgerEvalFixture.create();
      addTearDown(fixture.close);
      final countBefore = await fixture.transactionCount();
      final input = testCase['input'] as Map;
      final steps = input['steps'] as List;
      final history = <Map<String, Object?>>[];
      for (final (index, raw) in steps.indexed) {
        final step = raw as Map;
        final oracle = (step['oracleCalls'] as List).single as Map;
        final correct = core.AgentToolCall(
            id: 'correct-$index',
            name: oracle['name'] as String,
            arguments: Map<String, Object?>.from(oracle['arguments'] as Map));
        final shouldCorrect = steps.length == 1 || index == 1;
        final wrong = correct.name == 'get_period_overview'
            ? core.AgentToolCall(
                id: 'wrong-$index',
                name: 'query_transactions',
                arguments: {
                    'start': correct.arguments['start'],
                    'end': correct.arguments['end']
                  })
            : core.AgentToolCall(
                id: 'wrong-$index',
                name: correct.name,
                arguments: {...correct.arguments}..remove('categoryLevel'));
        final model = _ReplayModel([
          if (shouldCorrect) core.AgentTurn.toolCalls([wrong]),
          core.AgentTurn.toolCalls([correct]),
          const core.AgentTurn.finalText('基于正确查询结果回答'),
        ]);
        final facade = AgentAppFacade(
          memoryRepository: fixture.memory,
          toolGateway: fixture.gateway,
          permissionStore: SharedPreferencesAgentToolPermissionStore(
              getPreferences: SharedPreferences.getInstance),
          model: model,
          now: () => fixture.now,
          runIdFactory: () => '${testCase['id']}-$index',
        );
        final events = await facade.processMessageEvents(
          message: step['prompt'] as String,
          ledgerId: fixture.ledgers[input['ledger']]!,
          context: {'recentMessages': history},
        ).toList();
        final response = (events.last as AgentRunCompletedEvent).result;
        expect(response.type, 'text');
        final executed = events.whereType<AgentToolCompletedEvent>().single;
        expect(executed.toolName, correct.name);
        expect(executed.succeeded, isTrue);
        final expected = (((testCase['expected'] as Map)['turns']
            as List)[index] as Map)['tools'] as List;
        expect(
            core.agentEvalMismatches(
                (expected.single as Map)['result'], executed.result,
                numericTolerance: 1e-9),
            isEmpty);
        if (shouldCorrect) {
          expect(model.requests[1].toolData.single['id'], wrong.id);
          expect(model.requests[1].toolData.single['data'],
              containsPair('retryable', true));
        }
        history.addAll([
          {'role': 'user', 'content': step['prompt']},
          {'role': 'assistant', 'content': response.text},
        ]);
      }
      final audits =
          await fixture.database.select(fixture.database.agentToolCalls).get();
      expect(audits.where((item) => item.status == 'rejected'), hasLength(1));
      expect(audits.where((item) => item.status == 'denied'), isEmpty);
      expect(await fixture.transactionCount(), countBefore);
    });
  }

  test('其他概览工具不能掩盖尚未纠正的子分类查询', () async {
    final fixture = await LedgerEvalFixture.create();
    addTearDown(fixture.close);
    final response = await AgentAppFacade(
      memoryRepository: fixture.memory,
      toolGateway: fixture.gateway,
      permissionStore: SharedPreferencesAgentToolPermissionStore(
          getPreferences: SharedPreferences.getInstance),
      now: () => fixture.now,
      model: _ReplayModel([
        core.AgentTurn.toolCalls([
          core.AgentToolCall(
              id: 'overview',
              name: 'get_period_overview',
              arguments: {'period': 'current_month'}),
          core.AgentToolCall(
              id: 'wrong-level',
              name: 'get_category_breakdown',
              arguments: {
                'period': 'current_month',
                'categoryNames': ['餐饮']
              }),
        ]),
        const core.AgentTurn.finalText('没有子分类'),
      ]),
    ).processMessage(
        message: '本月餐饮按明细分类排行', ledgerId: fixture.ledgers['main']!);
    expect(response.type, 'error');
    expect(response.text, isNot(contains('没有子分类')));
    expect(response.response.action, isNull);
  });

  test('单月按月追问允许使用分类查询，不因工具名不同拦截结果', () async {
    final fixture = await LedgerEvalFixture.create();
    addTearDown(fixture.close);
    final events = await AgentAppFacade(
      memoryRepository: fixture.memory,
      toolGateway: fixture.gateway,
      permissionStore: SharedPreferencesAgentToolPermissionStore(
          getPreferences: SharedPreferences.getInstance),
      now: () => fixture.now,
      runIdFactory: () => 'single-month-category-followup',
      model: _ReplayModel([
        core.AgentTurn.toolCalls([
          core.AgentToolCall(
            id: 'category-query',
            name: 'get_category_breakdown',
            arguments: {
              'period': 'custom',
              'start': '2026-09-01T00:00:00.000',
              'end': '2026-10-01T00:00:00.000',
              'categoryLevel': 'top',
            },
          ),
        ]),
        const core.AgentTurn.finalText('9月支出总额1295，住房1000，餐饮120。'),
      ]),
    )
        .processMessageEvents(
          message: '按月列出 2026-09-01T00:00:00.000 至 '
              '2026-10-01T00:00:00.000（不含结束时间） '
              '中全部支出分类的支出，不做同比或环比比较。',
          ledgerId: fixture.ledgers['main']!,
          readOnly: true,
        )
        .toList();
    final response = (events.last as AgentRunCompletedEvent).result;
    expect(response.type, 'text');
    expect(response.text, '9月支出总额1295，住房1000，餐饮120。');
    final tool = events.whereType<AgentToolCompletedEvent>().single;
    expect(tool.toolName, 'get_category_breakdown');
    expect(tool.succeeded, isTrue);
    expect(tool.result!['totalExpense'], 1295);
    final runs =
        await fixture.database.select(fixture.database.agentRuns).get();
    expect(runs.single.status, 'completed');
    expect(runs.single.errorMessage, isNull);
  });

  test('纠正失败不虚构没有子分类，也不误报模型不支持工具', () async {
    final fixture = await LedgerEvalFixture.create();
    addTearDown(fixture.close);
    final model = _ReplayModel([
      for (final id in ['bad-1', 'bad-2'])
        core.AgentTurn.toolCalls([
          core.AgentToolCall(
              id: id,
              name: 'get_category_breakdown',
              arguments: {
                'period': 'current_month',
                'categoryNames': ['餐饮']
              })
        ]),
      const core.AgentTurn.finalText('没有子分类，请切换模型'),
    ]);
    final response = await AgentAppFacade(
      memoryRepository: fixture.memory,
      toolGateway: fixture.gateway,
      permissionStore: SharedPreferencesAgentToolPermissionStore(
          getPreferences: SharedPreferences.getInstance),
      model: model,
      now: () => fixture.now,
    ).processMessage(
        message: '本月餐饮按明细分类排行', ledgerId: fixture.ledgers['main']!);
    expect(response.type, 'error');
    expect(response.text, contains('查询参数未能纠正'));
    expect(response.text, isNot(contains('没有子分类')));
    expect(response.response.action, isNull);
    expect(model.requests.last.allowToolCalls, isFalse);
  });

  test('英文参数纠正失败保留独立错误，不再报未调用指定工具', () async {
    final fixture = await LedgerEvalFixture.create();
    addTearDown(fixture.close);
    final response = await AgentAppFacade(
      memoryRepository: fixture.memory,
      toolGateway: fixture.gateway,
      permissionStore: SharedPreferencesAgentToolPermissionStore(
          getPreferences: SharedPreferences.getInstance),
      now: () => fixture.now,
      runIdFactory: () => 'invalid-query-parameters',
      model: _ReplayModel([
        core.AgentTurn.toolCalls([
          core.AgentToolCall(
            id: 'wrong-leaf',
            name: 'get_category_breakdown',
            arguments: {'period': 'current_month', 'categoryLevel': 'top'},
          ),
        ]),
        const core.AgentTurn.finalText('No subcategories.'),
      ]),
    ).processMessage(
      message: 'List spending by subcategory this month.',
      ledgerId: fixture.ledgers['main']!,
      l10n: AppLocalizationsEn(),
    );
    expect(response.type, 'error');
    expect(response.text, AppLocalizationsEn().agentQueryValidationFailed);
    expect(response.response.action, isNull);
    final runs =
        await fixture.database.select(fixture.database.agentRuns).get();
    expect(runs.single.errorMessage, 'agent_query_validation_failed');
  });
}

final class _ReplayModel implements core.AgentModel {
  _ReplayModel(this.turns);
  final List<core.AgentTurn> turns;
  final List<core.AgentRequest> requests = [];
  @override
  Future<core.AgentTurn> nextTurn(core.AgentRequest request) async {
    requests.add(request);
    return turns.removeAt(0);
  }
}
