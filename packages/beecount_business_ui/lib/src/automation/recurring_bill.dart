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
    this.nextRunLabel,
    this.nextRunHighlighted = false,
    this.nextRunMuted = false,
    this.warningMessage,
    this.busy = false,
    this.onOpen,
    this.onToggle,
  });

  final String title, ledger, frequency, toggleLabel;
  final String? note, lastGenerated, nextRunLabel, warningMessage;
  final Widget amount, icon;
  final bool enabled, busy, nextRunHighlighted, nextRunMuted;
  final VoidCallback? onOpen;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    final cards = BeeCardTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasNote = note?.trim().isNotEmpty ?? false;
    final hasWarning = warningMessage?.trim().isNotEmpty ?? false;
    final hasNextRun = nextRunLabel?.trim().isNotEmpty ?? false;

    Widget detail(String name, String value) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeeLineIcon(name, size: 13.5, color: muted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(value,
                  style: TextStyle(fontSize: 11.5, height: 1.35, color: muted)),
            ),
          ],
        );

    Widget buildNextPill() {
      final bg = nextRunHighlighted
          ? scheme.primary
          : nextRunMuted
              ? cards.soft
              : scheme.primary.withValues(alpha: 0.12);
      final fg = nextRunHighlighted
          ? scheme.onPrimary
          : nextRunMuted
              ? muted
              : scheme.onSurface;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: nextRunHighlighted || nextRunMuted
              ? null
              : Border.all(color: cards.divider, width: 0.8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!nextRunMuted) ...[
                BeeLineIcon('Calendar', size: 12.5, color: fg),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  nextRunLabel!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final warnColor = beeToneColor(context, BeeTone.warning);

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
                Opacity(
                  opacity: enabled ? 1.0 : 0.62,
                  child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: cards.soft,
                          borderRadius: BorderRadius.circular(12)),
                      child: Center(child: ExcludeSemantics(child: icon))),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Opacity(
                  opacity: enabled ? 1.0 : 0.68,
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
                      ]),
                )),
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
              const SizedBox(height: 11),
              Opacity(
                opacity: enabled ? 1.0 : 0.68,
                child: LayoutBuilder(builder: (context, constraints) {
                  if (!hasNote) {
                    return Align(
                        alignment: Alignment.centerRight, child: amount);
                  }
                  if (constraints.maxWidth < 260) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(alignment: Alignment.centerRight, child: amount),
                        const SizedBox(height: 6),
                        Text(note!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: muted)),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(note!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: muted)),
                      ),
                      const SizedBox(width: 10),
                      Flexible(child: amount),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: cards.divider),
              const SizedBox(height: 9),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 7,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      detail('Repeat2', frequency),
                      if (lastGenerated?.isNotEmpty ?? false)
                        detail('Clock', lastGenerated!),
                    ],
                  ),
                  if (hasNextRun) buildNextPill(),
                ],
              ),
              if (hasWarning) ...[
                const SizedBox(height: 9),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: warnColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        BeeLineIcon('CircleAlert', size: 14, color: warnColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            warningMessage!,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                              color: warnColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
