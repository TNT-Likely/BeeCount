import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_ai_kit/flutter_ai_kit.dart';
import 'package:flutter_ai_kit_zhipu/flutter_ai_kit_zhipu.dart';

import 'ai_provider_config.dart';
import 'ai_provider_manager.dart';
import '../../services/system/logger_service.dart';

/// AI Provider 工厂类
///
/// 统一管理 AI 基础能力，屏蔽底层服务商差异。
/// 支持多服务商配置，每种能力可以使用不同的服务商。
class AIProviderFactory {
  AIProviderFactory._();

  static Dio? _dio;

  /// 获取/创建 Dio 实例
  static Dio _getDio(AIServiceProviderConfig config) {
    _dio ??= Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ));
    _dio!.options.baseUrl = config.baseUrl;
    _dio!.options.headers = {
      'Authorization': 'Bearer ${config.apiKey}',
      'Content-Type': 'application/json',
    };
    return _dio!;
  }

  // ============================================================
  // 基础能力接口
  // ============================================================

  /// 文本对话
  ///
  /// [prompt] 用户输入
  /// [systemPrompt] 系统提示（可选）
  /// [temperature] 温度（可选，默认0.7）
  /// 返回 AI 响应文本
  static Future<String> chat(
    String prompt, {
    String? systemPrompt,
    double temperature = 0.7,
    String? logTag,
  }) async {
    final tag = logTag ?? 'AIFactory';

    // 获取文本能力对应的服务商
    final config = await AIProviderManager.getProviderForCapability(
      AICapabilityType.text,
    );

    if (config == null || !config.isValid) {
      throw AIException('未配置文本对话服务商');
    }

    if (!config.supportsText) {
      throw AIException('服务商 ${config.name} 未配置文本模型');
    }

    logger.debug(tag, '发起文本对话 (${config.name}, 模型: ${config.textModel})');

    if (config.isBuiltIn) {
      return _chatZhipu(config, prompt, systemPrompt, temperature);
    } else {
      return _chatOpenAI(config, prompt, systemPrompt, temperature);
    }
  }

  /// 图片理解
  ///
  /// [image] 图片文件
  /// [prompt] 提示词
  /// 返回 AI 对图片的理解/描述
  static Future<String> vision(
    File image,
    String prompt, {
    String? logTag,
  }) async {
    final tag = logTag ?? 'AIFactory';

    // 获取视觉能力对应的服务商
    final config = await AIProviderManager.getProviderForCapability(
      AICapabilityType.vision,
    );

    if (config == null || !config.isValid) {
      throw AIException('未配置图片理解服务商');
    }

    if (!config.supportsVision) {
      throw AIException('服务商 ${config.name} 未配置视觉模型');
    }

    logger.debug(tag, '发起图片理解 (${config.name}, 模型: ${config.visionModel})');

    if (config.isBuiltIn) {
      return _visionZhipu(config, image, prompt);
    } else {
      return _visionOpenAI(config, image, prompt);
    }
  }

  /// 语音转文字
  ///
  /// [audio] 音频文件
  /// 返回识别的文字
  static Future<String> speechToText(
    File audio, {
    String? logTag,
  }) async {
    final tag = logTag ?? 'AIFactory';

    // 获取语音能力对应的服务商
    final config = await AIProviderManager.getProviderForCapability(
      AICapabilityType.speech,
    );

    if (config == null || !config.isValid) {
      throw AIException('未配置语音转文字服务商');
    }

    if (!config.supportsSpeech) {
      throw AIException('服务商 ${config.name} 未配置语音模型');
    }

    logger.debug(tag, '发起语音转文字 (${config.name}, 模型: ${config.audioModel})');

    if (config.isBuiltIn) {
      return _speechToTextZhipu(config, audio);
    } else {
      return _speechToTextOpenAI(config, audio);
    }
  }

  /// 验证当前文本服务商配置是否可用
  static Future<(bool success, String? error)> validateConfig({
    String? logTag,
  }) async {
    final config = await AIProviderManager.getProviderForCapability(
      AICapabilityType.text,
    );

    if (config == null) {
      return (false, '未配置文本对话服务商');
    }

    return validateProvider(config, logTag: logTag);
  }

  /// 验证指定服务商配置是否可用（兼容旧接口）
  static Future<(bool success, String? error)> validateProvider(
    AIServiceProviderConfig config, {
    String? logTag,
  }) async {
    return validateTextCapability(config, logTag: logTag);
  }

  /// 验证文本对话能力
  static Future<(bool success, String? error)> validateTextCapability(
    AIServiceProviderConfig config, {
    String? logTag,
  }) async {
    final tag = logTag ?? 'AIFactory';
    logger.info(tag, '验证文本能力: ${config.name}');
    logger.debug(tag, '  Base URL: ${config.baseUrl}');
    logger.debug(tag, '  模型: ${config.textModel}');

    if (!config.isValid) {
      return (false, '未配置 API Key');
    }

    if (!config.supportsText) {
      return (false, '未配置文本模型');
    }

    try {
      String response;
      if (config.isBuiltIn) {
        response = await _chatZhipu(config, 'hi', null, 0.7);
      } else {
        response = await _chatOpenAI(config, 'hi', null, 0.7);
      }

      if (response.isNotEmpty) {
        logger.info(tag, '文本能力验证成功: ${config.name}');
        return (true, null);
      } else {
        return (false, 'API返回空响应');
      }
    } on AIException catch (e) {
      logger.warning(tag, '文本能力验证失败: ${e.message}');
      return (false, e.message);
    } catch (e, st) {
      logger.error(tag, '文本能力验证异常', e, st);
      return (false, '验证异常: $e');
    }
  }

  /// 验证图片理解能力
  static Future<(bool success, String? error)> validateVisionCapability(
    AIServiceProviderConfig config, {
    String? logTag,
  }) async {
    final tag = logTag ?? 'AIFactory';
    logger.info(tag, '验证视觉能力: ${config.name}');
    logger.debug(tag, '  Base URL: ${config.baseUrl}');
    logger.debug(tag, '  模型: ${config.visionModel}');

    if (!config.isValid) {
      return (false, '未配置 API Key');
    }

    if (!config.supportsVision) {
      return (false, '未配置视觉模型');
    }

    try {
      // 创建一个最小的测试图片
      final testImageBytes = _createTestImage();
      final tempDir = Directory.systemTemp;
      final testImage = File('${tempDir.path}/bee_test_image.jpg');
      await testImage.writeAsBytes(testImageBytes);

      try {
        String response;
        if (config.isBuiltIn) {
          response = await _visionZhipu(config, testImage, '描述这张图片');
        } else {
          response = await _visionOpenAI(config, testImage, '描述这张图片');
        }

        if (response.isNotEmpty) {
          logger.info(tag, '视觉能力验证成功: ${config.name}');
          return (true, null);
        } else {
          return (false, 'API返回空响应');
        }
      } finally {
        // 清理测试图片
        if (await testImage.exists()) {
          await testImage.delete();
        }
      }
    } on AIException catch (e) {
      logger.warning(tag, '视觉能力验证失败: ${e.message}');
      return (false, e.message);
    } catch (e, st) {
      logger.error(tag, '视觉能力验证异常', e, st);
      return (false, '验证异常: $e');
    }
  }

  /// 验证语音转文字能力
  static Future<(bool success, String? error)> validateSpeechCapability(
    AIServiceProviderConfig config, {
    String? logTag,
  }) async {
    final tag = logTag ?? 'AIFactory';
    logger.info(tag, '验证语音能力: ${config.name}');
    logger.debug(tag, '  Base URL: ${config.baseUrl}');
    logger.debug(tag, '  模型: ${config.audioModel}');

    if (!config.isValid) {
      return (false, '未配置 API Key');
    }

    if (!config.supportsSpeech) {
      return (false, '未配置语音模型');
    }

    try {
      // 创建一个最小的测试音频（静音 WAV）
      final testAudioBytes = _createMinimalWav();
      final tempDir = Directory.systemTemp;
      final testAudio = File('${tempDir.path}/bee_test_audio.wav');
      await testAudio.writeAsBytes(testAudioBytes);

      try {
        if (config.isBuiltIn) {
          await _speechToTextZhipu(config, testAudio);
        } else {
          await _speechToTextOpenAI(config, testAudio);
        }

        // 静音音频返回空字符串也算成功
        logger.info(tag, '语音能力验证成功: ${config.name}');
        return (true, null);
      } finally {
        // 清理测试音频
        if (await testAudio.exists()) {
          await testAudio.delete();
        }
      }
    } on AIException catch (e) {
      logger.warning(tag, '语音能力验证失败: ${e.message}');
      return (false, e.message);
    } catch (e, st) {
      logger.error(tag, '语音能力验证异常', e, st);
      return (false, '验证异常: $e');
    }
  }

  /// 创建测试用的 JPEG 图片（64x64 像素红色方块）
  /// 这是一个有效的 JPEG 文件，base64 解码后可直接使用
  /// GLM VL 模型要求图片尺寸至少 28x28 像素
  static List<int> _createTestImage() {
    // 64x64 像素的红色 JPEG 图片 base64 编码
    const base64Jpeg =
        '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAUDBAQEAwUEBAQFBQUGBwwIBwcHBw8LCwkM'
        'EQ8SEhEPERETFhwXExQaFRERGCEYGh0dHx8fExciJCIeJBweHx7/2wBDAQUFBQcGBw4I'
        'CA4eFBEUHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4e'
        'Hh4eHh7/wAARCABAAEADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQF'
        'BgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEI'
        'I0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNk'
        'ZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLD'
        'xMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEB'
        'AQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJB'
        'UQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZH'
        'SElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaan'
        'qKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oA'
        'DAMBAAIRAxEAPwDyyiiivzo/ssKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiig'
        'AooooAKKKKACiiigAooooAKKKKACiiigAooooA//2Q==';
    return base64Decode(base64Jpeg);
  }

  /// 创建最小的 WAV 音频（1秒静音）
  static List<int> _createMinimalWav() {
    // 简单的 16-bit PCM WAV：44 字节头 + 8000 字节静音数据（1秒 8kHz）
    final sampleRate = 8000;
    final numSamples = sampleRate; // 1秒
    final dataSize = numSamples * 2; // 16-bit = 2 bytes per sample
    final fileSize = 36 + dataSize;

    final buffer = <int>[];

    // RIFF header
    buffer.addAll([0x52, 0x49, 0x46, 0x46]); // "RIFF"
    buffer.addAll(_intToBytes(fileSize, 4)); // file size - 8
    buffer.addAll([0x57, 0x41, 0x56, 0x45]); // "WAVE"

    // fmt chunk
    buffer.addAll([0x66, 0x6D, 0x74, 0x20]); // "fmt "
    buffer.addAll(_intToBytes(16, 4)); // chunk size
    buffer.addAll(_intToBytes(1, 2)); // audio format (PCM)
    buffer.addAll(_intToBytes(1, 2)); // num channels
    buffer.addAll(_intToBytes(sampleRate, 4)); // sample rate
    buffer.addAll(_intToBytes(sampleRate * 2, 4)); // byte rate
    buffer.addAll(_intToBytes(2, 2)); // block align
    buffer.addAll(_intToBytes(16, 2)); // bits per sample

    // data chunk
    buffer.addAll([0x64, 0x61, 0x74, 0x61]); // "data"
    buffer.addAll(_intToBytes(dataSize, 4)); // data size

    // 静音数据（全0）
    for (var i = 0; i < numSamples; i++) {
      buffer.addAll([0x00, 0x00]); // 16-bit silence
    }

    return buffer;
  }

  /// 整数转字节数组（小端序）
  static List<int> _intToBytes(int value, int length) {
    final result = <int>[];
    for (var i = 0; i < length; i++) {
      result.add((value >> (i * 8)) & 0xFF);
    }
    return result;
  }

  // ============================================================
  // 智谱 GLM 实现
  // ============================================================

  static Future<String> _chatZhipu(
    AIServiceProviderConfig config,
    String prompt,
    String? systemPrompt,
    double temperature,
  ) async {
    final provider = ZhipuGLMProvider(
      apiKey: config.apiKey,
      model: config.textModel,
      temperature: temperature,
    );

    final task = _SimpleTask(prompt);
    final result = await provider.execute(task);

    if (!result.success) {
      throw AIException(result.error ?? '智谱GLM调用失败');
    }

    return result.data!;
  }

  static Future<String> _visionZhipu(
    AIServiceProviderConfig config,
    File image,
    String prompt,
  ) async {
    final provider = ZhipuGLMProvider(
      apiKey: config.apiKey,
      model: config.visionModel,
      imageFile: image,
      temperature: 0.3,
    );

    final task = _SimpleTask(prompt);
    final result = await provider.execute(task);

    if (!result.success) {
      throw AIException(result.error ?? '智谱GLM视觉调用失败');
    }

    return result.data!;
  }

  static Future<String> _speechToTextZhipu(
    AIServiceProviderConfig config,
    File audio,
  ) async {
    final provider = ZhipuGLMProvider(
      apiKey: config.apiKey,
      model: config.audioModel,
      audioFile: audio,
    );

    final task = _SimpleTask('请将语音内容转换为文字，只返回识别的文字内容，不要添加任何解释或标点修饰。');
    final result = await provider.execute(task);

    if (!result.success) {
      throw AIException(result.error ?? '智谱GLM语音识别失败');
    }

    return result.data!.trim();
  }

  // ============================================================
  // OpenAI 兼容实现
  // ============================================================

  static Future<String> _chatOpenAI(
    AIServiceProviderConfig config,
    String prompt,
    String? systemPrompt,
    double temperature,
  ) async {
    final dio = _getDio(config);

    final messages = <Map<String, dynamic>>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

    logger.debug('AIFactory', '请求: ${config.baseUrl}/chat/completions');

    try {
      final response = await dio.post(
        '/chat/completions',
        data: {
          'model': config.textModel,
          'messages': messages,
          'temperature': temperature,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final choices = data['choices'] as List;
      final message = choices.first['message'] as Map<String, dynamic>;
      return message['content'] as String;
    } on DioException catch (e) {
      throw AIException(_extractDioError(e));
    }
  }

  static Future<String> _visionOpenAI(
    AIServiceProviderConfig config,
    File image,
    String prompt,
  ) async {
    final dio = _getDio(config);

    final imageBytes = await image.readAsBytes();
    final base64Image = base64Encode(imageBytes);

    logger.debug('AIFactory', '请求: ${config.baseUrl}/chat/completions');

    try {
      final response = await dio.post(
        '/chat/completions',
        data: {
          'model': config.visionModel,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image',
                  },
                },
              ],
            },
          ],
        },
      );

      final data = response.data as Map<String, dynamic>;
      final choices = data['choices'] as List;
      final message = choices.first['message'] as Map<String, dynamic>;
      return message['content'] as String;
    } on DioException catch (e) {
      throw AIException(_extractDioError(e));
    }
  }

  static Future<String> _speechToTextOpenAI(
    AIServiceProviderConfig config,
    File audio,
  ) async {
    final dio = _getDio(config);

    logger.debug('AIFactory', '请求: ${config.baseUrl}/audio/transcriptions');

    // 只发送必需参数，兼容硅基流动等服务商
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        audio.path,
        filename: audio.path.split('/').last,
      ),
      'model': config.audioModel,
    });

    try {
      final response = await dio.post(
        '/audio/transcriptions',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      final text = response.data['text'] as String;
      return text.trim();
    } on DioException catch (e) {
      throw AIException(_extractDioError(e));
    }
  }

  /// 提取 Dio 错误信息
  static String _extractDioError(DioException e, {String? logTag}) {
    final tag = logTag ?? 'AIFactory';
    final statusCode = e.response?.statusCode;
    final responseData = e.response?.data;

    // 打印详细错误信息用于调试
    logger.warning(tag, 'HTTP错误: $statusCode, 响应: $responseData');
    logger.warning(tag, '  错误类型: ${e.type}');
    logger.warning(tag, '  请求URL: ${e.requestOptions.uri}');
    if (e.error != null) {
      logger.warning(tag, '  底层错误: ${e.error}');
    }

    if (responseData is Map) {
      final data = responseData as Map<String, dynamic>;
      // OpenAI 格式: {"error": {"message": "...", "type": "..."}}
      if (data['error'] is Map) {
        final error = data['error'] as Map;
        final message = error['message'] ?? error['msg'] ?? 'API调用失败';
        return '[$statusCode] $message';
      }
      // 其他格式: {"message": "..."} 或 {"msg": "..."}
      if (data['message'] != null) {
        return '[$statusCode] ${data['message']}';
      }
      if (data['msg'] != null) {
        return '[$statusCode] ${data['msg']}';
      }
    }

    // 如果响应是字符串
    if (responseData is String && responseData.isNotEmpty) {
      return '[$statusCode] $responseData';
    }

    return '[$statusCode] ${e.message ?? 'API调用失败'}';
  }
}

/// AI 异常
class AIException implements Exception {
  final String message;

  AIException(this.message);

  @override
  String toString() => message;
}

/// 简单任务
class _SimpleTask extends AITask<String, String> {
  final String prompt;

  _SimpleTask(this.prompt);

  @override
  String get taskType => 'chat';

  @override
  String get input => prompt;

  @override
  Map<String, dynamic> toJson() => {
        'task_type': taskType,
        'prompt': prompt,
      };
}
