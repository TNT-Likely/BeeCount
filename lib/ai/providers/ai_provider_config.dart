/// AI 服务商配置
///
/// 存储单个服务商的完整配置信息
class AIServiceProviderConfig {
  /// 唯一标识（UUID）
  final String id;

  /// 显示名称（如"智谱GLM"、"硅基流动"）
  final String name;

  /// 是否为内置服务商（智谱GLM 是内置的，不可删除）
  final bool isBuiltIn;

  /// API Key
  final String apiKey;

  /// Base URL（自定义服务商必填）
  final String baseUrl;

  /// 文本模型
  final String textModel;

  /// 视觉模型
  final String visionModel;

  /// 语音模型
  final String audioModel;

  /// 创建时间
  final DateTime createdAt;

  const AIServiceProviderConfig({
    required this.id,
    required this.name,
    this.isBuiltIn = false,
    this.apiKey = '',
    this.baseUrl = '',
    this.textModel = '',
    this.visionModel = '',
    this.audioModel = '',
    required this.createdAt,
  });

  /// 智谱GLM 默认配置
  static AIServiceProviderConfig get zhipuDefault => AIServiceProviderConfig(
        id: 'zhipu_glm',
        name: '智谱GLM',
        isBuiltIn: true,
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        textModel: 'glm-4-flash',
        visionModel: 'glm-4v-flash',
        audioModel: 'glm-4-voice',
        createdAt: DateTime(2024, 1, 1),
      );

  /// 配置是否有效（至少有 API Key）
  bool get isValid => apiKey.isNotEmpty;

  /// 是否支持文本对话
  bool get supportsText => textModel.isNotEmpty;

  /// 是否支持图片理解
  bool get supportsVision => visionModel.isNotEmpty;

  /// 是否支持语音转文字
  bool get supportsSpeech => audioModel.isNotEmpty;

  /// 复制并修改
  AIServiceProviderConfig copyWith({
    String? id,
    String? name,
    bool? isBuiltIn,
    String? apiKey,
    String? baseUrl,
    String? textModel,
    String? visionModel,
    String? audioModel,
    DateTime? createdAt,
  }) {
    return AIServiceProviderConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      textModel: textModel ?? this.textModel,
      visionModel: visionModel ?? this.visionModel,
      audioModel: audioModel ?? this.audioModel,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 从 JSON 创建
  factory AIServiceProviderConfig.fromJson(Map<String, dynamic> json) {
    return AIServiceProviderConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      apiKey: json['apiKey'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      textModel: json['textModel'] as String? ?? '',
      visionModel: json['visionModel'] as String? ?? '',
      audioModel: json['audioModel'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isBuiltIn': isBuiltIn,
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'textModel': textModel,
      'visionModel': visionModel,
      'audioModel': audioModel,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'AIServiceProviderConfig(id: $id, name: $name)';
}

/// AI 能力绑定配置
///
/// 存储每种能力使用哪个服务商
class AICapabilityBinding {
  /// 文本对话使用的服务商 ID
  final String? textProviderId;

  /// 图片理解使用的服务商 ID
  final String? visionProviderId;

  /// 语音转文字使用的服务商 ID
  final String? speechProviderId;

  const AICapabilityBinding({
    this.textProviderId,
    this.visionProviderId,
    this.speechProviderId,
  });

  /// 默认绑定（全部使用智谱GLM）
  static const AICapabilityBinding defaultBinding = AICapabilityBinding(
    textProviderId: 'zhipu_glm',
    visionProviderId: 'zhipu_glm',
    speechProviderId: 'zhipu_glm',
  );

  /// 复制并修改
  AICapabilityBinding copyWith({
    String? textProviderId,
    String? visionProviderId,
    String? speechProviderId,
  }) {
    return AICapabilityBinding(
      textProviderId: textProviderId ?? this.textProviderId,
      visionProviderId: visionProviderId ?? this.visionProviderId,
      speechProviderId: speechProviderId ?? this.speechProviderId,
    );
  }

  /// 从 JSON 创建
  factory AICapabilityBinding.fromJson(Map<String, dynamic> json) {
    return AICapabilityBinding(
      textProviderId: json['textProviderId'] as String?,
      visionProviderId: json['visionProviderId'] as String?,
      speechProviderId: json['speechProviderId'] as String?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'textProviderId': textProviderId,
      'visionProviderId': visionProviderId,
      'speechProviderId': speechProviderId,
    };
  }
}

/// AI 能力类型
enum AICapabilityType {
  /// 文本对话
  text,

  /// 图片理解
  vision,

  /// 语音转文字
  speech,
}

extension AICapabilityTypeExtension on AICapabilityType {
  String get displayName {
    switch (this) {
      case AICapabilityType.text:
        return '文本对话';
      case AICapabilityType.vision:
        return '图片理解';
      case AICapabilityType.speech:
        return '语音转文字';
    }
  }

  String get icon {
    switch (this) {
      case AICapabilityType.text:
        return '💬';
      case AICapabilityType.vision:
        return '🖼️';
      case AICapabilityType.speech:
        return '🎤';
    }
  }
}
