import 'package:beecount_business_ui/share_posters.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../services/export/share_poster_types.dart';
import 'poster_projection.dart';

class YearSummaryPoster extends StatelessWidget {
  const YearSummaryPoster(
      {super.key,
      required this.data,
      required this.primaryColor,
      this.hideIncome = false,
      this.currencyCode = 'CNY'});
  final YearSummaryPosterData data;
  final Color primaryColor;
  final bool hideIncome;
  final String currencyCode;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String money(double n, {bool hidden = false}) =>
        posterMoney(n, l, currency: currencyCode, hidden: hidden);
    return MediaQuery.withNoTextScaling(
        child: BeeFinancialSharePoster(
            header: posterHeader(l, primaryColor, 'YEAR IN REVIEW'),
            footer: posterFooter(l),
            title: '${data.year}',
            subtitle: l.sharePosterYearSubtitle,
            year: true,
            titleIcon: const Icon(Icons.calendar_month_outlined),
            expenseLabel: '${l.sharePosterTotalExpense} · $currencyCode',
            expense: money(data.totalExpense),
            metrics: [
              BeePosterMetric(l.sharePosterTotalIncome,
                  money(data.totalIncome, hidden: hideIncome)),
              BeePosterMetric(l.sharePosterYearBalance,
                  money(data.balance, hidden: hideIncome))
            ],
            facts: [
              BeePosterMetric(l.sharePosterRecordDays,
                  '${data.recordDays}${l.sharePosterUnitDay}'),
              BeePosterMetric(l.sharePosterRecordCount,
                  '${data.recordCount}${l.sharePosterUnitCount}')
            ],
            accent: primaryColor,
            expenseRankingLabel: l.sharePosterTopExpense,
            incomeRankingLabel: l.v4SharePosterTopIncome,
            emptyLabel: l.commonEmpty,
            expenseCategories: posterCategories(
                context, data.topExpenseCategories, l, currency: currencyCode),
            incomeCategories: posterCategories(
                context, data.topIncomeCategories, l,
                currency: currencyCode, hidden: hideIncome, kind: 'income'),
            description: [
              '${l.sharePosterAvgMonthlyExpense} ${money(data.avgMonthlyExpense)}',
              '${l.sharePosterAvgMonthlyIncome} ${money(data.avgMonthlyIncome, hidden: hideIncome)}',
              if (data.maxExpenseMonth != null && data.maxExpenseAmount != null)
                '${l.sharePosterMaxExpenseMonth} ${DateFormat.MMMM(l.localeName).format(DateTime(data.year, data.maxExpenseMonth!))} · ${money(data.maxExpenseAmount!)}'
            ].join('\n')));
  }
}
