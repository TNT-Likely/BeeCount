/// 自定义月度周期工具(账本级 monthStartDay,1-28)。
///
/// 约定(见 .docs/period-start-date/design.md):
/// - 全库统一半开区间 [start, end)
/// - 周期按「起始月」命名:startDay=10 时「2026年6月」= 2026-06-10 ~ 2026-07-10
/// - startDay=1 全部退化为自然月,单代码路径
///
/// ⚠️ 两个语义不可混用(D11):
/// - [periodForLabel]:标签 (year, month) → 范围。统计/图表用。
/// - [labelForDate]:日期 → 它所属周期的标签。「今天是几月」「滚动定位」用。
/// 把 DateTime(y, m, 1) 当日期喂给 containing 类逻辑会整体偏移一个周期。
library;

typedef DateRange = ({DateTime start, DateTime end});

int _clampDay(int startDay) => startDay < 1 ? 1 : (startDay > 28 ? 28 : startDay);

/// 标签 (year, month) 对应的周期范围:[y-m-startDay, y-(m+1)-startDay)。
DateRange periodForLabel(int year, int month, int startDay) {
  final d = _clampDay(startDay);
  return (
    start: DateTime(year, month, d),
    end: DateTime(year, month + 1, d), // Dart 自动进位:13月 → 次年1月
  );
}

/// [date] 所属周期的「标签月」,返回 DateTime(y, m, 1)(仅作 key / 显示)。
/// 规则:date.day >= startDay 归当月,否则归上月。
/// [date] 必须是本地时间 DateTime;传 UTC 会在临近零点时错一天。
DateTime labelForDate(DateTime date, int startDay) {
  final d = _clampDay(startDay);
  if (date.day >= d) return DateTime(date.year, date.month, 1);
  return DateTime(date.year, date.month - 1, 1); // 0月 → 上年12月,Dart 自动借位
}

/// [date] 所在周期的范围,= periodForLabel(labelForDate(date))。预算「当前周期」用。
/// [date] 必须是本地时间(同 labelForDate)。
DateRange periodContaining(DateTime date, int startDay) {
  final label = labelForDate(date, startDay);
  return periodForLabel(label.year, label.month, startDay);
}

/// 「year 年」= [当年1月周期起点, 次年1月周期起点),恰 12 个完整周期(D4)。
DateRange yearRangeFor(int year, int startDay) {
  final d = _clampDay(startDay);
  return (start: DateTime(year, 1, d), end: DateTime(year + 1, 1, d));
}

/// UI 周期范围短文案,如 "6.10-7.9"(含端展示);startDay=1 返回 null(自然月不标注)。
String? periodRangeText(int year, int month, int startDay) {
  if (_clampDay(startDay) == 1) return null;
  final r = periodForLabel(year, month, startDay);
  // 日历日减一(非 Duration:有 DST 的时区减 86400s 可能落到前一天 23:00)
  final e = r.end;
  final endIncl = DateTime(e.year, e.month, e.day - 1);
  return '${r.start.month}.${r.start.day}-${endIncl.month}.${endIncl.day}';
}
