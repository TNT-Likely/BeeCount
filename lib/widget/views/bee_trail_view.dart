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
    final recent = activity.length > 28
        ? activity.sublist(activity.length - 28)
        : activity;
    final recorded = recent.where((day) => day.hasRecord).length;
    final streak = _currentStreak(recent);
    final dots = <bool>[for (final day in recent) day.hasRecord];
    while (dots.length < 28) {
      dots.insert(0, false);
    }

    return WidgetCardSurface(
      width: width,
      height: height,
      dark: dark,
      padding: const EdgeInsets.all(13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        WidgetCardHeading(
            icon: Icons.hexagon_outlined,
            title: titleLabel,
            dark: dark,
            compact: true),
        const SizedBox(height: 4),
        if (recorded == 0)
          Expanded(
              child: WidgetCardEmpty(
                  icon: Icons.hexagon_outlined,
                  label: emptyLabel,
                  dark: dark,
                  compact: true))
        else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(text: '$streak ', children: [
                  TextSpan(
                      text: streakSuffix,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: widgetTextSecondary(dark))),
                ]),
                maxLines: 1,
                style: TextStyle(
                    fontSize: 27,
                    height: 1.06,
                    color: widgetTextPrimary(dark),
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [kWidgetTabularFeature]),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
              child: SizedBox.expand(
                  child: CustomPaint(
                      painter: _HivePainter(dots, themeColor, dark)))),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(
                child: Text(completionLabel,
                    style: TextStyle(
                        color: widgetTextSecondary(dark),
                        fontSize: 9.5,
                        height: 1.1))),
            const SizedBox(width: 3),
            Text('${(recorded / recent.length * 100).round()}%',
                style: TextStyle(
                    color: widgetTextPrimary(dark),
                    fontSize: 11,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [kWidgetTabularFeature])),
          ]),
        ],
      ]),
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
    final rowHeight = size.height / rows;
    final radius = math.min(cellWidth * .52, rowHeight * .48);
    final hexagon = Path();
    for (var side = 0; side < 6; side++) {
      final angle = (60 * side - 30) * math.pi / 180;
      final x = radius * math.cos(angle), y = radius * math.sin(angle);
      if (side == 0) {
        hexagon.moveTo(x, y);
      } else {
        hexagon.lineTo(x, y);
      }
    }
    hexagon.close();
    final recorded = Paint()..color = color;
    final empty = Paint()..color = widgetCardSoft(dark);
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final center = Offset(cellWidth * (column + (row.isOdd ? 1 : .5)),
            rowHeight * (row + .5));
        canvas.drawPath(hexagon.shift(center),
            dots[row * columns + column] ? recorded : empty);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HivePainter oldDelegate) =>
      oldDelegate.dots != dots ||
      oldDelegate.color != color ||
      oldDelegate.dark != dark;
}
