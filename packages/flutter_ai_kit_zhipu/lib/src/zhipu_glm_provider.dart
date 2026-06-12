import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_ai_kit/flutter_ai_kit.dart';

/// 智谱GLM Provider
///
/// 支持智谱AI的GLM系列模型
///
/// 示例:
/// ```dart
/// final provider = ZhipuGLMProvider(
///   apiKey: 'your_api_key',
///   model: 'glm-4.6v-flash', // 默认使用免费的glm-4.6v-flash
/// );
/// ```
class ZhipuGLMProvider implements AIProvider<String, String> {
  @override
  String get id => 'zhipu_glm_$model';

  @override
  String get name => '智谱GLM-${model.toUpperCase()}';

  @override
  AIProviderType get type => AIProviderType.cloud;

  @override
  bool get requiresNetwork => true;

  /// API密钥
  final String apiKey;

  /// 模型名称（默认: glm-4-flash 免费）
  final String model;

  /// 温度参数（0.0 - 1.0，越低越确定性）
  final double temperature;

  /// 图片文件（可选，用于GLM-4V视觉模型）
  final File? imageFile;

  /// 音频文件（可选，用于GLM-4语音识别）
  final File? audioFile;

  late final Dio _dio;

  /// 连接超时（默认 30s）
  final Duration connectTimeout;

  /// 接收超时（默认 60s，对齐 app 层 OpenAI 兼容路径）
  final Duration receiveTimeout;

  /// 发送超时（默认 60s，上传 base64 大图/音频时有用）
  final Duration sendTimeout;

