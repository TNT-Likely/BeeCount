import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 日志级别
enum LogLevel {
  debug,
  info,
  warning,
  error;

  String get displayName {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  String get emoji {
    switch (this) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
    }
  }
}

/// 日志来源平台
enum LogPlatform {
  flutter,
  android,
  ios;

  String get displayName {
    switch (this) {
      case LogPlatform.flutter:
        return 'Flutter';
      case LogPlatform.android:
        return 'Android';
      case LogPlatform.ios:
        return 'iOS';
    }
  }
}

/// 日志条目
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final LogPlatform platform;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.platform,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'level': level.index,
      'platform': platform.index,
      'tag': tag,
      'message': message,
      'error': error?.toString(),
      'stackTrace': stackTrace?.toString(),
    };
  }

  /// 从 JSON 反序列化
  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      level: LogLevel.values[json['level'] as int],
      platform: LogPlatform.values[json['platform'] as int],
      tag: json['tag'] as String,
      message: json['message'] as String,
      error: json['error'],
      stackTrace: json['stackTrace'] != null
          ? StackTrace.fromString(json['stackTrace'] as String)
          : null,
    );
  }

  /// 格式化为文本
  String toFormattedString() {
    final buffer = StringBuffer();

    // 时间戳
    final time = '${_twoDigits(timestamp.hour)}:'
        '${_twoDigits(timestamp.minute)}:'
        '${_twoDigits(timestamp.second)}.'
        '${_threeDigits(timestamp.millisecond)}';

    buffer.write('[$time] ');
    buffer.write('[${level.displayName}] ');
    buffer.write('[${platform.displayName}] ');
    buffer.write('[$tag] ');
    buffer.writeln(message);

    if (error != null) {
      buffer.writeln('  Error: $error');
    }

    if (stackTrace != null) {
      buffer.writeln('  Stack Trace:');
      buffer.writeln('  ${stackTrace.toString().replaceAll('\n', '\n  ')}');
    }

    return buffer.toString();
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
  static String _threeDigits(int n) => n.toString().padLeft(3, '0');
}

