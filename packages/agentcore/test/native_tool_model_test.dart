import 'package:agentcore/agentcore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const definitions = [
    AgentNativeToolDefinition(
      name: 'read_report',
      description: 'Read a report',
      parameters: {'type': 'object'},
    ),
  ];

  test('native model uses injected prompt and scope rules', () async {
    final transport = _FakeTransport([
      AgentNativeModelResponse.toolCalls([
        AgentNativeToolCall(
          id: 'call-1',
          name: 'read_report',
          arguments: {'ledgerId': 1, 'range': 'month'},
        ),
      ]),
      const AgentNativeModelResponse.finalText('done'),
    ]);
    final model = NativeToolAgentModel(
      transport: transport,
      promptBuilder: (request) => 'initial:${request.text}',
      ledgerScopedToolNames: const {'read_report'},
    );
    final request = AgentRequest(
      text: 'show this month',
      scope: const AgentScope(id: 'run-1', ledgerId: 1),
    );

    final first = await model.nextTurn(request);
    final second = await model.nextTurn(
      request.withToolData([
        {
          'id': 'call-1',
          'name': 'read_report',
          'data': {'total': 8},
        },
      ]),
    );

    expect((first as AgentToolCallsTurn).calls.single.arguments, {
      'range': 'month',
    });
    expect((second as AgentFinalTextTurn).text, 'done');
    expect(transport.requests.first.userPrompt, 'initial:show this month');
    expect(transport.requests.last.toolResults.single.content, '{"total":8}');
  });

  test('openai-compatible transport aggregates SSE tool fragments', () async {
    final transport = OpenAiCompatibleNativeToolTransport(
      systemPrompt: 'system',
      toolDefinitions: definitions,
      toolStream: ({required messages, required tools, logTag}) =>
          Stream<Map<String, dynamic>>.fromIterable([
        {
          'choices': [
            {
              'delta': {
                'tool_calls': [
                  {
                    'index': 0,
                    'id': 'call-1',
                    'function': {
                      'name': 'read_report',
                      'arguments': '{"range":"mo',
                    },
                  },
                ],
              },
            },
          ],
        },
        {
          'choices': [
            {
              'delta': {
                'tool_calls': [
                  {
                    'index': 0,
                    'function': {'arguments': 'nth"}'},
                  },
                ],
              },
            },
          ],
        },
      ]),
    );

    final response = await transport.complete(
      AgentNativeToolRequest(
        runId: 'run-1',
        userPrompt: 'show',
        toolResults: const [],
      ),
    );
    final call = (response as AgentNativeToolCallsResponse).calls.single;
    expect(call.name, 'read_report');
    expect(call.arguments, {'range': 'month'});
  });
}

final class _FakeTransport implements AgentNativeToolTransport {
  _FakeTransport(this.responses);

  final List<AgentNativeModelResponse> responses;
  final requests = <AgentNativeToolRequest>[];

  @override
  Future<AgentNativeModelResponse> complete(
    AgentNativeToolRequest request, {
    AgentNativeEventSink? onEvent,
  }) async {
    requests.add(request);
    return responses.removeAt(0);
  }
}
