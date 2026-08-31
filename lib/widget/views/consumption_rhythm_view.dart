import 'package:flutter/material.dart';

import '../widget_data_service.dart' show DailyWidgetActivity;
import 'widget_view_style.dart';

/// 中号「消费节奏」小组件:以近 30 日支出热力格展示消费是否集中，并用最近
/// 七天与前七天的比较给出一句简短的节奏提示。
class ConsumptionRhythmView extends StatelessWidget {
  final List<DailyWidgetActivity> activity;
  final Color themeColor;
  final bool dark;
  final String titleLabel;
  final String stableLabel;
  final String increaseLabel;
  final String decreaseLabel;
  final String emptyLabel;
  final double width;
  final double height;

  const ConsumptionRhythmView({
    super.key,
    required this.activity,
    required this.themeColor,
    required this.dark,
    required this.titleLabel,
    required this.stableLabel,
    required this.increaseLabel,
    required this.decreaseLabel,
    required this.emptyLabel,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final days = activity.length > 30
        ? activity.sublist(activity.length - 30)
        : activity;
    final maxExpense = days.fold<double>(
        0, (maximum, day) => day.expenseTotal > maximum ? day.expenseTotal : maximum);
    final empty = maxExpense == 0;

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: widgetCardBackground(dark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(titleLabel,
                  style: TextStyle(
                      color: widgetTextSecondary(dark),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('近 30 天',
                  style: TextStyle(color: widgetTextTertiary(dark), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 7),
          Expanded(
            child: empty
                ? Center(
                    child: Text(emptyLabel,
                        style: TextStyle(
                            color: widgetTextTertiary(dark), fontSize: 12)))
                : _HeatMap(days: days, maxExpense: maxExpense, color: themeColor, dark: dark),
          ),
          const SizedBox(height: 5),
          Text(
            empty ? '' : _comparisonLabel(days),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: empty ? widgetTextTertiary(dark) : widgetTextSecondary(dark),
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _comparisonLabel(List<DailyWidgetActivity> days) {
    if (days.every((day) => day.expenseTotal == 0)) return emptyLabel;
    final recent = days.skip((days.length - 7).clamp(0, days.length)).fold<double>(
        0, (sum, day) => sum + day.expenseTotal);
    final previousStart = (days.length - 14).clamp(0, days.length);
    final previousEnd = (days.length - 7).clamp(0, days.length);
    final previous = days
        .sublist(previousStart, previousEnd)
        .fold<double>(0, (sum, day) => sum + day.expenseTotal);
    if (previous == 0) return stableLabel;
    final change = (recent - previous).abs() / previous;
    if (change < 0.1) return stableLabel;
    return recent > previous ? increaseLabel : decreaseLabel;
  }
}

class _HeatMap extends StatelessWidget {
  final List<DailyWidgetActivity> days;
  final double maxExpense;
  final Color color;
  final bool dark;

  const _HeatMap({
    required this.days,
    required this.maxExpense,
    required this.color,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final cells = <DailyWidgetActivity?>[...days];
    while (cells.length < 30) {
      cells.insert(0, null);
    }
    return Column(
      children: [
        for (var row = 0; row < 3; row++)
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < 10; column++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: _cell(cells[row * 10 + column]),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(DailyWidgetActivity? day) {
    final ratio = day == null || maxExpense == 0 ? 0.0 : day.expenseTotal / maxExpense;
    final alpha = ratio == 0 ? (dark ? 0.10 : 0.08) : 0.22 + ratio * 0.70;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
