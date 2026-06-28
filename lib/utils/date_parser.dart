import 'package:intl/intl.dart';

/// 日期解析工具类
/// 支持多种常见日期格式的自动解析
class DateParser {
  DateParser._();

  /// 尝试解析日期字符串，支持多种格式
  ///
  /// 支持的格式包括：
  /// - ISO 8601: 2024-11-05, 2024-11-05T12:30:45
  /// - 中文格式: 2024年11月5日, 2024年11月05日 12:30:45
  /// - 常见格式: 2024/11/05, 2024-11-05 12:30:45
  ///
  /// [dateStr] 待解析的日期字符串
  /// [fallback] 解析失败时返回的默认值，默认为当前时间
  ///
  /// 返回解析后的 DateTime 对象
  static DateTime parse(String? dateStr, {DateTime? fallback}) {
    if (dateStr == null || dateStr.trim().isEmpty) {
      return fallback ?? DateTime.now();
    }

    // 1. 尝试标准 ISO 8601 格式
    DateTime? result = _tryParseIso(dateStr);
    if (result != null) return result.toLocal();

    // 2. 尝试中文日期格式
    result = _tryParseChineseDate(dateStr);
    if (result != null) return result;

    // 3. 尝试常见日期格式
    result = _tryParseCommonFormats(dateStr);
    if (result != null) return result;

    // 4. 所有格式都失败，返回默认值
    return fallback ?? DateTime.now();
  }

  /// 尝试解析 ISO 8601 标准格式
  static DateTime? _tryParseIso(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  /// 尝试解析中文日期格式
  ///
  /// 支持格式：
  /// - 2024年11月5日
  /// - 2024年11月05日
  /// - 2024年11月5日 12:30
  /// - 2024年11月5日 12:30:45
  static DateTime? _tryParseChineseDate(String dateStr) {
    final trimmed = dateStr.trim();

    // 匹配 "YYYY年MM月DD日 [HH:mm[:ss]]" 格式
    final regex = RegExp(
      r'(\d{4})年(\d{1,2})月(\d{1,2})日(?:\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?'
    );

    final match = regex.firstMatch(trimmed);
    if (match == null) return null;

    try {
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      final hour = match.group(4) != null ? int.parse(match.group(4)!) : 0;
      final minute = match.group(5) != null ? int.parse(match.group(5)!) : 0;
      final second = match.group(6) != null ? int.parse(match.group(6)!) : 0;

      return DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      return null;
    }
  }

  /// 尝试使用常见日期格式解析。
  ///
  /// 这些格式都是**无时区信息的裸墙钟时间**(斜杠分隔、单数字月份、MM/dd/yyyy 等,
  /// 过不了 DateTime.parse),按口径一律解析为**本地时间**(`parse` 默认 utc=false)。
  /// 切勿用 `parse(str, /*utc=*/true)` 强标 UTC —— 那会让 CSV 导入的本地时间在
  /// 本地(如 UTC+8)展示时整体 +8 小时(历史 bug)。
  static DateTime? _tryParseCommonFormats(String dateStr) {
    final formats = [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy/MM/dd HH:mm:ss',
      'yyyy/MM/dd HH:mm',
      'yyyy-MM-dd',
      'yyyy/M/d',
      'yyyy/MM/dd',
      'MM/dd/yyyy HH:mm:ss',
      'MM/dd/yyyy HH:mm',
      'MM/dd/yyyy',
      'dd-MM-yyyy HH:mm:ss',
      'dd-MM-yyyy HH:mm',
      'dd-MM-yyyy',
      'dd/MM/yyyy',
    ];

    for (final format in formats) {
      try {
        // utc=false(默认):按本地墙钟解析,不做时区偏移。
        return DateFormat(format).parse(dateStr);
      } catch (_) {
        // 继续尝试下一个格式
      }
    }

    return null;
  }

  /// 尝试解析日期字符串，失败时返回 null
  ///
  /// 与 [parse] 方法的区别是：解析失败时返回 null 而不是当前时间
  static DateTime? tryParse(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) {
      return null;
    }

    return parse(dateStr, fallback: null);
  }
}
