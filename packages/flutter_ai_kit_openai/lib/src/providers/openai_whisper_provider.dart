import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart' as dio_io;
import 'package:flutter_ai_kit/flutter_ai_kit.dart';

import '../config/openai_config.dart';
import '../exceptions/openai_exception.dart';

/// OpenAI 兼容的语音转文字 Provider
class OpenAIWhisperProvider implements AIProvider<File, String> {
  @override
  String get id => 'openai_whisper_${config.getAudioModel()}';

  @override
  String get name => 'OpenAI Whisper (${config.getAudioModel()})';

  @override
  AIProviderType get type => AIProviderType.cloud;

  @override
  bool get requiresNetwork => true;

  final OpenAIConfig config;
  final Dio _dio;

  OpenAIWhisperProvider({
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
      'speech_to_text',
      'audio_transcription',
    ].contains(taskType);
  }

  @override
  Future<bool> isReady() async => config.validate();

  @override
  Future<AIResult<String>> execute(AITask<File, String> task) async {
    final startTime = DateTime.now();

    try {
      // 使用 getAudioModel() 获取语音任务的模型
      final model = config.getAudioModel();

      // 构建 FormData（Whisper 使用 multipart/form-data）
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          task.input.path,
          filename: task.input.path.split('/').last,
        ),
        'model': model,
        'language': 'zh', // 中文
        'response_format': 'json',
      });

      // 发送请求
      final response = await _dio.post(
        '/audio/transcriptions',
        data: formData,
      );

      // 解析响应
      final rawData = response.data;
      if (rawData is Map && rawData['error'] != null) {
        throw OpenAIException.fromResponse(response.statusCode, rawData);
      }
      if (rawData is! Map || rawData['text'] is! String) {
        throw OpenAIException.invalidResponse();
      }
      final text = rawData['text'] as String;

      return AIResult.success(
        text,
        DateTime.now().difference(startTime),
        metadata: AIResultMetadata(
          providerName: name,
          modelName: model,
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
    return 0.0005; // 语音转文字成本适中
  }
}
