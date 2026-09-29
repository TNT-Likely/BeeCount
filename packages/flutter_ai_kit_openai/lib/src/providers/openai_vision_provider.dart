import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart' as dio_io;
import 'package:flutter_ai_kit/flutter_ai_kit.dart';

import '../config/openai_config.dart';
import '../exceptions/openai_exception.dart';
import '../models/chat_message.dart';
import '../models/chat_request.dart';
import '../models/chat_response.dart';

/// OpenAI 兼容的图片识别 Provider
class OpenAIVisionProvider implements AIProvider<File, String> {
  @override
  String get id => 'openai_vision_${config.getVisionModel()}';

  @override
  String get name => 'OpenAI Vision (${config.getVisionModel()})';

  @override
  AIProviderType get type => AIProviderType.cloud;

  @override
  bool get requiresNetwork => true;

  final OpenAIConfig config;
  final Dio _dio;

  OpenAIVisionProvider({
    required this.config,
    Dio? dio,
  }) : _dio = dio ?? _createDio(config);

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

    if (config.proxy != null) {
      (dio.httpClientAdapter as dio_io.IOHttpClientAdapter).createHttpClient =
          () {
        final client = HttpClient();
        client.findProxy = (uri) => 'PROXY ${config.proxy}';
        return client;
      };
    }

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
      'ocr',
      'image_recognition',
      'vision',
    ].contains(taskType);
  }

  @override
  Future<bool> isReady() async => config.validate();

  @override
  Future<AIResult<String>> execute(AITask<File, String> task) async {
    final startTime = DateTime.now();

    try {
      // 使用 getVisionModel() 获取视觉任务的模型
      final model = config.getVisionModel();

      // 1. 读取图片文件并转为 Base64
      final imageBytes = await task.input.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // 2. 构建多模态消息
      final request = ChatRequest(
        model: model,
        messages: [
          ChatMessage.multimodal(
            text: '请识别图片中的文字和数字',
            base64Image: base64Image,
          ),
        ],
      );

      // 3. 发送请求
      final response = await _dio.post(
        '/chat/completions',
        data: request.toJson(),
      );

      // 4. 解析响应并返回结果
      final rawData = response.data;
      if (rawData is Map && rawData['error'] != null) {
        throw OpenAIException.fromResponse(response.statusCode, rawData);
      }
      if (rawData is! Map) throw OpenAIException.invalidResponse();
      final chatResponse = ChatResponse.fromJson(
        Map<String, dynamic>.from(rawData),
      );
      final content = chatResponse.choices.first.message.content as String;

      return AIResult.success(
        content,
        DateTime.now().difference(startTime),
        metadata: AIResultMetadata(
          providerName: name,
          modelName: model,
          tokensUsed: chatResponse.usage.totalTokens,
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
  Future<double> estimateCost(AITask<File, String> task) async {
    return 0.001; // 视觉任务通常更贵
  }
}
