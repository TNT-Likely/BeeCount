import 'package:agentcore/agentcore.dart';
import 'package:flutter/material.dart';

/// Contextual questions and host templates share one locally rotating pool.
/// Rotating candidates is local; this widget never sends model requests.
class AgentFollowUpSection extends StatefulWidget {
  const AgentFollowUpSection(
      {super.key,
      required this.questions,
      required this.templates,
      required this.title,
      required this.rotateLabel,
      required this.onSelected,
      this.enabled = true,
      this.visibleQuestionCount = 2});

  final List<AgentPromptSuggestion> questions;
  final List<AgentPromptSuggestion> templates;
  final String title;
  final String rotateLabel;
  final ValueChanged<AgentPromptSuggestion> onSelected;
  final bool enabled;
  final int visibleQuestionCount;

  @override
  State<AgentFollowUpSection> createState() => _AgentFollowUpSectionState();
}

class _AgentFollowUpSectionState extends State<AgentFollowUpSection> {
  int _start = 0;

  String _fingerprint(AgentFollowUpSection widget) =>
      [...widget.questions, ...widget.templates]
          .map((item) => '${item.id}\u0000${item.title}\u0000${item.prompt}')
          .join('\u0001');

  @override
  void didUpdateWidget(AgentFollowUpSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_fingerprint(oldWidget) != _fingerprint(widget)) {
      _start = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty && widget.templates.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final count = widget.visibleQuestionCount.clamp(1, 3);
    final ids = <String>{};
    final prompts = <String>{};
    final questions = [...widget.questions, ...widget.templates]
        .where(
            (item) => !ids.contains(item.id) && !prompts.contains(item.prompt))
        .where((item) {
      ids.add(item.id);
      prompts.add(item.prompt);
      return true;
    }).toList();
    final shown = questions.isEmpty
        ? const <AgentPromptSuggestion>[]
        : [
            for (var index = 0;
                index < count && index < questions.length;
                index++)
              questions[(_start + index) % questions.length],
          ];
    return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: DecoratedBox(
            key: const ValueKey('agent-follow-up-surface'),
            decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(widget.title,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: muted)),
                            if (questions.length > count)
                              TextButton(
                                  key: const ValueKey('agent-follow-up-rotate'),
                                  onPressed: widget.enabled
                                      ? () => setState(() => _start =
                                          (_start + count) % questions.length)
                                      : null,
                                  style: TextButton.styleFrom(
                                      foregroundColor: muted,
                                      textStyle: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w400)),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shuffle_rounded,
                                            size: 14, color: muted),
                                        const SizedBox(width: 5),
                                        Flexible(
                                            child: Text(widget.rotateLabel)),
                                      ])),
                          ]),
                      for (final question in shown)
                        _QuestionRow(
                            item: question,
                            enabled: widget.enabled,
                            onSelected: widget.onSelected),
                    ]))));
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow(
      {required this.item, required this.enabled, required this.onSelected});
  final AgentPromptSuggestion item;
  final bool enabled;
  final ValueChanged<AgentPromptSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
        message: item.prompt,
        child: TextButton(
            key: ValueKey('agent-follow-up-${item.id}'),
            onPressed: enabled ? () => onSelected(item) : null,
            style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface,
                alignment: AlignmentDirectional.centerStart,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(vertical: 10)),
            child: Row(children: [
              Expanded(
                  child: Text(item.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: enabled
                              ? theme.colorScheme.onSurface
                              : theme.disabledColor))),
              const SizedBox(width: 10),
              Icon(Icons.north_east_rounded,
                  size: 14,
                  color: enabled
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.disabledColor),
            ])));
  }
}
