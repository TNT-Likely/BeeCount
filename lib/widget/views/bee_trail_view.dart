import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widget_data_service.dart' show DailyWidgetActivity;
import 'widget_view_style.dart';

/// 小号「记账连续蜂迹」小组件:以 28 枚蜂巢格呈现最近记录，并强调当前连续
/// 记账天数而不是消费金额。
class BeeTrailView extends StatelessWidget {
  final List<DailyWidgetActivity> activity;
  final Color themeColor;
  final bool dark;
  final String titleLabel;
  final String streakSuffix;
  final String completionLabel;
  final String emptyLabel;
  final double width;
  final double height;

  const BeeTrailView({
    super.key,
    required this.activity,
    required this.themeColor,
    required this.dark,
    required this.titleLabel,
    required this.streakSuffix,
    required this.completionLabel,
    required this.emptyLabel,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final recorded = activity.where((day) => day.hasRecord).length;
    final streak = _currentStreak(activity);
    final recent = activity.length > 28
        ? activity.sublist(activity.length - 28)
        : activity;
    final dots = <bool>[for (final day in recent) day.hasRecord];
    while (dots.length < 28) {
      dots.insert(0, false);
    }

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: widgetCardBackground(dark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titleLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: widgetTextSecondary(dark),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          if (recorded == 0)
            Expanded(
              child: Center(
                child: Text(emptyLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: widgetTextTertiary(dark), fontSize: 11)),
              ),
            )
          else ...[
            Text('$streak $streakSuffix',
                style: TextStyle(
                    color: widgetTextPrimary(dark),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.0)),
            const SizedBox(height: 4),
            Expanded(child: CustomPaint(painter: _HivePainter(dots, themeColor, dark))),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(completionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: widgetTextTertiary(dark), fontSize: 9)),
                ),
                Text('${(recorded / activity.length * 100).round()}%',
                    style: TextStyle(
                        color: widgetTextSecondary(dark),
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  int _currentStreak(List<DailyWidgetActivity> days) {
    var count = 0;
    for (final day in days.reversed) {
      if (!day.hasRecord) break;
      count++;
    }
    return count;
  }
}

class _HivePainter extends CustomPainter {
  final List<bool> dots;
  final Color color;
  final bool dark;

  const _HivePainter(this.dots, this.color, this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    const rows = 4;
    const columns = 7;
    final cellWidth = size.width / (columns + 0.5);
    final radius = cellWidth * 0.46;
    final rowHeight = size.height / rows;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final index = row * columns + column;
        final center = Offset(
          cellWidth * (column + 0.5 + (row.isOdd ? 0.5 : 0)),
          rowHeight * (row + 0.5),
        );
        final path = Path();
        for (var side = 0; side < 6; side++) {
          final angle = (60 * side - 30) * 3.141592653589793 / 180;
          final point = Offset(center.dx + radius * math.cos(angle),
              center.dy + radius * math.sin(angle));
          if (side == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(
            path,
            Paint()
              ..color = dots[index]
                  ? color.withValues(alpha: 0.90)
                  : (dark ? Colors.white.withValues(alpha: 0.09) : const Color(0xFFF1F1F1)));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HivePainter oldDelegate) =>
      oldDelegate.dots != dots || oldDelegate.color != color || oldDelegate.dark != dark;
}
