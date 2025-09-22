import 'package:flutter/material.dart';
import '../../styles/colors.dart';
import '../../styles/design.dart';
import '../../l10n/app_localizations.dart';

class AnalyticsSummary extends StatelessWidget {
  final String scope; // month/year/all
  final bool isExpense;
  final double total;
  final double avg;
  final bool isSummary; // 汇总视角
  final double? expenseTotal; // 汇总视角的支出总额
  final double? incomeTotal; // 汇总视角的收入总额
  final double? expenseAvg; // 汇总视角的支出平均值
  final double? incomeAvg; // 汇总视角的收入平均值
  final bool showExpense; // 是否显示支出信息
  final bool showIncome; // 是否显示收入信息
  final Color? expenseColor; // 支出颜色
  final Color? incomeColor; // 收入颜色

  const AnalyticsSummary({
    super.key,
    required this.scope,
    required this.isExpense,
    required this.total,
    required this.avg,
    this.isSummary = false,
    this.expenseTotal,
    this.incomeTotal,
    this.expenseAvg,
    this.incomeAvg,
    this.showExpense = true,
    this.showIncome = true,
    this.expenseColor,
    this.incomeColor,
  });

  @override
  Widget build(BuildContext context) {
    final grey = BeeColors.secondaryText;
    final l10n = AppLocalizations.of(context)!;

    String avgLabel;
    switch (scope) {
      case 'year':
        avgLabel = l10n.analyticsMonthlyAvg;
        break;
      case 'all':
        avgLabel = l10n.analyticsOverallAvg;
        break;
      case 'month':
      default:
        avgLabel = l10n.analyticsDailyAvg;
    }

    if (isSummary) {
      // 汇总视角：显示收入、支出、结余
      final expense = expenseTotal ?? 0.0;
      final income = incomeTotal ?? 0.0;
      final balance = income - expense;
      final expenseAvgValue = expenseAvg ?? 0.0;
      final incomeAvgValue = incomeAvg ?? 0.0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (showIncome)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(l10n.analyticsTotalIncome,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: grey)),
                          Text(income.toStringAsFixed(2),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: incomeColor ?? Colors.green, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(l10n.analyticsAvgIncome(avgLabel),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: grey)),
                          Text(incomeAvgValue.toStringAsFixed(2),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: grey)),
                        ],
                      ),
                    ],
                  ),
                ),
              if (showExpense)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(l10n.analyticsTotalExpense,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: grey)),
                          Text(expense.toStringAsFixed(2),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: expenseColor ?? Colors.red, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(l10n.analyticsAvgExpense(avgLabel),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: grey)),
                          Text(expenseAvgValue.toStringAsFixed(2),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: grey)),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(l10n.analyticsBalance,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: grey)),
              Text(balance.toStringAsFixed(2),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                          color: balance >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          AppDivider.thin(),
        ],
      );
    } else {
      // 单一视角：原有逻辑
      final titleWord = isExpense ? l10n.analyticsExpense : l10n.analyticsIncome;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(l10n.analyticsTotal(titleWord),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: grey)),
              Text(total.toStringAsFixed(2),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: isExpense ? (expenseColor ?? Colors.red) : (incomeColor ?? Colors.green), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(l10n.analyticsAverage(avgLabel),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: grey)),
              Text(avg.toStringAsFixed(2),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: grey)),
            ],
          ),
          const SizedBox(height: 8),
          AppDivider.thin(),
        ],
      );
    }
  }
}