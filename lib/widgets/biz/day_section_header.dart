import 'package:flutter/material.dart';
import '../../styles/colors.dart';
import '../../styles/design.dart';
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
    String weekdayZh(String yyyyMMdd) {
      try {
        final dt = DateTime.parse(yyyyMMdd);
        const names = ['一', '二', '三', '四', '五', '六', '日'];
        return '星期${names[dt.weekday - 1]}';
      } catch (_) {
        return '';
      }
    }

    String fmt(double v) => v == 0 ? '' : formatMoneyCompact(v, maxDecimals: 2);
    final grey = BeeColors.black54;
    final week = weekdayZh(dateText);
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
              Text('支出 ${fmt(expense)}',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: grey, fontSize: 12)),
            if (!hide && fmt(income).isNotEmpty) const SizedBox(width: 12),
            if (!hide && fmt(income).isNotEmpty)
              Text('收入 ${fmt(income)}',
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
