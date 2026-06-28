import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/utils/analytics_average.dart';

/// 洞察页"日均/月均/年均"求值口径(issue 修复)。
///
/// 口径:分母用**已发生的单位数**(零值单位也计入),不是"有记账的单位数"。
/// 调用方传入的序列已按时间范围裁到"已发生"区间(当前周期到今天/当前月/当前年),
/// 本函数直接对全长取平均。
void main() {
  group('computeSeriesAverage — 按已发生单位数平均(含零值单位)', () {
    test('按天:零消费的天也计入分母(核心回归)', () {
      final series = <({DateTime day, double total})>[
        (day: DateTime(2026, 6, 1), total: 100),
        (day: DateTime(2026, 6, 2), total: 0),
        (day: DateTime(2026, 6, 3), total: 0),
        (day: DateTime(2026, 6, 4), total: 0),
        (day: DateTime(2026, 6, 5), total: 0),
      ];
      // 5 天已发生、仅 1 天有记账:应为 100/5=20,而非旧口径 100/1=100
      expect(computeSeriesAverage(series), 20);
    });

    test('按天:空序列返回 0', () {
      expect(computeSeriesAverage(<({DateTime day, double total})>[]), 0);
    });

    test('按天:全零序列返回 0(0/2)', () {
      final series = <({DateTime day, double total})>[
        (day: DateTime(2026, 6, 1), total: 0),
        (day: DateTime(2026, 6, 2), total: 0),
      ];
      expect(computeSeriesAverage(series), 0);
    });

    test('按月:除以月数(空月计入)', () {
      final series = <({DateTime month, double total})>[
        (month: DateTime(2026, 1, 1), total: 300),
        (month: DateTime(2026, 2, 1), total: 0),
        (month: DateTime(2026, 3, 1), total: 0),
      ];
      expect(computeSeriesAverage(series), 100); // 300/3,非 300/1
    });

    test('按年:除以年份跨度(空年计入)', () {
      final series = <({int year, double total})>[
        (year: 2024, total: 1200),
        (year: 2025, total: 0),
        (year: 2026, total: 0),
      ];
      expect(computeSeriesAverage(series), 400); // 1200/3,非 1200/1
    });

    test('结余口径:净额可为负(净额/已发生天数)', () {
      final series = <({DateTime day, double total})>[
        (day: DateTime(2026, 6, 1), total: -60),
        (day: DateTime(2026, 6, 2), total: 0),
      ];
      expect(computeSeriesAverage(series), -30); // -60/2
    });

    test('未知形状返回 0', () {
      expect(computeSeriesAverage(<int>[1, 2, 3]), 0);
    });
  });
}
