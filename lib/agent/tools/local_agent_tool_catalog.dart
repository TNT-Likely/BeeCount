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
      description:
          '查询当前账本在指定时间范围内的交易明细，只读，不会修改数据。结果含交易原币金额、账本本位币金额、分类、转出/转入账户、标签和统计/预算排除状态。',
      parameters: _rangeParameters,
    ),
    core.AgentNativeToolDefinition(
      name: 'get_spending_summary',
      description: '按账本本位币汇总当前账本在指定时间范围内的支出总额，只读，不会修改数据。多币种交易已使用各笔已保存的本位币折算金额。',
      parameters: _rangeParameters,
    ),
    core.AgentNativeToolDefinition(
      name: 'get_budget_status',
      description: '读取当前账本的预算快照，只读，不会修改数据。结果含本位币、总预算和分类预算的已用、剩余、使用率、状态及日均可用额度。',
      parameters: _emptyParameters,
    ),
    core.AgentNativeToolDefinition(
      name: 'get_recurring_transactions',
      description: '读取当前账本启用中的周期记账，只读，不会修改数据。结果含分类、账户、币种、重复规则、起止时间和最近生成时间。',
      parameters: _emptyParameters,
    ),
    core.AgentNativeToolDefinition(
      name: 'record_transaction_from_text',
      description:
          '将当前用户明确提供的原始交易文本记录到当前账本，会创建交易数据。成功结果返回最终落库的交易明细；不要把保存前的推测当成结果。',
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
      description: '保存用户明确要求长期记住的信息，仅写入本地记忆。成功结果会返回记忆 ID，供后续精确遗忘。',
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
      description:
          '删除用户明确指定的本地记忆，只影响当前应用中的记忆记录。结果只说明当前账本内该 ID 是否成功遗忘，不泄露其他账本信息。',
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
