import 'package:flutter/material.dart';
import '../../styles/colors.dart';
import '../../styles/design.dart';

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
    final primaryColor = Theme.of(context).colorScheme.primary;

    String avgLabel;
    switch (scope) {
      case 'year':
        avgLabel = '月均';
        break;
      case 'all':
        avgLabel = '平均值';
        break;
      case 'month':
      default:
        avgLabel = '日均';
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
                          Text('总收入： ',
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
                          Text('$avgLabel收入： ',
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
                          Text('总支出： ',
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
                          Text('$avgLabel支出： ',
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
              Text('结余： ',
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
      final titleWord = isExpense ? '支出' : '收入';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('总$titleWord： ',
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
              Text('$avgLabel： ',
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