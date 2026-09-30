import 'package:agentcore/agentcore.dart' show AgentPromptSuggestion;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/assistant_prompt_suggestions.dart';
import '../../providers/theme_providers.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';

/// Compact presentation of the host's recommended questions.
final class AIPromptSuggestions extends ConsumerWidget {
  const AIPromptSuggestions({
    super.key,
    required this.onSuggestionTap,
  });

  final ValueChanged<AgentPromptSuggestion> onSuggestionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);
    final suggestions = AssistantPromptSuggestions.localized(l10n);
    final gap = 8.0.scaled(context, ref);
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - gap) / 2;
        return SizedBox(
          width: constraints.maxWidth,
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var index = 0; index < suggestions.length; index++)
                SizedBox(
                  width: itemWidth,
                  height: 38.0.scaled(context, ref),
                  child: _AIPromptSuggestionCard(
                    key: ValueKey('ai-prompt-suggestion-$index'),
                    iconKey: ValueKey(
                      'ai-prompt-suggestion-icon-$index',
                    ),
                    suggestion: suggestions[index],
                    title: suggestions[index].title,
                    primary: primary,
                    onTap: () => onSuggestionTap(suggestions[index]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

final class _AIPromptSuggestionCard extends StatelessWidget {
  const _AIPromptSuggestionCard({
    super.key,
    required this.iconKey,
    required this.suggestion,
    required this.title,
    required this.primary,
    required this.onTap,
  });

  final Key iconKey;
  final AgentPromptSuggestion suggestion;
  final String title;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = BeeTokens.isDark(context);
    final radius = BorderRadius.circular(12);
    final iconBackground = primary.withValues(alpha: isDark ? 0.22 : 0.14);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          color: BeeTokens.surface(context),
          borderRadius: radius,
          border: Border.all(
            color: primary.withValues(alpha: isDark ? 0.32 : 0.14),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Row(
              children: [
                Container(
                  key: iconKey,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    _iconFor(suggestion),
                    color: primary,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: BeeTextTokens.strongTitle(context).copyWith(
                      color: BeeTokens.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Recommended questions remain available beside the input during a chat.
final class AIPromptSuggestionLauncher extends ConsumerWidget {
  const AIPromptSuggestionLauncher({
    super.key,
    required this.onSuggestionTap,
    this.enabled = true,
  });

  final ValueChanged<AgentPromptSuggestion> onSuggestionTap;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);
    return IconButton(
      key: const ValueKey('ai-prompt-suggestion-launcher'),
      tooltip: l10n.agentSuggestionsOpen,
      onPressed: enabled
          ? () async {
              final suggestion =
                  await showModalBottomSheet<AgentPromptSuggestion>(
                context: context,
                backgroundColor: BeeTokens.surfaceSheet(context),
                barrierColor: BeeTokens.overlay(context),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => const _AIPromptSuggestionsSheet(),
              );
              if (suggestion != null) onSuggestionTap(suggestion);
            }
          : null,
      style: IconButton.styleFrom(foregroundColor: primary),
      icon: const Icon(Icons.auto_awesome_outlined),
    );
  }
}

final class _AIPromptSuggestionsSheet extends ConsumerWidget {
  const _AIPromptSuggestionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);
    final suggestions = AssistantPromptSuggestions.localized(l10n);
    return SafeArea(
      top: false,
      child: SizedBox(
        key: const ValueKey('ai-prompt-suggestion-sheet'),
        height: 300.0.scaled(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: EdgeInsets.only(top: 12.0.scaled(context, ref)),
                width: 34.0.scaled(context, ref),
                height: 4.0.scaled(context, ref),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20.0.scaled(context, ref),
                18.0.scaled(context, ref),
                20.0.scaled(context, ref),
                12.0.scaled(context, ref),
              ),
              child: Row(
                children: [
                  Container(
                    key: const ValueKey(
                        'ai-prompt-suggestion-sheet-header-icon'),
                    width: 38.0.scaled(context, ref),
                    height: 38.0.scaled(context, ref),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.14),
                      borderRadius:
                          BorderRadius.circular(13.0.scaled(context, ref)),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: primary,
                      size: 20.0.scaled(context, ref),
                    ),
                  ),
                  SizedBox(width: 12.0.scaled(context, ref)),
                  Text(
                    l10n.agentSuggestionsTitle,
                    style: BeeTextTokens.boldTitle(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                key: const ValueKey('ai-prompt-suggestion-sheet-grid'),
                padding: EdgeInsets.fromLTRB(
                  16.0.scaled(context, ref),
                  0,
                  16.0.scaled(context, ref),
                  16.0.scaled(context, ref),
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10.0.scaled(context, ref),
                  crossAxisSpacing: 10.0.scaled(context, ref),
                  mainAxisExtent: 82.0.scaled(context, ref),
                ),
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return Material(
                    key: ValueKey('ai-prompt-suggestion-sheet-item-$index'),
                    color: primary.withValues(
                      alpha: BeeTokens.isDark(context) ? 0.18 : 0.08,
                    ),
                    borderRadius:
                        BorderRadius.circular(16.0.scaled(context, ref)),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(suggestion),
                      borderRadius:
                          BorderRadius.circular(16.0.scaled(context, ref)),
                      child: Padding(
                        padding: EdgeInsets.all(12.0.scaled(context, ref)),
                        child: Row(
                          children: [
                            Container(
                              width: 30.0.scaled(context, ref),
                              height: 30.0.scaled(context, ref),
                              decoration: BoxDecoration(
                                color: BeeTokens.surface(context),
                                borderRadius: BorderRadius.circular(
                                  10.0.scaled(context, ref),
                                ),
                              ),
                              child: Icon(
                                _iconFor(suggestion),
                                color: primary,
                                size: 16.0.scaled(context, ref),
                              ),
                            ),
                            SizedBox(width: 9.0.scaled(context, ref)),
                            Expanded(
                              child: Text(
                                suggestion.title,
                                style: BeeTextTokens.strongTitle(context),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(AgentPromptSuggestion suggestion) => switch (suggestion.id) {
      'monthly_overview' => Icons.calendar_month_outlined,
      'category_breakdown' => Icons.pie_chart_outline_rounded,
      'spending_trend' => Icons.trending_up_rounded,
      _ => Icons.chat_bubble_outline,
    };
