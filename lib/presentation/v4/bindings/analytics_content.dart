import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../widgets/biz/format_money.dart';
import 'analytics_data.dart';
import 'analytics_ranking.dart';

class AnalyticsContent extends ConsumerWidget {
  const AnalyticsContent(
      {super.key,
      required this.data,
      required this.scope,
      required this.type,
      required this.month,
      required this.viewLabel,
      required this.showPie,
      required this.headerDismissed,
      required this.chartDismissed,
      required this.onView,
      required this.onAnnual,
      required this.onShare,
      required this.onSwitch,
      required this.onTogglePie,
      required this.onDismissHeader,
      required this.onDismissChart,
      required this.onRecalculate,
      required this.onPrevious,
      required this.onNext,
      required this.onChartSwipe,
      required this.onBodySwipe,
      this.onPeriod});
  final AnalyticsResult data;
  final String scope, type, viewLabel;
  final DateTime month;
  final bool showPie, headerDismissed, chartDismissed;
  final VoidCallback? onPeriod;
  final VoidCallback onAnnual,
      onShare,
      onView,
      onSwitch,
      onTogglePie,
      onDismissHeader,
      onDismissChart,
      onPrevious,
      onNext;
  final ValueChanged<int> onRecalculate;
  final ValueChanged<bool> onChartSwipe, onBodySwipe;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        t = Theme.of(context),
        hide = ref.watch(hideAmountsProvider),
        base = ref.watch(currentLedgerCurrencyProvider),
        unconverted =
            ref.watch(ledgerUnconvertedForeignTxCountProvider).valueOrNull ?? 0,
        foreign = ref.watch(ledgerForeignTxCountProvider).valueOrNull ?? 0;
    final period = scope == 'all'
        ? l.analyticsAllYears
        : scope == 'year'
            ? '${month.year}'
            : '${month.year}-${month.month.toString().padLeft(2, '0')}';
    String money(double v) => hide
        ? '****'
        : formatDisplayAmount(v,
            signed: false, showCurrency: true, currencyCode: base);
    final avgLabel = scope == 'year'
        ? l.analyticsMonthlyAvg
        : scope == 'all'
            ? l.analyticsOverallAvg
            : l.analyticsDailyAvg;
    List<String> labels() {
      final s = data.series;
      if (s is List<({DateTime day, double total})>) {
        return s.map((e) => '${e.day.day}').toList();
      }
      if (s is List<({DateTime month, double total})>) {
        return s
            .map((e) => l.homeMonth(e.month.month.toString().padLeft(2, '0')))
            .toList();
      }
      if (s is List<({int year, double total})>) {
        return s.map((e) => '${e.year}').toList();
      }
      return [];
    }

    final x = labels(), now = DateTime.now();
    int? highlight;
    if (scope == 'month' &&
        data.series is List<({DateTime day, double total})> &&
        month.year == now.year &&
        month.month == now.month) {
      highlight = now.day - 1;
      if (highlight >= 0 && highlight < x.length) {
        x[highlight] = l.analyticsToday;
      }
    }
    final chartHint = chartDismissed
        ? null
        : BeeAnalyticsHint(
            label: l.analyticsSwipeHint, onClose: onDismissChart);
    final children = <Widget>[
      if (unconverted > 0)
        BeeSurface(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const BeeLineIcon('ArrowLeftRight', size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(l.recalcForeignTxBanner,
                      style: const TextStyle(fontSize: 11))),
              TextButton(
                  onPressed: () => onRecalculate(unconverted),
                  child: Text(l.v4AnalyticsRecalculate))
            ])),
      if (foreign > 0)
        Text(l.statsConvertedFootnote(base),
            style: TextStyle(fontSize: 11, color: t.hintColor)),
      BeeAnalyticsSummary(
          period: period,
          viewLabel: viewLabel,
          onPeriod: onPeriod,
          onView: onView,
          totalLabel: l.analyticsTotal(viewLabel).trim(),
          total: money(data.total),
          countLabel: l.sharePosterRecordCount,
          count: '${data.count}',
          averageLabel: avgLabel,
          average: money(data.average)),
      if (data.empty) ...[
        BeeSurface(
            child: BeeEmptyState(
                title: l.commonEmpty,
                message: l.analyticsNoDataSubtext,
                action: BeeButton(
                    label: l.analyticsSwitchTo(type == 'expense'
                        ? l.homeIncome
                        : type == 'income'
                            ? l.homeBalance
                            : l.homeExpense),
                    onPressed: onSwitch))),
        if (!headerDismissed) BeeAnalyticsHint(label: l.analyticsTipHeader)
      ] else ...[
        BeeSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.v4AnalyticsTrend,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SizedBox(
                      height: 240,
                      child: BeeLineChart(
                          values: data.values,
                          xLabels: x,
                          highlightIndex: highlight,
                          onSwipeLeft: () => onChartSwipe(false),
                          onSwipeRight: () => onChartSwipe(true),
                          themeColor: t.colorScheme.primary,
                          whiteBg: false,
                          isDark: t.brightness == Brightness.dark,
                          showGrid: false,
                          showDots: true,
                          annotate: true,
                          hideAmounts: hide,
                          averageColor: t.hintColor.withValues(alpha: .55),
                          gridColor: t.dividerColor,
                          backgroundColor: BeeCardTheme.of(context).surface,
                          textColor: t.colorScheme.onSurface,
                          mutedColor: t.hintColor)),
                  if (chartHint != null) chartHint
                ])),
        if (type != 'balance')
          BeeSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(l.analyticsCategoryRanking,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600))),
                      if (data.categories.isNotEmpty && data.total > 0)
                        BeeIconButton(
                            label: showPie
                                ? l.v4AnalyticsShowRanking
                                : l.v4AnalyticsShowPie,
                            onPressed: onTogglePie,
                            icon: BeeLineIcon(showPie ? 'List' : 'ChartPie',
                                size: 18))
                    ]),
                    if (!headerDismissed)
                      BeeAnalyticsHint(
                          label: l.analyticsSwipeToSwitch,
                          onClose: onDismissHeader),
                    const SizedBox(height: 8),
                    if (showPie && data.total > 0)
                      AnalyticsPie(data: data)
                    else
                      AnalyticsRanking(
                          key: ValueKey((scope, month, type, data.total)),
                          data: data,
                          scope: scope,
                          month: month)
                  ]))
      ],
      BeeSurface(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
                leading: const BeeLineIcon('ChartNoAxesCombined', size: 20),
                title: Text(l.annualReportTitle,
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(l.annualReportEntrySubtitle,
                    style: const TextStyle(fontSize: 11)),
                trailing: const BeeLineIcon('ChevronRight', size: 16),
                onTap: onAnnual),
            Divider(
                height: 1, indent: 16, endIndent: 16, color: t.dividerColor),
            ListTile(
                leading: const BeeLineIcon('Image', size: 20),
                title: Text(l.annualReportShareButton,
                    style: const TextStyle(fontSize: 13)),
                trailing: const BeeLineIcon('ChevronRight', size: 16),
                onTap: onShare)
          ])),
    ];
    return GestureDetector(
        onHorizontalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) == 0) return;
          final previous = d.primaryVelocity! > 0;
          if (data.empty) {
            previous ? onPrevious() : onNext();
          } else {
            onBodySwipe(previous);
          }
        },
        child: BeePageBody(eager: true, bottomInset: 84, children: children));
  }
}
