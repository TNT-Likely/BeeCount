import 'dart:io';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/attachment_export_import_service.dart';
import '../../attachment_preview_page.dart';

/// Original archive service and platform actions; the page composes pure views.
mixin AttachmentTransferActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  bool isExporting = false;
  bool isImporting = false;
  int exportProgress = 0;
  int exportTotal = 0;
  int exportAttachmentCount = 0;
  int exportIconCount = 0;
  int importProgress = 0;
  int importTotal = 0;

  /// 预览即将导出的附件和自定义图标
  Future<void> previewExportAttachments() async {
    final service = ref.read(attachmentExportImportServiceProvider);
    final previewData = await service.getExportPreviewImages();

    if (!mounted) return;

    if (previewData.isEmpty) {
      showBeeToast(context, AppLocalizations.of(context).attachmentExportEmpty);
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

  Future<void> exportAttachmentsAction() async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(attachmentExportImportServiceProvider);

    // 先获取实际存在的文件数用于进度显示
    final previewData = await service.getExportPreviewImages();
    final attachmentCount = previewData.attachments.length;
    final iconCount = previewData.customIcons.length;
    final actualFileCount = attachmentCount + iconCount;

    if (!mounted) return;
    setState(() {
      isExporting = true;
      exportProgress = 0;
      exportTotal = actualFileCount; // 使用实际文件数（附件 + 图标）
      exportAttachmentCount = attachmentCount;
      exportIconCount = iconCount;
    });

    final exportPath = await service.exportAttachments(
      onProgress: (current, total) {
        if (mounted) {
          setState(() {
            exportProgress = current;
            exportTotal = total;
          });
        }
      },
    );

    if (!mounted) return;
    setState(() {
      isExporting = false;
    });

    if (!mounted) return;

    if (exportPath != null) {
      showBeeToast(context, l10n.attachmentExportSuccess);

      // iOS 弹出分享
      if (Platform.isIOS) {
        await SharePlus.instance.share(ShareParams(files: [XFile(exportPath)]));
      } else {
        // Android 显示保存路径
        showBeeToast(context, l10n.attachmentExportSavedTo(exportPath));
      }
    } else {
      // exportPath 为 null 表示没有内容需要导出
      showBeeToast(context, l10n.attachmentExportEmpty);
    }
  }

  Future<void> selectAttachmentImportFile() async {
    final pickerResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gz'],
    );

    if (pickerResult == null || pickerResult.files.isEmpty) return;

    final filePath = pickerResult.files.first.path;
    if (filePath == null) return;

    final service = ref.read(attachmentExportImportServiceProvider);
    final info = await service.previewArchive(filePath);

    if (!mounted) return;

    if (info == null) {
      showBeeToast(context, AppLocalizations.of(context).attachmentImportFailed);
      return;
    }

    // 显示确认弹窗
    final dialogResult = await showAttachmentImportConfirm(filePath, info);
    if (dialogResult != null) {
      final conflictStrategy = dialogResult['strategy'] as String;
      final shouldPreview = dialogResult['preview'] as bool? ?? false;

      if (shouldPreview) {
        // 显示预览
        await previewArchiveAttachments(filePath);
      } else {
        // 直接导入
        await importArchiveAttachments(filePath, info, conflictStrategy);
      }
    }
  }

  /// 预览归档中的附件和自定义图标
  Future<void> previewArchiveAttachments(String filePath) async {
    final service = ref.read(attachmentExportImportServiceProvider);
    final previewData = await service.getArchivePreviewImages(filePath);

    if (!mounted) return;

    if (previewData.isEmpty) {
      showBeeToast(context, AppLocalizations.of(context).attachmentPreviewEmpty);
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

  Future<void> importArchiveAttachments(
    String filePath,
    AttachmentArchiveInfo info,
    String conflictStrategy,
  ) async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(attachmentExportImportServiceProvider);

    setState(() {
      isImporting = true;
      importProgress = 0;
      importTotal = info.count;
    });

    final result = await service.importAttachments(
      archivePath: filePath,
      conflictStrategy: conflictStrategy,
      onProgress: (current, total) {
        if (mounted) {
          setState(() {
            importProgress = current;
            importTotal = total;
          });
        }
      },
    );

    if (!mounted) return;
    setState(() {
      isImporting = false;
    });

    if (!mounted) return;

    if (result.success) {
      // 构建详细的导入结果消息
      final parts = <String>[];

      // 交易附件结果
      if (result.imported > 0 ||
          result.skipped > 0 ||
          result.overwritten > 0 ||
          result.failed > 0) {
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
        parts.add(
            '自定义图标：导入${result.customIconsImported}个${result.customIconsSkipped > 0 ? '，跳过${result.customIconsSkipped}个' : ''}');
      }

      // 如果没有任何导入结果，显示提示
      if (parts.isEmpty &&
          !result.avatarImported &&
          result.customIconsImported == 0) {
        parts.add('未导入任何内容');
      }

      showBeeToast(context, parts.join('；'));
    } else {
      showBeeToast(context, result.message ?? l10n.attachmentImportFailed);
    }
  }

  Future<Map<String, dynamic>?> showAttachmentImportConfirm(
      String filePath, AttachmentArchiveInfo info) {
    final l = AppLocalizations.of(context);
    var overwrite = false;
    return showDialog<Map<String, dynamic>>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .26),
        builder: (dialog) => StatefulBuilder(
            builder: (dialog, setDraft) => BeeDialog(
                    title: Text(l.attachmentImportTitle),
                    content: BeeArchiveSummary(
                        fileName: filePath.split('/').last,
                        details: [
                          l.attachmentArchiveInfo(
                              info.count,
                              info.exportedAt != null
                                  ? DateFormat('yyyy-MM-dd HH:mm')
                                      .format(info.exportedAt!)
                                  : '-'),
                          if (info.customIconCount > 0)
                            '自定义图标: ${info.customIconCount} 个',
                          if (info.hasAvatar) '包含头像'
                        ],
                        strategyLabel: l.attachmentImportConflictStrategy,
                        skipLabel: l.attachmentImportConflictSkip,
                        overwriteLabel: l.attachmentImportConflictOverwrite,
                        overwrite: overwrite,
                        onOverwrite: (v) => setDraft(() => overwrite = v)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialog),
                          child: Text(l.commonCancel)),
                      TextButton(
                          onPressed: () => Navigator.pop(dialog, {
                                'strategy': overwrite
                                    ? AttachmentExportImportService
                                        .conflictOverwrite
                                    : AttachmentExportImportService
                                        .conflictSkip,
                                'preview': true
                              }),
                          child: Text(l.attachmentPreview)),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialog, {
                                'strategy': overwrite
                                    ? AttachmentExportImportService
                                        .conflictOverwrite
                                    : AttachmentExportImportService
                                        .conflictSkip,
                                'preview': false
                              }),
                          child: Text(l.attachmentStartImport))
                    ])));
  }
}
