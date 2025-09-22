import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ui/ui.dart';
import '../../utils/logger.dart';

/// 更新对话框管理类
class UpdateDialogs {
  UpdateDialogs._();

  /// 显示安装确认对话框
  static Future<bool> showInstallDialog(BuildContext context) async {
    logI('UpdateDialogs', '=== 开始显示安装确认对话框 ===');
    logI('UpdateDialogs', 'Context挂载状态: ${context.mounted}');

    if (!context.mounted) {
      logW('UpdateDialogs', 'Context未挂载，无法显示安装确认对话框');
      return false;
    }

    logI('UpdateDialogs', '准备调用AppDialog.confirm显示安装确认对话框');

    try {
      final result = await AppDialog.confirm<bool>(
        context,
        title: AppLocalizations.of(context).updateDownloadCompleteTitle,
        message: AppLocalizations.of(context).updateInstallConfirmMessage,
      );

      logI('UpdateDialogs', '安装确认对话框结果: $result');
      return result ?? false;
    } catch (e) {
      logE('UpdateDialogs', '显示安装确认对话框失败', e);
      return false;
    }
  }

  /// 显示通知权限指南对话框
  static Future<void> showNotificationGuideDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).updateNotificationPermissionTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).updateNotificationPermissionGuideText,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              _buildGuideStep('1', AppLocalizations.of(context).updateNotificationGuideStep1),
              const SizedBox(height: 8),
              _buildGuideStep('2', AppLocalizations.of(context).updateNotificationGuideStep2),
              const SizedBox(height: 8),
              _buildGuideStep('3', AppLocalizations.of(context).updateNotificationGuideStep3),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).updateNotificationGuideInfo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).updateOk),
          ),
        ],
      ),
    );
  }

  /// 构建指南步骤小部件
  static Widget _buildGuideStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  /// 显示下载确认对话框
  static Future<bool> showDownloadConfirmDialog(
    BuildContext context,
    String version,
    String releaseNotes,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).updateNewVersionTitle(version)),
        content: SingleChildScrollView(
          child: Text(releaseNotes.isEmpty ? AppLocalizations.of(context).updateConfirmDownload : releaseNotes),
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
            child: Text(AppLocalizations.of(context).updateLaterButton),
          ),
          const SizedBox(width: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).updateDownloadButton),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 显示更新检测失败的错误弹窗，提供去GitHub的兜底选项
  static Future<void> showUpdateErrorWithFallback(
    BuildContext context,
    String error,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).updateCheckFailedTitle),
        content: Text(error),
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
            child: Text(AppLocalizations.of(context).updateCancelButton),
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
            label: Text(AppLocalizations.of(context).updateGoToGitHub),
          ),
        ],
      ),
    );

    if (result == true) {
      await launchGitHubReleases(context);
    }
  }

  /// 显示下载失败的错误弹窗，提供去GitHub的兜底选项
  static Future<void> showDownloadErrorWithFallback(
    BuildContext context,
    String error,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).updateDownloadFailedTitle),
        content: Text(error),
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
            child: Text(AppLocalizations.of(context).updateCancelButton),
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
            label: Text(AppLocalizations.of(context).updateGoToGitHub),
          ),
        ],
      ),
    );

    if (result == true) {
      await launchGitHubReleases(context);
    }
  }

  /// 启动GitHub Releases页面
  static Future<void> launchGitHubReleases(BuildContext context) async {
    const url = 'https://github.com/TNT-Likely/BeeCount/releases';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Cannot open link');
      }
    } catch (e) {
      logE('UpdateDialogs', '打开GitHub链接失败', e);

      // 如果无法打开，显示提示
      if (context.mounted) {
        await AppDialog.info(
          context,
          title: AppLocalizations.of(context).updateCannotOpenLinkTitle,
          message: AppLocalizations.of(context).updateManualVisit,
        );
      }
    }
  }
}