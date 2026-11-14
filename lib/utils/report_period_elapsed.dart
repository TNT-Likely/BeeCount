/// Read-only report denominators for the existing custom calendar periods.
library;

import 'month_range.dart';

/// Includes today when the period has started; ended periods use every day.
/// UTC calendar components avoid treating a DST day as 23 or 25 elapsed hours.
int elapsedReportDays(DateRange range, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final cutoff = today.isBefore(range.start)
      ? range.start
      : today.isBefore(range.end)
          ? DateTime(today.year, today.month, today.day + 1)
          : range.end;
  return DateTime.utc(cutoff.year, cutoff.month, cutoff.day)
      .difference(
          DateTime.utc(range.start.year, range.start.month, range.start.day))
      .inDays;
}

/// Counts started custom month periods, including the current partial month.
/// A completed custom year has 12; a year that has not started has zero.
int elapsedReportYearMonths(int year,
    {required int monthStartDay, required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final range = yearRangeFor(year, monthStartDay);
  if (today.isBefore(range.start)) return 0;
  if (!today.isBefore(range.end)) return 12;
  return labelForDate(today, monthStartDay).month;
}
