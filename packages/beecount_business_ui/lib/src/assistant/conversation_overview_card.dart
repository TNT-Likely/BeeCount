import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shows the active ledger period. The app formats the money and computes a
/// cumulative daily series in the ledger's base currency.
class BeeConversationOverviewCard extends StatelessWidget {
  const BeeConversationOverviewCard({
    super.key,
    required this.period,
    required this.amountLabel,
    required this.amount,
    required this.countLabel,
    required this.trendLabel,
    required this.points,
    required this.reviewLabel,
    required this.onReview,
    this.showTrend = true,
  });

  final String period, amountLabel, countLabel, trendLabel, reviewLabel;
  final Widget amount;
  final List<double> points;
  final VoidCallback? onReview;
  final bool showTrend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cards = BeeCardTheme.of(context);
    final tint =
        Color.alphaBlend(scheme.primary.withValues(alpha: .12), cards.overlay);
    final edge =
        Color.alphaBlend(scheme.primary.withValues(alpha: .27), cards.divider);
    return BeeSurface(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
      background: DecoratedBox(
          decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: edge))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const BeeLineIcon('Calendar', size: 15),
          const SizedBox(width: 6),
          Expanded(child: Text(period, style: theme.textTheme.labelMedium)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(amountLabel, style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: amount),
                const SizedBox(height: 2),
                Text(countLabel, style: theme.textTheme.labelSmall),
              ])),
          if (showTrend) ...[
            const SizedBox(width: 8),
            _ReceiptTrend(label: trendLabel, points: points),
          ],
        ]),
        const SizedBox(height: 12),
        Divider(height: 1, color: edge),
        Semantics(
            button: true,
            child: InkWell(
              onTap: onReview,
              borderRadius: BorderRadius.circular(9),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 46),
                  child: Row(children: [
                    const BeeLineIcon('Sparkles', size: 16),
                    const SizedBox(width: 7),
                    Expanded(
                        child: Text(reviewLabel,
                            style: theme.textTheme.labelLarge)),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ])),
            )),
      ]),
    );
  }
}

class _ReceiptTrend extends StatelessWidget {
  const _ReceiptTrend({required this.label, required this.points});
  final String label;
  final List<double> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = scheme.onSurface;
    return Semantics(
        image: true,
        label: label,
        child: ExcludeSemantics(
          child: Transform.rotate(
              angle: .08,
              child: SizedBox(
                width: 77,
                height: 62,
                child: Stack(children: [
                  Positioned.fill(
                      left: 7,
                      top: 4,
                      right: 0,
                      bottom: 4,
                      child: Transform.rotate(
                          angle: .07,
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: .75),
                                  borderRadius: BorderRadius.circular(3))))),
                  Positioned.fill(
                      right: 6,
                      bottom: 2,
                      child: CustomPaint(
                          painter: _ReceiptPainter(points,
                              sheet: Color.alphaBlend(
                                  scheme.primary.withValues(alpha: .06),
                                  scheme.surface),
                              stroke: ink,
                              accent: scheme.primary),
                          child: Align(
                              alignment: AlignmentDirectional.topStart,
                              child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(6, 5, 6, 0),
                                  child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            BeeLineIcon('ReceiptText',
                                                size: 10, color: ink),
                                            const SizedBox(width: 3),
                                            Text(label,
                                                style: TextStyle(
                                                    fontSize: 9, color: ink))
                                          ])))))),
                ]),
              )),
        ));
  }
}

class _ReceiptPainter extends CustomPainter {
  const _ReceiptPainter(this.points,
      {required this.sheet, required this.stroke, required this.accent});
  final List<double> points;
  final Color sheet, stroke, accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paper = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h - 3);
    for (var i = 1; i <= 12; i++) {
      paper.lineTo(w - i * w / 12, i.isOdd ? h : h - 3);
    }
    paper.close();
    canvas.drawPath(paper, Paint()..color = sheet);
    canvas.drawPath(
        paper,
        Paint()
          ..color = accent.withValues(alpha: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .75);
    final plot = Rect.fromLTRB(6, 24, w - 6, h - 9);
    final grid = Paint()
      ..color = stroke.withValues(alpha: .18)
      ..strokeWidth = .8;
    for (final y in [plot.top, plot.bottom]) {
      for (double x = plot.left; x + 2 <= plot.right; x += 5) {
        canvas.drawLine(Offset(x, y), Offset(x + 2, y), grid);
      }
    }
    final low = points.fold<double>(0, (a, b) => a < b ? a : b);
    final high = points.fold<double>(0, (a, b) => a > b ? a : b);
    final span = high == low ? 1.0 : high - low;
    double y(double v) => plot.bottom - plot.height * (v - low) / span;
    final line = Path()
      ..moveTo(plot.left, y(points.isEmpty ? 0 : points.first));
    if (points.length < 2) {
      line.lineTo(plot.right, y(points.isEmpty ? 0 : points.first));
    } else {
      for (int i = 1; i < points.length; i++) {
        line.lineTo(
            plot.left + plot.width * i / (points.length - 1), y(points[i]));
      }
    }
    canvas.drawPath(
        Path.from(line)
          ..lineTo(plot.right, plot.bottom)
          ..lineTo(plot.left, plot.bottom)
          ..close(),
        Paint()..color = accent.withValues(alpha: .26));
    canvas.drawPath(
        line,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_ReceiptPainter old) =>
      old.sheet != sheet ||
      old.stroke != stroke ||
      old.accent != accent ||
      !listEquals(old.points, points);
}
