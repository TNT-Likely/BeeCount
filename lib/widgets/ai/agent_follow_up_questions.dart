import 'package:agentcore/agentcore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/theme_providers.dart';
import '../../styles/tokens.dart';

/// Follow-ups are visible actions, not text mixed into the model's answer.
final class AgentFollowUpQuestions extends ConsumerWidget {
  const AgentFollowUpQuestions(
      {super.key,
      required this.suggestions,
      required this.onSuggestionTap,
      this.enabled = true});

  final List<AgentPromptSuggestion> suggestions;
  final ValueChanged<AgentPromptSuggestion> onSuggestionTap;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final primary = ref.watch(primaryColorProvider);
    return Column(
      key: const ValueKey('agent-follow-up-questions'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context).agentFollowUpTitle,
            style: BeeTextTokens.label(context)
                .copyWith(color: BeeTokens.textTertiary(context))),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final item in suggestions)
            Tooltip(
                message: item.prompt,
                child: ActionChip(
                  key: ValueKey('agent-follow-up-${item.id}'),
                  label: Text(item.title, maxLines: 2),
                  avatar: Icon(Icons.arrow_forward_rounded,
                      size: 14, color: primary),
                  onPressed: enabled ? () => onSuggestionTap(item) : null,
                  backgroundColor: primary.withValues(alpha: 0.06),
                  side: BorderSide(color: primary.withValues(alpha: 0.18)),
                )),
        ]),
      ],
    );
  }
}
