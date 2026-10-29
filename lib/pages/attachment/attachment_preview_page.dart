import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/db.dart';
import 'widgets/attachment_viewer.dart';

/// 附件图片预览页面
/// 支持左右滑动查看多张图片，支持手势缩放
/// 支持添加和删除图片
class AttachmentPreviewPage extends StatelessWidget {
  /// 附件列表（当直接传入时使用）
  final List<TransactionAttachment>? attachments;

  /// 交易ID（用于从数据库加载附件或保存新附件）
  final int? transactionId;

  /// 初始显示的索引
  final int initialIndex;

  /// 是否允许删除
  final bool allowDelete;

  /// 是否允许添加
  final bool allowAdd;

  /// 待上传的文件列表（新建模式）
  final List<File>? pendingFiles;
  final ValueChanged<List<File>>? onPendingFilesChanged;

  /// 使用附件列表构造
  const AttachmentPreviewPage({
    super.key,
    required List<TransactionAttachment> this.attachments,
    this.initialIndex = 0,
    this.allowDelete = true,
    this.allowAdd = false,
    this.pendingFiles,
    this.onPendingFilesChanged,
    this.transactionId,
  });

  /// 使用交易ID构造（延迟加载附件）
  const AttachmentPreviewPage.fromTransaction({
    super.key,
    required int this.transactionId,
    this.initialIndex = 0,
    this.allowDelete = true,
    this.allowAdd = false,
    this.onPendingFilesChanged,
  })  : attachments = null,
        pendingFiles = null;

  @override
  Widget build(BuildContext context) => AttachmentViewerBinding(
      attachments: attachments,
      transactionId: transactionId,
      initialIndex: initialIndex,
      allowDelete: allowDelete,
      allowAdd: allowAdd,
      pendingFiles: pendingFiles,
      onPendingFilesChanged: onPendingFilesChanged);
}
