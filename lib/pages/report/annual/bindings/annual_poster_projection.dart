import 'package:beecount_business_ui/share_posters.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/db.dart';
import '../../../../l10n/app_localizations.dart';
import '../../annual_report_page.dart';
import '../../../../utils/month_range.dart';
import '../../../../utils/report_period_elapsed.dart';
import '../../../shared/sharing/bindings/poster_projection.dart';

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
    BeeAnnualPosterMoment moment(
            String label, Transaction tx, Category? category, IconData icon) =>
        BeeAnnualPosterMoment(
            label: label,
            amount: money(tx.amount,
                currency: tx.currencyCode ?? data.currencyCode,
                hidden: hideIncome && tx.type == 'income'),
            date: DateFormat.yMMMd(l.localeName).format(tx.happenedAt),
            note: tx.note ?? category?.name ?? '',
            icon: Icon(icon));
    return BeeAnnualReportPoster(
      header: posterHeader(l, primaryColor, 'ANNUAL REPORT / ${data.year}'),
      footer: posterFooter(l),
      year: '${data.year}',
      subtitle: l.annualReportPage1Subtitle(data.year),
      expenseLabel: '${l.annualReportTotalExpense} · ${data.currencyCode}',
      expense: money(data.totalExpense),
      accent: primaryColor,
      summaryMetrics: [
        BeePosterMetric(l.annualReportTotalIncome,
            money(data.totalIncome, hidden: hideIncome)),
        BeePosterMetric(l.annualReportNetSavings,
            money(data.netSavings, hidden: hideIncome, sign: true)),
      ],
      chapters: [
        BeeAnnualPosterChapter(
            index: '01',
            title: l.annualReportPage1Title,
            metricGroups: [
              if (hideIncome)
                [
                  BeePosterMetric(
                      l.annualReportConsistency,
                      posterUnit(
                          data.maxConsecutiveDays, l.sharePosterUnitDay, l)),
                ],
              [
                BeePosterMetric(l.annualReportTotalDays,
                    '${data.totalDays}${l.sharePosterUnitDay}'),
                BeePosterMetric(l.annualReportTotalRecords,
                    '${data.totalRecords}${l.sharePosterUnitCount}'),
              ],
            ]),
        BeeAnnualPosterChapter(
            index: '02',
            title: l.annualReportPage3Title,
            subtitle: l.annualReportPage3Subtitle,
            trend: [
              for (final m in data.monthlyData)
                BeePosterTrendPoint(
                    '${m.month}', maxExpense > 0 ? m.expense / maxExpense : 0,
                    selected:
                        m.month == today.month && data.year == today.year),
            ],
            metricGroups: [
              [
                BeePosterMetric(l.annualReportHighestMonth,
                    '${month(maxMonth)} · ${money(maxExpense)}'),
                BeePosterMetric(l.annualReportLowestMonth,
                    '${month(minMonth)} · ${money(minExpense)}'),
              ]
            ]),
        BeeAnnualPosterChapter(
            index: '03',
            title: l.annualReportInsightsTitle,
            subtitle: l.annualReportInsightsSubtitle,
            metricGroups: [
              [
                BeePosterMetric(
                    l.annualReportAveragePerRecord,
                    money(data.totalRecords > 0
                        ? data.totalExpense / data.totalRecords
                        : 0)),
                BeePosterMetric(
                    l.annualReportDailyAverage,
                    money(
                        elapsedDays > 0 ? data.totalExpense / elapsedDays : 0)),
              ],
              [
                BeePosterMetric(
                    l.sharePosterAvgMonthlyExpense,
                    money(elapsedMonths > 0
                        ? data.totalExpense / elapsedMonths
                        : 0)),
                BeePosterMetric(
                    l.sharePosterAvgMonthlyIncome,
                    money(
                        elapsedMonths > 0
                            ? data.totalIncome / elapsedMonths
                            : 0,
                        hidden: hideIncome)),
              ],
              [
                BeePosterMetric(
                    l.annualReportBusiestMonth, month(busiestMonth)),
                BeePosterMetric(
                    l.annualReportCategoryCount,
                    l.annualReportCategoryCountValue(
                        data.topExpenseCategories.length)),
              ],
              if (data.totalIncome > 0)
                [
                  BeePosterMetric(
                      l.annualReportSavingsRate,
                      hideIncome
                          ? '**'
                          : '${(data.netSavings / data.totalIncome * 100).toStringAsFixed(1)}%'),
                ],
            ]),
        BeeAnnualPosterChapter(
            index: '04',
            title: l.annualReportPage2Title,
            subtitle: l.annualReportPage2Subtitle,
            rankingTitle: l.annualReportTotalExpense,
            categories: posterCategories(context, data.topExpenseCategories, l,
                currency: data.currencyCode),
            emptyLabel: l.commonEmpty),
        BeeAnnualPosterChapter(
            index: '05',
            title: l.annualReportPage4Title,
            subtitle: l.annualReportPage4Subtitle,
            moments: [
              if (data.largestExpense != null)
                moment(l.annualReportLargestExpense, data.largestExpense!,
                    data.largestExpenseCategory, Icons.shopping_bag_outlined),
              if (data.largestIncome != null)
                moment(l.annualReportLargestIncome, data.largestIncome!,
                    data.largestIncomeCategory, Icons.work_outline),
              if (data.firstRecord != null)
                moment(l.annualReportFirstRecord, data.firstRecord!,
                    data.firstRecordCategory, Icons.receipt_long_outlined),
            ],
            emptyMomentLabel: data.firstRecord == null ? l.commonEmpty : null),
        BeeAnnualPosterChapter(
            index: '06',
            title: l.annualReportPage5Title,
            moments: [
              BeeAnnualPosterMoment(
                  label: l.annualReportAchievementConsistent,
                  note: l.annualReportAchievementConsistentDesc(
                      data.maxConsecutiveDays),
                  icon: const Icon(Icons.local_fire_department_outlined),
                  unlocked: data.maxConsecutiveDays >= 7),
              BeeAnnualPosterMoment(
                  label: l.annualReportAchievementSaver,
                  note: l.annualReportAchievementSaverDesc,
                  icon: const Icon(Icons.savings_outlined),
                  unlocked: data.netSavings > 0),
              BeeAnnualPosterMoment(
                  label: l.annualReportAchievementDetail,
                  note: l.annualReportAchievementDetailDesc(data.totalRecords),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  unlocked: data.totalRecords >= 100),
            ]),
        BeeAnnualPosterChapter(
            index: '07',
            title: l.sharePosterSlogan,
            body: l.annualReportPage5Subtitle),
      ],
    );
  }
}
