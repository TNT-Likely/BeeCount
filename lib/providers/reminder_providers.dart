import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

/// 记账提醒设置
class ReminderSettings {
  final bool isEnabled;
  final int hour;  // 0-23
  final int minute; // 0-59

  const ReminderSettings({
    required this.isEnabled,
    required this.hour,
    required this.minute,
  });

  factory ReminderSettings.defaultSettings() {
    return const ReminderSettings(
      isEnabled: false,
      hour: 21, // 默认晚上9点
      minute: 0,
    );
  }

  ReminderSettings copyWith({
    bool? isEnabled,
    int? hour,
    int? minute,
  }) {
    return ReminderSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  String get timeString {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderSettings &&
          runtimeType == other.runtimeType &&
          isEnabled == other.isEnabled &&
          hour == other.hour &&
          minute == other.minute;

  @override
  int get hashCode => isEnabled.hashCode ^ hour.hashCode ^ minute.hashCode;
}

/// 记账提醒设置的StateNotifier
class ReminderSettingsNotifier extends StateNotifier<ReminderSettings> {
  ReminderSettingsNotifier() : super(ReminderSettings.defaultSettings()) {
    _loadSettings();
  }

  static const String _keyEnabled = 'reminder_enabled';
  static const String _keyHour = 'reminder_hour';
  static const String _keyMinute = 'reminder_minute';

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(_keyEnabled) ?? false;
      final hour = prefs.getInt(_keyHour) ?? 21;
      final minute = prefs.getInt(_keyMinute) ?? 0;

      state = ReminderSettings(
        isEnabled: isEnabled,
        hour: hour,
        minute: minute,
      );
    } catch (e) {
      // 保持默认设置
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnabled, state.isEnabled);
      await prefs.setInt(_keyHour, state.hour);
      await prefs.setInt(_keyMinute, state.minute);
    } catch (e) {
      // 忽略保存错误
    }
  }

  /// 更新启用状态
  Future<void> updateEnabled(bool enabled) async {
    state = state.copyWith(isEnabled: enabled);
    await _saveSettings();
    
    if (enabled) {
      await NotificationService.scheduleAccountingReminder(
        hour: state.hour,
        minute: state.minute,
      );
    } else {
      await NotificationService.cancelAccountingReminder();
    }
  }

  /// 更新提醒时间
  Future<void> updateTime(int hour, int minute) async {
    state = state.copyWith(hour: hour, minute: minute);
    await _saveSettings();
    
    // 如果提醒已启用，重新设置通知
    if (state.isEnabled) {
      await NotificationService.scheduleAccountingReminder(
        hour: hour,
        minute: minute,
      );
    }
  }

  /// 更新完整设置
  Future<void> updateSettings(ReminderSettings settings) async {
    state = settings;
    await _saveSettings();
    
    if (settings.isEnabled) {
      await NotificationService.scheduleAccountingReminder(
        hour: settings.hour,
        minute: settings.minute,
      );
    } else {
      await NotificationService.cancelAccountingReminder();
    }
  }
}

/// 记账提醒设置Provider
final reminderSettingsProvider = StateNotifierProvider<ReminderSettingsNotifier, ReminderSettings>((ref) {
  return ReminderSettingsNotifier();
});