import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum WheelDatePickerMode { y, ym, ymd }

class WheelDatePicker extends StatefulWidget {
  final DateTime initial;
  final WheelDatePickerMode mode;
  final DateTime? minDate;
  final DateTime? maxDate;
  const WheelDatePicker({
    super.key,
    required this.initial,
    this.mode = WheelDatePickerMode.ymd,
    this.minDate,
    this.maxDate,
  });

  @override
  State<WheelDatePicker> createState() => _WheelDatePickerState();
}

Future<DateTime?> showWheelDatePicker(
  BuildContext context, {
  required DateTime initial,
  WheelDatePickerMode mode = WheelDatePickerMode.ymd,
  DateTime? minDate,
  DateTime? maxDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => WheelDatePicker(
      initial: initial,
      mode: mode,
      minDate: minDate,
      maxDate: maxDate,
    ),
  );
}

class _WheelDatePickerState extends State<WheelDatePicker> {
  late int year;
  late int month;
  late int day;
  late FixedExtentScrollController _yearCtrl;
  FixedExtentScrollController? _monthCtrl;
  FixedExtentScrollController? _dayCtrl;

  @override
  void initState() {
    super.initState();
    final clamped = _clamp(widget.initial);
    year = clamped.year;
    month = clamped.month;
    day = clamped.day;
  // 初始化滚动控制器
  final years = [for (int y = _min.year; y <= _max.year; y++) y];
  _yearCtrl = FixedExtentScrollController(initialItem: years.indexOf(year));
  // month/day 控制器在 build 中根据当前 year/month 的有效范围惰性创建
  }

  DateTime get _min => widget.minDate ?? DateTime(2000, 1, 1);
  DateTime get _max => widget.maxDate ?? DateTime(2100, 12, 31);

  DateTime _clamp(DateTime d) {
    if (d.isBefore(_min)) return _min;
    if (d.isAfter(_max)) return _max;
    return d;
  }

  List<int> _daysInMonth(int y, int m) {
    final last = DateTime(y, m + 1, 0).day;
    return List.generate(last, (i) => i + 1);
  }

  @override
  Widget build(BuildContext context) {
    final min = _min;
    final max = _max;

    final years = [for (int y = min.year; y <= max.year; y++) y];
    int startMonth = 1, endMonth = 12;
    if (year == min.year) startMonth = min.month;
    if (year == max.year) endMonth = max.month;
    final months = [for (int m = startMonth; m <= endMonth; m++) m];

    int startDay = 1, endDay = _daysInMonth(year, month).last;
    if (year == min.year && month == min.month) startDay = min.day;
    if (year == max.year && month == max.month) endDay = max.day;
    final days = [for (int d = startDay; d <= endDay; d++) d];
    final mode = widget.mode;

  // 确保 month/day 控制器已创建并指向当前索引
  _monthCtrl ??= FixedExtentScrollController(initialItem: months.indexOf(month));
  final dayIndex = days.indexOf(day);
  _dayCtrl ??= FixedExtentScrollController(initialItem: dayIndex < 0 ? 0 : dayIndex);

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
                          result = _clamp(DateTime(year, 1, 1));
                          break;
                        case WheelDatePickerMode.ym:
                          result = _clamp(DateTime(year, month, 1));
                          break;
                        case WheelDatePickerMode.ymd:
                          result = _clamp(DateTime(year, month, day));
                          break;
                      }
                      Navigator.pop(context, result);
                    },
                    child: const Text('确定')),
              ],
            ),
          ),
          SizedBox(
            height: 120, // 每列显示3个 item，40*3
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 40,
                    scrollController: _yearCtrl,
                    onSelectedItemChanged: (i) => setState(() {
                      year = years[i];
                      // 调整月份与日期以符合边界
                      int sm = 1, em = 12;
                      if (year == min.year) sm = min.month;
                      if (year == max.year) em = max.month;
                      if (month < sm) month = sm;
                      if (month > em) month = em;
                      final dim = _daysInMonth(year, month).last;
                      int sd = 1, ed = dim;
                      if (year == min.year && month == min.month) sd = min.day;
                      if (year == max.year && month == max.month) ed = max.day;
                      if (day < sd) day = sd;
                      if (day > ed) day = ed;
                      // 同步月份/日期滚动位置
                      final monthsNow = [for (int m = sm; m <= em; m++) m];
                      final mi = monthsNow.indexOf(month);
                      if (_monthCtrl == null) {
                        _monthCtrl = FixedExtentScrollController(initialItem: mi);
                      } else {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _monthCtrl!.jumpToItem(mi);
                        });
                      }
                      final daysNow = [for (int d = sd; d <= ed; d++) d];
                      final di = daysNow.indexOf(day);
                      if (_dayCtrl == null) {
                        _dayCtrl = FixedExtentScrollController(initialItem: di < 0 ? 0 : di);
                      } else {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _dayCtrl!.jumpToItem(di < 0 ? 0 : di);
                        });
                      }
                    }),
                    children: [
                      for (final y in years)
                        Center(child: Text('$y', style: const TextStyle(fontSize: 16))),
                    ],
                  ),
                ),
                if (mode != WheelDatePickerMode.y)
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 40,
                      scrollController: _monthCtrl,
                      onSelectedItemChanged: (i) => setState(() {
                        month = months[i];
                        // 调整日期以符合边界
                        final dim = _daysInMonth(year, month).last;
                        int sd = 1, ed = dim;
                        if (year == min.year && month == min.month)
                          sd = min.day;
                        if (year == max.year && month == max.month)
                          ed = max.day;
                        if (day < sd) day = sd;
                        if (day > ed) day = ed;
                        // 同步日期滚动位置
                        final daysNow = [for (int d = sd; d <= ed; d++) d];
                        final di = daysNow.indexOf(day);
                        if (_dayCtrl == null) {
                          _dayCtrl = FixedExtentScrollController(initialItem: di < 0 ? 0 : di);
                        } else {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _dayCtrl!.jumpToItem(di < 0 ? 0 : di);
                          });
                        }
                      }),
                      children: [
                        for (final m in months)
                          Center(child: Text('$m', style: const TextStyle(fontSize: 16))),
                      ],
                    ),
                  ),
                if (mode == WheelDatePickerMode.ymd)
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 40,
                      scrollController: _dayCtrl,
                      onSelectedItemChanged: (i) => setState(() {
                        day = days[i];
                      }),
                      children: [
                        for (final d in days)
                          Center(child: Text('$d', style: const TextStyle(fontSize: 16))),
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
