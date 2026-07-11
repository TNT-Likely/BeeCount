import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../styles/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/theme_providers.dart';
import 'format_money.dart';

class DaySectionHeader extends ConsumerWidget {
  final String dateText; // yyyy-MM-dd
  final double income;
  final double expense;
  final bool? hide; // 改为可选,null时使用全局状态
  const DaySectionHeader(
      {super.key,
      required this.dateText,
      required this.income,
      required this.expense,
      this.hide});

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
    final grey = BeeTokens.textSecondary(context);
    final week = getWeekday(dateText);
    final l10n = AppLocalizations.of(context);
    return Container(
      // 不设背景色:与交易行一样透明,显示同一外层列表背景。否则暗黑下 header
      // 是 surface 深灰(#1C1C1E)、交易行是纯黑 scaffold 底,两者不协调。
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: BeeDimens.listHeaderVertical),
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
            if (shouldHide == false && fmt(expense).isNotEmpty)
              Text('${l10n.homeExpense} ${fmt(expense)}',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: grey, fontSize: 12)),
            if (shouldHide == false && fmt(income).isNotEmpty) const SizedBox(width: 12),
            if (shouldHide == false && fmt(income).isNotEmpty)
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
