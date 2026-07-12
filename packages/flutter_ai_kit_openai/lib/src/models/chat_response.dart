import 'package:json_annotation/json_annotation.dart';
import 'chat_message.dart';

part 'chat_response.g.dart';

/// Chat API 响应
@JsonSerializable()
class ChatResponse {
  /// 响应 ID
  final String id;

  /// 对象类型
  final String object;

  /// 创建时间戳
  final int created;

  /// 模型名称
  final String model;

  /// 选择项列表
  final List<Choice> choices;

  /// 使用量统计
  final Usage usage;

  ChatResponse({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
    required this.usage,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) =>
      _$ChatResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ChatResponseToJson(this);
}

/// 选择项
@JsonSerializable()
class Choice {
  /// 索引
  final int index;

  /// 消息
  final ChatMessage message;

  /// 结束原因
  @JsonKey(name: 'finish_reason')
  final String finishReason;

  Choice({
    required this.index,
    required this.message,
    required this.finishReason,
  });

  factory Choice.fromJson(Map<String, dynamic> json) => _$ChoiceFromJson(json);

  Map<String, dynamic> toJson() => _$ChoiceToJson(this);
}

/// 使用量统计
@JsonSerializable()
class Usage {
  /// 提示 token 数
  @JsonKey(name: 'prompt_tokens')
  final int promptTokens;

  /// 完成 token 数
  @JsonKey(name: 'completion_tokens')
  final int completionTokens;

  /// 总 token 数
  @JsonKey(name: 'total_tokens')
  final int totalTokens;

  Usage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  factory Usage.fromJson(Map<String, dynamic> json) => _$UsageFromJson(json);

  Map<String, dynamic> toJson() => _$UsageToJson(this);
}
