import 'package:dio/dio.dart';
import 'package:flutter_ai_kit_openai/flutter_ai_kit_openai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpenAIException', () {
    test('提取 OpenAI 嵌套错误、状态码与错误码', () {
      final error = OpenAIException.fromResponse(404, {
        'error': {
          'message': 'Model does not exist',
          'type': 'invalid_request_error',
          'code': 'model_not_found',
        },
      });

      expect(
        error.userMessage,
        '[HTTP 404 / model_not_found] Model does not exist',
      );
    });

    test('兼容硅基流动顶层 code 和 message', () {
      final error = OpenAIException.fromResponse(400, {
        'code': 20012,
        'message': 'Model does not exist. Please check it carefully.',
        'data': null,
      });

      expect(
        error.userMessage,
        '[HTTP 400 / 20012] Model does not exist. Please check it carefully.',
      );
    });

    test('解析字符串 JSON 响应', () {
      final error = OpenAIException.fromResponse(
        401,
        '{"error":{"message":"Invalid API key","code":"invalid_key"}}',
      );

      expect(error.userMessage, '[HTTP 401 / invalid_key] Invalid API key');
    });

    test('网络错误不暴露 DioException 与底层 socket 文案', () {
      final request = RequestOptions(path: '/chat/completions');
      final error = OpenAIException.fromDioException(
        DioException.connectionError(
          requestOptions: request,
          reason: 'SocketException: Connection refused',
        ),
      );

      expect(error.userMessage, '无法连接到服务器，请检查服务地址与网络连接');
      expect(error.userMessage, isNot(contains('DioException')));
      expect(error.userMessage, isNot(contains('SocketException')));
    });
  });
}
