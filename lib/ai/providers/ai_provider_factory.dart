import 'dart:convert';
import 'dart:io';
import 'package:agentcore/agentcore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_ai_kit/flutter_ai_kit.dart';
import 'package:flutter_ai_kit_openai/flutter_ai_kit_openai.dart'
    show OpenAIException;
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

  /// Real Server-Sent Events from an OpenAI-compatible tool-call endpoint.
  /// Each yielded map is one parsed `data:` payload; callers aggregate content
  /// and fragmented tool-call arguments while presenting updates immediately.
  static Stream<Map<String, dynamic>> chatWithToolsStream({
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
    String? logTag,
  }) async* {
    final config = await AIProviderManager.getProviderForCapability(
      AICapabilityType.text,
    );
    if (config == null || !config.isValid || !config.supportsText) {
      throw AIException('未配置可用的文本对话服务商');
    }
    logger.debug(logTag ?? 'AgentNativeTools',
        '发起原生工具流式对话 (${config.name}, 模型: ${config.textModel})');
    yield* chatWithToolsStreamForConfig(
      config: config,
      messages: messages,
      tools: tools,
      logTag: logTag,
    );
  }

  @visibleForTesting
  static Stream<Map<String, dynamic>> chatWithToolsStreamForConfig({
    required AIServiceProviderConfig config,
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
    String? logTag,
    Dio? client,
  }) async* {
    final dio = client ?? _getDio(config);
    final payload = _toolCompletionPayload(
      config: config,
      messages: messages,
      tools: tools,
      stream: true,
    );
    try {
      await for (final chunk in _streamToolCompletion(dio, payload)) {
        yield chunk;
      }
    } on DioException catch (error) {
      if (!_mayRejectStreaming(error)) {
        throw _toolRequestException(error);
      }
      logger.info(logTag ?? 'AgentNativeTools', '服务商拒绝流式工具请求，自动降级为非流式');
      try {
        final response = await _postToolCompletion(
          dio,
          {...payload, 'stream': false},
        );
        yield _normalizeCompletion(response);
      } on DioException catch (fallbackError) {
        throw _toolRequestException(fallbackError);
      } on FormatException catch (_) {
        throw AIException(
          '服务商返回了无法解析的非流式工具调用响应',
          code: AIExceptionCode.invalidResponse,
        );
      }
    } on FormatException catch (_) {
      throw AIException(
        '服务商返回了无法解析的工具调用响应',
        code: AIExceptionCode.invalidResponse,
      );
    }
  }

  static Map<String, Object?> _toolCompletionPayload({
    required AIServiceProviderConfig config,
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
    required bool stream,
  }) {
    final payload = <String, Object?>{
      'model': config.textModel,
      'messages': messages,
      'temperature': 0.1,
      'stream': stream,
    };
    // Keep an explicit no-tool choice during finalization. DeepSeek-compatible
    // gateways may otherwise emit textual DSML markup after a tool turn.
    if (tools.isNotEmpty) {
      payload['tools'] = tools;
      payload['tool_choice'] = 'auto';
    } else {
      payload['tool_choice'] = 'none';
    }
    return payload;
  }

  static Stream<Map<String, dynamic>> _streamToolCompletion(
    Dio dio,
    Map<String, Object?> payload, {
    int strippedParameterCount = 0,
  }) async* {
    final Response<ResponseBody> response;
    try {
      response = await dio.post<ResponseBody>(
        '/chat/completions',
        data: payload,
        options: Options(responseType: ResponseType.stream),
      );
    } on DioException catch (error) {
      await OpenAIException.decodeStreamErrorResponse(error);
      final rejected = rejectedChatParam(
        Map<String, dynamic>.from(payload),
        error.response?.statusCode,
        error.response?.data?.toString() ?? '',
      );
      // Retry optional parameter incompatibilities in SSE mode first. Never
      // strip the tool catalog or stream flag; genuine stream rejection still
      // follows the existing bounded non-streaming fallback in the caller.
      if ((error.response?.statusCode == 400 ||
              error.response?.statusCode == 422) &&
          rejected != null &&
          rejected != 'tools' &&
          rejected != 'stream' &&
          strippedParameterCount < _maxParamStrips) {
        logger.info('AgentNativeTools', '服务商不接受 $rejected，保留流式并移除参数重试');
        yield* _streamToolCompletion(
          dio,
          Map<String, Object?>.of(payload)..remove(rejected),
          strippedParameterCount: strippedParameterCount + 1,
        );
        return;
      }
      rethrow;
    }
    final body = response.data;
    if (body == null) {
      throw AIException(
        '服务商未返回工具调用响应',
        code: AIExceptionCode.invalidResponse,
      );
    }
    final contentType = response.headers.value(Headers.contentTypeHeader) ?? '';
    if (!contentType.toLowerCase().contains('text/event-stream')) {
      final bytes = await body.stream
          .map<List<int>>(List<int>.from)
          .fold<List<int>>(<int>[], (buffer, chunk) => buffer..addAll(chunk));
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) throw const FormatException();
      yield _normalizeCompletion(Map<String, dynamic>.from(decoded));
      return;
    }
    await for (final line in body.stream
        .map<List<int>>(List<int>.from)
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data == '[DONE]') return;
      if (data.isEmpty) continue;
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        final mapped = Map<String, dynamic>.from(decoded);
        _throwEmbeddedToolError(mapped);
        yield mapped;
      }
    }
  }

  static Future<Map<String, dynamic>> _postToolCompletion(
    Dio dio,
    Map<String, Object?> payload, {
    bool retryWithoutToolChoice = true,
    int strippedParameterCount = 0,
  }) async {
    try {
      final response = await dio.post<dynamic>(
        '/chat/completions',
        data: payload,
      );
      final data = response.data;
      if (data is! Map) throw const FormatException();
      final mapped = Map<String, dynamic>.from(data);
      _throwEmbeddedToolError(mapped);
      return mapped;
    } on DioException catch (error) {
      final message = _extractDioError(error);
      final rejected = rejectedChatParam(
        Map<String, dynamic>.from(payload),
        error.response?.statusCode,
        error.response?.data?.toString() ?? message,
      );
      final mayStrip = rejected != null &&
          rejected != 'tools' &&
          (rejected != 'tool_choice' || retryWithoutToolChoice) &&
          strippedParameterCount < _maxParamStrips;
      if (mayStrip) {
        logger.info('AgentNativeTools', '服务商不接受 $rejected，移除后重试');
        return _postToolCompletion(
          dio,
          Map<String, Object?>.of(payload)..remove(rejected),
          retryWithoutToolChoice: retryWithoutToolChoice,
          strippedParameterCount: strippedParameterCount + 1,
        );
      }
      rethrow;
    }
  }

  static Map<String, dynamic> _normalizeCompletion(
    Map<String, dynamic> completion,
  ) {
    _throwEmbeddedToolError(completion);
    final choices = completion['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const FormatException();
    }
    final choice = Map<String, dynamic>.from(choices.first as Map);
    final message = choice['message'];
    if (message is! Map) throw const FormatException();
    final delta = <String, Object?>{};
    if (message['content'] case final String content when content.isNotEmpty) {
      delta['content'] = content;
    }
    if (message['tool_calls'] case final List calls) {
      delta['tool_calls'] = [
        for (var index = 0; index < calls.length; index++)
          if (calls[index] is Map)
            _normalizeToolCall(calls[index] as Map, index),
      ];
    }
    return {
      'choices': [
        {
          'delta': delta,
          'finish_reason': choice['finish_reason'] ??
              (delta.containsKey('tool_calls') ? 'tool_calls' : 'stop'),
        },
      ],
    };
  }

  static Map<String, dynamic> _normalizeToolCall(Map raw, int index) {
    final call = Map<String, dynamic>.from(raw);
    final rawFunction = call['function'];
    if (rawFunction is Map) {
      final function = Map<String, dynamic>.from(rawFunction);
      final arguments = function['arguments'];
      if (arguments != null && arguments is! String) {
        function['arguments'] = jsonEncode(arguments);
      }
      call['function'] = function;
    }
    return {'index': index, ...call};
  }

  static void _throwEmbeddedToolError(Map<String, dynamic> response) {
    final error = response['error'];
    if (error == null) return;
    final message = error is Map
        ? (error['message'] ?? error['msg'] ?? error).toString()
        : error.toString();
    throw AIException(
      message,
      code: classifyProviderError(null, message, toolRequest: true),
    );
  }

  static bool _mayRejectStreaming(DioException error) {
    final status = error.response?.statusCode;
    if (status == 400 || status == 405 || status == 415 || status == 422) {
      return true;
    }
    return classifyProviderError(status, error.response?.data) ==
        AIExceptionCode.streamingUnsupported;
  }

  static AIException _toolRequestException(DioException error) => AIException(
        _extractDioError(error, logTag: 'AgentNativeTools'),
        code: classifyProviderError(
          error.response?.statusCode,
          error.response?.data,
          toolRequest: true,
        ),
      );

  /// 把底层异常转换为可直接展示的文本，避免泄露 Dio/Dart 实现细节。
  static String userFacingError(
    Object error, {
    String prefix = '验证失败',
  }) {
    final String detail;
    if (error is AIException) {
      detail = error.message;
    } else if (error is OpenAIException) {
      detail = error.userMessage;
    } else if (error is DioException) {
      detail = OpenAIException.fromDioException(error).userMessage;
    } else {
      detail = '服务商返回了无法识别的响应，请检查模型名称和接口兼容性';
    }
    return '$prefix：$detail';
  }

  /// Classifies only explicit provider signals; a generic occurrence of the
  /// word "tool" is not enough to label a model as incompatible.
  @visibleForTesting
  static AIExceptionCode classifyProviderError(
    int? statusCode,
    Object? responseData, {
    bool toolRequest = false,
  }) {
    final normalized = responseData is String
        ? responseData.toLowerCase()
        : jsonEncode(responseData).toLowerCase();
    if (statusCode == 401 || statusCode == 403) {
      return AIExceptionCode.unauthorized;
    }
    if (statusCode == 429) return AIExceptionCode.rateLimited;
    const nativeToolSignals = <String>[
      'does not support tools',
      'tools are not supported',
      'tool calls are not supported',
      'function calling is not supported',
      'function_call is not supported',
      'unsupported parameter: tools',
      'unsupported field: tools',
      'unknown field: tools',
      'unrecognized request argument supplied: tools',
      '不支持原生工具',
      '不支持工具调用',
      '不支持 function calling',
    ];
    if (nativeToolSignals.any(normalized.contains)) {
      return AIExceptionCode.nativeToolsUnsupported;
    }
    const streamingSignals = <String>[
      'stream is not supported',
      'streaming is not supported',
      'unsupported parameter: stream',
      '不支持流式',
    ];
    if (streamingSignals.any(normalized.contains)) {
      return AIExceptionCode.streamingUnsupported;
    }
    if (toolRequest &&
        (statusCode == 404 || statusCode == 405) &&
        (normalized.contains('function calling') ||
            normalized.contains('tool calls'))) {
      return AIExceptionCode.nativeToolsUnsupported;
    }
    return AIExceptionCode.unknown;
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
    void Function(AgentModelCapabilities capabilities)? onCapabilities,
    @visibleForTesting Dio? client,
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
        response = await _chatOpenAI(
          config,
          'hi',
          null,
          0.7,
          client: client,
        );
      }

      if (response.isNotEmpty) {
        final capabilities = await probeAgentCapabilities(
          config,
          probeStreaming: true,
          logTag: tag,
          client: client,
        );
        onCapabilities?.call(capabilities);
        if (!capabilities.canRunNativeToolAgent) {
          return (
            false,
            capabilities.detail ??
                '普通文本对话可用，但该模型未返回原生工具调用，无法用于账本 Agent。请切换支持 function calling/tool calls 的模型。',
          );
        }
        logger.info(tag, '文本与 Agent 工具能力验证成功: ${config.name}');
        return (true, capabilities.detail);
      } else {
        return (false, 'API返回空响应');
      }
    } on AIException catch (e) {
      logger.warning(tag, '文本能力验证失败: ${e.message}');
      return (false, e.message);
    } catch (e, st) {
      logger.error(tag, '文本能力验证异常', e, st);
      return (false, userFacingError(e));
    }
  }

  /// Probes native function calling with synthetic data only.
  ///
  /// Forced tool choice is attempted first, then `auto`. A model is considered
  /// Agent-capable only when it returns a structured `tool_calls` entry; plain
  /// text claiming that it called a tool does not pass the probe.
  static Future<AgentModelCapabilities> probeAgentCapabilities(
    AIServiceProviderConfig config, {
    bool probeStreaming = false,
    String? logTag,
    @visibleForTesting Dio? client,
  }) async {
    if (!config.isValid || !config.supportsText) {
      return AgentModelCapabilities(
        text: config.supportsText
            ? AgentCapabilitySupport.unknown
            : AgentCapabilitySupport.unsupported,
        nativeToolCalls: AgentCapabilitySupport.unsupported,
        detail: config.isValid ? '未配置文本模型' : '未配置 API Key',
      );
    }
    final dio = client ?? _getDio(config);
    const probeName = 'beecount_agent_capability_probe';
    const tools = <Map<String, Object?>>[
      {
        'type': 'function',
        'function': {
          'name': probeName,
          'description': '用于检查模型是否支持结构化原生工具调用，不访问任何用户数据。',
          'parameters': {
            'type': 'object',
            'properties': {
              'value': {
                'type': 'string',
                'enum': ['ok']
              },
            },
            'required': ['value'],
            'additionalProperties': false,
          },
        },
      },
    ];
    const messages = <Map<String, Object?>>[
      {
        'role': 'user',
        'content':
            '请调用 beecount_agent_capability_probe，参数 value 必须是 ok。不要输出普通文本。',
      },
    ];
    final base = <String, Object?>{
      'model': config.textModel,
      'messages': messages,
      'tools': tools,
      'temperature': 0,
      'stream': false,
    };
    var forced = AgentCapabilitySupport.unknown;
    Map<String, dynamic>? response;
    Object? forcedError;
    try {
      response = await _postToolCompletion(
        dio,
        {
          ...base,
          'tool_choice': {
            'type': 'function',
            'function': {'name': probeName},
          },
        },
        retryWithoutToolChoice: false,
      );
      forced = _hasToolCall(response, probeName)
          ? AgentCapabilitySupport.supported
          : AgentCapabilitySupport.unknown;
    } on Object catch (error) {
      forcedError = error;
      forced = AgentCapabilitySupport.unsupported;
    }

    if (response == null || !_hasToolCall(response, probeName)) {
      try {
        response = await _postToolCompletion(
          dio,
          {...base, 'tool_choice': 'auto'},
        );
      } on DioException catch (error) {
        final exception = _toolRequestException(error);
        final support = exception.code == AIExceptionCode.nativeToolsUnsupported
            ? AgentCapabilitySupport.unsupported
            : AgentCapabilitySupport.unknown;
        logger.warning(logTag ?? 'AgentCapability', '原生工具能力探测失败', {
          'provider': config.name,
          'model': config.textModel,
          'error': exception.message,
        });
        return AgentModelCapabilities(
          text: AgentCapabilitySupport.supported,
          nativeToolCalls: support,
          forcedToolChoice: forced,
          detail: support == AgentCapabilitySupport.unsupported
              ? '普通文本对话可用，但模型或接口不支持原生工具调用（tool calls/function calling）。'
              : '普通文本对话可用，但暂时无法确认原生工具能力：${exception.message}',
        );
      } on Object catch (error) {
        return AgentModelCapabilities(
          text: AgentCapabilitySupport.supported,
          nativeToolCalls: AgentCapabilitySupport.unknown,
          forcedToolChoice: forced,
          detail: '普通文本对话可用，但${userFacingError(error, prefix: '工具能力探测失败')}',
        );
      }
    }

    if (!_hasToolCall(response, probeName)) {
      return AgentModelCapabilities(
        text: AgentCapabilitySupport.supported,
        nativeToolCalls: AgentCapabilitySupport.unsupported,
        forcedToolChoice: forced,
        detail: '普通文本对话可用，但模型没有返回结构化 tool_calls，无法可靠读取或操作账本。',
        metadata: {
          if (forcedError != null) 'forcedToolChoiceError': '$forcedError',
        },
      );
    }

    var streaming = AgentCapabilitySupport.unknown;
    if (probeStreaming) {
      final streamingPayload = <String, Object?>{
        ...base,
        'stream': true,
        'tool_choice': 'auto',
      }..remove('temperature');
      streaming = await _probeToolStreaming(dio, streamingPayload);
    }
    final detail = streaming == AgentCapabilitySupport.unsupported
        ? '原生工具调用可用；服务商不支持 SSE 工具流，运行时会自动使用非流式兼容模式。'
        : '原生工具调用可用。';
    return AgentModelCapabilities(
      text: AgentCapabilitySupport.supported,
      nativeToolCalls: AgentCapabilitySupport.supported,
      streaming: streaming,
      forcedToolChoice: forced,
      detail: detail,
    );
  }

  static bool _hasToolCall(Map<String, dynamic>? response, String name) {
    final choices = response?['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      return false;
    }
    final message = (choices.first as Map)['message'];
    if (message is! Map || message['tool_calls'] is! List) return false;
    for (final call in (message['tool_calls'] as List).whereType<Map>()) {
      final function = call['function'];
      if (function is Map && function['name'] == name) return true;
    }
    return false;
  }

  static Future<AgentCapabilitySupport> _probeToolStreaming(
    Dio dio,
    Map<String, Object?> payload,
  ) async {
    try {
      final response = await dio.post<ResponseBody>(
        '/chat/completions',
        data: payload,
        options: Options(responseType: ResponseType.stream),
      );
      final body = response.data;
      if (body == null) return AgentCapabilitySupport.unknown;
      final contentType =
          response.headers.value(Headers.contentTypeHeader)?.toLowerCase() ??
              '';
      // Drain the small synthetic response so the connection can be reused.
      await body.stream.drain<void>();
      return contentType.contains('text/event-stream')
          ? AgentCapabilitySupport.supported
          : AgentCapabilitySupport.unsupported;
    } on DioException catch (error) {
      await OpenAIException.decodeStreamErrorResponse(error);
      return _mayRejectStreaming(error)
          ? AgentCapabilitySupport.unsupported
          : AgentCapabilitySupport.unknown;
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
      return (false, userFacingError(e));
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
      return (false, userFacingError(e));
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
      // 视觉模型处理大图更慢，给 120s 避免误超时
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 120),
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
      // 语音需上传音频文件，给更长的发送和接收超时
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 120),
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

  // 结构上必须保留的键;其余键(temperature 等)被上游拒绝时可摘掉重发。
  static const _requiredChatKeys = {'model', 'messages', 'stream'};
  static const _maxParamStrips = 3;

  /// 上游因「参数不合法」报 4xx 时,返回它点名的那个可丢键(候选只来自我们发出去的键)。
  ///
  /// 推理模型(Moonshot kimi-k2.5 / OpenAI o1·o3 / DeepSeek-R1)把 temperature 锁死成 1,
  /// 发其他值返回 400「invalid temperature: only 1 is allowed for this model」即走这里。
  /// 不写死参数名/模型名,而是看错误文案点了我们发出去的哪个键。
  @visibleForTesting
  static String? rejectedChatParam(
    Map<String, dynamic> payload,
    int? statusCode,
    String errorBody,
  ) {
    if (statusCode == null || statusCode < 400) return null;
    final low = errorBody.toLowerCase();
    for (final key in payload.keys) {
      if (!_requiredChatKeys.contains(key) && low.contains(key.toLowerCase())) {
        return key;
      }
    }
    return null;
  }

  /// POST /chat/completions;被某个可选参数拒就摘掉重发,最多 [_maxParamStrips] 次。
  ///
  /// 普通模型:参数都合法 → 一次成功,行为不变(只有 4xx 才会进摘参数逻辑)。
  /// 推理模型:temperature 等被锁 → 摘掉 → 用模型默认值,通过。
  static Future<Response<dynamic>> _postChatCompletions(
    Dio dio,
    Map<String, dynamic> body,
  ) async {
    var payload = Map<String, dynamic>.of(body);
    for (var attempt = 0;; attempt++) {
      try {
        return await dio.post('/chat/completions', data: payload);
      } on DioException catch (e) {
        final param = rejectedChatParam(
          payload,
          e.response?.statusCode,
          e.response?.data?.toString() ?? '',
        );
        if (param == null || attempt >= _maxParamStrips) rethrow;
        logger.warning('AIFactory', '上游拒绝参数 $param,去掉重发');
        payload = Map<String, dynamic>.of(payload)..remove(param);
      }
    }
  }

  static Future<String> _chatOpenAI(
    AIServiceProviderConfig config,
    String prompt,
    String? systemPrompt,
    double temperature, {
    Dio? client,
  }) async {
    final dio = client ?? _getDio(config);

    final messages = <Map<String, dynamic>>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

    logger.debug('AIFactory', '请求: ${config.baseUrl}/chat/completions');

    try {
      final response = await _postChatCompletions(dio, {
        'model': config.textModel,
        'messages': messages,
        'temperature': temperature,
      });

      return _extractChatContent(response, capability: '文本');
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

      return _extractChatContent(response, capability: '视觉');
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

      final data = _responseData(response, capability: '语音');
      final text = data['text'];
      if (text is! String) {
        throw AIException('服务商返回了无法识别的语音响应（缺少 text）');
      }
      return text.trim();
    } on DioException catch (e) {
      throw AIException(_extractDioError(e));
    }
  }

  static Map<String, dynamic> _responseData(
    Response<dynamic> response, {
    required String capability,
  }) {
    final rawData = response.data;
    if (rawData is! Map) {
      throw AIException('服务商返回了无法识别的$capability响应（不是 JSON 对象）');
    }
    final data = Map<String, dynamic>.from(rawData);
    if (data['error'] != null) {
      throw AIException(
        OpenAIException.fromResponse(response.statusCode, data).userMessage,
      );
    }
    return data;
  }

  static String _extractChatContent(
    Response<dynamic> response, {
    required String capability,
  }) {
    final data = _responseData(response, capability: capability);
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw AIException('服务商返回了无法识别的$capability响应（缺少 choices）');
    }
    final message = (choices.first as Map)['message'];
    if (message is! Map || message['content'] is! String) {
      throw AIException('服务商返回了无法识别的$capability响应（缺少消息内容）');
    }
    return message['content'] as String;
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

    return OpenAIException.fromDioException(e).userMessage;
  }
}

enum AIExceptionCode {
  unknown,
  nativeToolsUnsupported,
  streamingUnsupported,
  invalidResponse,
  unauthorized,
  rateLimited,
}

/// AI 异常
class AIException implements Exception {
  final String message;
  final AIExceptionCode code;

  AIException(this.message, {this.code = AIExceptionCode.unknown});

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
