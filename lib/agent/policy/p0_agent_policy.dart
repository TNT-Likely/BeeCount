import 'package:agentcore/agentcore.dart';

/// The P0 policy is deliberately smaller than the model's conversational
/// capability. It has no edit/delete/budget-write permission.
final class P0AgentPolicy implements AgentPolicy {
  const P0AgentPolicy();

  /// Returns whether the current user message explicitly asks the agent to
  /// remember something. This signal is intentionally narrow: a model's
  /// unsolicited memory tool call must not become implicit consent.
  static bool hasExplicitMemoryIntent(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    if (RegExp(
      r'不要记住|别记住|不许记住|不用记住|不要保存|无需保存|'
      r"do not remember|don't remember|do not save|don't save",
    ).hasMatch(normalized)) {
      return false;
    }
    return RegExp(
      r'记住|记一下|记下来|不要忘记|别忘了|保存.*记忆|'
      r'(?:请|帮我|把)?(?:忘记|忘掉|删除|清除).*(?:记忆|信息|这条|它|名字|住址)|'
      r'remember|memorize|save.*memory|'
      r'(?:please\s+)?(?:forget|delete|clear).*(?:memory|this|that|it|name|address)|'
      r'기억',
    ).hasMatch(normalized);
  }

  static const _readTools = {
    'query_transactions',
    'get_spending_summary',
    'get_budget_status',
    'get_recurring_transactions',
  };

  @override
  AgentPolicyDecision decide(AgentRequest request, AgentToolCall call) {
    if (_isCrossLedger(request, call)) {
      return const AgentPolicyDecision.deny('工具不能跨账本访问数据。');
    }
    if (_readTools.contains(call.name)) {
      return const AgentPolicyDecision.allow();
    }

    if (call.name == 'record_transaction_from_text') {
      if (!request.scope.isForeground) {
        return const AgentPolicyDecision.deny('后台任务不能直接记账。');
      }
      return _hasCurrentUserSourceText(request, call)
          ? const AgentPolicyDecision.allow()
          : const AgentPolicyDecision.deny('记账来源必须是当前用户消息。');
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

  bool _hasCurrentUserSourceText(
    AgentRequest request,
    AgentToolCall call,
  ) =>
      call.arguments['sourceText'] == request.text;
}
