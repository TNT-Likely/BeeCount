import 'package:beecount_business_ui/annual_report.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../data/db.dart';
import '../../../../l10n/app_localizations.dart';
import '../../annual_report_page.dart';
import '../../../../services/data/category_service.dart';
import '../../../../utils/currencies.dart';
import '../../../../utils/month_range.dart';
import '../../../../utils/report_period_elapsed.dart';

/// Localization, currency formatting and the existing report calculations stay
/// in App. Business UI receives only values, labels and chart proportions.
List<Widget> annualReportSections(BuildContext context, AnnualReportData data,
    {required int monthStartDay, DateTime? now}) {
  final l = AppLocalizations.of(context);
  final accent = Theme.of(context).colorScheme.primary;
  const incomeColor = Color(0xff23896d), expenseColor = Color(0xffd45c5c);
  final decimal = NumberFormat('#,##0.00', l.localeName);
  final integer = NumberFormat('#,##0', l.localeName);
  String money(double value,
          {String? currency, bool whole = false, bool sign = false}) =>
      '${sign ? (value >= 0 ? '+' : '-') : ''}${getCurrencySymbol(currency ?? data.currencyCode)}${(whole ? integer : decimal).format(sign ? value.abs() : value)}';
  Widget metric(String label, String value, IconData icon,
          {String? description, Color? color, bool compact = false}) =>
      BeeAnnualMetric(
          label: label,
          value: value,
          icon: Icon(icon),
          description: description,
          color: color,
          compact: compact);
  Widget section(String title, String subtitle, List<Widget> children) =>
      BeeAnnualReportSection(
          title: title, subtitle: subtitle, children: children);
  String month(int m, {bool full = false}) =>
      (full ? DateFormat.MMMM(l.localeName) : DateFormat.MMM(l.localeName))
          .format(DateTime(data.year, m));

  final avgExpensePerRecord =
      data.totalRecords > 0 ? data.totalExpense / data.totalRecords : 0.0;
  final today = now ?? DateTime.now();
  final yr = yearRangeFor(data.year, monthStartDay);
  final totalCalendarDays = elapsedReportDays(yr, now: today);
  final elapsedMonths = elapsedReportYearMonths(data.year,
      monthStartDay: monthStartDay, now: today);
  final dailyAvg =
      totalCalendarDays > 0 ? data.totalExpense / totalCalendarDays : 0.0;
  final monthlyAvg =
      elapsedMonths > 0 ? data.totalExpense / elapsedMonths : 0.0;
  int busiestMonth = 1;
  double maxMonthlyTotal = 0;
  for (final m in data.monthlyData) {
    final total = m.income + m.expense;
    if (total > maxMonthlyTotal) {
      maxMonthlyTotal = total;
      busiestMonth = m.month;
    }
  }
  final savingsRate =
      data.totalIncome > 0 ? data.netSavings / data.totalIncome * 100 : 0.0;
  double maxIncome = 0, maxExpense = 0, minExpense = double.infinity;
  int maxIncomeMonth = 1, maxExpenseMonth = 1, minMonth = 1;
  for (final m in data.monthlyData) {
    if (m.income > maxIncome) {
      maxIncome = m.income;
      maxIncomeMonth = m.month;
    }
    if (m.expense > maxExpense) {
      maxExpense = m.expense;
      maxExpenseMonth = m.month;
    }
    if (m.expense < minExpense && m.expense > 0) {
      minExpense = m.expense;
      minMonth = m.month;
    }
  }
  if (minExpense == double.infinity) minExpense = 0;
  final maxValue = maxIncome > maxExpense ? maxIncome : maxExpense;
  Widget moment(String label, Transaction tx, Category? category, IconData icon,
          Color color) =>
      BeeAnnualMoment(
          label: label,
          amount:
              money(tx.amount, currency: tx.currencyCode ?? data.currencyCode),
          date: DateFormat.MMMd(l.localeName).format(tx.happenedAt),
          note: tx.note ?? category?.name ?? '',
          icon: Icon(icon),
          color: color);
  return [
    SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(17, 8, 17, 20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BeeAnnualOverview(
              year: '${data.year}',
              title: l.annualReportPage1Title,
              subtitle:
                  '${l.annualReportPage1Subtitle(data.year)} · ${data.currencyCode}',
              expenseLabel: l.annualReportTotalExpense,
              expense: money(data.totalExpense),
              incomeLabel: l.annualReportTotalIncome,
              income: money(data.totalIncome),
              savingsLabel: l.annualReportNetSavings,
              savings: money(data.netSavings, sign: true),
              brand: Image.asset('assets/logo2.png', width: 32, height: 32),
              facts: [
                (
                  label: l.annualReportTotalDays,
                  value: '${data.totalDays}${l.sharePosterUnitDay}'
                ),
                (
                  label: l.annualReportTotalRecords,
                  value: '${data.totalRecords}${l.sharePosterUnitCount}'
                )
              ]),
        ])),
    section(l.annualReportInsightsTitle, l.annualReportInsightsSubtitle, [
      metric(l.annualReportAveragePerRecord, money(avgExpensePerRecord),
          Icons.receipt_long_outlined,
          description: l.annualReportAveragePerRecordDesc),
      metric(l.annualReportDailyAverage, money(dailyAvg), Icons.schedule,
          description: l.annualReportDailyAverageDesc),
      metric(l.annualReportMonthlyAverage, money(monthlyAvg),
          Icons.date_range_outlined,
          description: l.annualReportMonthlyAverageDesc),
      metric(l.annualReportBusiestMonth, month(busiestMonth, full: true),
          Icons.calendar_month_outlined,
          description: l.annualReportBusiestMonthDesc),
      metric(
          l.annualReportCategoryCount,
          l.annualReportCategoryCountValue(data.topExpenseCategories.length),
          Icons.category_outlined,
          description: l.annualReportCategoryCountDesc),
      if (data.totalIncome > 0)
        metric(l.annualReportSavingsRate, '${savingsRate.toStringAsFixed(1)}%',
            Icons.savings_outlined,
            description: savingsRate >= 0
                ? l.annualReportSavingsRatePositive
                : l.annualReportSavingsRateNegative,
            color: savingsRate >= 0 ? incomeColor : expenseColor),
    ]),
    section(l.annualReportComparisonTitle, l.annualReportComparisonSubtitle, [
      for (final m in data.monthlyData)
        BeeAnnualComparisonRow(
            month: month(m.month),
            income: money(m.income, whole: true),
            expense: money(m.expense, whole: true),
            incomeRatio: maxValue > 0 ? m.income / maxValue : 0,
            expenseRatio: maxValue > 0 ? m.expense / maxValue : 0,
            incomeLabel: l.analyticsIncome,
            expenseLabel: l.analyticsExpense,
            highlights: [
              if (m.month == maxIncomeMonth) l.annualReportHighestIncome,
              if (m.month == maxExpenseMonth) l.annualReportHighestExpense
            ]),
    ]),
    section(l.annualReportPage2Title, l.annualReportPage2Subtitle, [
      for (final entry in data.topExpenseCategories.asMap().entries)
        BeeAnnualRank(
            rank: entry.key + 1,
            title: entry.value.name,
            amount: money(entry.value.total),
            percentage: '${(entry.value.percentage * 100).toStringAsFixed(1)}%',
            fraction: entry.value.percentage,
            icon: entry.value.icon == null
                ? null
                : Icon(CategoryService.getCategoryIcon(entry.value.icon))),
    ]),
    section(l.annualReportPage3Title, l.annualReportPage3Subtitle, [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: metric(l.annualReportHighestMonth,
                month(maxExpenseMonth, full: true), Icons.trending_up,
                description: money(maxExpense, whole: true),
                color: expenseColor,
                compact: true)),
        const SizedBox(width: 12),
        Expanded(
            child: metric(l.annualReportLowestMonth,
                month(minMonth, full: true), Icons.trending_down,
                description: money(minExpense, whole: true),
                color: incomeColor,
                compact: true))
      ]),
      BeeAnnualTrend(points: [
        for (final m in data.monthlyData)
          BeeAnnualTrendPoint(
              label: '${m.month}',
              amount: money(m.expense, whole: true),
              fraction: maxExpense > 0 ? m.expense / maxExpense : 0,
              color: m.month == maxExpenseMonth
                  ? expenseColor
                  : m.month == minMonth
                      ? incomeColor
                      : null)
      ]),
    ]),
    section(l.annualReportPage4Title, l.annualReportPage4Subtitle, [
      if (data.largestExpense != null)
        moment(l.annualReportLargestExpense, data.largestExpense!,
            data.largestExpenseCategory, Icons.arrow_downward, expenseColor),
      if (data.largestIncome != null)
        moment(l.annualReportLargestIncome, data.largestIncome!,
            data.largestIncomeCategory, Icons.arrow_upward, incomeColor),
      if (data.firstRecord != null)
        moment(l.annualReportFirstRecord, data.firstRecord!,
            data.firstRecordCategory, Icons.flag_outlined, accent),
    ]),
    section(l.annualReportPage5Title, l.annualReportPage5Subtitle, [
      BeeAnnualAchievement(
          title: l.annualReportAchievementConsistent,
          description:
              l.annualReportAchievementConsistentDesc(data.maxConsecutiveDays),
          icon: const Icon(Icons.local_fire_department_outlined),
          unlocked: data.maxConsecutiveDays >= 7),
      BeeAnnualAchievement(
          title: l.annualReportAchievementSaver,
          description: l.annualReportAchievementSaverDesc,
          icon: const Icon(Icons.savings_outlined),
          unlocked: data.netSavings > 0),
      BeeAnnualAchievement(
          title: l.annualReportAchievementDetail,
          description: l.annualReportAchievementDetailDesc(data.totalRecords),
          icon: const Icon(Icons.auto_awesome_outlined),
          unlocked: data.totalRecords >= 100),
    ]),
  ];
}
