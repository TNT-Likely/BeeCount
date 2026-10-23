import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Labels and privacy formatting are supplied by the ledger binding.
class BeeBudgetStrip extends StatelessWidget {
  const BeeBudgetStrip(
      {super.key,
      required this.label,
      required this.remaining,
      required this.progress,
      this.onTap,
      this.exceeded = false});
  final String label, remaining;
  final double progress;
  final VoidCallback? onTap;
  final bool exceeded;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
            height: 26,
            child: Row(children: [
              Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: Theme.of(context).hintColor))),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(remaining,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color: exceeded
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).hintColor))),
              if (onTap != null)
                const Padding(
                    padding: EdgeInsets.only(left: 3),
                    child: BeeLineIcon('ChevronRight', size: 14)),
            ])),
        const SizedBox(height: 8),
        LinearProgressIndicator(
            value: progress.isFinite ? progress.clamp(0, 1) : 0,
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
            color: exceeded
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
            backgroundColor: BeeCardTheme.of(context).soft),
      ]));
}

class BeeTransactionStreamHeader extends StatelessWidget {
  const BeeTransactionStreamHeader(
      {super.key,
      required this.title,
      required this.count,
      required this.actions});
  final String title, count;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Column(children: [
        ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 43),
            child: Row(children: [
              Expanded(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                    Flexible(
                        flex: 3,
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text(count,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).hintColor))),
                  ])),
              ...actions,
            ])),
        const Divider(height: 1, thickness: .6),
      ]);
}

class BeeTransactionDayHeader extends StatelessWidget {
  const BeeTransactionDayHeader(
      {super.key,
      required this.title,
      required this.date,
      required this.totals,
      this.semanticLabel});
  final String title, date;
  final List<String> totals;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => Semantics(
      label: semanticLabel,
      child: Padding(
          padding: const EdgeInsets.only(top: 13, bottom: 1),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
                child: Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(date,
                      style: TextStyle(
                          fontSize: 11, color: Theme.of(context).hintColor)),
                ])),
            const SizedBox(width: 10),
            Flexible(
                child: Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    alignment: WrapAlignment.end,
                    children: totals
                        .map((value) => Text(value,
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).hintColor)))
                        .toList())),
          ])));
}
