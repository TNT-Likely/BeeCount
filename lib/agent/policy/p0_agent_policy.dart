import 'package:agentcore/agentcore.dart';

/// The P0 policy is deliberately smaller than the model's conversational
/// capability. It has no edit/delete/budget-write permission.
final class P0AgentPolicy implements AgentPolicy {
  const P0AgentPolicy();

  static const _readTools = {
    'query_transactions',
    'get_spending_summary',
    'get_budget_status',
  };

  @override
  AgentPolicyDecision decide(AgentRequest request, AgentToolCall call) {
    if (_isCrossLedger(request, call)) {
      return const AgentPolicyDecision.deny('工具不能跨账本访问数据。');
    }
    if (_readTools.contains(call.name))
      return const AgentPolicyDecision.allow();

    if (call.name == 'record_transaction_from_text') {
      if (!request.scope.isForeground) {
        return const AgentPolicyDecision.deny('后台任务不能直接记账。');
      }
      final validation = call.validateAgainst(request.text);
      return validation.isValid
          ? const AgentPolicyDecision.allow()
          : AgentPolicyDecision.deny(validation.reason!);
    }

    if (call.name == 'save_explicit_memory' || call.name == 'forget_memory') {
      if (!request.scope.isForeground || !request.scope.allowsExplicitMemory) {
        return const AgentPolicyDecision.deny('仅能响应用户明确的记忆操作。');
      }
      return const AgentPolicyDecision.allow();
    }

    return const AgentPolicyDecision.deny('P0 不允许此操作。');
  }

  bool _isCrossLedger(AgentRequest request, AgentToolCall call) {
    final requestedLedgerId = call.arguments['ledgerId'];
    return requestedLedgerId != null &&
        requestedLedgerId != request.scope.ledgerId;
  }
}
