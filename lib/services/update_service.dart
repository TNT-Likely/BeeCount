import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Priority;
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as notifications;
import 'package:url_launcher/url_launcher.dart';
import '../utils/logger.dart';
import '../widgets/ui/ui.dart';

class UpdateService {
  static final Dio _dio = Dio();
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isNotificationInitialized = false;
  static bool _notificationPermissionDenied = false;
  static int _lastNotificationProgress = -1; // 记录上次通知的进度，避免频繁更新
  
  /// 检查更新信息
  static Future<UpdateResult> checkUpdate() async {
    try {
      // 获取当前版本信息
      final currentInfo = await _getAppInfo();
      final currentVersion = _normalizeVersion(currentInfo.version);
      
      logI('UpdateService', '当前版本: $currentVersion');

      // 配置Dio超时
      _dio.options.connectTimeout = const Duration(seconds: 30);
      _dio.options.receiveTimeout = const Duration(minutes: 2);
      _dio.options.sendTimeout = const Duration(minutes: 2);
      
      // 获取最新 release 信息 - 添加重试机制
      logI('UpdateService', '开始请求GitHub API...');
      Response? resp;
      int attempts = 0;
      const maxAttempts = 3;
      
      while (attempts < maxAttempts) {
        attempts++;
        try {
          logI('UpdateService', '尝试第$attempts次请求GitHub API...');
          resp = await _dio.get(
            'https://api.github.com/repos/TNT-Likely/BeeCount/releases/latest',
            options: Options(
              headers: {
                'Accept': 'application/vnd.github+json',
                'User-Agent': 'BeeCount-Mobile-App/1.0 (Android)',
              },
            ),
          );
          // 如果是成功响应，跳出循环
          if (resp.statusCode == 200) {
            logI('UpdateService', 'GitHub API请求成功');
            break;
          } else {
            logW('UpdateService', '第$attempts次请求返回错误状态码: ${resp.statusCode}');
            if (attempts == maxAttempts) {
              break; // 最后一次尝试，不再重试
            }
            await Future.delayed(const Duration(seconds: 1));
          }
        } catch (e) {
          logE('UpdateService', '第$attempts次请求失败', e);
          if (attempts == maxAttempts) {
            rethrow; // 最后一次尝试失败时抛出异常
          }
          // 等待1秒后重试
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      logI('UpdateService', 'GitHub API响应状态码: ${resp?.statusCode}');
      if (resp != null && resp.statusCode == 200) {
        final data = resp.data;
        final latestVersion = _normalizeVersion(data['tag_name']);
        
        logI('UpdateService', '最新版本: $latestVersion');
        
        if (_isNewerVersion(latestVersion, currentVersion)) {
          // 找到APK下载链接
          final assets = data['assets'] as List;
          String? apkUrl;
          
          for (final asset in assets) {
            if (asset['name'].toString().endsWith('.apk')) {
              apkUrl = asset['browser_download_url'];
              break;
            }
          }
          
          if (apkUrl != null) {
            return UpdateResult(
              hasUpdate: true,
              version: latestVersion,
              downloadUrl: apkUrl,
              releaseNotes: data['body'] ?? '',
            );
          } else {
            return UpdateResult(
              hasUpdate: false,
              message: '未找到APK下载链接',
            );
          }
        } else {
          return UpdateResult(
            hasUpdate: false,
            message: '当前已是最新版本',
          );
        }
      } else {
        final statusCode = resp?.statusCode ?? 'unknown';
        final responseData = resp?.data ?? 'no response';
        logE('UpdateService', 'GitHub API请求失败: HTTP $statusCode, 响应: $responseData');
        return UpdateResult(
          hasUpdate: false,
          message: '检查更新失败: HTTP $statusCode',
        );
      }
    } catch (e) {
      logE('UpdateService', '检查更新异常', e);
      return UpdateResult(
        hasUpdate: false,
        message: '检查更新失败: $e',
      );
    }
  }

  /// 下载并安装APK更新
  static Future<UpdateResult> downloadAndInstallUpdate(
    BuildContext context,
    String downloadUrl, {
    Function(double progress, String status)? onProgress,
  }) async {
    try {
      // 检查权限
      onProgress?.call(0.0, '检查权限...');
      final hasPermission = await _checkAndRequestPermissions();
      if (!hasPermission) {
        return UpdateResult(
          hasUpdate: false,
          message: '权限被拒绝',
        );
      }

      // 如果通知权限被拒绝，显示用户指南
      if (_notificationPermissionDenied && context.mounted) {
        await _showNotificationGuideDialog(context);
        _notificationPermissionDenied = false; // 重置状态，避免重复显示
      }

      // 开始下载
      onProgress?.call(0.0, '准备下载...');
      if (!context.mounted) {
        return UpdateResult(
          hasUpdate: false,
          message: '用户取消下载',
        );
      }
      
      final downloadResult = await _downloadApk(
        context,
        downloadUrl,
        'BeeCount更新',
        onProgress: onProgress,
      );
      
      if (downloadResult.success && downloadResult.filePath != null) {
        // 下载成功，询问是否立即安装
        logI('UpdateService', '下载成功，准备显示安装确认弹窗');
        logI('UpdateService', 'Context挂载状态: ${context.mounted}');
        
        if (context.mounted) {
          // 检查Context状态和Widget树
          logI('UpdateService', 'Context已挂载，正在检查Widget树状态...');
          
          try {
            // 使用PostFrameCallback确保在下一帧显示对话框，避免黑屏
            logI('UpdateService', '等待UI刷新完成再显示安装确认弹窗');
            
            bool? shouldInstall;
            // 等待更长时间，确保UI完全刷新
            await Future.delayed(const Duration(milliseconds: 1000));
            
            // 再次检查context状态
            if (context.mounted) {
              logI('UpdateService', '延迟后Context仍然挂载，开始显示安装确认弹窗');
              
              // 使用更简洁的方式显示对话框，避免复杂的导航栈操作
              shouldInstall = await _showInstallDialogSafely(context);
              logI('UpdateService', '安装确认弹窗返回结果: $shouldInstall');
            } else {
              logW('UpdateService', 'Context在延迟后变为未挂载状态');
              shouldInstall = false;
            }
            
            if (shouldInstall == true) {
              // 在安装前提供进度回调
              logI('UpdateService', '用户确认安装，开始启动安装程序');
              onProgress?.call(0.95, '正在启动安装...');
              
              // 确保在启动安装器之前，界面状态是正确的
              await Future.delayed(const Duration(milliseconds: 300));
              
              logI('UpdateService', '调用_installApk方法，文件路径: ${downloadResult.filePath}');
              final installed = await _installApk(downloadResult.filePath!);
              logI('UpdateService', '_installApk返回结果: $installed');
              
              if (installed) {
                onProgress?.call(1.0, '安装程序已启动');
                return UpdateResult(
                  hasUpdate: true,
                  success: true,
                  message: '下载完成，安装程序已启动',
                  filePath: downloadResult.filePath,
                );
              } else {
                onProgress?.call(1.0, '安装失败');
                return UpdateResult(
                  hasUpdate: true,
                  success: false,
                  message: '安装失败',
                  filePath: downloadResult.filePath,
                );
              }
            } else {
              // 用户选择稍后安装或弹窗被取消
              logI('UpdateService', '用户选择稍后安装或操作被取消');
              onProgress?.call(1.0, '下载完成');
              return UpdateResult(
                hasUpdate: true,
                success: true,
                message: '下载完成，可以手动安装',
                filePath: downloadResult.filePath,
              );
            }
          } catch (e) {
            logE('UpdateService', '显示安装确认弹窗过程中发生异常', e);
            onProgress?.call(1.0, '下载完成');
            return UpdateResult(
              hasUpdate: true,
              success: true,
              message: '下载完成，请手动安装（弹窗异常）',
              filePath: downloadResult.filePath,
            );
          }
        } else {
          // context未挂载，无法显示对话框
          logW('UpdateService', 'Context未挂载，无法显示安装确认弹窗');
          onProgress?.call(1.0, '下载完成');
          return UpdateResult(
            hasUpdate: true,
            success: true,
            message: '下载完成，请手动安装',
            filePath: downloadResult.filePath,
          );
        }
      } else {
        onProgress?.call(1.0, '下载失败');
        return UpdateResult(
          hasUpdate: false,
          success: false,
          message: downloadResult.message ?? '下载失败',
        );
      }
    } catch (e) {
      logE('UpdateService', '下载更新失败', e);
      onProgress?.call(1.0, '下载失败');
      return UpdateResult(
        hasUpdate: false,
        success: false,
        message: '下载失败: $e',
      );
    }
  }

  /// 检查和申请权限
  static Future<bool> _checkAndRequestPermissions() async {
    if (!Platform.isAndroid) return true;

    logI('UpdateService', '开始检查权限...');

    // Android 10以下需要存储权限
    if (Platform.version.contains('API') && 
        int.tryParse(Platform.version.split(' ').last) != null &&
        int.parse(Platform.version.split(' ').last) <= 29) {
      final storageStatus = await Permission.storage.status;
      logI('UpdateService', '存储权限状态: $storageStatus');
      if (!storageStatus.isGranted) {
        final result = await Permission.storage.request();
        logI('UpdateService', '存储权限申请结果: $result');
        if (!result.isGranted) {
          logW('UpdateService', '存储权限被拒绝');
          return false;
        }
      }
    }

    // 安装权限
    final installStatus = await Permission.requestInstallPackages.status;
    logI('UpdateService', '安装权限状态: $installStatus');
    if (!installStatus.isGranted) {
      final result = await Permission.requestInstallPackages.request();
      logI('UpdateService', '安装权限申请结果: $result');
      if (!result.isGranted) {
        logW('UpdateService', '安装权限被拒绝');
        return false;
      }
    }

    // 通知权限检查 (所有Android版本)
    try {
      final notificationStatus = await Permission.notification.status;
      logI('UpdateService', '通知权限状态: $notificationStatus');
      
      if (!notificationStatus.isGranted) {
        logI('UpdateService', '申请通知权限...');
        final result = await Permission.notification.request();
        logI('UpdateService', '通知权限申请结果: $result');
        
        if (!result.isGranted) {
          logW('UpdateService', '通知权限被拒绝，进度通知将不会显示，但不影响下载功能');
          // 存储通知权限被拒绝的状态，稍后显示用户指南
          _notificationPermissionDenied = true;
        } else {
          logI('UpdateService', '通知权限获取成功');
        }
      } else {
        logI('UpdateService', '通知权限已获取');
      }
    } catch (e) {
      logE('UpdateService', '检查通知权限失败', e);
    }

    logI('UpdateService', '权限检查完成');
    return true;
  }

  /// 初始化通知
  static Future<void> _initializeNotifications() async {
    if (_isNotificationInitialized) return;
    
    try {
      // Android 通知渠道设置
      const androidChannel = AndroidNotificationChannel(
        'update_download',
        '更新下载',
        description: 'APK更新文件下载进度',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      );
      
      // 创建通知渠道
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(androidChannel);
        logI('UpdateService', '通知渠道创建成功: ${androidChannel.id}');
        
        // 检查权限状态（Android 13+）
        final hasPermission = await androidImplementation.requestNotificationsPermission();
        logI('UpdateService', '通知权限状态: $hasPermission');
      }
      
      const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsIOS = DarwinInitializationSettings();
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      final initialized = await _notificationsPlugin.initialize(initializationSettings);
      _isNotificationInitialized = initialized == true;
      logI('UpdateService', '通知初始化结果: $initialized');
    } catch (e) {
      logE('UpdateService', '通知初始化失败', e);
    }
  }

  /// 显示下载进度通知
  static Future<void> _showProgressNotification(int progress, {bool indeterminate = false}) async {
    try {
      await _initializeNotifications();
      if (!_isNotificationInitialized) {
        logW('UpdateService', '通知未初始化，跳过显示进度');
        return;
      }
      
      final androidDetails = AndroidNotificationDetails(
        'update_download',
        '更新下载',
        channelDescription: 'APK更新文件下载进度',
        importance: Importance.low,
        priority: notifications.Priority.low,
        showProgress: true,
        maxProgress: 100,
        progress: progress,
        indeterminate: indeterminate,
        ongoing: true,
        autoCancel: false,
        playSound: false,
        enableVibration: false,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );
      
      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      
      final title = '蜜蜂记账更新下载';
      final body = indeterminate ? '正在下载新版本...' : '下载进度: $progress%';
      
      logI('UpdateService', '开始显示通知 - 标题: $title, 内容: $body, 进度: $progress, 不确定: $indeterminate');
      
      await _notificationsPlugin.show(
        0,
        title,
        body,
        details,
      );
      
      logI('UpdateService', '通知显示完成 - ID: 0, 进度: $progress%');
    } catch (e) {
      logE('UpdateService', '显示进度通知失败', e);
    }
  }

  /// 完成下载通知
  static Future<void> _showDownloadCompleteNotification(String filePath) async {
    try {
      await _initializeNotifications();
      if (!_isNotificationInitialized) {
        logW('UpdateService', '通知未初始化，跳过显示完成通知');
        return;
      }
      
      const androidDetails = AndroidNotificationDetails(
        'update_download',
        '更新下载',
        channelDescription: 'APK更新文件下载进度',
        importance: Importance.high,
        priority: notifications.Priority.high,
        playSound: true,
        enableVibration: true,
      );
      
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      
      await _notificationsPlugin.show(
        0,
        '下载完成',
        '新版本已下载完成，点击安装',
        details,
      );
      
      logI('UpdateService', '显示下载完成通知');
    } catch (e) {
      logE('UpdateService', '显示完成通知失败', e);
    }
  }

  /// 取消下载通知
  static Future<void> _cancelDownloadNotification() async {
    try {
      await _notificationsPlugin.cancel(0);
      logI('UpdateService', '取消下载通知');
    } catch (e) {
      logE('UpdateService', '取消通知失败', e);
    }
  }

  /// 下载APK文件
  static Future<UpdateResult> _downloadApk(
      BuildContext context, String url, String fileName, {
      Function(double progress, String status)? onProgress,
  }) async {
    try {
      // 获取下载目录
      Directory? downloadDir;
      if (Platform.isAndroid) {
        downloadDir = await getExternalStorageDirectory();
      }
      downloadDir ??= await getApplicationDocumentsDirectory();

      final filePath = '${downloadDir.path}/BeeCount_$fileName.apk';
      logI('UpdateService', '下载路径: $filePath');

      // 删除旧文件
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // 显示下载进度对话框和通知
      double progress = 0.0;
      bool cancelled = false;
      late StateSetter dialogSetState;

      // 重置进度记录
      _lastNotificationProgress = -1;

      // 创建取消令牌
      final cancelToken = CancelToken();

      // 显示初始通知 - 从确定进度0%开始
      await _showProgressNotification(0, indeterminate: false);

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              dialogSetState = setState;
              return AlertDialog(
                title: const Text('下载更新'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('下载中: ${(progress * 100).toStringAsFixed(1)}%'),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 16),
                    const Text('可以将应用切换到后台，下载会继续进行',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      cancelled = true;
                      cancelToken.cancel('用户取消下载');
                      Navigator.of(context).pop();
                    },
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('后台下载'),
                  ),
                ],
              );
            },
          ),
        );
      }
      
      // 开始下载
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && !cancelled) {
            final newProgress = received / total;
            progress = newProgress;
            final progressPercent = (progress * 100).round();
            
            // 调用外部进度回调  
            onProgress?.call(newProgress, '下载中: $progressPercent%');
            
            // 更新UI进度（如果对话框还在显示）
            try {
              if (context.mounted) {
                dialogSetState(() {});
              }
            } catch (e) {
              // 对话框已关闭，忽略错误
            }
            
            // 只有进度变化超过1%或者是关键节点时才更新通知（减少频率）
            if (_lastNotificationProgress == -1 || 
                progressPercent - _lastNotificationProgress >= 1 ||
                progressPercent == 0 ||
                progressPercent == 100) {
              _lastNotificationProgress = progressPercent;
              // 异步更新通知进度，不阻塞下载
              _showProgressNotification(progressPercent, indeterminate: false).catchError((e) {
                logE('UpdateService', '更新通知进度失败', e);
              });
            }
          }
        },
        cancelToken: cancelToken,
      );

      if (cancelled) {
        // 用户取消了下载，对话框已经通过取消按钮关闭，无需额外处理
        logI('UpdateService', '用户取消下载');
        await _cancelDownloadNotification();
        onProgress?.call(0.0, ''); // 立即清除进度状态
        return UpdateResult.userCancelled();
      }

      // 下载完成，强制关闭下载对话框
      logI('UpdateService', '下载完成，准备关闭下载进度对话框');
      if (context.mounted) {
        try {
          // 检查导航栈状态
          final canPop = Navigator.of(context).canPop();
          logI('UpdateService', '当前导航栈可以pop: $canPop');

          if (canPop) {
            // 直接关闭当前对话框
            Navigator.of(context).pop();
            logI('UpdateService', '下载进度对话框已关闭');
          } else {
            logW('UpdateService', '导航栈不能pop，可能对话框已经被关闭');
          }
        } catch (e) {
          logW('UpdateService', '关闭下载对话框失败: $e');
          // 如果直接pop失败，尝试查找并关闭所有对话框
          try {
            while (Navigator.of(context).canPop()) {
              logI('UpdateService', '强制关闭一个对话框');
              Navigator.of(context).pop();
            }
            logI('UpdateService', '强制关闭所有对话框完成');
          } catch (e2) {
            logE('UpdateService', '强制关闭对话框也失败: $e2');
          }
        }
      } else {
        logW('UpdateService', 'Context未挂载，无法关闭下载对话框');
      }

      // 等待对话框完全关闭，确保UI状态正常
      logI('UpdateService', '等待对话框完全关闭...');
      await Future.delayed(const Duration(milliseconds: 800));

      logI('UpdateService', '下载完成: $filePath');
      onProgress?.call(0.9, '下载完成');
      await _showDownloadCompleteNotification(filePath);
      onProgress?.call(1.0, '完成');
      return UpdateResult.downloadSuccess(filePath);
    } catch (e) {
      // 检查是否是用户取消导致的异常
      if (e is DioException && e.type == DioExceptionType.cancel) {
        logI('UpdateService', '用户取消下载（通过异常捕获）');
        await _cancelDownloadNotification();
        onProgress?.call(0.0, ''); // 清除进度状态
        return UpdateResult.userCancelled();
      }

      // 真正的下载错误
      logE('UpdateService', '下载失败', e);

      // 安全关闭下载对话框
      if (context.mounted) {
        try {
          // 检查是否有活跃的对话框需要关闭
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            // 等待对话框关闭动画完成
            await Future.delayed(const Duration(milliseconds: 300));
          }
        } catch (navError) {
          logE('UpdateService', '关闭下载对话框失败', navError);
        }
      }

      await _cancelDownloadNotification();
      onProgress?.call(0.0, ''); // 清除进度状态
      return UpdateResult.error('下载失败: $e');
    }
  }

  /// 安装APK
  static Future<bool> _installApk(String filePath) async {
    try {
      logI('UpdateService', '开始安装APK: $filePath');
      final result = await OpenFilex.open(filePath);
      logI('UpdateService', '安装结果: ${result.message}');
      return result.type == ResultType.done;
    } catch (e) {
      logE('UpdateService', '安装APK失败', e);
      return false;
    }
  }

  /// 显示更新提示对话框
  static Future<bool> _showUpdateDialog(
      BuildContext context, String title, String description) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('发现新版本：$title'),
        content: SingleChildScrollView(
          child: Text(description.isEmpty ? '是否下载并安装更新？' : description),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
              side: BorderSide(color: Theme.of(context).primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('稍后'),
          ),
          const SizedBox(width: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('下载'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 安全地显示安装确认对话框 - 避免黑屏问题
  static Future<bool> _showInstallDialogSafely(BuildContext context) async {
    logI('UpdateService', '=== 安全显示安装确认对话框 ===');
    
    if (!context.mounted) {
      logW('UpdateService', 'Context未挂载，无法显示安装确认对话框');
      return false;
    }
    
    try {
      // 使用Completer来更好地控制异步操作
      final completer = Completer<bool>();
      
      // 确保在下一帧显示对话框
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          logI('UpdateService', 'PostFrameCallback: 开始显示安装确认对话框');
          showDialog<bool>(
            context: context,
            barrierDismissible: false,
            useRootNavigator: false, // 不使用根导航器，避免层级问题
            builder: (dialogContext) {
              logI('UpdateService', '安装确认对话框Builder被调用');
              return AlertDialog(
                title: const Text('下载完成'),
                content: const Text('APK文件下载完成，是否立即安装？\n\n注意：安装时应用会暂时退到后台，这是正常现象。'),
                actions: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                      side: BorderSide(color: Theme.of(context).primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      logI('UpdateService', '用户点击"稍后安装"按钮');
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        completer.complete(false);
                      }
                    },
                    child: const Text('稍后安装'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      logI('UpdateService', '用户点击"立即安装"按钮');
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        completer.complete(true);
                      }
                    },
                    child: const Text('立即安装'),
                  ),
                ],
              );
            },
          ).then((result) {
            if (!completer.isCompleted) {
              logI('UpdateService', 'showDialog then回调: $result');
              completer.complete(result ?? false);
            }
          }).catchError((error) {
            logE('UpdateService', 'showDialog发生错误', error);
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          });
        } else {
          logW('UpdateService', 'PostFrameCallback: Context未挂载');
          completer.complete(false);
        }
      });
      
      // 等待对话框完成
      final result = await completer.future;
      logI('UpdateService', '=== 安全显示安装确认对话框完成，结果: $result ===');
      return result;
      
    } catch (e) {
      logE('UpdateService', '安全显示安装确认对话框异常', e);
      return false;
    }
  }

  /// 显示安装确认对话框
  static Future<bool> _showInstallDialog(BuildContext context) async {
    logI('UpdateService', '=== 开始显示安装确认对话框 ===');
    logI('UpdateService', 'Context挂载状态: ${context.mounted}');
    
    if (!context.mounted) {
      logW('UpdateService', 'Context未挂载，无法显示安装确认对话框');
      return false;
    }
    
    // 检查导航栈状态
    try {
      final canPush = Navigator.of(context).canPop();
      logI('UpdateService', '当前可以pop的导航栈状态: $canPush');
      
      // 检查是否已经有其他对话框在显示
      final overlay = Overlay.of(context);
      logI('UpdateService', 'Overlay状态: ${overlay != null}');
      
    } catch (e) {
      logE('UpdateService', '检查导航栈状态失败', e);
    }
    
    logI('UpdateService', '准备调用showDialog显示安装确认对话框');
    
    bool? result;
    try {
      result = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // 防止意外关闭
        useRootNavigator: true, // 确保使用根导航器
        builder: (dialogContext) {
          logI('UpdateService', '安装确认对话框Builder被调用');
          return AlertDialog(
            title: const Text('下载完成'),
            content: const Text('APK文件下载完成，是否立即安装？\n\n注意：安装时应用会暂时退到后台，这是正常现象。'),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                  side: BorderSide(color: Theme.of(context).primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  logI('UpdateService', '用户点击"稍后安装"按钮');
                  try {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(false);
                      logI('UpdateService', '稍后安装 - 对话框已关闭');
                    } else {
                      logW('UpdateService', '稍后安装 - dialogContext未挂载');
                    }
                  } catch (e) {
                    logE('UpdateService', '稍后安装按钮处理失败', e);
                  }
                },
                child: const Text('稍后安装'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  logI('UpdateService', '用户点击"立即安装"按钮');
                  try {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                      logI('UpdateService', '立即安装 - 对话框已关闭');
                    } else {
                      logW('UpdateService', '立即安装 - dialogContext未挂载');
                    }
                  } catch (e) {
                    logE('UpdateService', '立即安装按钮处理失败', e);
                  }
                },
                child: const Text('立即安装'),
              ),
            ],
          );
        },
      );
      logI('UpdateService', 'showDialog调用完成，结果: $result');
    } catch (e) {
      logE('UpdateService', 'showDialog调用失败', e);
      result = false;
    }
    
    logI('UpdateService', '=== 安装确认对话框返回结果: $result ===');
    return result ?? false;
  }

  /// 显示通知权限指南对话框
  static Future<void> _showNotificationGuideDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications_off, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Text('通知权限被拒绝'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '无法获得通知权限，下载进度将不会在通知栏显示，但下载功能正常。',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                '如需开启通知，请按以下步骤操作：',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildGuideStep('1', '打开系统设置'),
              _buildGuideStep('2', '找到「应用管理」或「应用设置」'),
              _buildGuideStep('3', '找到「蜜蜂记账」应用'),
              _buildGuideStep('4', '点击「权限管理」或「通知管理」'),
              _buildGuideStep('5', '开启「通知权限」'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'MIUI用户：小米系统对通知权限管控较严，可能需要在安全中心中额外设置',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// 构建指南步骤小部件
  static Widget _buildGuideStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }


  // 下面是从mine_page.dart复制的辅助方法
  static Future<_AppInfo> _getAppInfo() async {
    final p = await PackageInfo.fromPlatform();
    final commit = const String.fromEnvironment('GIT_COMMIT');
    final buildTime = const String.fromEnvironment('BUILD_TIME');
    final ciVersion = const String.fromEnvironment('CI_VERSION');

    final version = ciVersion.isNotEmpty ? ciVersion : 'dev-${p.version}';

    return _AppInfo(version, p.buildNumber,
        commit: commit.isEmpty ? null : commit,
        buildTime: buildTime.isEmpty ? null : buildTime);
  }

  static String _normalizeVersion(String version) {
    String normalized = version;
    if (normalized.startsWith('v')) {
      normalized = normalized.substring(1);
    }
    if (normalized.startsWith('dev-')) {
      normalized = normalized.substring(4);
    }
    final dashIndex = normalized.indexOf('-');
    if (dashIndex != -1) {
      normalized = normalized.substring(0, dashIndex);
    }
    return normalized;
  }

  static bool _isNewerVersion(String newVersion, String currentVersion) {
    final newParts = newVersion
        .split('.')
        .map(int.tryParse)
        .where((e) => e != null)
        .cast<int>()
        .toList();
    final currentParts = currentVersion
        .split('.')
        .map(int.tryParse)
        .where((e) => e != null)
        .cast<int>()
        .toList();

    final maxLength = [newParts.length, currentParts.length].reduce((a, b) => a > b ? a : b);
    while (newParts.length < maxLength) {
      newParts.add(0);
    }
    while (currentParts.length < maxLength) {
      currentParts.add(0);
    }

    for (int i = 0; i < maxLength; i++) {
      if (newParts[i] > currentParts[i]) return true;
      if (newParts[i] < currentParts[i]) return false;
    }

    return false;
  }

  /// 完整的更新检查流程，包含UI交互
  static Future<void> checkUpdateWithUI(
    BuildContext context, {
    required Function(bool loading) setLoading,
    required Function(double progress, String status) setProgress,
  }) async {
    // 防重复点击
    if (Platform.isAndroid) {
      setLoading(true);
      setProgress(0.0, '正在检查更新...');

      try {
        // Android: 先检查更新
        final checkResult = await checkUpdate();

        if (!context.mounted) return;

        if (!checkResult.hasUpdate) {
          // 检查是否是网络错误或API错误，提供兜底方案
          final message = checkResult.message ?? '当前已是最新版本';
          final isNetworkError = message.contains('检查更新失败') ||
                                 message.contains('HTTP') ||
                                 message.contains('异常') ||
                                 message.contains('失败');
          if (isNetworkError) {
            // 网络错误或API错误，提供去GitHub的兜底选项
            await _showUpdateErrorWithFallback(context, message);
          } else {
            // 正常情况（已是最新版本）
            await AppDialog.info(
              context,
              title: '检查更新',
              message: message,
            );
          }
          return;
        }

        // 发现有新版本，显示确认对话框
        // 重置进度和加载状态，显示确认对话框
        setLoading(false);
        setProgress(0.0, '');

        final shouldDownload = await _showDownloadConfirmDialog(
          context,
          checkResult.version ?? '',
          checkResult.releaseNotes ?? '',
        );

        if (!shouldDownload || !context.mounted) {
          // 用户取消下载，完全清除状态显示
          setLoading(false);
          setProgress(0.0, '');
          return;
        }

        // 用户确认下载，开始下载过程
        final downloadResult = await downloadAndInstallUpdate(
          context,
          checkResult.downloadUrl!,
          onProgress: setProgress,
        );

        if (!context.mounted) return;

        if (!downloadResult.success && downloadResult.message != null) {
          // 检查是否是用户取消，如果是则不显示错误弹窗
          if (downloadResult.type == UpdateResultType.userCancelled) {
            // 用户取消下载，什么都不做，静默返回
            return;
          }

          // 等待一段时间确保下载对话框完全关闭，避免黑屏
          await Future.delayed(const Duration(milliseconds: 500));

          // 再次检查context是否仍然有效
          if (!context.mounted) return;

          // 显示下载错误信息，并提供GitHub fallback
          await _showDownloadErrorWithFallback(context, downloadResult.message!);
        }
        // 成功下载的情况不需要额外提示，UpdateService内部已处理
      } catch (e) {
        if (context.mounted) {
          await _showUpdateErrorWithFallback(context, '检查更新失败: $e');
        }
      } finally {
        setLoading(false);
        setProgress(0.0, '');
      }
    }
  }

  /// 显示下载确认对话框
  static Future<bool> _showDownloadConfirmDialog(
    BuildContext context,
    String version,
    String releaseNotes,
  ) async {
    if (!context.mounted) return false;

    final message = releaseNotes.isEmpty ? '发现新版本，是否立即下载？' : '更新内容：\n\n$releaseNotes';

    return await AppDialog.confirm<bool>(
      context,
      title: '发现新版本 $version',
      message: message,
      cancelLabel: '取消',
      okLabel: '下载更新',
    ) ?? false;
  }

  /// 显示更新检测失败的错误弹窗，提供去GitHub的兜底选项
  static Future<void> _showUpdateErrorWithFallback(
    BuildContext context,
    String errorMessage,
  ) async {
    if (!context.mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Text('检测更新失败'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '无法自动检测更新：\n$errorMessage',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '您可以手动前往GitHub Releases页面查看和下载最新版本',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
              side: BorderSide(color: Theme.of(context).primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('前往GitHub'),
          ),
        ],
      ),
    );
    if (result == true && context.mounted) {
      await _launchGitHubReleases(context);
    }
  }

  /// 显示下载失败的错误弹窗，提供去GitHub的兜底选项
  static Future<void> _showDownloadErrorWithFallback(
    BuildContext context,
    String errorMessage,
  ) async {
    if (!context.mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Text('下载失败'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '下载更新文件失败：\n$errorMessage',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '您可以手动前往GitHub Releases页面下载最新版本APK文件',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
              side: BorderSide(color: Theme.of(context).primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('前往GitHub'),
          ),
        ],
      ),
    );
    if (result == true && context.mounted) {
      await _launchGitHubReleases(context);
    }
  }

  /// 启动GitHub Releases页面
  static Future<void> _launchGitHubReleases(BuildContext context) async {
    final uri = Uri.parse('https://github.com/TNT-Likely/BeeCount/releases');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // 如果无法打开，显示提示
        if (context.mounted) {
          await AppDialog.info(
            context,
            title: '无法打开链接',
            message: '请手动在浏览器中访问：\nhttps://github.com/TNT-Likely/BeeCount/releases',
          );
        }
      }
    } catch (e) {
      // 打开链接失败，显示提示
      if (context.mounted) {
        await AppDialog.info(
          context,
          title: '无法打开链接',
          message: '请手动在浏览器中访问：\nhttps://github.com/TNT-Likely/BeeCount/releases',
        );
      }
    }
  }
}

