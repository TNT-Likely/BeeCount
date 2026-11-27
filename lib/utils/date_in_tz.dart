import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 锁账业务日期所用时区,固定 Asia/Shanghai(见 S1-01a §1.4)。
/// 业务日期是"用户看到的日历日",不是 UTC 日,因此不能拿 UTC 时间戳直接截取。
const String kLockPeriodTimeZone = 'Asia/Shanghai';

bool _tzInitialized = false;

tz.Location _location() {
  if (!_tzInitialized) {
    tzdata.initializeTimeZones();
    _tzInitialized = true;
  }
  return tz.getLocation(kLockPeriodTimeZone);
}

/// 当前时刻按 Asia/Shanghai 落到的业务日期,`YYYY-MM-DD`。
String businessDateInShanghai([DateTime? at]) {
  final utc = (at ?? DateTime.now()).toUtc();
  final local = tz.TZDateTime.from(utc, _location());
  return _formatDate(local.year, local.month, local.day);
}

String _formatDate(int year, int month, int day) =>
    '${year.toString().padLeft(4, '0')}-'
    '${month.toString().padLeft(2, '0')}-'
    '${day.toString().padLeft(2, '0')}';

/// 业务日期比较(两端都是 `YYYY-MM-DD` 字符串,字典序即时间序)。
/// [effectiveLockLine] 为空表示无锁账,一切日期都不锁。
bool isBusinessDateAtOrBefore(String date, String effectiveLockLine) =>
    effectiveLockLine.isNotEmpty && date.compareTo(effectiveLockLine) <= 0;

/// 本地写库用的 UTC ISO8601 字符串(App 侧 locked_at 口径)。
String utcIsoNow() => DateTime.now().toUtc().toIso8601String();

/// **唯一**的 UTC ISO8601 解析器,apply / import / hydration 三条路径共用。
///
/// App 侧 locked_at 是 Text,Cloud 侧是 `DateTime(timezone=True)`;传输统一
/// UTC ISO8601 字符串。Parser 必须吃下三种格式:
///   - `...Z`
///   - `...+08:00` / `...-05:00`(也兼容 `+0800`)
///   - 无时区后缀 → **按 UTC** 处理(Dart 的 DateTime.parse 会当本地时间,
///     必须显式补 Z 才能保证跨设备排序/LWW 比的是同一时刻)
/// 归一化到 `DateTime.utc().toIso8601String()`。
DateTime? parseUtcIso8601(dynamic value) {
  if (value is DateTime) return value.toUtc();
  if (value is! String) return null;
  var text = value.trim();
  if (text.isEmpty) return null;

  // 容忍空格分隔的 ISO 串(`2026-11-27 12:00:00`)。
  if (RegExp(r'^\d{4}-\d{2}-\d{2} ').hasMatch(text)) {
    text = text.replaceFirst(' ', 'T');
  }
  final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false)
      .hasMatch(text);
  if (!hasZone) {
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      text = '${text}T00:00:00';
    }
    text = '${text}Z';
  }
  return DateTime.tryParse(text)?.toUtc();
}

/// 同上,但返回归一化后的 UTC ISO8601 字符串;无法解析时返回 null。
String? normalizeUtcIso8601(dynamic value) =>
    parseUtcIso8601(value)?.toIso8601String();
