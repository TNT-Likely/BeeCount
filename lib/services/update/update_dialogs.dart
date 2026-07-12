import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ui/ui.dart';
import '../../styles/tokens.dart';
import '../system/logger_service.dart';
import 'github_mirror_service.dart';

/// 更新对话框管理类
class UpdateDialogs {
  UpdateDialogs._();

  /// 显示安装确认对话框
  static Future<bool> showInstallDialog(BuildContext context) async {
    logger.info('UpdateDialogs', '=== 开始显示安装确认对话框 ===');
    logger.info('UpdateDialogs', 'Context挂载状态: ${context.mounted}');

    if (!context.mounted) {
      logger.warning('UpdateDialogs', 'Context未挂载，无法显示安装确认对话框');
      return false;
    }

    logger.info('UpdateDialogs', '准备调用AppDialog.confirm显示安装确认对话框');

    try {
      final result = await AppDialog.confirm<bool>(
        context,
        title: AppLocalizations.of(context).updateDownloadCompleteTitle,
        message: AppLocalizations.of(context).updateInstallConfirmMessage,
      );

      logger.info('UpdateDialogs', '安装确认对话框结果: $result');
      return result ?? false;
    } catch (e) {
      logger.error('UpdateDialogs', '显示安装确认对话框失败', e);
      return false;
    }
  }

  /// 显示通知权限指南对话框
  static Future<void> showNotificationGuideDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            AppLocalizations.of(context).updateNotificationPermissionTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)
                    .updateNotificationPermissionGuideText,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              _buildGuideStep('1',
                  AppLocalizations.of(context).updateNotificationGuideStep1),
              const SizedBox(height: 8),
              _buildGuideStep('2',
                  AppLocalizations.of(context).updateNotificationGuideStep2),
              const SizedBox(height: 8),
              _buildGuideStep('3',
                  AppLocalizations.of(context).updateNotificationGuideStep3),
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
                        AppLocalizations.of(context)
                            .updateNotificationGuideInfo,
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
      builder: (context) => _DownloadConfirmDialog(
        version: version,
        releaseNotes: releaseNotes,
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
      logger.error('UpdateDialogs', '打开GitHub链接失败', e);

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

  /// 显示镜像选择对话框
  /// 返回选择的镜像，如果用户取消则返回 null
  static Future<GitHubMirror?> showMirrorSelectDialog(
    BuildContext context, {
    bool showTestButton = true,
  }) async {
    return showDialog<GitHubMirror>(
      context: context,
      builder: (context) => _MirrorSelectDialog(showTestButton: showTestButton),
    );
  }
}

/// 镜像选择对话框
class _MirrorSelectDialog extends StatefulWidget {
  final bool showTestButton;

  const _MirrorSelectDialog({required this.showTestButton});

  @override
  State<_MirrorSelectDialog> createState() => _MirrorSelectDialogState();
}

