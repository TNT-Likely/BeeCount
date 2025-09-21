import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../styles/colors.dart';

class LineChart extends StatelessWidget {
  final List<double> values;
  final List<double>? secondaryValues; // 第二条线的数据（可选）
  final Color? secondaryColor; // 第二条线的颜色（可选）
  final List<String> xLabels;
  final int? highlightIndex;
  final VoidCallback onSwipeLeft; // 下一周期
  final VoidCallback onSwipeRight; // 上一周期
  final bool showHint;
  final String? hintText;
  final VoidCallback? onCloseHint;
  final VoidCallback? onPrimaryLineTap; // 主线点击回调
  final VoidCallback? onSecondaryLineTap; // 副线点击回调
  final bool whiteBg;
  final bool showGrid;
  final bool showDots;
  final bool annotate;
  final Color themeColor;
  // 令牌化参数
  final double lineWidth;
  final double dotRadius;
  final double cornerRadius;
  final double xLabelFontSize;
  final double yLabelFontSize;

  const LineChart({
    super.key,
    required this.values,
    this.secondaryValues,
    this.secondaryColor,
    required this.xLabels,
    required this.highlightIndex,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.showHint,
    this.hintText,
    this.onCloseHint,
    this.onPrimaryLineTap,
    this.onSecondaryLineTap,
    this.whiteBg = true,
    this.showGrid = true,
    this.showDots = true,
    this.annotate = true,
    required this.themeColor,
    this.lineWidth = 2.0,
    this.dotRadius = 2.5,
    this.cornerRadius = 12,
    this.xLabelFontSize = 10,
    this.yLabelFontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        // 如果有点击回调，处理点击事件
        if (onPrimaryLineTap != null || onSecondaryLineTap != null) {
          _handleTap(details.localPosition, context);
        }
      },
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < 0) {
          onSwipeLeft();
        } else if (v > 0) {
          onSwipeRight();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _LinePainter(
              values: values,
              secondaryValues: secondaryValues,
              secondaryColor: secondaryColor,
              xLabels: xLabels,
              highlightIndex: highlightIndex,
              whiteBg: whiteBg,
              showGrid: showGrid,
              showDots: showDots,
              annotate: annotate,
              themeColor: themeColor,
              lineWidth: lineWidth,
              dotRadius: dotRadius,
              cornerRadius: cornerRadius,
              xLabelFontSize: xLabelFontSize,
              yLabelFontSize: yLabelFontSize,
            ),
          ),
          if (showHint)
            Positioned(
              right: 8,
              top: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: BeeColors.divider,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.swipe,
                          size: 14, color: BeeColors.secondaryText),
                      const SizedBox(width: 4),
                      Text(
                        hintText ?? '左右滑动切换',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: BeeColors.secondaryText),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: onCloseHint,
                        child: Icon(Icons.close,
                            size: 14, color: BeeColors.hintText),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleTap(Offset localPosition, BuildContext context) {
    final size = context.size;
    if (size == null) return;

    // 计算主线所有点
    List<Offset> primaryPoints = [];
    if (values.isNotEmpty) {
      final dx = (size.width - 24) / (values.length - 1).clamp(1, 999);
      final allValues = <double>[...values];
      final allMax = allValues.reduce(math.max);
      final allMin = allValues.reduce(math.min);
      final span = (allMax - allMin).abs();
      final bottomPadding = 20.0;
      final topPadding = 12.0;
      double yFor(double v) {
        if (span == 0) return size.height / 2;
        final t = (v - allMin) / span;
        return topPadding +
            (1 - t) * (size.height - topPadding - bottomPadding);
      }

      for (int i = 0; i < values.length; i++) {
        primaryPoints.add(Offset(12 + i * dx, yFor(values[i])));
      }
    }

    // 计算副线所有点
    List<Offset> secondaryPoints = [];
    if (secondaryValues != null && secondaryValues!.isNotEmpty) {
      final dx =
          (size.width - 24) / (secondaryValues!.length - 1).clamp(1, 999);
      final allValues = <double>[...secondaryValues!];
      final allMax = allValues.reduce(math.max);
      final allMin = allValues.reduce(math.min);
      final span = (allMax - allMin).abs();
      final bottomPadding = 20.0;
      final topPadding = 12.0;
      double yFor(double v) {
        if (span == 0) return size.height / 2;
        final t = (v - allMin) / span;
        return topPadding +
            (1 - t) * (size.height - topPadding - bottomPadding);
      }

      for (int i = 0; i < secondaryValues!.length; i++) {
        secondaryPoints.add(Offset(12 + i * dx, yFor(secondaryValues![i])));
      }
    }

    // 计算点击点到主线/副线所有点的最小距离
    double minPrimaryDist = double.infinity;
    for (final p in primaryPoints) {
      final d = (p - localPosition).distance;
      if (d < minPrimaryDist) minPrimaryDist = d;
    }
    double minSecondaryDist = double.infinity;
    for (final p in secondaryPoints) {
      final d = (p - localPosition).distance;
      if (d < minSecondaryDist) minSecondaryDist = d;
    }

    // 判断最近的线
    if (secondaryPoints.isEmpty || minPrimaryDist <= minSecondaryDist) {
      onPrimaryLineTap?.call();
    } else {
      onSecondaryLineTap?.call();
    }
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final List<double>? secondaryValues;
  final Color? secondaryColor;
  final List<String> xLabels;
  final int? highlightIndex;
  final bool whiteBg;
  final bool showGrid;
  final bool showDots;
  final bool annotate;
  final Color themeColor;
  final double lineWidth;
  final double dotRadius;
  final double cornerRadius;
  final double xLabelFontSize;
  final double yLabelFontSize;

  _LinePainter({
    required this.values,
    this.secondaryValues,
    this.secondaryColor,
    required this.xLabels,
    required this.highlightIndex,
    required this.whiteBg,
    required this.showGrid,
    required this.showDots,
    required this.annotate,
    required this.themeColor,
    this.lineWidth = 2.0,
    this.dotRadius = 2.5,
    this.cornerRadius = 12,
    this.xLabelFontSize = 10,
    this.yLabelFontSize = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()..color = whiteBg ? Colors.white : BeeColors.divider;
    // 背景
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)), bgPaint);

