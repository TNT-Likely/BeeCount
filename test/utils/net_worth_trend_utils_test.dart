import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/utils/net_worth_trend_utils.dart';

/// 构造一条每日序列条目(net 用作可辨识的标记值)。
({DateTime date, double assets, double liabilities, double net}) _pt(
  DateTime date, {
  double assets = 0,
  double liabilities = 0,
  double net = 0,
}) =>
    (date: date, assets: assets, liabilities: liabilities, net: net);

void main() {
  group('downsampleMonthly', () {
    test('单/双位数月混排:按月末值聚合且排序正确(2025-1 在 2025-10 之前)', () {
      // 入参按日期升序(序列原始约定),含 1 月与 10 月,验证排序不按字符串。
      final daily = [
        _pt(DateTime(2025, 1, 15), net: 100),
        _pt(DateTime(2025, 1, 31), net: 110), // 1 月末值
        _pt(DateTime(2025, 2, 28), net: 200),
        _pt(DateTime(2025, 10, 31), net: 1000),
      ];

      final result = downsampleMonthly(daily);

      // 每月一个点:1 / 2 / 10 月。
      expect(result.length, 3);
      // 排序按真实日期,1 月在 10 月前(字符串 "2025-10" < "2025-1" 的话会排错)。
      expect(result.map((e) => e.date.month).toList(), [1, 2, 10]);
      // 1 月取月末值 110(非 15 日的 100)。
      expect(result.first.net, 110);
      // 10 月值。
      expect(result.last.net, 1000);
    });

    test('跨年:2024-12 排在 2025-01 之前', () {
      final daily = [
        _pt(DateTime(2024, 12, 31), net: 500),
        _pt(DateTime(2025, 1, 31), net: 600),
      ];

      final result = downsampleMonthly(daily);

      expect(result.length, 2);
      expect(result[0].date.year, 2024);
      expect(result[0].date.month, 12);
      expect(result[1].date.year, 2025);
      expect(result[1].date.month, 1);
      expect(result[0].net, 500);
      expect(result[1].net, 600);
    });

    test('同月多日:取最后一日的值(月末值)', () {
      final daily = [
        _pt(DateTime(2025, 3, 1), net: 10, assets: 1),
        _pt(DateTime(2025, 3, 15), net: 20, assets: 2),
        _pt(DateTime(2025, 3, 31), net: 30, assets: 3), // 最后一日 → 胜出
      ];

      final result = downsampleMonthly(daily);

      expect(result.length, 1);
      expect(result.single.net, 30);
      expect(result.single.assets, 3);
      expect(result.single.date.day, 31);
    });
  });
}
