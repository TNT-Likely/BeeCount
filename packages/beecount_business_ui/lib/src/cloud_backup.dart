import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Snapshot presentation only. Providers, file transport and restore stay in App.
class BeeCloudBackupSummary extends StatelessWidget {
  const BeeCloudBackupSummary(
      {super.key,
      required this.title,
      required this.status,
      required this.icon,
      this.tone = BeeTone.neutral,
      this.busy = false,
      this.localSummary,
      this.remoteSummary,
      this.backupTime,
      this.onDetails,
      this.error,
      this.retryLabel,
      this.onRetry});
  final String title, status;
  final String? localSummary, remoteSummary, backupTime, error, retryLabel;
  final Widget icon;
  final BeeTone tone;
  final bool busy;
  final VoidCallback? onDetails, onRetry;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
            onTap: onDetails,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: BeeCardTheme.of(context).soft,
                                borderRadius: BorderRadius.circular(13)),
                            child: ExcludeSemantics(child: icon)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600))),
                        const SizedBox(width: 8),
                        if (busy)
                          const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                        else if (onDetails != null)
                          const BeeLineIcon('ChevronRight', size: 18),
                      ]),
                      const SizedBox(height: 12),
                      Text(status,
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.55,
                              color: beeToneColor(context, tone))),
                      if (localSummary != null || remoteSummary != null) ...[
                        const SizedBox(height: 14),
                        Wrap(spacing: 12, runSpacing: 8, children: [
                          for (final label in [localSummary, remoteSummary])
                            if (label != null)
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                      color: BeeCardTheme.of(context).soft,
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text(label,
                                      style: const TextStyle(fontSize: 12))),
                        ]),
                      ],
                      if (backupTime != null) ...[
                        const SizedBox(height: 10),
                        Text(backupTime!,
                            style: TextStyle(
                                fontSize: 11,
                                height: 1.55,
                                color: Theme.of(context).hintColor))
                      ],
                    ]))),
        if (error != null)
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(error!,
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.55,
                            color: Theme.of(context).colorScheme.error)),
                    if (onRetry != null) ...[
                      const SizedBox(height: 10),
                      BeeButton(
                          label: retryLabel ?? title,
                          onPressed: onRetry,
                          kind: BeeButtonKind.secondary)
                    ],
                  ])),
      ]));
}

class BeeCloudBackupAction extends StatelessWidget {
  const BeeCloudBackupAction(
      {super.key,
      required this.title,
      required this.icon,
      this.subtitle,
      this.enabled = true,
      this.busy = false,
      this.onTap});
  final String title;
  final String? subtitle;
  final Widget icon;
  final bool enabled, busy;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Opacity(
      opacity: enabled || busy ? 1 : .45,
      child: BeeSurface(
          padding: EdgeInsets.zero,
          child: BeeMenuRow(
              title: title,
              subtitle: subtitle,
              leading: icon,
              onTap: enabled && !busy ? onTap : null,
              trailing: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : null)));
}

class BeeCloudBackupPreference extends StatelessWidget {
  const BeeCloudBackupPreference(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: EdgeInsets.zero,
      child: SwitchListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(title, style: const TextStyle(fontSize: 14)),
          subtitle: Text(subtitle,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).hintColor)),
          value: value,
          onChanged: onChanged));
}
