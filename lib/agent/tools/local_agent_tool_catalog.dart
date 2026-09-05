import 'package:agentcore/agentcore.dart' as core;

/// Business-owned metadata sent to the model for the local Agent tools.
///
/// The generic agentcore package only knows how to transport this metadata;
/// BeeCount owns the names, descriptions, and argument schemas because they
/// describe BeeCount's local accounting capabilities.
final class LocalAgentToolCatalog {
  const LocalAgentToolCatalog._();

  static const _rangeParameters = <String, Object?>{
    'type': 'object',
    'properties': {
      'start': {
        'type': 'string',
        'description': '查询开始时间，ISO 8601 格式（包含）。',
      },
      'end': {
        'type': 'string',
        'description': '查询结束时间，ISO 8601 格式（包含）。',
      },
    },
    'additionalProperties': false,
  };

  static const _emptyParameters = <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{},
    'additionalProperties': false,
  };

  static const definitions = <core.AgentNativeToolDefinition>[
    core.AgentNativeToolDefinition(
      name: 'query_transactions',
      description: '查询当前账本在指定时间范围内的交易明细，只读，不会修改数据。',
      parameters: _rangeParameters,
    ),
    core.AgentNativeToolDefinition(
      name: 'get_spending_summary',
      description: '汇总当前账本在指定时间范围内的支出总额，只读，不会修改数据。',
      parameters: _rangeParameters,
    ),
    core.AgentNativeToolDefinition(
      name: 'get_budget_status',
      description: '读取当前账本的预算使用情况和可用额度，只读，不会修改数据。',
      parameters: _emptyParameters,
    ),
    core.AgentNativeToolDefinition(
      name: 'record_transaction_from_text',
      description: '将当前用户明确提供的原始交易文本记录到当前账本，会创建交易数据。',
      parameters: {
        'type': 'object',
        'properties': {
          'sourceText': {
            'type': 'string',
            'description': '原始交易文本，必须逐字等于用户当前消息。',
            'minLength': 1,
          },
        },
        'required': ['sourceText'],
        'additionalProperties': false,
      },
    ),
    core.AgentNativeToolDefinition(
      name: 'save_explicit_memory',
      description: '保存用户明确要求长期记住的信息，仅写入本地记忆。',
      parameters: {
        'type': 'object',
        'properties': {
          'content': {
            'type': 'string',
            'description': '用户明确要求长期记住的内容。',
            'minLength': 1,
          },
        },
        'required': ['content'],
        'additionalProperties': false,
      },
    ),
    core.AgentNativeToolDefinition(
      name: 'forget_memory',
      description: '删除用户明确指定的本地记忆，只影响当前应用中的记忆记录。',
      parameters: {
        'type': 'object',
        'properties': {
          'memoryId': {
            'type': 'integer',
            'description': '要删除的记忆 ID。',
            'minimum': 1,
          },
        },
        'required': ['memoryId'],
        'additionalProperties': false,
      },
    ),
  ];
}
