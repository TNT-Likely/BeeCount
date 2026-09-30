import 'package:agentcore/agentcore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/theme_providers.dart';
import '../../styles/tokens.dart';

/// Follow-ups are visible actions, not text mixed into the model's answer.
final class AgentFollowUpQuestions extends ConsumerStatefulWidget {
  const AgentFollowUpQuestions(
      {super.key,
      required this.suggestions,
      required this.onSuggestionTap,
      this.enabled = true});

  final List<AgentPromptSuggestion> suggestions;
  final ValueChanged<AgentPromptSuggestion> onSuggestionTap;
  final bool enabled;

  @override
  ConsumerState<AgentFollowUpQuestions> createState() =>
      _AgentFollowUpQuestionsState();
}

final class _AgentFollowUpQuestionsState
    extends ConsumerState<AgentFollowUpQuestions> {
  bool _expanded = false;

  @override
  void didUpdateWidget(AgentFollowUpQuestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suggestions.map((item) => item.prompt).join('\u0000') !=
        widget.suggestions.map((item) => item.prompt).join('\u0000')) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = widget.suggestions;
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final primary = ref.watch(primaryColorProvider);
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const ValueKey('agent-follow-up-questions'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.agentFollowUpTitle,
            style: BeeTextTokens.label(context)
                .copyWith(color: BeeTokens.textTertiary(context))),
        const SizedBox(height: 4),
        LayoutBuilder(
            builder: (context, constraints) =>
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final item
                      in _expanded ? suggestions : suggestions.take(3))
                    Tooltip(
                        message: item.prompt,
                        child: ConstrainedBox(
                            constraints:
                                BoxConstraints(maxWidth: constraints.maxWidth),
                            child: ActionChip(
                              key: ValueKey('agent-follow-up-${item.id}'),
                              label: Text(item.title,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              avatar: Icon(Icons.arrow_forward_rounded,
                                  size: 14, color: primary),
                              onPressed: widget.enabled
                                  ? () => widget.onSuggestionTap(item)
                                  : null,
                              backgroundColor: primary.withValues(alpha: 0.06),
                              side: BorderSide(
                                  color: primary.withValues(alpha: 0.18)),
                            ))),
                ])),
        if (suggestions.length > 3)
          TextButton.icon(
            key: const ValueKey('agent-follow-up-more'),
            onPressed: widget.enabled
                ? () => setState(() => _expanded = !_expanded)
                : null,
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                size: 16),
            label: Text(_expanded
                ? l10n.agentSuggestionsLess
                : l10n.agentSuggestionsMore),
            style: TextButton.styleFrom(
                foregroundColor: primary,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact),
          ),
      ],
    );
  }
}
