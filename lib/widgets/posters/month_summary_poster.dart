import 'package:beecount_business_ui/share_posters.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../services/export/share_poster_types.dart';
import 'poster_projection.dart';

class MonthSummaryPoster extends StatelessWidget {
  const MonthSummaryPoster(
      {super.key,
      required this.data,
      required this.primaryColor,
      this.hideIncome = false,
      this.currencyCode = 'CNY'});
  final MonthSummaryPosterData data;
  final Color primaryColor;
  final bool hideIncome;
  final String currencyCode;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String money(double n, {bool hidden = false}) =>
        posterMoney(n, l, currency: currencyCode, hidden: hidden);
    final change = data.expenseChangeRate;
    return MediaQuery.withNoTextScaling(
        child: BeeFinancialSharePoster(
            header: posterHeader(l, primaryColor, 'MONTH IN REVIEW'),
            footer: posterFooter(l),
            title: DateFormat.yMMMM(l.localeName)
                .format(DateTime(data.year, data.month)),
            subtitle: l.sharePosterMonthSubtitle,
            titleIcon: const Icon(Icons.calendar_month_outlined),
            expenseLabel: '${l.sharePosterTotalExpense} · $currencyCode',
            expense: money(data.totalExpense),
            metrics: [
              BeePosterMetric(l.sharePosterTotalIncome,
                  money(data.totalIncome, hidden: hideIncome)),
              BeePosterMetric(l.sharePosterMonthBalance,
                  money(data.balance, hidden: hideIncome))
            ],
            facts: [
              BeePosterMetric(l.sharePosterRecordCount,
                  '${data.recordCount}${l.sharePosterUnitCount}'),
              BeePosterMetric(
                  l.sharePosterAvgDailyExpense, money(data.avgDailyExpense))
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
            description: change == null
                ? null
                : '${change >= 0 ? l.sharePosterIncreaseRate : l.sharePosterDecreaseRate} ${(change.abs() * 100).toStringAsFixed(1)}%'));
  }
}
