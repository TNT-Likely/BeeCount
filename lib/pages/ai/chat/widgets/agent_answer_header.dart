import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_agent_ui/flutter_agent_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../styles/tokens.dart';
import 'agent_brand_mark.dart';

class AgentAnswerHeader extends StatelessWidget {
  const AgentAnswerHeader(
      {super.key,
      this.steps = const [],
      this.readQuery = false,
      this.onMore,
      this.messageId,
      this.hideDetails = false});
  final List<AgentActivityStep> steps;
  final bool readQuery, hideDetails;
  final VoidCallback? onMore;
  final int? messageId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = BeeTokens.textSecondary(context);
    final failed = steps.any((s) => s.status == AgentActivityStatus.failed);
    final summary = failed
        ? l.agentExecutionFailedSummary
        : readQuery
            ? l.aiChatCheckedCount(steps.length)
            : l.agentExecutionCompletedSummary(steps.length);
    return Row(children: [
      const AgentBrandMark(size: 28),
      const SizedBox(width: 7),
      Flexible(
          child: Text(l.aiChatAssistantName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      if (steps.isNotEmpty)
        Flexible(
            flex: 3,
            child: TextButton(
              key: ValueKey('execution-$messageId'),
              onPressed: () => showBeeSheet<void>(context,
                  title: l.aiChatQueryProcess,
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final s in steps)
                      BeeMenuRow(
                        leading: BeeLineIcon(
                            s.status == AgentActivityStatus.failed
                                ? 'CircleAlert'
                                : 'CircleCheck',
                            size: 18),
                        title: s.title,
                        subtitle: !hideDetails && s.details.isNotEmpty
                            ? s.details.join('\n')
                            : null,
                      )
                  ]))),
              style: TextButton.styleFrom(
                  foregroundColor: muted,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(44, 44)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                    child: Text(summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12))),
                const SizedBox(width: 2),
                const BeeLineIcon('ChevronDown', size: 14),
              ]),
            )),
      const Spacer(),
      if (onMore != null)
        IconButton(
          key: ValueKey('agent-answer-more-$messageId'),
          tooltip: l.aiChatAnswerActions,
          icon: const BeeLineIcon('Ellipsis', size: 20),
          onPressed: onMore,
        ),
    ]);
  }
}
