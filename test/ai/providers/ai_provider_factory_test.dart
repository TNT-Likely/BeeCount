import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/ai/providers/ai_provider_factory.dart';

/// issue #312:推理模型(kimi-k2.5 / o1 / o3 / R1)锁 temperature=1,被拒时自适应摘参数。
///
/// 这里直接单测决策逻辑 `rejectedChatParam`(纯函数,无需 mock HTTP):
/// 给定上游错误响应 + 我们发出去的 payload,判断该摘哪个键。
void main() {
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
}
