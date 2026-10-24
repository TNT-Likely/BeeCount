import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../widgets/ui/wheel_date_picker.dart';
import '../bindings/calendar_month_view.dart';

class CalendarSample extends StatefulWidget {
  const CalendarSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<CalendarSample> createState() => _CalendarSampleState();
}

class _CalendarSampleState extends State<CalendarSample> {
  DateTime month = DateTime(2026, 10);
  DateTime? selected = DateTime(2026, 10, 20);
  String event = '仅修改示例日期草稿';
  void jump(DateTime value) => setState(() {
        month = DateTime(value.year, value.month);
        selected = null;
      });
  Future<void> picker() async {
    final value = await showWheelDatePicker(context,
        initial: month,
        mode: WheelDatePickerMode.ym,
        minDate: DateTime(2000),
        maxDate: DateTime(2027, 10, 20));
    if (value != null && mounted) jump(value);
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CalendarMonthView(
            focusedMonth: month,
            firstDay: DateTime(2000),
            lastDay: DateTime(2027, 10, 20),
            selectedDay: selected,
            totals: {'2026-10-20': (12000.0, 208.4), '2026-10-15': (0.0, 32.0)},
            onSelect: (day, _) => setState(() => selected = day),
            onPage: jump,
            onJump: jump,
            onMonth: picker),
        const SizedBox(height: 12),
        if (selected != null)
          BeeCalendarDayHeading(
              title: '${selected!.month}.${selected!.day}',
              weekday: '示例日期',
              addLabel: '在该日记账',
              onAdd: () => setState(
                  () => event = '新账单初始日期 ${calendarDateKey(selected!)} 12:00')),
        const SizedBox(height: 8),
        Text(event),
        const SizedBox(height: 16),
        const BeeSurface(child: BeeEmptyState(title: '当天无交易')),
        const SizedBox(height: 16),
        widget.liveData ?? const Text('App内读取原日历仓库；正式入口执行记账，不从样例直接写入。')
      ]);
}