    // 网格（可选）
    if (showGrid) {
      final gridPaint = Paint()
        ..color = BeeColors.divider
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      const rows = 4;
      for (int i = 1; i <= rows; i++) {
        final y = size.height * i / (rows + 1);
        canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), gridPaint);
      }
    }

    if (values.isEmpty) return;

    // 数据归一化 - 包含所有值（包括0）用于正确的Y轴缩放
    final allValues = <double>[...values];
    if (secondaryValues != null && secondaryValues!.isNotEmpty) {
      allValues.addAll(secondaryValues!);
    }

    final maxV = allValues.isEmpty ? 0.0 : allValues.reduce(math.max);
    final minV = allValues.isEmpty ? 0.0 : allValues.reduce(math.min);

    // 计算主线非零值的平均值，用于平均线绘制
    final nonZeroVals = values.where((v) => v != 0).toList();
    final avgV = nonZeroVals.isEmpty
        ? 0.0
        : nonZeroVals.reduce((a, b) => a + b) / nonZeroVals.length;

    // 计算副线非零值的平均值和索引
    final secondaryNonZeroVals = secondaryValues == null
        ? <double>[]
        : secondaryValues!.where((v) => v != 0).toList();
    final avgSecondaryV = secondaryNonZeroVals.isEmpty
        ? 0.0
        : secondaryNonZeroVals.reduce((a, b) => a + b) /
            secondaryNonZeroVals.length;

    final span = (maxV - minV).abs();
    final bottomPadding = 20.0;
    final topPadding = 12.0;
    double yFor(double v) {
      if (span == 0) return size.height / 2;
      final t = (v - minV) / span; // 0..1
      return topPadding + (1 - t) * (size.height - topPadding - bottomPadding);
    }

    final dx = (size.width - 24) / (values.length - 1).clamp(1, 999);
    Offset pointFor(int i) => Offset(12 + i * dx, yFor(values[i]));

    // 为所有点生成坐标，包括零值点，确保线条连续
    final allPoints = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      allPoints.add(pointFor(i));
    }

    // 收集非零点的索引，用于绘制圆点和标注
    final nzIndices = <int>[];
    for (int i = 0; i < values.length; i++) {
      if (values[i] != 0) nzIndices.add(i);
    }

    final line = Paint()
      ..color = themeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..isAntiAlias = true;

    // 绘制连续的折线，包括所有点（包括零值点）
    if (allPoints.length >= 2) {
      final path = Path()..moveTo(allPoints.first.dx, allPoints.first.dy);
      for (int i = 1; i < allPoints.length; i++) {
        path.lineTo(allPoints[i].dx, allPoints[i].dy);
      }
      canvas.drawPath(path, line);
    }

    // 绘制第二条线（如果有）
    if (secondaryValues != null &&
        secondaryValues!.isNotEmpty &&
        secondaryColor != null) {
      final secondaryAllPoints = <Offset>[];
      for (int i = 0; i < secondaryValues!.length; i++) {
        secondaryAllPoints.add(Offset(12 + i * dx, yFor(secondaryValues![i])));
      }

      final secondaryNzIndices = <int>[];
      for (int i = 0; i < secondaryValues!.length; i++) {
        if (secondaryValues![i] != 0) secondaryNzIndices.add(i);
      }

      final secondaryLine = Paint()
        ..color = secondaryColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth
        ..isAntiAlias = true;

      if (secondaryAllPoints.length >= 2) {
        final secondaryPath = Path()
          ..moveTo(secondaryAllPoints.first.dx, secondaryAllPoints.first.dy);
        for (int i = 1; i < secondaryAllPoints.length; i++) {
          secondaryPath.lineTo(
              secondaryAllPoints[i].dx, secondaryAllPoints[i].dy);
        }
        canvas.drawPath(secondaryPath, secondaryLine);
      }

      if (showDots) {
        final secondaryDot = Paint()..color = secondaryColor!;
        // 只在非零值点绘制圆点
        for (final i in secondaryNzIndices) {
          canvas.drawCircle(secondaryAllPoints[i], dotRadius, secondaryDot);
        }
      }
    }

    if (showDots) {
      final dot = Paint()..color = themeColor;
      // 只在非零值点绘制圆点
      for (final i in nzIndices) {
        canvas.drawCircle(allPoints[i], dotRadius, dot);
      }
    }

    // 左侧Y轴线
    final axisPaint = Paint()
      ..color = BeeColors.divider
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(8, topPadding),
        Offset(8, size.height - bottomPadding), axisPaint);

    // 主线平均线（虚线）
    final avgY = yFor(avgV);
    final avgLinePaint = Paint()
      ..color = BeeColors.secondaryText.withValues(alpha: 0.55)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    _drawDashedLine(
        canvas, Offset(8, avgY), Offset(size.width - 8, avgY), avgLinePaint,
        dashWidth: 6, gapWidth: 4);

    // 副线平均线（虚线，副线色）
    if (secondaryValues != null &&
        secondaryValues!.isNotEmpty &&
        secondaryColor != null) {
      final spanSec = (maxV - minV).abs();
      double yForSec(double v) {
        if (spanSec == 0) return size.height / 2;
        final t = (v - minV) / spanSec;
        return topPadding +
            (1 - t) * (size.height - topPadding - bottomPadding);
      }

      final avgSecY = yForSec(avgSecondaryV);
      final avgSecLinePaint = Paint()
        ..color = secondaryColor!.withOpacity(0.55)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      _drawDashedLine(canvas, Offset(8, avgSecY),
          Offset(size.width - 8, avgSecY), avgSecLinePaint,
          dashWidth: 6, gapWidth: 4);
    }

    // 所有非零点数值标注
    if (annotate) {
      // 主线标注
      final textStyle =
          TextStyle(fontSize: yLabelFontSize - 1, color: BeeColors.primaryText);
      for (final i in nzIndices) {
        final tp = TextPainter(
          text: TextSpan(text: _fmt(values[i]), style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 60);
        final pos = allPoints[i] + const Offset(0, -10);
        tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height));
      }
      // 副线标注
      if (secondaryValues != null &&
          secondaryValues!.isNotEmpty &&
          secondaryColor != null) {
        final dx =
            (size.width - 24) / (secondaryValues!.length - 1).clamp(1, 999);
        final spanSec = (maxV - minV).abs();
        double yForSec(double v) {
          if (spanSec == 0) return size.height / 2;
          final t = (v - minV) / spanSec;
          return topPadding +
              (1 - t) * (size.height - topPadding - bottomPadding);
        }

        for (int i = 0; i < secondaryValues!.length; i++) {
          final v = secondaryValues![i];
          if (v == 0) continue;
          final pos = Offset(12 + i * dx, yForSec(v)) + const Offset(0, -10);
          final tp = TextPainter(
            text: TextSpan(
                text: _fmt(v),
                style: TextStyle(
                    fontSize: yLabelFontSize - 1, color: secondaryColor)),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: 60);
          tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height));
        }
      }
    }

    // X 轴标签（保持原始标签与索引）
    if (xLabels.isNotEmpty) {
      final baseStyle =
          TextStyle(fontSize: xLabelFontSize, color: BeeColors.secondaryText);
      final hiStyle = TextStyle(
          fontSize: xLabelFontSize,
          color: BeeColors.primaryText,
          fontWeight: FontWeight.w600);
      final n = xLabels.length;
      int step = (n / 8).ceil();
      if (step < 1) step = 1;
      for (int i = 0; i < n; i += step) {
        final lbl = xLabels[i];
        final tp = TextPainter(
          text: TextSpan(
              text: lbl,
              style: (highlightIndex != null && i == highlightIndex)
                  ? hiStyle
                  : baseStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 60);
        final dxi = (i / (n - 1).clamp(1, 999)) * (size.width - 24) + 12;
        tp.paint(
            canvas, Offset(dxi - tp.width / 2, size.height - tp.height - 2));
      }
    }
  }

  String _fmt(double v) {
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}w';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.xLabels != xLabels ||
        oldDelegate.highlightIndex != highlightIndex ||
        oldDelegate.whiteBg != whiteBg ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showDots != showDots ||
        oldDelegate.annotate != annotate;
  }
}

void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint,
    {double dashWidth = 5, double gapWidth = 3}) {
  final total = (p2 - p1).distance;
  final dir = (p2 - p1) / total;
  double drawn = 0;
  while (drawn < total) {
    final start = p1 + dir * drawn;
    final end = p1 + dir * (drawn + dashWidth).clamp(0, total);
    canvas.drawLine(start, end, paint);
    drawn += dashWidth + gapWidth;
  }
}
