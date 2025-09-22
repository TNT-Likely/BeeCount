import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/logger.dart';
import '../../l10n/app_localizations.dart';
import 'update_result.dart';
import 'update_notifications.dart';

/// 更新下载管理类
class UpdateDownloader {
  UpdateDownloader._();

  static final Dio _dio = Dio();

  /// 生成随机User-Agent，避免被GitHub限制
  static String _generateRandomUserAgent() {
    final userAgents = [
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/119.0',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/119.0',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36 Edg/119.0.0.0',
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
      'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/119.0',
    ];

    // 使用时间戳作为随机种子，确保每次调用都可能不同
    final random = (DateTime.now().millisecondsSinceEpoch % userAgents.length);
    final selectedUA = userAgents[random];

    logI('UpdateDownloader', '使用User-Agent: ${selectedUA.substring(0, 50)}...');
    return selectedUA;
  }

  /// 下载APK文件
  static Future<UpdateResult> downloadApk(
    BuildContext context,
    String url,
    String fileName, {
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
      logI('UpdateDownloader', '下载路径: $filePath');

      // 只删除当前要下载的文件（如果存在），保留其他版本的缓存
      final file = File(filePath);
      if (await file.exists()) {
        logI('UpdateDownloader', '删除已存在的同版本文件: $filePath');
        await file.delete();
      }

      // 显示下载进度对话框和通知
      double progress = 0.0;
      bool cancelled = false;
      late StateSetter dialogSetState;

      // 重置进度记录
      UpdateNotifications.resetProgress();

      // 创建取消令牌
      final cancelToken = CancelToken();

      // 显示初始通知 - 从确定进度0%开始
      await UpdateNotifications.showProgressNotification(0, indeterminate: false);

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              dialogSetState = setState;
              return AlertDialog(
                title: Text(AppLocalizations.of(context).updateDownloadTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppLocalizations.of(context).updateDownloading((progress * 100).toStringAsFixed(1))),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context).updateDownloadBackgroundHint,
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      cancelled = true;
                      cancelToken.cancel('User cancelled download');
                      Navigator.of(context).pop();
                    },
                    child: Text(AppLocalizations.of(context).updateCancelButton),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(AppLocalizations.of(context).updateBackgroundDownload),
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
        options: Options(
          headers: {
            'User-Agent': _generateRandomUserAgent(),
          },
        ),
        onReceiveProgress: (received, total) {
          if (total > 0 && !cancelled) {
            final newProgress = received / total;
            progress = newProgress;
            final progressPercent = (progress * 100).round();

            // 调用外部进度回调
            onProgress?.call(newProgress, context.mounted ? AppLocalizations.of(context).updateDownloadProgress('$progressPercent') : 'Downloading: $progressPercent%');

            // 更新UI进度（如果对话框还在显示）
            try {
              if (context.mounted) {
                dialogSetState(() {});
              }
            } catch (e) {
              // 对话框已关闭，忽略错误
            }

            // 只有进度变化超过1%或者是关键节点时才更新通知（减少频率）
            if (UpdateNotifications.shouldUpdateProgress(progressPercent)) {
              UpdateNotifications.recordProgress(progressPercent);
              // 异步更新通知进度，不阻塞下载
              UpdateNotifications.showProgressNotification(progressPercent, indeterminate: false)
                  .catchError((e) {
                logE('UpdateDownloader', '更新通知进度失败', e);
              });
            }
          }
        },
        cancelToken: cancelToken,
      );

      if (cancelled) {
        // 用户取消了下载，对话框已经通过取消按钮关闭，无需额外处理
        logI('UpdateDownloader', '用户取消下载');
        await UpdateNotifications.cancelDownloadNotification();
        onProgress?.call(0.0, ''); // 立即清除进度状态
        return UpdateResult.userCancelled();
      }

      // 下载完成，强制关闭下载对话框
      logI('UpdateDownloader', '下载完成，准备关闭下载进度对话框');
      if (context.mounted) {
        try {
          // 检查导航栈状态
          final canPop = Navigator.of(context).canPop();
          logI('UpdateDownloader', '当前导航栈可以pop: $canPop');

          if (canPop) {
            // 直接关闭当前对话框
            Navigator.of(context).pop();
            logI('UpdateDownloader', '下载进度对话框已关闭');
          } else {
            logW('UpdateDownloader', '导航栈不能pop，可能对话框已经被关闭');
          }
        } catch (e) {
          logW('UpdateDownloader', '关闭下载对话框失败: $e');
          // 如果直接pop失败，尝试查找并关闭所有对话框
          try {
            while (Navigator.of(context).canPop()) {
              logI('UpdateDownloader', '强制关闭一个对话框');
              Navigator.of(context).pop();
            }
            logI('UpdateDownloader', '强制关闭所有对话框完成');
          } catch (e2) {
            logE('UpdateDownloader', '强制关闭对话框也失败: $e2');
          }
        }
      } else {
        logW('UpdateDownloader', 'Context未挂载，无法关闭下载对话框');
      }

      // 等待对话框完全关闭，确保UI状态正常
      logI('UpdateDownloader', '等待对话框完全关闭...');
      await Future.delayed(const Duration(milliseconds: 800));

      logI('UpdateDownloader', '下载完成: $filePath');
      onProgress?.call(0.9, '下载完成');

      await UpdateNotifications.showDownloadCompleteNotification(filePath);
      onProgress?.call(1.0, '完成');
      return UpdateResult.downloadSuccess(filePath);
    } catch (e) {
      // 检查是否是用户取消导致的异常
      if (e is DioException && e.type == DioExceptionType.cancel) {
        logI('UpdateDownloader', '用户取消下载（通过异常捕获）');
        await UpdateNotifications.cancelDownloadNotification();
        onProgress?.call(0.0, ''); // 清除进度状态
        return UpdateResult.userCancelled();
      }

      // 真正的下载错误
      logE('UpdateDownloader', '下载失败', e);

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
          logE('UpdateDownloader', '关闭下载对话框失败', navError);
        }
      }

      await UpdateNotifications.cancelDownloadNotification();
      onProgress?.call(0.0, ''); // 清除进度状态
      return UpdateResult.downloadFailed('$e');
    }
  }
}