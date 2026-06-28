import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/utils/date_parser.dart';

/// DateParser 单测。
///
/// 解析口径(原则:**除非串里显式带 UTC 标记,否则一律按本地墙钟解析**):
/// - ISO 8601 路径走 `DateTime.parse(...).toLocal()`:带 Z/offset → 转本地保留
///   时刻;无时区 → 本地(isUtc=false);
/// - 中文日期路径走 `DateTime(...)` 构造 → 本地时区;
/// - 常见格式路径走 `DateFormat(fmt).parse(str)` → 本地时间(isUtc=false)。
///   这些格式都是无时区的裸墙钟,必须当本地;否则 CSV 导入会被当成 UTC 而 +8h
///   (历史 bug:单数字月份 `2026-6-25` 等过不了 DateTime.parse,曾被强标 UTC)。
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

  group('常见格式(无 UTC 标记 → 本地时间)', () {
    test('yyyy/MM/dd', () {
      final d = DateParser.parse('2024/11/05');
      expect(d.year, 2024);
      expect(d.month, 11);
      expect(d.day, 5);
      expect(d.isUtc, isFalse);
    });

    test('yyyy/MM/dd HH:mm — 分量原样,本地时区不偏移', () {
      final d = DateParser.parse('2024/08/29 23:16');
      expect(d.year, 2024);
      expect(d.month, 8);
      expect(d.day, 29);
      expect(d.hour, 23);
      expect(d.minute, 16);
      expect(d.isUtc, isFalse);
    });

    test('yyyy-MM-dd HH:mm:ss', () {
      final d = DateParser.parse('2024-08-29 23:16:05');
      expect(d.year, 2024);
      expect(d.day, 29);
      expect(d.hour, 23);
      expect(d.second, 5);
      expect(d.isUtc, isFalse);
    });
  });

  group('回归:无 UTC 标记一律本地,不产生 8h 偏移(CSV 导入)', () {
    test('单数字月份 2026-6-25 00:00 → 本地,且与零填充同一时刻', () {
      final single = DateParser.parse('2026-6-25 00:00');
      final padded = DateParser.parse('2026-06-25 00:00');
      expect(single.isUtc, isFalse);
      expect(single.year, 2026);
      expect(single.month, 6);
      expect(single.day, 25);
      expect(single.hour, 0);
      // 关键:两种写法必须解析成同一时刻(修复前差整 8 小时 = 480 分钟)
      expect(single.difference(padded), Duration.zero);
    });

    test('单数字月份月末晚间不跨月 2025-9-30 23:45', () {
      final d = DateParser.parse('2025-9-30 23:45');
      expect(d.isUtc, isFalse);
      expect(d.month, 9);
      expect(d.day, 30);
      expect(d.hour, 23);
      expect(d.minute, 45);
    });

    test('斜杠格式同样本地 2024/08/29 23:16', () {
      final d = DateParser.parse('2024/08/29 23:16');
      expect(d.isUtc, isFalse);
      expect(d.hour, 23);
    });
  });
}
