import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Prepared labels only. The host owns periods, currency, privacy and queries.
class BeeAnalyticsSummary extends StatelessWidget {
  const BeeAnalyticsSummary(
      {super.key,
      required this.period,
      required this.viewLabel,
      required this.totalLabel,
      required this.total,
      required this.countLabel,
      required this.count,
      required this.averageLabel,
      required this.average,
      this.onPeriod,
      required this.onView});
  final String period,
      viewLabel,
      totalLabel,
      total,
      countLabel,
      count,
      averageLabel,
      average;
  final VoidCallback? onPeriod;
  final VoidCallback onView;
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    Widget selector(String label, VoidCallback? action) => TextButton(
        onPressed: action,
        style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            disabledForegroundColor: Theme.of(context).colorScheme.onSurface,
            padding: EdgeInsets.zero),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600))),
          if (action != null)
            const Padding(
                padding: EdgeInsets.only(left: 4),
                child: BeeLineIcon('ChevronDown', size: 14))
        ]));
    Widget metric(String label, String value) => Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 5),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
        ]));
    return BeeSurface(
        padding: const EdgeInsets.all(18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: selector(period, onPeriod))),
            const SizedBox(width: 8),
            Flexible(child: selector(viewLabel, onView))
          ]),
          const SizedBox(height: 4),
          Text(totalLabel, style: TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 8),
          Semantics(
              label: '$totalLabel $total',
              excludeSemantics: true,
              child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(total,
                      style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w600,
                          height: 1.15)))),
          const SizedBox(height: 20),
          Row(children: [
            metric(countLabel, count),
            const SizedBox(width: 12),
            metric(averageLabel, average)
          ])
        ]));
  }
}

class BeeAnalyticsHint extends StatelessWidget {
  const BeeAnalyticsHint({super.key, required this.label, this.onClose});
  final String label;
  final VoidCallback? onClose;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(Icons.swipe_outlined,
            size: 16, color: Theme.of(context).hintColor),
        const SizedBox(width: 6),
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).hintColor))),
        if (onClose != null)
          BeeIconButton(
              label: label,
              onPressed: onClose,
              icon: const BeeLineIcon('X', size: 14))
      ]);
}
