import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Presentation of a fixed CSV export. The host supplies the current ledger,
/// localized columns and task state; repository, platform and file I/O stay out.
class BeeTransactionExport extends StatelessWidget {
  const BeeTransactionExport({
    super.key,
    required this.description,
    required this.ledgerLabel,
    required this.fieldLabels,
    required this.actionLabel,
    required this.onExport,
    this.ledgerName,
    this.exporting = false,
    this.progress = 0,
    this.savedMessage,
    this.errorTitle,
    this.errorMessage,
  });

  final String description, ledgerLabel, actionLabel;
  final String? ledgerName, savedMessage, errorTitle, errorMessage;
  final List<String> fieldLabels;
  final bool exporting;
  final double progress;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const BeeLineIcon('FileSpreadsheet', size: 24),
          const SizedBox(width: 10),
          const Text('CSV',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const Spacer(),
          const BeeLineIcon('FileDown', size: 20),
        ]),
        const SizedBox(height: 12),
        Text(description,
            style: TextStyle(fontSize: 13, height: 1.6, color: muted)),
        if (ledgerName != null) ...[
          const SizedBox(height: 14),
          const Divider(height: 1),
          BeeMenuRow(
              title: ledgerLabel,
              subtitle: ledgerName,
              leading: const BeeLineIcon('BookOpen', size: 20)),
        ],
      ])),
      const SizedBox(height: 12),
      BeeSurface(
          child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final label in fieldLabels)
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                  color: BeeCardTheme.of(context).soft,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const BeeLineIcon('Check', size: 12),
                const SizedBox(width: 5),
                Flexible(
                    child: Text(label, style: const TextStyle(fontSize: 12))),
              ])),
      ])),
      const SizedBox(height: 16),
      BeeButton(
          key: const ValueKey('transaction-export-action'),
          label: actionLabel,
          icon: const BeeLineIcon('FileDown', size: 18),
          loading: exporting,
          onPressed: exporting ? null : onExport),
      if (exporting) ...[
        const SizedBox(height: 12),
        BeeSurface(
            child: Semantics(
                liveRegion: true,
                child: BeeProgress(
                    value: progress == 0 ? null : progress,
                    label: actionLabel,
                    trailing: progress == 0
                        ? null
                        : '${(progress * 100).round()}%'))),
      ],
      if (savedMessage != null) ...[
        const SizedBox(height: 12),
        _ExportMessage(
            icon: 'CircleCheck', message: savedMessage!, success: true),
      ],
      if (errorMessage != null) ...[
        const SizedBox(height: 12),
        _ExportMessage(
            icon: 'CircleAlert', title: errorTitle, message: errorMessage!),
      ],
    ]);
  }
}

class _ExportMessage extends StatelessWidget {
  const _ExportMessage(
      {required this.icon,
      required this.message,
      this.title,
      this.success = false});
  final String icon, message;
  final String? title;
  final bool success;
  @override
  Widget build(BuildContext context) => BeeSurface(
      child: Semantics(
          liveRegion: true,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BeeLineIcon(icon,
                size: 20,
                color: success ? null : Theme.of(context).colorScheme.error),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  if (title != null) ...[
                    Text(title!,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                  ],
                  SelectableText(message,
                      style: const TextStyle(fontSize: 12, height: 1.5)),
                ])),
          ])));
}
