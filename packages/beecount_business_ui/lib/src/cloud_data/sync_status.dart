import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

enum BeeSyncState {
  signedOut,
  unconfigured,
  noCloudData,
  synced,
  localNewer,
  cloudNewer,
  conflict,
  checking,
  syncing,
  offline,
  error
}

class BeeSyncStatus extends StatelessWidget {
  const BeeSyncStatus(
      {super.key,
      required this.state,
      required this.title,
      required this.label,
      this.detail,
      this.progress,
      this.onTap,
      this.action});
  final BeeSyncState state;
  final String title, label;
  final String? detail;
  final double? progress;
  final VoidCallback? onTap;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (state) {
      BeeSyncState.synced => const Color(0xff43835e),
      BeeSyncState.error || BeeSyncState.offline => theme.colorScheme.error,
      BeeSyncState.localNewer ||
      BeeSyncState.cloudNewer ||
      BeeSyncState.conflict =>
        theme.brightness == Brightness.dark
            ? const Color(0xffe9bc70)
            : const Color(0xffa06a14),
      _ => theme.hintColor
    };
    final busy =
        state == BeeSyncState.checking || state == BeeSyncState.syncing;
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(children: [
              Row(children: [
                const SizedBox(
                    width: 26, child: BeeLineIcon('CloudSync', size: 18)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 3),
                      Text(label,
                          style: TextStyle(
                              fontSize: 11, height: 1.6, color: color)),
                      if (detail != null)
                        Text(detail!,
                            style:
                                TextStyle(fontSize: 10, color: theme.hintColor))
                    ])),
                if (action != null)
                  action!
                else if (busy)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 1.5))
                else
                  BeeLineIcon(
                      switch (state) {
                        BeeSyncState.synced => 'Check',
                        BeeSyncState.error ||
                        BeeSyncState.offline ||
                        BeeSyncState.conflict =>
                          'CircleHelp',
                        _ => 'ChevronRight'
                      },
                      size: 18,
                      color: color)
              ]),
              if (state == BeeSyncState.syncing && progress != null) ...[
                const SizedBox(height: 7),
                LinearProgressIndicator(
                    value: progress!.isFinite ? progress!.clamp(0, 1) : null,
                    minHeight: 3)
              ]
            ])));
  }
}