/// 日志服务
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal() {
    _setupNativeBridge();
  }

  static const _channel = MethodChannel('com.beecount.logger');
  static const _storageKey = 'app_logs';
  static const _maxStorageHours = 48; // 保留48小时

  // 使用循环缓冲区存储日志，最多保留最近的 2000 条
  static const int _maxLogs = 2000;
  final _logs = Queue<LogEntry>();

  // 日志监听器
  final _listeners = <VoidCallback>[];

  bool _isLoaded = false;
  Timer? _saveTimer;
  bool _isSaving = false;

  /// 获取所有日志（自动加载持久化的日志）
  List<LogEntry> get logs {
    if (!_isLoaded) {
      _loadLogs();
    }
    return _logs.toList();
  }

  /// 添加监听器
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// 移除监听器
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// 通知监听器
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// 添加日志
  void _addLog(LogEntry entry) {
    // 确保已加载
    if (!_isLoaded) {
      _loadLogs();
    }

    // 循环缓冲：如果超过最大数量，移除最旧的
    if (_logs.length >= _maxLogs) {
      _logs.removeFirst();
    }

    _logs.add(entry);

    // 同时打印到控制台（开发模式）
    if (kDebugMode) {
      debugPrint(entry.toFormattedString());
    }

    // 通知监听器
    _notifyListeners();

    // 异步保存到持久化存储
    _saveLogs();
  }

  /// 加载持久化的日志
  void _loadLogs() {
    if (_isLoaded) return;

    try {
      SharedPreferences.getInstance().then((prefs) {
        final jsonStr = prefs.getString(_storageKey);
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(jsonStr);
          final now = DateTime.now();

          // 过滤掉超过48小时的日志
          for (final json in jsonList) {
            try {
              final entry = LogEntry.fromJson(json as Map<String, dynamic>);
              final age = now.difference(entry.timestamp);

              if (age.inHours < _maxStorageHours) {
                _logs.add(entry);
              }
            } catch (e) {
              debugPrint('加载日志条目失败: $e');
            }
          }

          debugPrint('从持久化存储加载了 ${_logs.length} 条日志');
        }
      });
    } catch (e) {
      debugPrint('加载日志失败: $e');
    } finally {
      _isLoaded = true;
    }
  }

  /// 保存日志到持久化存储（节流：最多每 2 秒写一次）
  void _saveLogs() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _doSaveLogs);
  }

  Future<void> _doSaveLogs() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      final now = DateTime.now();
      final validLogs = _logs.where((log) {
        final age = now.difference(log.timestamp);
        return age.inHours < _maxStorageHours;
      }).toList();

      final jsonList = validLogs.map((log) => log.toJson()).toList();
      final jsonStr = jsonEncode(jsonList);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('保存日志失败: $e');
    } finally {
      _isSaving = false;
    }
  }

  /// Debug 日志
  void debug(String tag, String message, [dynamic data]) {
    final msg = data != null ? '$message | Data: $data' : message;
    _addLog(LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.debug,
      platform: LogPlatform.flutter,
      tag: tag,
      message: msg,
    ));
  }

  /// Info 日志
  void info(String tag, String message, [dynamic data]) {
    final msg = data != null ? '$message | Data: $data' : message;
    _addLog(LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.info,
      platform: LogPlatform.flutter,
      tag: tag,
      message: msg,
    ));
  }

  /// Warning 日志
  void warning(String tag, String message, [dynamic data]) {
    final msg = data != null ? '$message | Data: $data' : message;
    _addLog(LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.warning,
      platform: LogPlatform.flutter,
      tag: tag,
      message: msg,
    ));
  }

  /// Error 日志
  void error(String tag, String message,
      [dynamic error, StackTrace? stackTrace]) {
    _addLog(LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.error,
      platform: LogPlatform.flutter,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  /// 清空日志
  void clear() {
    _logs.clear();
    _notifyListeners();
  }

  /// 导出所有日志为文本
  String exportAsText() {
    final buffer = StringBuffer();
    buffer.writeln('=== BeeCount 日志导出 ===');
    buffer.writeln('导出时间: ${DateTime.now()}');
    buffer.writeln('日志数量: ${_logs.length}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (final log in _logs) {
      buffer.write(log.toFormattedString());
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// 设置原生日志桥接
  void _setupNativeBridge() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNativeLog') {
        final args = call.arguments as Map;
        _handleNativeLog(args);
      }
    });
  }

  /// 处理原生日志
  void _handleNativeLog(Map args) {
    try {
      debugPrint('📱 收到原生日志: $args');

      final platformStr = args['platform'] as String;
      final levelStr = args['level'] as String;
      final tag = args['tag'] as String;
      final message = args['message'] as String;
      final timestamp = args['timestamp'] as int;

      // 解析平台
      final platform = platformStr == 'android'
          ? LogPlatform.android
          : platformStr == 'ios'
              ? LogPlatform.ios
              : LogPlatform.flutter;

      // 解析日志级别
      final level = _parseLogLevel(levelStr);

      debugPrint('📝 添加原生日志到队列: [$platformStr] [$levelStr] [$tag] $message');

      _addLog(LogEntry(
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
        level: level,
        platform: platform,
        tag: tag,
        message: message,
      ));
    } catch (e, stackTrace) {
      debugPrint('处理原生日志失败: $e');
      debugPrint('堆栈: $stackTrace');
    }
  }

  LogLevel _parseLogLevel(String levelStr) {
    switch (levelStr.toUpperCase()) {
      case 'DEBUG':
      case 'D':
        return LogLevel.debug;
      case 'INFO':
      case 'I':
        return LogLevel.info;
      case 'WARNING':
      case 'WARN':
      case 'W':
        return LogLevel.warning;
      case 'ERROR':
      case 'E':
        return LogLevel.error;
      default:
        return LogLevel.info;
    }
  }
}

/// 全局日志实例
final logger = LoggerService();
