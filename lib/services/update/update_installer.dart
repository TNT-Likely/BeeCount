import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/logger.dart';
import '../../widgets/ui/ui.dart';
import '../../l10n/app_localizations.dart';
import 'update_permissions.dart';
import 'update_cache.dart';

/// 更新安装管理类
class UpdateInstaller {
  UpdateInstaller._();

  /// 安装APK
  static Future<bool> installApk(String filePath) async {
    try {
      logI('UpdateInstaller', 'UPDATE_CRASH: === 开始APK安装流程 ===');
      logI('UpdateInstaller', 'UPDATE_CRASH: 文件路径: $filePath');

      // 检查文件是否存在
      final file = File(filePath);
      final exists = await file.exists();
      logI('UpdateInstaller', 'UPDATE_CRASH: 文件是否存在: $exists');

      if (!exists) {
        logE('UpdateInstaller', 'UPDATE_CRASH: APK文件不存在，无法安装');
        return false;
      }

      // 检查文件大小
      final fileSize = await file.length();
      logI('UpdateInstaller', 'UPDATE_CRASH: APK文件大小: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB');

      // 检查平台
      logI('UpdateInstaller', 'UPDATE_CRASH: 运行平台: ${Platform.operatingSystem}');
      logI('UpdateInstaller', 'UPDATE_CRASH: 平台版本: ${Platform.version}');

      // 检查权限状态
      final installPermission = await UpdatePermissions.checkAndRequestPermissions();
      logI('UpdateInstaller', 'UPDATE_CRASH: 安装权限状态: $installPermission');

      logI('UpdateInstaller', 'UPDATE_CRASH: 准备调用OpenFilex.open...');

      // 在生产环境中使用更安全的调用方式
      bool success = false;
      if (const bool.fromEnvironment('dart.vm.product')) {
        logI('UpdateInstaller', 'UPDATE_CRASH: 生产环境，使用原生Intent方式安装');
        try {
          success = await _installApkWithIntent(filePath);
        } catch (intentException) {
          logE('UpdateInstaller', 'UPDATE_CRASH: Intent安装失败，尝试OpenFilex备用方案', intentException);
          try {
            final result = await OpenFilex.open(filePath);
            logI('UpdateInstaller', 'UPDATE_CRASH: === OpenFilex.open备用调用完成 ===');
            success = result.type == ResultType.done;
          } catch (openFileException) {
            logE('UpdateInstaller', 'UPDATE_CRASH: OpenFilex备用方案也失败', openFileException);
            success = false;
          }
        }
      } else {
        // 开发环境使用原来的方式
        final result = await OpenFilex.open(filePath);
        logI('UpdateInstaller', 'UPDATE_CRASH: === OpenFilex.open调用完成 ===');
        logI('UpdateInstaller', 'UPDATE_CRASH: 返回类型: ${result.type}');
        logI('UpdateInstaller', 'UPDATE_CRASH: 返回消息: ${result.message}');
        success = result.type == ResultType.done;
      }

      logI('UpdateInstaller', 'UPDATE_CRASH: 安装结果判定: $success');

      if (success) {
        logI('UpdateInstaller', 'UPDATE_CRASH: ✅ APK安装程序启动成功');
      } else {
        logW('UpdateInstaller', 'UPDATE_CRASH: ⚠️ APK安装程序启动失败');
      }

      return success;
    } catch (e, stackTrace) {
      logE('UpdateInstaller', 'UPDATE_CRASH: ❌ 安装APK过程中发生异常', e);
      logE('UpdateInstaller', 'UPDATE_CRASH: 异常堆栈: $stackTrace');

      // 记录异常类型
      logE('UpdateInstaller', 'UPDATE_CRASH: 异常类型: ${e.runtimeType}');
      if (e is PlatformException) {
        logE('UpdateInstaller', 'UPDATE_CRASH: PlatformException code: ${e.code}');
        logE('UpdateInstaller', 'UPDATE_CRASH: PlatformException message: ${e.message}');
        logE('UpdateInstaller', 'UPDATE_CRASH: PlatformException details: ${e.details}');
      }

      return false;
    }
  }

  /// 使用原生Android Intent安装APK（生产环境专用）
  static Future<bool> _installApkWithIntent(String filePath) async {
    try {
      logI('UpdateInstaller', 'UPDATE_CRASH: 开始使用Intent安装APK');

      if (!Platform.isAndroid) {
        logE('UpdateInstaller', 'UPDATE_CRASH: 非Android平台，无法使用Intent安装');
        return false;
      }

      // 使用MethodChannel调用原生Android代码
      const platform = MethodChannel('com.example.beecount/install');

      logI('UpdateInstaller', 'UPDATE_CRASH: 调用原生安装方法，文件路径: $filePath');

      final result = await platform.invokeMethod('installApk', {
        'filePath': filePath,
      });

      logI('UpdateInstaller', 'UPDATE_CRASH: 原生安装方法调用完成，结果: $result');

      return result == true;
    } catch (e, stackTrace) {
      logE('UpdateInstaller', 'UPDATE_CRASH: Intent安装异常', e);
      logE('UpdateInstaller', 'UPDATE_CRASH: Intent安装异常堆栈', stackTrace);
      return false;
    }
  }

