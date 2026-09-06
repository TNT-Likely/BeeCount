import 'package:flutter/material.dart';

import 'agent_ai_mark.dart';

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
            child: SizedBox.square(
              dimension: 24,
              child: Center(
                child: AgentAiMark(size: 22, color: iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
