import 'dart:math' as math;
import 'package:flutter/material.dart';

class BeeChartSlice {
  const BeeChartSlice(
      {required this.label,
      required this.value,
      required this.color,
      required this.valueLabel});
  final String label, valueLabel;
  final double value;
  final Color color;
}

class BeeDonutChart extends StatelessWidget {
  const BeeDonutChart(
      {super.key,
      required this.items,
      required this.centerLabel,
      this.onSelected,
      this.selected});
  final List<BeeChartSlice> items;
  final String centerLabel;
  final ValueChanged<int>? onSelected;
  final int? selected;
  @override
  Widget build(BuildContext context) => Column(children: [
        Semantics(
            label: ([
              centerLabel,
              ...items.map((e) => '${e.label} ${e.valueLabel}')
            ]).join(', '),
            image: true,
            child: SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                    painter:
                        _DonutPainter(items, Theme.of(context).dividerColor),
                    child: Center(
                        child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(centerLabel,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600))))))),
        const SizedBox(height: 12),
        Wrap(
            spacing: 8,
            runSpacing: 6,
            children: items
                .asMap()
                .entries
                .map((e) => Semantics(
                    selected: selected == e.key,
                    child: ActionChip(
                        onPressed: onSelected == null
                            ? null
                            : () => onSelected!(e.key),
                        avatar: CircleAvatar(
                            backgroundColor: e.value.color, radius: 4),
                        label: Text('${e.value.label} ${e.value.valueLabel}',
                            style: const TextStyle(fontSize: 11)))))
                .toList()),
      ]);
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.items, this.track);
  final List<BeeChartSlice> items;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(12);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    canvas.drawArc(arc, 0, math.pi * 2, false, paint..color = track);
    final total = items.fold<double>(
        0, (v, s) => v + (s.value.isFinite && s.value > 0 ? s.value : 0));
    if (total <= 0 || !total.isFinite) return;
    var start = -math.pi / 2;
    for (final item in items) {
      if (!item.value.isFinite || item.value <= 0) continue;
      final sweep = item.value / total * 2 * math.pi;
      canvas.drawArc(arc, start, sweep, false, paint..color = item.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.items != items || old.track != track;
}

class BeeTrendChart extends StatelessWidget {
  const BeeTrendChart(
      {super.key,
      required this.values,
      required this.label,
      this.height = 120});
  final List<double> values;
  final String label;
  final double height;
  @override
  Widget build(BuildContext context) => Semantics(
      label: label,
      image: true,
      child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
              painter: _TrendPainter(
                  values, Theme.of(context).colorScheme.primary))));
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values, this.color);
  final List<double> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final clean = values.where((v) => v.isFinite).toList();
    if (clean.isEmpty) return;
    final min = clean.reduce(math.min), max = clean.reduce(math.max);
    final range = max - min;
    final points = <Offset>[];
    for (var i = 0; i < clean.length; i++) {
      points.add(Offset(
          clean.length == 1
              ? size.width / 2
              : i / (clean.length - 1) * size.width,
          size.height -
              8 -
              (range == 0 ? .5 : (clean[i] - min) / range) *
                  (size.height - 16)));
    }
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, stroke);
    for (final point in points) {
      canvas.drawCircle(point, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.values != values || old.color != color;
}
