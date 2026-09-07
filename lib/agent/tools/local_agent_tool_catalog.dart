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
        'description': '查询结束时间，ISO 8601 格式（不包含）。',
      },
    },
    'additionalProperties': false,
  };

  static const _transactionSummaryParameters = <String, Object?>{
    'type': 'object',
    'properties': {
      'start': {
        'type': 'string',
        'description': '查询开始时间，ISO 8601 格式（包含）。',
      },
      'end': {
        'type': 'string',
        'description': '查询结束时间，ISO 8601 格式（不包含）。',
      },
      'types': {
        'type': 'array',
        'description': '需要统计的交易类型；不传表示收入、支出和转账全部统计。',
        'items': {
          'type': 'string',
          'enum': ['income', 'expense', 'transfer'],
        },
        'uniqueItems': true,
      },
      'groupBy': {
        'type': 'string',
        'description':
            '可选分组维度；none 表示只返回总额。用户说“每天/按日”时传 day，“每周/按周”时传 week，“每月/按月”时传 month，“每年/按年”时传 year；趋势或分布问题首次调用也必须传入对应维度。',
        'enum': [
          'none',
          'category',
          'tag',
          'account',
          'day',
          'week',
          'month',
          'year',
        ],
      },
      'categoryLevel': {
        'type': 'string',
        'description': '按分类分组时使用 leaf 明细分类或 top 一级分类。',
        'enum': ['leaf', 'top'],
      },
      'categoryIds': {
        'type': 'array',
        'description': '只统计指定分类 ID（转账账户不受此筛选影响）；与 categoryNames 为或关系。',
        'items': {'type': 'integer', 'minimum': 1},
        'uniqueItems': true,
      },
      'categoryNames': {
        'type': 'array',
        'description': '按分类名称筛选，名称会去除首尾空格并忽略大小写；与 categoryIds 为或关系。',
        'items': {'type': 'string', 'minLength': 1},
        'uniqueItems': true,
      },
      'tagIds': {
        'type': 'array',
        'description': '只统计带有任一指定标签 ID 的交易；与 tagNames 为或关系。',
        'items': {'type': 'integer', 'minimum': 1},
        'uniqueItems': true,
      },
      'tagNames': {
        'type': 'array',
        'description': '按标签名称筛选，名称会去除首尾空格并忽略大小写；与 tagIds 为或关系。',
        'items': {'type': 'string', 'minLength': 1},
        'uniqueItems': true,
      },
      'accountIds': {
        'type': 'array',
        'description': '只统计涉及任一指定账户 ID 的交易（转账会检查转出和转入账户）；与 accountNames 为或关系。',
        'items': {'type': 'integer', 'minimum': 1},
        'uniqueItems': true,
      },
      'accountNames': {
        'type': 'array',
        'description':
            '按账户名称筛选，名称会去除首尾空格并忽略大小写（转账会检查转出和转入账户）；与 accountIds 为或关系。',
        'items': {'type': 'string', 'minLength': 1},
        'uniqueItems': true,
      },
      'includeExcludedFromStats': {
        'type': 'boolean',
        'description': '是否包含标记为不计入统计的交易，默认 false。',
      },
      'groupLimit': {
        'type': 'integer',
        'description': '最多返回的分组数量，超出部分合并到“其他”，默认 20，范围 1-50。',
        'minimum': 1,
        'maximum': 50,
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
          '查询当前账本在时间范围内的交易明细，只读，不会修改数据。start 包含、end 不包含；缺少时间范围时使用最近 30 天。最多返回 20 条，适合用户明确要求查看明细或最近几笔交易，不适合计算总额或趋势。每条结果含交易原币金额、账本本位币金额、分类、转出/转入账户、标签、时间、备注及统计/预算排除状态。',
      parameters: _rangeParameters,
    ),
    core.AgentNativeToolDefinition(
      name: 'get_transaction_summary',
      description:
          '在数据库内直接聚合当前账本的交易，不受明细查询条数限制。只读，不会修改数据。start 包含、end 不包含；缺少时间范围时使用最近 30 天。types 不传表示收入、支出和转账全部统计；groupBy 不传表示只返回总额，也可按分类、标签、账户或日/周/月/年分组。可用 ID 或名称筛选分类、标签和账户；金额均为账本本位币。返回 currency、periodStart、periodEnd、types、totals、groups、truncated；按标签分组时交易可能出现在多个标签组，按账户分组时转账会分别提供 transferOut 和 transferIn。聚合问题优先使用本工具，不要用明细列表自行汇总。',
      parameters: _transactionSummaryParameters,
    ),
    core.AgentNativeToolDefinition(
      name: 'get_budget_status',
      description:
          '读取当前账本的预算快照，只读，不会修改数据，不需要参数。结果含 currency、daysRemaining、dailyAvailable、total 预算使用情况及 categoryBudgets 分类预算使用情况；每项包含已用、预算、剩余、使用率和状态。',
      parameters: _emptyParameters,
    ),
    core.AgentNativeToolDefinition(
      name: 'get_recurring_transactions',
      description:
          '读取当前账本启用中的周期记账，只读，不会修改数据，不需要参数。结果是 items 列表，包含金额、币种、收入/支出类型、分类、账户、重复频率和间隔、起止日期、最近生成日期及备注。',
      parameters: _emptyParameters,
    ),
    core.AgentNativeToolDefinition(
      name: 'record_transaction_from_text',
      description:
          '将当前用户明确提供的原始交易文本记录到当前账本，会创建本地交易数据，属于写操作，需要通过权限策略。sourceText 必须逐字等于当前用户消息；同一条消息只允许成功记账一次。成功结果返回最终落库的交易 ID、完整交易明细、关联分类、账户、标签和未转换币种；不要把保存前的推测当成结果。',
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
      description:
          '保存用户明确要求长期记住的信息，仅写入本地记忆，属于写操作，需要通过权限策略。只有用户明确说“记住/保存/以后记得”等意图时才可调用。成功结果返回 saved 和 memoryId，供后续精确遗忘。',
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
          '删除用户明确指定的本地记忆，只影响当前应用中的本地记录，属于写操作，需要通过权限策略。只有用户明确要求忘记且提供目标记忆 ID 时才可调用。结果返回 forgotten，不泄露其他账本信息。',
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