  ZhipuGLMProvider({
    required this.apiKey,
    this.model = 'glm-4.6v-flash',
    this.temperature = 0.1,
    this.imageFile,
    this.audioFile,
    this.connectTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 60),
    this.sendTimeout = const Duration(seconds: 60),
  }) {
    _dio = Dio(BaseOptions(
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: sendTimeout,
    ));
  }

  @override
  bool supportsTask(String taskType) {
    // 支持通用文本处理任务
    return [
      'text_extraction',
      'chat',
      'summarization',
      'translation',
    ].contains(taskType);
  }

  @override
  Future<bool> isReady() async => apiKey.isNotEmpty;

  @override
  Future<AIResult<String>> execute(AITask<String, String> task) async {
    final startTime = DateTime.now();

    try {
      // 准备消息内容
      final messageContent = await _prepareMessageContent(task.input);

      // 构建消息列表
      final messages = <Map<String, dynamic>>[];

      // 对于音频模型，添加system消息强制JSON输出
      if (audioFile != null) {
        messages.add({
          'role': 'system',
          'content': '你是一个专业的账单信息提取助手。用户会提供语音输入和提取要求，你必须严格按照要求返回JSON格式的结果，不要返回其他任何文字或解释。'
        });
      }

      messages.add({'role': 'user', 'content': messageContent});

      // 简化日志输出
      final simplifiedMessages = messages.map((m) {
        final content = m['content'];
        String contentPreview;
        if (content is String) {
          contentPreview = content.length > 200
              ? '${content.substring(0, 200)}...(${content.length} chars)'
              : content;
        } else {
          contentPreview = '[multimodal content]';
        }
        return {'role': m['role'], 'content': contentPreview};
      }).toList();

      print('🔍 [GLM] 请求: model=$model, messages=${simplifiedMessages.length}条, temperature=$temperature');

      final response = await _dio.post(
        'https://open.bigmodel.cn/api/paas/v4/chat/completions',
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': model,
          'messages': messages,
          'temperature': temperature,
        },
      );

      print('📦 [GLM] 响应数据: ${jsonEncode(response.data)}');

      final content = response.data['choices'][0]['message']['content'];
      final tokens = response.data['usage']['total_tokens'];

      return AIResult.success(
        content,
        DateTime.now().difference(startTime),
        metadata: AIResultMetadata(
          providerName: name,
          modelName: model,
          tokensUsed: tokens,
        ),
      );
    } on DioException catch (e) {
      print('❌ [GLM] DioException: ${e.type} - ${e.message}');
      if (e.response != null) {
        print('❌ [GLM] 响应状态码: ${e.response?.statusCode}');
        print('❌ [GLM] 响应数据: ${e.response?.data}');
      }
      return AIResult.failure(
        _parseDioError(e),
        DateTime.now().difference(startTime),
        metadata: AIResultMetadata(providerName: name),
      );
    } catch (e, stackTrace) {
      print('❌ [GLM] Exception: $e');
      print('❌ [GLM] Stack trace: $stackTrace');
      return AIResult.failure(
        e.toString(),
        DateTime.now().difference(startTime),
        metadata: AIResultMetadata(providerName: name),
      );
    }
  }

  @override
  Future<double> estimateCost(AITask<String, String> task) async {
    // GLM-4-Flash 完全免费
    if (model == 'glm-4-flash') return 0.0;

    // 其他模型按字符数粗略估算
    final charCount = task.input.length;
    final estimatedTokens = charCount ~/ 2; // 粗略估算

    // 价格（示例，实际需查看官方文档）
    switch (model) {
      case 'glm-4':
        return estimatedTokens * 0.00001; // $0.01/1k tokens
      case 'glm-3-turbo':
        return estimatedTokens * 0.000005; // $0.005/1k tokens
      default:
        return 0.0;
    }
  }

  /// 准备消息内容（支持图片和音频上传）
  Future<dynamic> _prepareMessageContent(String text) async {
    print('📝 [GLM] 准备消息内容，文本长度: ${text.length}');
    print('📝 [GLM] 音频文件: ${audioFile?.path ?? "无"}');
    print('📝 [GLM] 图片文件: ${imageFile?.path ?? "无"}');

    final List<Map<String, dynamic>> content = [];

    // 添加音频（如果有）
    if (audioFile != null) {
      try {
        final audioBytes = await audioFile!.readAsBytes();
        final base64Audio = base64Encode(audioBytes);

        // 检测音频格式（GLM API 支持 wav 和 mp3）
        final extension = audioFile!.path.split('.').last.toLowerCase();
        String format = 'mp3'; // 默认
        if (extension == 'wav') {
          format = 'wav';
        } else if (extension == 'm4a' || extension == 'aac') {
          // m4a/aac 录音格式，GLM可能识别为 mp3
          format = 'mp3';
        }

        content.add({
          'type': 'input_audio',
          'input_audio': {
            'data': base64Audio, // 纯 base64，不需要 data URI 前缀
            'format': format,
          }
        });
      } catch (e) {
        print('⚠️ [GLM] 音频编码失败: $e');
      }
    }

    // 添加图片（如果有）
    if (imageFile != null) {
      try {
        final imageBytes = await imageFile!.readAsBytes();
        final base64Image = base64Encode(imageBytes);

        // 检测图片格式
        final extension = imageFile!.path.split('.').last.toLowerCase();
        String mimeType = 'image/jpeg'; // 默认
        if (extension == 'png') {
          mimeType = 'image/png';
        } else if (extension == 'jpg' || extension == 'jpeg') {
          mimeType = 'image/jpeg';
        } else if (extension == 'webp') {
          mimeType = 'image/webp';
        }

        content.add({
          'type': 'image_url',
          'image_url': {
            'url': 'data:$mimeType;base64,$base64Image',
          }
        });
      } catch (e) {
        print('⚠️ [GLM] 图片编码失败: $e');
      }
    }

    // 添加文本
    if (text.isNotEmpty) {
      content.add({
        'type': 'text',
        'text': text,
      });
    }

    // 如果只有文本，直接返回字符串
    if (content.length == 1 && content[0]['type'] == 'text') {
      return text;
    }

    // 如果有多模态内容，返回数组
    if (content.isNotEmpty) {
      print('📝 [GLM] 返回多模态内容数组（${content.length}个块）');
      return content;
    }

    // 默认返回文本
    print('📝 [GLM] 默认返回文本');
    return text;
  }

  String _parseDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timeout';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['error']?['message'];
        return 'API error ($statusCode): ${message ?? "Unknown error"}';
      case DioExceptionType.cancel:
        return 'Request cancelled';
      case DioExceptionType.connectionError:
        return 'Connection error: ${e.message}';
      default:
        return 'Network error: ${e.message}';
    }
  }
}
