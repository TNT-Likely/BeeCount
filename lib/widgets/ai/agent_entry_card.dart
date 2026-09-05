import 'package:flutter/material.dart';

import '../../styles/tokens.dart';
import 'agent_ai_mark.dart';
import 'agent_brand_mark.dart';

/// A compact, discoverable entry point for the Agent from the home page.
final class AgentEntryCard extends StatelessWidget {
  const AgentEntryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
          decoration: BoxDecoration(
            color: BeeTokens.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withValues(alpha: 0.18)),
            boxShadow: BeeTokens.isDark(context) ? null : BeeShadows.card,
          ),
          child: Row(
            children: [
              const AgentBrandMark(
                size: 38,
                showStatus: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BeeTextTokens.strongTitle(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BeeTextTokens.label(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: BeeTokens.iconTertiary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact icon button used in the home header where a full card would be
/// too wide. The AI wordmark makes this entry distinct from the chat avatar.
final class AgentEntryButton extends StatelessWidget {
  const AgentEntryButton({
    super.key,
    required this.tooltip,
    required this.onTap,
  });

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        IconTheme.of(context).color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: AgentAiMark(size: 24, color: iconColor),
          ),
        ),
      ),
    );
  }
}
