import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/repositories/budget_repository.dart'
    show BudgetOverview, BudgetUsage;
import '../../utils/currencies.dart' show getCurrencySymbol;
import '../../utils/format_money.dart' show formatMoneyCompact;
import '../widget_spec.dart' show HWSize;
import 'widget_view_style.dart';

/// Monthly budget, with category budget usage or spending shares when available.
class BudgetView extends StatelessWidget {
  const BudgetView({
    super.key,
    required this.size,
    required this.overview,
    required this.currencyCode,
    required this.themeColor,
    required this.redForIncome,
    required this.dark,
    this.budgetLabel = '本月预算',
    this.usedLabel = '已用',
    this.totalLabel = '总额',
    this.remainingLabel = '剩',
    this.noBudgetLabel = '未设预算',
    this.monthLabel,
    this.categoryUsageLabel,
    this.spendingShareLabel,
    this.fallbackShares = const [],
    required this.width,
    required this.height,
  });

  final HWSize size;
  final BudgetOverview overview;
  final String currencyCode;
  final Color themeColor;
  final bool redForIncome, dark;
  final String budgetLabel,
      usedLabel,
      totalLabel,
      remainingLabel,
      noBudgetLabel;
  final String? monthLabel, categoryUsageLabel, spendingShareLabel;
  final List<({String name, double share})> fallbackShares;
  final double width, height;

  String _money(double value) =>
      '${getCurrencySymbol(currencyCode)}${formatMoneyCompact(value)}';

  Color _statusColor(String status) => switch (status) {
        'exceeded' || 'danger' => widgetExpenseColor(redForIncome, dark: dark),
        'warning' => dark ? const Color(0xffffb85e) : const Color(0xffae6914),
        _ => themeColor,
      };

  Widget _caption(String label, {double fontSize = 10}) => Text(label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: fontSize, color: widgetTextSecondary(dark)));

  Widget _ring(BudgetUsage total, bool small) => SizedBox.square(
        dimension: small ? 47 : 63,
        child: CustomPaint(
          painter: _BudgetRingPainter(
              progress: total.rate,
              trackColor: widgetCardSoft(dark),
              progressColor: _statusColor(total.status),
              strokeWidth: small ? 4 : 6),
          child: Padding(
            padding: EdgeInsets.all(small ? 6 : 9),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('${(total.rate * 100).round()}%',
                  style: TextStyle(
                      fontSize: small ? 14 : 17,
                      fontWeight: FontWeight.w700,
                      color: widgetTextPrimary(dark),
                      fontFeatures: const [kWidgetTabularFeature])),
            ),
          ),
        ),
      );

  Widget _details(String label, double amount, bool small) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _caption(label, fontSize: small ? 9 : 11),
          const SizedBox(width: 4),
          WidgetCardMoney(
              amount: _money(amount), dark: dark, fontSize: small ? 11 : 13),
        ]),
      );

  Widget _categories() {
    // Category budgets and spending shares use different denominators.
    final hasBudgets = overview.categoryBudgets.isNotEmpty;
    final entries = hasBudgets
        ? [
            for (final item in overview.categoryBudgets.take(3))
              (
                name: item.categoryName,
                fraction: item.usage.rate,
                color: item.usage.status == 'normal'
                    ? widgetTextPrimary(dark)
                    : _statusColor(item.usage.status)
              )
          ]
        : [
            for (final item in fallbackShares.take(3))
              (
                name: item.name,
                fraction: item.share,
                color: widgetTextPrimary(dark)
              )
          ];
    final label = hasBudgets ? categoryUsageLabel : spendingShareLabel;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (label != null && label.isNotEmpty) _caption(label),
      Row(children: [
        for (final entry in entries)
          Expanded(
              child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(children: [
              Flexible(child: _caption(entry.name)),
              const SizedBox(width: 3),
              Text('${(entry.fraction * 100).round()}%',
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 11,
                      color: entry.color,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [kWidgetTabularFeature])),
            ]),
          )),
      ]),
    ]);
  }

  Widget _categoryOnlyRows() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 7),
          _caption(categoryUsageLabel ?? '分类预算'),
          for (final entry in overview.categoryBudgets.take(3))
            Expanded(
              child: Row(children: [
                Expanded(
                  flex: 2,
                  child: Text(entry.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, color: widgetTextPrimary(dark))),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: WidgetCardMoney(
                      amount:
                          '${_money(entry.usage.used)} / ${_money(entry.usage.budget)}',
                      dark: dark,
                      fontSize: 13,
                      alignment: Alignment.centerRight),
                ),
                const SizedBox(width: 8),
                SizedBox(
                    width: 42,
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text('${(entry.usage.rate * 100).round()}%',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: entry.usage.status == 'normal'
                                    ? widgetTextPrimary(dark)
                                    : _statusColor(entry.usage.status))))),
              ]),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final small = size == HWSize.small;
    final categoryOnly =
        overview.totalBudget == null && overview.categoryBudgets.isNotEmpty;
    final firstCategory =
        categoryOnly && small ? overview.categoryBudgets.first : null;
    final total = overview.totalBudget ?? firstCategory?.usage;
    final hasCategories = !small &&
        !categoryOnly &&
        (overview.categoryBudgets.isNotEmpty || fallbackShares.isNotEmpty);
    return WidgetCardSurface(
      dark: dark,
      width: width,
      height: height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        WidgetCardHeading(
            icon: Icons.pie_chart_outline,
            title: budgetLabel,
            dark: dark,
            compact: small,
            meta: small ? null : monthLabel),
        if (categoryOnly && !small)
          Expanded(child: _categoryOnlyRows())
        else if (total == null)
          Expanded(
              child: WidgetCardEmpty(
                  icon: Icons.pie_chart_outline,
                  label: noBudgetLabel,
                  dark: dark,
                  compact: small || hasCategories))
        else ...[
          if (firstCategory != null) ...[
            const SizedBox(height: 3),
            Row(children: [
              Flexible(
                  child: _caption(categoryUsageLabel ?? '分类预算', fontSize: 9)),
              const SizedBox(width: 4),
              Flexible(
                  child: Text(firstCategory.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color: widgetTextPrimary(dark),
                          fontWeight: FontWeight.w600))),
            ]),
          ],
          Expanded(
              child: Row(children: [
            _ring(total, small),
            SizedBox(width: small ? 6 : 12),
            Expanded(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _caption(remainingLabel),
                const SizedBox(height: 3),
                WidgetCardMoney(
                    amount: _money(total.remaining),
                    dark: dark,
                    fontSize: small ? 18 : 26),
              ],
            )),
          ])),
          Container(height: 1, color: widgetDivider(dark)),
          const SizedBox(height: 5),
          if (small) ...[
            _details(usedLabel, total.used, true),
            const SizedBox(height: 2),
            _details(totalLabel, total.budget, true),
          ] else
            Row(children: [
              Expanded(child: _details(usedLabel, total.used, false)),
              const SizedBox(width: 8),
              Expanded(
                  child: Align(
                      alignment: Alignment.centerRight,
                      child: _details(totalLabel, total.budget, false))),
            ]),
        ],
        if (hasCategories) ...[
          const SizedBox(height: 5),
          _categories(),
        ],
      ]),
    );
  }
}

class _BudgetRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _BudgetRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _BudgetRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
