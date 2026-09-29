import 'dart:convert';
import 'dart:typed_data';

import 'package:beecount/ai/providers/ai_provider_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/ai/providers/ai_provider_factory.dart';

/// issue #312:推理模型(kimi-k2.5 / o1 / o3 / R1)锁 temperature=1,被拒时自适应摘参数。
///
/// 这里直接单测决策逻辑 `rejectedChatParam`(纯函数,无需 mock HTTP):
/// 给定上游错误响应 + 我们发出去的 payload,判断该摘哪个键。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('AIProviderFactory.rejectedChatParam', () {
    const moonshotTempErr =
        '{"error":{"message":"invalid temperature: only 1 is allowed for this model","type":"invalid_request_error"}}';

    test('Moonshot kimi-k2.5 锁温度 → 返回 temperature', () {
      final param = AIProviderFactory.rejectedChatParam(
        {'model': 'kimi-k2.5', 'messages': <dynamic>[], 'temperature': 0.3},
        400,
        moonshotTempErr,
      );
      expect(param, 'temperature');
    });

    test('OpenAI o1 风格文案也命中 temperature', () {
      final param = AIProviderFactory.rejectedChatParam(
        {'model': 'o1', 'messages': <dynamic>[], 'temperature': 0.2},
        400,
        "Unsupported value: 'temperature' does not support 0.2 with this model. "
        'Only the default (1) value is supported.',
      );
      expect(param, 'temperature');
    });

    test('成功状态 → null(摘参数逻辑不触发)', () {
      expect(
        AIProviderFactory.rejectedChatParam({'temperature': 0.2}, 200, ''),
        isNull,
      );
    });

    test('status 为 null(网络异常等)→ null', () {
      expect(
        AIProviderFactory.rejectedChatParam({'temperature': 0.2}, null, ''),
        isNull,
      );
    });

    test('非参数错误(限流)→ null,交给上层照常报错', () {
      expect(
        AIProviderFactory.rejectedChatParam(
          {'model': 'x', 'messages': <dynamic>[], 'temperature': 0.2},
          429,
          '{"error":"rate limited"}',
        ),
        isNull,
      );
    });

    test('"model not found" 含 model,但 model 是必须键 → 不摘', () {
      expect(
        AIProviderFactory.rejectedChatParam(
          {'model': 'missing', 'messages': <dynamic>[]},
          404,
          '{"error":"model not found"}',
        ),
        isNull,
      );
    });
  });

  group('AIProviderFactory.classifyProviderError', () {
    test('classifies an explicit tool capability rejection', () {
      expect(
        AIProviderFactory.classifyProviderError(
          400,
          {'error': 'This model does not support tools'},
          toolRequest: true,
        ),
        AIExceptionCode.nativeToolsUnsupported,
      );
    });

    test('does not treat an unrelated tool timeout as incompatibility', () {
      expect(
        AIProviderFactory.classifyProviderError(
          500,
          {'error': 'upstream tool timed out'},
          toolRequest: true,
        ),
        AIExceptionCode.unknown,
      );
    });

    test('classifies stream-only rejection separately from tool support', () {
      expect(
        AIProviderFactory.classifyProviderError(
          400,
          {'error': 'streaming is not supported'},
          toolRequest: true,
        ),
        AIExceptionCode.streamingUnsupported,
      );
    });
  });

  test('tool stream falls back to a non-streaming tool completion', () async {
    final adapter = _StreamingRejectedAdapter();
    final client = Dio(BaseOptions(baseUrl: 'https://example.com/v1'))
      ..httpClientAdapter = adapter;
    final chunks = await AIProviderFactory.chatWithToolsStreamForConfig(
      config: AIServiceProviderConfig(
        id: 'test',
        name: 'test',
        apiKey: 'key',
        baseUrl: 'https://example.com/v1',
        textModel: 'model',
        createdAt: DateTime.utc(2026),
      ),
      messages: const [
        {'role': 'user', 'content': 'probe'},
      ],
      tools: const [
        {
          'type': 'function',
          'function': {
            'name': 'probe',
            'parameters': {'type': 'object'},
          },
        },
      ],
      client: client,
    ).toList();

    expect(adapter.requests, 3);
    final choice = (chunks.single['choices'] as List).single as Map;
    final calls = (choice['delta'] as Map)['tool_calls'] as List;
    expect((calls.single as Map)['index'], 0);
    expect(((calls.single as Map)['function'] as Map)['name'], 'probe');
    expect(choice['finish_reason'], 'tool_calls');
  });
}

final class _StreamingRejectedAdapter implements HttpClientAdapter {
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    final payload = options.data as Map;
    if (payload['stream'] == true) {
      return ResponseBody.fromString(
        jsonEncode({'error': 'streaming is not supported'}),
        400,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (payload.containsKey('temperature')) {
      return ResponseBody.fromString(
        jsonEncode({'error': 'invalid temperature: only 1 is allowed'}),
        400,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'choices': [
          {
            'message': {
              'content': null,
              'tool_calls': [
                {
                  'id': 'call-1',
                  'type': 'function',
                  'function': {'name': 'probe', 'arguments': '{}'},
                },
              ],
            },
            'finish_reason': 'tool_calls',
          },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
