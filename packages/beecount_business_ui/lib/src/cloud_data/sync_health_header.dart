import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_ui/status_pill.dart';
import 'package:flutter/material.dart';

/// Read-only status header. The host retains all health rows, retries and errors.
class BeeSyncHealthHeader extends StatelessWidget {
  const BeeSyncHealthHeader(
      {super.key,
      required this.title,
      required this.status,
      this.busy = false,
      this.error = false,
      this.difference = false});
  final String title, status;
  final bool busy, error, difference;
  @override
  Widget build(BuildContext context) => Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.cloud_outlined,
                  size: 22, color: Theme.of(context).hintColor),
              const SizedBox(width: 10),
              Flexible(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)))
            ]),
            ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: BeeStatusPill(
                    key: const ValueKey('sync-health-status'),
                    label: status,
                    busy: busy,
                    tone: error
                        ? BeeTone.error
                        : difference
                            ? BeeTone.warning
                            : busy
                                ? BeeTone.neutral
                                : BeeTone.success)),
          ]);
}
