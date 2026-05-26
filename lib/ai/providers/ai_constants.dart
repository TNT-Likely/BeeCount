/// AI 服务相关常量
class AIConstants {
  AIConstants._();

  // SharedPreferences Keys & YAML Keys (统一使用)
  static const String keyGlmApiKey = 'ai_glm_api_key';
  static const String keyGlmModel = 'ai_glm_model';
  static const String keyGlmVisionModel = 'ai_glm_vision_model';
  static const String keyGlmAudioModel = 'ai_glm_audio_model';
  static const String keyAiStrategy = 'ai_strategy';
  static const String keyAiBillExtractionEnabled = 'ai_bill_extraction_enabled';
  static const String keyAiUseVision = 'ai_use_vision';
  static const String keyAiCustomPrompt = 'ai_custom_prompt';

  // OpenAI 兼容协议配置
  static const String keyAiServiceProvider = 'ai_service_provider';
  static const String keyCustomBaseUrl = 'ai_custom_base_url';
  static const String keyCustomDefaultModel = 'ai_custom_default_model';
  static const String keyCustomApiKey = 'ai_custom_api_key';
  static const String keyCustomTextModel = 'ai_custom_text_model';
  static const String keyCustomVisionModel = 'ai_custom_vision_model';
  static const String keyCustomAudioModel = 'ai_custom_audio_model';

  // 默认模型
  /// 默认文本模型
  static const String defaultGlmModel = 'glm-4-flash';

  /// 默认视觉模型
  static const String defaultGlmVisionModel = 'glm-4v-flash';

  /// 默认语音模型（GLM 暂不支持语音转文字接口）
  static const String defaultGlmAudioModel = 'glm-4-voice';

  /// 默认执行策略
  static const String defaultStrategy = 'cloud_first';

  // GLM 可选模型列表（简化版，与旧版一致）
  /// 文本模型列表
  static const List<String> glmTextModels = [
    'glm-4-flash',
    'glm-4.6',
  ];

  /// 视觉模型列表
  static const List<String> glmVisionModels = [
    'glm-4v-flash',
    'glm-4.6v',
  ];

  /// 语音模型列表
  static const List<String> glmAudioModels = [
    'glm-4-voice',
  ];

  /// 获取模型显示名称
  static String getModelDisplayName(String modelId, {String? fastLabel, String? accurateLabel}) {
    final fast = fastLabel ?? '快速';
    final accurate = accurateLabel ?? '精准';

    switch (modelId) {
      // 文本模型
      case 'glm-4-flash':
        return 'GLM-4-Flash（$fast）';
      case 'glm-4.6':
        return 'GLM-4.6（$accurate）';
      // 视觉模型
      case 'glm-4v-flash':
        return 'GLM-4V-Flash（$fast）';
      case 'glm-4.6v':
        return 'GLM-4.6V（$accurate）';
      // 语音模型
      case 'glm-4-voice':
        return 'GLM-4-Voice（语音）';
      default:
        return modelId;
    }
  }
}
