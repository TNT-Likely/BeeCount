import 'dart:async';

import 'package:agentcore/agentcore.dart';
import 'package:test/test.dart';

void main() {
  const definitions = [
    AgentNativeToolDefinition(
      name: 'read_report',
      description: 'Read a report',
      parameters: {'type': 'object'},
    ),
  ];

  test(
      'provider phases are deduplicated and reasoning stays separate from content',
      () async {
    final events = <AgentNativeStreamEvent>[];
    final transport = OpenAiCompatibleNativeToolTransport(
      systemPrompt: 'system',
      toolDefinitions: definitions,
      toolStream: ({required messages, required tools, logTag}) =>
          Stream<Map<String, dynamic>>.fromIterable([
        for (final delta in [
          {'reasoning_content': 'private reasoning one'},
          {'reasoning_content': 'private reasoning two'},
          {'reasoning': 'private reasoning three'},
          {'content': 'answer'},
          {'content': ' complete'},
          {'reasoning_content': 'late private reasoning'},
        ])
          {
            'choices': [
              {'delta': delta}
            ]
          },
      ]),
    );
    final response = await transport.complete(
      AgentNativeToolRequest(
          runId: 'phases', userPrompt: 'question', toolResults: []),
      onEvent: events.add,
    );
    expect(
        events
            .whereType<AgentNativeModelActivity>()
            .map((event) => event.phase),
        [
          AgentNativeModelPhase.awaitingResponse,
          AgentNativeModelPhase.thinking,
          AgentNativeModelPhase.generating
        ]);
    expect(events.whereType<AgentNativeTextDelta>().map((event) => event.text),
        ['answer', ' complete']);
    expect(events.whereType<AgentNativeReasoningDelta>().map((e) => e.text), [
      'private reasoning one',
      'private reasoning two',
      'private reasoning three',
      'late private reasoning'
    ]);
    expect((response as AgentNativeFinalTextResponse).text, 'answer complete');
  });

  test('ordinary models do not fabricate a thinking phase', () async {
    final events = <AgentNativeStreamEvent>[];
    final transport = OpenAiCompatibleNativeToolTransport(
      systemPrompt: 'system',
      toolDefinitions: definitions,
      toolStream: ({required messages, required tools, logTag}) =>
          Stream<Map<String, dynamic>>.fromIterable([
        for (final delta in [
          {'reasoning_content': '', 'reasoning': ' '},
          {
            'reasoning_content': {'text': 'unsupported shape'}
          },
          {'content': 'answer'},
        ])
          {
            'choices': [
              {'delta': delta}
            ]
          },
      ]),
    );
    await transport.complete(
      AgentNativeToolRequest(
          runId: 'ordinary', userPrompt: 'question', toolResults: []),
      onEvent: events.add,
    );
    expect(
        events
            .whereType<AgentNativeModelActivity>()
            .map((event) => event.phase),
        [
          AgentNativeModelPhase.awaitingResponse,
          AgentNativeModelPhase.generating
        ]);
  });

  test('buffered finalization still reports real model phases', () async {
    final events = <AgentNativeStreamEvent>[];
    final transport = OpenAiCompatibleNativeToolTransport(
      systemPrompt: 'system',
      toolDefinitions: definitions,
      toolStream: ({required messages, required tools, logTag}) =>
          Stream<Map<String, dynamic>>.fromIterable([
        {
          'choices': [
            {
              'delta': {'reasoning_content': 'private reasoning'}
            }
          ]
        },
        {
          'choices': [
            {
              'delta': {'content': 'answer'}
            }
          ]
        },
      ]),
    );
    final response = await transport.complete(
      AgentNativeToolRequest(
          runId: 'buffered-phases',
          userPrompt: 'question',
          toolResults: [],
          allowToolCalls: false),
      onEvent: events.add,
    );
    expect(
        events
            .whereType<AgentNativeModelActivity>()
            .map((event) => event.phase),
        [
          AgentNativeModelPhase.awaitingResponse,
          AgentNativeModelPhase.thinking,
          AgentNativeModelPhase.generating
        ]);
    expect(events.whereType<AgentNativeTextDelta>(), isEmpty);
    expect((response as AgentNativeFinalTextResponse).text, 'answer');
  });

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

  test('native model preserves the finalization flag with streaming context',
      () async {
    final transport = _FakeTransport([
      const AgentNativeModelResponse.finalText('done'),
    ]);
    final model = NativeToolAgentModel(
      transport: transport,
      promptBuilder: (request) => request.text,
    );
    final request = AgentRequest(
      text: 'finish',
      scope: const AgentScope(id: 'run-finalization'),
      allowToolCalls: false,
    ).withStreamingTextDeltas((_) {});

    await model.nextTurn(request);

    expect(transport.requests.single.allowToolCalls, isFalse);
  });

  test('native model forwards a request-scoped native tool catalog', () async {
    final transport = _FakeTransport([
      const AgentNativeModelResponse.finalText('done'),
    ]);
    final model = NativeToolAgentModel(
      transport: transport,
      promptBuilder: (request) => request.text,
    );

    await model.nextTurn(AgentRequest(
      text: 'budget',
      scope: const AgentScope(id: 'run-selected-tools'),
      availableToolNames: const {'read_report'},
    ));

    expect(transport.requests.single.availableToolNames, {'read_report'});
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

  test('openai-compatible transport sends only request-selected schemas',
      () async {
    List<Map<String, dynamic>>? sentTools;
    final transport = OpenAiCompatibleNativeToolTransport(
      systemPrompt: 'system',
      toolDefinitions: [
        ...definitions,
        const AgentNativeToolDefinition(
          name: 'hidden',
          description: 'Hidden tool',
          parameters: {'type': 'object'},
        ),
      ],
      toolStream: ({required messages, required tools, logTag}) {
        sentTools = tools;
        return Stream.value({
          'choices': [
            {
              'delta': {'content': 'done'},
            },
          ],
        });
      },
    );

    await transport.complete(AgentNativeToolRequest(
      runId: 'run-selected-schemas',
      userPrompt: 'show',
      toolResults: const [],
      availableToolNames: const {'read_report'},
    ));

    expect(sentTools, hasLength(1));
    expect((sentTools!.single['function'] as Map)['name'], 'read_report');
  });

  test('finalization request sends no tool definitions to the provider',
      () async {
    List<Map<String, dynamic>>? sentTools;
    final transport = OpenAiCompatibleNativeToolTransport(
      systemPrompt: 'system',
      toolDefinitions: definitions,
      toolStream: ({required messages, required tools, logTag}) {
        sentTools = tools;
        return Stream<Map<String, dynamic>>.value({
          'choices': [
            {
              'delta': {'content': 'done'},
              'finish_reason': 'stop',
            },
          ],
        });
      },
    );

    await transport.complete(
      AgentNativeToolRequest(
        runId: 'finalization',
        userPrompt: 'show',
        toolResults: const [],
        allowToolCalls: false,
      ),
    );

    expect(sentTools, isEmpty);
  });

  test('finalization request tells text-only providers not to emit tool markup',
      () async {
    List<Map<String, dynamic>>? sentMessages;
    final transport = OpenAiCompatibleNativeToolTransport(
      systemPrompt: 'system',
      toolDefinitions: definitions,
      toolStream: ({required messages, required tools, logTag}) {
        sentMessages = messages;
        return Stream<Map<String, dynamic>>.value({
          'choices': [
            {
              'delta': {'content': 'done'},
              'finish_reason': 'stop',
            },
          ],
        });
      },
    );

    await transport.complete(
      AgentNativeToolRequest(
        runId: 'finalization-instruction',
        userPrompt: 'show',
        toolResults: const [],
        allowToolCalls: false,
      ),
    );

    expect(sentMessages, isNotNull);
    expect(sentMessages!.last['role'], 'user');
    expect(
      sentMessages!.last['content'],
      contains('不得输出任何工具调用标记'),
    );
  });

  test('finalization retries and hides a gateway DSML response', () async {
    var invocations = 0;
    final streamedText = <String>[];
    final transport = OpenAiCompatibleNativeToolTransport(
      systemPrompt: 'system',
      toolDefinitions: definitions,
      toolStream: ({required messages, required tools, logTag}) {
        invocations += 1;
        final text = invocations == 1
            ? '<｜DSML｜tool_calls><｜DSML｜invoke name="read_report"></｜DSML｜invoke></｜DSML｜tool_calls>'
            : '根据结果，查询已完成。';
        return Stream<Map<String, dynamic>>.value({
          'choices': [
            {
              'delta': {'content': text},
              'finish_reason': 'stop',
            },
          ],
        });
      },
    );

    final response = await transport.complete(
      AgentNativeToolRequest(
        runId: 'finalization-dsml',
        userPrompt: 'show',
        toolResults: const [],
        allowToolCalls: false,
      ),
      onEvent: (event) {
        if (event case AgentNativeTextDelta(:final text)) {
          streamedText.add(text);
        }
      },
    );

    expect(invocations, 2);
    expect((response as AgentNativeFinalTextResponse).text, '根据结果，查询已完成。');
    expect(streamedText, isEmpty);
  });

  test('disposing a run drops its unfinished native tool session', () async {
    var invocation = 0;
    final sentMessages = <List<Map<String, dynamic>>>[];
    final transport = OpenAiCompatibleNativeToolTransport(
      systemPrompt: 'system',
      toolDefinitions: definitions,
      toolStream: ({required messages, required tools, logTag}) {
        sentMessages.add(messages.map(Map<String, dynamic>.from).toList());
        invocation += 1;
        return Stream<Map<String, dynamic>>.value(
          invocation == 1
              ? {
                  'choices': [
                    {
                      'delta': {
                        'tool_calls': [
                          {
                            'index': 0,
                            'id': 'unfinished-call',
                            'function': {
                              'name': 'read_report',
                              'arguments': '{}',
                            },
                          },
                        ],
                      },
                      'finish_reason': 'tool_calls',
                    },
                  ],
                }
              : {
                  'choices': [
                    {
                      'delta': {'content': 'fresh run'},
                      'finish_reason': 'stop',
                    },
                  ],
                },
        );
      },
    );
    final request = AgentNativeToolRequest(
      runId: 'dispose-run',
      userPrompt: 'first request',
      toolResults: const [],
    );

    await transport.complete(request);
    (transport as AgentNativeToolRunFinalizer).disposeRun('dispose-run');
    await transport.complete(
      AgentNativeToolRequest(
        runId: 'dispose-run',
        userPrompt: 'second request',
        toolResults: const [],
      ),
    );

    expect(sentMessages.last, [
      {'role': 'system', 'content': 'system'},
      {'role': 'user', 'content': 'second request'},
    ]);
  });

  test('disposing a run cancels its active native tool stream', () async {
    final controller = StreamController<Map<String, dynamic>>();
    final transport = OpenAiCompatibleNativeToolTransport(
      systemPrompt: 'system',
      toolDefinitions: definitions,
      toolStream: ({required messages, required tools, logTag}) =>
          controller.stream,
    );

    final response = transport.complete(
      AgentNativeToolRequest(
        runId: 'cancel-active-stream',
        userPrompt: 'show',
        toolResults: const [],
      ),
    );
    await Future<void>.delayed(Duration.zero);

    (transport as AgentNativeToolRunFinalizer)
        .disposeRun('cancel-active-stream');

    await expectLater(
      response.timeout(const Duration(milliseconds: 200)),
      throwsA(isA<AgentNativeToolRunCancelledException>()),
    );
    expect(controller.hasListener, isFalse);
    await controller.close();
  });

  test(
      'openai-compatible transport completes on a final chunk before stream close',
      () async {
    final controller = StreamController<Map<String, dynamic>>();
    final transport = OpenAiCompatibleNativeToolTransport(
      systemPrompt: 'system',
      toolDefinitions: definitions,
      toolStream: ({required messages, required tools, logTag}) =>
          controller.stream,
    );

    final responseFuture = transport.complete(
      AgentNativeToolRequest(
        runId: 'run-final-chunk',
        userPrompt: 'show',
        toolResults: const [],
      ),
    );
    controller.add({
      'choices': [
        {
          'delta': {'content': 'done'},
          'finish_reason': 'stop',
        },
      ],
    });

    try {
      final response = await responseFuture.timeout(
        const Duration(milliseconds: 200),
      );
      expect(response, isA<AgentNativeFinalTextResponse>());
      expect((response as AgentNativeFinalTextResponse).text, 'done');
    } finally {
      await controller.close();
    }
  });

  test('logs the tool catalog sent to the provider', () async {
    final events = <String, Map<String, Object?>>{};
    final transport = OpenAiCompatibleNativeToolTransport(
      systemPrompt: 'system',
      toolDefinitions: definitions,
      logSink: (event, data) => events[event] = data,
      toolStream: ({required messages, required tools, logTag}) =>
          Stream<Map<String, dynamic>>.value({
        'choices': [
          {
            'delta': {'content': 'done'},
          },
        ],
      }),
    );

    await transport.complete(
      AgentNativeToolRequest(
        runId: 'catalog-log',
        userPrompt: 'show',
        toolResults: const [],
      ),
    );

    final started = events['turnStarted'];
    expect(started, isNotNull);
    expect(started!['toolDefinitions'], [
      {
        'name': 'read_report',
        'description': 'Read a report',
        'parameters': {'type': 'object'},
      },
    ]);
  });

  test('native model resets a run after an unexpected transport error',
      () async {
    final transport = _FailOnceTransport();
    var promptCalls = 0;
    final model = NativeToolAgentModel(
      transport: transport,
      promptBuilder: (request) {
        promptCalls += 1;
        return request.text;
      },
    );
    final request = AgentRequest(
      text: 'try again',
      scope: const AgentScope(id: 'run-retry'),
    );

    await expectLater(model.nextTurn(request), throwsA(isA<FormatException>()));
    await model.nextTurn(request);

    expect(promptCalls, 2);
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

final class _FailOnceTransport implements AgentNativeToolTransport {
  var _failed = false;

  @override
  Future<AgentNativeModelResponse> complete(
    AgentNativeToolRequest request, {
    AgentNativeEventSink? onEvent,
  }) {
    if (!_failed) {
      _failed = true;
      return Future<AgentNativeModelResponse>.error(
        const FormatException('temporary'),
      );
    }
    return Future<AgentNativeModelResponse>.value(
      const AgentNativeModelResponse.finalText('retried'),
    );
  }
}
