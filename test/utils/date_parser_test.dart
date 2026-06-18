import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/utils/date_parser.dart';

/// DateParser 单测。
///
/// 断言的是**当前线上实现**的行为(非某个理想化版本):
/// - ISO 8601 路径走 `DateTime.parse(...).toLocal()` → 结果为本地时区(isUtc=false);
/// - 中文日期路径走 `DateTime(...)` 构造 → 本地时区;
/// - 常见格式路径走 `DateFormat(fmt).parse(str, /*utc=*/true)` → 结果带 UTC 标记
///   (字面年月日时分原样保留,只是 isUtc=true)。这是 #314 在云端按客户端时区
///   换算后,App 侧保持的解析口径。
void main() {
  group('DateParser.parse — 空与兜底', () {
    final fallback = DateTime(2020, 1, 2, 3, 4, 5);

    test('null 返回 fallback', () {
      expect(DateParser.parse(null, fallback: fallback), fallback);
    });

    test('空白字符串返回 fallback', () {
      expect(DateParser.parse('   ', fallback: fallback), fallback);
    });

    test('无法识别的字符串返回 fallback', () {
      expect(DateParser.parse('not a date', fallback: fallback), fallback);
    });
  });

  group('DateParser.tryParse', () {
    test('null / 空 / 全空白 返回 null', () {
      expect(DateParser.tryParse(null), isNull);
      expect(DateParser.tryParse(''), isNull);
      expect(DateParser.tryParse('   '), isNull);
    });

    test('非空但无法解析的串:当前实现回落到 now()(非 null)', () {
      // 已知遗留:tryParse 文档称"失败返回 null",但它委托给
      // parse(fallback: null),而 parse 解析失败时 `return fallback ?? DateTime.now()`
      // → 返回 now()。只有 null/空白在 tryParse 入口被拦下返回 null。
      // 此用例锁定**当前真实行为**;若日后修正为"失败即 null",改这里。
      expect(DateParser.tryParse('not a date'), isNotNull);
    });
  });

  group('ISO 8601(本地时区)', () {
    test('纯日期', () {
      final d = DateParser.parse('2024-11-05');
      expect(d.year, 2024);
      expect(d.month, 11);
      expect(d.day, 5);
      expect(d.isUtc, isFalse);
    });

    test('带时间', () {
      final d = DateParser.parse('2024-11-05T23:16:00');
      expect(d.year, 2024);
      expect(d.month, 11);
      expect(d.day, 5);
      expect(d.hour, 23);
      expect(d.minute, 16);
      expect(d.isUtc, isFalse);
    });
  });

  group('中文日期(本地时区)', () {
    test('年月日', () {
      final d = DateParser.parse('2024年11月5日');
      expect(d, DateTime(2024, 11, 5));
    });

    test('年月日 时:分', () {
      final d = DateParser.parse('2024年11月5日 12:30');
      expect(d, DateTime(2024, 11, 5, 12, 30));
    });

    test('年月日 时:分:秒(零填充)', () {
      final d = DateParser.parse('2024年11月05日 12:30:45');
      expect(d, DateTime(2024, 11, 5, 12, 30, 45));
    });
  });

  group('常见格式(字面分量保留,带 UTC 标记)', () {
    test('yyyy/MM/dd', () {
      final d = DateParser.parse('2024/11/05');
      expect(d.year, 2024);
      expect(d.month, 11);
      expect(d.day, 5);
      expect(d.isUtc, isTrue);
    });

    test('yyyy/MM/dd HH:mm — 分量原样,不做时区偏移', () {
      final d = DateParser.parse('2024/08/29 23:16');
      expect(d.year, 2024);
      expect(d.month, 8);
      expect(d.day, 29);
      expect(d.hour, 23);
      expect(d.minute, 16);
      expect(d.isUtc, isTrue);
    });

    test('yyyy-MM-dd HH:mm:ss', () {
      final d = DateParser.parse('2024-08-29 23:16:05');
      expect(d.year, 2024);
      expect(d.day, 29);
      expect(d.hour, 23);
      expect(d.second, 5);
    });
  });
}
