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
        dimension: small ? 47 : 60,
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

  Widget _amountRow(String label, double amount, {required bool small}) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(flex: 2, child: _caption(label, fontSize: small ? 9 : 10)),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: WidgetCardMoney(
              amount: _money(amount),
              dark: dark,
              fontSize: small ? 11 : 12,
              alignment: Alignment.centerRight,
            ),
          ),
        ],
      );

  Widget _summary(BudgetUsage usage, {required bool small}) => Row(children: [
        _ring(usage, small),
        SizedBox(width: small ? 6 : 14),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _caption(remainingLabel),
              const SizedBox(height: 3),
              WidgetCardMoney(
                amount: _money(usage.remaining),
                dark: dark,
                fontSize: small ? 18 : 26,
              ),
              if (!small) ...[
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                        child: _amountRow(usedLabel, usage.used, small: false)),
                    const SizedBox(width: 14),
                    Expanded(
                        child:
                            _amountRow(totalLabel, usage.budget, small: false)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ]);

  Color _rateColor(String status) =>
      status == 'normal' ? widgetTextPrimary(dark) : _statusColor(status);

  Widget _categoryRate(
      String name, double fraction, Color textColor, Color fillColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: _caption(name)),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 50),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text('${(fraction * 100).round()}%',
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 11,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [kWidgetTabularFeature])),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: ColoredBox(
              color: widgetCardSoft(dark),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction.clamp(0.0, 1.0),
                heightFactor: 1,
                child: ColoredBox(color: fillColor),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _categories() {
    // Category budgets and spending shares use different denominators.
    final hasBudgets = overview.categoryBudgets.isNotEmpty;
    final entries = hasBudgets
        ? [
            for (final c in overview.categoryBudgets.take(3))
              (
                name: c.categoryName,
                fraction: c.usage.rate,
                textColor: _rateColor(c.usage.status),
                fillColor: _statusColor(c.usage.status)
              ),
          ]
        : [
            for (final share in fallbackShares.take(3))
              (
                name: share.name,
                fraction: share.share,
                textColor: widgetTextPrimary(dark),
                fillColor: themeColor
              ),
          ];
    final title = hasBudgets
        ? (categoryUsageLabel ?? '分类预算')
        : (spendingShareLabel ?? '支出占比');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(height: 1, color: widgetDivider(dark)),
      const SizedBox(height: 6),
      Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: widgetTextPrimary(dark))),
      const SizedBox(height: 4),
      Row(children: [
        for (final (index, entry) in entries.indexed) ...[
          if (index > 0) const SizedBox(width: 12),
          Expanded(
              child: _categoryRate(entry.name, entry.fraction, entry.textColor,
                  entry.fillColor)),
        ],
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
                                color: _rateColor(entry.usage.status))))),
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
          Expanded(child: _summary(total, small: small)),
          if (small) ...[
            Container(height: 1, color: widgetDivider(dark)),
            const SizedBox(height: 5),
            _amountRow(usedLabel, total.used, small: true),
            const SizedBox(height: 2),
            _amountRow(totalLabel, total.budget, small: true),
          ],
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
