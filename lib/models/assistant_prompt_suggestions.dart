import 'package:agentcore/agentcore.dart';

import '../l10n/app_localizations.dart';

/// BeeCount's six read-only analysis templates. Suggestions contain only a real
/// user question: no DB reads, hidden instructions or special execution mode.
final class AssistantPromptSuggestions {
  const AssistantPromptSuggestions._();

  /// Contextual questions come first. Analysis templates remain available
  /// after any successful answer, without pretending to be query evidence.
  static List<AgentPromptSuggestion> continuations(
    AppLocalizations l10n, {
    Iterable<AgentPromptSuggestion> contextual = const [],
    Iterable<String> recentPrompts = const [],
  }) =>
      const AgentPromptSuggestionSelector(maximumCount: 9).select(
        [...contextual, ...localized(l10n)],
        recentPrompts: recentPrompts,
      );

  static List<AgentPromptSuggestion> localized(AppLocalizations l10n) => [
        AgentPromptSuggestion(
          id: 'financial_health',
          title: l10n.agentSuggestionHealthTitle,
          prompt: l10n.agentSuggestionHealthPrompt,
        ),
        AgentPromptSuggestion(
          id: 'monthly_expense_summary',
          title: l10n.agentSuggestionSummaryTitle,
          prompt: l10n.agentSuggestionSummaryPrompt,
        ),
        AgentPromptSuggestion(
          id: 'category_analysis',
          title: l10n.agentSuggestionAnalysisTitle,
          prompt: l10n.agentSuggestionAnalysisPrompt,
        ),
        AgentPromptSuggestion(
          id: 'budget_planning',
          title: l10n.agentSuggestionBudgetTitle,
          prompt: l10n.agentSuggestionBudgetPrompt,
        ),
        AgentPromptSuggestion(
          id: 'abnormal_expense',
          title: l10n.agentSuggestionAnomalyTitle,
          prompt: l10n.agentSuggestionAnomalyPrompt,
        ),
        AgentPromptSuggestion(
          id: 'saving_tips',
          title: l10n.agentSuggestionSavingTitle,
          prompt: l10n.agentSuggestionSavingPrompt,
        ),
      ];
}
