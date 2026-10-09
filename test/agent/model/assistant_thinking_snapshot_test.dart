import 'package:agentcore/agentcore.dart' as core;
import 'package:beecount/ai/providers/ai_provider_config.dart';
import 'package:beecount/agent/model/native_tool_agent_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final provider in [
    AIServiceProviderConfig.xiaomiDefault,
    AIServiceProviderConfig.deepSeekDefault
  ]) {
    test(
        '${provider.name} Assistant setting is frozen for tool rounds and refreshed for the next run',
        () async {
      var config = provider.copyWith(apiKey: 'fake');
      var loads = 0;
      final usedSettings = <bool>[];
      var calls = 0;
      final transport = OpenAiCompatibleNativeToolTransport(
        loadConfig: () async {
          loads++;
          return config;
        },
        systemPrompt: '',
        toolDefinitions: const [
          core.AgentNativeToolDefinition(
              name: 'probe',
              description: 'probe',
              parameters: {'type': 'object'})
        ],
        createStream: (snapshot) =>
            ({required messages, required tools, logTag}) async* {
          usedSettings.add(snapshot.assistantThinkingEnabled);
          calls++;
          if (calls == 1) {
            yield {
              'choices': [
                {
                  'delta': {
                    'reasoning_content': 'reasoning',
                    'tool_calls': [
                      {
                        'index': 0,
                        'id': 'one',
                        'type': 'function',
                        'function': {'name': 'probe', 'arguments': '{}'}
                      }
                    ]
                  },
                  'finish_reason': 'tool_calls'
                }
              ]
            };
          } else {
            if (calls == 2) {
              expect(
                  messages
                      .where((m) => m['role'] == 'assistant')
                      .first['reasoning_content'],
                  'reasoning');
            }
            yield {
              'choices': [
                {
                  'delta': {'content': 'done'},
                  'finish_reason': 'stop'
                }
              ]
            };
          }
        },
      );
      await transport.complete(core.AgentNativeToolRequest(
          runId: 'first', userPrompt: 'test', toolResults: []));
      config = config.copyWith(assistantThinkingEnabled: false);
      await transport.complete(core.AgentNativeToolRequest(
          runId: 'first',
          userPrompt: 'test',
          allowToolCalls: false,
          toolResults: [
            core.AgentNativeToolResult(toolCallId: 'one', content: 'ok')
          ]));
      transport.disposeRun('first');
      await transport.complete(core.AgentNativeToolRequest(
          runId: 'next', userPrompt: 'test', toolResults: []));
      transport.disposeRun('next');
      expect(usedSettings, [true, true, false]);
      expect(loads, 2);
      expect(config.thinkingEnabled, true);
    });
  }
}
