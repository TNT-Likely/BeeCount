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
        'get_budget_status' => l10n.agentToolBudgetStatus,
        'record_transaction_from_text' => l10n.agentToolRecordTransaction,
        'save_explicit_memory' => l10n.agentToolSaveMemory,
        'forget_memory' => l10n.agentToolForgetMemory,
        _ => toolName,
      };

  static String description(AppLocalizations l10n, String toolName) =>
      switch (toolName) {
        'query_transactions' => l10n.agentToolQueryTransactionsDescription,
        'get_spending_summary' => l10n.agentToolSpendingSummaryDescription,
        'get_budget_status' => l10n.agentToolBudgetStatusDescription,
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
        toolName == 'get_spending_summary') {
      final start = arguments['start'];
      final end = arguments['end'];
      if (start is String || end is String) {
        return [
          (
            label: l10n.agentAuthorizationTimeRange,
            value: '${start ?? '—'} – ${end ?? '—'}',
          ),
        ];
      }
      return const [];
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
        _ => key,
      };

  static String _displayValue(Object value) => switch (value) {
        String value => value,
        num value => value.toString(),
        bool value => value.toString(),
        _ => '—',
      };
}