class _MirrorSelectDialogState extends State<_MirrorSelectDialog> {
  String? _selectedMirrorId;
  bool _isTesting = false;
  Map<String, MirrorTestResult> _testResults = {};
  int _testCompleted = 0;
  int _testTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadSelectedMirror();
  }

  Future<void> _loadSelectedMirror() async {
    final selectedId = await GitHubMirrorService.getSelectedMirrorId();
    if (mounted) {
      setState(() {
        _selectedMirrorId = selectedId;
      });
    }
  }

  Future<void> _testAllMirrors() async {
    setState(() {
      _isTesting = true;
      _testResults = {};
      _testCompleted = 0;
      _testTotal = GitHubMirrorService.mirrors.length;
    });

    final results = await GitHubMirrorService.testAllMirrors(
      onProgress: (completed, total) {
        if (mounted) {
          setState(() {
            _testCompleted = completed;
            _testTotal = total;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        for (final result in results) {
          _testResults[result.mirror.id] = result;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';

    return AlertDialog(
      title: Text(l10n.updateMirrorSelectTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.updateMirrorSelectHint,
              style: TextStyle(
                fontSize: 13,
                color: BeeTokens.textSecondary(context),
              ),
            ),
            const SizedBox(height: 12),
            if (_isTesting)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value:
                          _testTotal > 0 ? _testCompleted / _testTotal : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.updateMirrorTesting(_testCompleted, _testTotal),
                      style: TextStyle(
                        fontSize: 12,
                        color: BeeTokens.textTertiary(context),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: GitHubMirrorService.mirrors.length,
                itemBuilder: (context, index) {
                  final mirror = GitHubMirrorService.mirrors[index];
                  final testResult = _testResults[mirror.id];
                  final isSelected = _selectedMirrorId == mirror.id;

                  return RadioListTile<String>(
                    value: mirror.id,
                    groupValue: _selectedMirrorId,
                    onChanged: _isTesting
                        ? null
                        : (value) {
                            setState(() {
                              _selectedMirrorId = value;
                            });
                          },
                    title: Text(
                      isZh ? mirror.name : mirror.nameEn,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: testResult != null
                        ? Text(
                            isZh
                                ? testResult.latencyText
                                : testResult.latencyTextEn,
                            style: TextStyle(
                              fontSize: 12,
                              color: testResult.isAvailable
                                  ? (testResult.latency < 300
                                      ? Colors.green
                                      : (testResult.latency < 800
                                          ? Colors.orange
                                          : Colors.red))
                                  : Colors.red,
                            ),
                          )
                        : (mirror.isDefault
                            ? Text(
                                l10n.updateMirrorDirectHint,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: BeeTokens.textTertiary(context),
                                ),
                              )
                            : null),
                    secondary: testResult != null
                        ? Icon(
                            testResult.isAvailable
                                ? Icons.check_circle
                                : Icons.error,
                            color: testResult.isAvailable
                                ? Colors.green
                                : Colors.red,
                            size: 20,
                          )
                        : null,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.showTestButton)
          TextButton.icon(
            onPressed: _isTesting ? null : _testAllMirrors,
            icon: _isTesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.speed, size: 18),
            label: Text(l10n.updateMirrorTestButton),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _isTesting || _selectedMirrorId == null
              ? null
              : () async {
                  final mirror =
                      GitHubMirrorService.getMirrorById(_selectedMirrorId!);
                  if (mirror != null) {
                    await GitHubMirrorService.setSelectedMirrorId(mirror.id);
                    if (context.mounted) {
                      Navigator.of(context).pop(mirror);
                    }
                  }
                },
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }
}

/// 下载确认对话框（带镜像选择）
class _DownloadConfirmDialog extends StatefulWidget {
  final String version;
  final String releaseNotes;

  const _DownloadConfirmDialog({
    required this.version,
    required this.releaseNotes,
  });

  @override
  State<_DownloadConfirmDialog> createState() => _DownloadConfirmDialogState();
}

class _DownloadConfirmDialogState extends State<_DownloadConfirmDialog> {
  String _currentMirrorName = 'GitHub 直连';

  @override
  void initState() {
    super.initState();
    _loadCurrentMirror();
  }

  Future<void> _loadCurrentMirror() async {
    final mirror = await GitHubMirrorService.getSelectedMirror();
    if (mounted) {
      setState(() {
        _currentMirrorName = mirror.name;
      });
    }
  }

  Future<void> _openMirrorSelect() async {
    final result = await UpdateDialogs.showMirrorSelectDialog(context);
    if (result != null && mounted) {
      setState(() {
        _currentMirrorName = result.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.updateNewVersionTitle(widget.version)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.releaseNotes.isEmpty
                ? l10n.updateConfirmDownload
                : widget.releaseNotes),
            const SizedBox(height: 16),
            // 镜像选择入口
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openMirrorSelect,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.08),
                        Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.03),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // 图标容器
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.rocket_launch_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 文字内容
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.updateMirrorSettingTitle,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: BeeTokens.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentMirrorName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // 箭头
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
          child: Text(l10n.updateLaterButton),
        ),
        const SizedBox(width: 12),
        FilledButton(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.updateDownloadButton),
        ),
      ],
    );
  }
}
