import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/logger.dart';

/// 更新权限管理类
class UpdatePermissions {
  UpdatePermissions._();

  static bool _notificationPermissionDenied = false;

  /// 获取通知权限被拒绝状态
  static bool get notificationPermissionDenied => _notificationPermissionDenied;

  /// 重置通知权限被拒绝状态
  static void resetNotificationPermissionDenied() {
    _notificationPermissionDenied = false;
  }

  /// 检查和申请权限
  static Future<bool> checkAndRequestPermissions() async {
    if (!Platform.isAndroid) return true;

    logI('UpdatePermissions', '开始检查权限...');

    // Android 10以下需要存储权限
    if (Platform.version.contains('API') &&
        int.tryParse(Platform.version.split(' ').last) != null &&
        int.parse(Platform.version.split(' ').last) <= 29) {
      final storageStatus = await Permission.storage.status;
      logI('UpdatePermissions', '存储权限状态: $storageStatus');
      if (!storageStatus.isGranted) {
        final result = await Permission.storage.request();
        logI('UpdatePermissions', '存储权限申请结果: $result');
        if (!result.isGranted) {
          logW('UpdatePermissions', '存储权限被拒绝');
          return false;
        }
      }
    }

    // 安装权限
    final installStatus = await Permission.requestInstallPackages.status;
    logI('UpdatePermissions', '安装权限状态: $installStatus');
    if (!installStatus.isGranted) {
      final result = await Permission.requestInstallPackages.request();
      logI('UpdatePermissions', '安装权限申请结果: $result');
      if (!result.isGranted) {
        logW('UpdatePermissions', '安装权限被拒绝');
        return false;
      }
    }

    // 通知权限检查 (所有Android版本)
    try {
      final notificationStatus = await Permission.notification.status;
      logI('UpdatePermissions', '通知权限状态: $notificationStatus');

      if (!notificationStatus.isGranted) {
        logI('UpdatePermissions', '申请通知权限...');
        final result = await Permission.notification.request();
        logI('UpdatePermissions', '通知权限申请结果: $result');

        if (!result.isGranted) {
          logW('UpdatePermissions', '通知权限被拒绝，进度通知将不会显示，但不影响下载功能');
          // 存储通知权限被拒绝的状态，稍后显示用户指南
          _notificationPermissionDenied = true;
        } else {
          logI('UpdatePermissions', '通知权限获取成功');
        }
      } else {
        logI('UpdatePermissions', '通知权限已获取');
      }
    } catch (e) {
      logE('UpdatePermissions', '检查通知权限失败', e);
    }

    logI('UpdatePermissions', '权限检查完成');
    return true;
  }
}