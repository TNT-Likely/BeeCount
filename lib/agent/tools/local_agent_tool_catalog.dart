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

  static const _periodProperties = <String, Object?>{
    'period': {
      'type': 'string',
      'description': '常用时间范围。custom 使用 start/end；其他值由应用按当前时间和账本月起始日计算。',
      'enum': [
        'current_month',
        'previous_month',
        'current_year',
        'previous_year',
        'last_30_days',
        'last_90_days',
        'last_3_months',
        'last_6_months',
        'last_12_months',
        'custom',
      ],
    },
    'start': {
      'type': 'string',
      'description': '自定义查询开始时间，ISO 8601 格式（包含）。',
    },
    'end': {
      'type': 'string',
      'description': '自定义查询结束时间，ISO 8601 格式（不包含）。',
    },
  };

  static const _periodOverviewParameters = <String, Object?>{
    'type': 'object',
    'properties': _periodProperties,
    'additionalProperties': false,
  };

  static const _flowTypeProperties = <String, Object?>{
    'flowType': {
      'type': 'string',
      'description':
          '资金方向：expense 为支出（默认），income 为收入。用户询问收入分类'
              '（如捐赠、募资、薪资、副业等分类下都是收入）的金额、趋势、占比或构成时，'
              '必须传 income，否则查不到数据。',
      'enum': ['expense', 'income'],
    },
  };

  static const _spendingTrendParameters = <String, Object?>{
    'type': 'object',
    'properties': {
      ..._periodProperties,
      ..._flowTypeProperties,
      'interval': {
        'type': 'string',
        'description': '趋势粒度，默认 month。',
        'enum': ['day', 'week', 'month', 'year'],
      },
      'categoryNames': {
        'type': 'array',
        'description': '可选分类；选择一级分类时自动包含全部子分类。收入分类须搭配 flowType="income"。',
        'items': {'type': 'string', 'minLength': 1},
        'uniqueItems': true,
      },
      'comparison': {
        'type': 'string',
        'description':
            '比较方式；previous_point 为相邻周期环比，previous_year 为同比。默认 previous_point。',
        'enum': ['none', 'previous_point', 'previous_year'],
      },
    },
    'additionalProperties': false,
  };

  static const _categoryBreakdownParameters = <String, Object?>{
    'type': 'object',
    'properties': {
      ..._periodProperties,
      ..._flowTypeProperties,
      'categoryLevel': {
        'type': 'string',
        'description':
            '必须明确选择：leaf 为明细/子分类，top 为一级分类。用户要求某分类内部、下属分类或明细分类时使用 leaf。',
        'enum': ['leaf', 'top'],
      },
      'categoryNames': {
        'type': 'array',
        'description': '可选分类范围；一级分类会包含全部子分类。收入分类须搭配 flowType="income"。',
        'items': {'type': 'string', 'minLength': 1},
        'uniqueItems': true,
      },
      'limit': {
        'type': 'integer',
        'description': '最多返回的分类数量，默认 20，范围 1-50。',
        'minimum': 1,
        'maximum': 50,
      },
    },
    'required': ['categoryLevel'],
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
      name: 'get_period_overview',
      description:
          '读取当前账本一个周期的收支概览，只读。应用负责解析本月、上月、今年等周期并遵守账本月起始日。返回本位币、准确区间、收入、支出、结余、储蓄率和交易笔数。询问“花了多少、收入多少、结余多少”时使用。',
      parameters: _periodOverviewParameters,
    ),
    core.AgentNativeToolDefinition(
      name: 'get_spending_trend',
      description:
          '读取当前账本支出或收入的趋势，只读。默认统计支出；查询收入分类（如捐赠、募资、薪资）时传 flowType="income"。可按日、周、月、年分组并筛选一个或多个分类；一级分类自动包含子分类。返回金额、笔数以及环比或同比；按月时无交易月份补零。模型不要自行汇总明细或重新计算涨跌幅。询问“各月/趋势/环比/同比/某分类对比支出或收入”时使用。',
      parameters: _spendingTrendParameters,
    ),
    core.AgentNativeToolDefinition(
      name: 'get_category_breakdown',
      description:
          '读取当前账本指定周期的支出或收入分类构成，只读。默认统计支出；查询收入分类（分类下都是收入）时传 flowType="income"。可按一级分类或明细分类返回金额、笔数和占比；一级分类范围会自动包含子分类。询问“哪些分类花得最多、分类占比、支出/收入构成”时使用。',
      parameters: _categoryBreakdownParameters,
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

  static core.AgentNativeToolDefinition definition(String name) =>
      definitions.firstWhere((definition) => definition.name == name);
}
