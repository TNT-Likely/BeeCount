import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../utils/logger.dart';

/// 更新通知管理类
class UpdateNotifications {
  UpdateNotifications._();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isNotificationInitialized = false;
  static int _lastNotificationProgress = -1; // 记录上次通知的进度，避免频繁更新

  /// 初始化通知
  static Future<void> initializeNotifications() async {
    if (_isNotificationInitialized) return;

    try {
      // Android 通知渠道设置
      const androidChannel = AndroidNotificationChannel(
        'update_download',
        'Update Download',
        description: 'APK update file download progress',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      );

      // 创建通知渠道
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(androidChannel);
        logI('UpdateNotifications', '通知渠道创建成功: ${androidChannel.id}');

        // 检查权限状态（Android 13+）
        final hasPermission =
            await androidImplementation.requestNotificationsPermission();
        logI('UpdateNotifications', '通知权限状态: $hasPermission');
      }

      // 初始化插件
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initializationSettings =
          InitializationSettings(android: androidSettings, iOS: iosSettings);

      final initialized =
          await _notificationsPlugin.initialize(initializationSettings);
      _isNotificationInitialized = initialized == true;
      logI('UpdateNotifications', '通知初始化结果: $initialized');
    } catch (e) {
      logE('UpdateNotifications', '通知初始化失败', e);
    }
  }

  /// 显示下载进度通知
  static Future<void> showProgressNotification(int progress,
      {bool indeterminate = false}) async {
    try {
      await initializeNotifications();
      if (!_isNotificationInitialized) {
        logW('UpdateNotifications', '通知未初始化，跳过显示进度');
        return;
      }

      final androidDetails = AndroidNotificationDetails(
        'update_download',
        'Update Download',
        channelDescription: 'APK update file download progress',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showProgress: !indeterminate,
        maxProgress: indeterminate ? 0 : 100,
        progress: indeterminate ? 0 : progress,
        indeterminate: indeterminate,
        enableVibration: false,
        playSound: false,
        showWhen: false,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );

      final details =
          NotificationDetails(android: androidDetails, iOS: iosDetails);

      final title = 'BeeCount Update Download';
      final body = indeterminate ? 'Downloading new version...' : 'Download progress: $progress%';

      logI('UpdateNotifications',
          '开始显示通知 - 标题: $title, 内容: $body, 进度: $progress, 不确定: $indeterminate');

      await _notificationsPlugin.show(
        0,
        title,
        body,
        details,
      );

      logI('UpdateNotifications', '通知显示完成 - ID: 0, 进度: $progress%');
    } catch (e) {
      logE('UpdateNotifications', '显示进度通知失败', e);
    }
  }

  /// 完成下载通知
  static Future<void> showDownloadCompleteNotification(String filePath) async {
    try {
      await initializeNotifications();
      if (!_isNotificationInitialized) {
        logW('UpdateNotifications', '通知未初始化，跳过显示完成通知');
        return;
      }

      const androidDetails = AndroidNotificationDetails(
        'update_download',
        'Update Download',
        channelDescription: 'APK update file download progress',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: false,
        autoCancel: true,
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _notificationsPlugin.show(
        0,
        'Download Complete',
        'New version downloaded, tap to install',
        details,
      );

      logI('UpdateNotifications', '显示下载完成通知');
    } catch (e) {
      logE('UpdateNotifications', '显示完成通知失败', e);
    }
  }

  /// 取消下载通知
  static Future<void> cancelDownloadNotification() async {
    try {
      await _notificationsPlugin.cancel(0);
      logI('UpdateNotifications', '取消下载通知');
    } catch (e) {
      logE('UpdateNotifications', '取消通知失败', e);
    }
  }

  /// 重置进度记录
  static void resetProgress() {
    _lastNotificationProgress = -1;
  }

  /// 检查是否应该更新通知进度
  static bool shouldUpdateProgress(int currentProgress) {
    return _lastNotificationProgress == -1 ||
        currentProgress - _lastNotificationProgress >= 1 ||
        currentProgress == 0 ||
        currentProgress == 100;
  }

  /// 记录上次通知进度
  static void recordProgress(int progress) {
    _lastNotificationProgress = progress;
  }
}