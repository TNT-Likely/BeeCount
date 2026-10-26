import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/calendar/calendar_page.dart';
import '../../../providers.dart';
import '../../../providers/calendar_providers.dart';
import 'calendar_month_view.dart';

class LiveCalendarPreview extends ConsumerWidget {
  const LiveCalendarPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now(),
        month = DateTime(DateTime.now().year, DateTime.now().month),
        ledgerId = ref.watch(currentLedgerIdProvider),
        l = AppLocalizations.of(context);
    final totals = ref
        .watch(dailyTotalsByMonthProvider((ledgerId: ledgerId, month: month)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('真实日历汇总（只读）'),
      const SizedBox(height: 8),
      Text(DateFormat.yMMMM(Localizations.localeOf(context).toString())
          .format(month)),
      const SizedBox(height: 8),
      totals.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => Text(l.commonError),
          data: (values) {
            final keys = values.keys.toList()..sort();
            final visible = keys.reversed.take(3).toList();
            if (visible.isEmpty) {
              return BeeEmptyState(title: l.calendarNoTransactions);
            }
            return SizedBox(
                height: 90,
                child: Row(children: [
                  for (final key in visible)
                    Expanded(
                        child: BeeCalendarDayCell(
                            day: '${DateTime.parse(key).day}',
                            semanticLabel:
                                '$key +${values[key]!.$1.toStringAsFixed(2)} -${values[key]!.$2.toStringAsFixed(2)}',
                            expense: values[key]!.$2 > 0
                                ? calendarCompactAmount(values[key]!.$2, '-')
                                : null,
                            income: values[key]!.$1 > 0
                                ? calendarCompactAmount(values[key]!.$1, '+')
                                : null,
                            expenseColor: beeTransactionColor(
                                context, BeeTransactionKind.expense,
                                incomeIsRed: ref
                                    .watch(incomeExpenseColorSchemeProvider)),
                            incomeColor: beeTransactionColor(
                                context, BeeTransactionKind.income,
                                incomeIsRed: ref
                                    .watch(incomeExpenseColorSchemeProvider)),
                            today: key == calendarDateKey(now)))
                ]));
          }),
      const SizedBox(height: 12),
      BeeButton(
          label: '打开真实账单日历',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => const CalendarPage())))
    ]);
  }
}
