import 'package:flutter/material.dart';
import '../../styles/colors.dart';
import '../../styles/design.dart';
import '../../l10n/app_localizations.dart';
import 'format_money.dart';

class DaySectionHeader extends StatelessWidget {
  final String dateText; // yyyy-MM-dd
  final double income;
  final double expense;
  final bool hide;
  const DaySectionHeader(
      {super.key,
      required this.dateText,
      required this.income,
      required this.expense,
      this.hide = false});

  @override
  Widget build(BuildContext context) {
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

    String fmt(double v) => v == 0 ? '' : formatMoneyCompact(v, maxDecimals: 2);
    final grey = BeeColors.black54;
    final week = getWeekday(dateText);
    final l10n = AppLocalizations.of(context);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: AppDimens.listHeaderVertical),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text(dateText,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: grey, fontSize: 12)),
            if (week.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(week,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: grey, fontSize: 12)),
            ]
          ]),
          Row(children: [
            if (!hide && fmt(expense).isNotEmpty)
              Text('${l10n.homeExpense} ${fmt(expense)}',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: grey, fontSize: 12)),
            if (!hide && fmt(income).isNotEmpty) const SizedBox(width: 12),
            if (!hide && fmt(income).isNotEmpty)
              Text('${l10n.homeIncome} ${fmt(income)}',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: grey, fontSize: 12)),
          ])
        ],
      ),
    );
  }
}
