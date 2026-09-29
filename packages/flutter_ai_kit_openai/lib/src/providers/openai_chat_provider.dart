import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_ai_kit/flutter_ai_kit.dart';

import '../config/openai_config.dart';
import '../exceptions/openai_exception.dart';
import '../models/chat_message.dart';
import '../models/chat_request.dart';
import '../models/chat_response.dart';

/// OpenAI 兼容的文本对话 Provider
class OpenAIChatProvider implements AIProvider<String, String> {
  @override
  String get id => 'openai_chat_${config.getTextModel()}';

  @override
  String get name => 'OpenAI Chat (${config.getTextModel()})';

  @override
  AIProviderType get type => AIProviderType.cloud;

  @override
  bool get requiresNetwork => true;

  final OpenAIConfig config;
  final Dio _dio;

  OpenAIChatProvider({
    required this.config,
    Dio? dio,
  }) : _dio = dio ?? _createDio(config);

  /// 创建 Dio 实例
  static Dio _createDio(OpenAIConfig config) {
    final dio = Dio(BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: Duration(seconds: config.timeout),
      receiveTimeout: Duration(seconds: config.timeout),
      headers: {
        'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
      },
    ));

    // 配置代理
    if (config.proxy != null) {
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.findProxy = (uri) => 'PROXY ${config.proxy}';
        return client;
      };
    }

    // 配置日志
    if (config.enableLogging) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }

    return dio;
  }

  @override
  bool supportsTask(String taskType) {
    return [
      'text_extraction',
      'chat',
      'summarization',
      'translation',
    ].contains(taskType);
  }

  @override
  Future<bool> isReady() async => config.validate();

  @override
  Future<AIResult<String>> execute(AITask<String, String> task) async {
    final startTime = DateTime.now();

    try {
      // 使用 getTextModel() 获取文本任务的模型
      final model = config.getTextModel();

      // 构建请求
      final request = ChatRequest(
        model: model,
        messages: [
          ChatMessage.user(task.input),
        ],
        temperature: 0.1,
      );

      // 发送请求
      final response = await _dio.post(
        '/chat/completions',
        data: request.toJson(),
      );

      // 解析响应
      final rawData = response.data;
      if (rawData is Map && rawData['error'] != null) {
        throw OpenAIException.fromResponse(response.statusCode, rawData);
      }
      if (rawData is! Map) throw OpenAIException.invalidResponse();
      final chatResponse = ChatResponse.fromJson(
        Map<String, dynamic>.from(rawData),
      );
      final content = chatResponse.choices.first.message.content as String;
      final tokensUsed = chatResponse.usage.totalTokens;

      return AIResult.success(
        content,
        DateTime.now().difference(startTime),
        metadata: AIResultMetadata(
          providerName: name,
          modelName: model,
          tokensUsed: tokensUsed,
        ),
      );
    } on OpenAIException catch (e) {
      return AIResult.failure(
        e.userMessage,
        DateTime.now().difference(startTime),
        metadata: AIResultMetadata(providerName: name),
      );
    } on DioException catch (e) {
      return AIResult.failure(
        OpenAIException.fromDioException(e).userMessage,
        DateTime.now().difference(startTime),
        metadata: AIResultMetadata(providerName: name),
      );
    } catch (_) {
      return AIResult.failure(
        OpenAIException.invalidResponse().userMessage,
        DateTime.now().difference(startTime),
        metadata: AIResultMetadata(providerName: name),
      );
    }
  }

  @override
  Future<double> estimateCost(AITask<String, String> task) async {
    // 基于模型定价估算成本
    // TODO: 实现详细的成本估算逻辑
    return 0.0001; // 示例值
  }
}
