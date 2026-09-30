import 'package:agentcore/agentcore.dart';

import '../l10n/app_localizations.dart';

/// BeeCount's small, read-only entry catalog. Suggestions contain only a real
/// user question: no DB reads, hidden instructions or special execution mode.
final class AssistantPromptSuggestions {
  const AssistantPromptSuggestions._();

  static List<AgentPromptSuggestion> localized(AppLocalizations l10n) => [
        AgentPromptSuggestion(
          id: 'monthly_overview',
          title: l10n.agentSuggestionOverviewTitle,
          prompt: l10n.agentSuggestionOverviewPrompt,
        ),
        AgentPromptSuggestion(
          id: 'category_breakdown',
          title: l10n.agentSuggestionCategoryTitle,
          prompt: l10n.agentSuggestionCategoryPrompt,
        ),
        AgentPromptSuggestion(
          id: 'spending_trend',
          title: l10n.agentSuggestionTrendTitle,
          prompt: l10n.agentSuggestionTrendPrompt,
        ),
      ];
}
