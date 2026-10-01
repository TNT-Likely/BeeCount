import 'package:agentcore/agentcore.dart';
import 'package:flutter/material.dart';

/// Optional host palette. Unspecified colors follow the current Theme;
/// tinted surfaces are derived from primary, never Material's default tint.
@immutable
final class AgentFollowUpStyle {
  const AgentFollowUpStyle({
    this.surfaceColor,
    this.accentColor,
    this.foregroundColor,
    this.secondaryForegroundColor,
    this.separatorColor,
  });

  final Color? surfaceColor;
  final Color? accentColor;
  final Color? foregroundColor;
  final Color? secondaryForegroundColor;
  final Color? separatorColor;
}

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
      this.style = const AgentFollowUpStyle(),
      this.enabled = true,
      this.visibleQuestionCount = 2});

  final List<AgentPromptSuggestion> questions;
  final List<AgentPromptSuggestion> templates;
  final String title;
  final String rotateLabel;
  final ValueChanged<AgentPromptSuggestion> onSelected;
  final bool enabled;
  final AgentFollowUpStyle style;
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
    final accent = widget.style.accentColor ?? theme.colorScheme.primary;
    final foreground =
        widget.style.foregroundColor ?? theme.colorScheme.onSurface;
    final muted = widget.style.secondaryForegroundColor ??
        theme.colorScheme.onSurfaceVariant;
    final dark = theme.brightness == Brightness.dark;
    final surface = widget.style.surfaceColor ??
        Color.alphaBlend(accent.withValues(alpha: dark ? 0.15 : 0.08),
            theme.colorScheme.surface);
    final separator =
        widget.style.separatorColor ?? accent.withValues(alpha: 0.12);
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
                color: surface, borderRadius: BorderRadius.circular(14)),
            child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minHeight: 44),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                          key: const ValueKey(
                                              'agent-follow-up-accent'),
                                          width: 3,
                                          height: 12,
                                          decoration: BoxDecoration(
                                              color: accent,
                                              borderRadius:
                                                  BorderRadius.circular(3))),
                                      const SizedBox(width: 7),
                                      Flexible(
                                          child: Text(widget.title,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                      color: muted,
                                                      fontWeight:
                                                          FontWeight.w500))),
                                    ])),
                            if (questions.length > count)
                              TextButton(
                                  key: const ValueKey('agent-follow-up-rotate'),
                                  onPressed: widget.enabled
                                      ? () => setState(() => _start =
                                          (_start + count) % questions.length)
                                      : null,
                                  style: TextButton.styleFrom(
                                      foregroundColor: muted,
                                      minimumSize: const Size(0, 44),
                                      padding: const EdgeInsets.only(left: 8),
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
                      for (var index = 0; index < shown.length; index++) ...[
                        if (index > 0)
                          Divider(
                              key: ValueKey('agent-follow-up-divider-$index'),
                              height: 1,
                              thickness: 1,
                              color: separator),
                        _QuestionRow(
                            item: shown[index],
                            enabled: widget.enabled,
                            foreground: foreground,
                            muted: muted,
                            accent: accent,
                            onSelected: widget.onSelected),
                      ],
                    ]))));
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow(
      {required this.item,
      required this.enabled,
      required this.foreground,
      required this.muted,
      required this.accent,
      required this.onSelected});
  final AgentPromptSuggestion item;
  final bool enabled;
  final Color foreground;
  final Color muted;
  final Color accent;
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
                foregroundColor: foreground,
                overlayColor: accent.withValues(alpha: 0.08),
                alignment: AlignmentDirectional.centerStart,
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(vertical: 9)),
            child: Row(children: [
              Expanded(
                  child: Text(item.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: enabled ? foreground : theme.disabledColor))),
              const SizedBox(width: 10),
              Icon(Icons.north_east_rounded,
                  size: 14, color: enabled ? muted : theme.disabledColor),
            ])));
  }
}
