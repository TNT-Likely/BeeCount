import 'package:agentcore/agentcore.dart';

/// Narrow checks for known query regressions, not a natural-language query
/// protocol. BeeCount owns accounting semantics; AgentCore owns execution,
/// native error pairing and the bounded correction budget.
final class LedgerQueryCallValidator {
  const LedgerQueryCallValidator._();

  static AgentToolValidationIssue? validate(
    AgentRequest request,
    AgentToolCall call,
  ) {
    final text = request.text;
    if (call.name == 'get_category_breakdown') {
      final explicitLeaf = RegExp(
        r'明细分类|二级分类|子分类|细分分类|subcategory|leaf',
        caseSensitive: false,
      ).hasMatch(text);
      final explicitTop = RegExp(
        r'一级分类|顶级分类|top.level',
        caseSensitive: false,
      ).hasMatch(text);
      final names = call.arguments['categoryNames'];
      // “餐饮下早餐和午餐” asks for the children of the named parent.
      // Do not match generic “查一下” or infer the level from old history.
      final underParent = names is List &&
          names.any((name) =>
              name is String && name.isNotEmpty && text.contains('$name下'));
      if (!explicitTop &&
          (explicitLeaf || underParent) &&
          call.arguments['categoryLevel'] != 'leaf') {
        return const AgentToolValidationIssue(
          code: 'category_level_mismatch',
          message: '用户要求明细/子分类。请重新调用 get_category_breakdown，'
              '设置 categoryLevel="leaf"，保留原来的时间和分类范围。'
              '本次未查询数据，不能据此声称没有子分类。',
        );
      }
    }
    if (call.name == 'query_transactions') {
      final totals = RegExp(
        r'总收入|总支出|总收支|结余|total\s+(income|expenses?|spending)',
        caseSensitive: false,
      ).hasMatch(text);
      final otherQuery = RegExp(
        r'明细|最近.{0,4}(笔|条)|逐笔|列出|趋势|各月|环比|同比|占比|构成|排行|预算|'
        r'transactions?|details?|trend|breakdown|budget',
        caseSensitive: false,
      ).hasMatch(text);
      if (totals && !otherQuery) {
        return const AgentToolValidationIssue(
          code: 'aggregate_tool_required',
          message: '用户要求收支总额，请调用 get_period_overview。'
              '指定日期使用 period="custom" 和对应 start/end；'
              '常用周期使用 period 枚举。交易明细最多返回 20 条，'
              '不能作为总额来源。本次未查询数据。',
        );
      }
    }
    return null;
  }

  /// A different tool (e.g. a month overview) must not mask an unrepaired
  /// category-level failure just because the broad directory matcher matched
  /// both intents. Permission denials remain separate from invalid input.
  static bool hasUnresolvedIssue(AgentRunResult result) =>
      result.rejectedCalls.any((rejected) => switch (rejected.issue.code) {
            'category_level_mismatch' => !result.executedCalls.any((call) =>
                call.name == 'get_category_breakdown' &&
                call.arguments['categoryLevel'] == 'leaf'),
            'aggregate_tool_required' => !result.executedCalls
                .any((call) => call.name == 'get_period_overview'),
            _ => true,
          });
}
