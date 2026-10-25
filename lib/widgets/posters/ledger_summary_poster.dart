import 'package:beecount_business_ui/share_posters.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../services/export/share_poster_types.dart';
import 'poster_projection.dart';

class LedgerSummaryPoster extends StatelessWidget {
  const LedgerSummaryPoster(
      {super.key,
      required this.data,
      required this.primaryColor,
      this.hideIncome = false,
      this.currencyCode = 'CNY'});
  final LedgerSummaryPosterData data;
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
            header: posterHeader(l, primaryColor, 'OUR SHARED DAYS'),
            footer: posterFooter(l),
            title: data.ledgerName,
            subtitle: l.sharePosterLedgerTitle,
            titleIcon: const Icon(Icons.menu_book_outlined),
            period: data.firstRecordDate == null || data.lastRecordDate == null
                ? null
                : '${DateFormat.yMd(l.localeName).format(data.firstRecordDate!)} — ${DateFormat.yMd(l.localeName).format(data.lastRecordDate!)}',
            expenseLabel: '${l.sharePosterTotalExpense} · $currencyCode',
            expense: money(data.totalExpense),
            metrics: [
              BeePosterMetric(l.sharePosterTotalIncome,
                  money(data.totalIncome, hidden: hideIncome)),
              BeePosterMetric(
                  l.sharePosterBalance, money(data.balance, hidden: hideIncome))
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
                currency: currencyCode, hidden: hideIncome, kind: 'income')));
  }
}
