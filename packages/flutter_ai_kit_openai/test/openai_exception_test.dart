import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_ai_kit_openai/flutter_ai_kit_openai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpenAIException', () {
    test('解析流式请求的真实错误响应，保留 HTTP 状态和错误码', () async {
      final request = RequestOptions(path: '/chat/completions');
      final error = DioException.badResponse(
        statusCode: 401,
        requestOptions: request,
        response: Response(
            requestOptions: request,
            statusCode: 401,
            data: ResponseBody.fromString(
                '{"error":{"message":"Invalid API key","code":"invalid_key"}}',
                401)),
      );
      await OpenAIException.decodeStreamErrorResponse(error);
      expect(OpenAIException.fromDioException(error).userMessage,
          '[HTTP 401 / invalid_key] Invalid API key');
      expect(error.response!.data, isA<Map>());
    });

    test('流式错误体损坏不掩盖原来的服务商错误', () async {
      final request = RequestOptions(path: '/chat/completions');
      final error = DioException.badResponse(
        statusCode: 502,
        requestOptions: request,
        response: Response(
            requestOptions: request,
            statusCode: 502,
            data: ResponseBody.fromString('Upstream unavailable', 502)),
      );
      await OpenAIException.decodeStreamErrorResponse(error);
      expect(OpenAIException.fromDioException(error).userMessage,
          '[HTTP 502] Upstream unavailable');
    });

    test('流式错误体有界，过大响应不会无限缓冲', () async {
      final request = RequestOptions(path: '/chat/completions');
      final error = DioException.badResponse(
        statusCode: 502,
        requestOptions: request,
        response: Response(
            requestOptions: request,
            statusCode: 502,
            data: ResponseBody.fromBytes(utf8.encode('x' * 100000), 502)),
      );
      await OpenAIException.decodeStreamErrorResponse(error);
      expect((error.response!.data as String).length, 64 * 1024);
      expect(OpenAIException.fromDioException(error).message.length,
          lessThanOrEqualTo(801));
    });

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
