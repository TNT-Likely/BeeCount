import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../utils/file_picker_helper.dart';
import '../../providers/font_scale_provider.dart';
import '../../providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/export/config_export_service.dart';
import '../../services/system/logger_service.dart';

/// 配置导入导出页面
class ConfigImportExportPage extends ConsumerStatefulWidget {
  const ConfigImportExportPage({super.key});

  @override
  ConsumerState<ConfigImportExportPage> createState() =>
      _ConfigImportExportPageState();
}

class _ConfigImportExportPageState
    extends ConsumerState<ConfigImportExportPage> {
  bool _isExporting = false;
  bool _isImporting = false;
  String? _lastExportedFilePath;

  /// 获取配置导出目录
  Future<Directory> _getExportDirectory() async {
    if (Platform.isAndroid) {
      // Android: 保存到公共 Download/BeeCount 目录
      final downloadPath = '/storage/emulated/0/Download/BeeCount';
      final dir = Directory(downloadPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } else {
      // iOS: 使用分享功能
      return await getTemporaryDirectory();
    }
  }

  Future<void> _exportConfig() async {
    // Step 1: 显示选择导出内容对话框
    final options = await showDialog<ExportOptions>(
      context: context,
      builder: (context) => _ExportOptionsDialog(ref: ref),
    );

    if (options == null || !mounted) return;

    setState(() {
      _isExporting = true;
      _lastExportedFilePath = null;
    });

    try {
      // 获取仓库和当前账本ID
      final repo = ref.read(repositoryProvider);
      final ledgerId = ref.read(currentLedgerIdProvider);

      // Step 2: 生成预览内容
      final yamlContent = await ConfigExportService.exportToYaml(
        repository: repo,
        ledgerId: ledgerId,
        options: options,
      );

      if (!mounted) return;

      // Step 3: 显示预览并确认导出
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => _ExportPreviewDialog(yamlContent: yamlContent),
      );

      if (confirm != true || !mounted) {
        setState(() => _isExporting = false);
        return;
      }

      // Step 4: 执行导出
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'beecount_config_$timestamp.yml';

      if (Platform.isAndroid) {
        // Android: 直接保存到 Download/BeeCount 目录
        final exportDir = await _getExportDirectory();
        final filePath = '${exportDir.path}/$fileName';

        final file = File(filePath);
        await file.writeAsString(yamlContent);

        logger.info('ConfigExport', '配置已导出到: $filePath');

        if (!mounted) return;

        setState(() {
          _lastExportedFilePath = filePath;
        });

        showToast(context, AppLocalizations.of(context).configExportSuccess);
      } else {
        // iOS: 使用分享功能
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';

        final file = File(filePath);
        await file.writeAsString(yamlContent);

        if (!mounted) return;

        final result = await Share.shareXFiles(
          [XFile(filePath)],
          subject: AppLocalizations.of(context).configExportShareSubject,
        );

        if (result.status == ShareResultStatus.success) {
          if (!mounted) return;
          showToast(context, AppLocalizations.of(context).configExportSuccess);
        }
      }
    } catch (e) {
      logger.error('ConfigExport', '导出配置失败: $e');
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: AppLocalizations.of(context).configExportFailed,
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  /// 查看配置文件内容
  Future<void> _viewExportedContent() async {
    if (_lastExportedFilePath == null) return;

    try {
      final file = File(_lastExportedFilePath!);
      final content = await file.readAsString();

      if (!mounted) return;
      final dialogContext = context;
      final l10n = AppLocalizations.of(context);

      await showDialog(
        context: dialogContext,
        builder: (context) => _ConfigContentDialog(
          content: content,
          onCopy: () async {
            await Clipboard.setData(ClipboardData(text: content));
            if (!mounted) return;
            Navigator.pop(context);
            showToast(dialogContext, l10n.configExportContentCopied);
          },
        ),
      );
    } catch (e) {
      logger.error('ConfigExport', '读取配置文件失败: $e');
      if (!mounted) return;
      showToast(context, AppLocalizations.of(context).configExportReadFileFailed);
    }
  }

  Future<void> _importConfig() async {
    setState(() => _isImporting = true);

    try {
      // Step 1: 选择文件（使用 FilePickerHelper 处理部分设备不支持扩展名过滤的问题）
      final result = await FilePickerHelper.pickYamlFile();

      if (result == null || result.files.isEmpty) {
        if (mounted) {
          setState(() => _isImporting = false);
        }
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        if (!mounted) return;
        throw Exception(AppLocalizations.of(context).configImportNoFilePath);
      }

      // Step 2: 读取文件并检测可用内容
      if (!mounted) return;
      final file = File(filePath);
      final yamlContent = await file.readAsString();

      // 检测文件中包含哪些配置项
      final contentInfo = ConfigExportService.detectContent(yamlContent);

      // Step 3: 显示预览并选择导入内容的对话框
      if (!mounted) return;
      final options = await showDialog<ExportOptions>(
        context: context,
        builder: (context) => _ImportPreviewDialog(
          ref: ref,
          yamlContent: yamlContent,
          contentInfo: contentInfo,
        ),
      );

      if (options == null || !mounted) {
        setState(() => _isImporting = false);
        return;
      }

      // Step 4: 执行导入
      // 注意：不传入 ledgerId，让导入逻辑使用 yml 中指定的账本名称
      // 这样预算等数据会导入到正确的账本，而不是当前账本
      final repo = ref.read(repositoryProvider);

      await ConfigExportService.importFromFile(
        filePath,
        repository: repo,
        options: options,
      );

      // 导入后立即刷新相关的 Provider 状态
      if (options.appSettings) {
        await _refreshProvidersAfterImport();
      }

      if (!mounted) return;
      showToast(context, AppLocalizations.of(context).configImportSuccess);

      // 提示需要重启应用（部分设置可能仍需重启）
      if (!mounted) return;
      await AppDialog.info(
        context,
        title: AppLocalizations.of(context).configImportRestartTitle,
        message: AppLocalizations.of(context).configImportRestartMessage,
      );
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: AppLocalizations.of(context).configImportFailed,
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  /// 导入后刷新相关的 Provider 状态
  Future<void> _refreshProvidersAfterImport() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 刷新主题色
      final primaryColor = prefs.getInt('primaryColor');
      if (primaryColor != null) {
        ref.read(primaryColorProvider.notifier).state = Color(primaryColor);
        logger.info('ConfigImport', '主题色已刷新: $primaryColor');
      }

      // 刷新主题模式
      final themeMode = prefs.getString('themeMode');
      if (themeMode != null) {
        switch (themeMode) {
          case 'light':
            ref.read(themeModeProvider.notifier).state = ThemeMode.light;
            break;
          case 'dark':
            ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
            break;
          default:
            ref.read(themeModeProvider.notifier).state = ThemeMode.system;
        }
        logger.info('ConfigImport', '主题模式已刷新: $themeMode');
      }

      // 刷新字体缩放
      final fontScaleLevel = prefs.getInt('fontScaleLevel');
      if (fontScaleLevel != null) {
        ref.read(fontScaleLevelProvider.notifier).state = fontScaleLevel.clamp(-3, 4);
        logger.info('ConfigImport', '字体缩放档位已刷新: $fontScaleLevel');
      }

      final customFontScale = prefs.getDouble('customFontScale');
      if (customFontScale != null) {
        ref.read(customFontScaleProvider.notifier).state = customFontScale.clamp(0.7, 1.5);
        logger.info('ConfigImport', '自定义字体缩放已刷新: $customFontScale');
      }

      // 刷新金额显示格式
      final compactAmount = prefs.getBool('compactAmount');
      if (compactAmount != null) {
        ref.read(compactAmountProvider.notifier).state = compactAmount;
        logger.info('ConfigImport', '金额显示格式已刷新: $compactAmount');
      }

      // 刷新交易时间显示
      final showTransactionTime = prefs.getBool('showTransactionTime');
      if (showTransactionTime != null) {
        ref.read(showTransactionTimeProvider.notifier).state = showTransactionTime;
        logger.info('ConfigImport', '交易时间显示已刷新: $showTransactionTime');
      }

      // 刷新头部皮肤
      final headerSkin = prefs.getString('headerSkin');
      if (headerSkin != null) {
        ref.read(headerSkinProvider.notifier).state = headerSkin;
        logger.info('ConfigImport', '头部皮肤已刷新: $headerSkin');
      }
      logger.info('ConfigImport', 'Provider 状态刷新完成');
    } catch (e) {
      logger.error('ConfigImport', '刷新 Provider 状态失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.configImportExportTitle,
            subtitle: l10n.configImportExportSubtitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: 12.0.scaled(context, ref),
                vertical: 8.0.scaled(context, ref),
              ),
              children: [
                // 说明卡片
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: EdgeInsets.all(12.0.scaled(context, ref)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20.0.scaled(context, ref),
                              color: ref.watch(primaryColorProvider),
                            ),
                            SizedBox(width: 8.0.scaled(context, ref)),
                            Text(
                              l10n.configImportExportInfoTitle,
                              style: TextStyle(
                                fontSize: 16.0.scaled(context, ref),
                                fontWeight: FontWeight.w600,
                                color: BeeTokens.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.0.scaled(context, ref)),
                        Text(
                          l10n.configImportExportInfoMessage,
                          style: TextStyle(
                            fontSize: 14.0.scaled(context, ref),
                            color: BeeTokens.textSecondary(context),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8.0.scaled(context, ref)),
                // 功能按钮
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 导出配置
                      AppListTile(
                        leading: Icons.upload_file,
                        title: l10n.configExportTitle,
                        subtitle: l10n.configExportSubtitle,
                        trailing: _isExporting
                            ? SizedBox(
                                width: 20.0.scaled(context, ref),
                                height: 20.0.scaled(context, ref),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: ref.watch(primaryColorProvider),
                                ),
                              )
                            : null,
                        onTap: _isExporting ? null : _exportConfig,
                      ),
                      // Android平台显示导出路径和打开按钮
                      if (Platform.isAndroid && _lastExportedFilePath != null) ...[
                        const Divider(height: 1, thickness: 0.5),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.0.scaled(context, ref),
                            vertical: 12.0.scaled(context, ref),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 16.0.scaled(context, ref),
                                    color: Colors.green,
                                  ),
                                  SizedBox(width: 8.0.scaled(context, ref)),
                                  Expanded(
                                    child: Text(
                                      l10n.configExportSavedTo(_lastExportedFilePath!.replaceAll('/storage/emulated/0/', '')),
                                      style: TextStyle(
                                        fontSize: 13.0.scaled(context, ref),
                                        color: BeeTokens.textSecondary(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8.0.scaled(context, ref)),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _viewExportedContent,
                                  icon: const Icon(Icons.visibility_outlined, size: 18),
                                  label: Text(l10n.configExportViewContent),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: ref.watch(primaryColorProvider),
                                    side: BorderSide(
                                      color: ref.watch(primaryColorProvider).withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Divider(height: 1, thickness: 0.5),
                      // 导入配置
                      AppListTile(
                        leading: Icons.download_outlined,
                        title: l10n.configImportTitle,
                        subtitle: l10n.configImportSubtitle,
                        trailing: _isImporting
                            ? SizedBox(
                                width: 20.0.scaled(context, ref),
                                height: 20.0.scaled(context, ref),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: ref.watch(primaryColorProvider),
                                ),
                              )
                            : null,
                        onTap: _isImporting ? null : _importConfig,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.0.scaled(context, ref)),
                // 包含的配置项
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: EdgeInsets.all(12.0.scaled(context, ref)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.configImportExportIncludesTitle,
                          style: TextStyle(
                            fontSize: 16.0.scaled(context, ref),
                            fontWeight: FontWeight.w600,
                            color: BeeTokens.textPrimary(context),
                          ),
                        ),
                        SizedBox(height: 12.0.scaled(context, ref)),
                        _buildConfigItem(
                          context,
                          ref,
                          Icons.book_outlined,
                          l10n.configIncludeLedgers,
                        ),
                        SizedBox(height: 8.0.scaled(context, ref)),
                        _buildConfigItem(
                          context,
                          ref,
                          Icons.cloud_outlined,
                          l10n.configIncludeSupabase,
                        ),
                        SizedBox(height: 8.0.scaled(context, ref)),
                        _buildConfigItem(
                          context,
                          ref,
                          Icons.folder_outlined,
                          l10n.configIncludeWebdav,
                        ),
                        SizedBox(height: 8.0.scaled(context, ref)),
                        _buildConfigItem(
                          context,
                          ref,
                          Icons.storage,
                          l10n.configIncludeS3,
                        ),
                        SizedBox(height: 8.0.scaled(context, ref)),
                        _buildConfigItem(
                          context,
                          ref,
                          Icons.smart_toy_outlined,
                          l10n.configIncludeAI,
                        ),
                        SizedBox(height: 8.0.scaled(context, ref)),
                        _buildConfigItem(
                          context,
                          ref,
                          Icons.settings_outlined,
                          l10n.configIncludeAppSettings,
                        ),
                        SizedBox(height: 8.0.scaled(context, ref)),
                        _buildConfigItem(
                          context,
                          ref,
                          Icons.repeat,
                          l10n.configIncludeRecurringTransactions,
                        ),
                        SizedBox(height: 8.0.scaled(context, ref)),
                        _buildConfigItem(
                          context,
                          ref,
                          Icons.account_balance_wallet_outlined,
                          l10n.configIncludeAccounts,
                        ),
                        SizedBox(height: 8.0.scaled(context, ref)),
                        _buildConfigItem(
                          context,
                          ref,
                          Icons.category_outlined,
                          l10n.configIncludeCategories,
                        ),
                        SizedBox(height: 8.0.scaled(context, ref)),
                        _buildConfigItem(
                          context,
                          ref,
                          Icons.label_outline,
                          l10n.configIncludeTags,
                        ),
                        SizedBox(height: 8.0.scaled(context, ref)),
                        _buildConfigItem(
                          context,
                          ref,
                          Icons.account_balance_outlined,
                          l10n.configIncludeBudgets,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigItem(
    BuildContext context,
    WidgetRef ref,
    IconData icon,
    String text,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18.0.scaled(context, ref),
          color: ref.watch(primaryColorProvider),
        ),
        SizedBox(width: 8.0.scaled(context, ref)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.0.scaled(context, ref),
              color: BeeTokens.textPrimary(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// 配置内容查看对话框
class _ConfigContentDialog extends StatelessWidget {
  final String content;
  final VoidCallback onCopy;

  const _ConfigContentDialog({
    required this.content,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BeeTokens.surfaceElevated(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.configExportViewContent,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // 内容区域
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: SelectableText(
                  content,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          // 底部按钮
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BeeTokens.surfaceElevated(context),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(l10n.configExportCopyContent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 配置预览对话框
class _ConfigPreviewDialog extends StatefulWidget {
  final String yamlContent;

  const _ConfigPreviewDialog({required this.yamlContent});

  @override
  State<_ConfigPreviewDialog> createState() => _ConfigPreviewDialogState();
}

class _ConfigPreviewDialogState extends State<_ConfigPreviewDialog> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      backgroundColor: BeeTokens.surfaceElevated(context),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BeeTokens.surfaceElevated(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.preview_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '配置预览',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // 内容区域 - 直接展示YAML内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '导入将覆盖现有配置，建议先备份当前配置。',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BeeTokens.surface(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: BeeTokens.border(context)),
                    ),
                    child: SelectableText(
                      widget.yamlContent,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.5,
                        color: BeeTokens.textPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 底部按钮
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BeeTokens.surfaceElevated(context),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.configImportConfirmTitle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 导出选项选择对话框
class _ExportOptionsDialog extends StatefulWidget {
  final WidgetRef ref;

  const _ExportOptionsDialog({required this.ref});

  @override
  State<_ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<_ExportOptionsDialog> {
  // 默认全选
  bool _ledgers = true;
  bool _categories = true;
  bool _accounts = true;
  bool _tags = true;
  bool _budgets = true;
  bool _recurringTransactions = true;
  bool _appSettings = true;
  bool _ai = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = widget.ref.watch(primaryColorProvider);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: BeeTokens.surfaceElevated(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BeeTokens.surfaceElevated(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.checklist_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.configExportSelectTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // 选项列表
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                CheckboxListTile(
                  value: _ledgers,
                  onChanged: (v) => setState(() => _ledgers = v ?? true),
                  title: Text(l10n.configIncludeLedgers),
                  secondary: Icon(Icons.book_outlined, color: primary),
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _categories,
                  onChanged: (v) => setState(() => _categories = v ?? true),
                  title: Text(l10n.configIncludeCategories),
                  secondary: Icon(Icons.category_outlined, color: primary),
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _accounts,
                  onChanged: (v) => setState(() => _accounts = v ?? true),
                  title: Text(l10n.configIncludeAccounts),
                  secondary: Icon(Icons.account_balance_wallet_outlined, color: primary),
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _tags,
                  onChanged: (v) => setState(() => _tags = v ?? true),
                  title: Text(l10n.configIncludeTags),
                  secondary: Icon(Icons.label_outline, color: primary),
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _budgets,
                  onChanged: (v) => setState(() => _budgets = v ?? true),
                  title: Text(l10n.configIncludeBudgets),
                  secondary: Icon(Icons.account_balance_outlined, color: primary),
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _recurringTransactions,
                  onChanged: (v) => setState(() => _recurringTransactions = v ?? true),
                  title: Text(l10n.configIncludeRecurringTransactions),
                  secondary: Icon(Icons.repeat, color: primary),
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _ai,
                  onChanged: (v) => setState(() => _ai = v ?? true),
                  title: Text(l10n.configIncludeAI),
                  subtitle: Text(
                    l10n.configIncludeAISubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: BeeTokens.textSecondary(context),
                    ),
                  ),
                  secondary: Icon(Icons.smart_toy_outlined, color: primary),
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _appSettings,
                  onChanged: (v) => setState(() => _appSettings = v ?? true),
                  title: Text(l10n.configIncludeOtherSettings),
                  subtitle: Text(
                    l10n.configIncludeOtherSettingsSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: BeeTokens.textSecondary(context),
                    ),
                  ),
                  secondary: Icon(Icons.settings_outlined, color: primary),
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 底部按钮
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    final options = ExportOptions(
                      ledgers: _ledgers,
                      categories: _categories,
                      accounts: _accounts,
                      tags: _tags,
                      budgets: _budgets,
                      recurringTransactions: _recurringTransactions,
                      appSettings: _appSettings,
                      ai: _ai,
                    );
                    Navigator.pop(context, options);
                  },
                  child: Text(l10n.commonNext),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 导出预览对话框
class _ExportPreviewDialog extends StatelessWidget {
  final String yamlContent;

  const _ExportPreviewDialog({required this.yamlContent});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: BeeTokens.surfaceElevated(context),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BeeTokens.surfaceElevated(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.preview_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.configExportPreviewTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // 内容区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BeeTokens.surface(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BeeTokens.border(context)),
                ),
                child: SelectableText(
                  yamlContent,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.5,
                    color: BeeTokens.textPrimary(context),
                  ),
                ),
              ),
            ),
          ),
          // 底部按钮
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.configExportConfirmTitle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 导入预览对话框（先预览内容，再选择导入项）
class _ImportPreviewDialog extends StatefulWidget {
  final WidgetRef ref;
  final String yamlContent;
  final ConfigContentInfo contentInfo;

  const _ImportPreviewDialog({
    required this.ref,
    required this.yamlContent,
    required this.contentInfo,
  });

  @override
  State<_ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<_ImportPreviewDialog> {
  // 默认全选（仅对文件中存在的项）
  late bool _ledgers;
  late bool _categories;
  late bool _accounts;
  late bool _tags;
  late bool _budgets;
  late bool _recurringTransactions;
  late bool _appSettings;
  late bool _ai;

  @override
  void initState() {
    super.initState();
    _ledgers = widget.contentInfo.hasLedgers;
    _categories = widget.contentInfo.hasCategories;
    _accounts = widget.contentInfo.hasAccounts;
    _tags = widget.contentInfo.hasTags;
    _budgets = widget.contentInfo.hasBudgets;
    _recurringTransactions = widget.contentInfo.hasRecurringTransactions;
    _appSettings = widget.contentInfo.hasAppSettings;
    _ai = widget.contentInfo.hasAi;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = widget.ref.watch(primaryColorProvider);
    final info = widget.contentInfo;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: BeeTokens.surfaceElevated(context),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BeeTokens.surfaceElevated(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.preview_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.configImportPreviewTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // YAML 内容预览
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 警告提示
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '导入将覆盖现有配置，建议先备份当前配置。',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // YAML 内容
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: BeeTokens.surface(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: BeeTokens.border(context)),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        widget.yamlContent,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.5,
                          color: BeeTokens.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 选择导入内容标题
                  Text(
                    l10n.configImportSelectTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BeeTokens.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 选项列表
                  if (info.hasLedgers)
                    CheckboxListTile(
                      value: _ledgers,
                      onChanged: (v) => setState(() => _ledgers = v ?? true),
                      title: Text(l10n.configIncludeLedgers),
                      secondary: Icon(Icons.book_outlined, color: primary),
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  if (info.hasCategories)
                    CheckboxListTile(
                      value: _categories,
                      onChanged: (v) => setState(() => _categories = v ?? true),
                      title: Text(l10n.configIncludeCategories),
                      secondary: Icon(Icons.category_outlined, color: primary),
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  if (info.hasAccounts)
                    CheckboxListTile(
                      value: _accounts,
                      onChanged: (v) => setState(() => _accounts = v ?? true),
                      title: Text(l10n.configIncludeAccounts),
                      secondary: Icon(Icons.account_balance_wallet_outlined, color: primary),
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  if (info.hasTags)
                    CheckboxListTile(
                      value: _tags,
                      onChanged: (v) => setState(() => _tags = v ?? true),
                      title: Text(l10n.configIncludeTags),
                      secondary: Icon(Icons.label_outline, color: primary),
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  if (info.hasBudgets)
                    CheckboxListTile(
                      value: _budgets,
                      onChanged: (v) => setState(() => _budgets = v ?? true),
                      title: Text(l10n.configIncludeBudgets),
                      secondary: Icon(Icons.account_balance_outlined, color: primary),
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  if (info.hasRecurringTransactions)
                    CheckboxListTile(
                      value: _recurringTransactions,
                      onChanged: (v) => setState(() => _recurringTransactions = v ?? true),
                      title: Text(l10n.configIncludeRecurringTransactions),
                      secondary: Icon(Icons.repeat, color: primary),
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  if (info.hasAi)
                    CheckboxListTile(
                      value: _ai,
                      onChanged: (v) => setState(() => _ai = v ?? true),
                      title: Text(l10n.configIncludeAI),
                      subtitle: Text(
                        l10n.configIncludeAISubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: BeeTokens.textSecondary(context),
                        ),
                      ),
                      secondary: Icon(Icons.smart_toy_outlined, color: primary),
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  if (info.hasAppSettings)
                    CheckboxListTile(
                      value: _appSettings,
                      onChanged: (v) => setState(() => _appSettings = v ?? true),
                      title: Text(l10n.configIncludeOtherSettings),
                      subtitle: Text(
                        l10n.configIncludeOtherSettingsSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: BeeTokens.textSecondary(context),
                        ),
                      ),
                      secondary: Icon(Icons.settings_outlined, color: primary),
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
          ),
          // 底部按钮
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BeeTokens.surfaceElevated(context),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    final options = ExportOptions(
                      ledgers: _ledgers,
                      categories: _categories,
                      accounts: _accounts,
                      tags: _tags,
                      budgets: _budgets,
                      recurringTransactions: _recurringTransactions,
                      appSettings: _appSettings,
                      ai: _ai,
                    );
                    Navigator.pop(context, options);
                  },
                  child: Text(l10n.configImportConfirmTitle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
