import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum WheelDatePickerMode { y, ym, ymd }

class WheelDatePicker extends StatefulWidget {
  final DateTime initial;
  final WheelDatePickerMode mode;
  const WheelDatePicker(
      {super.key, required this.initial, this.mode = WheelDatePickerMode.ymd});

  @override
  State<WheelDatePicker> createState() => _WheelDatePickerState();
}

class _WheelDatePickerState extends State<WheelDatePicker> {
  late int year;
  late int month;
  late int day;

  @override
  void initState() {
    super.initState();
    year = widget.initial.year;
    month = widget.initial.month;
    day = widget.initial.day;
  }

  List<int> _daysInMonth(int y, int m) {
    final last = DateTime(y, m + 1, 0).day;
    return List.generate(last, (i) => i + 1);
  }

  @override
  Widget build(BuildContext context) {
    final years = List.generate(201, (i) => 2000 + i);
    final months = List.generate(12, (i) => i + 1);
    final days = _daysInMonth(year, month);
    final mode = widget.mode;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消')),
                const Spacer(),
                const Text('选择日期'),
                const Spacer(),
                TextButton(
                    onPressed: () {
                      DateTime result;
                      switch (mode) {
                        case WheelDatePickerMode.y:
                          result = DateTime(year, 1, 1);
                          break;
                        case WheelDatePickerMode.ym:
                          result = DateTime(year, month, 1);
                          break;
                        case WheelDatePickerMode.ymd:
                          result = DateTime(year, month, day);
                          break;
                      }
                      Navigator.pop(context, result);
                    },
                    child: const Text('确定')),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                        initialItem: years.indexOf(year)),
                    onSelectedItemChanged: (i) => setState(() {
                      year = years[i];
                      if (day > _daysInMonth(year, month).last) {
                        day = _daysInMonth(year, month).last;
                      }
                    }),
                    children: [
                      for (final y in years) Center(child: Text('$y'))
                    ],
                  ),
                ),
                if (mode != WheelDatePickerMode.y)
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 32,
                      scrollController: FixedExtentScrollController(
                          initialItem: months.indexOf(month)),
                      onSelectedItemChanged: (i) => setState(() {
                        month = months[i];
                        if (day > _daysInMonth(year, month).last) {
                          day = _daysInMonth(year, month).last;
                        }
                      }),
                      children: [
                        for (final m in months) Center(child: Text('$m'))
                      ],
                    ),
                  ),
                if (mode == WheelDatePickerMode.ymd)
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 32,
                      scrollController: FixedExtentScrollController(
                          initialItem: days.indexOf(day)),
                      onSelectedItemChanged: (i) => setState(() {
                        day = _daysInMonth(year, month)[i];
                      }),
                      children: [
                        for (final d in days) Center(child: Text('$d'))
                      ],
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
