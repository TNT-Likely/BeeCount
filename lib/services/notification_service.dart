import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

class NotificationService {
  static FlutterLocalNotificationsPlugin? _flutterLocalNotificationsPlugin;
  static bool _initialized = false;
  
  static const int _accountingReminderId = 1001;
  static const MethodChannel _channel = MethodChannel('notification_channel');

  /// 初始化通知服务
  static Future<void> initialize() async {
    if (_initialized) return;

    print('开始初始化通知服务...');
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // 初始化时区数据
    tz.initializeTimeZones();
    
    // 设置本地时区
    final String timeZoneName = DateTime.now().timeZoneName;
    print('设备时区名称: $timeZoneName');
    
    // 尝试设置为Asia/Shanghai或者使用设备时区
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
      print('设置时区为: Asia/Shanghai');
    } catch (e) {
      print('无法设置Asia/Shanghai时区，使用系统时区: ${tz.local.name}');
    }
    print('时区数据初始化完成');
    
    // Android初始化设置
    const androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS初始化设置
    const iosInitializationSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    try {
      await _flutterLocalNotificationsPlugin!.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      print('通知插件初始化成功');

      // 请求权限（Android 13+）
      final permissionGranted = await _requestPermissions();
      print('通知权限请求结果: $permissionGranted');
      
      _initialized = true;
      print('✅ 通知服务初始化完成');
    } catch (e) {
      print('❌ 通知服务初始化失败: $e');
      rethrow;
    }
  }

  /// 请求通知权限
  static Future<bool> _requestPermissions() async {
    if (_flutterLocalNotificationsPlugin == null) return false;

    // Android权限请求
    final androidPlugin = _flutterLocalNotificationsPlugin!
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      print('正在请求Android通知权限...');
      
      // 请求通知权限
      final granted = await androidPlugin.requestNotificationsPermission();
      print('基础通知权限: ${granted ?? false}');
      
      // 对于Android 12+，还需要请求精确闹钟权限
      try {
        final exactAlarmGranted = await androidPlugin.requestExactAlarmsPermission();
        print('精确闹钟权限: ${exactAlarmGranted ?? false}');
        
        // 检查是否可以设置精确闹钟
        final canScheduleExactAlarms = await androidPlugin.canScheduleExactNotifications();
        print('可以设置精确闹钟: ${canScheduleExactAlarms ?? false}');
        
        if (!(canScheduleExactAlarms ?? false)) {
          print('⚠️  警告: 无法设置精确闹钟，后台通知可能不可靠');
        }
      } catch (e) {
        print('❌ 请求精确闹钟权限失败: $e');
      }
      
      return granted ?? false;
    }

    // iOS权限请求
    final iosPlugin = _flutterLocalNotificationsPlugin!
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  /// 处理通知点击
  static void _onNotificationTap(NotificationResponse response) {
    // 这里可以处理用户点击通知后的逻辑
    // 比如跳转到记账页面
    print('用户点击了记账提醒通知: ${response.payload}');
  }

  /// 设置记账提醒
  static Future<void> scheduleAccountingReminder({
    required int hour,
    required int minute,
  }) async {
    print('🔔 开始设置记账提醒: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
    
    if (!_initialized) {
      print('⚠️  通知服务未初始化，正在初始化...');
      await initialize();
    }
    if (_flutterLocalNotificationsPlugin == null) {
      print('❌ 通知插件为null，无法设置提醒');
      return;
    }

    // 先取消之前的提醒
    print('🗑️  取消之前的提醒...');
    await cancelAccountingReminder();

    // 计算下一次提醒时间
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    print('⏰ 当前时间: ${now.toString()}');
    print('⏰ 计划提醒时间: ${scheduledDate.toString()}');
    
    // 如果时间已过，则设置为明天
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
      print('⏰ 时间已过，调整为明天: ${scheduledDate.toString()}');
    }

    final tzScheduledDate = tz.TZDateTime(tz.local, scheduledDate.year, scheduledDate.month, scheduledDate.day, scheduledDate.hour, scheduledDate.minute);
    print('🌍 时区调整后的提醒时间: ${tzScheduledDate.toString()}');

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

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      print('📱 准备设置主要通知 (ID: $_accountingReminderId)...');
      
      // 使用 exactAllowWhileIdle 来确保在设备休眠时也能触发
      await _flutterLocalNotificationsPlugin!.zonedSchedule(
        _accountingReminderId,
        '记账提醒',
        '别忘了记录今天的收支哦 💰',
        tzScheduledDate,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // 每天重复
        payload: 'accounting_reminder',
      );

      print('✅ 主要记账提醒设置成功: 每天${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
      print('✅ 下次提醒时间: ${scheduledDate.toString()}');
      print('✅ 使用调度模式: exactAllowWhileIdle');
      print('✅ 每日重复: ${DateTimeComponents.time}');
      
      // 额外调度一些近期的提醒作为备用（解决某些系统清理定时任务的问题）
      print('🔄 开始设置备用提醒...');
      await _scheduleBackupReminders(hour, minute);

      // 对于Android，额外使用AlarmManager作为备用调度
      if (Platform.isAndroid) {
        print('📱 设置Android AlarmManager备用调度...');
        await _scheduleAlarmManagerBackup(hour, minute);
      }
      
    } catch (e) {
      print('❌ 设置记账提醒失败: $e');
      print('❌ 错误详情: ${e.toString()}');
      rethrow;
    }
  }
  
  /// 使用Android AlarmManager作为备用调度
  static Future<void> _scheduleAlarmManagerBackup(int hour, int minute) async {
    try {
      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

      // 如果时间已过，则设置为明天
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      print('🔔 使用AlarmManager设置备用提醒: ${scheduledDate.toString()}');

      await _channel.invokeMethod('scheduleNotification', {
        'title': '记账提醒',
        'body': '别忘了记录今天的收支哦 💰',
        'scheduledTimeMillis': scheduledDate.millisecondsSinceEpoch,
        'notificationId': _accountingReminderId + 100, // 使用不同的ID避免冲突
      });

      print('✅ AlarmManager备用提醒设置成功');
    } catch (e) {
      print('❌ AlarmManager备用提醒设置失败: $e');
    }
  }

  /// 调度备用提醒（解决系统可能清理定时任务的问题）
  static Future<void> _scheduleBackupReminders(int hour, int minute) async {
    try {
      final now = DateTime.now();
      print('📅 开始设置7天备用提醒...');
      
      // 调度未来7天的单独提醒作为备用
      for (int i = 1; i <= 7; i++) {
        final backupDate = DateTime(now.year, now.month, now.day + i, hour, minute);
        final tzBackupDate = tz.TZDateTime(tz.local, backupDate.year, backupDate.month, backupDate.day, backupDate.hour, backupDate.minute);
        final backupId = _accountingReminderId + i;
        
        print('📅 设置备用提醒 $i/7 (ID: $backupId): ${backupDate.toString()}');
        
        const androidDetails = AndroidNotificationDetails(
          'accounting_reminder_backup',
          '记账提醒备用',
          channelDescription: '记账提醒备用通道',
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
          playSound: true,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
        );

        const iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        const platformChannelSpecifics = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );
        
        await _flutterLocalNotificationsPlugin!.zonedSchedule(
          backupId, // 使用不同的ID
          '记账提醒',
          '别忘了记录今天的收支哦 💰',
          tzBackupDate,
          platformChannelSpecifics,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'accounting_reminder_backup',
        );
      }
      print('✅ 所有备用提醒设置完成 (共7天)');
    } catch (e) {
      print('设置备用提醒失败: $e');
    }
  }

  /// 取消记账提醒
  static Future<void> cancelAccountingReminder() async {
    print('🗑️  开始取消所有记账提醒...');
    
    if (!_initialized) await initialize();
    if (_flutterLocalNotificationsPlugin == null) {
      print('❌ 通知插件为null，无法取消提醒');
      return;
    }

    // 取消主要提醒
    print('🗑️  取消主要提醒 (ID: $_accountingReminderId)');
    await _flutterLocalNotificationsPlugin!.cancel(_accountingReminderId);
    
    // 取消所有备用提醒 (未来7天)
    print('🗑️  取消备用提醒 (ID: ${_accountingReminderId + 1} - ${_accountingReminderId + 7})');
    for (int i = 1; i <= 7; i++) {
      await _flutterLocalNotificationsPlugin!.cancel(_accountingReminderId + i);
    }

    // 取消AlarmManager备用提醒
    if (Platform.isAndroid) {
      try {
        print('🗑️  取消AlarmManager备用提醒 (ID: ${_accountingReminderId + 100})');
        await _channel.invokeMethod('cancelNotification', {
          'notificationId': _accountingReminderId + 100,
        });
        print('✅ AlarmManager备用提醒已取消');
      } catch (e) {
        print('❌ 取消AlarmManager备用提醒失败: $e');
      }
    }

    print('✅ 所有记账提醒已取消 (包括备用提醒)');
  }

  /// 立即发送测试通知
  static Future<void> showTestNotification() async {
    print('开始发送测试通知...');
    if (!_initialized) {
      print('通知服务未初始化，正在初始化...');
      await initialize();
    }
    if (_flutterLocalNotificationsPlugin == null) {
      print('❌ 通知插件为null，无法发送通知');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'accounting_reminder', // 使用相同的渠道ID
      '记账提醒',
      channelDescription: '每日记账提醒',
      importance: Importance.max, // 使用最高重要性
      priority: Priority.max, // 使用最高优先级
      enableVibration: true,
      playSound: true,
      enableLights: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _flutterLocalNotificationsPlugin!.show(
        999,
        '测试通知',
        '这是一条测试记账提醒通知',
        platformChannelSpecifics,
      );
      print('✅ 测试通知发送成功');
    } catch (e) {
      print('❌ 测试通知发送失败: $e');
      rethrow;
    }
  }

  /// 获取待处理的通知
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_initialized) await initialize();
    if (_flutterLocalNotificationsPlugin == null) return [];

    return await _flutterLocalNotificationsPlugin!.pendingNotificationRequests();
  }

  /// 检查是否被电池优化
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (e) {
      print('检查电池优化状态失败: $e');
      return false;
    }
  }

  /// 请求忽略电池优化
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
      return result ?? false;
    } catch (e) {
      print('请求忽略电池优化失败: $e');
      return false;
    }
  }

  /// 打开应用设置页面
  static Future<void> openAppSettings() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (e) {
      print('打开应用设置失败: $e');
    }
  }

  /// 打开通知渠道设置页面
  static Future<void> openNotificationChannelSettings() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('openNotificationChannelSettings');
    } catch (e) {
      print('打开通知渠道设置失败: $e');
    }
  }

  /// 获取通知渠道信息
  static Future<Map<String, dynamic>> getNotificationChannelInfo() async {
    if (!Platform.isAndroid) {
      return {
        'isEnabled': true,
        'importance': 'high',
        'sound': true,
        'vibration': true,
      };
    }

    try {
      final result = await _channel.invokeMethod('getNotificationChannelInfo');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      print('获取通知渠道信息失败: $e');
      return {
        'isEnabled': false,
        'importance': 'unknown',
        'sound': false,
        'vibration': false,
      };
    }
  }

  /// 获取电池优化状态信息
  static Future<Map<String, dynamic>> getBatteryOptimizationInfo() async {
    if (!Platform.isAndroid) {
      return {
        'isIgnoring': true,
        'canRequest': false,
        'manufacturer': 'iOS',
      };
    }

    try {
      final result = await _channel.invokeMethod('getBatteryOptimizationInfo');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      print('获取电池优化信息失败: $e');
      return {
        'isIgnoring': false,
        'canRequest': false,
        'manufacturer': 'Unknown',
      };
    }
  }

  /// 设置一个几分钟后的测试提醒（用于验证后台通知功能）
  static Future<void> scheduleTestReminderInMinutes(int minutes) async {
    print('⏲️  开始设置$minutes分钟后的测试提醒...');

    if (!_initialized) {
      print('⚠️  通知服务未初始化，正在初始化...');
      await initialize();
    }
    if (_flutterLocalNotificationsPlugin == null) {
      print('❌ 通知插件为null，无法设置测试提醒');
      return;
    }

    final now = DateTime.now();
    final testTime = now.add(Duration(minutes: minutes));
    final tzTestTime = tz.TZDateTime(tz.local, testTime.year, testTime.month, testTime.day, testTime.hour, testTime.minute);

    print('⏲️  当前时间: $now');
    print('⏲️  测试提醒时间: $testTime');
    print('⏲️  时区调整后: $tzTestTime');
    print('⏲️  时间戳: ${testTime.millisecondsSinceEpoch}');

    // 1. 首先使用flutter_local_notifications
    const androidDetails = AndroidNotificationDetails(
      'test_reminder',
      '测试提醒',
      channelDescription: '测试提醒通道',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      print('⏲️  准备设置Flutter测试提醒 (ID: 9999)...');

      await _flutterLocalNotificationsPlugin!.zonedSchedule(
        9999, // 特殊ID用于测试
        '测试提醒(Flutter)',
        '这是一个$minutes分钟后的Flutter测试提醒 🔔',
        tzTestTime,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'test_reminder_flutter',
      );

      print('✅ Flutter测试提醒设置成功');

      // 2. 对于Android，同时使用AlarmManager作为备用
      if (Platform.isAndroid) {
        print('⏲️  准备设置AlarmManager测试提醒 (ID: 9998)...');

        await _channel.invokeMethod('scheduleNotification', {
          'title': '测试提醒(AlarmManager)',
          'body': '这是一个$minutes分钟后的AlarmManager测试提醒 ⏰',
          'scheduledTimeMillis': testTime.millisecondsSinceEpoch,
          'notificationId': 9998,
        });

        print('✅ AlarmManager测试提醒设置成功');
      }

      print('✅ 所有测试提醒设置完成: $minutes分钟后');
      print('✅ 请将应用置于后台，等待$minutes分钟查看通知是否到达');
      print('✅ 应该会收到两个通知（Flutter + AlarmManager）');
    } catch (e) {
      print('❌ 设置测试提醒失败: $e');
      rethrow;
    }
  }

  /// 15秒快速测试（仅使用AlarmManager）
  static Future<void> scheduleQuickTest() async {
    print('🚀 开始设置15秒快速测试...');

    if (!Platform.isAndroid) {
      print('❌ 快速测试仅支持Android');
      return;
    }

    final now = DateTime.now();
    final testTime = now.add(const Duration(seconds: 15));

    try {
      await _channel.invokeMethod('scheduleNotification', {
        'title': '快速测试提醒',
        'body': '15秒测试提醒到达！如果您看到这个通知说明AlarmManager工作正常 ✅',
        'scheduledTimeMillis': testTime.millisecondsSinceEpoch,
        'notificationId': 9997,
      });

      print('✅ 15秒快速测试设置成功');
      print('⏰ 测试时间: $testTime');
    } catch (e) {
      print('❌ 15秒快速测试设置失败: $e');
      rethrow;
    }
  }

  /// 立即测试AlarmManager通知点击功能
  static Future<void> testAlarmManagerNotificationClick() async {
    print('🧪 开始测试AlarmManager通知点击功能...');

    if (!Platform.isAndroid) {
      print('❌ 测试仅支持Android');
      return;
    }

    try {
      // 立即触发一个AlarmManager通知（1秒后）
      final now = DateTime.now();
      final testTime = now.add(const Duration(seconds: 1));

      print('⏰ 当前时间: $now');
      print('⏰ 通知时间: $testTime');
      print('⏰ 时间戳: ${testTime.millisecondsSinceEpoch}');

      await _channel.invokeMethod('scheduleNotification', {
        'title': '点击测试通知',
        'body': '请点击这个通知测试是否能打开应用 🔄',
        'scheduledTimeMillis': testTime.millisecondsSinceEpoch,
        'notificationId': 8888,
      });

      print('✅ AlarmManager点击测试通知已设置，1秒后显示');
      print('📱 请查看日志: adb logcat | grep -E "(NotificationReceiver|NotificationClickReceiver|MainActivity)"');
    } catch (e) {
      print('❌ AlarmManager点击测试失败: $e');
      rethrow;
    }
  }

  /// 直接测试NotificationReceiver创建通知
  static Future<void> testDirectNotificationReceiver() async {
    print('🔨 开始直接测试NotificationReceiver...');

    if (!Platform.isAndroid) {
      print('❌ 测试仅支持Android');
      return;
    }

    try {
      await _channel.invokeMethod('testDirectNotification', {
        'title': '直接测试通知',
        'body': '这是直接调用NotificationReceiver的测试 🛠️',
        'notificationId': 7777,
      });

      print('✅ 直接测试通知已发送');
    } catch (e) {
      print('❌ 直接测试失败: $e');
      rethrow;
    }
  }
}