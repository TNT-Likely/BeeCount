import 'dart:convert';

import 'package:dio/dio.dart';

/// OpenAI 兼容接口异常。
///
/// 除了保留状态码与错误码，还负责把不同服务商的错误响应收敛成可直接展示给
/// 用户的消息，避免上层把 [DioException] 或 Dart 类型错误暴露到界面。
class OpenAIException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final dynamic details;

  OpenAIException({
    required this.message,
    this.code,
    this.statusCode,
    this.details,
  });

  /// 适合直接展示给用户的错误文本。
  String get userMessage {
    final labels = <String>[
      if (statusCode != null) 'HTTP $statusCode',
      if (code != null && code!.trim().isNotEmpty) code!.trim(),
    ];
    return labels.isEmpty ? message : '[${labels.join(' / ')}] $message';
  }

  @override
  String toString() => userMessage;

  /// 从任意 OpenAI 兼容服务商的错误响应创建。
  ///
  /// 支持 OpenAI 的嵌套 `error.message`，也兼容常见的顶层
  /// `message`、`msg`、`detail` 以及字符串 JSON 响应。
  factory OpenAIException.fromResponse(
    int? statusCode,
    Object? data,
  ) {
    final normalized = _normalizeData(data);
    final error = normalized is Map ? normalized['error'] : null;
    final source = error is Map ? error : normalized;
    final message = _firstText(source, const [
          'message',
          'msg',
          'detail',
          'error_description',
        ]) ??
        (error is String ? _cleanText(error) : null) ??
        (normalized is String ? _cleanText(normalized) : null) ??
        '服务商请求失败';
    final codeValue = _firstValue(source, const ['code', 'type']) ??
        _firstValue(normalized, const ['code', 'type']);

    return OpenAIException(
      message: message,
      code: codeValue?.toString(),
      statusCode: statusCode,
      details: normalized,
    );
  }

  /// 从 Dio 异常创建，同时屏蔽其实现类和底层 socket 文案。
  factory OpenAIException.fromDioException(DioException error) {
    // Dio 5.11 新增了 transformTimeout；使用 name 兼容仍锁定旧版 Dio 的 App。
    if (error.type.name == 'transformTimeout') {
      return OpenAIException(message: '请求超时，请检查网络连接');
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return OpenAIException(message: '请求超时，请检查网络连接');
      case DioExceptionType.connectionError:
        return OpenAIException(message: '无法连接到服务器，请检查服务地址与网络连接');
      case DioExceptionType.badCertificate:
        return OpenAIException(message: '服务器证书校验失败，请检查服务地址');
      case DioExceptionType.cancel:
        return OpenAIException(message: '请求已取消');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
      // Dio 新版本可能新增异常类型；旧版静态分析会认为此分支不可达。
      // ignore: unreachable_switch_default
      default:
        if (error.response != null) {
          return OpenAIException.fromResponse(
            error.response?.statusCode,
            error.response?.data,
          );
        }
        return OpenAIException(message: '网络请求失败，请检查服务地址与网络连接');
    }
  }

  /// Decode a failed streaming response before synchronous error classification
  /// or optional-parameter retries. Dio otherwise exposes a ResponseBody object
  /// instead of the provider's actual error. Reading is bounded and never
  /// replaces the original HTTP failure with a decoding exception.
  static Future<void> decodeStreamErrorResponse(DioException error) async {
    final response = error.response;
    final body = response?.data;
    if (body is! ResponseBody) return;
    const maximumBytes = 64 * 1024;
    final bytes = <int>[];
    try {
      await for (final chunk
          in body.stream.timeout(const Duration(seconds: 10))) {
        bytes.addAll(chunk.take(maximumBytes - bytes.length));
        if (bytes.length >= maximumBytes) break;
      }
      response!.data = _normalizeData(utf8.decode(bytes, allowMalformed: true));
    } on Object {
      response!.data = null;
    }
  }

  /// 服务商返回了成功状态，但响应结构不是 OpenAI 兼容格式。
  factory OpenAIException.invalidResponse([String? detail]) => OpenAIException(
        message: detail == null || detail.trim().isEmpty
            ? '服务商返回了无法识别的响应格式'
            : '服务商返回了无法识别的响应格式：${detail.trim()}',
      );

  /// API Key 无效
  factory OpenAIException.invalidApiKey() => OpenAIException(
        message: 'API Key 无效或已过期',
        code: 'invalid_api_key',
        statusCode: 401,
      );

  /// 配额不足
  factory OpenAIException.quotaExceeded() => OpenAIException(
        message: 'API 配额已用尽',
        code: 'quota_exceeded',
        statusCode: 429,
      );

  /// 网络错误
  factory OpenAIException.networkError(String message) => OpenAIException(
        message: '网络请求失败: $message',
        code: 'network_error',
      );

  /// 超时
  factory OpenAIException.timeout() => OpenAIException(
        message: '请求超时',
        code: 'timeout',
      );

  static Object? _normalizeData(Object? data) {
    if (data is! String) return data;
    final text = data.trim();
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  static Object? _firstValue(Object? source, List<String> keys) {
    if (source is! Map) return null;
    for (final key in keys) {
      final value = source[key];
      if (value != null && value.toString().trim().isNotEmpty) return value;
    }
    return null;
  }

  static String? _firstText(Object? source, List<String> keys) {
    final value = _firstValue(source, keys);
    return value == null ? null : _cleanText(value.toString());
  }

  static String? _cleanText(String value) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return null;
    const maxLength = 800;
    return text.length <= maxLength ? text : '${text.substring(0, maxLength)}…';
  }
}
