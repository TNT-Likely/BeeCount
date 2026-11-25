import 'dart:convert';
import 'dart:io';

import 'package:agentcore/agentcore.dart' show AgentEvalCase;
import 'package:beecount/agent/model/native_tool_agent_model.dart';
import 'package:beecount/agent/runtime/agent_execution_settings.dart';
import 'package:beecount/ai/providers/ai_provider_config.dart';
import 'package:beecount/ai/providers/ai_provider_factory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/assistant_eval.dart';
import 'support/conversation_matrix_scoring.dart';

class _FixedDepth implements AgentExecutionSettingsStore {
  const _FixedDepth(this.turns);
  final int turns;
  @override
  Future<AgentExecutionSettings> read() async =>
      AgentExecutionSettings(maximumModelTurns: turns);
  @override
  Future<void> setMaximumModelTurns(int value) =>
      throw UnsupportedError('Fixture');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final env = Platform.environment;
  final replay = env['BEE_MATRIX_REPLAY'];
  if (replay != null) {
    test('rescore a saved ledger-v1 conversation matrix offline', () async {
      final saved = jsonDecode(await File(replay).readAsString()) as Map;
      final samples = (saved['samples'] as List)
          .cast<Map>()
          .map((sample) => {
                ...Map<String, Object?>.from(sample),
                'quality': scoreMatrixSample(sample)
              })
          .toList();
      await _writeReport(
          File(env['BEE_MATRIX_OUTPUT'] ?? '$replay.scored.json'),
          saved['model'] as String,
          samples);
    });
    return;
  }
  test('compare standard and deep ledger conversations with a configured model',
      () async {
    SharedPreferences.setMockInitialValues({});
    final config = AIServiceProviderConfig(
        id: 'eval',
        name: 'Eval',
        apiKey: env['AI_EVAL_API_KEY']!,
        baseUrl: env['AI_EVAL_BASE_URL']!,
        textModel: env['AI_EVAL_MODEL']!,
        createdAt: DateTime(2026, 9, 30));
    const tasks = {
      'conditional-review': [
        '从 2026 年 1 月到 9 月，哪个月餐饮支出最多？比较它和下一个月的差额，再找下一个月最贵的那笔餐饮，按它使用的支付账户计算当月除餐饮外的支出。每一步说出实际金额。'
      ],
      'cash-followup': ['9 月吃饭一共花了多少钱？', '只看刚才里面用现金付的呢？储蓄卡又是多少？'],
      'paged-count': ['9 月的每一笔购物都算上，一共有几笔、合计多少？明细先给我看最近的两笔。'],
      'monthly-review': [
        '帮我复盘 9 月。和 8 月相比，总支出和餐饮差多少？9 月的花钱上限和我设的每月自动记账分别是什么情况？没有设置就直说。'
      ],
    };
    final samples = <Map<String, Object?>>[];
    final output = File(env['BEE_MATRIX_OUTPUT']!);
    final originalPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    try {
      for (final depth in [4, 8]) {
        for (final task in tasks.entries.where((t) =>
            env['BEE_MATRIX_TASK'] == null ||
            t.key == env['BEE_MATRIX_TASK'])) {
          int requests = 0,
              inputTokens = 0,
              outputTokens = 0,
              meteredRequests = 0;
          final executor = AssistantEvalExecutor(
              live: true,
              executionSettingsStore: _FixedDepth(depth),
              createLiveModel: () => NativeToolAgentModel(
                      transport: OpenAiCompatibleNativeToolTransport(
                    toolStream: (
                        {required messages, required tools, logTag}) async* {
                      requests++;
                      // Sum the latest cumulative usage once per request, even
                      // when the consumer closes a stream on its finish reason.
                      int? lastInput;
                      var lastOutput = 0;
                      await for (final chunk
                          in AIProviderFactory.chatWithToolsStreamForConfig(
                              config: config,
                              messages: messages,
                              tools: tools,
                              logTag: logTag)) {
                        if (chunk['usage']
                            case {
                              'prompt_tokens': final int input,
                              'completion_tokens': final int output
                            }) {
                          if (lastInput == null) meteredRequests++;
                          inputTokens += input - (lastInput ?? 0);
                          outputTokens += output - lastOutput;
                          lastInput = input;
                          lastOutput = output;
                        }
                        yield chunk;
                      }
                    },
                  )));
          final sample = AgentEvalCase.fromJson({
            'id': task.key,
            'tags': ['zh'],
            'input': {
              'ledger': 'main',
              'steps': [
                for (final prompt in task.value) {'prompt': prompt}
              ]
            },
            'expected': {'turns': []},
          });
          final clock = Stopwatch()..start();
          final observation = await HttpOverrides.runZoned(
              () => executor.execute(sample),
              createHttpClient: _LiveHttpOverrides().createHttpClient);
          final result = {
            'task': task.key,
            'depth': depth,
            'toolBudget': depth + 2,
            'elapsedMs': clock.elapsedMilliseconds,
            'requests': requests,
            'meteredResponses': meteredRequests,
            if (meteredRequests > 0) 'inputTokens': inputTokens,
            if (meteredRequests > 0) 'outputTokens': outputTokens,
            'metrics': observation.metrics,
            'observation': observation.data
          };
          samples.add({...result, 'quality': scoreMatrixSample(result)});
          await _writeReport(output, config.textModel, samples);
        }
      }
    } finally {
      debugPrint = originalPrint;
    }
    expect(samples.length,
        (env['BEE_MATRIX_TASK'] == null ? tasks.length : 1) * 2);
    expect(
        samples.any(
            (sample) => ((sample['metrics'] as Map)['toolCalls'] as int) > 0),
        isTrue,
        reason:
            'The configured model must reach the production tool protocol.');
  },
      skip: env['BEE_MATRIX_LIVE'] != '1',
      timeout: const Timeout(Duration(minutes: 25)));
}

Future<void> _writeReport(
    File output, String model, List<Map<String, Object?>> samples) async {
  await output.writeAsString(
      jsonEncode({
        'model': model,
        'fixture': 'ledger-v1',
        'scoreVersion': 1,
        'samples': samples,
        'byDepth': {
          for (final depth in [4, 8])
            depth.toString(): summarizeMatrixSamples(
                samples.where((sample) => sample['depth'] == depth).toList()),
        },
      }),
      flush: true);
}

final class _LiveHttpOverrides extends HttpOverrides {}
