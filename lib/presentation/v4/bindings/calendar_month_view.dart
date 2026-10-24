import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

String calendarDateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// Preserve the original integer/k/w labels; raw totals remain in semantics.
String calendarCompactAmount(double amount, String sign) => amount >= 10000
    ? '$sign${(amount / 10000).toStringAsFixed(1)}w'
    : amount >= 1000
        ? '$sign${(amount / 1000).toStringAsFixed(1)}k'
        : '$sign${amount.toInt()}';

class CalendarMonthView extends StatelessWidget {
  const CalendarMonthView(
      {super.key,
      required this.focusedMonth,
      required this.firstDay,
      required this.lastDay,
      required this.selectedDay,
      required this.totals,
      required this.onSelect,
      required this.onPage,
      required this.onMonth,
      required this.onJump,
      this.incomeColor,
      this.expenseColor,
      this.incomeLabel = '+',
      this.expenseLabel = '-'});
  final DateTime focusedMonth, firstDay, lastDay;
  final DateTime? selectedDay;
  final Map<String, (double, double)> totals;
  final void Function(DateTime, DateTime) onSelect;
  final ValueChanged<DateTime> onPage, onJump;
  final VoidCallback onMonth;
  final Color? incomeColor, expenseColor;
  final String incomeLabel, expenseLabel;
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final previous = DateTime(focusedMonth.year, focusedMonth.month - 1);
    final next = DateTime(focusedMonth.year, focusedMonth.month + 1);
    Widget cell(BuildContext context, DateTime day, DateTime month,
        {bool outside = false}) {
      final (income, expense) = totals[calendarDateKey(day)] ?? (0.0, 0.0);
      return BeeCalendarDayCell(
          day: '${day.day}',
          semanticLabel:
              '${DateFormat.yMd(locale).format(day)} +${income.toStringAsFixed(2)} -${expense.toStringAsFixed(2)}',
          expenseColor: expenseColor ??
              beeTransactionColor(context, BeeTransactionKind.expense),
          incomeColor: incomeColor ??
              beeTransactionColor(context, BeeTransactionKind.income),
          expense: expense > 0 ? calendarCompactAmount(expense, '-') : null,
          income: income > 0 ? calendarCompactAmount(income, '+') : null,
          selected: isSameDay(day, selectedDay),
          today: isSameDay(day, DateTime.now()),
          outside: outside);
    }

    final scaler = MediaQuery.textScalerOf(context);
    return BeeSurface(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
        child: Column(children: [
          BeeCalendarMonthHeading(
              title: DateFormat.yMMMM(locale).format(focusedMonth),
              previousLabel: DateFormat.yMMMM(locale).format(previous),
              nextLabel: DateFormat.yMMMM(locale).format(next),
              onMonth: onMonth,
              onPrevious:
                  previous.isBefore(DateTime(firstDay.year, firstDay.month))
                      ? null
                      : () => onJump(previous),
              onNext: next.isAfter(lastDay) ? null : () => onJump(next)),
          TableCalendar<void>(
              locale: locale,
              firstDay: firstDay,
              lastDay: lastDay,
              focusedDay: focusedMonth,
              headerVisible: false,
              pageAnimationEnabled: TickerMode.of(context) &&
                  !MediaQuery.disableAnimationsOf(context),
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarFormat: CalendarFormat.month,
              availableGestures: AvailableGestures.horizontalSwipe,
              selectedDayPredicate: (day) => isSameDay(day, selectedDay),
              onDaySelected: onSelect,
              onPageChanged: onPage,
              rowHeight: 64 * scaler.scale(1).clamp(1, 2),
              daysOfWeekHeight: 30 + (scaler.scale(12) - 12).clamp(0, 12),
              daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                      fontSize: 12, color: Theme.of(context).hintColor),
                  weekendStyle: TextStyle(
                      fontSize: 12, color: Theme.of(context).hintColor)),
              calendarBuilders: CalendarBuilders<void>(
                  markerBuilder: (context, day, events) {
                    final value = totals[calendarDateKey(day)];
                    if (value == null ||
                        day.month != focusedMonth.month ||
                        day.year != focusedMonth.year) {
                      return null;
                    }
                    return IgnorePointer(
                        child: Semantics(
                            label:
                                '${DateFormat.yMd(locale).format(day)} $incomeLabel ${value.$1.toStringAsFixed(2)} $expenseLabel ${value.$2.toStringAsFixed(2)}',
                            child: const SizedBox.expand()));
                  },
                  defaultBuilder: cell,
                  todayBuilder: cell,
                  selectedBuilder: cell,
                  outsideBuilder: (c, d, m) => cell(c, d, m, outside: true),
                  disabledBuilder: (c, d, m) => cell(c, d, m, outside: true)))
        ]));
  }
}
