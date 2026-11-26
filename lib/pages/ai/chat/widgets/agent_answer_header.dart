import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_agent_ui/flutter_agent_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../styles/tokens.dart';
import 'agent_brand_mark.dart';

class AgentAnswerHeader extends StatefulWidget {
  const AgentAnswerHeader(
      {super.key,
      this.steps = const [],
      this.readQuery = false,
      this.onMore,
      this.messageId,
      this.basis,
      this.initiallyExpanded = false,
      this.onExpansionChanged,
      this.hideDetails = false});
  final List<AgentActivityStep> steps;
  final AgentActivityStep? basis;
  final bool readQuery, hideDetails, initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final VoidCallback? onMore;
  final int? messageId;

  @override
  State<AgentAnswerHeader> createState() => _AgentAnswerHeaderState();
}

class _AgentAnswerHeaderState extends State<AgentAnswerHeader> {
  bool? _expanded;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = BeeTokens.textSecondary(context);
    final basis = widget.basis;
    final steps = widget.steps;
    final expanded = _expanded ?? widget.initiallyExpanded;
    final failed = steps.any((s) => s.status == AgentActivityStatus.failed);
    final summary = basis != null || widget.readQuery
        ? l.agentQueryBasis
        : failed
            ? l.agentExecutionFailedSummary
            : l.agentExecutionCompletedSummary(steps.length);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const AgentBrandMark(size: 28),
        const SizedBox(width: 7),
        Expanded(
            child: Text(l.aiChatAssistantName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600))),
        if (basis != null || steps.isNotEmpty)
          Flexible(
              flex: 2,
              child: TextButton(
                key: ValueKey('execution-${widget.messageId}'),
                onPressed: () {
                  if (basis == null) {
                    showBeeSheet<void>(context,
                        title: summary,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              for (final s in steps)
                                BeeMenuRow(
                                  leading: BeeLineIcon(
                                      s.status == AgentActivityStatus.failed
                                          ? 'CircleAlert'
                                          : 'CircleCheck',
                                      size: 18),
                                  title: s.title,
                                  subtitle: !widget.hideDetails &&
                                          s.details.isNotEmpty
                                      ? s.details.join('\n')
                                      : null,
                                ),
                            ])));
                  } else {
                    setState(() => _expanded = !expanded);
                    widget.onExpansionChanged?.call(!expanded);
                  }
                },
                style: TextButton.styleFrom(
                    foregroundColor: muted,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(44, 44)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (basis != null) ...[
                    const BeeLineIcon('CircleCheck', size: 14),
                    const SizedBox(width: 4)
                  ],
                  Flexible(
                      child: Text(summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12))),
                  const SizedBox(width: 2),
                  BeeLineIcon(
                      basis != null && expanded ? 'ChevronUp' : 'ChevronDown',
                      size: 14),
                ]),
              )),
        if (widget.onMore != null)
          IconButton(
              key: ValueKey('agent-answer-more-${widget.messageId}'),
              tooltip: l.aiChatAnswerActions,
              icon: const BeeLineIcon('Ellipsis', size: 20),
              onPressed: widget.onMore),
      ]),
      if (basis != null && expanded)
        Container(
            margin: const EdgeInsetsDirectional.fromSTEB(5, 0, 0, 7),
            padding: const EdgeInsetsDirectional.only(start: 12),
            decoration: BoxDecoration(
                border: BorderDirectional(
                    start: BorderSide(color: Theme.of(context).dividerColor))),
            child: Text(
                widget.hideDetails
                    ? l.aiChatHiddenMessage
                    : [...basis.details, basis.title].join('\n'),
                style: TextStyle(fontSize: 12, height: 1.6, color: muted))),
    ]);
  }
}
