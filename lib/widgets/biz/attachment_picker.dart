import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/attachment_service.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../ui/ui.dart';

/// 附件选择器组件
/// 用于在交易编辑页面选择和管理附件
/// 采用水平滚动列表，更优雅的交互体验
class AttachmentPicker extends ConsumerStatefulWidget {
  /// 交易ID（如果为null，表示新建交易，附件将在保存后关联）
  final int? transactionId;

  /// 待上传的临时文件列表（用于新建交易时临时存储）
  final List<File>? pendingFiles;

  /// 待上传文件变化回调
  final ValueChanged<List<File>>? onPendingFilesChanged;

  /// 最大附件数量
  final int maxCount;

  /// 是否只读模式
  final bool readOnly;

  /// 点击附件的回调
  final Function(List<TransactionAttachment> attachments, int index)?
      onAttachmentTap;

  const AttachmentPicker({
    super.key,
    this.transactionId,
    this.pendingFiles,
    this.onPendingFilesChanged,
    this.maxCount = 9,
    this.readOnly = false,
    this.onAttachmentTap,
  });

  @override
  ConsumerState<AttachmentPicker> createState() => _AttachmentPickerState();
}

class _AttachmentPickerState extends ConsumerState<AttachmentPicker> {
  List<File> _pendingFiles = [];

  @override
  void initState() {
    super.initState();
    _pendingFiles = widget.pendingFiles ?? [];
  }

