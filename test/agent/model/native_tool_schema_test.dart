import 'package:beecount/agent/model/native_tool_agent_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test(
      'sends every local tool with a complete description and parameter schema',
      () async {
    List<Map<String, dynamic>>? sentTools;
    final transport = OpenAiCompatibleNativeToolTransport(
      toolStream: ({required messages, required tools, logTag}) {
        sentTools = tools;
        return Stream<Map<String, dynamic>>.value({
          'choices': [
            {
              'delta': {'content': 'ok'},
            },
          ],
        });
      },
    );

    await transport.complete(
      AgentNativeToolRequest(
        runId: 'schema-test',
        userPrompt: '检查工具定义',
        toolResults: [],
      ),
    );

    expect(sentTools, isNotNull);
    final definitions = <String, Map<String, dynamic>>{
      for (final raw in sentTools!)
        (raw['function'] as Map)['name'] as String:
            Map<String, dynamic>.from(raw['function'] as Map),
    };

    expect(
      definitions.keys,
      containsAll(<String>[
        'query_transactions',
        'get_period_overview',
        'get_spending_trend',
        'get_category_breakdown',
        'get_budget_status',
        'get_recurring_transactions',
        'record_transaction_from_text',
        'save_explicit_memory',
        'forget_memory',
      ]),
    );
    expect(definitions, isNot(contains('get_income_expense_summary')));
    expect(definitions, isNot(contains('get_category_spending')));
    expect(definitions, isNot(contains('get_spending_summary')));
    for (final definition in definitions.values) {
      expect(definition['description'], isA<String>());
      expect((definition['description'] as String).trim(), isNotEmpty);
      expect(definition['parameters'], isA<Map>());
    }

    final overviewParameters =
        definitions['get_period_overview']!['parameters'] as Map;
    final overviewProperties = overviewParameters['properties'] as Map;
    expect(
      (overviewProperties['period'] as Map)['enum'],
      containsAll(<String>[
        'current_month',
        'previous_month',
        'current_year',
        'last_12_months',
        'custom',
      ]),
    );
    final trendParameters =
        definitions['get_spending_trend']!['parameters'] as Map;
    final trendProperties = trendParameters['properties'] as Map;
    expect(
      (trendProperties['interval'] as Map)['enum'],
      ['day', 'week', 'month', 'year'],
    );
    expect(trendProperties, contains('categoryNames'));
    expect(trendProperties, contains('comparison'));
    final breakdownParameters =
        definitions['get_category_breakdown']!['parameters'] as Map;
    expect(
      (breakdownParameters['properties'] as Map),
      contains('categoryLevel'),
    );
    expect(
      definitions['query_transactions']!['description'],
      contains('最多返回 20 条'),
    );
    expect(
      definitions['get_spending_trend']!['description'],
      contains('无交易月份补零'),
    );

    final recordParameters =
        definitions['record_transaction_from_text']!['parameters'] as Map;
    expect(
      (recordParameters['properties'] as Map)['sourceText'],
      containsPair('description', '原始交易文本，必须逐字等于用户当前消息。'),
    );
    expect(recordParameters['required'], contains('sourceText'));

    final memoryParameters =
        definitions['save_explicit_memory']!['parameters'] as Map;
    expect(memoryParameters['required'], contains('content'));
    expect(
      (memoryParameters['properties'] as Map)['content'],
      containsPair('description', '用户明确要求长期记住的内容。'),
    );

    final forgetParameters = definitions['forget_memory']!['parameters'] as Map;
    expect(forgetParameters['required'], contains('memoryId'));
    expect(
      (forgetParameters['properties'] as Map)['memoryId'],
      containsPair('description', '要删除的记忆 ID。'),
    );
  });
}
