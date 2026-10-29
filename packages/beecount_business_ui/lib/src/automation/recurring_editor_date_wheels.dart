import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Bounded draft wheels preserve the original full DateTime clamp on confirm.
class BeeRecurringEditorDateWheels extends StatefulWidget {
  const BeeRecurringEditorDateWheels(
      {super.key,
      required this.value,
      required this.minDate,
      required this.maxDate,
      required this.onChanged});
  final DateTime value, minDate, maxDate;
  final ValueChanged<DateTime> onChanged;
  @override
  State<BeeRecurringEditorDateWheels> createState() =>
      _BeeRecurringEditorDateWheelsState();
}

class _BeeRecurringEditorDateWheelsState
    extends State<BeeRecurringEditorDateWheels> {
  late DateTime value = widget.value;
  void change({int? year, int? month, int? day}) {
    final y = year ?? value.year;
    final minMonth = y == widget.minDate.year ? widget.minDate.month : 1;
    final maxMonth = y == widget.maxDate.year ? widget.maxDate.month : 12;
    final m = (month ?? value.month).clamp(minMonth, maxMonth);
    final minDay = y == widget.minDate.year && m == widget.minDate.month
        ? widget.minDate.day
        : 1;
    final maxDay = y == widget.maxDate.year && m == widget.maxDate.month
        ? widget.maxDate.day
        : DateUtils.getDaysInMonth(y, m);
    final d = (day ?? value.day).clamp(minDay, maxDay);
    setState(() => value = DateTime(y, m, d));
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final min = widget.minDate, max = widget.maxDate;
    final minMonth = value.year == min.year ? min.month : 1,
        maxMonth = value.year == max.year ? max.month : 12;
    final minDay =
        value.year == min.year && value.month == min.month ? min.day : 1;
    final maxDay = value.year == max.year && value.month == max.month
        ? max.day
        : DateUtils.getDaysInMonth(value.year, value.month);
    return Row(children: [
      Expanded(
          flex: 3,
          child: BeeWheel<int>(
              values:
                  List.generate(max.year - min.year + 1, (i) => min.year + i),
              value: value.year,
              label: (i) => '$i',
              onChanged: (v) => change(year: v))),
      Expanded(
          flex: 2,
          child: BeeWheel<int>(
              values:
                  List.generate(maxMonth - minMonth + 1, (i) => minMonth + i),
              value: value.month,
              label: (i) => '$i',
              onChanged: (v) => change(month: v))),
      Expanded(
          flex: 2,
          child: BeeWheel<int>(
              values: List.generate(maxDay - minDay + 1, (i) => minDay + i),
              value: value.day,
              label: (i) => '$i',
              onChanged: (v) => change(day: v))),
    ]);
  }
}
