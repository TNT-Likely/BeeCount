import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'notification_util.dart' as util;

/// Android 特定的通知实现
class AndroidNotificationUtil implements util.NotificationUtil {
  final FlutterLocalNotificationsPlugin _plugin;
  final MethodChannel _channel = const MethodChannel('notification_channel');
  bool _initialized = false;

  AndroidNotificationUtil(this._plugin);

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    // 初始化后立即请求权限
    await requestPermissions();

    _initialized = true;

    print('[Android] 通知服务初始化完成');
  }

  @override
  Future<bool> requestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return false;

    // 请求基础通知权限
    final granted = await androidPlugin.requestNotificationsPermission();
    print('[Android] 基础通知权限: ${granted ?? false}');

    // 请求精确闹钟权限 (Android 12+)
    try {
      await androidPlugin.requestExactAlarmsPermission();
      final canScheduleExact =
          await androidPlugin.canScheduleExactNotifications();
      print('[Android] 精确闹钟权限: ${canScheduleExact ?? false}');
    } catch (e) {
      print('[Android] 请求精确闹钟权限失败: $e');
    }

    return granted ?? false;
  }

  @override
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (!_initialized) await initialize();

    final scheduledDate = util.calculateNextReminderTime(hour, minute);
    final tzScheduledDate = util.convertToTZDateTime(scheduledDate);

    const androidDetails = AndroidNotificationDetails(
      'accounting_reminder',
      '记账提醒',
      channelDescription: '每日记账提醒',
      importance: Importance.max,
      priority: Priority.max,
      ticker: '记账提醒',
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
      enableLights: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      autoCancel: false,
      ongoing: false,
      showWhen: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    try {
      // 使用 exactAllowWhileIdle 确保休眠时也能触发
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // 每天重复
      );

      print('[Android] ✅ 每日提醒设置成功: $hour:$minute');
      print('[Android] ✅ 下次提醒时间: $scheduledDate');
      print('[Android] ✅ 使用调度模式: exactAllowWhileIdle');
      print('[Android] ✅ 每日重复: ${DateTimeComponents.time}');

      // 设置7天备用提醒（防止系统清理定时任务）
      print('[Android] 🔄 开始设置7天备用提醒...');
      await _scheduleBackupReminders(id, title, body, hour, minute);

      // 设置 AlarmManager 备用
      await _scheduleAlarmManagerBackup(id, title, body, scheduledDate);
    } catch (e) {
      print('[Android] Flutter 通知设置失败: $e');
      // 降级到 AlarmManager
      await _scheduleAlarmManagerBackup(id, title, body, scheduledDate);
    }
  }

  @override
  Future<void> scheduleOnceReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized) await initialize();

    final tzScheduledDate = util.convertToTZDateTime(scheduledDate);

    const androidDetails = AndroidNotificationDetails(
      'accounting_reminder',
      '记账提醒',
      channelDescription: '每日记账提醒',
      importance: Importance.max,
      priority: Priority.max,
      ticker: '记账提醒',
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
      enableLights: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    print('[Android] 单次提醒设置成功: $scheduledDate');
  }

  @override
  Future<void> cancelNotification(int id) async {
    if (!_initialized) await initialize();

    print('[Android] 🗑️  开始取消所有提醒...');

    // 取消主要提醒
    await _plugin.cancel(id);
    print('[Android] 🗑️  取消主要提醒 (ID: $id)');

    // 取消所有7天备用提醒
    print('[Android] 🗑️  取消备用提醒 (ID: ${id + 1} - ${id + 7})');
    for (int i = 1; i <= 7; i++) {
      await _plugin.cancel(id + i);
    }

    // 同时取消 AlarmManager 备用
    try {
      print('[Android] 🗑️  取消AlarmManager备用提醒 (ID: ${id + 100})');
      await _channel.invokeMethod('cancelNotification', {
        'notificationId': id + 100,
      });
    } catch (e) {
      print('[Android] 取消 AlarmManager 备用失败: $e');
    }

    print('[Android] ✅ 所有提醒已取消 (包括备用提醒)');
  }

  @override
  Future<void> cancelAllNotifications() async {
    if (!_initialized) await initialize();
    await _plugin.cancelAll();
    print('[Android] 所有通知已取消');
  }

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'accounting_reminder',
      '记账提醒',
      channelDescription: '每日记账提醒',
      importance: Importance.max,
      priority: Priority.max,
      ticker: '记账提醒',
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
      enableLights: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(id, title, body, notificationDetails);
    print('[Android] 即时通知已显示: $title');
  }

  @override
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_initialized) await initialize();
    return await _plugin.pendingNotificationRequests();
  }

  @override
  Future<bool> checkPermissionStatus() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return false;

    final enabled = await androidPlugin.areNotificationsEnabled();
    return enabled ?? false;
  }

  /// 调度7天备用提醒（防止系统清理定时任务）
  Future<void> _scheduleBackupReminders(
    int id,
    String title,
    String body,
    int hour,
    int minute,
  ) async {
    try {
      final now = DateTime.now();

      // 调度未来7天的单独提醒作为备用
      for (int i = 1; i <= 7; i++) {
        final backupDate =
            DateTime(now.year, now.month, now.day + i, hour, minute);
        final tzBackupDate = tz.TZDateTime.from(backupDate, tz.local);
        final backupId = id + i;

        print('[Android] 📅 设置备用提醒 $i/7 (ID: $backupId): $backupDate');

        const androidDetails = AndroidNotificationDetails(
          'accounting_reminder_backup',
          '记账提醒备用',
          channelDescription: '记账提醒备用通道',
          importance: Importance.max,
          priority: Priority.max,
          ticker: '记账提醒',
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
          playSound: true,
          enableLights: true,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
        );

        const notificationDetails =
            NotificationDetails(android: androidDetails);

        await _plugin.zonedSchedule(
          backupId,
          title,
          body,
          tzBackupDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
      print('[Android] ✅ 所有备用提醒设置完成 (共7天)');
    } catch (e) {
      print('[Android] ⚠️  设置备用提醒失败: $e');
    }
  }

  /// 使用 AlarmManager 作为备用调度（Android 特有）
  Future<void> _scheduleAlarmManagerBackup(
    int id,
    String title,
    String body,
    DateTime scheduledDate,
  ) async {
    try {
      await _channel.invokeMethod('scheduleNotification', {
        'title': title,
        'body': body,
        'scheduledTimeMillis': scheduledDate.millisecondsSinceEpoch,
        'notificationId': id + 100, // 使用不同ID避免冲突
      });

      print('[Android] AlarmManager 备用设置成功');
    } catch (e) {
      print('[Android] AlarmManager 备用设置失败: $e');
    }
  }

  /// 检查电池优化状态（Android 特有）
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final result =
          await _channel.invokeMethod('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (e) {
      print('[Android] 检查电池优化状态失败: $e');
      return false;
    }
  }

  /// 请求忽略电池优化（Android 特有）
  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final result =
          await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
      return result ?? false;
    } catch (e) {
      print('[Android] 请求忽略电池优化失败: $e');
      return false;
    }
  }

  /// 打开应用设置（Android 特有）
  Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (e) {
      print('[Android] 打开应用设置失败: $e');
    }
  }

  /// 打开通知渠道设置（Android 特有）
  Future<void> openNotificationChannelSettings() async {
    try {
      await _channel.invokeMethod('openNotificationChannelSettings');
    } catch (e) {
      print('[Android] 打开通知渠道设置失败: $e');
    }
  }

  /// 获取电池优化详细信息（Android 特有）
  Future<Map<String, dynamic>> getBatteryOptimizationInfo() async {
    try {
      final result = await _channel.invokeMethod('getBatteryOptimizationInfo');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      print('[Android] 获取电池优化信息失败: $e');
      return {
        'isIgnoring': false,
        'canRequest': false,
        'manufacturer': 'Unknown',
        'model': 'Unknown',
        'androidVersion': 'Unknown',
      };
    }
  }

  /// 获取通知渠道详细信息（Android 特有）
  Future<Map<String, dynamic>> getNotificationChannelInfo() async {
    try {
      final result = await _channel.invokeMethod('getNotificationChannelInfo');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      print('[Android] 获取通知渠道信息失败: $e');
      return {
        'isEnabled': false,
        'importance': 'unknown',
        'sound': false,
        'vibration': false,
      };
    }
  }
}
