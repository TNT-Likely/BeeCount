import 'dart:math' as math;
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'finance_components.dart';

class BeeResourceMetric {
  const BeeResourceMetric({required this.label, required this.value});
  final String label, value;
}

/// Shared detail identity and totals for categories, accounts and tags.
/// Currency, privacy and scope are resolved by the App before rendering.
class BeeResourceHero extends StatelessWidget {
  const BeeResourceHero(
      {super.key,
      required this.title,
      required this.caption,
      required this.icon,
      required this.amountLabel,
      required this.amount,
      required this.metrics,
      this.prefix = ''});
  final String title, caption, amountLabel, amount, prefix;
  final Widget icon;
  final List<BeeResourceMetric> metrics;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 380;
    final muted = Theme.of(context).hintColor;
    return BeeSurface(
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(15)),
                    child: Center(child: icon)),
                const SizedBox(width: 11),
                Expanded(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(caption,
                          style: TextStyle(
                              fontSize: 11, height: 1.5, color: muted)),
                    ])),
              ]),
              const SizedBox(height: 21),
              Text(amountLabel, style: TextStyle(fontSize: 11, color: muted)),
              const SizedBox(height: 4),
              Align(
                  alignment: Alignment.centerLeft,
                  child: BeeMoney(
                      amount: amount,
                      prefix: prefix.isEmpty ? null : prefix,
                      prefixSize: 19,
                      size: compact ? 29 : 33,
                      lineHeight: 1.45)),
              const SizedBox(height: 18),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 15),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < metrics.length; i++) ...[
                  if (i > 0) SizedBox(width: compact ? 6 : 9),
                  Expanded(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(metrics[i].label,
                            style: TextStyle(
                                fontSize: 10, height: 1.5, color: muted)),
                        const SizedBox(height: 5),
                        Text(metrics[i].value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: compact ? 12 : 14,
                                fontWeight: FontWeight.w500,
                                height: 1.5)),
                      ])),
                ],
              ]),
            ]));
  }
}

class BeeResourceBreakdownItem {
  const BeeResourceBreakdownItem(
      {required this.id,
      required this.label,
      required this.amount,
      required this.detail,
      required this.fraction,
      required this.icon});
  final String id, label, amount, detail;
  final double fraction;
  final Widget icon;
}

class BeeResourceBreakdown extends StatelessWidget {
  const BeeResourceBreakdown(
      {super.key, required this.items, required this.onSelected});
  final List<BeeResourceBreakdownItem> items;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: items
          .map((item) => InkWell(
              onTap: () => onSelected(item.id),
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(children: [
                    Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                            color: BeeCardTheme.of(context).soft,
                            borderRadius: BorderRadius.circular(12)),
                        child: Center(child: item.icon)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          Row(children: [
                            Expanded(
                                child: Text(item.label,
                                    style: const TextStyle(fontSize: 13))),
                            const SizedBox(width: 8),
                            Text(item.amount,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500))
                          ]),
                          const SizedBox(height: 3),
                          Text(item.detail,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).hintColor)),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                              value: item.fraction.isFinite
                                  ? item.fraction.clamp(0, 1)
                                  : 0,
                              minHeight: 3,
                              borderRadius: BorderRadius.circular(3),
                              backgroundColor: BeeCardTheme.of(context).soft),
                        ])),
                    const SizedBox(width: 8),
                    const BeeLineIcon('ChevronRight', size: 14),
                  ]))))
          .toList());
}

/// Filled cumulative chart shared by resource detail pages. Labels are supplied
/// by the App so the presentation package does not format dates or query data.
class BeeResourceTrend extends StatelessWidget {
  const BeeResourceTrend(
      {super.key,
      required this.values,
      required this.label,
      this.axisLabels = const []});
  final List<double> values;
  final String label;
  final List<String> axisLabels;
  @override
  Widget build(BuildContext context) => Semantics(
      label: label,
      image: true,
      child: SizedBox(
          height: 115,
          width: double.infinity,
          child: CustomPaint(
              painter: _ResourceTrendPainter(
                  values,
                  Theme.of(context).colorScheme.primary,
                  BeeCardTheme.of(context).divider,
                  Theme.of(context).hintColor,
                  axisLabels,
                  MediaQuery.textScalerOf(context)))));
}

class _ResourceTrendPainter extends CustomPainter {
  _ResourceTrendPainter(this.values, this.accent, this.grid, this.muted,
      this.labels, this.scaler);
  final List<double> values;
  final Color accent, grid, muted;
  final List<String> labels;
  final TextScaler scaler;
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 308, sy = size.height / 110;
    final left = 8 * sx, right = 300 * sx, top = 17 * sy, bottom = 87 * sy;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = top + (bottom - top) * i / 2;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
    }
    final clean = values.where((v) => v.isFinite).toList();
    if (clean.isNotEmpty) {
      final lo = math.min(0.0, clean.reduce(math.min));
      final hi = math.max(1.0, clean.reduce(math.max));
      final points = List.generate(
          clean.length,
          (i) => Offset(
              clean.length == 1
                  ? (left + right) / 2
                  : left + (right - left) * i / (clean.length - 1),
              bottom - (clean[i] - lo) / (hi - lo) * (bottom - top)));
      final line = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        line.lineTo(point.dx, point.dy);
      }
      final area = Path.from(line)
        ..lineTo(points.last.dx, bottom)
        ..lineTo(points.first.dx, bottom)
        ..close();
      canvas.drawPath(area, Paint()..color = accent.withValues(alpha: .12));
      canvas.drawPath(
          line,
          Paint()
            ..color = accent
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke);
      canvas.drawCircle(points.last, 3.5, Paint()..color = accent);
    }
    for (var i = 0; i < labels.length && i < 3; i++) {
      final text = TextPainter(
          text: TextSpan(
              text: labels[i], style: TextStyle(fontSize: 10, color: muted)),
          textDirection: TextDirection.ltr,
          textScaler: scaler)
        ..layout(maxWidth: size.width / 3);
      final x = i == 0
          ? left
          : i == 1
              ? size.width / 2 - text.width / 2
              : right - text.width;
      text.paint(
          canvas,
          Offset(
              x, math.min(107 * sy - text.height, size.height - text.height)));
    }
  }

  @override
  bool shouldRepaint(covariant _ResourceTrendPainter old) =>
      old.values != values ||
      old.accent != accent ||
      old.grid != grid ||
      old.muted != muted ||
      old.labels != labels ||
      old.scaler != scaler;
}
