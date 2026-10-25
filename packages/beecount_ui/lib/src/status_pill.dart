import 'package:flutter/material.dart';
import '../beecount_ui.dart';

/// A compact, non-interactive status. Copy and state are supplied by its host.
class BeeStatusPill extends StatelessWidget {
  const BeeStatusPill(
      {super.key,
      required this.label,
      this.tone = BeeTone.neutral,
      this.busy = false,
      this.icon});
  final String label;
  final BeeTone tone;
  final bool busy;
  final Widget? icon;
  @override
  Widget build(BuildContext context) {
    final color = beeToneColor(context, tone);
    return Semantics(
        liveRegion: true,
        excludeSemantics: true,
        label: label,
        child: DecoratedBox(
            decoration: BoxDecoration(
                color: color.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(99)),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (busy)
                    SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: color))
                  else
                    icon ??
                        BeeLineIcon(
                            tone == BeeTone.error || tone == BeeTone.warning
                                ? 'CircleAlert'
                                : 'CircleCheck',
                            size: 12,
                            color: color),
                  const SizedBox(width: 5),
                  Flexible(
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 10, height: 1.4, color: color)))
                ]))));
  }
}
