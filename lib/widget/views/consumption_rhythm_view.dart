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
  final String rangeLabel;
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
    this.rangeLabel = 'Last 30 days',
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
        0,
        (maximum, day) =>
            day.expenseTotal > maximum ? day.expenseTotal : maximum);
    final empty = maxExpense == 0;

    return WidgetCardSurface(
      width: width,
      height: height,
      dark: dark,
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WidgetCardHeading(
              icon: Icons.bar_chart_rounded,
              title: titleLabel,
              meta: rangeLabel,
              dark: dark),
          const SizedBox(height: 7),
          if (empty)
            Expanded(
                child: WidgetCardEmpty(
                    icon: Icons.bar_chart_rounded,
                    label: emptyLabel,
                    dark: dark))
          else ...[
            Expanded(
                child: _HeatMap(
                    days: days,
                    maxExpense: maxExpense,
                    color: themeColor,
                    dark: dark)),
            const SizedBox(height: 5),
            Text(_comparisonLabel(days),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: widgetTextSecondary(dark),
                    fontSize: 11,
                    height: 1.15)),
          ],
        ],
      ),
    );
  }

  String _comparisonLabel(List<DailyWidgetActivity> days) {
    final recent = days
        .skip((days.length - 7).clamp(0, days.length))
        .fold<double>(0, (sum, day) => sum + day.expenseTotal);
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
      key: const ValueKey('widget-rhythm-grid'),
      children: [
        for (var row = 0; row < 3; row++)
          Expanded(
            child: Row(
              // 每个热力格都是无 child 的 DecoratedBox；Row 默认居中时它
              // 会按自身固有高度 0 布局。撑满交叉轴，确保离屏 PNG 中每格
              // 都拿到非零高度。
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
    final ratio =
        day == null || maxExpense == 0 ? 0.0 : day.expenseTotal / maxExpense;
    final base = widgetCardSoft(dark);
    final fill =
        ratio <= 0 ? base : Color.lerp(base, color, .18 + .82 * ratio)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
