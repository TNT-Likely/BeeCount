import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

enum BeeFileTaskState { ready, running, success, partial, error }

/// File workflow presentation. Providers, storage and archive I/O stay in App.
class BeeFileTransferStatus extends StatelessWidget {
  const BeeFileTransferStatus(
      {super.key,
      required this.title,
      required this.state,
      this.subtitle,
      this.leading,
      this.progress,
      this.progressLabel,
      this.onTap,
      this.onPreview,
      this.previewLabel,
      this.animateCompletion = false});
  final String title;
  final String? subtitle, progressLabel, previewLabel;
  final Widget? leading;
  final BeeFileTaskState state;
  final double? progress;
  final VoidCallback? onTap, onPreview;
  final bool animateCompletion;
  @override
  Widget build(BuildContext context) {
    final busy = state == BeeFileTaskState.running;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = switch (state) {
      BeeFileTaskState.success =>
        dark ? const Color(0xff8bd4aa) : const Color(0xff38845c),
      BeeFileTaskState.partial =>
        dark ? const Color(0xfff5d580) : const Color(0xff88620c),
      BeeFileTaskState.error =>
        dark ? const Color(0xffffb3b3) : const Color(0xffb54242),
      _ => Theme.of(context).colorScheme.onSurface
    };
    Widget bar(double? value) =>
        BeeProgress(value: value, label: progressLabel ?? subtitle ?? title);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeMenuRow(
          title: title,
          subtitle: subtitle,
          leading: IconTheme(
              data: IconThemeData(color: statusColor, size: 20),
              child: leading ??
                  Icon(switch (state) {
                    BeeFileTaskState.success => Icons.check_circle_outline,
                    BeeFileTaskState.partial => Icons.info_outline,
                    BeeFileTaskState.error => Icons.error_outline,
                    _ => Icons.file_upload_outlined
                  })),
          trailing: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : onPreview != null
                  ? BeeIconButton(
                      icon: const Icon(Icons.preview_outlined, size: 20),
                      label: previewLabel ?? title,
                      onPressed: onPreview)
                  : onTap != null
                      ? const Icon(Icons.chevron_right, size: 18)
                      : const SizedBox.shrink(),
          onTap: busy ? null : onTap),
      if (busy || state == BeeFileTaskState.success)
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: animateCompletion && state == BeeFileTaskState.success
                ? TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => bar(value))
                : bar(progress))
    ]);
  }
}

class BeeArchiveSummary extends StatelessWidget {
  const BeeArchiveSummary(
      {super.key,
      required this.fileName,
      required this.details,
      required this.strategyLabel,
      required this.skipLabel,
      required this.overwriteLabel,
      required this.overwrite,
      required this.onOverwrite});
  final String fileName, strategyLabel, skipLabel, overwriteLabel;
  final List<String> details;
  final bool overwrite;
  final ValueChanged<bool>? onOverwrite;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.archive_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(fileName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)))
        ]),
        const SizedBox(height: 12),
        for (final text in details)
          Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(text,
                  style: TextStyle(
                      fontSize: 13, color: Theme.of(context).hintColor))),
        const SizedBox(height: 12),
        Text(strategyLabel,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        BeeRadioTile<bool>(
            value: false,
            groupValue: overwrite,
            label: skipLabel,
            onChanged: onOverwrite),
        BeeRadioTile<bool>(
            value: true,
            groupValue: overwrite,
            label: overwriteLabel,
            onChanged: onOverwrite),
      ]);
}
