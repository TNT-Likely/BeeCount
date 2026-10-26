import 'package:beecount_business_ui/share_posters.dart';
import 'package:beecount_ui/paper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/report/annual_report_page.dart';
import '../../utils/month_range.dart';
import '../../utils/report_period_elapsed.dart';
import 'poster_projection.dart';

/// The same yearly snapshot, calendar cutoffs and original transaction currencies
/// drive both preview and capture. No repository request or export side effect.
class AnnualReportPoster extends StatelessWidget {
  const AnnualReportPoster(
      {super.key,
      required this.data,
      required this.primaryColor,
      this.hideIncome = false,
      this.monthStartDay = 1,
      this.now});
  final AnnualReportData data;
  final Color primaryColor;
  final bool hideIncome;
  final int monthStartDay;
  final DateTime? now;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), today = now ?? DateTime.now();
    final elapsedDays = elapsedReportDays(
            yearRangeFor(data.year, monthStartDay),
            now: today),
        elapsedMonths = elapsedReportYearMonths(data.year,
            monthStartDay: monthStartDay, now: today);
    String money(double n,
            {bool hidden = false, String? currency, bool sign = false}) =>
        (sign && !hidden ? (n >= 0 ? '+' : '-') : '') +
        posterMoney(sign ? n.abs() : n, l,
            currency: currency ?? data.currencyCode, hidden: hidden);
    String month(int n) =>
        DateFormat.MMMM(l.localeName).format(DateTime(data.year, n));
    var maxExpense = 0.0,
        minExpense = double.infinity,
        maxMonth = 1,
        minMonth = 1,
        busiestMonth = 1;
    var busiestTotal = 0.0;
    for (final m in data.monthlyData) {
      if (m.expense > maxExpense) {
        maxExpense = m.expense;
        maxMonth = m.month;
      }
      if (m.expense > 0 && m.expense < minExpense) {
        minExpense = m.expense;
        minMonth = m.month;
      }
      if (m.income + m.expense > busiestTotal) {
        busiestTotal = m.income + m.expense;
        busiestMonth = m.month;
      }
    }
    if (!minExpense.isFinite) minExpense = 0;
    Widget metrics(List<BeePosterMetric> values) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: BeePosterMetricPair(metrics: values, soft: false));
    Widget moment(
            String label, Transaction tx, Category? category, IconData icon) =>
        BeePosterMoment(
            label: label,
            amount: money(tx.amount,
                currency: tx.currencyCode ?? data.currencyCode,
                hidden: hideIncome && tx.type == 'income'),
            date: DateFormat.yMMMd(l.localeName).format(tx.happenedAt),
            note: tx.note ?? category?.name ?? '',
            icon: Icon(icon));
    return MediaQuery.withNoTextScaling(
        child: BeePosterCanvas(height: null, children: [
      posterHeader(l, primaryColor, 'ANNUAL REPORT / ${data.year}'),
      const SizedBox(height: 65),
      Text('${data.year}',
          style: const TextStyle(
              fontSize: 105,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: -4)),
      const SizedBox(height: 17),
      Text(l.annualReportPage1Subtitle(data.year),
          style: const TextStyle(fontSize: 25, color: BeePaper.muted)),
      const SizedBox(height: 45),
      Text('${l.annualReportTotalExpense} · ${data.currencyCode}',
          style: const TextStyle(fontSize: 22, color: BeePaper.muted)),
      const SizedBox(height: 14),
      BeePosterAmount(money(data.totalExpense)),
      const SizedBox(height: 32),
      BeePosterMetricPair(metrics: [
        BeePosterMetric(l.annualReportTotalIncome,
            money(data.totalIncome, hidden: hideIncome)),
        BeePosterMetric(l.annualReportNetSavings,
            money(data.netSavings, hidden: hideIncome, sign: true))
      ]),
      BeePosterChapter(index: '01', title: l.annualReportPage1Title, children: [
        if (hideIncome)
          metrics([
            BeePosterMetric(l.annualReportConsistency,
                posterUnit(data.maxConsecutiveDays, l.sharePosterUnitDay, l))
          ]),
        metrics([
          BeePosterMetric(l.annualReportTotalDays,
              '${data.totalDays}${l.sharePosterUnitDay}'),
          BeePosterMetric(l.annualReportTotalRecords,
              '${data.totalRecords}${l.sharePosterUnitCount}')
        ])
      ]),
      BeePosterChapter(
          index: '02',
          title: l.annualReportPage3Title,
          subtitle: l.annualReportPage3Subtitle,
          children: [
            BeePosterTrend(accent: primaryColor, points: [
              for (final m in data.monthlyData)
                BeePosterTrendPoint(
                    '${m.month}', maxExpense > 0 ? m.expense / maxExpense : 0,
                    selected: m.month == today.month && data.year == today.year)
            ]),
            const SizedBox(height: 27),
            metrics([
              BeePosterMetric(l.annualReportHighestMonth,
                  '${month(maxMonth)} · ${money(maxExpense)}'),
              BeePosterMetric(l.annualReportLowestMonth,
                  '${month(minMonth)} · ${money(minExpense)}')
            ])
          ]),
      BeePosterChapter(
          index: '03',
          title: l.annualReportInsightsTitle,
          subtitle: l.annualReportInsightsSubtitle,
          children: [
            metrics([
              BeePosterMetric(
                  l.annualReportAveragePerRecord,
                  money(data.totalRecords > 0
                      ? data.totalExpense / data.totalRecords
                      : 0)),
              BeePosterMetric(l.annualReportDailyAverage,
                  money(elapsedDays > 0 ? data.totalExpense / elapsedDays : 0))
            ]),
            metrics([
              BeePosterMetric(
                  l.sharePosterAvgMonthlyExpense,
                  money(elapsedMonths > 0
                      ? data.totalExpense / elapsedMonths
                      : 0)),
              BeePosterMetric(
                  l.sharePosterAvgMonthlyIncome,
                  money(
                      elapsedMonths > 0 ? data.totalIncome / elapsedMonths : 0,
                      hidden: hideIncome))
            ]),
            metrics([
              BeePosterMetric(l.annualReportBusiestMonth, month(busiestMonth)),
              BeePosterMetric(
                  l.annualReportCategoryCount,
                  l.annualReportCategoryCountValue(
                      data.topExpenseCategories.length))
            ]),
            if (data.totalIncome > 0)
              metrics([
                BeePosterMetric(
                    l.annualReportSavingsRate,
                    hideIncome
                        ? '**'
                        : '${(data.netSavings / data.totalIncome * 100).toStringAsFixed(1)}%')
              ])
          ]),
      BeePosterChapter(
          index: '04',
          title: l.annualReportPage2Title,
          subtitle: l.annualReportPage2Subtitle,
          children: [
            BeePosterRanking(
                title: l.annualReportTotalExpense,
                categories: posterCategories(
                    context, data.topExpenseCategories, l,
                    currency: data.currencyCode),
                accent: primaryColor,
                emptyLabel: l.commonEmpty,
                limit: 5)
          ]),
      BeePosterChapter(
          index: '05',
          title: l.annualReportPage4Title,
          subtitle: l.annualReportPage4Subtitle,
          children: [
            if (data.largestExpense != null)
              moment(l.annualReportLargestExpense, data.largestExpense!,
                  data.largestExpenseCategory, Icons.shopping_bag_outlined),
            if (data.largestIncome != null)
              moment(l.annualReportLargestIncome, data.largestIncome!,
                  data.largestIncomeCategory, Icons.work_outline),
            if (data.firstRecord != null)
              moment(l.annualReportFirstRecord, data.firstRecord!,
                  data.firstRecordCategory, Icons.receipt_long_outlined),
            if (data.firstRecord == null)
              Text(l.commonEmpty,
                  style: const TextStyle(fontSize: 22, color: BeePaper.muted))
          ]),
      BeePosterChapter(index: '06', title: l.annualReportPage5Title, children: [
        BeePosterMoment(
            label: l.annualReportAchievementConsistent,
            amount: '',
            date: '',
            note: l
                .annualReportAchievementConsistentDesc(data.maxConsecutiveDays),
            icon: const Icon(Icons.local_fire_department_outlined),
            unlocked: data.maxConsecutiveDays >= 7),
        BeePosterMoment(
            label: l.annualReportAchievementSaver,
            amount: '',
            date: '',
            note: l.annualReportAchievementSaverDesc,
            icon: const Icon(Icons.savings_outlined),
            unlocked: data.netSavings > 0),
        BeePosterMoment(
            label: l.annualReportAchievementDetail,
            amount: '',
            date: '',
            note: l.annualReportAchievementDetailDesc(data.totalRecords),
            icon: const Icon(Icons.auto_awesome_outlined),
            unlocked: data.totalRecords >= 100)
      ]),
      BeePosterChapter(index: '07', title: l.sharePosterSlogan, children: [
        Text(l.annualReportPage5Subtitle,
            style: const TextStyle(
                fontSize: 23, height: 1.8, color: BeePaper.muted))
      ]),
      const SizedBox(height: 42),
      posterFooter(l),
    ]));
  }
}
