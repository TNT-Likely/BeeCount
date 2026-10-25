import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../beecount_ui.dart';

/// Prepared labels, values and average; the host owns their financial meaning.
/// Both negative and positive columns share the actual zero baseline.
class BeeColumnChart extends StatelessWidget {
  const BeeColumnChart({
    super.key,
    required this.values,
    required this.labels,
    required this.valueLabels,
    required this.average,
    required this.averageLabel,
    this.selected,
    this.highlightIndex,
    this.onSelected,
    this.onAverage,
    this.plotHeight = 145,
  });

  final List<double> values;
  final List<String> labels, valueLabels;
  final double average, plotHeight;
  final String averageLabel;
  final int? selected, highlightIndex;
  final ValueChanged<int>? onSelected;
  final VoidCallback? onAverage;

  @override
  Widget build(BuildContext context) {
    assert(
        values.length == labels.length && values.length == valueLabels.length);
    final theme = Theme.of(context), accent = theme.colorScheme.primary;
    if (values.isEmpty) return SizedBox(height: plotHeight);
    final clean = values.map((v) => v.isFinite ? v : 0.0).toList();
    final low = math.min(0.0, clean.reduce(math.min)),
        high = math.max(0.0, clean.reduce(math.max));
    final mean = average.isFinite ? average : 0.0;
    final min = math.min(low, mean) * 1.13, max = math.max(high, mean) * 1.15;
    final upper = max == min ? min + 1 : max;
    final range = upper - min;
    double y(double v) => 12 + (upper - v) / range * (plotHeight - 22);
    final zero = y(0), meanY = y(mean);
    final chosen =
        selected != null && selected! >= 0 && selected! < values.length
            ? selected
            : null;
    final indices = {0, (values.length - 1) ~/ 2, values.length - 1}.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, bounds) {
        final slot = bounds.maxWidth / values.length;
        return SizedBox(
          key: const ValueKey('column-chart-plot'),
          height: plotHeight,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ColumnGrid(meanY, zero, low < 0, theme.hintColor,
                      BeeCardTheme.of(context).divider),
                ),
              ),
            ),
            for (var i = 0; i < clean.length; i++)
              Positioned(
                left: i * slot,
                width: slot,
                top: 0,
                bottom: 0,
                child: Semantics(
                  button: onSelected != null,
                  selected: chosen == i,
                  label: '${labels[i]} ${valueLabels[i]}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onSelected == null ? null : () => onSelected!(i),
                    child: Stack(children: [
                      Positioned(
                        left: (slot - math.min(23.0, slot * .62)) / 2,
                        width: math.min(23.0, slot * .62),
                        top: clean[i] >= 0 ? y(clean[i]) : zero,
                        height: math.max(1.5, (zero - y(clean[i])).abs()),
                        child: DecoratedBox(
                          key: ValueKey('column-bar-$i'),
                          decoration: BoxDecoration(
                              color: accent.withValues(
                                  alpha: chosen == i ||
                                          (chosen == null &&
                                              i ==
                                                  (highlightIndex ??
                                                      values.length - 1))
                                      ? 1
                                      : clean[i] < 0
                                          ? .35
                                          : .18),
                              borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            if (low < 0)
              Positioned(
                  key: const ValueKey('column-zero-baseline'),
                  left: 0,
                  top: (zero - 12).clamp(0, plotHeight - 12),
                  child: Text('0',
                      style: TextStyle(fontSize: 8, color: theme.hintColor))),
            Positioned(
              right: 0,
              top: (meanY - 18).clamp(0, plotHeight - 24),
              child: Semantics(
                label: averageLabel,
                button: onAverage != null,
                child: InkWell(
                  key: const ValueKey('column-average-label'),
                  onTap: onAverage,
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 5),
                      decoration: BoxDecoration(
                          color: BeeCardTheme.of(context)
                              .surface
                              .withValues(alpha: .94),
                          borderRadius: BorderRadius.circular(5)),
                      child: Text(averageLabel,
                          style:
                              TextStyle(fontSize: 9, color: theme.hintColor))),
                ),
              ),
            ),
            if (chosen != null)
              Positioned(
                top: -10,
                left: ((chosen + .5) * slot - 62)
                    .clamp(0, math.max(0, bounds.maxWidth - 124)),
                child: IgnorePointer(
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      key: const ValueKey('column-point-detail'),
                      constraints: const BoxConstraints(maxWidth: 124),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 7),
                      decoration: BoxDecoration(
                          color: const Color(0xff30343a),
                          borderRadius: BorderRadius.circular(9)),
                      child: Text('${labels[chosen]}\n${valueLabels[chosen]}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white)),
                    ),
                  ),
                ),
              ),
          ]),
        );
      }),
      const SizedBox(height: 7),
      Row(
          mainAxisAlignment: indices.length == 1
              ? MainAxisAlignment.center
              : MainAxisAlignment.spaceBetween,
          children: [
            for (final i in indices)
              Text(labels[i],
                  style: TextStyle(fontSize: 9, color: theme.hintColor))
          ]),
    ]);
  }
}

class _ColumnGrid extends CustomPainter {
  _ColumnGrid(
      this.averageY, this.zeroY, this.showZero, this.muted, this.divider);
  final double averageY, zeroY;
  final bool showZero;
  final Color muted, divider;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()..strokeWidth = 1;
    if (showZero) {
      canvas.drawLine(
          Offset(0, zeroY), Offset(size.width, zeroY), pen..color = divider);
    }
    pen.color = muted.withValues(alpha: .65);
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, averageY),
          Offset(math.min(x + 3.5, size.width), averageY), pen);
    }
  }

  @override
  bool shouldRepaint(covariant _ColumnGrid oldDelegate) =>
      averageY != oldDelegate.averageY ||
      zeroY != oldDelegate.zeroY ||
      showZero != oldDelegate.showZero ||
      muted != oldDelegate.muted ||
      divider != oldDelegate.divider;
}