/// 更新结果类
class UpdateResult {
  final bool hasUpdate;
  final bool success;
  final String? message;
  final String? filePath;
  final String? version;
  final String? downloadUrl;
  final String? releaseNotes;
  final UpdateResultType? type;

  UpdateResult({
    this.hasUpdate = false,
    this.success = false,
    this.message,
    this.filePath,
    this.version,
    this.downloadUrl,
    this.releaseNotes,
    this.type,
  });

  UpdateResult._({
    required this.success,
    this.hasUpdate = false,
    this.message,
    this.filePath,
    this.version,
    this.downloadUrl,
    this.releaseNotes,
    required this.type,
  });

  factory UpdateResult.downloadSuccess(String filePath) => UpdateResult._(
        success: true,
        filePath: filePath,
        type: UpdateResultType.downloadSuccess,
      );

  factory UpdateResult.alreadyLatest(String version) => UpdateResult._(
        success: true,
        message: '当前已是最新版本 $version',
        type: UpdateResultType.alreadyLatest,
      );

  factory UpdateResult.userCancelled() => UpdateResult._(
        success: false,
        message: '用户取消',
        type: UpdateResultType.userCancelled,
      );

  factory UpdateResult.permissionDenied() => UpdateResult._(
        success: false,
        message: '权限被拒绝',
        type: UpdateResultType.permissionDenied,
      );

  factory UpdateResult.networkError(String message) => UpdateResult._(
        success: false,
        message: message,
        type: UpdateResultType.networkError,
      );

  factory UpdateResult.noApkFound() => UpdateResult._(
        success: false,
        message: '未找到APK文件',
        type: UpdateResultType.noApkFound,
      );

  factory UpdateResult.error(String message) => UpdateResult._(
        success: false,
        message: message,
        type: UpdateResultType.error,
      );
}

enum UpdateResultType {
  downloadSuccess,
  alreadyLatest,
  userCancelled,
  permissionDenied,
  networkError,
  noApkFound,
  error,
}

class _AppInfo {
  final String version;
  final String buildNumber;
  final String? commit;
  final String? buildTime;
  
  const _AppInfo(this.version, this.buildNumber, {this.commit, this.buildTime});
}