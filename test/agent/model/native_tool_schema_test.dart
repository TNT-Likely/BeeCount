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
        'get_transaction_summary',
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

    final summaryParameters =
        definitions['get_transaction_summary']!['parameters'] as Map;
    final summaryProperties = summaryParameters['properties'] as Map;
    expect(summaryProperties['types'], containsPair('type', 'array'));
    expect(
      (summaryProperties['types'] as Map)['items'],
      containsPair('enum', ['income', 'expense', 'transfer']),
    );
    expect(
      (summaryProperties['groupBy'] as Map)['enum'],
      containsAll(<String>[
        'none',
        'category',
        'tag',
        'account',
        'day',
        'week',
        'month',
        'year',
      ]),
    );
    expect(summaryProperties, contains('includeExcludedFromStats'));
    expect(summaryProperties, contains('groupLimit'));

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
