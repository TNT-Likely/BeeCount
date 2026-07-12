import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../services/attachment_service.dart';
import '../../widgets/ui/ui.dart';

/// 附件图片预览页面
/// 支持左右滑动查看多张图片，支持手势缩放
/// 支持添加和删除图片
class AttachmentPreviewPage extends ConsumerStatefulWidget {
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

  /// 使用附件列表构造
  const AttachmentPreviewPage({
    super.key,
    required List<TransactionAttachment> this.attachments,
    this.initialIndex = 0,
    this.allowDelete = true,
    this.allowAdd = false,
    this.pendingFiles,
    this.transactionId,
  });

  /// 使用交易ID构造（延迟加载附件）
  const AttachmentPreviewPage.fromTransaction({
    super.key,
    required int this.transactionId,
    this.initialIndex = 0,
    this.allowDelete = true,
    this.allowAdd = false,
  })  : attachments = null,
        pendingFiles = null;

  @override
  ConsumerState<AttachmentPreviewPage> createState() =>
      _AttachmentPreviewPageState();
}

class _AttachmentPreviewPageState extends ConsumerState<AttachmentPreviewPage> {
  late PageController _pageController;
  late int _currentIndex;
  List<TransactionAttachment> _savedAttachments = [];
  List<File> _pendingFiles = [];
  bool _isLoading = true;

  /// 总项目数（已保存 + 待上传）
  int get _totalCount => _savedAttachments.length + _pendingFiles.length;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _pendingFiles = List.from(widget.pendingFiles ?? []);

    // 隐藏状态栏，显示为全屏沉浸式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // 加载附件
    _loadAttachments();
  }

  Future<void> _loadAttachments() async {
    if (widget.attachments != null) {
      // 直接使用传入的附件列表
      setState(() {
        _savedAttachments = List.from(widget.attachments!);
        _isLoading = false;
      });
    } else if (widget.transactionId != null) {
      // 从数据库加载附件
      final attachments = await ref
          .read(transactionAttachmentsProvider(widget.transactionId!).future);
      if (mounted) {
        setState(() {
          _savedAttachments = List.from(attachments);
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    // 恢复状态栏
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // 加载中状态
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // 空状态
    if (_totalCount == 0) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            l10n.commonEmpty,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 图片查看区域
          GestureDetector(
            onTap: () => _handleClose(),
            child: PageView.builder(
              controller: _pageController,
              itemCount: _totalCount,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                if (index < _savedAttachments.length) {
                  // 显示已保存的附件
                  return _buildSavedImageView(_savedAttachments[index]);
                } else {
                  // 显示待上传的文件
                  final pendingIndex = index - _savedAttachments.length;
                  return _buildPendingImageView(_pendingFiles[pendingIndex]);
                }
              },
            ),
          ),
          // 顶部工具栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(context, l10n),
          ),
          // 底部页码指示器
          if (_totalCount > 1)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: _buildPageIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, AppLocalizations l10n) {
    final isSavedAttachment = _currentIndex < _savedAttachments.length;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // 返回按钮
              IconButton(
                onPressed: _handleClose,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
              const Spacer(),
              // 页码
              Text(
                '${_currentIndex + 1} / $_totalCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              // 添加按钮
              if (widget.allowAdd && _totalCount < 9)
                IconButton(
                  onPressed: () => _showAddOptions(l10n),
                  icon: const Icon(Icons.add_photo_alternate_outlined,
                      color: Colors.white),
                ),
              // 删除按钮
              if (widget.allowDelete)
                IconButton(
                  onPressed: () => isSavedAttachment
                      ? _deleteSavedAttachment(l10n)
                      : _deletePendingFile(),
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedImageView(TransactionAttachment attachment) {
    return FutureBuilder<String>(
      future: ref
          .read(attachmentServiceProvider)
          .getAttachmentPath(attachment.fileName),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final file = File(snapshot.data!);
        if (!file.existsSync()) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).commonError,
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          );
        }

        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.file(
              file,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingImageView(File file) {
    return Stack(
      children: [
        InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.file(
              file,
              fit: BoxFit.contain,
            ),
          ),
        ),
        // 待上传标识
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.hourglass_empty,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context).commonSave,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalCount, (index) {
        final isActive = index == _currentIndex;
        final isPending = index >= _savedAttachments.length;
        return Container(
          width: isActive ? 10 : 8,
          height: isActive ? 10 : 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white
                : (isPending
                    ? Colors.orange.withValues(alpha: 0.7)
                    : Colors.white54),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  void _handleClose() {
    // 返回更新后的 pendingFiles 列表
    Navigator.pop(context, _pendingFiles);
  }

  Future<void> _showAddOptions(AppLocalizations l10n) async {
    final service = ref.read(attachmentServiceProvider);

    await showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.attachmentTakePhoto),
              onTap: () async {
                Navigator.pop(context);
                final file = await service.takePhoto();
                if (file != null && mounted) {
                  await _addFile(file);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.attachmentChooseFromGallery),
              onTap: () async {
                Navigator.pop(context);
                final remaining = 9 - _totalCount;
                final files =
                    await service.pickFromGallery(maxCount: remaining);
                if (files.isNotEmpty && mounted) {
                  for (final file in files) {
                    await _addFile(file);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addFile(File file) async {
    final service = ref.read(attachmentServiceProvider);

    if (widget.transactionId != null) {
      // 编辑模式：直接保存到数据库
      final attachment = await service.saveAttachment(
        transactionId: widget.transactionId!,
        sourceFile: file,
        index: _savedAttachments.length,
      );
      if (attachment != null && mounted) {
        setState(() {
          _savedAttachments.add(attachment);
          _currentIndex = _savedAttachments.length - 1;
        });
        _pageController.jumpToPage(_currentIndex);
        // 触发刷新
        ref.read(attachmentListRefreshProvider.notifier).state++;
      }
    } else {
      // 新建模式：添加到待上传列表
      setState(() {
        _pendingFiles.add(file);
        _currentIndex = _totalCount - 1;
      });
      _pageController.jumpToPage(_currentIndex);
    }
  }

  Future<void> _deleteSavedAttachment(AppLocalizations l10n) async {
    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.deleteConfirmTitle,
      message: l10n.attachmentDeleteConfirm,
    );

    if (confirmed != true) return;

    final attachment = _savedAttachments[_currentIndex];
    final service = ref.read(attachmentServiceProvider);

    await service.deleteAttachment(attachment.id);

    // 触发附件列表刷新
    ref.read(attachmentListRefreshProvider.notifier).state++;

    setState(() {
      _savedAttachments.removeAt(_currentIndex);
      if (_currentIndex >= _totalCount && _currentIndex > 0) {
        _currentIndex--;
      }
    });

    if (_totalCount == 0) {
      if (mounted) {
        Navigator.pop(context, _pendingFiles);
      }
    } else {
      _pageController.jumpToPage(_currentIndex);
    }

    if (mounted) {
      showToast(context, l10n.commonDeleted);
    }
  }

  void _deletePendingFile() {
    final pendingIndex = _currentIndex - _savedAttachments.length;

    setState(() {
      _pendingFiles.removeAt(pendingIndex);
      if (_currentIndex >= _totalCount && _currentIndex > 0) {
        _currentIndex--;
      }
    });

    if (_totalCount == 0) {
      Navigator.pop(context, _pendingFiles);
    } else {
      _pageController.jumpToPage(_currentIndex);
    }
  }
}
