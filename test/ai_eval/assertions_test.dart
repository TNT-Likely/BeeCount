import 'dart:convert';
import 'dart:io';

import 'package:agentcore/agentcore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/assistant_eval.dart';

void main() {
  final testCase = AgentEvalCase(id: 'assertions', input: {}, expected: {
    'turns': [
      {
        'responseType': 'text',
        'tools': [
          {
            'name': 'get_period_overview',
            'result': {
              'expense': 1295,
              'currency': 'CNY',
              'periodStart': '2026-09-01T00:00:00.000',
            },
          }
        ],
        'answerPatterns': [r'1295'],
      }
    ],
  });

  AgentEvalObservation observed({
    Object expense = 1295,
    String currency = 'CNY',
    String start = '2026-09-01T00:00:00.000',
    String text = '支出 1295 元',
    bool hasTool = true,
    bool unchanged = true,
    int denied = 0,
  }) =>
      AgentEvalObservation(data: {
        'transactionsUnchanged': unchanged,
        'deniedCalls': denied,
        'selectionPassed': true,
        'turns': [
          {
            'responseType': 'text',
            'text': text,
            'calls': [
              if (hasTool)
                {
                  'name': 'get_period_overview',
                  'succeeded': true,
                  'result': {
                    'expense': expense,
                    'currency': currency,
                    'periodStart': start,
                  },
                }
            ],
          }
        ],
      });

  List<String> failures(AgentEvalObservation observation,
          {bool live = false}) =>
      AssistantEvalExecutor(live: live)
          .evaluate(testCase, observation)
          .where((check) => !check.passed)
          .map((check) => check.name)
          .toList();

  test('业务检查不会放过金额、币种、日期范围和工具缺失', () {
    expect(failures(observed()), isEmpty);
    expect(failures(observed(expense: 1296)), contains('numeric_and_scope'));
    expect(failures(observed(currency: 'USD')), contains('numeric_and_scope'));
    expect(failures(observed(start: '2026-08-01T00:00:00.000')),
        contains('numeric_and_scope'));
    expect(failures(observed(hasTool: false)), contains('required_tool'));
  });

  test('只读保护异常和拒绝调用必须失败', () {
    expect(failures(observed(unchanged: false)), contains('readonly'));
    expect(failures(observed(denied: 1)), contains('no_denied_calls'));
  });

  test('在线回答必须包含关键数字且不能吐出协议或实现异常', () {
    expect(failures(observed(), live: true), isEmpty);
    expect(
        failures(observed(text: '支出很多'), live: true), contains('answer_facts'));
    expect(failures(observed(text: 'DioException: 1295'), live: true),
        contains('clean_answer'));
  });

  test('追问断言必须检查完整问题，而非只有按钮标题', () {
    const prompt = '查询 2026-09-01 至 2026-10-01（不含结束时间）中「餐饮」的明细分类支出占比。';
    final original = (testCase.expected['turns'] as List).single as Map;
    final withFollowUp =
        AgentEvalCase(id: 'grounded-followups', input: {}, expected: {
      'turns': [
        {
          ...original,
          'requiredFollowUpPrompts': [prompt]
        }
      ],
    });
    final data = observed().data;
    final turn = (data['turns'] as List).single as Map;
    for (final candidate in [prompt, '细看餐饮', '查询本月餐饮']) {
      final observation = AgentEvalObservation(data: {
        ...data,
        'turns': [
          {
            ...turn,
            'followUps': [
              {'id': 'leaf', 'title': '细看餐饮', 'prompt': candidate}
            ]
          },
        ]
      });
      final check = const AssistantEvalExecutor(live: false)
          .evaluate(withFollowUp, observation)
          .singleWhere((check) => check.name == 'grounded_followups');
      expect(check.passed, candidate == prompt);
    }
  });

  test('负金额事实断言兼容货币格式，不把正金额或其他金额判为正确', () {
    final suite = jsonDecode(
        File('test/ai_eval/fixtures/readonly_cases_v1.json')
            .readAsStringSync()) as Map;
    final year = (suite['cases'] as List)
        .singleWhere((raw) => (raw as Map)['id'] == 'overview-year-3') as Map;
    final pattern =
        RegExp(year['expected']['turns'][0]['answerPatterns'][1] as String);
    expect(pattern.hasMatch('结余 -¥205.00'), isTrue);
    expect(pattern.hasMatch('结余 −205 元'), isTrue);
    expect(pattern.hasMatch('结余 ¥205.00'), isFalse);
    expect(pattern.hasMatch('结余 -¥2050.00'), isFalse);
  });
}
