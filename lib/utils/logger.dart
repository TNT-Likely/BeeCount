import 'package:flutter/foundation.dart';

enum LogLevel { info, warn, error }

String _ts() {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  String three(int n) => n.toString().padLeft(3, '0');
  return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.${three(now.millisecond)}';
}

void _log(LogLevel level, String tag, String msg) {
  final lv = switch (level) {
    LogLevel.info => 'I',
    LogLevel.warn => 'W',
    LogLevel.error => 'E',
  };
  debugPrint('[$lv ${_ts()}][$tag] $msg');
}

void logI(String tag, String msg) => _log(LogLevel.info, tag, msg);
void logW(String tag, String msg) => _log(LogLevel.warn, tag, msg);
void logE(String tag, String msg, [Object? err, StackTrace? st]) {
  _log(LogLevel.error, tag, msg);
  if (err != null) debugPrint('  error: $err');
  if (st != null) debugPrint('  stack: $st');
}
