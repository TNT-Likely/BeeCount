import '../../agent/permission/agent_tool_permission.dart';
import '../../l10n/app_localizations.dart';

/// UI-only labels and safe argument excerpts for local Agent tools.
///
/// AgentCore deliberately has no Flutter or localization dependency. Keeping
/// these mappings here also ensures that an authorization dialog never turns a
/// record's source text into guessed transaction fields.
final class AgentToolPresentation {
  const AgentToolPresentation._();

  static String label(AppLocalizations l10n, String toolName) =>
      switch (toolName) {
        'query_transactions' => l10n.agentToolQueryTransactions,
        'get_spending_summary' => l10n.agentToolSpendingSummary,
        'get_transaction_summary' => l10n.agentToolTransactionSummary,
        'get_budget_status' => l10n.agentToolBudgetStatus,
        'get_recurring_transactions' => l10n.agentToolRecurringTransactions,
        'record_transaction_from_text' => l10n.agentToolRecordTransaction,
        'save_explicit_memory' => l10n.agentToolSaveMemory,
        'forget_memory' => l10n.agentToolForgetMemory,
        _ => toolName,
      };

  static String description(AppLocalizations l10n, String toolName) =>
      switch (toolName) {
        'query_transactions' => l10n.agentToolQueryTransactionsDescription,
        'get_spending_summary' => l10n.agentToolSpendingSummaryDescription,
        'get_transaction_summary' =>
          l10n.agentToolTransactionSummaryDescription,
        'get_budget_status' => l10n.agentToolBudgetStatusDescription,
        'get_recurring_transactions' =>
          l10n.agentToolRecurringTransactionsDescription,
        'record_transaction_from_text' =>
          l10n.agentToolRecordTransactionDescription,
        'save_explicit_memory' => l10n.agentToolSaveMemoryDescription,
        'forget_memory' => l10n.agentToolForgetMemoryDescription,
        _ => l10n.agentToolUnknownDescription,
      };

  /// Returns only a whitelisted, human-readable subset of tool input.
  static List<({String label, String value})> safeArguments(
    AppLocalizations l10n,
    String toolName,
    Map<String, Object?> arguments,
  ) {
    if (toolName == 'record_transaction_from_text') {
      final sourceText = arguments['sourceText'];
      return sourceText is String
          ? [(label: l10n.agentAuthorizationSourceText, value: sourceText)]
          : const [];
    }

    if (toolName == 'query_transactions' ||
        toolName == 'get_spending_summary' ||
        toolName == 'get_transaction_summary') {
      final start = arguments['start'];
      final end = arguments['end'];
      final result = <({String label, String value})>[];
      if (start is String || end is String) {
        result.add(
          (
            label: l10n.agentAuthorizationTimeRange,
            value: '${start ?? '—'} – ${end ?? '—'}',
          ),
        );
      }
      if (toolName == 'get_transaction_summary') {
        final types = arguments['types'];
        if (types is List && types.whereType<String>().isNotEmpty) {
          result.add(
            (
              label: l10n.agentAuthorizationSummaryTypes,
              value: types.whereType<String>().join(', '),
            ),
          );
        }
        final groupBy = arguments['groupBy'];
        if (groupBy is String && groupBy.isNotEmpty) {
          result.add(
            (
              label: l10n.agentAuthorizationSummaryGroupBy,
              value: groupBy,
            ),
          );
        }
        for (final key in const ['categoryIds', 'tagIds', 'accountIds']) {
          final ids = arguments[key];
          if (ids is List && ids.whereType<int>().isNotEmpty) {
            result.add(
              (
                label: _argumentLabel(l10n, key),
                value: ids.whereType<int>().join(', '),
              ),
            );
          }
        }
      }
      return result;
    }

    const allowedKeys = {'content', 'memoryId'};
    return [
      for (final entry in arguments.entries)
        if (allowedKeys.contains(entry.key) && entry.value != null)
          (
            label: _argumentLabel(l10n, entry.key),
            value: _displayValue(entry.value!),
          ),
    ];
  }

  static String permissionLabel(
    AppLocalizations l10n,
    AgentToolPermission permission,
  ) =>
      switch (permission) {
        AgentToolPermission.ask => l10n.agentPermissionAsk,
        AgentToolPermission.alwaysAllow => l10n.agentPermissionAlwaysAllow,
      };

  static String _argumentLabel(AppLocalizations l10n, String key) =>
      switch (key) {
        'content' => l10n.agentAuthorizationMemoryContent,
        'memoryId' => l10n.agentAuthorizationMemoryId,
        'categoryIds' => l10n.agentAuthorizationCategoryIds,
        'tagIds' => l10n.agentAuthorizationTagIds,
        'accountIds' => l10n.agentAuthorizationAccountIds,
        _ => key,
      };

  static String _displayValue(Object value) => switch (value) {
        String value => value,
        num value => value.toString(),
        bool value => value.toString(),
        _ => '—',
      };
}
