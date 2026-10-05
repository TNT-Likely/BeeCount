import 'package:intl/intl.dart';

import '../../agent/permission/agent_tool_permission.dart';
import '../../l10n/app_localizations.dart';

/// UI-only labels and safe argument excerpts for local Agent tools.
///
/// AgentCore deliberately has no Flutter or localization dependency. Keeping
/// these mappings here also ensures that an authorization dialog never turns a
/// record's source text into guessed transaction fields.
final class AgentToolPresentation {
  const AgentToolPresentation._();

  /// Friendly display names. Authorization retains exact tool identifiers for
  /// unknown tools; the conversation surface does not expose implementation names.
  static String activityTitle(AppLocalizations l10n, String toolName) =>
      switch (toolName) {
        'get_period_overview' => l10n.agentActivityOverview,
        'get_spending_trend' => l10n.agentActivityTrend,
        'get_category_breakdown' => l10n.agentActivityCategories,
        'query_transactions' ||
        'get_spending_summary' ||
        'get_transaction_summary' ||
        'get_budget_status' ||
        'get_recurring_transactions' ||
        'record_transaction_from_text' ||
        'save_explicit_memory' ||
        'forget_memory' =>
          label(l10n, toolName),
        _ => l10n.agentActivityUnknownTool,
      };

  /// Only a bounded, human-readable projection is shown or persisted. Never
  /// stringify arbitrary maps, transaction notes, source text or error objects.
  static List<String> activityDetails(AppLocalizations l10n, String toolName,
      Map<String, Object?> arguments, Map<String, Object?>? result) {
    final lines = <String>[];
    final queryTools = {
      'query_transactions',
      'get_spending_summary',
      'get_transaction_summary',
      'get_period_overview',
      'get_spending_trend',
      'get_category_breakdown'
    };
    if (!queryTools.contains(toolName)) return lines;
    final start =
        _displayDate(result?['periodStart'] ?? arguments['start'], l10n);
    final end = _displayDate(result?['periodEnd'] ?? arguments['end'], l10n);
    if (start != null && end != null) {
      lines.add(l10n.agentFollowUpRange(start, end));
    }
    if (toolName == 'get_category_breakdown') {
      lines.add(
          (result?['categoryLevel'] ?? arguments['categoryLevel']) == 'leaf'
              ? l10n.agentActivityLeafCategories
              : l10n.categoryGenerateDefaultFlat);
    }
    final names = arguments['categoryNames'];
    if (names is List) {
      final safeNames = names
          .whereType<String>()
          .where((name) =>
              name.trim().isNotEmpty &&
              name.length <= 60 &&
              !RegExp(r'[\x00-\x1f]').hasMatch(name))
          .take(3)
          .toList();
      if (safeNames.isNotEmpty) {
        lines.add(l10n.agentActivityCategoryScope(safeNames.join('、')));
      }
    }
    if (result == null || result.containsKey('error')) return lines;
    final items = result['items'];
    final points = result['points'];
    if (items is List) {
      lines.add(toolName == 'query_transactions'
          ? l10n.agentActivityReturnedRows(items.length)
          : l10n.agentActivityReturnedGroups(items.length));
    }
    if (points is List) {
      lines.add(l10n.agentActivityReturnedGroups(points.length));
    }
    final count = result['transactionCount'];
    if (count is int && count >= 0) {
      lines.add(l10n.agentActivityReturnedRows(count));
    }
    final currency = result['currency'];
    if (currency is String && RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      final expense = result['totalExpense'] ?? result['expense'];
      final income = result['totalIncome'] ?? result['income'];
      final money =
          NumberFormat.simpleCurrency(locale: l10n.localeName, name: currency);
      if (income is num && income.isFinite) {
        lines.add('${l10n.categoryIncome}：${money.format(income)}');
      }
      if (expense is num && expense.isFinite) {
        lines.add('${l10n.categoryExpense}：${money.format(expense)}');
      }
    }
    if (result['truncated'] == true) lines.add(l10n.agentActivityTruncated);
    return List.unmodifiable(lines.take(8));
  }

  static String? _displayDate(Object? raw, AppLocalizations l10n) {
    if (raw is! String) return null;
    final date = DateTime.tryParse(raw);
    if (date == null) return null;
    final format = date.hour == 0 &&
            date.minute == 0 &&
            date.second == 0 &&
            date.millisecond == 0
        ? DateFormat.yMd(l10n.localeName)
        : DateFormat.yMd(l10n.localeName).add_Hm();
    return format.format(date);
  }

  static String label(AppLocalizations l10n, String toolName) =>
      switch (toolName) {
        'query_transactions' => l10n.agentToolQueryTransactions,
        'get_spending_summary' => l10n.agentToolSpendingSummary,
        'get_transaction_summary' => l10n.agentToolTransactionSummary,
        'get_period_overview' => l10n.agentToolTransactionSummary,
        'get_spending_trend' => l10n.agentToolSpendingSummary,
        'get_category_breakdown' => l10n.agentToolSpendingSummary,
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
        'get_period_overview' => l10n.agentToolTransactionSummaryDescription,
        'get_spending_trend' => l10n.agentToolSpendingSummaryDescription,
        'get_category_breakdown' => l10n.agentToolSpendingSummaryDescription,
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
        toolName == 'get_transaction_summary' ||
        toolName == 'get_period_overview' ||
        toolName == 'get_spending_trend' ||
        toolName == 'get_category_breakdown') {
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
      if (toolName == 'get_transaction_summary' ||
          toolName == 'get_period_overview' ||
          toolName == 'get_spending_trend' ||
          toolName == 'get_category_breakdown') {
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
