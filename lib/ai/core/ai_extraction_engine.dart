import 'dart:io';

import '../providers/ai_provider_factory.dart';
import '../../services/system/logger_service.dart';
import 'ai_extraction_context.dart';
import 'bill_info.dart';
import 'json_response_parser.dart';
import 'prompt_builder.dart';

/// AI 多模态记账底座 · 提取引擎。
///
/// 把 text / image / audio 输入 + [AiExtractionContext] 转换成
/// `List<BillInfo>`。这一层是 Layer 1 底座的对外契约,不依赖 Repository /
/// Riverpod / UI,可以独立单测。
abstract class AiExtractionEngine {
  /// 从文本提取账单信息。空 list 表示失败或无有效账单。
  Future<List<BillInfo>> extractFromText(
    String text,
    AiExtractionContext context,
  );

  /// 从图片提取账单信息。空 list 表示失败或无有效账单。
  Future<List<BillInfo>> extractFromImage(
    File image,
    AiExtractionContext context,
  );

  /// 从音频提取账单信息(语音转文字 → 文本提取)。
  Future<AudioExtractionResult> extractFromAudio(
    File audio,
    AiExtractionContext context,
  );

  /// 仅语音转文字,不提取账单。
  Future<String?> speechToText(File audio);
}

/// 音频提取结果(同时返回识别出的原始文本,便于 UI 展示)
class AudioExtractionResult {
  final List<BillInfo> bills;
  final String? recognizedText;

  const AudioExtractionResult({
    this.bills = const [],
    this.recognizedText,
  });
}

/// 默认实现:`PromptBuilder` + `AIProviderFactory` + `JsonResponseParser`。
class DefaultAiExtractionEngine implements AiExtractionEngine {
  static const String _tag = 'AiExtraction';

  final PromptBuilder _promptBuilder;
  final JsonResponseParser _parser;

  const DefaultAiExtractionEngine({
    PromptBuilder promptBuilder = const PromptBuilder(),
    JsonResponseParser parser = const JsonResponseParser(),
  })  : _promptBuilder = promptBuilder,
        _parser = parser;

  @override
  Future<List<BillInfo>> extractFromText(
    String text,
    AiExtractionContext context,
  ) async {
    if (text.trim().isEmpty) {
      logger.warning(_tag, '输入文本为空');
      return const [];
    }
    try {
      final prompt = _promptBuilder.build(
        context: context,
        inputSource: '从以下支付账单文本中',
        ocrText: text,
      );
      logger.debug(_tag, '文本 prompt 长度: ${prompt.length}');
      logger.debug(_tag, '完整 prompt:\n$prompt');

      final response = await AIProviderFactory.chat(
        prompt,
        temperature: 0.3,
        logTag: _tag,
      );
      return _parser.parse(response);
    } on AIException catch (e) {
      logger.warning(_tag, '文本账单提取失败: ${e.message}');
      return const [];
    } catch (e, st) {
      logger.error(_tag, '文本账单提取异常', e, st);
      return const [];
    }
  }

  @override
  Future<List<BillInfo>> extractFromImage(
    File image,
    AiExtractionContext context,
  ) async {
    if (!await image.exists()) {
      logger.warning(_tag, '图片文件不存在');
      return const [];
    }
    try {
      final prompt = _promptBuilder.build(
        context: context,
        inputSource: '分析支付账单截图，从中',
      );
      logger.debug(_tag, '图片 prompt 长度: ${prompt.length}');
      logger.debug(_tag, '完整 prompt:\n$prompt');

      final response = await AIProviderFactory.vision(
        image,
        prompt,
        logTag: _tag,
      );
      return _parser.parse(response);
    } on AIException catch (e) {
      logger.warning(_tag, '图片账单提取失败: ${e.message}');
      return const [];
    } catch (e, st) {
      logger.error(_tag, '图片账单提取异常', e, st);
      return const [];
    }
  }

  @override
  Future<AudioExtractionResult> extractFromAudio(
    File audio,
    AiExtractionContext context,
  ) async {
    if (!await audio.exists()) {
      logger.warning(_tag, '音频文件不存在');
      return const AudioExtractionResult();
    }
    try {
      logger.info(_tag, '步骤1: 语音转文字');
      final recognizedText = await AIProviderFactory.speechToText(
        audio,
        logTag: _tag,
      );
      logger.info(_tag, '识别结果: $recognizedText');
      if (recognizedText.trim().isEmpty) {
        logger.warning(_tag, '语音识别结果为空');
        return const AudioExtractionResult();
      }

      logger.info(_tag, '步骤2: 提取账单信息');
      final bills = await extractFromText(recognizedText, context);
      return AudioExtractionResult(
        bills: bills,
        recognizedText: recognizedText,
      );
    } on AIException catch (e) {
      logger.warning(_tag, '语音账单提取失败: ${e.message}');
      return const AudioExtractionResult();
    } catch (e, st) {
      logger.error(_tag, '语音账单提取异常', e, st);
      return const AudioExtractionResult();
    }
  }

  @override
  Future<String?> speechToText(File audio) async {
    if (!await audio.exists()) {
      logger.warning(_tag, '音频文件不存在');
      return null;
    }
    try {
      final text = await AIProviderFactory.speechToText(audio, logTag: _tag);
      return text.trim().isEmpty ? null : text;
    } on AIException catch (e) {
      logger.warning(_tag, '语音转文字失败: ${e.message}');
      return null;
    } catch (e, st) {
      logger.error(_tag, '语音转文字异常', e, st);
      return null;
    }
  }
}
