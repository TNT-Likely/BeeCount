import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// A recurring rule's presentation. Loading, currency formatting and writes
/// remain in the host app; this card never starts a schedule or creates a bill.
class BeeRecurringBillCard extends StatelessWidget {
  const BeeRecurringBillCard({
    super.key,
    required this.title,
    required this.ledger,
    required this.frequency,
    required this.amount,
    required this.icon,
    required this.enabled,
    required this.toggleLabel,
    this.note,
    this.lastGenerated,
    this.busy = false,
    this.onOpen,
    this.onToggle,
  });

  final String title, ledger, frequency, toggleLabel;
  final String? note, lastGenerated;
  final Widget amount, icon;
  final bool enabled, busy;
  final VoidCallback? onOpen;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    Widget detail(String name, String value) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeeLineIcon(name, size: 14, color: muted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(value, style: TextStyle(fontSize: 12, color: muted)),
            ),
          ],
        );
    return BeeSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: busy ? null : onOpen,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: BeeCardTheme.of(context).soft,
                        borderRadius: BorderRadius.circular(12)),
                    child: Center(child: ExcludeSemantics(child: icon))),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(ledger,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: muted)),
                    ])),
                const SizedBox(width: 6),
                if (busy) ...[
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 4),
                ],
                Semantics(
                    label: toggleLabel,
                    child: Switch(
                        value: enabled, onChanged: busy ? null : onToggle)),
              ]),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: amount),
              const SizedBox(height: 10),
              Wrap(spacing: 14, runSpacing: 7, children: [
                detail('Repeat2', frequency),
                if (lastGenerated?.isNotEmpty ?? false)
                  detail('Clock', lastGenerated!),
              ]),
              if (note?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Text(note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class BeeRecurringUsageNotice extends StatelessWidget {
  const BeeRecurringUsageNotice(
      {super.key, required this.title, required this.description});
  final String title, description;

  @override
  Widget build(BuildContext context) => BeeSurface(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const BeeLineIcon('Info', size: 20),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(description,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: Theme.of(context).hintColor)),
        ])),
      ]));
}
