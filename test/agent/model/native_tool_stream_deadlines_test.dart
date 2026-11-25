import 'dart:async';

import 'package:agentcore/agentcore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<Map<String, dynamic>> provider;
  late NativeToolAgentModel model;
  late AgentRequest request;
  late List<AgentNativeStreamEvent> events;
  late List<String> prompts;

  setUp(() {
    // A synchronous stream lets the widget binding's simulated time advance
    // only when the test pumps it. No network or wall-clock delays are used.
    provider = StreamController<Map<String, dynamic>>(sync: true);
    events = [];
    prompts = [];
    model = NativeToolAgentModel(
      transport: OpenAiCompatibleNativeToolTransport(
        systemPrompt: 'system',
        toolDefinitions: const [],
        toolStream: ({required messages, required tools, logTag}) {
          prompts.add(messages[1]['content'] as String);
          return provider.stream;
        },
      ),
      promptBuilder: (r) => 'initial:${r.text}',
    );
    request = AgentRequest(text: 'first', scope: const AgentScope(id: 'run'))
        .withStreamingTextDeltas(events.add);
  });

  tearDown(() {
    unawaited(provider.close());
  });

  void send(Map<String, Object?> delta, {String? finish}) {
    provider.add({
      'choices': [
        {'delta': delta, if (finish != null) 'finish_reason': finish}
      ],
    });
  }

  testWidgets('repeated private reasoning and tool fragments sustain a turn',
      (tester) async {
    final response = model.nextTurn(request);
    await tester.pump(const Duration(seconds: 30));
    send({'reasoning_content': 'private first fragment'});
    await tester.pump(const Duration(seconds: 30));
    send({'reasoning_content': 'private second fragment'});
    await tester.pump(const Duration(seconds: 30));
    send({
      'tool_calls': [
        {
          'index': 0,
          'id': 'bill-search',
          'function': {'name': 'find', 'arguments': '{"value":'}
        }
      ]
    });
    await tester.pump(const Duration(seconds: 25));
    send({
      'tool_calls': [
        {
          'index': 0,
          'function': {'arguments': '42}'}
        }
      ]
    }, finish: 'tool_calls');
    await tester.pump();

    expect((await response as AgentToolCallsTurn).calls.single.arguments,
        {'value': 42});
    expect(events.whereType<AgentNativeTextDelta>(), isEmpty);
    expect(events.whereType<AgentNativeModelActivity>().map((e) => e.phase), [
      AgentNativeModelPhase.awaitingResponse,
      AgentNativeModelPhase.thinking,
    ]);
    expect(provider.hasListener, isFalse);
  });

  testWidgets('buffered final text can make progress with no UI deltas',
      (tester) async {
    final response = model.nextTurn(request.withoutToolCalls());
    for (final text in ['one', ' two', ' three']) {
      await tester.pump(const Duration(seconds: 35));
      send({'content': text});
    }
    send({}, finish: 'stop');
    await tester.pump();
    expect((await response as AgentFinalTextTurn).text, 'one two three');
    expect(events.whereType<AgentNativeTextDelta>(), isEmpty);
  });

  testWidgets('heartbeat, role and empty deltas cannot prolong the idle limit',
      (tester) async {
    final timedOut = expectLater(model.nextTurn(request),
        throwsA(isA<AgentNativeToolTimeoutException>()));
    await tester.pump(const Duration(seconds: 44));
    provider.add({'choices': [], 'usage': <String, int>{}});
    send({
      'role': 'assistant',
      'content': ' ',
      'reasoning_content': '',
      'tool_calls': []
    });
    await tester.pump(const Duration(seconds: 1));
    await timedOut;
    expect(provider.hasListener, isFalse);
  });

  testWidgets(
      'the absolute deadline applies while valid fragments keep arriving',
      (tester) async {
    final timedOut = expectLater(model.nextTurn(request),
        throwsA(isA<AgentNativeToolTimeoutException>()));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 35));
      send({'reasoning': 'private fragment'});
    }
    await tester.pump(const Duration(seconds: 14));
    expect(provider.hasListener, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await timedOut;
    expect(provider.hasListener, isFalse);
    expect(events.whereType<AgentNativeTextDelta>(), isEmpty);
  });

  testWidgets('cancelled streams can be immediately retried with the same ID',
      (tester) async {
    final oldProvider = provider;
    final cancelled = expectLater(model.nextTurn(request),
        throwsA(isA<AgentNativeToolRunCancelledException>()));
    send({'reasoning': 'private'});
    model.disposeRun('run');
    expect(oldProvider.hasListener, isFalse);

    provider = StreamController<Map<String, dynamic>>(sync: true);
    final retry = model.nextTurn(
        AgentRequest(text: 'retry', scope: const AgentScope(id: 'run')));
    await tester.pump();
    await cancelled;
    send({'content': 'retried'}, finish: 'stop');
    await tester.pump();
    expect((await retry as AgentFinalTextTurn).text, 'retried');
    expect(prompts, ['initial:first', 'initial:retry']);
    expect(provider.hasListener, isFalse);
    unawaited(oldProvider.close());
  });
}
