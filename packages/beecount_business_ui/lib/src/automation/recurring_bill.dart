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
    this.amountLabel,
    this.lastGenerated,
    this.nextRunCaption,
    this.nextRunLabel,
    this.nextRunHighlighted = false,
    this.nextRunMuted = false,
    this.warningMessage,
    this.busy = false,
    this.onOpen,
    this.onToggle,
  });

  final String title, ledger, frequency, toggleLabel;
  final String? note,
      amountLabel,
      lastGenerated,
      nextRunCaption,
      nextRunLabel,
      warningMessage;
  final Widget amount, icon;
  final bool enabled, busy, nextRunHighlighted, nextRunMuted;
  final VoidCallback? onOpen;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    final cards = BeeCardTheme.of(context);
    final foreground = Theme.of(context).colorScheme.onSurface;
    final hasNote = note?.trim().isNotEmpty ?? false;
    final hasWarning = warningMessage?.trim().isNotEmpty ?? false;
    final hasNextRun = nextRunLabel?.trim().isNotEmpty ?? false;

    Widget caption(String text) =>
        Text(text, style: TextStyle(fontSize: 11, height: 1.4, color: muted));

    Widget buildNextRunDetail({bool inline = false}) {
      final color = nextRunHighlighted && !nextRunMuted
          ? beeToneColor(context, BeeTone.success)
          : nextRunMuted
              ? muted
              : foreground;
      final date = Text(
        nextRunLabel!,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: nextRunMuted ? 14 : 17,
          fontWeight: FontWeight.w600,
          height: 1.5,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
      if (inline) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nextRunCaption != null) ...[
              Expanded(child: caption(nextRunCaption!)),
              const SizedBox(width: 12),
            ],
            Expanded(child: date),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (nextRunCaption != null) ...[
            caption(nextRunCaption!),
            const SizedBox(height: 3),
          ],
          date,
        ],
      );
    }

    Widget buildPrimary() => LayoutBuilder(builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          // Give the amount a full line on compact screens and at larger text
          // sizes, rather than leaving its sign or currency in a separate column.
          final stacked = constraints.maxWidth / scale < 290;
          final amountDetail = Opacity(
            opacity: enabled ? 1 : 0.68,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (amountLabel != null) ...[
                  caption(amountLabel!),
                  const SizedBox(height: 3),
                ],
                Align(alignment: Alignment.centerLeft, child: amount),
              ],
            ),
          );
          if (stacked || !hasNextRun) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                amountDetail,
                if (hasNextRun) ...[
                  const SizedBox(height: 12),
                  buildNextRunDetail(inline: true),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 5, child: amountDetail),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: buildNextRunDetail()),
            ],
          );
        });

    Widget buildFooter() => LayoutBuilder(builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
          final details = [
            Text(frequency,
                style:
                    TextStyle(fontSize: 11.5, height: 1.4, color: foreground)),
            if (lastGenerated?.isNotEmpty ?? false)
              Text(lastGenerated!,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, height: 1.4, color: muted)),
          ];
          if (constraints.maxWidth / scale < 290) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                details.first,
                if (details.length > 1) ...[
                  const SizedBox(height: 4),
                  details.last,
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details.first),
              if (details.length > 1) ...[
                const SizedBox(width: 12),
              Expanded(child: details.last),
              ],
            ],
          );
        });

    final warnColor = beeToneColor(context, BeeTone.warning);

    return BeeSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: busy ? null : onOpen,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Opacity(
                  opacity: enabled ? 1.0 : 0.62,
                  child: Container(
                      width: 38,
                      height: 38,
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
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: foreground)),
                        if (hasNote) ...[
                          const SizedBox(height: 3),
                          Text(note!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.5, height: 1.4, color: muted)),
                        ],
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
              const SizedBox(height: 18),
              buildPrimary(),
              const SizedBox(height: 14),
              Divider(height: 1, color: cards.divider),
              const SizedBox(height: 11),
              buildFooter(),
              const SizedBox(height: 6),
              Text(ledger,
                  style: TextStyle(fontSize: 11, height: 1.4, color: muted)),
              if (hasWarning) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(3, 0, 3, 4),
      child: Text(description,
          style: TextStyle(
              fontSize: 12, height: 1.55, color: Theme.of(context).hintColor)));
}
