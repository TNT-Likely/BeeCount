import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
export 'analytics_cards.dart';

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
      this.onView,
      this.views,
      this.selectedView,
      this.onViewChanged,
      this.ledgerLabel,
      this.onAverage});
  final String period,
      viewLabel,
      totalLabel,
      total,
      countLabel,
      count,
      averageLabel,
      average;
  final String? ledgerLabel, selectedView;
  final List<BeeSegment<String>>? views;
  final ValueChanged<String>? onViewChanged;
  final VoidCallback? onPeriod, onView, onAverage;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        final theme = Theme.of(context),
            compact = bounds.maxWidth < 330,
            textScale = MediaQuery.textScalerOf(context),
            muted = theme.hintColor;
        final inset = compact ? 15.0 : 18.0,
            tabWidth = compact ? 139.0 : 168.0,
            font = compact ? 10.0 : 11.0;
        final options = views;
        double widest = 0;
        for (final item in options ?? <BeeSegment<String>>[]) {
          final p = TextPainter(
              text:
                  TextSpan(text: item.label, style: TextStyle(fontSize: font)),
              textDirection: Directionality.of(context),
              textScaler: textScale)
            ..layout();
          if (p.width > widest) widest = p.width;
          p.dispose();
        }
        final stacked =
            options != null && (widest + 12) * options.length > tabWidth;
        final tabs = options == null
            ? null
            : BeeCompactTabs<String>(
                items: options,
                value: selectedView ?? '',
                onChanged: onViewChanged,
                trackHeight: compact ? 28 : 29,
                fontSize: font);
        Widget selector(String label, VoidCallback? action) => TextButton(
            onPressed: action,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: muted,
                disabledForegroundColor: muted),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: compact ? 10 : 12,
                          fontWeight: FontWeight.w400))),
              if (action != null)
                const Padding(
                    padding: EdgeInsets.only(left: 3),
                    child: BeeLineIcon('ChevronDown', size: 12))
            ]));
        Widget metric(String label, String value, {VoidCallback? action}) =>
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  InkWell(
                      onTap: action,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: compact ? 9 : 10, color: muted))),
                        if (action != null)
                          Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child:
                                  BeeLineIcon('Info', size: 11, color: muted))
                      ])),
                  const SizedBox(height: 3),
                  FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(value,
                          style: TextStyle(
                              fontSize: compact ? 14 : 15,
                              fontWeight: FontWeight.w600)))
                ]));
        final numberStart = RegExp(r'[0-9]').firstMatch(total)?.start ?? 0;
        final heroSize = compact ? 33.0 : 37.0;
        return BeeSurface(
            padding: EdgeInsets.fromLTRB(inset, 16, inset, 17),
            borderRadius: BorderRadius.circular(compact ? 21 : 23),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (stacked) ...[
                    Align(
                        alignment: Alignment.centerLeft,
                        child: selector(period, onPeriod)),
                    tabs!,
                    const SizedBox(height: 7)
                  ] else
                    Row(children: [
                      Expanded(
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: selector(period, onPeriod))),
                      const SizedBox(width: 8),
                      if (tabs != null)
                        SizedBox(width: tabWidth, child: tabs)
                      else
                        selector(viewLabel, onView)
                    ]),
                  const SizedBox(height: 6),
                  Text(
                      [
                        totalLabel,
                        if (ledgerLabel?.isNotEmpty ?? false) ledgerLabel!
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: muted)),
                  const SizedBox(height: 3),
                  Semantics(
                      label: '$totalLabel $total',
                      excludeSemantics: true,
                      child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text.rich(
                              TextSpan(children: [
                                if (numberStart > 0)
                                  TextSpan(
                                      text: total.substring(0, numberStart),
                                      style: TextStyle(
                                          fontSize: compact ? 22 : 24)),
                                TextSpan(text: total.substring(numberStart))
                              ]),
                              style: TextStyle(
                                  fontSize: heroSize,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                  letterSpacing: -1.0)))),
                  SizedBox(height: compact ? 17 : 20),
                  Row(children: [
                    metric(countLabel, count),
                    const SizedBox(width: 12),
                    metric(averageLabel, average, action: onAverage)
                  ])
                ]));
      });
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