  @override
  void didUpdateWidget(covariant AttachmentPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pendingFiles != oldWidget.pendingFiles) {
      _pendingFiles = widget.pendingFiles ?? [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // 如果有transactionId，从数据库获取附件
    if (widget.transactionId != null) {
      final attachmentsAsync =
          ref.watch(transactionAttachmentsProvider(widget.transactionId!));

      return attachmentsAsync.when(
        data: (attachments) =>
            _buildContent(context, attachments, _pendingFiles),
        loading: () => _buildLoading(),
        error: (e, s) => _buildError(l10n),
      );
    } else {
      // 新建交易时只显示待上传的文件
      return _buildContent(context, [], _pendingFiles);
    }
  }

  Widget _buildLoading() {
    return SizedBox(
      height: 80.scaled(context, ref),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return SizedBox(
      height: 80.scaled(context, ref),
      child: Center(
        child: Text(
          l10n.commonError,
          style: TextStyle(
            color: BeeTokens.textTertiary(context),
            fontSize: 14.scaled(context, ref),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<TransactionAttachment> attachments,
    List<File> pendingFiles,
  ) {
    final l10n = AppLocalizations.of(context);
    final totalCount = attachments.length + pendingFiles.length;
    final canAdd = !widget.readOnly && totalCount < widget.maxCount;

    // 只读模式且无附件时不显示
    if (totalCount == 0 && widget.readOnly) {
      return const SizedBox.shrink();
    }

    // 无附件时显示简洁的添加入口
    if (totalCount == 0 && canAdd) {
      return _buildEmptyState(context, l10n);
    }

    // 有附件时显示水平滚动列表
    final itemSize = 64.scaled(context, ref);
    final spacing = 8.scaled(context, ref);

    return SizedBox(
      height: itemSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length + pendingFiles.length + (canAdd ? 1 : 0),
        separatorBuilder: (_, __) => SizedBox(width: spacing),
        itemBuilder: (context, index) {
          // 已保存的附件
          if (index < attachments.length) {
            return _AttachmentThumbnail(
              attachment: attachments[index],
              size: itemSize,
              onTap: () => _openPreview(attachments, index),
              onDelete: widget.readOnly
                  ? null
                  : () => _deleteAttachment(attachments[index]),
            );
          }
          // 待上传的文件
          final pendingIndex = index - attachments.length;
          if (pendingIndex < pendingFiles.length) {
            return _PendingFileThumbnail(
              file: pendingFiles[pendingIndex],
              size: itemSize,
              onDelete: widget.readOnly
                  ? null
                  : () => _removePendingFile(pendingIndex),
            );
          }
          // 添加按钮
          return _AddButtonCompact(
            size: itemSize,
            onTap: () => _showAddOptions(context, l10n),
          );
        },
      ),
    );
  }

  /// 无附件时的空状态（简洁的添加入口）
  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => _showAddOptions(context, l10n),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: BeeTokens.surfaceInput(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.image_outlined,
              size: 18,
              color: BeeTokens.iconSecondary(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.attachmentAdd,
                style: TextStyle(
                  color: BeeTokens.textTertiary(context),
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              Icons.add,
              size: 18,
              color: BeeTokens.iconTertiary(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOptions(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.attachmentTakePhoto),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.attachmentChooseFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    final service = ref.read(attachmentServiceProvider);
    final file = await service.takePhoto();

    if (file != null) {
      if (widget.transactionId != null) {
        // 已有交易，直接保存
        await service.saveAttachment(
          transactionId: widget.transactionId!,
          sourceFile: file,
          index: 0,
        );
      } else {
        // 新建交易，添加到待上传列表
        setState(() {
          _pendingFiles = [..._pendingFiles, file];
        });
        widget.onPendingFilesChanged?.call(_pendingFiles);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final service = ref.read(attachmentServiceProvider);
    final currentCount = widget.transactionId != null
        ? (await ref
                .read(repositoryProvider)
                .getAttachmentsByTransaction(widget.transactionId!))
            .length
        : 0;
    final pendingCount = _pendingFiles.length;
    final remaining = widget.maxCount - currentCount - pendingCount;

    if (remaining <= 0) {
      if (mounted) {
        showToast(context, AppLocalizations.of(context).attachmentMaxReached);
      }
      return;
    }

    final files = await service.pickFromGallery(maxCount: remaining.toInt());

    if (files.isNotEmpty) {
      if (widget.transactionId != null) {
        // 已有交易，直接保存
        await service.saveAttachments(
          transactionId: widget.transactionId!,
          sourceFiles: files,
          startIndex: currentCount,
        );
      } else {
        // 新建交易，添加到待上传列表
        setState(() {
          _pendingFiles = [..._pendingFiles, ...files];
        });
        widget.onPendingFilesChanged?.call(_pendingFiles);
      }
    }
  }

  void _openPreview(List<TransactionAttachment> attachments, int index) {
    widget.onAttachmentTap?.call(attachments, index);
  }

  Future<void> _deleteAttachment(TransactionAttachment attachment) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.deleteConfirmTitle,
      message: l10n.attachmentDeleteConfirm,
    );

    if (confirmed == true) {
      final service = ref.read(attachmentServiceProvider);
      await service.deleteAttachment(attachment.id);
      if (mounted) {
        showToast(context, l10n.commonDeleted);
      }
    }
  }

  void _removePendingFile(int index) {
    setState(() {
      _pendingFiles = List.from(_pendingFiles)..removeAt(index);
    });
    widget.onPendingFilesChanged?.call(_pendingFiles);
  }
}

/// 已保存附件的缩略图
class _AttachmentThumbnail extends ConsumerWidget {
  final TransactionAttachment attachment;
  final double size;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _AttachmentThumbnail({
    required this.attachment,
    required this.size,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borderRadius = 10.scaled(context, ref);
    final deleteButtonSize = 18.scaled(context, ref);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: BeeTokens.surface(context),
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: FutureBuilder<String?>(
                future: ref
                    .read(attachmentServiceProvider)
                    .getThumbnailPath(attachment.fileName),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Image.file(
                      File(snapshot.data!),
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                    );
                  }
                  return Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: BeeTokens.iconTertiary(context),
                      size: 24.scaled(context, ref),
                    ),
                  );
                },
              ),
            ),
          ),
          if (onDelete != null)
            Positioned(
              top: -4,
              right: -4,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onDelete?.call();
                },
                child: Container(
                  width: deleteButtonSize,
                  height: deleteButtonSize,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 12.scaled(context, ref),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 待上传文件的缩略图
class _PendingFileThumbnail extends ConsumerWidget {
  final File file;
  final double size;
  final VoidCallback? onDelete;

  const _PendingFileThumbnail({
    required this.file,
    required this.size,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borderRadius = 10.scaled(context, ref);
    final deleteButtonSize = 18.scaled(context, ref);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: BeeTokens.surface(context),
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  file,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                ),
                // 待上传的半透明遮罩
                Container(
                  color: Colors.black.withValues(alpha: 0.2),
                  child: Center(
                    child: Icon(
                      Icons.hourglass_empty,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 20.scaled(context, ref),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onDelete != null)
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onDelete?.call();
              },
              child: Container(
                width: deleteButtonSize,
                height: deleteButtonSize,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 12.scaled(context, ref),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 紧凑型添加按钮（用于列表内）
class _AddButtonCompact extends ConsumerWidget {
  final double size;
  final VoidCallback onTap;

  const _AddButtonCompact({
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borderRadius = 10.scaled(context, ref);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: BeeTokens.surfaceInput(context),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: BeeTokens.border(context),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Icon(
          Icons.add,
          color: BeeTokens.iconSecondary(context),
          size: 24.scaled(context, ref),
        ),
      ),
    );
  }
}
