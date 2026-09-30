import 'package:agentcore/agentcore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_agent_ui/flutter_agent_ui.dart';

import '../../l10n/app_localizations.dart';

/// Host-localized adapter; rotating interaction and distinct surface are reusable.
final class AgentFollowUpQuestions extends StatelessWidget {
  const AgentFollowUpQuestions(
      {super.key,
      required this.suggestions,
      required this.onSuggestionTap,
      this.templates = const [],
      this.enabled = true});

  final List<AgentPromptSuggestion> suggestions;
  final List<AgentPromptSuggestion> templates;
  final ValueChanged<AgentPromptSuggestion> onSuggestionTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AgentFollowUpSection(
      key: const ValueKey('agent-follow-up-questions'),
      questions: suggestions,
      templates: templates,
      title: l10n.agentFollowUpTitle,
      rotateLabel: l10n.agentFollowUpRotate,
      enabled: enabled,
      onSelected: onSuggestionTap,
    );
  }
}
