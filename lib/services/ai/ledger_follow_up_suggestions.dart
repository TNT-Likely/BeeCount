import 'package:agentcore/agentcore.dart';

import '../../l10n/app_localizations.dart';

/// Read-only, grounded candidates. Never inspects model prose or transaction
/// notes, calls a model, reads the DB, or recommends a data mutation.
final class LedgerFollowUpSuggestions {
  const LedgerFollowUpSuggestions._();

  static List<AgentPromptSuggestion> generate({
    required Iterable<AgentSuggestionEvidence> evidence,
    required AppLocalizations l10n,
    required String currentPrompt,
    Iterable<String> recentPrompts = const [],
    bool enabled = true,
  }) {
    final candidates = <AgentPromptSuggestion>[];
    // More specific successful queries take precedence over a broad overview.
    final ordered = evidence.toList().reversed.toList()
      ..sort((a, b) => _priority(b.toolName).compareTo(_priority(a.toolName)));
    for (final item in ordered) {
      final data = item.result;
      // A confirmed saved bill can lead into analysis, but never into another
      // write. Relative scope is explicit in these new questions (this month).
      if (item.toolName == 'record_transaction_from_text' &&
          !data.containsKey('error') &&
          data['success'] == true &&
          data['transactionIds'] is List &&
          (data['transactionIds'] as List).whereType<int>().isNotEmpty) {
        candidates.addAll([
          AgentPromptSuggestion(
              id: 'followup-overview',
              title: l10n.agentSuggestionOverviewTitle,
              prompt: l10n.agentSuggestionOverviewPrompt),
          AgentPromptSuggestion(
              id: 'followup-category',
              title: l10n.agentSuggestionCategoryTitle,
              prompt: l10n.agentSuggestionCategoryPrompt),
        ]);
        continue;
      }
      if (data.containsKey('error') || _priority(item.toolName) == 0) {
        continue;
      }
      final start = DateTime.tryParse(data['periodStart']?.toString() ?? '');
      final end = DateTime.tryParse(data['periodEnd']?.toString() ?? '');
      final expense = data['totalExpense'] ?? data['expense'];
      if (start == null ||
          end == null ||
          !start.isBefore(end) ||
          expense is! num ||
          !expense.isFinite ||
          expense <= 0) {
        continue;
      }
      final range = l10n.agentFollowUpRange(
          start.toIso8601String(), end.toIso8601String());
      final rawNames = data['categoryNames'];
      if (rawNames != null && rawNames is! List) continue;
      final names = (rawNames is List ? rawNames : const [])
          .whereType<String>()
          .where((name) => name.trim().isNotEmpty)
          .toList();
      if (names.any((name) => !_safeName(name))) continue;
      final category = names.isEmpty
          ? l10n.agentFollowUpAllCategories
          : names.map((name) => '「$name」').join('、');
      AgentPromptSuggestion suggestion(
              String id, String title, String prompt) =>
          AgentPromptSuggestion(id: id, title: title, prompt: prompt);
      if (item.toolName == 'get_category_breakdown') {
        final items = data['items'];
        if (items is! List || items.isEmpty) continue;
        if (data['categoryLevel'] == 'top') {
          final first = items.whereType<Map>().firstOrNull;
          final rawCategory = first?['category'];
          final name = rawCategory is Map ? rawCategory['name'] : null;
          if (name is String &&
              _safeName(name) &&
              name != '未分类' &&
              name != '其他') {
            candidates.add(suggestion(
                'followup-leaf',
                l10n.agentFollowUpLeafTitle(name),
                l10n.agentFollowUpLeafPrompt(name, range)));
          }
        }
        candidates.add(suggestion(
            'followup-trend',
            l10n.agentFollowUpTrendTitle,
            l10n.agentFollowUpTrendPrompt(category, range)));
        // Include the previous month so month-over-month has a comparison point.
        final previousMonth = _previousMonth(start);
        final comparisonRange = l10n.agentFollowUpRange(
            previousMonth.toIso8601String(), end.toIso8601String());
        candidates.add(suggestion(
            'followup-compare',
            l10n.agentFollowUpCompareTitle,
            l10n.agentFollowUpComparePrompt(category, comparisonRange)));
      } else if (item.toolName == 'get_spending_trend') {
        if (names.isEmpty) {
          candidates.add(suggestion(
              'followup-category',
              l10n.agentFollowUpCategoryTitle,
              l10n.agentFollowUpCategoryPrompt(range)));
        } else if (names.length == 1) {
          candidates.add(suggestion(
              'followup-leaf',
              l10n.agentFollowUpLeafTitle(names.single),
              l10n.agentFollowUpLeafPrompt(names.single, range)));
        }
        if (data['comparison'] != 'previous_point') {
          final comparisonRange = l10n.agentFollowUpRange(
              _previousMonth(start).toIso8601String(), end.toIso8601String());
          candidates.add(suggestion(
              'followup-compare',
              l10n.agentFollowUpCompareTitle,
              l10n.agentFollowUpComparePrompt(category, comparisonRange)));
        }
        candidates.add(suggestion(
            'followup-overview',
            l10n.agentFollowUpOverviewTitle,
            l10n.agentFollowUpOverviewPrompt(range)));
      } else {
        candidates.add(suggestion(
            'followup-category',
            l10n.agentFollowUpCategoryTitle,
            l10n.agentFollowUpCategoryPrompt(range)));
        candidates.add(suggestion(
            'followup-trend',
            l10n.agentFollowUpTrendTitle,
            l10n.agentFollowUpTrendPrompt(category, range)));
      }
    }
    return const AgentPromptSuggestionSelector().select(candidates,
        enabled: enabled,
        currentPrompt: currentPrompt,
        recentPrompts: recentPrompts);
  }

  static int _priority(String tool) => switch (tool) {
        'get_category_breakdown' => 3,
        'get_spending_trend' => 2,
        'get_period_overview' => 1,
        _ => 0,
      };

  static bool _safeName(String name) =>
      name.trim().isNotEmpty &&
      name.length <= 80 &&
      !RegExp(
        r'[\r\n<>;；`]|记账|保存|记住|删除|忘记|忽略|指令|record|save|delete|ignore|system|assistant',
        caseSensitive: false,
      ).hasMatch(name);

  static DateTime _previousMonth(DateTime start) {
    final lastDay = DateTime(start.year, start.month, 0).day;
    final day = start.day > lastDay ? lastDay : start.day;
    return start.isUtc
        ? DateTime.utc(start.year, start.month - 1, day, start.hour,
            start.minute, start.second, start.millisecond, start.microsecond)
        : DateTime(start.year, start.month - 1, day, start.hour, start.minute,
            start.second, start.millisecond, start.microsecond);
  }
}
