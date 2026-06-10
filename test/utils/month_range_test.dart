import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/utils/month_range.dart';

void main() {
  group('periodForLabel', () {
    test('startDay=1 退化为自然月', () {
      final r = periodForLabel(2026, 6, 1);
      expect(r.start, DateTime(2026, 6, 1));
      expect(r.end, DateTime(2026, 7, 1));
    });
    test('startDay=10: 6月 = [6.10, 7.10)', () {
      final r = periodForLabel(2026, 6, 10);
      expect(r.start, DateTime(2026, 6, 10));
      expect(r.end, DateTime(2026, 7, 10));
    });
    test('12月跨年进位', () {
      final r = periodForLabel(2026, 12, 10);
      expect(r.end, DateTime(2027, 1, 10));
    });
    test('2月 startDay=28 不溢出', () {
      final r = periodForLabel(2026, 2, 28);
      expect(r.start, DateTime(2026, 2, 28));
      expect(r.end, DateTime(2026, 3, 28));
    });
  });

  group('labelForDate', () {
    test('日 >= startDay 归当月(含起始日当天)', () {
      expect(labelForDate(DateTime(2026, 6, 10), 10), DateTime(2026, 6, 1));
      expect(labelForDate(DateTime(2026, 6, 28), 10), DateTime(2026, 6, 1));
    });
    test('日 < startDay 归上月', () {
      expect(labelForDate(DateTime(2026, 6, 9), 10), DateTime(2026, 5, 1));
    });
    test('1月初借位到上年12月', () {
      expect(labelForDate(DateTime(2026, 1, 5), 10), DateTime(2025, 12, 1));
    });
    test('startDay=1 恒归当月', () {
      expect(labelForDate(DateTime(2026, 1, 1), 1), DateTime(2026, 1, 1));
    });
  });

  group('periodContaining', () {
    test('任意日期落在自己的周期内(连续 70 天无缝)', () {
      const sd = 15;
      for (int offset = 0; offset < 70; offset++) {
        final date = DateTime(2026, 5, 1).add(Duration(days: offset));
        final r = periodContaining(date, sd);
        expect(!date.isBefore(r.start) && date.isBefore(r.end), isTrue,
            reason: '$date 应落在 [${r.start}, ${r.end})');
      }
    });
    test('startDay=28 跨 2 月无缝(最难边界)', () {
      const sd = 28;
      for (int offset = 0; offset < 70; offset++) {
        final date = DateTime(2026, 2, 1).add(Duration(days: offset));
        final r = periodContaining(date, sd);
        expect(!date.isBefore(r.start) && date.isBefore(r.end), isTrue,
            reason: '$date 应落在 [${r.start}, ${r.end})');
      }
    });
  });

  group('yearRangeFor', () {
    test('年 = [当年1月周期起点, 次年1月周期起点)', () {
      final r = yearRangeFor(2026, 10);
      expect(r.start, DateTime(2026, 1, 10));
      expect(r.end, DateTime(2027, 1, 10));
    });
  });

  group('periodRangeText', () {
    test('自然月返回 null', () {
      expect(periodRangeText(2026, 6, 1), isNull);
    });
    test('展示首尾(含端): 6.10-7.9', () {
      expect(periodRangeText(2026, 6, 10), '6.10-7.9');
    });
    test('12月跨年展示: 12.10-1.9', () {
      expect(periodRangeText(2026, 12, 10), '12.10-1.9');
    });
  });
}
