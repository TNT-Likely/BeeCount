import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../styles/tokens.dart';
import '../data/import_page.dart';
import '../data/export_page.dart';
import '../category/category_manage_page.dart';
import '../category/category_migration_page.dart';
import '../tag/tag_manage_page.dart';
import '../settings/config_import_export_page.dart';
import '../settings/storage_management_page.dart';
import '../settings/attachment_preview_page.dart';
import '../settings/app_lock_settings_page.dart';
import '../maintenance/orphan_cleanup_page.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../services/attachment_export_import_service.dart';

/// 数据管理二级页面
class DataManagementPage extends ConsumerStatefulWidget {
  const DataManagementPage({super.key});

  @override
  ConsumerState<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends ConsumerState<DataManagementPage> {
  bool _isExporting = false;
  bool _isImporting = false;
  int _exportProgress = 0;
  int _exportTotal = 0;
  int _exportAttachmentCount = 0;
  int _exportIconCount = 0;
  int _importProgress = 0;
  int _importTotal = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: AppLocalizations.of(context).dataManagementPageTitle,
            subtitle: AppLocalizations.of(context).dataManagementPageSubtitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 提示文案
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    AppLocalizations.of(context).dataManagementAttachmentHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: BeeTokens.textTertiary(context),
                    ),
                  ),
                ),
                // 导入导出
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 导入数据
                      Consumer(builder: (ctx, r, _) {
                        final p = r.watch(importProgressProvider);
                        if (!p.running && p.total == 0) {
                          return AppListTile(
                            leading: Icons.file_upload_outlined,
                            title: AppLocalizations.of(context).mineImport,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ImportPage()),
                              );
                            },
                          );
                        }
                        if (p.running) {
                          final percent =
                              p.total == 0 ? null : (p.done / p.total).clamp(0.0, 1.0);
                          return AppListTile(
                            leading: Icons.upload_outlined,
                            title: AppLocalizations.of(context).mineImportProgressTitle,
                            subtitle: AppLocalizations.of(context)
                                .mineImportProgressSubtitle(p.done, p.fail, p.ok, p.total),
                            trailing: SizedBox(
                                width: 72, child: LinearProgressIndicator(value: percent)),
                            onTap: null,
                          );
                        }
                        final allOk = (p.done == p.total) && (p.fail == 0);
                        if (allOk) return const _ImportSuccessTile();
                        return AppListTile(
                          leading: Icons.info_outline,
                          title: AppLocalizations.of(context).mineImportCompleteTitle,
                          subtitle:
                              '${AppLocalizations.of(context).commonSuccess} ${p.ok}，${AppLocalizations.of(context).commonFailed} ${p.fail}',
                          onTap: null,
                        );
                      }),
                      BeeTokens.cardDivider(context),
                      // 导出数据
                      AppListTile(
                        leading: Icons.file_download_outlined,
                        title: AppLocalizations.of(context).mineExport,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ExportPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.0.scaled(context, ref)),
                // 附件导出导入
                _buildAttachmentSection(context, ref),
                SizedBox(height: 8.0.scaled(context, ref)),
                // 分类管理
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 分类管理
                      AppListTile(
                        leading: Icons.category_outlined,
                        title: AppLocalizations.of(context).mineCategoryManagement,
                        subtitle: AppLocalizations.of(context).mineCategoryManagementSubtitle,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CategoryManagePage()),
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),
                      // 分类迁移
                      AppListTile(
                        leading: Icons.swap_horiz,
                        title: AppLocalizations.of(context).mineCategoryMigration,
                        subtitle: AppLocalizations.of(context).mineCategoryMigrationSubtitle,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CategoryMigrationPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.0.scaled(context, ref)),
                // 标签管理
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: AppListTile(
                    leading: Icons.label_outline,
                    title: AppLocalizations.of(context).tagManageTitle,
                    subtitle: AppLocalizations.of(context).tagManageSubtitle,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TagManagePage()),
                      );
                    },
                  ),
                ),
                SizedBox(height: 8.0.scaled(context, ref)),
                // 配置管理
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 配置导入导出
                      AppListTile(
                        leading: Icons.settings_backup_restore,
                        title: AppLocalizations.of(context).configImportExportTitle,
                        subtitle: AppLocalizations.of(context).configImportExportSubtitle,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ConfigImportExportPage()),
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),
                      // 存储空间管理
                      AppListTile(
                        leading: Icons.storage_outlined,
                        title: AppLocalizations.of(context).storageManagementTitle,
                        subtitle: AppLocalizations.of(context).storageManagementSubtitle,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const StorageManagementPage()),
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),
                      // 数据清理(孤儿数据)
                      AppListTile(
                        leading: Icons.cleaning_services_outlined,
                        title: AppLocalizations.of(context)
                            .maintenanceOrphanCleanupTitle,
                        subtitle: AppLocalizations.of(context)
                            .maintenanceOrphanCleanupSubtitle,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const OrphanCleanupPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.0.scaled(context, ref)),
                // 安全
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: AppListTile(
                    leading: Icons.lock_outline,
                    title: AppLocalizations.of(context).appLockTitle,
                    subtitle: AppLocalizations.of(context).appLockDesc,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const AppLockSettingsPage()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // 附件导出导入相关
  // ============================================

  Widget _buildAttachmentSection(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);

    return SectionCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 导出附件
          AppListTile(
            leading: Icons.upload_file,
            title: l10n.attachmentExportTitle,
            subtitle: l10n.attachmentExportSubtitle,
            trailing: _isExporting
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.preview, color: primary),
                    onPressed: _handleExportPreview,
                  ),
            onTap: _isExporting ? null : _handleExport,
          ),
          // 导出进度
          if (_isExporting && _exportTotal > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _exportProgress / _exportTotal,
                    backgroundColor: BeeTokens.divider(context),
                    color: primary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _exportAttachmentCount > 0 || _exportIconCount > 0
                        ? l10n.attachmentExportProgressDetail(
                            _exportAttachmentCount,
                            _exportIconCount,
                            _exportProgress,
                            _exportTotal,
                          )
                        : l10n.attachmentExportProgress(_exportProgress, _exportTotal),
                    style: TextStyle(
                      fontSize: 12,
                      color: BeeTokens.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          BeeTokens.cardDivider(context),
          // 导入附件
          AppListTile(
            leading: Icons.download,
            title: l10n.attachmentImportTitle,
            subtitle: l10n.attachmentImportSubtitle,
            trailing: _isImporting
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  )
                : null,
            onTap: _isImporting ? null : _selectImportFile,
          ),
          // 导入进度
          if (_isImporting && _importTotal > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _importProgress / _importTotal,
                    backgroundColor: BeeTokens.divider(context),
                    color: primary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.attachmentImportProgress(_importProgress, _importTotal),
                    style: TextStyle(
                      fontSize: 12,
                      color: BeeTokens.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 预览即将导出的附件和自定义图标
  Future<void> _handleExportPreview() async {
    final service = ref.read(attachmentExportImportServiceProvider);
    final previewData = await service.getExportPreviewImages();

    if (!mounted) return;

    if (previewData.isEmpty) {
      showToast(context, AppLocalizations.of(context).attachmentExportEmpty);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttachmentPreviewPage(
          exportData: previewData,
          title: AppLocalizations.of(context).attachmentExportPreviewTitle,
        ),
      ),
    );
  }

  Future<void> _handleExport() async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(attachmentExportImportServiceProvider);

    // 先获取实际存在的文件数用于进度显示
    final previewData = await service.getExportPreviewImages();
    final attachmentCount = previewData.attachments.length;
    final iconCount = previewData.customIcons.length;
    final actualFileCount = attachmentCount + iconCount;

    setState(() {
      _isExporting = true;
      _exportProgress = 0;
      _exportTotal = actualFileCount; // 使用实际文件数（附件 + 图标）
      _exportAttachmentCount = attachmentCount;
      _exportIconCount = iconCount;
    });

    final exportPath = await service.exportAttachments(
      onProgress: (current, total) {
        if (mounted) {
          setState(() {
            _exportProgress = current;
            _exportTotal = total;
          });
        }
      },
    );

    setState(() {
      _isExporting = false;
    });

    if (!mounted) return;

    if (exportPath != null) {
      showToast(context, l10n.attachmentExportSuccess);

      // iOS 弹出分享
      if (Platform.isIOS) {
        await Share.shareXFiles([XFile(exportPath)]);
      } else {
        // Android 显示保存路径
        showToast(context, l10n.attachmentExportSavedTo(exportPath));
      }
    } else {
      // exportPath 为 null 表示没有内容需要导出
      showToast(context, l10n.attachmentExportEmpty);
    }
  }

  Future<void> _selectImportFile() async {
    final pickerResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gz', 'tar'],
    );

    if (pickerResult == null || pickerResult.files.isEmpty) return;

    final filePath = pickerResult.files.first.path;
    if (filePath == null) return;

    final service = ref.read(attachmentExportImportServiceProvider);
    final info = await service.previewArchive(filePath);

    if (!mounted) return;

    if (info == null) {
      showToast(context, AppLocalizations.of(context).attachmentImportFailed);
      return;
    }

    // 显示确认弹窗
    final dialogResult = await _showImportConfirmDialog(filePath, info);
    if (dialogResult != null) {
      final conflictStrategy = dialogResult['strategy'] as String;
      final shouldPreview = dialogResult['preview'] as bool? ?? false;

      if (shouldPreview) {
        // 显示预览
        await _handleImportPreview(filePath);
      } else {
        // 直接导入
        await _handleImport(filePath, info, conflictStrategy);
      }
    }
  }

  /// 预览归档中的附件和自定义图标
  Future<void> _handleImportPreview(String filePath) async {
    final service = ref.read(attachmentExportImportServiceProvider);
    final previewData = await service.getArchivePreviewImages(filePath);

    if (!mounted) return;

    if (previewData.isEmpty) {
      showToast(context, AppLocalizations.of(context).attachmentPreviewEmpty);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttachmentPreviewPage(
          archiveData: previewData,
          title: AppLocalizations.of(context).attachmentImportPreviewTitle,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showImportConfirmDialog(
    String filePath,
    AttachmentArchiveInfo info,
  ) async {
    final l10n = AppLocalizations.of(context);
    final primary = ref.read(primaryColorProvider);
    String conflictStrategy = AttachmentExportImportService.conflictSkip;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(l10n.attachmentImportTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 文件名
                  Row(
                    children: [
                      Icon(Icons.archive, size: 20, color: primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          filePath.split('/').last,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 归档信息
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.attachmentArchiveInfo(
                          info.count,
                          info.exportedAt != null
                              ? DateFormat('yyyy-MM-dd HH:mm').format(info.exportedAt!)
                              : '-',
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          color: BeeTokens.textSecondary(ctx),
                        ),
                      ),
                      if (info.customIconCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '自定义图标: ${info.customIconCount} 个',
                            style: TextStyle(
                              fontSize: 14,
                              color: BeeTokens.textSecondary(ctx),
                            ),
                          ),
                        ),
                      if (info.hasAvatar)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '包含头像',
                            style: TextStyle(
                              fontSize: 14,
                              color: BeeTokens.textSecondary(ctx),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 冲突策略
                  Text(
                    l10n.attachmentImportConflictStrategy,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  // 跳过选项
                  RadioListTile<String>(
                    title: Text(l10n.attachmentImportConflictSkip, style: const TextStyle(fontSize: 14)),
                    value: AttachmentExportImportService.conflictSkip,
                    groupValue: conflictStrategy,
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => conflictStrategy = v);
                      }
                    },
                    activeColor: primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                  ),
                  // 覆盖选项
                  RadioListTile<String>(
                    title: Text(l10n.attachmentImportConflictOverwrite, style: const TextStyle(fontSize: 14)),
                    value: AttachmentExportImportService.conflictOverwrite,
                    groupValue: conflictStrategy,
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => conflictStrategy = v);
                      }
                    },
                    activeColor: primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: Text(l10n.commonCancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop({
                    'strategy': conflictStrategy,
                    'preview': true,
                  }),
                  child: Text(l10n.attachmentPreview),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop({
                    'strategy': conflictStrategy,
                    'preview': false,
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l10n.attachmentStartImport),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleImport(
    String filePath,
    AttachmentArchiveInfo info,
    String conflictStrategy,
  ) async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(attachmentExportImportServiceProvider);

    setState(() {
      _isImporting = true;
      _importProgress = 0;
      _importTotal = info.count;
    });

    final result = await service.importAttachments(
      archivePath: filePath,
      conflictStrategy: conflictStrategy,
      onProgress: (current, total) {
        if (mounted) {
          setState(() {
            _importProgress = current;
            _importTotal = total;
          });
        }
      },
    );

    setState(() {
      _isImporting = false;
    });

    if (!mounted) return;

    if (result.success) {
      // 构建详细的导入结果消息
      final parts = <String>[];

      // 交易附件结果
      if (result.imported > 0 || result.skipped > 0 || result.overwritten > 0 || result.failed > 0) {
        parts.add(l10n.attachmentImportResult(
          result.imported,
          result.skipped,
          result.overwritten,
          result.failed,
        ));
      }

      // 头像导入结果
      if (result.avatarImported) {
        parts.add('头像已导入');
      }

      // 自定义图标导入结果
      if (result.customIconsImported > 0 || result.customIconsSkipped > 0) {
        parts.add('自定义图标：导入${result.customIconsImported}个${result.customIconsSkipped > 0 ? '，跳过${result.customIconsSkipped}个' : ''}');
      }

      // 如果没有任何导入结果，显示提示
      if (parts.isEmpty && !result.avatarImported && result.customIconsImported == 0) {
        parts.add('未导入任何内容');
      }

      showToast(context, parts.join('；'));
    } else {
      showToast(context, result.message ?? l10n.attachmentImportFailed);
    }
  }
}

// 导入完成后的短暂动画提示：线性进度条从 0 -> 100%
class _ImportSuccessTile extends StatelessWidget {
  const _ImportSuccessTile();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (ctx, v, child) {
        return AppListTile(
          leading: Icons.check_circle_outline,
          title: AppLocalizations.of(ctx).mineImportCompleteTitle,
          subtitle: AppLocalizations.of(ctx).mineImportCompleteAllSuccess,
          trailing: SizedBox(
            width: 72,
            child: LinearProgressIndicator(
              value: v,
              valueColor: AlwaysStoppedAnimation(primary),
            ),
          ),
        );
      },
    );
  }
}
