import 'package:flutter/material.dart';

import '../widget_spec.dart' show HWSize;
import 'widget_view_style.dart';

/// 收支速览只展示调用方已经按账本币种格式化的金额。
class GlanceView extends StatelessWidget {
  final HWSize size;
  final String todayExpense;
  final String todayIncome;
  final String monthExpense;
  final String monthIncome;
  final Color themeColor;
  final bool redForIncome;
  final bool dark;
  final String titleLabel;
  final String monthSuffix;
  final String todayLabel;
  final String todayExpenseLabel;
  final String todayIncomeLabel;
  final String monthExpenseLabel;
  final String monthIncomeLabel;
  final String? periodLabel;
  final String? currencyCode;
  final double width;
  final double height;
  final bool isolatePreviewTypography;

  const GlanceView.medium({
    super.key,
    required this.todayExpense,
    required this.todayIncome,
    required this.monthExpense,
    required this.monthIncome,
    required this.themeColor,
    required this.redForIncome,
    required this.dark,
    this.monthSuffix = '月',
    required this.todayExpenseLabel,
    required this.todayIncomeLabel,
    required this.monthExpenseLabel,
    required this.monthIncomeLabel,
    required this.width,
    required this.height,
    this.titleLabel = '收支速览',
    this.todayLabel = '今日',
    this.periodLabel,
    this.currencyCode,
    this.isolatePreviewTypography = false,
  }) : size = HWSize.medium;

  const GlanceView.small({
    super.key,
    required this.todayExpense,
    required this.monthExpense,
    required this.monthIncome,
    required this.themeColor,
    required this.redForIncome,
    required this.dark,
    required this.todayLabel,
    required this.todayExpenseLabel,
    required this.monthExpenseLabel,
    required this.monthIncomeLabel,
    required this.width,
    required this.height,
    this.todayIncome = '',
    this.titleLabel = '',
    this.monthSuffix = '',
    this.todayIncomeLabel = '',
    this.isolatePreviewTypography = false,
  })  : size = HWSize.small,
        periodLabel = null,
        currencyCode = null;

  @override
  Widget build(BuildContext context) {
    final small = size == HWSize.small;
    // Android's 2:1 launcher uses a 182dp canvas to center the 169dp artwork.
    final cardHeight = small || height <= 169 ? height : 169.0;
    final surface = WidgetCardSurface(
      width: width,
      height: cardHeight,
      dark: dark,
      padding: small
          ? const EdgeInsets.symmetric(horizontal: 13, vertical: 11)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WidgetCardHeading(
            icon: Icons.dashboard_outlined,
            title: titleLabel.isEmpty ? todayLabel : titleLabel,
            meta: small
                ? null
                : [
                    periodLabel ?? '${DateTime.now().month}$monthSuffix',
                    if (currencyCode?.isNotEmpty == true) currencyCode!,
                  ].join(' · '),
            dark: dark,
            compact: small,
          ),
          SizedBox(height: small ? 5 : 9),
          Expanded(child: small ? _compact() : _columns()),
        ],
      ),
    );
    final canvas = SizedBox(
      width: width,
      height: height,
      child: Center(child: surface),
    );
    return isolatePreviewTypography
        ? DefaultTextStyle(style: const TextStyle(), child: canvas)
        : canvas;
  }

  Widget _label(String text, double fontSize, {int? maxLines = 1}) => Text(
        text,
        maxLines: maxLines,
        overflow:
            maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
        style: TextStyle(
          color: widgetTextSecondary(dark),
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          height: 1.15,
        ),
      );

  Widget _money(String value, double fontSize) =>
      WidgetCardMoney(amount: value, dark: dark, fontSize: fontSize);

  Widget _rule() =>
      SizedBox(height: 1, child: ColoredBox(color: widgetDivider(dark)));

  Widget _compact() {
    Widget month(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _label(label, 9, maxLines: null),
              const SizedBox(height: 3),
              _money(value, 14)
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _label(todayExpenseLabel, 10),
              const SizedBox(height: 4),
              Flexible(child: _money(todayExpense, 29)),
            ],
          ),
        ),
        _rule(),
        const SizedBox(height: 7),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          month(monthExpenseLabel, monthExpense),
          const SizedBox(width: 5),
          month(monthIncomeLabel, monthIncome),
        ]),
      ],
    );
  }

  Widget _columns() {
    Widget flow(String todayLabel, String today, String monthLabel,
            String month, Color marker) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                DecoratedBox(
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: marker),
                  child: const SizedBox.square(dimension: 6),
                ),
                const SizedBox(width: 5),
                Expanded(child: _label(todayLabel, 11)),
              ]),
              const SizedBox(height: 4),
              _money(today, 30),
              const Spacer(),
              _rule(),
              const SizedBox(height: 7),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [_label(monthLabel, 11), _money(month, 16)],
              ),
            ],
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        flow(todayExpenseLabel, todayExpense, monthExpenseLabel, monthExpense,
            widgetExpenseColor(redForIncome, dark: dark)),
        const SizedBox(width: 14),
        SizedBox(width: 1, child: ColoredBox(color: widgetDivider(dark))),
        const SizedBox(width: 14),
        flow(todayIncomeLabel, todayIncome, monthIncomeLabel, monthIncome,
            widgetIncomeColor(redForIncome, dark: dark)),
      ],
    );
  }
}
