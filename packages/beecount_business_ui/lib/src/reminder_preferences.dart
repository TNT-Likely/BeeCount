import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// The App supplies real reminder preferences and performs OS scheduling.
/// Time stays selectable while reminders are off, matching the original flow.
class BeeReminderPreferences extends StatelessWidget {
  const BeeReminderPreferences(
      {super.key,
      required this.enabled,
      required this.enabledLabel,
      required this.enabledDescription,
      required this.timeLabel,
      required this.time,
      required this.onEnabled,
      required this.onTime});
  final bool enabled;
  final String enabledLabel, enabledDescription, timeLabel, time;
  final ValueChanged<bool>? onEnabled;
  final VoidCallback? onTime;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        BeeToggleRow(
            title: enabledLabel,
            subtitle: enabledDescription,
            value: enabled,
            onChanged: onEnabled),
        const BeeDivider(inset: 4),
        BeeMenuRow(
            title: timeLabel,
            subtitle: time,
            leading: const BeeLineIcon('Clock'),
            onTap: onTime),
      ]));
}
