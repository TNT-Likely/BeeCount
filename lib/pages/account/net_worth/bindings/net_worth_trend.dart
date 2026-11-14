import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/net_worth_trend_utils.dart';
import '../../../../utils/format_money.dart';

enum NetWorthLine { net, assets, liabilities }

enum NetWorthRange { m3, m6, m12, all }

extension NetWorthRangeDates on NetWorthRange {
  ({DateTime startDate, DateTime endDate}) dates(DateTime? earliest) {
    final now = trendTodayAnchor();
    final months =
        switch (this) { NetWorthRange.m3 => 2, NetWorthRange.m6 => 5, _ => 11 };
    final start = this == NetWorthRange.all
        ? earliest ?? DateTime(now.year, now.month - 11, 1)
        : DateTime(now.year, now.month - months, 1);
    return (startDate: DateTime(start.year, start.month, 1), endDate: now);
  }

  String label(AppLocalizations l) => switch (this) {
        NetWorthRange.m3 => l.netWorthTrend3M,
        NetWorthRange.m6 => l.netWorthTrend6M,
        NetWorthRange.m12 => l.netWorthTrend12M,
        NetWorthRange.all => l.netWorthTrendAll,
      };
}

extension NetWorthLineValue on NetWorthLine {
  String label(AppLocalizations l) => switch (this) {
        NetWorthLine.net => l.netWorthTrendLineNet,
        NetWorthLine.assets => l.netWorthTrendLineAssets,
        NetWorthLine.liabilities => l.netWorthTrendLineLiabilities,
      };
  double pick(
          ({DateTime date, double assets, double liabilities, double net}) e) =>
      switch (this) {
        NetWorthLine.net => e.net,
        NetWorthLine.assets => e.assets,
        NetWorthLine.liabilities => e.liabilities,
      };
}

/// Values and conversion stay in the existing repository/provider; this binding
/// only downsamples and formats its result for reusable presentation components.
class V4NetWorthTrendContent extends StatelessWidget {
  const V4NetWorthTrendContent(
      {super.key,
      required this.daily,
      required this.line,
      required this.range,
      required this.currency,
      required this.hidden,
      required this.multiCurrency,
      required this.onLine});
  final List<({DateTime date, double assets, double liabilities, double net})>
      daily;
  final NetWorthLine line;
  final NetWorthRange range;
  final String currency;
  final bool hidden, multiCurrency;
  final ValueChanged<NetWorthLine> onLine;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), theme = Theme.of(context);
    final monthly = downsampleMonthly(daily),
        values = monthly.map(line.pick).toList();
    final first = values.isEmpty ? 0.0 : values.first,
        last = values.isEmpty ? 0.0 : values.last;
    final delta = last - first;
    String amount(double v, {bool signed = false}) => hidden
        ? '••••'
        : formatDisplayAmount(v,
            currencyCode: currency, showCurrency: true, signed: signed);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (daily.length >= 2) ...[
        BeeResourceHero(
            title: line.label(l),
            caption: '$currency · ${range.label(l)}',
            icon: const BeeLineIcon('ChartNoAxesCombined', size: 22),
            fitMetricValues: true,
            amountLabel: l.v4TrendClosing,
            amount: amount(last),
            metrics: [
              BeeResourceMetric(label: l.v4TrendOpening, value: amount(first)),
              BeeResourceMetric(
                  label: l.v4TrendChange, value: amount(delta, signed: true)),
              if (!hidden && first != 0)
                BeeResourceMetric(
                    label: l.v4TrendChangeRate,
                    value:
                        '${delta >= 0 ? '+' : ''}${(delta / first.abs() * 100).toStringAsFixed(1)}%'),
            ]),
        const SizedBox(height: 12),
      ],
      BeeAssetChartSection<NetWorthLine>(
          title: l.netWorthTrendTitle,
          segments: [
            for (final v in NetWorthLine.values) BeeSegment(v, v.label(l))
          ],
          selected: line,
          onSelected: onLine,
          child: daily.length < 2
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: BeeEmptyState(
                      title: l.commonEmpty,
                      icon: const BeeLineIcon('ChartNoAxesCombined')))
              : SizedBox(
                  height: 240,
                  child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: BeeLineChart(
                        values: values,
                        xLabels: [
                          for (final e in monthly)
                            '${e.date.year % 100}/${e.date.month}'
                        ],
                        highlightIndex: values.length - 1,
                        onSwipeLeft: () {},
                        onSwipeRight: () {},
                        hideAmounts: hidden,
                        themeColor: theme.colorScheme.primary,
                        whiteBg: false,
                        minimal: true,
                        isDark: theme.brightness == Brightness.dark,
                      )))),
      if (multiCurrency)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(l.netWorthTrendMultiCurrencyNote,
                style: TextStyle(
                    fontSize: 11, height: 1.5, color: theme.hintColor))),
    ]);
  }
}
