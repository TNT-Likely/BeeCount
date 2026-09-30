import 'package:flutter/material.dart';

enum AgentActivityStatus {
  preparing,
  waiting,
  running,
  generating,
  completed,
  failed
}

/// A display-only projection. Hosts must whitelist data before constructing
/// this model; the UI never receives raw tool arguments, results or exceptions.
@immutable
class AgentActivityStep {
  const AgentActivityStep(
      {required this.title, required this.status, this.details = const []});

  final String title;
  final AgentActivityStatus status;
  final List<String> details;

  Map<String, Object?> toJson() => {
        'title': title,
        'status': status.name,
        'details': details,
      };

  static AgentActivityStep? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final title = raw['title'];
    final status = raw['status'];
    final details = raw['details'];
    if (title is! String ||
        title.trim().isEmpty ||
        title.length > 160 ||
        status is! String ||
        details is! List ||
        details.length > 8) {
      return null;
    }
    final statuses =
        AgentActivityStatus.values.where((value) => value.name == status);
    if (statuses.isEmpty ||
        details.any((line) => line is! String || line.length > 300)) {
      return null;
    }
    return AgentActivityStep(
        title: title,
        status: statuses.first,
        details: List<String>.unmodifiable(details.cast<String>()));
  }
}

/// A quiet, expandable real execution status, separate from answer content.
/// Strings and status come from the host, not an inferred reasoning narrative.
class AgentActivityView extends StatefulWidget {
  const AgentActivityView(
      {super.key,
      required this.summary,
      required this.status,
      required this.steps,
      this.initiallyExpanded = false});

  final String summary;
  final AgentActivityStatus status;
  final List<AgentActivityStep> steps;
  final bool initiallyExpanded;

  @override
  State<AgentActivityView> createState() => _AgentActivityViewState();
}

class _AgentActivityViewState extends State<AgentActivityView> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final color = widget.status == AgentActivityStatus.failed
        ? theme.colorScheme.error
        : muted;
    final busy = widget.status == AgentActivityStatus.preparing ||
        widget.status == AgentActivityStatus.running ||
        widget.status == AgentActivityStatus.generating;
    final hasDetails = widget.steps.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
          liveRegion: true,
          button: hasDetails,
          expanded: hasDetails ? _expanded : null,
          child: InkWell(
            key: const ValueKey('agent-activity-toggle'),
            onTap: hasDetails
                ? () => setState(() => _expanded = !_expanded)
                : null,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(children: [
                  if (busy)
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.6, color: muted))
                  else
                    Icon(_icon(widget.status), size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(widget.summary,
                          key: const ValueKey('agent-execution-phase'),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: color))),
                  if (hasDetails) ...[
                    const SizedBox(width: 8),
                    Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: muted),
                  ],
                ])),
          )),
      if (_expanded && hasDetails)
        Padding(
            key: const ValueKey('agent-activity-details'),
            padding: const EdgeInsets.only(left: 6, bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: theme.dividerColor))),
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final step in widget.steps)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(_icon(step.status),
                                        size: 15,
                                        color: step.status ==
                                                AgentActivityStatus.failed
                                            ? theme.colorScheme.error
                                            : muted)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(step.title,
                                          style: theme.textTheme.bodySmall),
                                      for (final detail in step.details)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 3),
                                            child: Text(detail,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                        color: muted,
                                                        height: 1.5))),
                                    ])),
                              ])),
                  ]),
            )),
    ]);
  }
}

IconData _icon(AgentActivityStatus status) => switch (status) {
      AgentActivityStatus.failed => Icons.error_outline_rounded,
      AgentActivityStatus.waiting => Icons.hourglass_empty_rounded,
      AgentActivityStatus.running ||
      AgentActivityStatus.preparing ||
      AgentActivityStatus.generating =>
        Icons.sync_rounded,
      AgentActivityStatus.completed => Icons.check_circle_outline_rounded,
    };