  /// 手动查找并安装本地APK
  static Future<bool> showLocalApkInstallOption(BuildContext context) async {
    try {
      // 获取下载目录
      Directory? downloadDir;
      if (Platform.isAndroid) {
        downloadDir = await getExternalStorageDirectory();
      }
      downloadDir ??= await getApplicationDocumentsDirectory();

      // 查找所有BeeCount APK文件
      final files = downloadDir.listSync();
      final apkFiles = files
          .where((file) =>
              file is File &&
              file.path.contains('BeeCount') &&
              file.path.endsWith('.apk'))
          .cast<File>()
          .toList();

      if (apkFiles.isEmpty) {
        if (context.mounted) {
          await AppDialog.info(
            context,
            title: AppLocalizations.of(context).updateNoLocalApkTitle,
            message: AppLocalizations.of(context).updateNoLocalApkFoundMessage,
          );
        }
        return false;
      }

      // 按修改时间排序，最新的在前
      apkFiles.sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      if (!context.mounted) return false;

      // 如果只有一个APK文件，直接显示安装选项
      if (apkFiles.length == 1) {
        final file = apkFiles.first;
        final fileStat = file.statSync();
        final fileSize = (fileStat.size / (1024 * 1024)).toStringAsFixed(1);
        final fileName = file.path.split('/').last;
        final modifiedTime = fileStat.modified;

        final shouldInstall = await AppDialog.confirm<bool>(
          context,
          title: AppLocalizations.of(context).updateInstallPackageTitle,
          message: AppLocalizations.of(context).updateInstallPackageFoundMessage(
              fileName,
              fileSize,
              '${modifiedTime.year}-${modifiedTime.month.toString().padLeft(2, '0')}-${modifiedTime.day.toString().padLeft(2, '0')} ${modifiedTime.hour.toString().padLeft(2, '0')}:${modifiedTime.minute.toString().padLeft(2, '0')}'
          ),
          cancelLabel: AppLocalizations.of(context).commonCancel,
          okLabel: AppLocalizations.of(context).updateInstallNow,
        );

        if (!context.mounted) return false;

        if (shouldInstall == true) {
          final installed = await installApk(file.path);
          if (installed) {
            return true;
          } else {
            if (context.mounted) {
              await AppDialog.error(
                context,
                title: AppLocalizations.of(context).updateInstallFailedTitle,
                message: AppLocalizations.of(context).updateInstallFailedMessage,
              );
            }
          }
        }
      } else {
        // 多个APK文件，让用户选择
        if (context.mounted) {
          await AppDialog.info(
            context,
            title: AppLocalizations.of(context).updateMultiplePackagesTitle,
            message: AppLocalizations.of(context).updateMultiplePackagesFoundMessage(
                apkFiles.length,
                downloadDir.path
            ),
          );
        }
      }
    } catch (e) {
      logE('UpdateInstaller', '查找本地APK失败', e);
      if (context.mounted) {
        await AppDialog.error(
          context,
          title: AppLocalizations.of(context).updateSearchFailedTitle,
          message: AppLocalizations.of(context).updateSearchLocalApkError('$e'),
        );
      }
    }

    return false;
  }

  /// 检查是否有可用的缓存APK并提供安装选项
  static Future<bool> showCachedApkInstallOption(BuildContext context) async {
    final cachedPath = await UpdateCache.getCachedApkPath();

    if (cachedPath == null || !context.mounted) {
      return false;
    }

    try {
      final file = File(cachedPath);
      final fileStat = await file.stat();
      final fileSize = (fileStat.size / (1024 * 1024)).toStringAsFixed(1); // MB
      final fileName = cachedPath.split('/').last;

      if (!context.mounted) return false;

      final shouldInstall = await AppDialog.confirm<bool>(
        context,
        title: AppLocalizations.of(context).updateFoundCachedPackageTitle,
        message: AppLocalizations.of(context).updateCachedPackageFoundMessage(fileName, fileSize),
        cancelLabel: AppLocalizations.of(context).updateIgnoreButton,
        okLabel: AppLocalizations.of(context).updateInstallNow,
      );

      if (!context.mounted) return false;

      if (shouldInstall == true) {
        final installed = await installApk(cachedPath);
        if (installed) {
          // 安装成功后清理缓存
          await UpdateCache.clearCachedApk();
          return true;
        } else {
          if (context.mounted) {
            await AppDialog.error(
              context,
              title: AppLocalizations.of(context).updateInstallFailedTitle,
              message: AppLocalizations.of(context).updateInstallFailedMessage,
            );
          }
        }
      }
    } catch (e) {
      logE('UpdateInstaller', '显示缓存APK安装选项失败', e);
      if (context.mounted) {
        await AppDialog.error(
          context,
          title: AppLocalizations.of(context).updateErrorTitle,
          message: AppLocalizations.of(context).updateReadCachedPackageError('$e'),
        );
      }
    }

    return false;
  }
}