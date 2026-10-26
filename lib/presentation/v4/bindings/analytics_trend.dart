import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'analytics_data.dart';

class AnalyticsTrend extends StatefulWidget {
  const AnalyticsTrend(
      {super.key,
      required this.data,
      required this.scope,
      required this.title,
      required this.unit,
      required this.averageLabel,
      required this.formatValue,
      required this.onAverage,
      this.onPrevious,
      this.onNext});
  final AnalyticsResult data;
  final String scope, title, unit, averageLabel;
  final String Function(double) formatValue;
  final VoidCallback onAverage;
  final VoidCallback? onPrevious, onNext;
  @override
  State<AnalyticsTrend> createState() => _AnalyticsTrendState();
}

class _AnalyticsTrendState extends State<AnalyticsTrend> {
  int? selected;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), theme = Theme.of(context);
    final raw = widget.data.series;
    final labels = raw is List<({DateTime day, double total})>
        ? raw
            .map((e) =>
                '${e.day.month.toString().padLeft(2, '0')}.${e.day.day.toString().padLeft(2, '0')}')
            .toList()
        : raw is List<({DateTime month, double total})>
            ? raw.map((e) => l.homeMonth('${e.month.month}')).toList()
            : raw is List<({int year, double total})>
                ? raw.map((e) => '${e.year}').toList()
                : <String>[];
    final today = DateUtils.dateOnly(DateTime.now());
    final active = raw is List<({DateTime day, double total})>
        ? raw.indexWhere((e) => DateUtils.isSameDay(e.day, today))
        : -1;
    Widget move(String label, String icon, VoidCallback? action,
        {bool back = false}) {
      final painter = TextPainter(
          text: TextSpan(text: label, style: const TextStyle(fontSize: 10)),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context))
        ..layout();
      final showText = painter.width <= 70;
      final width = showText ? painter.width + 14 : 36.0;
      painter.dispose();
      return Tooltip(
          message: label,
          child: SizedBox(
              width: width,
              child: TextButton(
                  onPressed: action,
                  style: TextButton.styleFrom(
                      foregroundColor: theme.hintColor,
                      minimumSize: const Size(0, 32),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (back || !showText) BeeLineIcon(icon, size: 12),
                        if (showText)
                          Text(label, style: const TextStyle(fontSize: 10)),
                        if (!back && showText) BeeLineIcon(icon, size: 12)
                      ]))));
    }

    return LayoutBuilder(builder: (context, bounds) {
      final compact = bounds.maxWidth < 330;
      return BeeSurface(
          padding: EdgeInsets.fromLTRB(17, 18, 17, 9),
          borderRadius: BorderRadius.circular(compact ? 21 : 23),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                  child: Text(widget.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600))),
              Text(widget.unit,
                  style: TextStyle(fontSize: 10, color: theme.hintColor))
            ]),
            const SizedBox(height: 15),
            BeeColumnChart(
                values: widget.data.values,
                labels: labels,
                valueLabels:
                    widget.data.values.map(widget.formatValue).toList(),
                average: widget.data.average,
                averageLabel: widget.averageLabel,
                selected: selected,
                highlightIndex: active < 0 ? null : active,
                onSelected: (i) =>
                    setState(() => selected = selected == i ? null : i),
                onAverage: widget.onAverage,
                plotHeight: compact ? 132 : 145),
            const SizedBox(height: 5),
            Row(children: [
              if (widget.scope != 'all')
                move(l.v4InsightsPreviousPeriod, 'ChevronLeft',
                    widget.onPrevious,
                    back: true),
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(l.v4InsightsTapBar,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style:
                              TextStyle(fontSize: 9, color: theme.hintColor)))),
              if (widget.scope != 'all')
                move(l.v4InsightsNextPeriod, 'ChevronRight', widget.onNext)
            ])
          ]));
    });
  }
}
