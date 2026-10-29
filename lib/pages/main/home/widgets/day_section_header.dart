import 'package:flutter/material.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/theme_providers.dart';
import '../../../../utils/format_money.dart';

class DaySectionHeader extends ConsumerWidget {
  final String dateText; // yyyy-MM-dd
  final double income;
  final double expense;
  final bool flatSurface;
  final bool? hide; // 改为可选,null时使用全局状态
  const DaySectionHeader(
      {super.key,
      required this.dateText,
      required this.income,
      required this.expense,
      this.hide,
      this.flatSurface = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String getWeekday(String yyyyMMdd) {
      try {
        final dt = DateTime.parse(yyyyMMdd);
        final l10n = AppLocalizations.of(context);
        switch (dt.weekday) {
          case DateTime.monday:
            return l10n.commonWeekdayMonday;
          case DateTime.tuesday:
            return l10n.commonWeekdayTuesday;
          case DateTime.wednesday:
            return l10n.commonWeekdayWednesday;
          case DateTime.thursday:
            return l10n.commonWeekdayThursday;
          case DateTime.friday:
            return l10n.commonWeekdayFriday;
          case DateTime.saturday:
            return l10n.commonWeekdaySaturday;
          case DateTime.sunday:
            return l10n.commonWeekdaySunday;
          default:
            return '';
        }
      } catch (_) {
        return '';
      }
    }

    // 优先使用传入的hide,否则使用全局状态
    final shouldHide = hide ?? ref.watch(hideAmountsProvider);
    String fmt(double v) => v == 0 ? '' : formatMoneyCompact(v, maxDecimals: 2);
    final week = getWeekday(dateText);
    final l10n = AppLocalizations.of(context);
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: flatSurface ? 0 : 21),
        child: BeeTransactionDayHeader(title: week, date: dateText, totals: [
          if (shouldHide == false && fmt(expense).isNotEmpty)
            '${l10n.homeExpense} ${fmt(expense)}',
          if (shouldHide == false && fmt(income).isNotEmpty)
            '${l10n.homeIncome} ${fmt(income)}',
        ]));
  }
}
